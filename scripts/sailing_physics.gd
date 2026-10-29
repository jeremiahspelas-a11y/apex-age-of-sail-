extends RigidBody3D
## Stable prototype displacement model. Bow -Z, starboard +X.
const Hydrostatics = preload("res://scripts/hull_hydrostatics.gd")
const RigPressure = preload("res://scripts/rig_pressure_load.gd")
const Refit = preload("res://scripts/ship_refit.gd")
@export var force_trial := false
@export var trial_dry_mass_kg := 80000.0 # rigid assembly excluding the separately integrated fore canvas; provisional
@export var trial_center_of_mass := Vector3(0,-0.60,0)
var hydro: RefCounted
var rig_pressure: RefCounted
var hydro_report: Dictionary = {}
var rig_report: Dictionary = {}
var trial_ticks := 0
var _trial_requested := false
var _last_trial_mass := -1.0
var _last_trial_com := Vector3.INF
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
var _yaw_velocity := 0.0
var last_rudder_torque_nm := 0.0
var effective_rudder_angle := 0.0
@export var yaw_inertia_kg_m2 := 540000.0
@export var yaw_damping_nm_per_rad_s := 145000.0
@export var rudder_lift_slope := 3.1
@export var rudder_stern_lever_m := 6.8
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
 if force_trial:
  force_trial = false
  set_force_trial.call_deferred(true)
func _height(x: float,z: float) -> float:
 if ocean != null and ocean.has_method("get_height"):
  return ocean.get_height(x,z)
 return 0.0
func _physics_process(delta: float) -> void:
 elapsed += delta
 if force_trial:
  _update_trial_mass()
  return
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
  # Helm wheel -> drum -> rope -> rudder -> lateral water force -> yaw moment.
  # This is an inertia-integrated steering slice while hull heave remains kinematic.
  var mechanism := get_node_or_null("Mechanisms")
  effective_rudder_angle = float(mechanism.rudder_angle_for_physics()) if mechanism != null else 0.0
  var flow_squared: float = _controlled_speed * _controlled_speed
  var rudder_cl: float = rudder_lift_slope * sin(effective_rudder_angle)
  var lateral_force: float = 0.5 * water_density * rudder_area_m2 * flow_squared * rudder_cl
  last_rudder_torque_nm = lateral_force * rudder_stern_lever_m
  var yaw_acceleration: float = (last_rudder_torque_nm - yaw_damping_nm_per_rad_s * _yaw_velocity) / yaw_inertia_kg_m2
  _yaw_velocity = clampf(_yaw_velocity + yaw_acceleration * delta,-0.24,0.24)
  _controlled_heading += _yaw_velocity * delta
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

func prepare_force_trial() -> void:
 if hydro == null:
  hydro = Hydrostatics.new()
  hydro.build_from_sections(Refit.hull_profile,AABB(Vector3(-3.45,-2.2,-13),Vector3(6.9,3.11,26.2)))
  rig_pressure = RigPressure.new()
  rig_pressure.bind(get_node("Mechanisms"))

func set_force_trial(enabled: bool) -> void:
 # Transition once inside the direct-state callback; no transform driving while active.
 prepare_force_trial()
 force_trial = enabled
 trial_ticks = 0
 _trial_requested = true
 freeze = not enabled
 axis_lock_angular_x = not enabled
 axis_lock_angular_z = not enabled
 if enabled:
  get_node("Mechanisms").reset_braces()
  get_node("Mechanisms").set_cloth_active(true)
  linear_damp = 0.0
  angular_damp = 0.0
  _last_trial_mass = -1.0
  _update_trial_mass()
 else:
  get_node("Mechanisms").set_cloth_active(false)
  mass = water_density*hull_displacement_m3
  inertia = Vector3.ZERO
  center_of_mass = Vector3(0,-1.2,0)
  linear_damp = 0.12
  angular_damp = 1.5
  _controlled_heading = rotation.y
  _controlled_speed = 0.0
  _yaw_velocity = 0.0
  linear_velocity = Vector3.ZERO
  angular_velocity = Vector3.ZERO
 sleeping = false
 print("APEX FORCE TRIAL ","ON" if enabled else "OFF")

func _update_trial_mass() -> void:
 var total := trial_dry_mass_kg
 var weighted := trial_center_of_mass*total
 var integrity := get_node_or_null("ShipIntegrity")
 if integrity != null:
  for compartment: Dictionary in integrity.compartments:
   var water_mass: float = float(compartment.water)*water_density
   total += water_mass
   weighted += Vector3(compartment.x,-0.8,compartment.z)*water_mass
 var next_com := weighted/total
 if absf(total-_last_trial_mass) < 0.01 and next_com.is_equal_approx(_last_trial_com): return
 mass = total
 center_of_mass = next_com
 _last_trial_com = next_com
 # Provisional box inertia, exposed mass/CG; replace with a surveyed mass ledger later.
 inertia = Vector3(total*(26.2*26.2+4.5*4.5)/12.0,total*(26.2*26.2+6.9*6.9)/12.0,total*(6.9*6.9+4.5*4.5)/12.0)
 _last_trial_mass = total

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
 if not force_trial or hydro == null: return
 trial_ticks += 1
 var reset_cloth := _trial_requested
 if _trial_requested:
  var initial := state.transform
  initial.basis = Basis(Vector3.UP,rotation.y)
  initial.origin.y = hydro.equilibrium_height(mass+get_node("Mechanisms").cloth.canvas_mass,center_of_mass)+_height(initial.origin.x,initial.origin.z)
  state.transform = initial
  state.linear_velocity = Vector3.ZERO
  state.angular_velocity = Vector3.ZERO
  _trial_requested = false
 var flow_at := Callable(ocean,"get_velocity") if ocean!=null and ocean.has_method("get_velocity") else Callable()
 hydro_report = hydro.evaluate(state.transform,Callable(self,"_height"),center_of_mass,state.linear_velocity,state.angular_velocity,flow_at)
 var cloth_load: Dictionary = get_node("Mechanisms").step_cloth(state.step,state.transform,wind_world,reef_fraction,state.transform*center_of_mass,reset_cloth)
 rig_report = rig_pressure.evaluate(state.transform*center_of_mass,wind_world,state.linear_velocity,state.angular_velocity,reef_fraction,state.transform,cloth_load)
 state.apply_central_force(hydro_report.buoyancy+hydro_report.drag+rig_report.force)
 state.apply_torque(hydro_report.buoyancy_torque+hydro_report.drag_torque+rig_report.torque)
 # A local-flow pressure approximation acts on the actual rudder angle, never raw helm input.
 var mechanism := get_node_or_null("Mechanisms")
 if mechanism != null:
  var yard_acceleration: float = mechanism.step_loaded_braces(state.step,rig_report.brace_torque)
  # Wind torque above is counted once. Internal brace forces cancel; subtract
  # the relative yard's angular-momentum change from the assembled hull.
  state.apply_torque(-state.transform.basis.y*mechanism.brace.inertia*yard_acceleration)
  effective_rudder_angle = mechanism.actual_rudder_angle
  var point := state.transform*Vector3(0,-1.0,13.45)
  var flow := state.linear_velocity+state.angular_velocity.cross(point-state.transform*center_of_mass)
  var local_flow := state.transform.basis.transposed()*flow
  var force := state.transform.basis*rudder_water_force(local_flow,effective_rudder_angle)
  state.apply_central_force(force)
  var hinge_moment := (Vector3(0,0,0.30)).cross(state.transform.basis.transposed()*force).y
  var steering: Dictionary = mechanism.step_loaded_steering(state.step,hinge_moment)
  state.apply_torque((point-state.transform*center_of_mass).cross(force)-state.transform.basis.y*mechanism.rudder_inertia*steering.rudder_acceleration-state.transform.basis.z*mechanism.wheel_inertia*steering.wheel_acceleration)
 if mechanism!=null and trial_ticks%15==0:
  for line: Dictionary in mechanism.brace.lines:
   if line.mode==1 and absf(line.pull)>0.1:
    var brace_sample: Dictionary = mechanism.brace_report()
    brace_sample["physics_tick"] = trial_ticks
    print("APEX BRACE SAMPLE ",JSON.stringify(brace_sample))
    break
  for line: Dictionary in mechanism.cloth.lines:
   if line.mode==1 and absf(line.pull)>0.1:
    var cloth_sample: Dictionary = mechanism.cloth_report()
    cloth_sample["physics_tick"] = trial_ticks
    print("APEX CLOTH SAMPLE ",JSON.stringify(cloth_sample))
    break
 if trial_ticks == 120:
  print("APEX FORCE SAMPLE ",JSON.stringify(force_trial_report()))

func force_trial_report() -> Dictionary:
 return {"mass_kg":mass,"submerged_m3":hydro_report.get("volume",0.0),"buoyancy_n":hydro_report.get("buoyancy",Vector3.ZERO).y,"position":[global_position.x,global_position.y,global_position.z],"speed_mps":linear_velocity.length(),"brace":get_node("Mechanisms").brace_report(),"cloth":get_node("Mechanisms").cloth_report(),"finite":global_position.is_finite() and linear_velocity.is_finite()}

func rudder_water_force(local_velocity: Vector3,angle: float) -> Vector3:
 var planar := Vector3(local_velocity.x,0,local_velocity.z)
 var speed := planar.length()
 if speed < 0.001: return Vector3.ZERO
 var incoming := -planar/speed
 var normal := Basis(Vector3.UP,angle)*Vector3.RIGHT
 var incidence := clampf(incoming.dot(normal),-1.0,1.0)
 var alpha := asin(incidence)
 var lift_direction := (normal-incoming*incidence).normalized()
 var dynamic_pressure := 0.5*water_density*speed*speed*rudder_area_m2
 var lift := lift_direction*(1.1*sin(2.0*alpha))
 var drag := incoming*(0.08+1.2*incidence*incidence)
 # Lift is perpendicular to flow; drag dissipates body motion rather than adding energy.
 return (lift+drag)*dynamic_pressure
