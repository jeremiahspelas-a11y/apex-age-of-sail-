extends RigidBody3D
## Stable prototype displacement model. Bow -Z, starboard +X.
@export var sail_area_m2 := 95.0
@export var sail_drag_coefficient := 0.6
@export var water_density := 1025.0
@export var hull_displacement_m3 := 34.0
@export var longitudinal_drag := 115.0
@export var lateral_drag := 1650.0
@export var rudder_area_m2 := 2.5
@export var wind_world := Vector3(8.0, 0.0, -3.0)
@export_range(-1.0, 1.0) var rudder_input := 0.0
@export_range(0.0, 1.0) var reef_fraction := 1.0
@export_range(-1.5, 1.5) var sheet_angle := 0.4
@export var ocean_path: NodePath
@export var waterline_offset := 0.75
@export var heave_frequency := 0.55
@export var heave_damping_ratio := 1.1
@export var roll_pitch_frequency := 0.6
@export var roll_pitch_damping := 1.4
var ocean: Node
var elapsed := 0.0
var _controlled_heading := 0.0
var _controlled_speed := 0.0
var _visual_roll := 0.0
var _visual_pitch := 0.0
var probes := [Vector3(-1.5,-0.7,-5.0), Vector3(1.5,-0.7,-5.0), Vector3(-1.5,-0.7,5.0), Vector3(1.5,-0.7,5.0)]
func _ready() -> void:
 ocean = get_node_or_null(ocean_path)
 mass = water_density * hull_displacement_m3
 axis_lock_angular_x = true
 axis_lock_angular_z = true
 linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
 angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
 linear_damp = 0.12
 angular_damp = 1.5
 freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
 freeze = true
 # Start on a broad reach relative to the weather's initial wind, not trapped in irons.
 # Weather seed 17 starts with wind traveling roughly toward +Z.
 _controlled_heading = 1.15
 rotation.y = _controlled_heading
 center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
 center_of_mass = Vector3(0,-1.2,0)
func _height(x: float,z: float) -> float:
 if ocean != null and ocean.has_method("get_height"):
  return ocean.get_height(x,z)
 return 0.0
func _physics_process(delta: float) -> void:
 elapsed += delta
 if freeze:
  var integrity := get_node_or_null("ShipIntegrity")
  var flooding: float = integrity.flooded_fraction() if integrity != null else 0.0
  var target_height := _height(global_position.x,global_position.z) + waterline_offset - flooding * 2.9
  var p := global_position
  p.y = lerpf(p.y,target_height,clampf(delta * 2.2,0.0,1.0))
  # Four hull probes recover the wave-driven pitching and rolling used in Dragon's Rest.
  var stern_port: Vector3 = global_transform * probes[2]
  var stern_starboard: Vector3 = global_transform * probes[3]
  var bow_port: Vector3 = global_transform * probes[0]
  var bow_starboard: Vector3 = global_transform * probes[1]
  var front_height: float = (_height(bow_port.x,bow_port.z) + _height(bow_starboard.x,bow_starboard.z)) * 0.5
  var back_height: float = (_height(stern_port.x,stern_port.z) + _height(stern_starboard.x,stern_starboard.z)) * 0.5
  var port_height: float = (_height(bow_port.x,bow_port.z) + _height(stern_port.x,stern_port.z)) * 0.5
  var starboard_height: float = (_height(bow_starboard.x,bow_starboard.z) + _height(stern_starboard.x,stern_starboard.z)) * 0.5
  var target_pitch: float = clampf(atan2(back_height-front_height,10.0),-0.14,0.14)
  var target_roll: float = clampf(atan2(port_height-starboard_height,3.0),-0.20,0.20)
  _visual_pitch = lerpf(_visual_pitch,target_pitch,clampf(delta*1.7,0.0,1.0))
  _visual_roll = lerpf(_visual_roll,target_roll,clampf(delta*1.7,0.0,1.0))
  # Apparent wind rather than unconditional forward thrust: square rig cannot sail in irons.
  var bow: Vector3 = -global_basis.z.normalized()
  var relative_wind: Vector3 = wind_world - bow * _controlled_speed
  var wind_speed: float = relative_wind.length()
  var incoming: Vector3 = -relative_wind.normalized() if wind_speed > 0.01 else Vector3.ZERO
  var off_bow: float = rad_to_deg(acos(clampf(bow.dot(incoming),-1.0,1.0))) if wind_speed > 0.01 else 0.0
  var point_of_sail: float = smoothstep(48.0,95.0,off_bow) * (1.0 - 0.22 * smoothstep(155.0,180.0,off_bow))
  var trim_efficiency: float = clampf(1.0 - absf(absf(sheet_angle) - 0.55) * 0.42,0.25,1.0)
  var target_speed: float = wind_speed * 0.18 * reef_fraction * point_of_sail * trim_efficiency
  target_speed *= (1.0 - flooding * 0.75)
  _controlled_speed = move_toward(_controlled_speed,target_speed,delta * (0.20 if target_speed >= _controlled_speed else 0.37))
  _controlled_heading += rudder_input * _controlled_speed * delta * 0.045
  rotation = Vector3(_visual_pitch,_controlled_heading,_visual_roll)
  global_position = p + (-global_basis.z * _controlled_speed * delta)
  return
 var basis := global_transform.basis
 var bow := -basis.z.normalized()
 var starboard := basis.x.normalized()
 var forward_speed := linear_velocity.dot(bow)
 var lateral_speed := linear_velocity.dot(starboard)
 var apparent := wind_world - linear_velocity
 var sail_normal := (starboard * cos(sheet_angle) + bow * sin(sheet_angle)).normalized()
 var normal_component := apparent.dot(sail_normal)
 var sail_force: Vector3 = sail_normal * normal_component * abs(normal_component) * 0.5 * 1.225 * sail_area_m2 * reef_fraction * sail_drag_coefficient
 apply_central_force(sail_force)
 apply_central_force(-bow * forward_speed * abs(forward_speed) * longitudinal_drag)
 apply_central_force(-starboard * lateral_speed * abs(lateral_speed) * lateral_drag)
 var rudder_flow: float = abs(forward_speed)
 var rudder_force: Vector3 = starboard * rudder_input * rudder_flow * rudder_flow * 0.5 * water_density * rudder_area_m2 * 0.65
 apply_force(rudder_force, basis * Vector3(0,-0.7,5.5))
 var surface := 0.0
 var front := 0.0
 var back := 0.0
 var left := 0.0
 var right := 0.0
 for probe in probes:
  var wp: Vector3 = global_transform * probe
  var h := _height(wp.x,wp.z)
  surface += h * 0.25
  if probe.z < 0.0: front += h * 0.5
  else: back += h * 0.5
  if probe.x < 0.0: left += h * 0.5
  else: right += h * 0.5
 var omega := TAU * heave_frequency
 var target_y := surface + waterline_offset
 var accel_y := omega * omega * (target_y - global_position.y) - 2.0 * heave_damping_ratio * omega * linear_velocity.y
 apply_central_force(Vector3.UP * mass * (9.81 + clampf(accel_y,-12.0,12.0)))
 var wave_roll := atan2(right-left,3.0)
 var wave_pitch := atan2(front-back,10.0)
 var up := basis.y.normalized()
 var target_up := Vector3(wave_roll,1.0,wave_pitch).normalized()
 var correction_axis := up.cross(target_up)
 var tilt_omega := TAU * roll_pitch_frequency
 var angular_correction := correction_axis * tilt_omega * tilt_omega - Vector3(angular_velocity.x,0.0,angular_velocity.z) * (2.0 * roll_pitch_damping * tilt_omega)
 apply_torque(angular_correction * mass * 0.45)
