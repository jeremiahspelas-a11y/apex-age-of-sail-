extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok:
  failures.append(message)
  push_error(message)
func run() -> void:
 var game: Node3D = load("res://physics_trial.tscn").instantiate()
 root.add_child(game)
 game.set_process(false)
 game.get_node("Weather").set_process(false)
 var boat: RigidBody3D = game.boat
 boat.set_physics_process(false)
 boat.transform = Transform3D.IDENTITY
 var player: CharacterBody3D = game.player
 player.position = Vector3(1.2,2.1,0)
 player._old_ship_transform = boat.global_transform
 for frame in 30: await physics_frame
 check(player.is_on_floor(),"First-person player must stand on the fitted main deck")
 game._deck_camera()
 check(game.camera.global_position.distance_to(player.global_position+Vector3.UP*0.65)<0.001,"Camera must follow the player's eye position")
 check(not player.get_node("CrewSkeleton").visible and not player.get_node("ImportedCharacter").visible,"Player meshes must not obscure the deck camera")
 game.view_yaw = PI*0.5
 game.view_pitch = 0.8
 game._deck_camera()
 var start := player.position
 player.motion_input = Vector2(0,-1)
 for frame in 15: await physics_frame
 player.motion_input = Vector2.ZERO
 var travel := player.position-start
 check(travel.x < -0.45 and absf(travel.z)<0.05,"Forward walking must follow horizontal gaze even when looking up")
 check(absf(player.velocity.length()-player.walk_speed)<0.1,"Head pitch must not reduce forward walking speed")
 await physics_frame
 game._toggle_fly()
 check(game.god_mode and not player.movement_enabled,"Inspection must suspend player movement")
 var anchored := boat.to_local(player.global_position)
 boat.position += Vector3(0.2,0,0.1)
 for frame in 2: await physics_frame
 check(boat.to_local(player.global_position).distance_to(anchored)<0.01,"Inspection must retain the player's position aboard a moving ship")
 game._toggle_fly()
 check(not game.god_mode and player.movement_enabled,"Returning from inspection must restore deck walking")
 check(game.camera.global_position.distance_to(player.global_position+Vector3.UP*0.65)<0.001,"Returning from inspection must restore the eye camera immediately")
 boat.rotation = Vector3(0.1,0.5,0.15)
 game._deck_camera()
 check(absf(game.camera.global_rotation.z)<0.001,"Desktop deck camera must retain an upright horizon")
 check(absf(angle_difference(game.camera.global_rotation.y,0.5+game.view_yaw))<0.001,"Head yaw must follow the vessel's heading")
 # A walking finger release must not cancel the other finger's deck look.
 var touch := InputEventScreenTouch.new()
 touch.index = 7
 touch.pressed = true
 touch.position = Vector2(800,300)
 game._unhandled_input(touch)
 touch.index = 8
 touch.pressed = false
 game._input(touch)
 check(game.dragging and game.deck_look_touch==7,"Deck look must keep ownership when another finger releases")
 touch.index = 7
 game._input(touch)
 check(not game.dragging and game.deck_look_touch==-1,"Deck look must release even when the finger ends over UI")
 game.free()
 if failures.is_empty(): print("APEX TRAINER TEST PASS: eye camera, gaze-relative walking, deck carry, inspection return and touch ownership")
 quit(0 if failures.is_empty() else 1)
