extends Node3D
signal steering_connection_changed(connected: bool)
## Articulate the imported parts at measured sockets; no duplicate solid proxy fittings.
const Refit = preload("res://scripts/ship_refit.gd")
const SailCloth = preload("res://scripts/sail_cloth.gd")
@onready var vessel: RigidBody3D = get_parent() as RigidBody3D
var rudder: Node3D
var wheel: Node3D
var yards: Array[Node3D] = []
var doors: Array[Node3D] = []
var hatches: Array[Node3D] = []
var door_open := false
var hatch_open := false
var wheel_angle := 0.0
var wheel_drum_radius := 0.18
var tiller_radius := 0.95
var rope_travel := 0.0
var actual_rudder_angle := 0.0
var steering_rope_intact := true
var drum_efficiency := 0.94
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
 var pedestal := Refit.find_mesh(root,"v8_helm_pedestal")
 if pedestal != null:
  _reshape_box(pedestal,AABB(Vector3(-0.21,Refit.QUARTER_TOP,10.54),Vector3(0.42,2.95-Refit.QUARTER_TOP,0.52)))

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
 var desired: float = clampf(float(vessel.get("rudder_input")),-1.0,1.0)*deg_to_rad(140.0)
 wheel_angle = move_toward(wheel_angle,desired,delta*1.5)
 rope_travel = wheel_angle*wheel_drum_radius*drum_efficiency if steering_rope_intact else 0.0
 var demanded := clampf(rope_travel/tiller_radius,-deg_to_rad(32.0),deg_to_rad(32.0))
 actual_rudder_angle = move_toward(actual_rudder_angle,demanded,delta*0.42) if steering_rope_intact else move_toward(actual_rudder_angle,0.0,delta*0.12)
 rudder.rotation.y = actual_rudder_angle
 wheel.rotation.z = wheel_angle
 var trim := clampf(float(vessel.get("sheet_angle")),-1.5,1.5)
 for yard in yards:
  yard.rotation.y = lerp_angle(yard.rotation.y,trim*0.55,minf(1.0,delta*1.6))
 for door in doors:
  door.rotation.y = lerp_angle(door.rotation.y,deg_to_rad(85.0) if door_open else 0.0,minf(1.0,delta*3.0))
 for hatch in hatches:
  hatch.rotation.x = lerp_angle(hatch.rotation.x,deg_to_rad(75.0) if hatch_open else 0.0,minf(1.0,delta*3.0))

func toggle_doors() -> void: door_open = not door_open
func toggle_hatches() -> void: hatch_open = not hatch_open
