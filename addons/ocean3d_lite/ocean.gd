extends Node
# APEX adaptation of Ocean3D Lite wave API (MIT); original: Ocean3D-Org/ocean3d-lite
const GRAVITY := 9.8
var time := 0.0
var storm_scale := 1.0
var waves := [Vector3(0,0.31,34), Vector3(140,0.19,19), Vector3(65,0.12,10), Vector3(205,0.07,5)]
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
