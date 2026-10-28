extends RefCounted
## Reusable wheel/drum/two-line/tiller solver. SI units: radians, seconds, N and N m.
## No nodes, meshes, input, ocean or scene references. Advance at a fixed physics step.
## Route geometry is relative to the rudder hinge; two ideal blocks sit abeam of the
## neutral tiller tip. Stiffness, inertia, stops and geometry need vessel calibration.
var tiller_length := 1.70
var block_half_span := 1.10
var wheel_angle := 0.0
var wheel_velocity := 0.0
var wheel_inertia := 20.0 # provisional kg m2
var drum_radius := 0.18
var wheel_handle_radius := 0.72
var wheel_stop := 5.0
var steering_line_stiffness := 8000.0 # effective N/m, including entire line route
var steering_line_damping := 160.0
var steering_line_pretension := 120.0
var port_line_tension := 120.0
var starboard_line_tension := 120.0
var direct_helm_control := false
var direct_helm_torque := 0.0
var rudder_velocity := 0.0
var rudder_inertia := 200.0 # provisional blade+tiller inertia, kg m2
var crew_hand_force := 0.0
var last_water_hinge_torque := 0.0
var rudder_angle := 0.0
var connected := true
var rudder_stop := deg_to_rad(32.0) # provisional mechanical stops; 8 degrees in optional whipstaff mode

func _step_whipstaff(delta: float,water_torque: float,command: float) -> float:
 # Virtual work through the sliding staff: hand force -> tiller torque.
 # A finite crew force permits stall and kickback; no angle is imposed in force mode.
 var depth := 1.15
 var length := tiller_length
 var upper := 2.35
 var ratio := length*sin(rudder_angle)/depth
 var staff_angle := -atan(ratio)
 var hand_x := -upper*sin(staff_angle)
 var derivative := upper*length*cos(rudder_angle)*cos(staff_angle)/(depth*(1.0+ratio*ratio))
 var target_angle := clampf(command,-1.0,1.0)*rudder_stop
 var target_x := upper*sin(atan(length*sin(target_angle)/depth))
 crew_hand_force = clampf(500.0*(target_x-hand_x)-120.0*derivative*rudder_velocity,-180.0,180.0) if connected else 0.0
 last_water_hinge_torque = water_torque
 var torque := crew_hand_force*derivative+water_torque-30.0*rudder_velocity
 var acceleration := torque/rudder_inertia
 var old_velocity := rudder_velocity
 rudder_velocity += acceleration*delta
 rudder_angle += rudder_velocity*delta
 if absf(rudder_angle)>rudder_stop:
  rudder_angle = clampf(rudder_angle,-rudder_stop,rudder_stop)
  if rudder_angle*rudder_velocity>0.0: rudder_velocity = 0.0
 return (rudder_velocity-old_velocity)/maxf(delta,0.000001)

func set_helm_torque(torque_nm: float) -> void:
 # Adapter for future hand/VR controls. Zero torque means a released, backdrivable wheel.
 direct_helm_control = true
 direct_helm_torque = torque_nm

func use_button_helm() -> void:
 direct_helm_control = false

func step(delta: float,water_torque: float,command: float = 0.0,use_whipstaff: bool = false) -> Dictionary:
 if delta <= 0.0:
  return {"rudder_acceleration":0.0,"wheel_acceleration":0.0}
 if use_whipstaff:
  return {"rudder_acceleration":_step_whipstaff(delta,water_torque,command),"wheel_acceleration":0.0}
 var old_rudder := rudder_velocity
 var old_wheel := wheel_velocity
 last_water_hinge_torque = water_torque
 var dt := delta/4.0
 for substep in 4:
  var tip := Vector3(-tiller_length*sin(rudder_angle),0,-tiller_length*cos(rudder_angle))
  var derivative := Vector3(-tiller_length*cos(rudder_angle),0,tiller_length*sin(rudder_angle))
  var lengths: Array[float] = []
  var derivatives: Array[float] = []
  for side in [-1.0,1.0]:
   var arm := tip-Vector3(side*block_half_span,0,-tiller_length)
   lengths.append(arm.length())
   derivatives.append(arm.normalized().dot(derivative))
  var extension_port := lengths[0]-block_half_span+drum_radius*wheel_angle
  var extension_starboard := lengths[1]-block_half_span-drum_radius*wheel_angle
  port_line_tension = maxf(0.0,steering_line_pretension+steering_line_stiffness*extension_port+steering_line_damping*(derivatives[0]*rudder_velocity+drum_radius*wheel_velocity)) if connected else 0.0
  starboard_line_tension = maxf(0.0,steering_line_pretension+steering_line_stiffness*extension_starboard+steering_line_damping*(derivatives[1]*rudder_velocity-drum_radius*wheel_velocity)) if connected else 0.0
  var target := clampf(command,-1.0,1.0)*wheel_stop
  var crew_torque := direct_helm_torque if direct_helm_control else 55.0*(target-wheel_angle)-35.0*wheel_velocity
  crew_torque = clampf(crew_torque,-180.0*wheel_handle_radius,180.0*wheel_handle_radius)
  crew_hand_force = crew_torque/wheel_handle_radius
  var wheel_torque := crew_torque+(starboard_line_tension-port_line_tension)*drum_radius-5.0*wheel_velocity
  var tiller_torque := -port_line_tension*derivatives[0]-starboard_line_tension*derivatives[1]+water_torque-30.0*rudder_velocity
  wheel_velocity += wheel_torque/wheel_inertia*dt
  rudder_velocity += tiller_torque/rudder_inertia*dt
  wheel_angle += wheel_velocity*dt
  rudder_angle += rudder_velocity*dt
  if absf(rudder_angle)>rudder_stop:
   rudder_angle = clampf(rudder_angle,-rudder_stop,rudder_stop)
   if rudder_angle*rudder_velocity>0.0: rudder_velocity = 0.0
  if absf(wheel_angle)>wheel_stop:
   wheel_angle = clampf(wheel_angle,-wheel_stop,wheel_stop)
   if wheel_angle*wheel_velocity>0.0: wheel_velocity = 0.0
 return {"rudder_acceleration":(rudder_velocity-old_rudder)/maxf(delta,0.000001),"wheel_acceleration":(wheel_velocity-old_wheel)/maxf(delta,0.000001)}

func steering_energy() -> float:
 var tip := Vector3(-tiller_length*sin(rudder_angle),0,-tiller_length*cos(rudder_angle))
 var extension_p := tip.distance_to(Vector3(-block_half_span,0,-tiller_length))-block_half_span+drum_radius*wheel_angle+steering_line_pretension/steering_line_stiffness
 var extension_s := tip.distance_to(Vector3(block_half_span,0,-tiller_length))-block_half_span-drum_radius*wheel_angle+steering_line_pretension/steering_line_stiffness
 return 0.5*wheel_inertia*wheel_velocity*wheel_velocity+0.5*rudder_inertia*rudder_velocity*rudder_velocity+0.5*steering_line_stiffness*(pow(maxf(0,extension_p),2)+pow(maxf(0,extension_s),2))
