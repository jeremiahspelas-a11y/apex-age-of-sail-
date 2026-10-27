extends Node3D
## Seeded evolving wind, sun, storm fronts and mobile-friendly 3D cloud banks.
@export var cycle_seconds := 240.0
@export var seed_value := 17
@export var max_wind_mps := 17.0
@onready var boat: RigidBody3D = get_parent().get_node("Boat")
@onready var ocean: MeshInstance3D = get_parent().get_node("Ocean")
## Start at late morning with strong daylight, then advance continuously through night.
@export_range(0.0,24.0,0.25) var starting_hour := 10.0
var phase := 0.0
var current_storm := 0.0
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var environment: Environment
var sky_material: PhysicalSkyMaterial
var cloud_banks: Array[Node3D] = []
var cloud_materials: Array[StandardMaterial3D] = []
var base_cloud_positions: Array[Vector3] = []
var cloud_clock := 0.0

func get_wetness() -> float:
 return current_storm

func _ready() -> void:
 phase = fposmod((starting_hour - 6.0) / 24.0 * TAU, TAU)
 sun = DirectionalLight3D.new()
 sun.name = "WeatherSun"
 sun.light_energy = 1.65
 sun.shadow_enabled = true
 sun.rotation_degrees = Vector3(-35.0,-35.0,0.0)
 add_child(sun)
 moon = DirectionalLight3D.new()
 moon.name = "WeatherMoon"
 moon.light_color = Color(0.56,0.68,0.90)
 moon.light_energy = 0.0
 moon.shadow_enabled = false
 add_child(moon)
 var world := WorldEnvironment.new()
 world.name = "WeatherEnvironment"
 var env := Environment.new()
 environment = env
 env.background_mode = Environment.BG_SKY
 var sky := Sky.new()
 sky_material = PhysicalSkyMaterial.new()
 sky_material.sun_disk_scale = 2.5
 sky_material.turbidity = 3.0
 sky_material.use_debanding = true
 sky.sky_material = sky_material
 env.sky = sky
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color(0.7,0.78,0.93)
 env.ambient_light_energy = 0.3
 env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
 env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 world.environment = env
 add_child(world)
 _build_clouds()

func _build_clouds() -> void:
 # Each cloud is a cluster of irregular volumetric lobes, not a flat disc.
 var rng := RandomNumberGenerator.new()
 rng.seed = seed_value
 for i in 24:
  var bank := Node3D.new()
  bank.name = "CloudBank_%02d" % i
  add_child(bank)
  var mat := StandardMaterial3D.new()
  mat.albedo_color = Color(0.96,0.97,0.99,0.86)
  mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
  mat.roughness = 1.0
  mat.cull_mode = BaseMaterial3D.CULL_DISABLED
  for j in 7:
   var lobe := MeshInstance3D.new()
   var sphere := SphereMesh.new()
   sphere.radius = 1.0
   sphere.height = 2.0
   sphere.radial_segments = 10
   sphere.rings = 6
   lobe.mesh = sphere
   lobe.material_override = mat
   lobe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   lobe.position = Vector3(rng.randf_range(-25.0,25.0),rng.randf_range(-6.0,10.0),rng.randf_range(-17.0,17.0))
   lobe.scale = Vector3(rng.randf_range(11.0,23.0),rng.randf_range(7.0,16.0),rng.randf_range(10.0,24.0))
   bank.add_child(lobe)
  var angle := rng.randf_range(0.0,TAU)
  var distance := rng.randf_range(145.0,450.0)
  var altitude := rng.randf_range(80.0,160.0)
  base_cloud_positions.append(Vector3(cos(angle)*distance,altitude,sin(angle)*distance))
  cloud_banks.append(bank)
  cloud_materials.append(mat)

func _process(delta: float) -> void:
 phase += delta / max(cycle_seconds, 1.0) * TAU
 cloud_clock += delta
 var front: float = 0.5 + 0.5*sin(phase + float(seed_value))
 var secondary: float = 0.5 + 0.5*sin(phase*0.37 + float(seed_value)*0.57)
 var storm: float = clamp(front*0.75 + secondary*0.25, 0.0, 1.0)
 current_storm = storm
 var gust: float = 0.8 + 0.2*sin(phase*7.0 + 2.0)
 var heading: float = phase*0.23 + float(seed_value)*0.1
 var speed: float = (5.0 + storm*max_wind_mps)*gust
 var wind := Vector3(cos(heading)*speed, 0.0, sin(heading)*speed)
 boat.wind_world = wind
 ocean.storm_scale = 0.55 + storm*2.6
 ocean.wetness = storm
 ocean.set("wind_direction", Vector2(wind.x, wind.z).normalized())
 # Procedural full-day lighting: configured 10 AM start, 6 AM sunrise, 6 PM sunset.
 # Rotation X drives sunlight direction; moon is on the opposite hemisphere.
 var solar_phase: float = phase
 var daylight: float = sin(solar_phase)
 var day_strength: float = smoothstep(-0.10,0.22,daylight)
 var night_strength: float = 1.0 - smoothstep(-0.22,0.08,daylight)
 sun.rotation_degrees = Vector3(-90.0 + rad_to_deg(solar_phase), -35.0, 0.0)
 sun.light_energy = (1.85-storm*0.5)*day_strength
 moon.rotation_degrees = Vector3(sun.rotation_degrees.x+180.0,sun.rotation_degrees.y,0.0)
 moon.light_energy = (0.36-storm*0.10)*night_strength
 environment.ambient_light_energy = lerpf(0.18,0.80,day_strength)
 environment.ambient_light_color = Color(0.43,0.54,0.78).lerp(Color(0.82,0.85,0.91),day_strength)
 sun.light_color = Color(1.0,0.95,0.84).lerp(Color(0.79,0.84,0.93),storm)
 sky_material.turbidity = lerpf(2.2,8.0,storm)
 sky_material.mie_coefficient = lerpf(0.004,0.014,storm)
 sky_material.rayleigh_coefficient = lerpf(2.5,1.3,storm)
 var camera := get_viewport().get_camera_3d()
 var center := Vector3.ZERO if camera == null else Vector3(camera.global_position.x, 0.0, camera.global_position.z)
 for i in cloud_banks.size():
  var p := base_cloud_positions[i]
  var drift: Vector3 = wind.normalized()*cloud_clock*(0.8 + 0.35*float(i%4))
  var dx: float = fposmod(p.x + drift.x + 520.0, 1040.0)-520.0
  var dz: float = fposmod(p.z + drift.z + 520.0, 1040.0)-520.0
  cloud_banks[i].global_position = center + Vector3(dx,p.y,dz)
  var cover: float = clamp(0.24 + storm*0.7 + 0.12*sin(phase*2.0 + float(i)),0.0,1.0)
  cloud_banks[i].visible = cover > 0.22 or i%3 == 0
  cloud_materials[i].albedo_color = Color(0.95,0.96,0.98,0.3 + cover*0.45).lerp(Color(0.37,0.43,0.52,0.55+cover*0.25),storm)
