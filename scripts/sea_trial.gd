extends Node3D
@onready var boat: RigidBody3D = $Boat
@onready var camera: Camera3D = $Camera3D
var rudder := 0.0
var reef := 0.65
var sheet := 0.4
var orbit := 0.65
var pitch := 0.40
var dragging := false
var active_walk_buttons: Dictionary = {}
var status: Label
var _last_boat_position := Vector3.ZERO
var _observed_speed := 0.0
var flooding_system: Node
var selected_compartment := 1
func _ready() -> void:
 var canvas := CanvasLayer.new()
 add_child(canvas)
 _last_boat_position = boat.global_position
 flooding_system = boat.get_node_or_null("ShipIntegrity")
 status = Label.new()
 status.position = Vector2(16,12)
 canvas.add_child(status)
 var root := Control.new()
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.mouse_filter = Control.MOUSE_FILTER_IGNORE
 canvas.add_child(root)
 var sailing := GridContainer.new()
 sailing.columns = 4
 sailing.set_anchors_preset(Control.PRESET_TOP_RIGHT)
 sailing.anchor_left = 1.0
 sailing.anchor_right = 1.0
 sailing.offset_left = -356.0
 sailing.offset_right = -8.0
 sailing.offset_top = 12.0
 sailing.mouse_filter = Control.MOUSE_FILTER_PASS
 root.add_child(sailing)
 var actions := [["Port","port"],["Starboard","starboard"],["Reef +","raise"],["Reef -","lower"],["Sheet -","sheet_l"],["Sheet +","sheet_r"],["Door","door"],["Hatch","hatch"]]
 for action in actions:
  var btn := Button.new()
  btn.text = action[0]
  btn.custom_minimum_size = Vector2(84,54)
  sailing.add_child(btn)
  btn.pressed.connect(command.bind(action[1]))
 var damage_actions := HBoxContainer.new()
 damage_actions.set_anchors_preset(Control.PRESET_TOP_RIGHT)
 damage_actions.offset_left = -356.0
 damage_actions.offset_right = -8.0
 damage_actions.offset_top = 132.0
 root.add_child(damage_actions)
 for action in [["BREACH","breach"],["PATCH","patch"],["PUMP","pump"],["ROPE CUT","rope_cut"]]:
  var damage_button := Button.new()
  damage_button.text = action[0]
  damage_button.custom_minimum_size = Vector2(84,48)
  damage_actions.add_child(damage_button)
  damage_button.pressed.connect(command.bind(action[1]))
 var walking := HBoxContainer.new()
 walking.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
 walking.offset_left = 12.0
 walking.offset_top = -78.0
 walking.offset_bottom = -12.0
 root.add_child(walking)
 for label in ["◀", "▲", "▼", "▶", "STOP"]:
  var btn := Button.new()
  btn.text = label
  btn.custom_minimum_size = Vector2(64,60)
  walking.add_child(btn)
  btn.button_down.connect(_walk_input.bind(label))
  btn.button_up.connect(_walk_release.bind(label))
 var jump := Button.new()
 jump.text = "JUMP"
 jump.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
 jump.offset_left = -92.0
 jump.offset_right = -12.0
 jump.offset_top = -78.0
 jump.offset_bottom = -12.0
 root.add_child(jump)
 jump.pressed.connect(_jump)
func _jump() -> void:
 Input.action_press("ui_accept")
 await get_tree().physics_frame
 Input.action_release("ui_accept")
func command(action: String) -> void:
 match action:
  "port": rudder = clamp(rudder-0.2,-1.0,1.0)
  "starboard": rudder = clamp(rudder+0.2,-1.0,1.0)
  "raise": reef = clamp(reef+0.1,0.0,1.0)
  "lower": reef = clamp(reef-0.1,0.0,1.0)
  "sheet_l": sheet = clamp(sheet-0.15,-1.5,1.5)
  "sheet_r": sheet = clamp(sheet+0.15,-1.5,1.5)
  "breach":
   if flooding_system != null: flooding_system.breach(selected_compartment)
  "patch":
   if flooding_system != null: flooding_system.patch(selected_compartment)
  "pump":
   if flooding_system != null: flooding_system.pump(8.0)
  "rope_cut": $Boat/Mechanisms.toggle_steering_rope()
  "door": $Boat/Mechanisms.toggle_doors()
  "hatch": $Boat/Mechanisms.toggle_hatches()
 boat.set("rudder_input",rudder)
 boat.set("reef_fraction",reef)
 boat.set("sheet_angle",sheet)
func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  match event.keycode:
   KEY_A: command("port")
   KEY_D: command("starboard")
   KEY_W: command("raise")
   KEY_S: command("lower")
   KEY_Q: command("sheet_l")
   KEY_E: command("sheet_r")
 if event is InputEventScreenTouch:
  dragging = event.pressed and event.position.x > get_viewport().get_visible_rect().size.x * 0.5
 if event is InputEventScreenDrag and dragging:
  orbit -= event.relative.x*0.004
  pitch = clamp(pitch+event.relative.y*0.003,-0.1,1.0)
 if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
  orbit -= event.relative.x*0.004
func _process(delta: float) -> void:
 if delta > 0.0001:
  _observed_speed = boat.global_position.distance_to(_last_boat_position) / delta
 _last_boat_position = boat.global_position
 var distance := 29.0
 var offset := Vector3(sin(orbit)*cos(pitch),sin(pitch)+0.42,cos(orbit)*cos(pitch))*distance
 camera.global_position = camera.global_position.lerp(boat.global_position+offset,clamp(delta*4.0,0.0,1.0))
 camera.look_at(boat.global_position+Vector3.UP*4.0)
 var tonnes: float = flooding_system.total_water_tonnes() if flooding_system != null else 0.0
 var helm := $Boat/Mechanisms
 var rope_state: String = "CONNECTED" if helm.steering_rope_intact else "CUT"
 status.text = "APEX  |  %.1f m/s  |  RUDDER %.0f deg  |  ROPE %s  |  FLOOD %.1f t" % [_observed_speed,rad_to_deg(helm.actual_rudder_angle),rope_state,tonnes]
func _walk_input(key: String) -> void:
 if key == "STOP":
  active_walk_buttons.clear()
 else:
  active_walk_buttons[key] = true
 _update_walk_vector()
func _walk_release(key: String) -> void:
 active_walk_buttons.erase(key)
 _update_walk_vector()
func _update_walk_vector() -> void:
 var player := get_node_or_null("Player")
 if player == null: return
 var axis := Vector2.ZERO
 if active_walk_buttons.has("◀"): axis.x -= 1.0
 if active_walk_buttons.has("▶"): axis.x += 1.0
 if active_walk_buttons.has("▲"): axis.y -= 1.0
 if active_walk_buttons.has("▼"): axis.y += 1.0
 player.motion_input = axis.normalized()
