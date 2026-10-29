extends RefCounted
## Controller-independent grip math. Outputs bounded torque/rate, never imposed poses.
var wheel_held := false
var wheel_target := 0.0
var previous_angle := 0.0
var brace_held := -1
var previous_hand := Vector3.ZERO
func grab_wheel(hand_in_wheel: Vector3,angle: float,radius: float = 0.72) -> bool:
 var planar := Vector2(hand_in_wheel.x,hand_in_wheel.y)
 if absf(planar.length()-radius)>0.25 or absf(hand_in_wheel.z)>0.30: return false
 wheel_held = true
 wheel_target = angle
 previous_angle = atan2(hand_in_wheel.y,hand_in_wheel.x)
 return true
func wheel_torque(hand_in_wheel: Vector3,angle: float,velocity: float) -> float:
 if not wheel_held: return 0.0
 var current := atan2(hand_in_wheel.y,hand_in_wheel.x)
 # From aft looking forward, clockwise hand travel is negative in XY.
 wheel_target -= angle_difference(previous_angle,current)
 previous_angle = current
 return clampf(65.0*(wheel_target-angle)-12.0*velocity,-129.6,129.6)
func grab_brace(index: int,hand: Vector3,pin: Vector3) -> bool:
 if hand.distance_to(pin)>0.4: return false
 brace_held = index
 previous_hand = hand
 return true
func brace_pull(hand: Vector3,toward_block: Vector3,delta: float) -> float:
 if brace_held<0 or delta<=0.0: return 0.0
 var speed := (hand-previous_hand).dot(toward_block.normalized())/delta
 previous_hand = hand
 return clampf(speed/0.35,-1.0,1.0)
func release() -> void:
 wheel_held = false
 brace_held = -1
