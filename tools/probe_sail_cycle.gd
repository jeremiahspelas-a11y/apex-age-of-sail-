extends SceneTree
## Reproducible isolated fixture. Diagnostic evidence, not calibrated fabric acceptance.
const Membrane = preload("res://scripts/sail_membrane.gd")
const Contact = preload("res://scripts/sail_contact.gd")
func _initialize() -> void:
 var cloth := Membrane.new()
 var leads: Array[Vector3] = [Vector3(-2.6,-4,3),Vector3(2.6,-4,3)]
 var pins: Array[Vector3] = [Vector3(-2.4,-4.5,3.3),Vector3(2.4,-4.5,3.3)]
 cloth.configure(AABB(Vector3(-2.75,-2.8,0),Vector3(5.5,2.8,0.1)),0,Transform3D.IDENTITY,leads,pins)
 var capsules: Array[Dictionary] = [{"a":Vector3(0,-3.2,0.6),"b":Vector3(0,-0.4,0.6),"radius":0.18}]
 cloth.set_capsules(capsules)
 cloth.release(0)
 cloth.release(1)
 var trace: Array[Dictionary] = []
 var snapshots: Array[Dictionary] = []
 var elapsed := 0.0
 var previous_wind := 0.0
 for phase: Dictionary in [{"name":"calm","seconds":4,"wind":0.0},{"name":"gust","seconds":5,"wind":8.0},{"name":"lull","seconds":12,"wind":0.0},{"name":"backwind","seconds":4,"wind":-8.0},{"name":"release","seconds":2,"wind":-8.0}]:
  if phase.name=="backwind":
   cloth.belay(0)
   cloth.belay(1)
  if phase.name=="release":
   cloth.release(0)
   cloth.release(1)
  for tick in phase.seconds*60:
   var local_time := float(tick+1)/60
   var wind := lerpf(previous_wind,phase.wind,smoothstep(0,1,local_time))
   var report: Dictionary = cloth.step(1.0/60,Transform3D.IDENTITY,Vector3(0,0,wind),1,Vector3.ZERO,Vector3.ZERO)
   elapsed += 1.0/60
   if tick%6!=5: continue
   var depth := 0.0
   var kinetic := 0.0
   for i in cloth.points.size():
    if cloth.masses[i]>0: depth += cloth.points[i].z
    kinetic += 0.5*cloth.masses[i]*cloth.velocities[i].length_squared()
   var gap := INF
   for t in range(0,cloth.triangles.size(),3):
    var hit := Contact.nearest(cloth.points[cloth.triangles[t]],cloth.points[cloth.triangles[t+1]],cloth.points[cloth.triangles[t+2]],capsules[0].a,capsules[0].b)
    gap = minf(gap,hit.distance-capsules[0].radius-cloth.contact_thickness)
   trace.append({"seconds":elapsed,"phase":phase.name,"wind_z_mps":wind,"mean_free_depth_m":depth/28,"kinetic_j":kinetic,"wind_force_z_n":report.wind_force.z,"support_force_n":vector(report.force),"support_torque_nm":vector(report.torque),"sheet_lengths_m":[cloth.lines[0].length,cloth.lines[1].length],"sheet_tensions_n":[cloth.lines[0].tension,cloth.lines[1].tension],"spar_gap_m":gap,"contact_constraints":report.contact_constraints})
  var points: Array = []
  for p in cloth.points: points.append(vector(p))
  snapshots.append({"phase":phase.name,"seconds":elapsed,"points_m":points})
  previous_wind = phase.wind
 var indices: Array = []
 for index in cloth.triangles: indices.append(index)
 var data := {"scope":"Isolated provisional 35-node cloth, fixed head, gravity, normal-pressure drag, one frictionless analytic spar. Not ship handling, self-contact, folds, luffing or fabric/reference acceptance.","engine":Engine.get_version_info().string,"source_sha256":{"membrane":FileAccess.get_sha256("res://scripts/sail_membrane.gd"),"contact":FileAccess.get_sha256("res://scripts/sail_contact.gd")},"dt_s":1.0/60,"gravity_mps2":[0,-9.81,0],"canvas_mass_kg":cloth.canvas_mass,"triangles":indices,"capsule":{"a_m":vector(capsules[0].a),"b_m":vector(capsules[0].b),"radius_m":0.18},"snapshots":snapshots,"trace":trace}
 var args := OS.get_cmdline_user_args()
 var destination := args[0] if not args.is_empty() else "res://docs/realism/fore-sail-cycle.json"
 var file := FileAccess.open(destination,FileAccess.WRITE)
 if file==null:
  push_error("Cannot save sail cycle: "+destination)
  quit(1)
  return
 file.store_string(JSON.stringify(data," ")+"\n")
 print("APEX SAIL CYCLE SAVED ",destination," samples=",trace.size())
 quit()
func vector(v: Vector3) -> Array:
 return [v.x,v.y,v.z]
