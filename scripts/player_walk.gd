extends CharacterBody3D
## Character stays in world space and follows the moving ship's rigid transform.
@export var boat_path: NodePath = NodePath("../Boat")
@export var view_path: NodePath = NodePath("../Camera3D")
@export var walk_speed := 2.7
@export var run_speed := 4.5
@export var jump_velocity := 4.2
var motion_input := Vector2.ZERO
var run_pressed := false
var movement_enabled := true
var movement_follows_view := true
var read_keyboard := true
var movement_heading := NAN
var remote_jump := false
var _old_ship_transform: Transform3D
var _has_ship_transform := false
@onready var boat: RigidBody3D = get_node_or_null(boat_path) as RigidBody3D
@onready var view: Camera3D = get_node_or_null(view_path) as Camera3D
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
 if not movement_enabled:
  velocity = Vector3.ZERO
  return
 var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") if read_keyboard else Vector2.ZERO
 if motion_input.length() > 0.12:
  direction = motion_input
 var desired := Vector3(direction.x, 0.0, direction.y)
 if is_finite(movement_heading):
  desired = Basis(Vector3.UP,movement_heading)*desired
 elif movement_follows_view and view != null:
  # Flatten axes separately so looking up/down does not change diagonal speed.
  var right := Vector3(view.global_basis.x.x,0,view.global_basis.x.z).normalized()
  var back := Vector3(view.global_basis.z.x,0,view.global_basis.z.z).normalized()
  desired = right*direction.x+back*direction.y
 elif boat != null:
  desired = boat.global_basis * desired
 desired.y = 0.0
 desired = desired.normalized()
 var speed := run_speed if run_pressed else walk_speed
 velocity.x = desired.x * speed
 velocity.z = desired.z * speed
 if is_on_floor():
  velocity.y = 0.0
  if remote_jump or (read_keyboard and Input.is_action_just_pressed("ui_accept")):
   velocity.y = jump_velocity
 else:
  velocity.y -= 9.81 * delta
 move_and_slide()
 remote_jump = false
