extends CharacterBody3D
## Character stays in world space and follows the moving ship's rigid transform.
@export var boat_path: NodePath = NodePath("../Boat")
@export var walk_speed := 2.7
@export var run_speed := 4.5
@export var jump_velocity := 4.2
var motion_input := Vector2.ZERO
var run_pressed := false
var _old_ship_transform: Transform3D
var _has_ship_transform := false
@onready var boat: RigidBody3D = get_node_or_null(boat_path) as RigidBody3D
func _ready() -> void:
 floor_snap_length = 0.4
 max_slides = 8
 if boat != null:
  _old_ship_transform = boat.global_transform
  _has_ship_transform = true
func _physics_process(delta: float) -> void:
 if boat != null and _has_ship_transform and is_on_floor():
  var local_point := _old_ship_transform.affine_inverse() * global_position
  global_position = boat.global_transform * local_point
 if boat != null:
  _old_ship_transform = boat.global_transform
  _has_ship_transform = true
 var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
 if motion_input.length() > 0.12:
  direction = motion_input
 var desired := Vector3(direction.x, 0.0, direction.y)
 if boat != null:
  desired = boat.global_basis * desired
 desired.y = 0.0
 desired = desired.normalized()
 var speed := run_speed if run_pressed else walk_speed
 velocity.x = desired.x * speed
 velocity.z = desired.z * speed
 if is_on_floor():
  velocity.y = 0.0
  if Input.is_action_just_pressed("ui_accept"):
   velocity.y = jump_velocity
 else:
  velocity.y -= 9.81 * delta
 move_and_slide()
