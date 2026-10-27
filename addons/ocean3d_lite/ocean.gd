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
 for w in waves:
  var dir := Vector2.RIGHT.rotated(deg_to_rad(w.x))
  var k: float = TAU/w.z
  var c: float = sqrt(GRAVITY/k)
  var a: float = w.y*storm_scale
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
func waves_for_shader() -> PackedVector3Array:
 return PackedVector3Array(waves)
