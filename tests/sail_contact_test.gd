extends SceneTree
const Membrane = preload("res://scripts/sail_membrane.gd")
const Contact = preload("res://scripts/sail_contact.gd")
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
 for tick in int(round(seconds/dt)): cloth.step(dt,Transform3D.IDENTITY,wind,1,Vector3.ZERO,Vector3.ZERO)
func kinetic(cloth: RefCounted) -> float:
 var energy := 0.0
 for i in cloth.points.size(): energy += 0.5*cloth.masses[i]*cloth.velocities[i].length_squared()
 return energy
func depth(cloth: RefCounted) -> float:
 var total := 0.0
 for i in range(Membrane.COLUMNS+1,cloth.points.size()): total += cloth.points[i].z
 return total/(cloth.points.size()-Membrane.COLUMNS-1)
func clearance(cloth: RefCounted,capsule: Dictionary) -> float:
 var minimum := INF
 for t in range(0,cloth.triangles.size(),3):
  var distance: float = Contact.nearest(cloth.points[cloth.triangles[t]],cloth.points[cloth.triangles[t+1]],cloth.points[cloth.triangles[t+2]],capsule.a,capsule.b).distance
  minimum = minf(minimum,distance-capsule.radius-cloth.contact_thickness)
 return minimum
func run() -> void:
 var degenerate := Contact.closest_triangle(Vector3(0.5,1,0),Vector3.ZERO,Vector3.RIGHT,Vector3.RIGHT*2)
 check(degenerate.is_finite() and absf(degenerate.y+2*degenerate.z-0.5)<0.00001,"Collapsed panels must use their nearest edge without NaNs")
 # A spar can pass through a panel interior without touching any vertex.
 var points := PackedVector3Array([Vector3(-1,0,0),Vector3(1,0,0),Vector3(0,1.4,0)])
 var old := points.duplicate()
 for i in old.size(): old[i].z = -0.3
 var masses := PackedFloat64Array([1,1,1])
 var triangles := PackedInt32Array([0,1,2])
 var capsule := {"a":Vector3(0,0.5,-0.1),"b":Vector3(0,0.5,0.1),"radius":0.15}
 var envelopes: Array[Dictionary] = [capsule]
 var hit := Contact.nearest(points[0],points[1],points[2],capsule.a,capsule.b)
 check(hit.distance<0.00001,"Segment piercing a triangle interior must be detected")
 for p in points: check(p.distance_to(Vector3(0,0.5,0))>0.5,"Fixture vertices must be clear, exercising interior contact")
 for iteration in 12: Contact.solve(points,masses,triangles,old,envelopes,0.012,1.0/240,Vector3.ZERO)
 hit = Contact.nearest(points[0],points[1],points[2],capsule.a,capsule.b)
 check(hit.distance>=0.1619,"Triangle interior must be projected clear of the capsule")
 check(points[2].z<0,"Ambiguous piercing must retain the preceding side")
 # Flat rest constraints cannot encode a permanent wind-inflated shape.
 var cloth := fixture()
 for p: Vector3 in cloth.rest: check(absf(p.z)<0.000001,"Rest pattern must be planar")
 cloth.cut(0)
 cloth.cut(1)
 advance(cloth,4,Vector3.ZERO)
 check(absf(depth(cloth))<0.00001 and kinetic(cloth)<0.01,"Gravity-on calm canvas must settle without wind billow")
 advance(cloth,3,Vector3(0,0,10))
 var gust := depth(cloth)
 check(gust>0.2,"Wind must produce billow from the flat cut pattern")
 advance(cloth,12,Vector3.ZERO)
 var lull := depth(cloth)
 check(absf(lull)<0.12 and kinetic(cloth)<0.01,"A lull must lose billow and settle with gravity still on")
 advance(cloth,3,Vector3(0,0,-10))
 var backwind := depth(cloth)
 check(backwind< -0.2,"Backwind must fill the opposite side")
 print("SAIL WIND CYCLE ",JSON.stringify({"gust_depth_m":gust,"lull_depth_m":lull,"backwind_depth_m":backwind}))
 # A loaded membrane must not pass through the middle of a spar between vertices.
 var spar := {"a":Vector3(0,-3.2,0.6),"b":Vector3(0,-0.4,0.6),"radius":0.18}
 var with_spar := fixture()
 var spar_list: Array[Dictionary] = [spar]
 with_spar.set_capsules(spar_list)
 var contacts := 0
 var worst := 0.0
 for tick in 180:
  var load: Dictionary = with_spar.step(1.0/60,Transform3D.IDENTITY,Vector3(0,0,10),1,Vector3.ZERO,Vector3.ZERO)
  contacts += load.contact_constraints
  worst = minf(worst,clearance(with_spar,spar))
  for p: Vector3 in with_spar.points: check(p.is_finite(),"Spar contact must remain finite")
 print("SAIL SPAR CONTACT ",JSON.stringify({"constraints":contacts,"worst_clearance_m":worst,"settled_clearance_m":clearance(with_spar,spar)}))
 check(contacts>0,"Loaded sail must actually exercise contact")
 check(worst> -0.003,"Panel-to-spar penetration must stay below 3 mm in the specified load fixture")
 # Contact impulse must remain in the one hull support resultant, not added twice.
 var before: Dictionary = with_spar.momentum()
 var forces: PackedVector3Array = with_spar.pressure(Vector3(0,0,10),1,1.0/240)
 var external := Vector3.ZERO
 var moment := Vector3.ZERO
 for i in forces.size():
  var f: Vector3 = forces[i]+with_spar.gravity*with_spar.masses[i]
  external += f
  moment += with_spar.points[i].cross(f)
 var dt := 1.0/240
 var load: Dictionary = with_spar.step(dt,Transform3D.IDENTITY,Vector3(0,0,10),1,Vector3.ZERO,Vector3.ZERO)
 var after: Dictionary = with_spar.momentum()
 check((load.force+(after.linear-before.linear)/dt-external).length()<0.02,"Contact load accounting must preserve the total linear balance")
 check((load.torque+(after.angular-before.angular)/dt-moment).length()<0.02,"Contact load accounting must preserve the total angular balance")
 advance(with_spar,12,Vector3.ZERO)
 check(kinetic(with_spar)<0.01,"After contact loading, gravity-on motion must settle in a lull")
 # The same contact fixture must converge under different outer tick rates.
 var a := fixture()
 var b := fixture()
 a.set_capsules(spar_list)
 b.set_capsules(spar_list)
 advance(a,1,Vector3(0,0,10))
 advance(b,1,Vector3(0,0,10),1.0/120)
 var error := 0.0
 for i in a.points.size(): error = maxf(error,a.points[i].distance_to(b.points[i]))
 check(error<0.03,"Contact at 60/120 Hz must agree within 3 cm")
 # Scene adapter: geometry-derived spar proxies, fitted clear head and moving hull/yard.
 var game: Node3D = load("res://physics_trial.tscn").instantiate()
 root.add_child(game)
 game.set_process(false)
 game.boat.set_physics_process(false)
 var rig: Node3D = game.boat.get_node("Mechanisms")
 rig.set_process(false)
 var body_pose: Transform3D = game.boat.global_transform
 rig.step_cloth(0,body_pose,Vector3.ZERO,1,body_pose.origin,true)
 var scene_capsules: Array[Dictionary] = rig._cloth_spar_envelopes()
 check(scene_capsules.size()==11,"Fore cloth must bind all three actual masts and eight actual yards")
 rig.cloth.set_capsules(scene_capsules)
 var world_capsules: Array[Dictionary] = rig.cloth._world_capsules()
 for envelope: Dictionary in world_capsules:
  check(clearance(rig.cloth,envelope)> -0.003,"Initial cloth/head must be clear of its measured spar envelopes")
 var local_head: Vector3 = game.boat.to_local(rig.cloth.points[3])
 check(local_head.z< -7.0,"Fore head must attach ahead of relocated yard, clear of the mast")
 var initial_yard_position: Vector3 = rig.loaded_yard.position
 for tick in 120:
  rig.loaded_yard.rotation.y = sin(float(tick)/60.0)*0.35
  var moving_pose := Transform3D(Basis(Vector3.UP,float(tick)*0.002)*body_pose.basis,body_pose.origin+Vector3(float(tick)*0.003,0,0))
  rig.step_cloth(1.0/60,moving_pose,moving_pose.basis*Vector3(0,0,10),1,moving_pose.origin,false)
  for p: Vector3 in rig.cloth.points: check(p.is_finite(),"Moving ship/yard contact must remain finite")
 check(rig.loaded_yard.position==initial_yard_position,"Spar clearance fix must retain the original brace pivot")
 rig.set_cloth_active(true)
 rig._update_clew_sheets()
 var rendered: PackedVector3Array = rig.loaded_sail.mesh.get_faces()
 for i in rig.cloth.triangles.size():
  check((rig.loaded_sail.global_transform*rendered[i]).distance_to(rig.cloth.points[rig.cloth.triangles[i]])<0.0001,"Rendered cloth must use the contact-solved particles")
 game.queue_free()
 await process_frame
 await process_frame
 if failures.is_empty(): print("APEX SAIL CONTACT TEST PASS: flat cut, gravity calm/gust/lull/backwind, triangle interior contact, clearance, momentum and timestep")
 quit(0 if failures.is_empty() else 1)
