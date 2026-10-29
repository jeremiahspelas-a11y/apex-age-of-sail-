extends Node
## Authoritative WebSocket co-op prototype: one ship simulation and exclusive stations.
## Reliable snapshots suit training; this is not an Internet lobby/relay service.
signal feedback(message: String)
const PlayerWalk = preload("res://scripts/player_walk.gd")
const MAX_CREW := 20
const HANDSHAKE_TIMEOUT_SECONDS := 15.0 # allow slow browser startup without unbounded pending peers
var game: Node3D
var active := false
var connected := false
var is_host := false
var stations: Dictionary = {}
var avatars: Dictionary = {}
var remote_visuals: Dictionary = {}
var last_input: Dictionary = {}
var rates: Dictionary = {}
var timer := 0.0
var send_clock := 0.0
var last_tick := -1
var target_pose := Transform3D.IDENTITY
var latest: Dictionary = {}
var accepted := 0
var rejected := 0
var jump_queued := false
var received_packets := 0
var pending_snapshots: Dictionary = {}
var reported_input := INF
var reported_crew := -1
func setup(root: Node3D) -> void:
 game = root
 multiplayer.peer_connected.connect(_peer_joined)
 multiplayer.peer_disconnected.connect(_peer_left)
 multiplayer.connected_to_server.connect(_connected)
 multiplayer.connection_failed.connect(func(): feedback.emit("Connection failed"); stop())
 multiplayer.server_disconnected.connect(func(): feedback.emit("Host disconnected"); stop())
func host(port: int = 9080) -> Error:
 if OS.has_feature("web"): return ERR_UNAVAILABLE
 if active: return ERR_ALREADY_IN_USE
 var peer := WebSocketMultiplayerPeer.new()
 peer.handshake_timeout = HANDSHAKE_TIMEOUT_SECONDS
 var error := peer.create_server(port)
 if error!=OK: return error
 multiplayer.multiplayer_peer = peer
 active = true
 connected = true
 is_host = true
 game.boat.set_force_trial(true)
 feedback.emit("Hosting co-op on port %d"%port)
 return OK
func join(url: String) -> Error:
 if active: return ERR_ALREADY_IN_USE
 if not (url.begins_with("ws://") or url.begins_with("wss://")): return ERR_INVALID_PARAMETER
 var peer := WebSocketMultiplayerPeer.new()
 peer.handshake_timeout = HANDSHAKE_TIMEOUT_SECONDS
 var error := peer.create_client(url)
 if error!=OK: return error
 multiplayer.multiplayer_peer = peer
 active = true
 is_host = false
 last_tick = -1
 received_packets = 0
 latest.clear()
 _client_mode()
 feedback.emit("Connecting…")
 return OK
func _client_mode() -> void:
 game.boat.prepare_force_trial()
 game.boat.force_trial = true
 game.boat.get_node("Mechanisms").set_cloth_active(true)
 game.boat.freeze = true
 game.boat.set_physics_process(false)
 game.boat.get_node("ShipIntegrity").set_physics_process(false)
 game.get_node("Weather").externally_driven = true
 Ocean.clock_authority = false
 target_pose = game.boat.global_transform
func _connected() -> void:
 connected = true
 feedback.emit("Joined shared ship")
 print("APEX COOP CONNECTED ",multiplayer.get_unique_id())
func stop() -> void:
 if not active: return
 var was_client := not is_host
 if is_host:
  for id: int in stations.values(): _release_stations(id)
 multiplayer.multiplayer_peer.close()
 multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
 active = false
 connected = false
 is_host = false
 stations.clear()
 pending_snapshots.clear()
 for avatar: Node in avatars.values(): avatar.queue_free()
 for visual: Node in remote_visuals.values(): visual.queue_free()
 avatars.clear()
 remote_visuals.clear()
 Ocean.clock_authority = true
 game.get_node("Weather").externally_driven = false
 if was_client:
  game.boat.set_physics_process(true)
  game.boat.get_node("ShipIntegrity").set_physics_process(true)
  game.boat.set_force_trial(false)
func _peer_joined(id: int) -> void:
 if not is_host: return
 if avatars.size()>=MAX_CREW-1:
  multiplayer.multiplayer_peer.disconnect_peer(id)
  return
 var avatar := CharacterBody3D.new()
 avatar.name = "Crew_%d"%id
 avatar.set_script(PlayerWalk)
 avatar.boat_path = game.boat.get_path()
 avatar.view_path = NodePath("")
 avatar.read_keyboard = false
 avatar.movement_follows_view = false
 avatar.collision_layer = 2
 avatar.collision_mask = 1
 var shape := CollisionShape3D.new()
 var capsule := CapsuleShape3D.new()
 capsule.radius = 0.3
 capsule.height = 1.8
 shape.shape = capsule
 avatar.add_child(shape)
 var visible_body := MeshInstance3D.new()
 var body_mesh := CapsuleMesh.new()
 body_mesh.radius = 0.28
 body_mesh.height = 1.8
 visible_body.mesh = body_mesh
 avatar.add_child(visible_body)
 game.add_child(avatar)
 avatar.global_position = game.boat.to_global(Vector3(-1.2,2.1,float(avatars.size())*0.8))
 avatars[id] = avatar
 last_input[id] = timer
 pending_snapshots[id] = -1
func _peer_left(id: int) -> void:
 if not is_host: return
 _release_stations(id)
 if avatars.has(id):
  avatars[id].queue_free()
  avatars.erase(id)
 last_input.erase(id)
 rates.erase(id)
 pending_snapshots.erase(id)
func _release_stations(id: int) -> void:
 var rig: Node3D = game.boat.get_node("Mechanisms")
 for station: String in stations.keys():
  if stations[station]!=id: continue
  if station=="helm": rig.set_helm_torque(0.0)
  if station=="brace_port" and rig.brace.lines[0].mode==1: rig.brace.release(0)
  if station=="brace_starboard" and rig.brace.lines[1].mode==1: rig.brace.release(1)
  if station=="clew_port" and rig.cloth.lines[0].mode==1: rig.cloth.release(0)
  if station=="clew_starboard" and rig.cloth.lines[1].mode==1: rig.cloth.release(1)
  stations.erase(station)
func _claim(id: int,station: String) -> bool:
 if stations.has(station) and int(stations[station])!=id: return false
 for previous: String in stations.keys():
  if stations[previous]==id and previous!=station: _release_stations(id)
 stations[station] = id
 return true
func _rate_ok(id: int) -> bool:
 var rate: Dictionary = rates.get(id,{"start":timer,"count":0})
 if timer-rate.start>1.0: rate = {"start":timer,"count":0}
 rate.count += 1
 rates[id] = rate
 return rate.count<=50
func _transport_open(id: int) -> bool:
 # SceneMultiplayer can retain an ID until its next poll after WebSocket close.
 # Do not queue RPCs to a closing socket just because the ID is still present.
 if not active or not multiplayer.get_peers().has(id): return false
 var transport := multiplayer.multiplayer_peer as WebSocketMultiplayerPeer
 if transport==null: return false
 var socket := transport.get_peer(id)
 return socket!=null and socket.get_ready_state()==WebSocketPeer.STATE_OPEN
func send_action(action: String,value: float = 0.0,index: int = 0) -> void:
 if not active: return
 if is_host: _apply_action(1,action,value,index)
 elif connected and _transport_open(1): request_action.rpc_id(1,action,value,index)
@rpc("any_peer","call_remote","reliable")
func request_action(action: String,value: float,index: int) -> void:
 if not is_host: return
 var id := multiplayer.get_remote_sender_id()
 if not avatars.has(id) or not _rate_ok(id): return
 last_input[id] = timer
 _apply_action(id,action,value,index)
func _deny(id: int,message: String) -> bool:
 rejected += 1
 if id==1: feedback.emit(message)
 elif _transport_open(id): command_feedback.rpc_id(id,message)
 return false
func _apply_action(id: int,action: String,value: float,index: int) -> bool:
 if not is_finite(value): return _deny(id,"Invalid input")
 var station := ""
 if action in ["port","starboard","rope_cut","helm_torque"]: station = "helm"
 elif action in ["raise","lower","sheet_l","sheet_r"]: station = "sails"
 elif action in ["door","hatch"]: station = "deck"
 elif action=="pump": station = "pumps"
 elif action.begins_with("brace_"):
  if index not in [0,1]: return _deny(id,"Invalid brace")
  station = "brace_port" if index==0 else "brace_starboard"
 elif action.begins_with("clew_"):
  if index not in [0,1]: return _deny(id,"Invalid clew sheet")
  station = "clew_port" if index==0 else "clew_starboard"
 elif action=="release_station":
  _release_stations(id)
  return true
 elif action=="weather":
  if id!=1 or int(value) not in range(5): return _deny(id,"Weather belongs to host")
  return game.get_node("Weather").set_scenario(["Evolving","Calm","Breeze","Squall","Storm"][int(value)])
 elif action in ["breach","patch"] and id==1: station = "instructor"
 else: return _deny(id,"Unknown command")
 if action not in ["port","starboard","rope_cut","helm_torque","raise","lower","sheet_l","sheet_r","door","hatch","pump","breach","patch","brace_pull","brace_stop","brace_belay","brace_free","brace_cut","clew_pull","clew_stop","clew_belay","clew_free","clew_cut"]:
  return _deny(id,"Unknown command")
 if action in ["brace_stop","clew_stop"]:
  if stations.get(station,0)==id:
   var line_rig: RefCounted = game.boat.get_node("Mechanisms").cloth if action=="clew_stop" else game.boat.get_node("Mechanisms").brace
   line_rig.lines[index].pull = 0.0
  return true
 if not _claim(id,station): return _deny(id,"Station is held by another sailor")
 var rig: Node3D = game.boat.get_node("Mechanisms")
 match action:
  "helm_torque": rig.set_helm_torque(clampf(value,-129.6,129.6))
  "brace_pull": rig.brace.set_hand(index,clampf(value,-1,1))
  "brace_belay": rig.brace.belay(index)
  "brace_free": rig.brace.release(index)
  "brace_cut": rig.brace.cut(index)
  "clew_pull": rig.cloth.set_hand(index,clampf(value,-1,1))
  "clew_belay": rig.cloth.belay(index)
  "clew_free": rig.cloth.release(index)
  "clew_cut": rig.cloth.cut(index)
  _:
   if station=="helm": rig.use_button_helm()
   game._apply_command(action)
 accepted += 1
 return true
@rpc("authority","call_remote","reliable")
func command_feedback(message: String) -> void:
 feedback.emit(message)
@rpc("any_peer","call_remote","reliable")
func request_move(axis: Vector2,heading: float,jump: bool) -> void:
 if not is_host: return
 var id := multiplayer.get_remote_sender_id()
 if not avatars.has(id) or not _rate_ok(id) or not axis.is_finite() or not is_finite(heading): return
 last_input[id] = timer
 var avatar: CharacterBody3D = avatars[id]
 avatar.motion_input = axis.limit_length(1.0)
 avatar.movement_heading = wrapf(heading,-PI,PI)
 avatar.remote_jump = jump
func _physics_process(delta: float) -> void:
 if not active: return
 timer += delta
 send_clock += delta
 if is_host:
  for id: int in avatars.keys():
   if timer-float(last_input.get(id,timer))>0.4:
    avatars[id].motion_input = Vector2.ZERO
   if timer-float(last_input.get(id,timer))>2.0: _release_stations(id)
  if send_clock>=0.1:
   send_clock = 0.0
   var data: Dictionary = {}
   for id: int in multiplayer.get_peers():
    if not _transport_open(id): continue
    if int(pending_snapshots.get(id,-1))!=-1: continue
    if data.is_empty(): data = capture_world()
    pending_snapshots[id] = data.tick
    receive_world.rpc_id(id,data)
 elif connected and _transport_open(1):
  jump_queued = jump_queued or Input.is_action_just_pressed("ui_accept")
  Ocean.time += delta
  game.boat.global_transform = game.boat.global_transform.interpolate_with(target_pose,1.0-exp(-delta*18.0))
  if latest.has("cloth"):
   game.boat.get_node("Mechanisms").cloth.receive_snapshot(latest.cloth,game.boat.global_transform)
  _update_visuals()
  if send_clock>=0.05:
   send_clock = 0.0
   var player: CharacterBody3D = game.player
   var axis := Input.get_vector("ui_left","ui_right","ui_up","ui_down")
   if player.motion_input.length()>0.1: axis = player.motion_input
   if not player.movement_enabled: axis = Vector2.ZERO
   var view: Camera3D = game.get_viewport().get_camera_3d()
   request_move.rpc_id(1,axis,view.global_rotation.y,jump_queued)
   jump_queued = false
func capture_world() -> Dictionary:
 var boat: RigidBody3D = game.boat
 var rig := boat.get_node("Mechanisms")
 var people := {1:boat.to_local(game.player.global_position)}
 for id: int in avatars.keys(): people[id] = boat.to_local(avatars[id].global_position)
 return {"protocol":2,"mass":boat.mass,"com":boat.center_of_mass,"inertia":boat.inertia,"tick":Engine.get_physics_frames(),"time":Ocean.time,"pose":boat.global_transform,"linear":boat.linear_velocity,"angular":boat.angular_velocity,"wind":boat.wind_world,"rudder_input":boat.rudder_input,"reef":boat.reef_fraction,"sheet":boat.sheet_angle,"wheel":rig.helm.wheel_angle,"rudder":rig.helm.rudder_angle,"steering_intact":rig.helm.connected,"steering_tensions":Vector2(rig.helm.port_line_tension,rig.helm.starboard_line_tension),"yard":rig.brace.angle,"yard_velocity":rig.brace.angular_velocity,"lines":rig.brace.lines.duplicate(true),"cloth":rig.cloth.snapshot(boat.global_transform),"doors":rig.door_open,"hatches":rig.hatch_open,"compartments":boat.get_node("ShipIntegrity").compartments.duplicate(true),"weather":game.get_node("Weather").snapshot(),"people":people,"stations":stations.duplicate(),"rig_force":boat.rig_report.get("force",Vector3.ZERO),"buoyancy":boat.hydro_report.get("buoyancy",Vector3.ZERO)}
@rpc("authority","call_remote","reliable")
func receive_world(data: Dictionary) -> void:
 if is_host: return
 if int(data.get("protocol",0))!=2:
  feedback.emit("Incompatible co-op version")
  stop()
  return
 if _transport_open(1): acknowledge_world.rpc_id(1,int(data.tick))
 if int(data.tick)<=last_tick: return
 last_tick = data.tick
 received_packets += 1
 if received_packets%10==1 or reported_input!=float(data.rudder_input) or reported_crew!=int(data.people.size()):
  reported_input = float(data.rudder_input)
  reported_crew = int(data.people.size())
  print("APEX COOP STATE ",JSON.stringify({"tick":data.tick,"time":data.time,"crew":data.people.size(),"rudder_input":data.rudder_input,"yard":data.yard,"sea_scale":data.weather.sea_scale,"wind":[data.wind.x,data.wind.y,data.wind.z]}))
 latest = data
 target_pose = data.pose
 if absf(Ocean.time-float(data.time))>0.5: Ocean.time = data.time
 else: Ocean.time = lerpf(Ocean.time,data.time,0.25)
 var boat: RigidBody3D = game.boat
 boat.linear_velocity = data.linear
 boat.angular_velocity = data.angular
 boat.wind_world = data.wind
 boat.mass = data.mass
 boat.center_of_mass = data.com
 boat.inertia = data.inertia
 boat.rudder_input = data.rudder_input
 boat.reef_fraction = data.reef
 boat.sheet_angle = data.sheet
 game.rudder = data.rudder_input
 game.reef = data.reef
 game.sheet = data.sheet
 var rig := boat.get_node("Mechanisms")
 rig.helm.wheel_angle = data.wheel
 rig.helm.rudder_angle = data.rudder
 rig.helm.connected = data.steering_intact
 rig.helm.port_line_tension = data.steering_tensions.x
 rig.helm.starboard_line_tension = data.steering_tensions.y
 rig.brace.angle = data.yard
 rig.brace.angular_velocity = data.yard_velocity
 rig.brace.lines = data.lines
 rig.cloth.receive_snapshot(data.cloth,boat.global_transform)
 if rig.loaded_yard!=null: rig.loaded_yard.rotation.y = data.yard
 rig.door_open = data.doors
 rig.hatch_open = data.hatches
 boat.hydro_report = {"buoyancy":data.buoyancy}
 boat.rig_report = {"force":data.get("rig_force",Vector3.ZERO)}
 boat.get_node("ShipIntegrity").compartments = data.compartments
 boat.get_node("ShipIntegrity").water_m3 = 0.0
 for compartment: Dictionary in data.compartments:
  boat.get_node("ShipIntegrity").water_m3 += float(compartment.water)
 game.get_node("Weather").receive_snapshot(data.weather)
 stations = data.stations
 var id := multiplayer.get_unique_id()
 if data.people.has(id):
  var target: Vector3 = boat.to_global(data.people[id])
  if game.player.global_position.distance_to(target)>1.5: game.player.global_position = target
  else: game.player.global_position = game.player.global_position.lerp(target,0.12)
 _update_visuals()
@rpc("any_peer","call_remote","reliable")
func acknowledge_world(tick: int) -> void:
 if not is_host: return
 var id := multiplayer.get_remote_sender_id()
 if pending_snapshots.get(id,-1)==tick: pending_snapshots[id] = -1
func _update_visuals() -> void:
 if latest.is_empty(): return
 var id := multiplayer.get_unique_id()
 for peer_id: int in latest.people.keys():
  if peer_id==id: continue
  if not remote_visuals.has(peer_id):
   var visual := MeshInstance3D.new()
   var body := CapsuleMesh.new()
   body.radius = 0.28
   body.height = 1.8
   visual.mesh = body
   var material := StandardMaterial3D.new()
   material.albedo_color = Color(0.20,0.38,0.55) if peer_id%2==0 else Color(0.55,0.30,0.16)
   visual.material_override = material
   game.add_child(visual)
   remote_visuals[peer_id] = visual
  remote_visuals[peer_id].global_position = game.boat.to_global(latest.people[peer_id])
 for peer_id: int in remote_visuals.keys():
  if not latest.people.has(peer_id):
   remote_visuals[peer_id].queue_free()
   remote_visuals.erase(peer_id)
