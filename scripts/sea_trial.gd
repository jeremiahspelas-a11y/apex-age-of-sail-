extends Node3D
@onready var boat: RigidBody3D = $Boat
@onready var camera: Camera3D = $Camera3D
var rudder := 0.0
var reef := 0.65
var sheet := 0.4
var orbit := 0.65
var pitch := 0.40
var dragging := false
var god_mode := false
var photo_mode := false
var fly_speed := 9.0
var fly_buttons: Dictionary = {}
var stick_move := Vector2.ZERO
var stick_look := Vector2.ZERO
var left_touch := -1
var right_touch := -1
var left_center := Vector2.ZERO
var right_center := Vector2.ZERO
var stick_radius := 58.0
var stick_canvas: Control
var fly_yaw := 0.0
var fly_pitch := 0.0
var photo_ui: Control
var restore_hud_button: Button
var fly_ui: Control
var normal_ui: Control
var hud_layer: CanvasLayer
var active_walk_buttons: Dictionary = {}
var status: Label
var _last_boat_position := Vector3.ZERO
var _observed_speed := 0.0
var flooding_system: Node
var selected_compartment := 1
func _ready() -> void:
 var canvas := CanvasLayer.new()
 add_child(canvas)
 hud_layer = canvas
 _last_boat_position = boat.global_position
 flooding_system = boat.get_node_or_null("ShipIntegrity")
 status = Label.new()
 status.position = Vector2(16,12)
 canvas.add_child(status)
 var root := Control.new()
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.mouse_filter = Control.MOUSE_FILTER_IGNORE
 canvas.add_child(root)
 normal_ui = root
 _build_fly_controls(canvas)
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
func _build_fly_controls(canvas: CanvasLayer) -> void:
 var toggle := Button.new()
 toggle.text = "FLY / WALK"
 toggle.position = Vector2(12, 56)
 toggle.custom_minimum_size = Vector2(130, 48)
 canvas.add_child(toggle)
 toggle.pressed.connect(_toggle_fly)
 var fly_root := Control.new()
 fly_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 fly_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
 canvas.add_child(fly_root)
 fly_ui = fly_root
 fly_ui.visible = false
 var sticks := Control.new()
 sticks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 sticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
 fly_root.add_child(sticks)
 stick_canvas = sticks
 sticks.draw.connect(_draw_sticks)
 var vertical := VBoxContainer.new()
 vertical.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
 vertical.offset_left = -100.0
 vertical.offset_top = -170.0
 fly_root.add_child(vertical)
 for item in [["UP","up"],["DOWN","down"]]:
  var b := Button.new()
  b.text = item[0]
  b.custom_minimum_size = Vector2(88,65)
  vertical.add_child(b)
  b.button_down.connect(_fly_press.bind(item[1]))
  b.button_up.connect(_fly_release.bind(item[1]))
 var photo := Button.new()
 photo.text = "HIDE HUD"
 photo.position = Vector2(12, 110)
 photo.custom_minimum_size = Vector2(130, 46)
 canvas.add_child(photo)
 photo.pressed.connect(_toggle_photo)
 photo_ui = photo
 var restore := Button.new()
 restore.text = "SHOW HUD"
 restore.position = Vector2(12, 12)
 restore.custom_minimum_size = Vector2(130, 48)
 restore.visible = false
 canvas.add_child(restore)
 restore.pressed.connect(_toggle_photo)
 restore_hud_button = restore

func _toggle_fly() -> void:
 god_mode = not god_mode
 fly_buttons.clear()
 stick_move = Vector2.ZERO
 stick_look = Vector2.ZERO
 left_touch = -1
 right_touch = -1
 fly_ui.visible = god_mode
 normal_ui.visible = not god_mode
 photo_mode = false
 photo_ui.visible = true
 restore_hud_button.visible = false
 status.visible = true
 if god_mode:
  fly_yaw = orbit
  fly_pitch = pitch
  camera.global_position = boat.global_position + Vector3(0, 14, 29)
  camera.look_at(boat.global_position + Vector3.UP * 5.0)
  fly_yaw = camera.rotation.y
  fly_pitch = camera.rotation.x

func _toggle_photo() -> void:
 photo_mode = not photo_mode
 status.visible = not photo_mode
 normal_ui.visible = not photo_mode and not god_mode
 fly_ui.visible = not photo_mode and god_mode
 photo_ui.visible = not photo_mode
 restore_hud_button.visible = photo_mode

func _fly_press(key: String) -> void:
 fly_buttons[key] = true
func _fly_release(key: String) -> void:
 fly_buttons.erase(key)

func _fly_step(delta: float) -> void:
 var axis := Vector3(stick_move.x, 0.0, stick_move.y)
 fly_yaw -= stick_look.x * delta * 2.0
 fly_pitch = clampf(fly_pitch - stick_look.y * delta * 1.7, -1.45, 1.45)
 if fly_buttons.has("forward") or Input.is_key_pressed(KEY_W): axis.z -= 1.0
 if fly_buttons.has("back") or Input.is_key_pressed(KEY_S): axis.z += 1.0
 if fly_buttons.has("left") or Input.is_key_pressed(KEY_A): axis.x -= 1.0
 if fly_buttons.has("right") or Input.is_key_pressed(KEY_D): axis.x += 1.0
 if fly_buttons.has("up") or Input.is_key_pressed(KEY_SPACE): axis.y += 1.0
 if fly_buttons.has("down") or Input.is_key_pressed(KEY_CTRL): axis.y -= 1.0
 var direction := camera.global_basis * Vector3(axis.x,0.0,axis.z)
 direction.y = axis.y
 camera.global_position += direction.limit_length(1.0) * fly_speed * delta
 camera.rotation = Vector3(fly_pitch,fly_yaw,0.0)

func _draw_sticks() -> void:
 if not god_mode:
  return
 var view := get_viewport().get_visible_rect().size
 var l := left_center if left_touch != -1 else Vector2(92.0,view.y - 100.0)
 var r := right_center if right_touch != -1 else Vector2(view.x - 92.0,view.y - 100.0)
 for item in [[l,stick_move],[r,stick_look]]:
  var center: Vector2 = item[0]
  var value: Vector2 = item[1]
  stick_canvas.draw_circle(center,stick_radius,Color(0.12,0.17,0.22,0.4))
  stick_canvas.draw_arc(center,stick_radius,0.0,TAU,48,Color(0.85,0.91,1.0,0.7),2.0)
  stick_canvas.draw_circle(center + value * stick_radius,22.0,Color(0.86,0.92,1.0,0.8))

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
  if event.keycode == KEY_F:
   _toggle_fly()
   return
  if event.keycode == KEY_P:
   _toggle_photo()
   return
  if god_mode:
   return
  match event.keycode:
   KEY_A: command("port")
   KEY_D: command("starboard")
   KEY_W: command("raise")
   KEY_S: command("lower")
   KEY_Q: command("sheet_l")
   KEY_E: command("sheet_r")
 if god_mode and event is InputEventScreenTouch:
  var half := get_viewport().get_visible_rect().size.x * 0.5
  if event.pressed:
   if event.position.x < half and left_touch == -1:
    left_touch = event.index
    left_center = event.position
    stick_move = Vector2.ZERO
   elif event.position.x >= half and right_touch == -1:
    right_touch = event.index
    right_center = event.position
    stick_look = Vector2.ZERO
  else:
   if event.index == left_touch:
    left_touch = -1
    stick_move = Vector2.ZERO
   if event.index == right_touch:
    right_touch = -1
    stick_look = Vector2.ZERO
  stick_canvas.queue_redraw()
  return
 if god_mode and event is InputEventScreenDrag:
  if event.index == left_touch:
   stick_move = ((event.position - left_center) / stick_radius).limit_length(1.0)
  elif event.index == right_touch:
   stick_look = ((event.position - right_center) / stick_radius).limit_length(1.0)
  stick_canvas.queue_redraw()
  return
 if event is InputEventScreenTouch:
  dragging = event.pressed and event.position.x > get_viewport().get_visible_rect().size.x * 0.5
 if event is InputEventScreenDrag and dragging and god_mode:
  fly_yaw -= event.relative.x * 0.004
  fly_pitch = clampf(fly_pitch - event.relative.y * 0.003, -1.45, 1.45)
 elif event is InputEventScreenDrag and dragging:
  orbit -= event.relative.x*0.004
  pitch = clamp(pitch+event.relative.y*0.003,-0.1,1.0)
 if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
  orbit -= event.relative.x*0.004
func _process(delta: float) -> void:
 if god_mode:
  _fly_step(delta)
  return
 if delta > 0.0001:
  _observed_speed = boat.global_position.distance_to(_last_boat_position) / delta
 _last_boat_position = boat.global_position
 var distance := 37.0
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
