extends Node3D
signal steering_connection_changed(connected: bool)
## V9 prototype: independent articulated solid parts and interactable states.
@onready var vessel: RigidBody3D = get_parent() as RigidBody3D
var rudder: Node3D
var wheel: Node3D
var yards: Array[Node3D] = []
var doors: Array[Node3D] = []
var hatches: Array[Node3D] = []
var door_open := false
var hatch_open := false
# Helm command is now expressed as a drum/rope/tiller kinematic transmission.
# Full tension and hydrodynamic yaw physics remain on the engineering checklist.
var wheel_angle := 0.0
var wheel_drum_radius := 0.18
var tiller_radius := 0.95
var rope_travel := 0.0
var actual_rudder_angle := 0.0
var steering_rope_intact := true
var original_rudder: MeshInstance3D
var original_wheel: MeshInstance3D
var original_rudder_base := Basis.IDENTITY
var original_wheel_base := Basis.IDENTITY
var drum_efficiency := 0.94
func toggle_steering_rope() -> void:
 steering_rope_intact = not steering_rope_intact
 steering_connection_changed.emit(steering_rope_intact)
func rudder_angle_for_physics() -> float:
 return actual_rudder_angle
func make_part(name: String, dimensions: Vector3, pos: Vector3, color: Color, collision := true) -> Node3D:
 var pivot := Node3D.new()
 pivot.name = name
 pivot.position = pos
 add_child(pivot)
 var mesh := MeshInstance3D.new()
 var shape := BoxMesh.new()
 shape.size = dimensions
 mesh.mesh = shape
 var material := StandardMaterial3D.new()
 material.albedo_color = color
 material.roughness = 0.83
 mesh.material_override = material
 pivot.add_child(mesh)
 if collision:
  var body := AnimatableBody3D.new()
  body.collision_layer = 2
  body.collision_mask = 2
  pivot.add_child(body)
  var collider := CollisionShape3D.new()
  var box := BoxShape3D.new()
  box.size = dimensions
  collider.shape = box
  body.add_child(collider)
 return pivot
func _ready() -> void:
 # Original GLB already contains rudder and wheel. Retain control state without duplicate visible boxes.
 rudder = Node3D.new()
 rudder.name = "RudderControlPivot"
 rudder.position = Vector3(0,-1.25,13.45)
 add_child(rudder)
 wheel = Node3D.new()
 wheel.name = "HelmControlPivot"
 wheel.position = Vector3(0,2.95,10.8)
 add_child(wheel)
 for z in [-2.5,4.5]:
  doors.append(make_part("HingedDoor", Vector3(1.02,1.68,.085), Vector3(-.45,-.01,z), Color(.46,.27,.12)))
 for z in [-4.0,2.0]:
  hatches.append(make_part("OpeningHatch", Vector3(1.15,.1,1.2), Vector3(0,1.39,z), Color(.46,.28,.13)))
 # Match only known original mesh identifiers; do not replace or reparent the GLB.
 var imported := vessel.get_node_or_null("HullVisual")
 if imported != null:
  original_rudder = _find_mesh(imported,"rudder_blade")
  original_wheel = _find_mesh(imported,"V9_helm_wheel_hub")
  if original_rudder != null:
   original_rudder_base = original_rudder.transform.basis
  if original_wheel != null:
   original_wheel_base = original_wheel.transform.basis
  print("APEX original rig controls: rudder=",original_rudder != null," wheel=",original_wheel != null)
 # Existing model contains eight rig yards. Do not create floating duplicate box yards.
 for z in [-6.5,3.1,10.8]:
  var pivot := Node3D.new()
  pivot.name = "YardControlPivot"
  pivot.position = Vector3(0,9.5,z)
  add_child(pivot)
  yards.append(pivot)
func _find_mesh(root: Node, exact_name: String) -> MeshInstance3D:
 if root is MeshInstance3D and root.name == exact_name:
  return root as MeshInstance3D
 for child in root.get_children():
  var found := _find_mesh(child,exact_name)
  if found != null:
   return found
 return null
func _process(delta: float) -> void:
 if vessel == null: return
 var desired_wheel_angle: float = clampf(float(vessel.get("rudder_input")),-1.0,1.0) * deg_to_rad(140.0)
 wheel_angle = move_toward(wheel_angle,desired_wheel_angle,delta * 1.5)
 rope_travel = wheel_angle * wheel_drum_radius * drum_efficiency if steering_rope_intact else 0.0
 var demanded_angle: float = clampf(rope_travel / tiller_radius,-deg_to_rad(32.0),deg_to_rad(32.0))
 actual_rudder_angle = move_toward(actual_rudder_angle,demanded_angle,delta * 0.42) if steering_rope_intact else move_toward(actual_rudder_angle,0.0,delta * 0.12)
 rudder.rotation.y = actual_rudder_angle
 wheel.rotation.z = wheel_angle
 if original_rudder != null:
  original_rudder.transform.basis = original_rudder_base * Basis(Vector3.UP,actual_rudder_angle)
 if original_wheel != null:
  original_wheel.transform.basis = original_wheel_base * Basis(Vector3.FORWARD,wheel_angle)
 var trim: float = clamp(float(vessel.get("sheet_angle")), -1.5, 1.5)
 for yard in yards: yard.rotation.y = lerp_angle(yard.rotation.y, trim*.55, min(1.0,delta*1.6))
 for door in doors: door.rotation.y = lerp_angle(door.rotation.y, deg_to_rad(85) if door_open else 0.0, min(1.0,delta*3.0))
 for hatch in hatches: hatch.rotation.x = lerp_angle(hatch.rotation.x, deg_to_rad(75) if hatch_open else 0.0, min(1.0,delta*3.0))
func toggle_doors() -> void: door_open = not door_open
func toggle_hatches() -> void: hatch_open = not hatch_open
