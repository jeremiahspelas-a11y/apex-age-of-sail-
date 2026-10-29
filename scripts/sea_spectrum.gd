extends RefCounted
## Seeded directional swell and wind waves. Identical field feeds CPU and GPU.
const COUNT := 16
const GRAVITY := 9.8
var waves := PackedVector3Array()
var phases := PackedFloat32Array()
var seed_value := 17
func configure(seed_number: int) -> void:
 seed_value = seed_number
 var rng := RandomNumberGenerator.new()
 rng.seed = seed_number
 waves.clear()
 phases.clear()
 for i in COUNT:
  var wavelength: float = [137.0,93.0,61.0,109.0][i] if i<4 else 36.0*pow(0.778,float(i-4))
  var direction := rng.randf_range(18.0,72.0) if i<4 else rng.randf_range(58.0,148.0)
  var amplitude: float = [0.30,0.21,0.13,0.11][i] if i<4 else 0.16*pow(wavelength/36.0,0.88)
  waves.append(Vector3(direction,amplitude,wavelength))
  phases.append(rng.randf_range(0,TAU))
func chop_for(scale: float) -> float:
 var steepness := 0.0
 for wave in waves: steepness += TAU/wave.z*wave.y*scale*1.12
 return minf(0.55,0.62/maxf(steepness,0.001))
func envelope(i: int,p: Vector2,t: float) -> Vector3:
 var index := float(i)
 var direction := Vector2.RIGHT.rotated(deg_to_rad(23.0+index*41.0))
 var k := 0.009+index*0.0007
 var a := direction.dot(p)*k-t*(0.065+index*0.004)+index*1.71
 var b := Vector2(-direction.y,direction.x).dot(p)*0.021+t*0.053+index*2.31
 var value := 0.72+0.25*sin(a)+0.13*sin(b)
 var gradient := direction*(0.25*cos(a)*k)+Vector2(-direction.y,direction.x)*(0.13*cos(b)*0.021)
 return Vector3(value,gradient.x,gradient.y)
func displacement(p: Vector2,t: float,scale: float = 1.0) -> Vector3:
 var result := Vector3.ZERO
 var chop := chop_for(scale)
 for i in waves.size():
  var w := waves[i]
  var direction := Vector2.RIGHT.rotated(deg_to_rad(w.x))
  var k := TAU/w.z
  var phase := k*direction.dot(p)-sqrt(GRAVITY*k)*t+phases[i]
  var amplitude := w.y*scale*envelope(i,p,t).x
  result += Vector3(direction.x*chop*amplitude*cos(phase),amplitude*sin(phase),direction.y*chop*amplitude*cos(phase))
 return result
func parameter_at(world: Vector2,t: float,scale: float) -> Vector2:
 var p := world
 for iteration in 4:
  var d := displacement(p,t,scale)
  p = world-Vector2(d.x,d.z)
 return p
func surface(world: Vector2,t: float,scale: float = 1.0) -> Dictionary:
 var p := parameter_at(world,t,scale)
 var dx := Vector3.RIGHT
 var dz := Vector3.BACK
 var position := Vector3(p.x,0,p.y)
 var velocity := Vector3.ZERO
 var chop := chop_for(scale)
 for i in waves.size():
  var w := waves[i]
  var direction := Vector2.RIGHT.rotated(deg_to_rad(w.x))
  var k := TAU/w.z
  var omega := sqrt(GRAVITY*k)
  var phase := k*direction.dot(p)-omega*t+phases[i]
  var s := sin(phase)
  var c := cos(phase)
  var env := envelope(i,p,t)
  var a := w.y*scale*env.x
  var ax := w.y*scale*env.y
  var az := w.y*scale*env.z
  position += Vector3(direction.x*chop*a*c,a*s,direction.y*chop*a*c)
  dx += Vector3(direction.x*chop*(ax*c-a*s*k*direction.x),ax*s+a*c*k*direction.x,direction.y*chop*(ax*c-a*s*k*direction.x))
  dz += Vector3(direction.x*chop*(az*c-a*s*k*direction.y),az*s+a*c*k*direction.y,direction.y*chop*(az*c-a*s*k*direction.y))
  var index := float(i)
  var d := Vector2.RIGHT.rotated(deg_to_rad(23.0+index*41.0))
  var e1 := d.dot(p)*(0.009+index*0.0007)-t*(0.065+index*0.004)+index*1.71
  var e2 := Vector2(-d.y,d.x).dot(p)*0.021+t*0.053+index*2.31
  var at := w.y*scale*(-0.25*cos(e1)*(0.065+index*0.004)+0.13*cos(e2)*0.053)
  velocity += Vector3(direction.x*chop*(at*c+a*omega*s),at*s-a*omega*c,direction.y*chop*(at*c+a*omega*s))
 return {"height":position.y,"position":position,"normal":dz.cross(dx).normalized(),"jacobian":dx.x*dz.z-dx.z*dz.x,"velocity":velocity}
