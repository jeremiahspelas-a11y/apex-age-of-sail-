extends Node3D
signal steering_connection_changed(connected: bool)
## Articulate the imported parts at measured sockets; no duplicate solid proxy fittings.
const Refit = preload("res://scripts/ship_refit.gd")
const SailCloth = preload("res://scripts/sail_cloth.gd")
@export var use_whipstaff := false # wheel preferred for the historically inspired trainer
@onready var vessel: RigidBody3D = get_parent() as RigidBody3D
var rudder: Node3D
var wheel: Node3D
var yards: Array[Node3D] = []
var doors: Array[Node3D] = []
var hatches: Array[Node3D] = []
var door_open := false
var hatch_open := false
var wheel_angle := 0.0
var wheel_velocity := 0.0
var wheel_inertia := 20.0 # provisional kg m2
var drum_radius := 0.18
var wheel_handle_radius := 0.72
var wheel_stop := 5.0
var steering_line_stiffness := 8000.0 # effective N/m, including entire line route
var steering_line_damping := 160.0
var steering_line_pretension := 120.0
var port_line_tension := 120.0
var starboard_line_tension := 120.0
var steering_lines: Array[MeshInstance3D] = []
var _line_clock := 0.0
var direct_helm_control := false
var direct_helm_torque := 0.0
var staff_command := 0.0
var rudder_velocity := 0.0
var rudder_inertia := 200.0 # provisional blade+tiller inertia, kg m2
var crew_hand_force := 0.0
var last_water_hinge_torque := 0.0
var actual_rudder_angle := 0.0
var steering_rope_intact := true
var whipstaff: Node3D
var staff_mesh: MeshInstance3D
var rowle: MeshInstance3D
var historical_rudder_limit := deg_to_rad(32.0) # provisional mechanical stops; 8 degrees in optional whipstaff mode
var original_rudder: MeshInstance3D
var original_wheel: MeshInstance3D
var rig_sails: Array[MeshInstance3D] = []
var rig_yards: Array[MeshInstance3D] = []

func toggle_steering_rope() -> void:
 steering_rope_intact = not steering_rope_intact
 steering_connection_changed.emit(steering_rope_intact)

func rudder_angle_for_physics() -> float:
 return actual_rudder_angle

func _ready() -> void:
 var imported := vessel.get_node_or_null("HullVisual")
 if imported == null:
  push_error("SHIP MECHANISMS: original ship missing")
  return
 _bind_rudder(imported)
 _bind_helm(imported)
 if use_whipstaff: historical_rudder_limit = deg_to_rad(8.0)
 _bind_period_steering(imported)
 _bind_steering_route()
 _bind_rig(imported)
 _bind_openings(imported)
 print("APEX original rig controls: rudder=",original_rudder != null," wheel=",original_wheel != null)
 print("APEX original sail-yard pairs found: ",rig_yards.size())

func _pivot(label: String, socket: Vector3, parts: Array[MeshInstance3D]) -> Node3D:
 var pivot := Node3D.new()
 pivot.name = label
 pivot.position = socket
 add_child(pivot)
 pivot.set_meta("rest_socket",socket)
 for part in parts:
  part.reparent(pivot,true)
 return pivot

func _reshape_box(part: MeshInstance3D, target: AABB) -> void:
 var bounds := part.mesh.get_aabb()
 var arrays := part.mesh.surface_get_arrays(0)
 var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 for i in vertices.size():
  var fraction := (vertices[i]-bounds.position)/bounds.size
  vertices[i] = target.position + fraction*target.size
 arrays[Mesh.ARRAY_VERTEX] = vertices
 var result := ArrayMesh.new()
 result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 part.mesh = result

func _bind_rudder(root: Node) -> void:
 original_rudder = Refit.find_mesh(root,"rudder_blade")
 var parts: Array[MeshInstance3D] = []
 if original_rudder != null:
  parts.append(original_rudder)
  for duplicate in ["V9_rudder_blade","legacy_054_Rudder blade"]:
   var old := Refit.find_mesh(root,duplicate)
   if old != null: old.visible = false
 var tiller := Refit.find_mesh(root,"rudder_stock")
 if tiller != null:
  # The old horizontal tiller extended 1.8 m behind its own stern hinge.
  var bounds := tiller.mesh.get_aabb()
  _reshape_box(tiller,AABB(bounds.position,Vector3(bounds.size.x,bounds.size.y,13.15-bounds.position.z)))
  parts.append(tiller)
 rudder = _pivot("RudderControlPivot",Vector3(0,0.15,13.15),parts)

func _bind_helm(root: Node) -> void:
 var parts: Array[MeshInstance3D] = []
 for part in root.find_children("*","MeshInstance3D",true,false):
  var n := str(part.name)
  if n in ["v7_helm_wheel","v7_helm"] or n.begins_with("v7_wheel_spoke_") or n == "V9_helm_wheel_hub":
   parts.append(part as MeshInstance3D)
 original_wheel = Refit.find_mesh(root,"V9_helm_wheel_hub")
 wheel = _pivot("HelmControlPivot",Vector3(0,2.95,10.8),parts)
 if not use_whipstaff:
  # Clear the original mizzenmast and raise the rim above the quarterdeck.
  wheel.position += Vector3(0,0.25,0.65)
  wheel.set_meta("rest_socket",wheel.position)
 var pedestal := Refit.find_mesh(root,"v8_helm_pedestal")
 if pedestal != null:
  _reshape_box(pedestal,AABB(Vector3(-0.21,Refit.QUARTER_TOP,wheel.position.z-0.26),Vector3(0.42,wheel.position.y-Refit.QUARTER_TOP,0.52)))

func _bind_rig(root: Node) -> void:
 var mast_z := [-6.5,3.1,10.8]
 for mast in range(1,4):
  for level in range(1,4):
   var suffix := str(mast)+"_"+str(level)
   var yard := _find_suffix(root,"Yard "+suffix)
   var sail := _find_suffix(root,"Square sail "+suffix)
   if yard == null or sail == null: continue
   var head := Vector3(0,yard.mesh.get_aabb().get_center().y,mast_z[mast-1])
   var old_bounds := sail.mesh.get_aabb()
   sail.set_meta("original_sail_bounds",old_bounds)
   sail.mesh = SailCloth.build(old_bounds,head.z)
   rig_yards.append(yard)
   rig_sails.append(sail)
   yards.append(_pivot("YardRig_"+suffix,head,[yard,sail]))

func _bind_openings(root: Node) -> void:
 var door_parts: Array[MeshInstance3D] = []
 for part in root.find_children("*","MeshInstance3D",true,false):
  if str(part.name).begins_with("V9_hinged_door_"): door_parts.append(part as MeshInstance3D)
 door_parts.sort_custom(func(a: MeshInstance3D,b: MeshInstance3D) -> bool: return a.mesh.get_aabb().get_center().z < b.mesh.get_aabb().get_center().z)
 for i in door_parts.size():
  var part := door_parts[i]
  var z: float = [-1.4,5.5][mini(i,1)]
  # Match the actual bulkhead door frames instead of leaving leaves floating in the hold.
  _reshape_box(part,AABB(Vector3(-0.64,-1.05,z-0.0425),Vector3(1.28,1.69,0.085)))
  var bounds := part.mesh.get_aabb()
  var pivot := _pivot("DoorHinge_%d"%i,Vector3(bounds.position.x,bounds.get_center().y,z),[part])
  _moving_collision(pivot,part)
  doors.append(pivot)
 for i in range(2):
  var hatch := Refit.find_mesh(root,"V9_hatch_"+str(i))
  if hatch == null: continue
  var bounds := hatch.mesh.get_aabb()
  var hinge := Vector3(0,bounds.get_center().y,bounds.end.z)
  var pivot := _pivot("HatchHinge_%d"%i,hinge,[hatch])
  _moving_collision(pivot,hatch)
  hatches.append(pivot)

func _moving_collision(pivot: Node3D, part: MeshInstance3D) -> void:
 var body := AnimatableBody3D.new()
 body.collision_layer = 1
 body.collision_mask = 2
 body.sync_to_physics = false
 pivot.add_child(body)
 body.add_collision_exception_with(vessel)
 vessel.add_collision_exception_with(body)
 var collision := CollisionShape3D.new()
 var shape := BoxShape3D.new()
 var bounds := part.mesh.get_aabb()
 shape.size = bounds.size
 collision.shape = shape
 collision.transform = part.transform*Transform3D(Basis.IDENTITY,bounds.get_center())
 body.add_child(collision)

func _find_suffix(root: Node, ending: String) -> MeshInstance3D:
 for part in root.find_children("*","MeshInstance3D",true,false):
  if str(part.name).ends_with(ending): return part as MeshInstance3D
 return null

func _process(delta: float) -> void:
 if vessel == null or rudder == null or wheel == null: return
 var command := clampf(float(vessel.get("rudder_input")),-1.0,1.0)
 if not vessel.force_trial:
  wheel_angle = move_toward(wheel_angle,command*wheel_stop,delta*1.5)
  var demanded := command*historical_rudder_limit if use_whipstaff else asin(clampf(wheel_angle*drum_radius/1.70,-1.0,1.0))
  if steering_rope_intact: actual_rudder_angle = clampf(demanded,-historical_rudder_limit,historical_rudder_limit)
  rudder_velocity = 0.0
  wheel_velocity = 0.0
 rudder.rotation.y = actual_rudder_angle
 wheel.rotation.z = wheel_angle
 _update_whipstaff()
 _line_clock += delta
 if _line_clock >= 0.1:
  _line_clock = 0.0
  _update_steering_route()
 var trim := clampf(float(vessel.get("sheet_angle")),-1.5,1.5)
 for yard in yards:
  yard.rotation.y = lerp_angle(yard.rotation.y,trim*0.55,minf(1.0,delta*1.6))
 for door in doors:
  door.rotation.y = lerp_angle(door.rotation.y,deg_to_rad(85.0) if door_open else 0.0,minf(1.0,delta*3.0))
 for hatch in hatches:
  hatch.rotation.x = lerp_angle(hatch.rotation.x,deg_to_rad(75.0) if hatch_open else 0.0,minf(1.0,delta*3.0))

func toggle_doors() -> void: door_open = not door_open
func toggle_hatches() -> void: hatch_open = not hatch_open

func _bind_period_steering(root: Node) -> void:
 # RMG c.1703 wheel evidence postdates our 1670–1690 baseline. Preserve the source
 # assembly for inspection but use a provisional whipstaff/tiller arrangement.
 wheel.visible = not use_whipstaff
 var pedestal := Refit.find_mesh(root,"v8_helm_pedestal")
 if pedestal != null: pedestal.visible = not use_whipstaff
 whipstaff = Node3D.new()
 whipstaff.name = "WhipstaffPivot"
 whipstaff.position = Vector3(0,1.30,11.45)
 add_child(whipstaff)
 whipstaff.visible = use_whipstaff
 staff_mesh = MeshInstance3D.new()
 staff_mesh.name = "WoodenWhipstaff"
 var pole := CylinderMesh.new()
 pole.top_radius = 0.035
 pole.bottom_radius = 0.045
 pole.height = 3.50
 pole.radial_segments = 10
 staff_mesh.mesh = pole
 staff_mesh.position.y = 0.60
 whipstaff.add_child(staff_mesh)
 rowle = MeshInstance3D.new()
 rowle.name = "WoodenWhipstaffRowle"
 var bearing := CylinderMesh.new()
 bearing.top_radius = 0.13
 bearing.bottom_radius = 0.13
 bearing.height = 0.50
 bearing.radial_segments = 12
 rowle.mesh = bearing
 rowle.rotation.x = PI*0.5
 rowle.position = whipstaff.position
 add_child(rowle)
 rowle.visible = use_whipstaff
 for side in [-1.0,1.0]:
  var support := MeshInstance3D.new()
  support.name = "WhipstaffBearingSupport"
  var beam := BoxMesh.new()
  beam.size = Vector3(0.22,0.35,0.16)
  support.mesh = beam
  support.position = Vector3(side*0.24,1.23,11.45)
  add_child(support)
  support.visible = use_whipstaff

func _update_whipstaff() -> void:
 if whipstaff == null: return
 var tip := rudder.position + Basis(Vector3.UP,actual_rudder_angle)*Vector3(0,0,-1.70)
 var depth := whipstaff.position.y-tip.y
 whipstaff.rotation.z = atan2(tip.x,depth)
 # Slide the staff through its rowle so the lower tip remains on the horizontal tiller.
 whipstaff.position.z = tip.z
 rowle.position.z = tip.z
 var lower_length := Vector2(tip.x,depth).length()
 var cylinder := staff_mesh.mesh as CylinderMesh
 cylinder.height = 2.35+lower_length
 staff_mesh.position.y = (2.35-lower_length)*0.5

func _step_whipstaff(delta: float,water_torque: float) -> float:
 # Virtual work through the sliding staff: hand force -> tiller torque.
 # A finite crew force permits stall and kickback; no angle is imposed in force mode.
 var depth := 1.15
 var length := 1.70
 var upper := 2.35
 var ratio := length*sin(actual_rudder_angle)/depth
 var staff_angle := -atan(ratio)
 var hand_x := -upper*sin(staff_angle)
 var derivative := upper*length*cos(actual_rudder_angle)*cos(staff_angle)/(depth*(1.0+ratio*ratio))
 var target_angle := clampf(float(vessel.rudder_input),-1.0,1.0)*historical_rudder_limit
 var target_x := upper*sin(atan(length*sin(target_angle)/depth))
 crew_hand_force = clampf(500.0*(target_x-hand_x)-120.0*derivative*rudder_velocity,-180.0,180.0) if steering_rope_intact else 0.0
 last_water_hinge_torque = water_torque
 var torque := crew_hand_force*derivative+water_torque-30.0*rudder_velocity
 var acceleration := torque/rudder_inertia
 var old_velocity := rudder_velocity
 rudder_velocity += acceleration*delta
 actual_rudder_angle += rudder_velocity*delta
 if absf(actual_rudder_angle)>historical_rudder_limit:
  actual_rudder_angle = clampf(actual_rudder_angle,-historical_rudder_limit,historical_rudder_limit)
  if actual_rudder_angle*rudder_velocity>0.0: rudder_velocity = 0.0
 return (rudder_velocity-old_velocity)/maxf(delta,0.000001)

func set_helm_torque(torque_nm: float) -> void:
 # Adapter for future hand/VR controls. Zero torque means a released, backdrivable wheel.
 direct_helm_control = true
 direct_helm_torque = torque_nm

func use_button_helm() -> void:
 direct_helm_control = false

func step_loaded_steering(delta: float,water_torque: float) -> Dictionary:
 if use_whipstaff:
  return {"rudder_acceleration":_step_whipstaff(delta,water_torque),"wheel_acceleration":0.0}
 var old_rudder := rudder_velocity
 var old_wheel := wheel_velocity
 last_water_hinge_torque = water_torque
 var dt := delta/4.0
 for substep in 4:
  var tip := Vector3(-1.70*sin(actual_rudder_angle),0,13.15-1.70*cos(actual_rudder_angle))
  var derivative := Vector3(-1.70*cos(actual_rudder_angle),0,1.70*sin(actual_rudder_angle))
  var lengths: Array[float] = []
  var derivatives: Array[float] = []
  for side in [-1.0,1.0]:
   var arm := tip-Vector3(side*1.10,0,11.45)
   lengths.append(arm.length())
   derivatives.append(arm.normalized().dot(derivative))
  var extension_port := lengths[0]-1.10+drum_radius*wheel_angle
  var extension_starboard := lengths[1]-1.10-drum_radius*wheel_angle
  port_line_tension = maxf(0.0,steering_line_pretension+steering_line_stiffness*extension_port+steering_line_damping*(derivatives[0]*rudder_velocity+drum_radius*wheel_velocity)) if steering_rope_intact else 0.0
  starboard_line_tension = maxf(0.0,steering_line_pretension+steering_line_stiffness*extension_starboard+steering_line_damping*(derivatives[1]*rudder_velocity-drum_radius*wheel_velocity)) if steering_rope_intact else 0.0
  var target := clampf(float(vessel.rudder_input),-1.0,1.0)*wheel_stop
  var crew_torque := direct_helm_torque if direct_helm_control else 55.0*(target-wheel_angle)-35.0*wheel_velocity
  crew_torque = clampf(crew_torque,-180.0*wheel_handle_radius,180.0*wheel_handle_radius)
  crew_hand_force = crew_torque/wheel_handle_radius
  var wheel_torque := crew_torque+(starboard_line_tension-port_line_tension)*drum_radius-5.0*wheel_velocity
  var tiller_torque := -port_line_tension*derivatives[0]-starboard_line_tension*derivatives[1]+water_torque-30.0*rudder_velocity
  wheel_velocity += wheel_torque/wheel_inertia*dt
  rudder_velocity += tiller_torque/rudder_inertia*dt
  wheel_angle += wheel_velocity*dt
  actual_rudder_angle += rudder_velocity*dt
  if absf(actual_rudder_angle)>historical_rudder_limit:
   actual_rudder_angle = clampf(actual_rudder_angle,-historical_rudder_limit,historical_rudder_limit)
   if actual_rudder_angle*rudder_velocity>0.0: rudder_velocity = 0.0
  if absf(wheel_angle)>wheel_stop:
   wheel_angle = clampf(wheel_angle,-wheel_stop,wheel_stop)
   if wheel_angle*wheel_velocity>0.0: wheel_velocity = 0.0
 return {"rudder_acceleration":(rudder_velocity-old_rudder)/maxf(delta,0.000001),"wheel_acceleration":(wheel_velocity-old_wheel)/maxf(delta,0.000001)}

func steering_energy() -> float:
 var tip := Vector3(-1.70*sin(actual_rudder_angle),0,13.15-1.70*cos(actual_rudder_angle))
 var extension_p := tip.distance_to(Vector3(-1.10,0,11.45))-1.10+drum_radius*wheel_angle+steering_line_pretension/steering_line_stiffness
 var extension_s := tip.distance_to(Vector3(1.10,0,11.45))-1.10-drum_radius*wheel_angle+steering_line_pretension/steering_line_stiffness
 return 0.5*wheel_inertia*wheel_velocity*wheel_velocity+0.5*rudder_inertia*rudder_velocity*rudder_velocity+0.5*steering_line_stiffness*(pow(maxf(0,extension_p),2)+pow(maxf(0,extension_s),2))

func _bind_steering_route() -> void:
 var drum := MeshInstance3D.new()
 drum.name = "WoodenHelmDrum"
 var cylinder := CylinderMesh.new()
 cylinder.top_radius = drum_radius
 cylinder.bottom_radius = drum_radius
 cylinder.height = 0.40
 cylinder.radial_segments = 12
 drum.mesh = cylinder
 drum.rotation.x = PI*0.5
 drum.position.z = 0.18
 wheel.add_child(drum)
 for side in [-1.0,1.0]:
  var line := MeshInstance3D.new()
  line.name = "SteeringRopePort" if side<0 else "SteeringRopeStarboard"
  add_child(line)
  steering_lines.append(line)
  for point in [Vector3(side*0.35,wheel.position.y-1.0,wheel.position.z+0.18),Vector3(side*1.10,0.15,11.45)]:
   var block := MeshInstance3D.new()
   block.name = "WoodenSteeringBlock"
   var shell := BoxMesh.new()
   shell.size = Vector3(0.14,0.24,0.18)
   block.mesh = shell
   block.position = point
   add_child(block)
 _update_steering_route()

func _update_steering_route() -> void:
 var tip := rudder.position+Basis(Vector3.UP,actual_rudder_angle)*Vector3(0,0,-1.70)
 for i in steering_lines.size():
  var line := steering_lines[i]
  line.visible = steering_rope_intact and not use_whipstaff
  var side := -1.0 if i==0 else 1.0
  var points := [Vector3(side*drum_radius,wheel.position.y,wheel.position.z+0.18),Vector3(side*0.35,wheel.position.y-1.0,wheel.position.z+0.18),Vector3(side*1.10,0.15,11.45)]
  var st := SurfaceTool.new()
  st.begin(Mesh.PRIMITIVE_TRIANGLES)
  st.set_smooth_group(0)
  for k in range(points.size()-1): Refit._tube(st,points[k],points[k+1],0.018)
  var block: Vector3 = points[-1]
  var tension := port_line_tension if i==0 else starboard_line_tension
  var payout := 1.10+side*drum_radius*wheel_angle
  var sag := minf(0.25,sqrt(maxf(0.0,payout-block.distance_to(tip)))*0.4) if tension<0.1 else 0.0
  for k in 4:
   var t0 := float(k)/4.0
   var t1 := float(k+1)/4.0
   var a := block.lerp(tip,t0)-Vector3.UP*sag*sin(t0*PI)
   var b := block.lerp(tip,t1)-Vector3.UP*sag*sin(t1*PI)
   Refit._tube(st,a,b,0.018)
  st.generate_normals()
  st.index()
  line.mesh = st.commit()
