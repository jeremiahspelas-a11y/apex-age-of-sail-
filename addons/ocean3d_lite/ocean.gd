extends Node
# APEX adaptation of Ocean3D Lite API (MIT); original: Ocean3D-Org/ocean3d-lite
const Spectrum = preload("res://scripts/sea_spectrum.gd")
var model := Spectrum.new()
var time := 0.0
var storm_scale := 1.0
var clock_authority := true
var waves: PackedVector3Array:
 get: return model.waves
func _ready() -> void:
 model.configure(17)
func _physics_process(delta: float) -> void:
 if clock_authority: time += delta
func get_displacement_at(x: float,z: float,t: float) -> Vector3:
 return model.displacement(Vector2(x,z),t,storm_scale)
func get_height(x: float,z: float) -> float:
 var p := model.parameter_at(Vector2(x,z),time,storm_scale)
 return model.displacement(p,time,storm_scale).y
func get_velocity(x: float,z: float) -> Vector3:
 return model.surface(Vector2(x,z),time,storm_scale).velocity
func waves_for_shader() -> PackedVector3Array:
 return model.waves
func group_envelope(i: int,pos: Vector2,t: float) -> float:
 return model.envelope(i,pos,t).x
