extends Node3D
## Seeded evolving wind, sun, storm fronts and mobile-friendly 3D cloud banks.
@export var cycle_seconds := 240.0
@export var seed_value := 17
@export var max_wind_mps := 17.0
@onready var boat: RigidBody3D = get_parent().get_node("Boat")
@onready var ocean: MeshInstance3D = get_parent().get_node("Ocean")
var phase := 0.0
var current_storm := 0.0
var sun: DirectionalLight3D
var sky_material: ProceduralSkyMaterial
var cloud_banks: Array[MeshInstance3D] = []
var cloud_materials: Array[StandardMaterial3D] = []
var base_cloud_positions: Array[Vector3] = []
var cloud_clock := 0.0

func get_wetness() -> float:
 return current_storm

func _ready() -> void:
 sun = DirectionalLight3D.new()
 sun.name = "WeatherSun"
 sun.light_energy = 1.45
 sun.shadow_enabled = true
 add_child(sun)
 var world := WorldEnvironment.new()
 world.name = "WeatherEnvironment"
 var env := Environment.new()
 env.background_mode = Environment.BG_SKY
 var sky := Sky.new()
 sky_material = ProceduralSkyMaterial.new()
 sky_material.use_debanding = true
 sky.sky_material = sky_material
 env.sky = sky
 env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
 env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
 env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 world.environment = env
 add_child(world)
 _build_clouds()

func _build_clouds() -> void:
 var rng := RandomNumberGenerator.new()
 rng.seed = seed_value
 for i in 32:
  var mesh_node := MeshInstance3D.new()
  mesh_node.name = "CloudBank_%02d" % i
  var sphere := SphereMesh.new()
  sphere.radius = 1.0
  sphere.height = 2.0
  sphere.radial_segments = 12
  sphere.rings = 6
  mesh_node.mesh = sphere
  var mat := StandardMaterial3D.new()
  mat.albedo_color = Color(0.91, 0.94, 0.97, 0.65)
  mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
  mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
  mat.roughness = 1.0
  mat.cull_mode = BaseMaterial3D.CULL_DISABLED
  mesh_node.material_override = mat
  mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var angle := rng.randf_range(0.0, TAU)
  var distance := rng.randf_range(115.0, 330.0)
  var altitude := rng.randf_range(58.0, 115.0)
  var p := Vector3(cos(angle)*distance, altitude, sin(angle)*distance)
  base_cloud_positions.append(p)
  mesh_node.scale = Vector3(rng.randf_range(17,35), rng.randf_range(3,9), rng.randf_range(12,31))
  add_child(mesh_node)
  cloud_banks.append(mesh_node)
  cloud_materials.append(mat)

func _process(delta: float) -> void:
 phase += delta / max(cycle_seconds, 1.0) * TAU
 cloud_clock += delta
 var front := 0.5 + 0.5*sin(phase + float(seed_value))
 var secondary := 0.5 + 0.5*sin(phase*0.37 + float(seed_value)*0.57)
 var storm := clamp(front*0.75 + secondary*0.25, 0.0, 1.0)
 current_storm = storm
 var gust := 0.8 + 0.2*sin(phase*7.0 + 2.0)
 var heading := phase*0.23 + float(seed_value)*0.1
 var speed := (5.0 + storm*max_wind_mps)*gust
 var wind := Vector3(cos(heading)*speed, 0.0, sin(heading)*speed)
 boat.wind_world = wind
 ocean.storm_scale = 0.55 + storm*2.6
 ocean.wetness = storm
 ocean.set("wind_direction", Vector2(wind.x, wind.z).normalized())
 var sun_elevation := -55.0 + 12.0*sin(phase*0.13) + storm*13.0
 sun.rotation_degrees = Vector3(sun_elevation, -35.0 + phase*7.0, 0.0)
 sun.light_energy = 1.5 - storm*0.9
 sun.light_color = Color(1.0,0.95,0.84).lerp(Color(0.79,0.84,0.93),storm)
 sky_material.sky_top_color = Color(0.12,0.37,0.73).lerp(Color(0.085,0.11,0.17),storm)
 sky_material.sky_horizon_color = Color(0.67,0.78,0.91).lerp(Color(0.26,0.30,0.37),storm)
 sky_material.ground_horizon_color = Color(0.46,0.57,0.68).lerp(Color(0.22,0.26,0.31),storm)
 var camera := get_viewport().get_camera_3d()
 var center := Vector3.ZERO if camera == null else Vector3(camera.global_position.x, 0.0, camera.global_position.z)
 for i in cloud_banks.size():
  var p := base_cloud_positions[i]
  var drift := wind.normalized()*cloud_clock*(0.8 + 0.35*float(i%4))
  var dx := fposmod(p.x + drift.x + 380.0, 760.0)-380.0
  var dz := fposmod(p.z + drift.z + 380.0, 760.0)-380.0
  cloud_banks[i].global_position = center + Vector3(dx,p.y,dz)
  var cover := clamp(0.24 + storm*0.7 + 0.12*sin(phase*2.0 + float(i)),0.0,1.0)
  cloud_banks[i].visible = cover > 0.27 or i%3 == 0
  cloud_materials[i].albedo_color = Color(0.95,0.96,0.98,0.3 + cover*0.45).lerp(Color(0.37,0.43,0.52,0.55+cover*0.25),storm)
