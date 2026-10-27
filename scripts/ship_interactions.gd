extends Node3D
## Prototype controls. These are gameplay control states, not a complete rigging simulation.
@export var boat_path: NodePath = NodePath("../Boat")
var helm_angle := 0.0
var sail_trim := 0.4
var hatch_open := false
func steer(amount: float) -> void:
 helm_angle = clamp(helm_angle + amount, -1.0, 1.0)
 var boat := get_node_or_null(boat_path)
 if boat: boat.set("rudder_input", helm_angle)
func trim_sails(amount: float) -> void:
 sail_trim = clamp(sail_trim + amount, -1.5, 1.5)
 var boat := get_node_or_null(boat_path)
 if boat: boat.set("sheet_angle", sail_trim)
func toggle_hatch() -> void:
 hatch_open = not hatch_open
