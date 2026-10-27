extends Node3D
## Deterministic weather cycle, affecting both wind force and the rendered ocean.
@export var cycle_seconds := 240.0
@export var seed_value := 17
@export var max_wind_mps := 17.0
@onready var boat: RigidBody3D = get_parent().get_node("Boat")
@onready var ocean: MeshInstance3D = get_parent().get_node("Ocean")
var phase := 0.0
var current_storm := 0.0
func get_wetness() -> float: return current_storm
var sun: DirectionalLight3D
var sky_material: ProceduralSkyMaterial
func _ready() -> void:
 sun=DirectionalLight3D.new()
 sun.name="WeatherSun"
 add_child(sun)
 var world=WorldEnvironment.new()
 world.name="WeatherEnvironment"
 var env=Environment.new()
 env.background_mode=Environment.BG_SKY
 var sky=Sky.new()
 sky_material=ProceduralSkyMaterial.new()
 sky.sky_material=sky_material
 env.sky=sky
 env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 world.environment=env
 add_child(world)
func _process(delta: float) -> void:
 phase += delta / max(cycle_seconds,1.0) * TAU
 var storm=clamp(0.5+0.5*sin(phase+float(seed_value)),0.0,1.0)
 current_storm=storm
 var gust=0.8+0.2*sin(phase*7.0+2.0)
 var heading=phase*0.23+float(seed_value)*0.1
 var speed=(5.0+storm*max_wind_mps)*gust
 boat.wind_world=Vector3(cos(heading)*speed,0.0,sin(heading)*speed)
 ocean.storm_scale=0.7+storm*2.0
 ocean.wetness=storm
 sun.rotation_degrees=Vector3(-50.0+storm*20.0,-35.0,0.0)
 sun.light_energy=1.2-storm*0.65
 sky_material.sky_top_color=Color(0.16,0.38,0.65).lerp(Color(0.09,0.12,0.18),storm)
 sky_material.sky_horizon_color=Color(0.58,0.69,0.73).lerp(Color(0.28,0.32,0.35),storm)
