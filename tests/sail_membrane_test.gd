extends SceneTree
const Membrane = preload("res://scripts/sail_membrane.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok:
  failures.append(message)
  push_error(message)
func fixture() -> RefCounted:
 var cloth := Membrane.new()
 var leads: Array[Vector3] = [Vector3(-2.6,-4,3),Vector3(2.6,-4,3)]
 var pins: Array[Vector3] = [Vector3(-2.4,-4.5,3.3),Vector3(2.4,-4.5,3.3)]
 cloth.configure(AABB(Vector3(-2.75,-2.8,0),Vector3(5.5,2.8,0.1)),0,Transform3D.IDENTITY,leads,pins)
 return cloth
func advance(cloth: RefCounted,seconds: float,wind: Vector3,dt: float = 1.0/60.0) -> void:
 for tick in int(round(seconds/dt)): cloth.step(dt,Transform3D.IDENTITY,wind,1.0,Vector3.ZERO,Vector3.ZERO)
func run() -> void:
 var cloth := fixture()
 check(cloth.points.size()==35 and cloth.triangles.size()==144,"Membrane must retain its documented resolution")
 check(cloth.canvas_mass>8 and cloth.canvas_mass<10,"Canvas mass must derive from area and 0.6 kg/m2 cloth")
 advance(cloth,2,Vector3(0,0,10))
 var center: int = 2*(Membrane.COLUMNS+1)+3
 var loaded: Vector3 = cloth.points[center]
 print("CLOTH LOADED: center=",loaded," mass=",cloth.canvas_mass," kg")
 check(loaded.z>cloth.rest[center].z+0.05,"Actual wind pressure must billow the membrane")
 for i in Membrane.COLUMNS+1:
  check(cloth.points[i].distance_to(cloth.rest[i])<0.00001,"Head must stay fixed to the yard")
 for p: Vector3 in cloth.points: check(p.is_finite(),"Particles must remain finite")
 for line: Dictionary in cloth.lines: check(line.tension>=0,"Sheets must not push")
 var length: float = cloth.lines[0].length
 cloth.belay(0)
 advance(cloth,0.5,Vector3(0,0,10))
 check(cloth.lines[0].length==length,"Belay must hold rope length under load")
 cloth.set_hand(0,-1)
 cloth.set_hand(1,1)
 advance(cloth,1,Vector3(0,0,3))
 check(cloth.lines[0].length<length-0.05,"Hand hauling must shorten the sheet")
 check(absf(cloth.lines[0].hand_force)<=180.001,"Hand effort must remain bounded")
 cloth.cut(0)
 cloth.cut(1)
 advance(cloth,1,Vector3(0,0,-10))
 check(cloth.lines[0].tension==0 and cloth.lines[1].tension==0,"Cut sheets must transmit zero tension")
 check(cloth.points[center].z<loaded.z-0.1,"Backwind and released clews must change the membrane shape")
 var restrained := fixture()
 advance(restrained,3,Vector3(0,0,-10))
 check(restrained.lines[0].tension>20 and restrained.lines[1].tension>20,"Belayed sheets must carry real clew load in the loaded wind direction")
 var clew: Vector3 = restrained.points[28]
 restrained.release(0)
 restrained.release(1)
 advance(restrained,1,Vector3(0,0,-10))
 check(restrained.points[28].distance_to(clew)>0.5,"Freeing loaded sheets must change clew position, not just a control flag")
 check(restrained.lines[0].length>length+0.2,"Free tail must pay out under clew load")
 var slipping := fixture()
 slipping.hand_force_limit = 20.0
 slipping.set_hand(0,0)
 slipping.set_hand(1,0)
 var held_length: float = slipping.lines[0].length
 advance(slipping,1,Vector3(0,0,-15))
 check(slipping.lines[0].length>held_length+0.05,"Overloaded hand-held sheets must slip")
 check(absf(slipping.lines[0].hand_force)<=20.001,"Slip must preserve finite declared effort")
 var unpowered := fixture()
 unpowered.gravity = Vector3.ZERO
 for i in unpowered.velocities.size():
  if unpowered.masses[i]>0: unpowered.velocities[i] = Vector3(0,0,1)
 advance(unpowered,3,Vector3.ZERO)
 var kinetic := 0.0
 for i in unpowered.velocities.size(): kinetic += 0.5*unpowered.masses[i]*unpowered.velocities[i].length_squared()
 check(kinetic<0.1,"Unpowered motion must decay rather than gain energy")
 var a := fixture()
 var b := fixture()
 advance(a,1,Vector3(0,0,8))
 advance(b,1,Vector3(0,0,8),1.0/120.0)
 var error := 0.0
 for i in a.points.size(): error = maxf(error,a.points[i].distance_to(b.points[i]))
 print("CLOTH RATE ERROR ",error)
 check(error<0.03,"60/120 Hz cloth positions must agree within 3 cm with fixed supports")
 var still := fixture()
 still.gravity = Vector3.ZERO
 var pressure: PackedVector3Array = still.pressure(Vector3(0,0,10))
 var reverse: PackedVector3Array = still.pressure(Vector3(0,0,-10))
 var total := Vector3.ZERO
 for i in pressure.size():
  total += pressure[i]
  check(pressure[i].is_equal_approx(-reverse[i]),"Backwind must reverse each panel's pressure")
 check(total.z>600 and total.z<850,"Pressure magnitude must match the approximate 14 m2 projected area")
 var before: Dictionary = still.momentum()
 var dt := 1.0/240.0
 var load: Dictionary = still.step(dt,Transform3D.IDENTITY,Vector3(0,0,10),1,Vector3.ZERO,Vector3.ZERO)
 var after: Dictionary = still.momentum()
 check((load.force+(after.linear-before.linear)/dt-total).length()<0.01,"Hull support plus cloth momentum change must equal external wind load")
 var wind_moment := Vector3.ZERO
 for i in pressure.size(): wind_moment += still.rest[i].cross(pressure[i])
 check((load.torque+(after.angular-before.angular)/dt-wind_moment).length()<0.01,"Hull support moment plus cloth angular momentum change must equal wind moment")
 # Snapshot coordinates must stay attached to each client's interpolated hull pose.
 var shifted := Transform3D(Basis(Vector3.UP,0.3),Vector3(4,2,7))
 var saved: Dictionary = a.snapshot(Transform3D.IDENTITY)
 b.receive_snapshot(saved,shifted)
 for i in b.points.size(): check(b.points[i].distance_to(shifted*a.points[i])<0.0001,"Replicated cloth geometry must follow the receiving hull pose")
 var carried := fixture()
 carried.gravity = Vector3.ZERO
 var drift := Vector3(2,0,-1)
 for i in carried.velocities.size(): carried.velocities[i] = drift
 for tick in 60:
  var support := Transform3D(Basis.IDENTITY,drift*float(tick+1)/60.0)
  carried.step(1.0/60.0,support,drift,1,Vector3.ZERO,support.origin,support)
 var drift_error := 0.0
 for i in carried.points.size(): drift_error = maxf(drift_error,carried.points[i].distance_to(carried.rest[i]+drift))
 check(drift_error<0.003,"Uniform ship/air translation must preserve cloth shape; damping must act relative to its support")
 var moving := fixture()
 for tick in 120:
  var support := Transform3D(Basis(Vector3.UP,float(tick)*0.002),Vector3(float(tick)*0.002,0,0))
  moving.step(1.0/60.0,support,Vector3(12,0,-25),1,Vector3.ZERO,support.origin,support)
  for i in Membrane.COLUMNS+1:
   check(moving.points[i].distance_to(support*moving.rest[i])<0.0001,"Moving yard must carry every head attachment")
  for point: Vector3 in moving.points: check(point.is_finite(),"Gusts and moving anchors must remain finite")
 # Reusable instances own independent state.
 check(a.lines[0].mode==Membrane.Hold.BELAYED,"Separate cloth instances must not share line state")
 var game: Node3D = load("res://physics_trial.tscn").instantiate()
 root.add_child(game)
 game.set_process(false)
 game.get_node("Weather").set_process(false)
 game.player.set_physics_process(false)
 game.boat.ocean = null
 game.boat.wind_world = Vector3(0,0,10)
 game.boat.set_force_trial(true)
 for frame in 120: await physics_frame
 var rig: Node3D = game.boat.get_node("Mechanisms")
 rig._update_clew_sheets()
 check(rig.cloth_active and rig.clew_lines.size()==2,"Force trial must activate two rendered clew sheets")
 check(rig.loaded_sail.mesh!=rig.resting_sail_mesh,"Force trial must display solved cloth vertices")
 check(game.boat.rig_pressure.last_sail_loads.size()==8,"Dynamic sail must replace one pressure panel, preserving eight sail loads")
 game._toggle_rig_control()
 check(game.clew_selected,"Trainer must select the clew-sheet circuit")
 game._brace_pull(-1.0)
 check(rig.cloth.lines[0].mode==Membrane.Hold.HAND and rig.cloth.lines[0].pull==-1,"Trainer hauling must address the selected clew sheet")
 game._brace_action("BELAY")
 check(rig.cloth.lines[0].mode==Membrane.Hold.BELAYED,"Trainer belay must secure the clew sheet")
 game._brace_action("CUT BRACE")
 check(rig.cloth.lines[0].mode==Membrane.Hold.CUT,"Trainer cut must address the selected circuit")
 check(game.boat.global_position.is_finite(),"Coupled cloth/yard/hull must remain finite")
 game.boat.set_force_trial(false)
 check(rig.loaded_sail.mesh==rig.resting_sail_mesh,"Prototype mode must restore the existing sail")
 game.free()
 if failures.is_empty(): print("APEX SAIL MEMBRANE TEST PASS: head attachment, wind, sheets, effort, cuts, backwind, timestep convergence, load accounting and scene")
 quit(0 if failures.is_empty() else 1)
