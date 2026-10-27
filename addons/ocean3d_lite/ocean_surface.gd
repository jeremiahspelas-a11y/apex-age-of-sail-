extends MeshInstance3D
# Camera-following surface sharing wave time and data with Ocean autoload.
var storm_scale := 1.0
var wetness := 0.0
var wind_direction := Vector2(1.0,0.0)
var clock := 0.0
func wave_height(x: float,z: float,_t: float) -> float:
 return Ocean.get_height(x,z)
func _ready() -> void:
 var plane := PlaneMesh.new()
 plane.size = Vector2(480,480)
 plane.subdivide_width = 320
 plane.subdivide_depth = 320
 mesh = plane
 var mat := ShaderMaterial.new()
 mat.shader = preload("res://addons/ocean3d_lite/shaders/ocean.gdshader")
 material_override = mat
func _process(_delta: float) -> void:
 clock = Ocean.time
 Ocean.storm_scale = storm_scale
 var mat := material_override as ShaderMaterial
 if mat != null:
  mat.set_shader_parameter("waves",Ocean.waves_for_shader())
  mat.set_shader_parameter("t",Ocean.time)
  mat.set_shader_parameter("storm_scale",Ocean.storm_scale)
  mat.set_shader_parameter("wind_direction",wind_direction)
  mat.set_shader_parameter("storminess",wetness)
  var boat := get_parent().get_node_or_null("Boat") as Node3D
  if boat != null:
   mat.set_shader_parameter("ship_position",Vector2(boat.global_position.x,boat.global_position.z))
   var forward: Vector3 = -boat.global_basis.z.normalized()
   mat.set_shader_parameter("ship_forward",Vector2(forward.x,forward.z))
   var speed: float = 0.0
   if boat is RigidBody3D:
    speed = (boat as RigidBody3D).linear_velocity.length()
   if boat.has_method("get"):
    var controlled_speed: Variant = boat.get("_controlled_speed")
    if controlled_speed is float:
     speed = maxf(speed,controlled_speed)
   mat.set_shader_parameter("ship_speed",speed)
 var cam := get_viewport().get_camera_3d()
 if cam != null:
  global_position = Vector3(cam.global_position.x,0.0,cam.global_position.z)
