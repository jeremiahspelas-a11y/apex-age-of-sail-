extends Node
# APEX adaptation of Ocean3D Lite wave API (MIT); original: Ocean3D-Org/ocean3d-lite
const GRAVITY := 9.8
var time := 0.0
var storm_scale := 1.0
## Direction (degrees), amplitude (m), wavelength (m). Eight scale bands, deterministic.
## Long swell overlaps local wind waves and shorter chop for non-repeating groups.
var waves := [
 Vector3(12,0.48,82), Vector3(41,0.31,48),
 Vector3(142,0.23,28), Vector3(111,0.17,17),
 Vector3(69,0.11,10), Vector3(204,0.075,6),
 Vector3(25,0.038,3.5), Vector3(163,0.018,2.2)
]
func _physics_process(delta: float) -> void:
 time += delta
func get_displacement_at(x: float,z: float,t: float) -> Vector3:
 var p := Vector3.ZERO
 for i in waves.size():
  var w: Vector3 = waves[i]
  var dir := Vector2.RIGHT.rotated(deg_to_rad(w.x))
  var k: float = TAU/w.z
  var c: float = sqrt(GRAVITY/k)
  var a: float = w.y*storm_scale*group_envelope(i,Vector2(x,z),t)
  var f: float = k*(dir.dot(Vector2(x,z))-c*t)
  p += Vector3(dir.x*a*cos(f),a*sin(f),dir.y*a*cos(f))
 return p
func get_height(x: float,z: float) -> float:
 var px := x
 var pz := z
 for i in 3:
  var d := get_displacement_at(px,pz,time)
  px = x-d.x
  pz = z-d.z
 return get_displacement_at(px,pz,time).y
## Slow, spatially traveling envelopes create distinct swell groups and calmer gaps.
## Identical function is implemented in the ocean shader for GPU/CPU consistency.
func group_envelope(i: int, pos: Vector2, t: float) -> float:
 var index: float = float(i)
 var angle: float = deg_to_rad(18.0 + index * 37.0)
 var direction := Vector2(cos(angle),sin(angle))
 var coordinate: float = direction.dot(pos)
 var slow: float = sin(coordinate * (0.012 + index * 0.0011) - t * (0.18 + index * 0.013) + index * 1.7)
 var secondary: float = sin(coordinate * 0.027 + t * 0.11 + index * 2.3)
 return clampf(0.64 + 0.29 * slow + 0.16 * secondary,0.22,1.10)

func waves_for_shader() -> PackedVector3Array:
 return PackedVector3Array(waves)
