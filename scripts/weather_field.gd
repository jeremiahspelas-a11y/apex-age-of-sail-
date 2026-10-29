extends RefCounted
## Seeded, advected weather field. Training approximation, not a forecast model.
var seed_value := 17
var scenario := "Evolving"
var noise := FastNoiseLite.new()
func configure(value: int) -> void:
 seed_value = value
 noise.seed = value
 noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
 noise.frequency = 1.0
 noise.fractal_octaves = 3
func sample(position: Vector2,t: float) -> Dictionary:
 var p := (position-Vector2(11,5)*t)/5200.0
 var front := noise.get_noise_2d(p.x,p.y)*0.5+0.5
 var humidity := clampf(0.53+0.48*noise.get_noise_2d(p.x+14.1,p.y-7.3),0.20,1.0)
 var storm := smoothstep(0.38,0.72,front)*smoothstep(0.45,0.8,humidity)
 var base_speed := 6.0+front*10.0
 match scenario:
  "Calm":
   base_speed = 1.2
   storm = 0.0
   humidity = 0.48
  "Breeze":
   base_speed = 8.0
   storm = 0.12
   humidity = 0.62
  "Squall":
   base_speed = 18.0
   storm = 0.78
   humidity = 0.91
  "Storm":
   base_speed = 27.0
   storm = 0.98
   humidity = 0.98
 var gradient := Vector2(noise.get_noise_2d(p.x+0.02,p.y)-noise.get_noise_2d(p.x-0.02,p.y),noise.get_noise_2d(p.x,p.y+0.02)-noise.get_noise_2d(p.x,p.y-0.02))*25.0
 var gust := noise.get_noise_2d(position.x/80.0-t*0.31,position.y/80.0+t*0.13)
 var heading := 1.7+noise.get_noise_2d(p.x-4,p.y+11)*0.65+gradient.angle()*0.035
 var speed := maxf(0.0,base_speed*(1.0+gust*(0.10+storm*0.25)))
 var wind := Vector3(cos(heading)*speed,0,sin(heading)*speed)
 var cloud := clampf(0.14+humidity*0.46+storm*0.46,0,1)
 var rain := 55.0*pow(maxf(0.0,(storm-0.18)/0.82),2.5)
 var visibility := lerpf(24000.0,550.0,pow(storm,1.7))
 var bucket := int(floor(t/11.0))
 var event_hash := fposmod(sin(float(bucket*73+seed_value*19))*43758.5453,1.0)
 var flash := 0.0
 if storm>0.72 and event_hash>0.63:
  var age := fposmod(t,11.0)
  flash = maxf(0.0,1.0-age/0.15)+maxf(0.0,1.0-absf(age-0.28)/0.08)*0.6
 return {"wind":wind,"storm":storm,"humidity":humidity,"cloud":cloud,"rain_mm_h":rain,"visibility_m":visibility,"pressure_hpa":1020.0-25.0*storm+gradient.length(),"temperature_c":21.0-10.0*storm,"lightning":flash,"lightning_event":bucket,"target_sea_scale":0.24+0.0065*speed*speed}
