extends SceneTree
const Hand = preload("res://scripts/vr_hand_input.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok:
  failures.append(message)
  push_error(message)
func run() -> void:
 var hand := Hand.new()
 check(not hand.grab_wheel(Vector3.ZERO,0.0),"VR grip must be near the wheel rim")
 check(hand.grab_wheel(Vector3(0.72,0,0),0.0),"A tracked hand at the rim must acquire the wheel")
 var torque := hand.wheel_torque(Vector3(0,0.72,0),0.0,0.0)
 check(torque>30 and torque<=129.6,"Hand rotation must request bounded torque rather than impose wheel angle")
 check(hand.wheel_torque(Vector3(-0.72,0,0),-3.0,-10.0)<=129.6,"VR spring and velocity feedback must respect crew effort")
 hand.release()
 check(hand.wheel_torque(Vector3(0.72,0,0),0.0,0.0)==0.0,"Releasing grip must remove torque")
 check(not hand.grab_brace(0,Vector3(3,0,0),Vector3.ZERO),"Distant hands must not acquire brace tails")
 check(hand.grab_brace(0,Vector3.ZERO,Vector3.ZERO),"Hand at the pin must acquire the brace")
 check(hand.brace_pull(Vector3(0,-0.1,0),Vector3.UP,0.1)<-0.9,"Pulling away from the lead must haul")
 check(hand.brace_pull(Vector3.ZERO,Vector3.UP,0.1)>0.9,"Returning toward the lead must ease")
 var game: Node3D = load("res://physics_trial.tscn").instantiate()
 root.add_child(game)
 await physics_frame
 await physics_frame
 game.set_process(false)
 game.get_node("Weather").set_process(false)
 check(not game.vr.active,"Desktop startup must remain non-XR")
 check(not game.vr.enter(),"Headless unsupported VR must fail without disturbing desktop mode")
 game.vr._dispatch("clew_pull",-1.0,0)
 check(game.boat.get_node("Mechanisms").cloth.lines[0].mode==1,"VR rope adapter must address clew sheets")
 game.vr._dispatch("clew_belay",0.0,0)
 check(game.boat.get_node("Mechanisms").cloth.lines[0].mode==0,"VR belay adapter must secure the clew sheet")
 game.vr._dispatch("clew_free",0.0,0)
 check(game.boat.get_node("Mechanisms").cloth.lines[0].mode==2,"VR release adapter must free the clew sheet")
 game._toggle_coop_panel()
 await process_frame
 await process_frame
 await process_frame
 check(game.get_viewport().gui_get_focus_owner()==game.coop_url,"Co-op address must gain focus after panel layout")
 game._toggle_coop_panel()
 game.vr._place_origin()
 check(game.vr.origin.global_position.distance_to(game.player.global_position-Vector3.UP*0.9)<0.001,"XR origin must be at the deck player's feet")
 game._toggle_photo()
 check(not game.coop_toggle.visible and not game.vr_button.visible,"Hide HUD must hide new co-op/VR controls")
 game._toggle_photo()
 check(game.coop_toggle.visible and game.vr_button.visible,"Restore HUD must restore new controls")
 game.free()
 await process_frame
 if failures.is_empty(): print("APEX VR INPUT TEST PASS: reach, bounded wheel torque, brace gestures, release, origin and unsupported-device fallback; headset untested")
 quit(0 if failures.is_empty() else 1)
