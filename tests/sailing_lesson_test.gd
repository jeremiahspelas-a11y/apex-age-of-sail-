extends SceneTree
var failures: Array[String] = []
var game: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok:
  failures.append(message)
  push_error(message)
func walk_to(target: Vector2) -> bool:
 # Move the real CharacterBody through deck collisions; no teleports between stations.
 for frame in 1200:
  var p: Vector3 = game.boat.to_local(game.player.global_position)
  var offset := target-Vector2(p.x,p.z)
  if offset.length()<0.15:
   game.player.motion_input = Vector2.ZERO
   return true
  game.player.movement_heading = game.boat.global_rotation.y
  game.player.motion_input = offset.normalized()
  await physics_frame
 game.player.motion_input = Vector2.ZERO
 var p: Vector3 = game.boat.to_local(game.player.global_position)
 push_error("Walk stopped at %s toward %s"%[p,target])
 return false
func run() -> void:
 root.size = Vector2i(960,540)
 game = load("res://physics_trial.tscn").instantiate()
 root.add_child(game)
 game.lesson.start_lesson()
 var lesson: Node = game.lesson
 var deck: Node = lesson.deck
 for frame in 60: await physics_frame
 check(game.boat.force_trial,"Lesson must use loaded mechanical physics")
 check(not game.normal_ui.visible and lesson.hud.visible,"Lesson must replace workshop controls with its context UI")
 check(deck.stations.size()==5,"Wheel and both fore sheets/braces must have deck stations")
 check(not deck.take(0),"Distant player must not operate the wheel")
 lesson._use_nearest()
 check(lesson.stage==0 and deck.current<0,"Lesson must not credit pressing Use from outside a station")
 check(await walk_to(Vector2(-1.7,-2.9)),"Player must walk to the fore sheet on the actual deck")
 check(deck.take(1),"Player beside fore sheet must take its tail")
 for frame in 2: await process_frame
 check(lesson.stage==1,"Reaching and taking the sheet must begin haul instruction")
 lesson._belay()
 for frame in 2: await process_frame
 check(lesson.stage==1,"Belaying without hauling must not complete the lesson")
 deck.pull(-1.0)
 for frame in 600:
  await physics_frame
  if lesson.stage>=2: break
 deck.stop_hands()
 check(lesson.stage==2,"Actual shortening by 12 cm must unlock belaying instruction")
 check(deck.mechanics.cloth.lines[0].mode==1,"Stopping the hand must not silently belay the rope")
 lesson._belay()
 for frame in 2: await process_frame
 check(lesson.stage==3 and deck.mechanics.cloth.lines[0].mode==0,"Actual belay must secure the sheet and advance")
 deck.release()
 check(deck.mechanics.cloth.lines[0].mode==0,"Leaving a belayed line must preserve its securing")
 for target: Vector2 in [Vector2(-1.2,0),Vector2(-1.2,5.9),Vector2(0,6.3),Vector2(0,9.7),Vector2(1,9.8),Vector2(1,11.35)]:
  check(await walk_to(target),"Player must traverse deck and quarterdeck stairs toward wheel: %s"%target)
 var foot: Vector3 = game.boat.to_local(game.player.global_position)-Vector3.UP*0.9
 check(foot.y>2.2,"Wheel approach must stand on raised quarterdeck")
 check(deck.take(0),"Quarterdeck sailor must take the wheel")
 for frame in 2: await process_frame
 check(lesson.stage==4,"Wheel grip must advance to steering instruction")
 deck.pull(1.0)
 for frame in 600:
  await physics_frame
  if lesson.stage>=5: break
 deck.stop_hands()
 check(lesson.stage==5,"Positive helm effort must move the solved rudder five degrees starboard")
 # User-like counter-steering with short pulls, rather than assigning rudder state.
 for frame in 1200:
  var angle: float = deck.mechanics.actual_rudder_angle
  var velocity: float = deck.mechanics.helm.rudder_velocity
  deck.pull(clampf(-angle*7.0-velocity*5.0,-1,1))
  await physics_frame
  if lesson.stage>=6: break
 check(lesson.stage==6,"Counter-steering must center the actual rudder and complete introduction")
 deck.release()
 check(is_zero_approx(deck.mechanics.helm.direct_helm_torque),"Leaving wheel must release applied hand effort")
 # Reach must also reject the wheel when directly below it on the main deck.
 game.player.global_position = game.boat.to_global(Vector3(1,2.04,11.35))
 check(not deck.can_reach(0),"Proximity must not reach wheel through the quarterdeck floor")
 # VR hint/adapter use the same physical pin and wheel locations.
 check("WHEEL" in game.vr.hint_at(deck.mechanics.wheel.position+Vector3(0.72,0,0)),"VR must explain grip beside wheel rim")
 check("CLEW SHEET" in game.vr.hint_at(deck.mechanics.cloth.lines[0].belay),"VR must explain grip and belay at real clew pin")
 check(game.vr.hint_at(Vector3(30,30,30)).is_empty(),"Distant VR hand must not display a use affordance")
 var hand: RefCounted = load("res://scripts/vr_hand_input.gd").new()
 hand.grab_brace(0,deck.mechanics.cloth.lines[0].belay,deck.mechanics.cloth.lines[0].belay)
 game.vr.grips[3] = hand
 game.vr.clew_grips[3] = true
 game.vr.active = true
 check(lesson._engaged(1) and not lesson._engaged(0),"VR clew grip must satisfy the same station lesson as desktop Use")
 game.vr.active = false
 game.vr.grips.clear()
 game.vr.clew_grips.clear()
 deck.mechanics.cloth.cut(0)
 deck.mechanics.helm.connected = false
 game.flooding_system.breach(0)
 game.flooding_system.compartments[0].water = 1.0
 var fitting_count: int = deck.mechanics.get_child_count()
 lesson.start_lesson()
 check(deck.mechanics.cloth.lines[0].mode==0 and deck.mechanics.helm.connected,"Restart must repair cut lesson controls")
 check(game.flooding_system.compartments[0].water==0.0 and game.flooding_system.compartments[0].leak_area==0.0,"Restart must reset practice flooding")
 check(deck.mechanics.get_child_count()==fitting_count,"Restart must not duplicate physical fittings")
 game.free()
 await process_frame
 if failures.is_empty(): print("APEX SAILING LESSON TEST PASS: real deck/stair travel, proximity, loaded haul/belay, wheel/rudder lesson and VR station affordances; headset untested")
 quit(0 if failures.is_empty() else 1)
