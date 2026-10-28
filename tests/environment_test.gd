extends SceneTree
const Sea = preload("res://scripts/sea_spectrum.gd")
const Atmosphere = preload("res://scripts/weather_field.gd")
const Hydro = preload("res://scripts/hull_hydrostatics.gd")
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok:
  failures.append(message)
  push_error(message)
func flat(_x: float,_z: float) -> float: return 0.0
func current(_x: float,_z: float) -> Vector3: return Vector3.RIGHT
func run() -> void:
 var a := Sea.new()
 var b := Sea.new()
 a.configure(17)
 b.configure(17)
 check(a.waves==b.waves and a.phases==b.phases,"Same sea seed must reproduce directions, amplitudes and phases")
 b.configure(18)
 check(a.phases!=b.phases,"Different sea seeds must change phase relationships")
 var minimum := 100.0
 var maximum := -100.0
 for scale in [0.25,1.0,4.0]:
  for x in range(-5,6):
   for z in range(-5,6):
    var p := Vector2(x*7.31,z*8.17)
    var s := a.surface(p,43.5,scale)
    check(is_finite(s.height) and s.normal.is_finite() and s.velocity.is_finite(),"Sea state must remain finite")
    check(s.jacobian>0.0,"Bounded wave steepness must prevent horizontal folding")
    check(Vector2(s.position.x,s.position.z).distance_to(p)<0.12,"Inverse surface coordinates must converge")
    minimum = minf(minimum,s.height)
    maximum = maxf(maximum,s.height)
 var p := Vector2(17.3,-23.8)
 var eps := 0.03
 var dx: float = (a.surface(p+Vector2(eps,0),12.0).height-a.surface(p-Vector2(eps,0),12.0).height)/(2.0*eps)
 var dz: float = (a.surface(p+Vector2(0,eps),12.0).height-a.surface(p-Vector2(0,eps),12.0).height)/(2.0*eps)
 check(a.surface(p,12.0).normal.dot(Vector3(-dx,1,-dz).normalized())>0.999,"Analytic sea normal must agree with finite-difference surface slope")
 check(maximum-minimum>1.0,"Crossing wave groups must produce uneven elevations")
 var weather := Atmosphere.new()
 weather.configure(17)
 var first := weather.sample(Vector2.ZERO,0.0)
 check(first==weather.sample(Vector2.ZERO,0.0),"Weather queries must be deterministic without mutating RNG state")
 var later := weather.sample(Vector2(12000,-4000),900.0)
 check(first.wind.distance_to(later.wind)>0.1,"Spatial weather and gusts must evolve")
 weather.scenario = "Calm"
 var calm := weather.sample(Vector2.ZERO,0.0)
 weather.scenario = "Storm"
 var storm := weather.sample(Vector2.ZERO,0.0)
 check(storm.wind.length()>calm.wind.length()*10 and storm.rain_mm_h>calm.rain_mm_h,"Scenario must couple wind, rain and visibility")
 check(storm.visibility_m<calm.visibility_m and storm.pressure_hpa<calm.pressure_hpa,"Storm field must lower visibility and pressure")
 var hull := Hydro.new()
 hull.build_box(Vector3(4,2,8))
 var moving_water := hull.evaluate(Transform3D.IDENTITY,flat,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO,current)
 check(moving_water.drag.x>1000.0,"Water resistance must respond to water velocity relative to the hull")
 var matched := hull.evaluate(Transform3D.IDENTITY,flat,Vector3.ZERO,Vector3.RIGHT,Vector3.ZERO,current)
 check(matched.drag.length()<0.01,"Hull moving with uniform water must have no relative-flow damping")
 print("SEA RANGE: ",minimum," to ",maximum," m; storm wind ",storm.wind.length()," m/s")
 if failures.is_empty(): print("APEX ENVIRONMENT TEST PASS: seeded sea, inversion, normals, nonfolding waves, weather coupling and relative water flow")
 quit(0 if failures.is_empty() else 1)
