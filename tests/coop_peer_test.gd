extends SceneTree
## Three-process loopback integration driver; tests/run_coop_test.py orchestrates it.
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok:
  failures.append(message)
  push_error(message)
func run() -> void:
 var mode := "server"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--role="): mode = argument.get_slice("=",1)
 var game: Node3D = load("res://physics_trial.tscn").instantiate()
 root.add_child(game)
 var session: Node = game.session
 var rig: Node3D = game.boat.get_node("Mechanisms")
 if mode=="server":
  check(session.host(19080)==OK,"WebSocket host must bind loopback test port")
  # Transport/ownership fixture uses a light steady load. Overload slip is tested
  # separately by the membrane suite; evolving gusts must not imply guaranteed haul.
  var weather: Node = game.get_node("Weather")
  weather.set_process(false)
  weather.state.wind = Vector3(0,0,-3)
  game.boat.wind_world = weather.state.wind
  for frame in 700: await physics_frame
  check(session.accepted>=3,"Host must accept remote helm and brace commands")
  check(session.rejected>=2,"Host must reject occupied stations and invalid commands")
  check(session.stations.is_empty(),"Disconnect must release station ownership")
  check(rig.cloth.lines[0].mode!=1,"Disconnect must release hand-held sheets")
  print("COOP SERVER: accepted=",session.accepted," rejected=",session.rejected)
 else:
  var messages: Array[String] = []
  session.feedback.connect(func(message: String): messages.append(message))
  check(session.join("ws://127.0.0.1:19080")==OK,"Client must create WebSocket transport")
  for frame in 180:
   await physics_frame
   if session.connected and session.last_tick>0: break
  check(session.connected and session.last_tick>0,"Client must receive authoritative ship snapshot")
  check(game.boat.freeze and not game.boat.is_physics_processing(),"Client must not independently simulate the shared hull")
  if mode=="helm":
   session.send_action("starboard")
   session.send_action("starboard")
   session.send_action("teleport",999999.0)
   for frame in 150: await physics_frame
   check(game.boat.rudder_input>0.1,"Authoritative helm response must reach client")
   check(session.latest.people.size()==3,"All three participants must be represented")
  else:
   # The helm client has already claimed the helm; the second must use another station.
   for frame in 45: await physics_frame
   session.send_action("port")
   session.send_action("brace_free",0.0,1)
   session.send_action("brace_pull",-1.0,0)
   # Deliberately stop polling, like a stalled browser/GPU. Old snapshots must not
   # flood its WebSocket buffer while the host keeps simulating.
   OS.delay_msec(2600)
   for frame in 120: await physics_frame
   session.send_action("brace_belay",0.0,0)
   for frame in 12: await physics_frame
   check(messages.any(func(m: String) -> bool: return "Station is held" in m),"Competing helm input must be denied")
   check(rig.brace.lines[0].mode==0,"Remote belaying must be reflected in authoritative state")
   check(session.latest.weather.has("state"),"Late-joining clients must receive current weather")
   var initial_length: float = rig.cloth.lines[0].length
   session.send_action("clew_pull",-1.0,0)
   for frame in 60: await physics_frame
   session.send_action("clew_belay",0.0,0)
   for frame in 12: await physics_frame
   for frame in 60:
    if rig.cloth.lines[0].mode==0 and rig.cloth.lines[0].length<initial_length-0.05: break
    await physics_frame
   print("COOP CLEW RESULT: ",initial_length," -> ",rig.cloth.lines[0].length," mode=",rig.cloth.lines[0].mode)
   check(rig.cloth.lines[0].mode==0 and rig.cloth.lines[0].length<initial_length-0.05,"Remote clew haul and belay must reach host and replicate back")
   check(session.latest.cloth.points.size()==35 and rig.cloth.points.size()==35,"Authoritative deformed cloth must reach clients")
   session.send_action("clew_pull",0.0,0) # disconnect must release a hand-held sheet
  check(game.boat.global_position.is_finite(),"Replicated vessel pose must remain finite")
  session.stop()
 if failures.is_empty(): print("APEX COOP PEER PASS: ",mode)
 game.free()
 quit(0 if failures.is_empty() else 1)
