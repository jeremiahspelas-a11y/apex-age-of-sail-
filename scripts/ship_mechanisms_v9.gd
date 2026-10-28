extends Node3D
signal steering_connection_changed(connected: bool)
## Articulate the imported parts at measured sockets; no duplicate solid proxy fittings.
const Refit = preload("res://scripts/ship_refit.gd")
const SteeringTransmission = preload("res://scripts/steering_transmission.gd")
const YardBrace = preload("res://scripts/yard_brace.gd")
var helm := SteeringTransmission.new()
var brace := YardBrace.new()
var loaded_yard: Node3D
var loaded_sail: MeshInstance3D
var brace_lines: Array[MeshInstance3D] = []
var brace_reactions: Array[Dictionary] = []
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
var steering_lines: Array[MeshInstance3D] = []
var _line_clock := 0.0
var whipstaff: Node3D
var staff_mesh: MeshInstance3D
var rowle: MeshInstance3D
var original_rudder: MeshInstance3D
var original_wheel: MeshInstance3D
var rig_sails: Array[MeshInstance3D] = []
var rig_yards: Array[MeshInstance3D] = []

var actual_rudder_angle: float:
 get: return helm.rudder_angle
var steering_rope_intact: bool:
 get: return helm.connected
var rudder_inertia: float:
 get: return helm.rudder_inertia
var wheel_inertia: float:
 get: return helm.wheel_inertia
var port_line_tension: float:
 get: return helm.port_line_tension
var starboard_line_tension: float:
 get: return helm.starboard_line_tension

func toggle_steering_rope() -> void:
 helm.connected = not helm.connected
 steering_connection_changed.emit(helm.connected)

func rudder_angle_for_physics() -> float:
 return helm.rudder_angle

func _ready() -> void:
 var imported := vessel.get_node_or_null("HullVisual")
 if imported == null:
  push_error("SHIP MECHANISMS: original ship missing")
  return
 _bind_rudder(imported)
 _bind_helm(imported)
 if use_whipstaff: helm.rudder_stop = deg_to_rad(8.0)
 _bind_period_steering(imported)
 _bind_steering_route()
 _bind_rig(imported)
 _bind_braces()
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
  helm.wheel_angle = move_toward(helm.wheel_angle,command*helm.wheel_stop,delta*1.5)
  var demanded := command*helm.rudder_stop if use_whipstaff else asin(clampf(helm.wheel_angle*helm.drum_radius/1.70,-1.0,1.0))
  if helm.connected: helm.rudder_angle = clampf(demanded,-helm.rudder_stop,helm.rudder_stop)
  helm.rudder_velocity = 0.0
  helm.wheel_velocity = 0.0
 rudder.rotation.y = helm.rudder_angle
 wheel.rotation.z = helm.wheel_angle
 _update_whipstaff()
 _line_clock += delta
 if _line_clock >= 0.1:
  _line_clock = 0.0
  _update_steering_route()
  _update_braces()
 var trim := clampf(float(vessel.get("sheet_angle")),-1.5,1.5)
 for yard in yards:
  if vessel.force_trial and yard==loaded_yard: continue
  yard.rotation.y = lerp_angle(yard.rotation.y,trim*0.55,minf(1.0,delta*1.6))
 for door in doors:
  door.rotation.y = lerp_angle(door.rotation.y,deg_to_rad(85.0) if door_open else 0.0,minf(1.0,delta*3.0))
 for hatch in hatches:
  hatch.rotation.x = lerp_angle(hatch.rotation.x,deg_to_rad(75.0) if hatch_open else 0.0,minf(1.0,delta*3.0))

func toggle_doors() -> void: door_open = not door_open
func toggle_hatches() -> void: hatch_open = not hatch_open

func _bind_braces() -> void:
 loaded_yard = get_node_or_null("YardRig_1_3")
 if loaded_yard == null: return
 for sail in rig_sails:
  if sail.get_parent()==loaded_yard:
   loaded_sail = sail
   sail.set_meta("loaded_brace",true)
 var span := 2.75
 if loaded_sail != null:
  var bounds: AABB = loaded_sail.get_meta("original_sail_bounds")
  span = bounds.size.x*0.5
 var leads: Array[Vector3] = []
 var belays: Array[Vector3] = []
 var hemp := StandardMaterial3D.new()
 hemp.albedo_color = Color(0.24,0.19,0.11)
 hemp.roughness = 0.96
 var wood := StandardMaterial3D.new()
 wood.albedo_color = Color(0.27,0.14,0.06)
 wood.roughness = 0.85
 for side in [-1.0,1.0]:
  # Single fixed turning blocks lead aft; pins stand on the main deck.
  var lead := Vector3(side*0.35,5.8,3.1)
  var pin := Vector3(side*2.4,Refit.MAIN_TOP+0.55,3.3)
  leads.append(lead-loaded_yard.position)
  belays.append(pin-loaded_yard.position)
  var line := MeshInstance3D.new()
  line.name = "ForeBraceRopePort" if side<0 else "ForeBraceRopeStarboard"
  line.material_override = hemp
  add_child(line)
  brace_lines.append(line)
  var block := MeshInstance3D.new()
  block.name = "ForeBraceTurningBlock"
  var shell := BoxMesh.new()
  shell.size = Vector3(0.18,0.28,0.22)
  block.mesh = shell
  block.material_override = wood
  block.position = lead
  add_child(block)
  # Strops attach the fixed blocks to the mainmast.
  var strop := MeshInstance3D.new()
  strop.name = "ForeBraceBlockRopeStrop"
  var surface := SurfaceTool.new()
  surface.begin(Mesh.PRIMITIVE_TRIANGLES)
  Refit._tube(surface,lead,Vector3(side*0.20,6.1,3.1),0.028)
  surface.generate_normals()
  strop.mesh = surface.commit()
  strop.material_override = hemp
  add_child(strop)
  var pin_mesh := MeshInstance3D.new()
  pin_mesh.name = "ForeBraceBelayingPin"
  var cylinder := CylinderMesh.new()
  cylinder.height = 0.45
  cylinder.top_radius = 0.04
  cylinder.bottom_radius = 0.04
  pin_mesh.mesh = cylinder
  pin_mesh.material_override = wood
  pin_mesh.position = pin
  add_child(pin_mesh)
  var rack := MeshInstance3D.new()
  rack.name = "ForeBracePinRack"
  var beam := BoxMesh.new()
  beam.size = Vector3(0.22,0.8,0.24)
  rack.mesh = beam
  rack.material_override = wood
  rack.position = Vector3(pin.x,Refit.MAIN_TOP+0.4,pin.z)
  add_child(rack)
 brace.configure(span,leads,belays)
 _update_braces()

func reset_braces() -> void:
 if loaded_yard == null: return
 var leads: Array[Vector3] = []
 var belays: Array[Vector3] = []
 for line: Dictionary in brace.lines:
  leads.append(line.lead)
  belays.append(line.belay)
 brace.configure(brace.half_span,leads,belays,loaded_yard.rotation.y)

func step_loaded_braces(delta: float,wind_torque: float) -> float:
 if loaded_yard == null: return 0.0
 var report := brace.step(delta,wind_torque)
 brace_reactions = report.reactions
 loaded_yard.rotation.y = brace.angle
 return report.angular_acceleration

func brace_report() -> Dictionary:
 if brace.lines.size()!=2: return {}
 return {"angle_deg":rad_to_deg(brace.angle),"velocity_rad_s":brace.angular_velocity,"port_length_m":brace.lines[0].length,"starboard_length_m":brace.lines[1].length,"port_tension_n":brace.lines[0].tension,"starboard_tension_n":brace.lines[1].tension,"port_mode":brace.lines[0].mode,"starboard_mode":brace.lines[1].mode}

func _update_braces() -> void:
 if loaded_yard == null: return
 for i in brace_lines.size():
  var line: Dictionary = brace.lines[i]
  var visual := brace_lines[i]
  visual.visible = line.mode!=YardBrace.Hold.CUT
  var end := loaded_yard.position+Basis(Vector3.UP,loaded_yard.rotation.y)*Vector3(-brace.half_span if i==0 else brace.half_span,0,0)
  var lead: Vector3 = loaded_yard.position+line.lead
  var pin: Vector3 = loaded_yard.position+line.belay
  var sag := 0.0
  if vessel.force_trial and line.tension<0.1:
   sag = minf(1.5,sqrt(maxf(0.0,line.length-line.tail-end.distance_to(lead)))*0.6)
  var st := SurfaceTool.new()
  st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for k in 8:
   var t0 := float(k)/8.0
   var t1 := float(k+1)/8.0
   Refit._tube(st,end.lerp(lead,t0)-Vector3.UP*sag*sin(t0*PI),end.lerp(lead,t1)-Vector3.UP*sag*sin(t1*PI),0.018)
  Refit._tube(st,lead,pin,0.018)
  st.generate_normals()
  visual.mesh = st.commit()

func _bind_period_steering(root: Node) -> void:
 # Keep the preferred wheel; the optional whipstaff is a separate visual adapter.
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
 var tip := rudder.position + Basis(Vector3.UP,helm.rudder_angle)*Vector3(0,0,-1.70)
 var depth := whipstaff.position.y-tip.y
 whipstaff.rotation.z = atan2(tip.x,depth)
 # Slide the staff through its rowle so the lower tip remains on the horizontal tiller.
 whipstaff.position.z = tip.z
 rowle.position.z = tip.z
 var lower_length := Vector2(tip.x,depth).length()
 var cylinder := staff_mesh.mesh as CylinderMesh
 cylinder.height = 2.35+lower_length
 staff_mesh.position.y = (2.35-lower_length)*0.5

func set_helm_torque(torque_nm: float) -> void:
 helm.set_helm_torque(torque_nm)

func use_button_helm() -> void:
 helm.use_button_helm()

func step_loaded_steering(delta: float,water_torque: float) -> Dictionary:
 return helm.step(delta,water_torque,float(vessel.rudder_input),use_whipstaff)

func steering_energy() -> float:
 return helm.steering_energy()

func _bind_steering_route() -> void:
 var drum := MeshInstance3D.new()
 drum.name = "WoodenHelmDrum"
 var cylinder := CylinderMesh.new()
 cylinder.top_radius = helm.drum_radius
 cylinder.bottom_radius = helm.drum_radius
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
 var tip := rudder.position+Basis(Vector3.UP,helm.rudder_angle)*Vector3(0,0,-1.70)
 for i in steering_lines.size():
  var line := steering_lines[i]
  line.visible = helm.connected and not use_whipstaff
  var side := -1.0 if i==0 else 1.0
  var points := [Vector3(side*helm.drum_radius,wheel.position.y,wheel.position.z+0.18),Vector3(side*0.35,wheel.position.y-1.0,wheel.position.z+0.18),Vector3(side*1.10,0.15,11.45)]
  var st := SurfaceTool.new()
  st.begin(Mesh.PRIMITIVE_TRIANGLES)
  st.set_smooth_group(0)
  for k in range(points.size()-1): Refit._tube(st,points[k],points[k+1],0.018)
  var block: Vector3 = points[-1]
  var tension := helm.port_line_tension if i==0 else helm.starboard_line_tension
  var payout := 1.10+side*helm.drum_radius*helm.wheel_angle
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
