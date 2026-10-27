extends MeshInstance3D
# Camera-following surface sharing wave time and data with Ocean autoload.
var storm_scale := 1.0
var wetness := 0.0
var wind_direction := Vector2(1.0,0.0)
var clock := 0.0
func wave_height(x: float,z: float,_t: float) -> float:
 return Ocean.get_height(x,z)
func _ready() -> void:
 # Dense near-field water makes short waves visible on Android; distant water remains coarse.
 var plane := PlaneMesh.new()
 plane.size = Vector2(220,220)
 plane.subdivide_width = 300
 plane.subdivide_depth = 300
 mesh = plane
 var mat := ShaderMaterial.new()
 mat.shader = preload("res://addons/ocean3d_lite/shaders/ocean.gdshader")
 material_override = mat
 # Four camera-centered outer patches cover the sea to the far horizon.
 # Their central opening prevents overlapping the high-detail near-water mesh.
 var outer: float = 3600.0
 var inner: float = 219.0
 var strip: float = (outer-inner)*0.5
 for section in 4:
  var far_mesh := PlaneMesh.new()
  var far_node := MeshInstance3D.new()
  var patch_size := Vector2(outer,strip) if section < 2 else Vector2(strip,inner)
  far_mesh.size = patch_size
  far_mesh.subdivide_width = 96 if section < 2 else 24
  far_mesh.subdivide_depth = 24 if section < 2 else 48
  far_node.mesh = far_mesh
  far_node.material_override = mat
  var offset := Vector3.ZERO
  if section == 0: offset.z = -(inner+strip)*0.5
  elif section == 1: offset.z = (inner+strip)*0.5
  elif section == 2: offset.x = -(inner+strip)*0.5
  else: offset.x = (inner+strip)*0.5
  far_node.position = offset
  add_child(far_node)
  horizon_patches.append(far_node)
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
