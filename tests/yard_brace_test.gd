extends SceneTree
const Brace = preload("res://scripts/yard_brace.gd")
const Surface = preload("res://scripts/sail_pressure_surface.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok:
  failures.append(message)
  push_error(message)
func fixture() -> RefCounted:
 var brace := Brace.new()
 var leads: Array[Vector3] = [Vector3(-0.35,-2.4,9.6),Vector3(0.35,-2.4,9.6)]
 var pins: Array[Vector3] = [Vector3(-2.4,-6.5,9.8),Vector3(2.4,-6.5,9.8)]
 brace.configure(2.75,leads,pins)
 return brace
func advance(brace: RefCounted,seconds: float,torque: float,dt: float = 1.0/60.0) -> void:
 for tick in int(round(seconds/dt)): brace.step(dt,torque)
func run() -> void:
 var brace := fixture()
 brace.angle = 0.12
 var initial: float = brace.stored_energy()
 advance(brace,5.0,0.0)
 check(brace.stored_energy()<initial*0.1,"Unpowered belayed rig must dissipate stored line/yard energy")
 brace = fixture()
 var port_length: float = brace.lines[0].length
 var starboard_length: float = brace.lines[1].length
 brace.set_hand(0,-1.0)
 brace.set_hand(1,1.0)
 advance(brace,2.0,0.0)
 check(brace.lines[0].length<port_length-0.2 and brace.lines[1].length>starboard_length+0.2,"Hauling/easing must change available line lengths")
 check(brace.angle>0.08,"Differential brace length must rotate the yard through tension")
 for line: Dictionary in brace.lines:
  check(line.tension>=0 and absf(line.hand_force)<=brace.hand_force_limit+0.001,"Braces must be tension-only and crew effort bounded")
 brace.belay(0)
 brace.belay(1)
 port_length = brace.lines[0].length
 starboard_length = brace.lines[1].length
 advance(brace,2.0,-120.0)
 check(brace.lines[0].length==port_length and brace.lines[1].length==starboard_length,"Belaying must hold paid-out length under external load")
 for reaction: Dictionary in brace.reactions():
  check((reaction.yard_force+reaction.lead_force+reaction.belay_force).length()<0.001,"Block/yard/pin forces must sum to zero")
  var moment: Vector3 = reaction.yard_point.cross(reaction.yard_force)+reaction.lead_point.cross(reaction.lead_force)+reaction.belay_point.cross(reaction.belay_force)
  check(moment.length()<0.01,"Internal routed-line reactions must not create net assembly torque")
 brace = fixture()
 brace.angle = 0.1
 brace.release(0)
 brace.release(1)
 var release_port: float = brace.lines[0].length
 var release_starboard: float = brace.lines[1].length
 initial = brace.stored_energy()
 advance(brace,2.0,0.0)
 check(brace.stored_energy()<=initial+0.1,"Released lines must not manufacture mechanical energy")
 check(brace.lines[0].length>release_port+0.01 or brace.lines[1].length>release_starboard+0.01,"Released tail must be able to run and unload")
 brace = fixture()
 brace.set_hand(0,0.0)
 brace.set_hand(1,0.0)
 release_starboard = brace.lines[1].length
 advance(brace,1.0,1000.0)
 check(brace.lines[1].length>release_starboard+0.05,"A hand-held line must slip when external load exceeds crew effort")
 check(absf(brace.lines[1].hand_force)<=180.001,"A slipping hand must retain the declared force limit")
 brace = fixture()
 advance(brace,1.0,180.0)
 var held: float = brace.angle
 brace.release(0)
 brace.release(1)
 advance(brace,1.0,180.0)
 check(brace.angle>held+0.1,"Releasing braces must let external load swing the yard")
 brace.cut(0)
 brace.cut(1)
 advance(brace,1.0,0.0)
 check(brace.lines[0].tension==0.0 and brace.lines[1].tension==0.0,"Cut braces must transmit no force")
 var a := fixture()
 var b := fixture()
 advance(a,2.0,150.0)
 advance(b,2.0,150.0,1.0/120.0)
 check(absf(a.angle-b.angle)<0.002,"Loaded brace integration must converge across 60/120 Hz")
 var pressure := Surface.new()
 pressure.build(PackedVector3Array([Vector3(-2,0,0),Vector3(2,0,0),Vector3(2,-2,0),Vector3(-2,0,0),Vector3(2,-2,0),Vector3(-2,-2,0)]))
 var load := pressure.evaluate(Transform3D.IDENTITY,Vector3.ZERO,Vector3(0,0,10),Vector3.ZERO,Vector3.ZERO,1.0,Vector3.ZERO)
 check(absf(load.force.z-392.0)<0.01,"Flat sail pressure must match 0.5 rho Cd V² A")
 var backwind := pressure.evaluate(Transform3D.IDENTITY,Vector3.ZERO,Vector3(0,0,-10),Vector3.ZERO,Vector3.ZERO,1.0,Vector3.ZERO)
 check(backwind.force.is_equal_approx(-load.force),"Backwinding must reverse the pressure load")
 var linear := Vector3(1,0,3)
 var angular := Vector3(0.1,0.2,0.0)
 var relative := Vector3(0,0.3,0)
 var still := pressure.evaluate(Transform3D.IDENTITY,Vector3.ZERO,Vector3.ZERO,linear,angular,1.0,Vector3.ZERO,relative)
 check(still.force.dot(linear)+still.torque.dot(angular)+still.hinge_torque.dot(relative)<=0.001,"Pressure must dissipate motion in still air, including yard rotation")
 var game: Node3D = load("res://physics_trial.tscn").instantiate()
 root.add_child(game)
 game.set_process(false)
 game.get_node("Weather").set_process(false)
 game.get_node("Player").set_physics_process(false)
 var boat: RigidBody3D = game.boat
 boat.ocean = null
 boat.wind_world = Vector3(8,0,10)
 boat.set_force_trial(true)
 var rig: Node3D = boat.get_node("Mechanisms")
 check(rig.loaded_yard!=null and rig.loaded_sail!=null and rig.brace_lines.size()==2,"Existing lower foreyard/sail must bind to two rendered brace routes")
 for frame in 30: await physics_frame
 check(absf(boat.rig_report.brace_torque)>0.1,"Cambered sail pressure must produce a measured yard hinge load")
 var pose_angle: float = rig.brace.angle
 game._brace_pull(-1.0)
 rig.brace.set_hand(1,1.0)
 for frame in 120: await physics_frame
 game._brace_stop()
 check(rig.brace.angle>pose_angle+0.05,"Real force trial must turn its original yard by hauling/easing")
 check(absf(rig.loaded_yard.rotation.y-rig.brace.angle)<0.001,"Visible yard must follow solved state")
 var angle: float = rig.brace.angle
 boat.sheet_angle = -1.5
 rig._process(0.2)
 check(absf(rig.loaded_yard.rotation.y-angle)<0.001,"Prototype trim must not impose the loaded yard's angle")
 game._brace_action("BELAY")
 check(rig.brace.lines[0].mode==Brace.Hold.BELAYED,"Trainer belay button must secure the selected line")
 game._brace_action("PORT BRACE")
 game._brace_action("FREE")
 check(rig.brace.lines[1].mode==Brace.Hold.FREE,"Selection and free button must address the opposite brace")
 game._brace_action("CUT BRACE")
 rig._update_braces()
 check(not rig.brace_lines[1].visible and rig.brace.lines[1].tension==0.0,"Cut brace must remove its rendered connection and load")
 print("BRACE MODEL: angle=",rad_to_deg(angle)," deg wind_hinge=",boat.rig_report.brace_torque," Nm")
 check(boat.global_position.is_finite() and boat.angular_velocity.is_finite(),"Coupled hull/rig integration must remain finite")
 game.free()
 if failures.is_empty(): print("APEX YARD BRACE TEST PASS: pressure, hauling/easing, effort, belaying, release, cutting, energy, reactions and scene integration")
 quit(0 if failures.is_empty() else 1)
