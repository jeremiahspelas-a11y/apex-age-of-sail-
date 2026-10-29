extends RefCounted
## One yawing yard with two tension-only braces led through fixed turning blocks.
## Scene-independent SI model. Ideal belaying pins; lumped line elasticity/tail mass.
enum Hold { BELAYED, HAND, FREE, CUT }
var angle := 0.0
var angular_velocity := 0.0
var inertia := 250.0 # provisional yard+sail yaw inertia, kg m2
var bearing_damping := 45.0
var angle_stop := deg_to_rad(55.0)
var stiffness := 1500.0
var line_damping := 45.0
var tail_mass := 2.0
var hand_force_limit := 180.0
var hand_speed := 0.35
var half_span := 2.75
var spar_offset := Vector3.ZERO # spar center relative to its mast-axis yaw bearing
var lines: Array[Dictionary] = []

func configure(span: float,leads: Array[Vector3],belays: Array[Vector3],initial_angle: float = 0.0) -> void:
 assert(span > 0.0 and leads.size()==2 and belays.size()==2)
 half_span = span
 angle = clampf(initial_angle,-angle_stop,angle_stop)
 angular_velocity = 0.0
 lines.clear()
 for i in 2:
  var tail := leads[i].distance_to(belays[i])
  var length := yard_end(i).distance_to(leads[i])+tail-80.0/stiffness
  lines.append({"lead":leads[i],"belay":belays[i],"tail":tail,"length":length,"velocity":0.0,"tension":80.0,"mode":Hold.BELAYED,"pull":0.0,"hand_force":0.0,"minimum":tail+0.2,"maximum":length+8.0})

func yard_end(index: int) -> Vector3:
 return Basis(Vector3.UP,angle)*rest_end(index)

func rest_end(index: int) -> Vector3:
 return spar_offset+Vector3(-half_span if index==0 else half_span,0,0)

func set_hand(index: int,pull: float) -> void:
 if lines[index].mode == Hold.CUT: return
 lines[index].mode = Hold.HAND
 lines[index].pull = clampf(pull,-1.0,1.0) # -1 haul, +1 ease, 0 hold with finite effort

func belay(index: int) -> void:
 if lines[index].mode == Hold.CUT: return
 lines[index].mode = Hold.BELAYED
 lines[index].velocity = 0.0
 lines[index].pull = 0.0

func release(index: int) -> void:
 if lines[index].mode == Hold.CUT: return
 lines[index].mode = Hold.FREE
 lines[index].pull = 0.0

func cut(index: int) -> void:
 lines[index].mode = Hold.CUT
 lines[index].tension = 0.0
 lines[index].hand_force = 0.0

func stop_hands() -> void:
 for line: Dictionary in lines: line.pull = 0.0

func step(delta: float,wind_torque: float) -> Dictionary:
 var old_velocity := angular_velocity
 if delta <= 0.0: return {"angular_acceleration":0.0,"reactions":reactions()}
 var dt := delta/8.0
 for substep in 8:
  var torque := wind_torque-bearing_damping*angular_velocity
  for i in lines.size():
   var line: Dictionary = lines[i]
   var end := yard_end(i)
   var arm: Vector3 = end-line.lead
   var derivative := arm.normalized().dot(Vector3.UP.cross(end))
   var extension: float = arm.length()+line.tail-line.length
   line.tension = maxf(0.0,stiffness*extension+line_damping*(derivative*angular_velocity-line.velocity)) if line.mode!=Hold.CUT and extension>0.0 else 0.0
   torque -= line.tension*derivative
   line.hand_force = 0.0
   if line.mode == Hold.BELAYED or line.mode == Hold.CUT:
    line.velocity = 0.0
   else:
    if line.mode == Hold.HAND:
     line.hand_force = clampf(tail_mass*30.0*(line.pull*hand_speed-line.velocity)-line.tension,-hand_force_limit,hand_force_limit)
    var resistance := 0.5*float(line.velocity)
    line.velocity += (line.tension+line.hand_force-resistance)/tail_mass*dt
    line.length += line.velocity*dt
    if line.length < line.minimum:
     line.length = line.minimum
     line.velocity = maxf(0.0,line.velocity)
    if line.length >= line.maximum:
     line.length = line.maximum
     cut(i) # end runs out through the block; it cannot become an invisible stopper
  angular_velocity += torque/inertia*dt
  angle += angular_velocity*dt
  if absf(angle)>angle_stop:
   angle = clampf(angle,-angle_stop,angle_stop)
   if angle*angular_velocity>0.0: angular_velocity = 0.0
 return {"angular_acceleration":(angular_velocity-old_velocity)/delta,"reactions":reactions()}

func reactions() -> Array[Dictionary]:
 var result: Array[Dictionary] = []
 for i in lines.size():
  var line: Dictionary = lines[i]
  var end := yard_end(i)
  var to_yard: Vector3 = (end-line.lead).normalized()*line.tension
  var to_pin: Vector3 = (line.belay-line.lead).normalized()*line.tension
  result.append({"yard_point":end,"yard_force":-to_yard,"lead_point":line.lead,"lead_force":to_yard+to_pin,"belay_point":line.belay,"belay_force":-to_pin})
 return result

func stored_energy() -> float:
 var energy := 0.5*inertia*angular_velocity*angular_velocity
 for i in lines.size():
  var line: Dictionary = lines[i]
  if line.mode == Hold.CUT: continue
  var extension: float = maxf(0.0,yard_end(i).distance_to(line.lead)+line.tail-line.length)
  energy += 0.5*stiffness*extension*extension+0.5*tail_mass*line.velocity*line.velocity
 return energy
