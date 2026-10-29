extends Node3D
## Advected atmosphere, independent day clock, lagged sea response and procedural FX.
const Field = preload("res://scripts/weather_field.gd")
@export var cycle_seconds := 1440.0
@export var seed_value := 17
@export_range(0.0,24.0,0.25) var starting_hour := 12.0
@onready var boat: RigidBody3D = get_parent().get_node("Boat")
@onready var ocean: MeshInstance3D = get_parent().get_node("Ocean")
var field := Field.new()
var current_storm := 0.0
var state: Dictionary = {}
var phase := 0.0
var externally_driven := false
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var environment: Environment
var sky_material: ShaderMaterial
var rain: MultiMeshInstance3D
var rain_material: ShaderMaterial
var thunder: AudioStreamPlayer
var thunder_delay := -1.0
var last_lightning := -1
var audio_enabled := false
var sea_scale := 1.0
func get_wetness() -> float:
 return current_storm
func _ready() -> void:
 field.configure(seed_value)
 Ocean.model.configure(seed_value)
 sun = DirectionalLight3D.new()
 sun.name = "WeatherSun"
 sun.shadow_enabled = true
 add_child(sun)
 moon = DirectionalLight3D.new()
 moon.name = "WeatherMoon"
 moon.light_color = Color(0.56,0.68,0.90)
 add_child(moon)
 var world := WorldEnvironment.new()
 environment = Environment.new()
 environment.background_mode = Environment.BG_SKY
 environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
 environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 var sky := Sky.new()
 sky_material = ShaderMaterial.new()
 sky_material.shader = preload("res://shaders/weather_sky.gdshader")
 sky.sky_material = sky_material
 environment.sky = sky
 world.environment = environment
 add_child(world)
 _build_rain()
 thunder = AudioStreamPlayer.new()
 thunder.volume_db = -12.0
 add_child(thunder)
 state = field.sample(Vector2(boat.position.x,boat.position.z),Ocean.time)
 _apply_state(0.0)
func set_scenario(value: String) -> bool:
 if value not in ["Evolving","Calm","Breeze","Squall","Storm"]: return false
 field.scenario = value
 return true
func _build_rain() -> void:
 rain = MultiMeshInstance3D.new()
 rain.name = "ProceduralRain"
 var instances := MultiMesh.new()
 instances.transform_format = MultiMesh.TRANSFORM_3D
 instances.use_custom_data = true
 var streak := QuadMesh.new()
 streak.size = Vector2(0.008,0.28)
 instances.mesh = streak
 instances.instance_count = 1200
 var rng := RandomNumberGenerator.new()
 rng.seed = seed_value+100
 for i in instances.instance_count:
  instances.set_instance_transform(i,Transform3D.IDENTITY)
  instances.set_instance_custom_data(i,Color(rng.randf(),rng.randf(),rng.randf(),rng.randf()))
 rain.multimesh = instances
 rain.custom_aabb = AABB(Vector3(-22,-1,-22),Vector3(44,28,44))
 rain_material = ShaderMaterial.new()
 rain_material.shader = preload("res://shaders/rain.gdshader")
 rain.material_override = rain_material
 rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(rain)
func _process(delta: float) -> void:
 if not externally_driven:
  var target := field.sample(Vector2(boat.global_position.x,boat.global_position.z),Ocean.time)
  var blend := 1.0-exp(-delta/4.0)
  for key in ["storm","humidity","cloud","rain_mm_h","visibility_m","pressure_hpa","temperature_c"]:
   state[key] = lerpf(float(state.get(key,target[key])),float(target[key]),blend)
  state.wind = state.get("wind",target.wind).lerp(target.wind,1.0-exp(-delta/1.0))
  state.lightning = target.lightning
  state.lightning_event = target.lightning_event
  sea_scale = lerpf(sea_scale,target.target_sea_scale,1.0-exp(-delta/35.0))
 _apply_state(delta)
func _apply_state(delta: float) -> void:
 if state.is_empty(): return
 current_storm = state.storm
 boat.wind_world = state.wind
 ocean.storm_scale = sea_scale
 Ocean.storm_scale = sea_scale
 ocean.wetness = current_storm
 ocean.wind_direction = Vector2(state.wind.x,state.wind.z).normalized()
 ocean.wind_speed = state.wind.length()
 phase = (starting_hour-6.0)/24.0*TAU+Ocean.time/maxf(cycle_seconds,1.0)*TAU
 var day := smoothstep(-0.10,0.22,sin(phase))
 sun.rotation = Vector3(-PI+phase,-0.61,0)
 sun.light_energy = (1.15-current_storm*0.55)*day+float(state.lightning)*2.0
 sun.light_color = Color(1.0,0.95,0.85).lerp(Color(0.72,0.80,0.91),current_storm)
 moon.rotation = Vector3(sun.rotation.x+PI,sun.rotation.y,0)
 moon.light_energy = 0.25*(1.0-day)*(1.0-current_storm*0.7)
 environment.ambient_light_color = Color(0.3,0.4,0.55).lerp(Color(0.64,0.72,0.80),day)
 environment.ambient_light_energy = 0.18+day*0.32
 environment.fog_enabled = true
 environment.fog_light_color = Color(0.41,0.51,0.57).lerp(Color(0.21,0.26,0.31),current_storm)
 environment.fog_density = 3.912/maxf(200.0,state.visibility_m)
 environment.fog_sky_affect = 0.12+current_storm*0.35
 sky_material.set_shader_parameter("clock",Ocean.time)
 sky_material.set_shader_parameter("daylight",day)
 sky_material.set_shader_parameter("cloud_cover",state.cloud)
 sky_material.set_shader_parameter("storminess",current_storm)
 sky_material.set_shader_parameter("wind",ocean.wind_direction)
 sky_material.set_shader_parameter("sun_direction",sun.global_basis.z)
 sky_material.set_shader_parameter("flash",state.lightning)
 rain.visible = state.rain_mm_h>0.1
 rain_material.set_shader_parameter("clock",Ocean.time)
 rain_material.set_shader_parameter("amount",clampf(state.rain_mm_h/45.0,0,1))
 rain_material.set_shader_parameter("wind",Vector2(state.wind.x,state.wind.z))
 var camera := get_viewport().get_camera_3d()
 if camera != null: rain.global_position = camera.global_position-Vector3.UP
 if state.lightning>0.1 and int(state.lightning_event)!=last_lightning:
  last_lightning = int(state.lightning_event)
  thunder_delay = 1.0+fposmod(float(last_lightning*17+seed_value),5.0)
 if thunder_delay>=0:
  thunder_delay -= delta
  if thunder_delay<0 and audio_enabled: _play_thunder()
func _play_thunder() -> void:
 # Seeded filtered noise: one synthesized thunder sample, no downloaded sound assets.
 var rng := RandomNumberGenerator.new()
 rng.seed = seed_value+last_lightning
 var data := PackedByteArray()
 data.resize(22050*3*2)
 var low := 0.0
 for i in 22050*3:
  low = low*0.92+rng.randf_range(-1,1)*0.08
  var envelope := exp(-float(i)/22050.0*1.3)*minf(1.0,float(i)/1100.0)
  data.encode_s16(i*2,int(clampf(low*envelope*4.0,-1,1)*16000))
 var sample := AudioStreamWAV.new()
 sample.format = AudioStreamWAV.FORMAT_16_BITS
 sample.mix_rate = 22050
 sample.data = data
 thunder.stream = sample
 thunder.play()
func snapshot() -> Dictionary:
 return {"state":state.duplicate(true),"sea_scale":sea_scale,"scenario":field.scenario,"seed":seed_value,"hour":starting_hour,"cycle":cycle_seconds}
func receive_snapshot(data: Dictionary) -> void:
 externally_driven = true
 state = data.state.duplicate(true)
 sea_scale = data.sea_scale
 field.scenario = data.scenario
 starting_hour = data.hour
 cycle_seconds = data.cycle
 if seed_value!=int(data.seed):
  seed_value = int(data.seed)
  field.configure(seed_value)
  Ocean.model.configure(seed_value)
