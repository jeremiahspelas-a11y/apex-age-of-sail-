extends Node3D
@onready var boat: RigidBody3D = $Boat
@onready var camera: Camera3D = $Camera3D
@onready var player: CharacterBody3D = $Player
var view_yaw := 0.0
var view_pitch := 0.0
var rudder := 0.0
var reef := 0.65
var sheet := 0.4
var orbit := 0.65
var pitch := 0.40
var dragging := false
var deck_look_touch := -1
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
var fly_toggle: Button
var pin_button: Button
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
var trial_button: Button
var spatial_qa: Node
var brace_ui: GridContainer
var brace_status: Label
var brace_select: Button
var selected_brace := 0
var clew_selected := false
var rig_control_toggle: Button
var session: Node
var coop_panel: PanelContainer
var coop_status: Label
var coop_url: LineEdit
var weather_choice: OptionButton
var vr: Node
var coop_toggle: Button
var vr_button: Button
var session_notice: Label
var notice_timer := 0.0
func _ready() -> void:
 session = preload("res://scripts/crew_session.gd").new()
 session.name = "CrewSession"
 add_child(session)
 session.setup(self)
 var canvas := CanvasLayer.new()
 add_child(canvas)
 hud_layer = canvas
 _last_boat_position = boat.global_position
 flooding_system = boat.get_node_or_null("ShipIntegrity")
 status = Label.new()
 status.position = Vector2(16,12)
 status.add_theme_font_size_override("font_size",14)
 status.add_theme_color_override("font_outline_color",Color.BLACK)
 status.add_theme_constant_override("outline_size",3)
 canvas.add_child(status)
 var root := Control.new()
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.mouse_filter = Control.MOUSE_FILTER_IGNORE
 canvas.add_child(root)
 normal_ui = root
 var trainer_hint := Label.new()
 trainer_hint.position = Vector2(16,165)
 trainer_hint.text = "DECK VIEW\nArrows: walk | Right-drag: look\nA/D: helm | W/S: reef | Q/E: other yards\nF: fly inspection | P: hide HUD"
 trainer_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
 root.add_child(trainer_hint)
 _build_fly_controls(canvas)
 _build_session_controls(canvas,root)
 spatial_qa = preload("res://scripts/spatial_qa.gd").new()
 add_child(spatial_qa)
 spatial_qa.setup(boat, camera, canvas)
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
 var actions := [["Port","port"],["Starboard","starboard"],["Reef +","raise"],["Reef -","lower"],["Yard -","sheet_l"],["Yard +","sheet_r"],["Door","door"],["Hatch","hatch"]]
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
 for action in [["BREACH","breach"],["PATCH","patch"],["PUMP","pump"],["LINK CUT","rope_cut"]]:
  var damage_button := Button.new()
  damage_button.text = action[0]
  damage_button.custom_minimum_size = Vector2(84,48)
  damage_actions.add_child(damage_button)
  damage_button.pressed.connect(command.bind(action[1]))
 trial_button = Button.new()
 trial_button.text = "PHYSICS TRIAL"
 trial_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
 trial_button.offset_left = -356.0
 trial_button.offset_right = -8.0
 trial_button.offset_top = 190.0
 trial_button.offset_bottom = 238.0
 root.add_child(trial_button)
 trial_button.pressed.connect(_toggle_force_trial)
 _build_brace_controls(root)
 if OS.has_feature("web"):
  var initial_weather: Variant = JavaScriptBridge.eval("new URLSearchParams(location.search).get('weather')")
  if initial_weather is String and $Weather.set_scenario(initial_weather):
   $Weather.state = $Weather.field.sample(Vector2.ZERO,Ocean.time)
   $Weather.sea_scale = $Weather.state.target_sea_scale
   $Weather._apply_state(0.0)
   weather_choice.select(["Evolving","Calm","Breeze","Squall","Storm"].find(initial_weather))
 if OS.has_feature("web") and JavaScriptBridge.eval("new URLSearchParams(location.search).get('simulation') === 'forces'"):
  _toggle_force_trial()
 var walking := HBoxContainer.new()
 walking.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
 walking.offset_left = 12.0
 walking.offset_top = -78.0
 walking.offset_bottom = -12.0
 root.add_child(walking)
 for action in [["LEFT","◀"],["FWD","▲"],["BACK","▼"],["RIGHT","▶"],["STOP","STOP"]]:
  var btn := Button.new()
  btn.text = action[0]
  btn.custom_minimum_size = Vector2(64,60)
  walking.add_child(btn)
  btn.button_down.connect(_walk_input.bind(action[1]))
  btn.button_up.connect(_walk_release.bind(action[1]))
 var jump := Button.new()
 jump.text = "JUMP"
 jump.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
 jump.offset_left = -92.0
 jump.offset_right = -12.0
 jump.offset_top = -78.0
 jump.offset_bottom = -12.0
 root.add_child(jump)
 jump.pressed.connect(_jump)
 camera.near = 0.05
 _update_player_view()
 _deck_camera()
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--serve="):
   session.host(int(argument.get_slice("=",1)))
   brace_ui.visible = true
   brace_status.visible = true
func _build_session_controls(canvas: CanvasLayer,root: Control) -> void:
 var button := Button.new()
 coop_toggle = button
 button.text = "CO-OP"
 button.position = Vector2(286,56)
 button.custom_minimum_size = Vector2(130,48)
 canvas.add_child(button)
 coop_panel = PanelContainer.new()
 coop_panel.position = Vector2(16,270)
 coop_panel.custom_minimum_size = Vector2(550,0)
 var panel_style := StyleBoxFlat.new()
 panel_style.bg_color = Color(0.055,0.08,0.10,0.98)
 for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: panel_style.set_content_margin(side,4.0)
 coop_panel.add_theme_stylebox_override("panel",panel_style)
 coop_panel.visible = false
 root.add_child(coop_panel)
 button.pressed.connect(_toggle_coop_panel)
 var column := VBoxContainer.new()
 coop_panel.add_child(column)
 var title := Label.new()
 title.text = "Shared ship — connect to a running co-op host"
 column.add_child(title)
 coop_url = LineEdit.new()
 coop_url.text = "ws://127.0.0.1:9080"
 coop_url.placeholder_text = "wss://your-host.example"
 column.add_child(coop_url)
 coop_url.focus_entered.connect(func(): print("APEX COOP ENDPOINT FOCUSED"))
 coop_url.text_submitted.connect(func(_text: String): _session_action("JOIN"))
 var actions := HBoxContainer.new()
 column.add_child(actions)
 for label in ["JOIN","HOST LAN","RELEASE STATION","LEAVE"]:
  var action := Button.new()
  action.text = label
  action.custom_minimum_size.y = 40
  if label=="HOST LAN": action.disabled = OS.has_feature("web")
  actions.add_child(action)
  action.pressed.connect(_session_action.bind(label))
 coop_status = Label.new()
 coop_status.text = "Commands reserve a station. Release it to let another sailor take over."
 coop_status.add_theme_font_size_override("font_size",13)
 column.add_child(coop_status)
 session_notice = Label.new()
 session_notice.position = Vector2(16,320)
 session_notice.add_theme_font_size_override("font_size",14)
 session_notice.add_theme_color_override("font_outline_color",Color.BLACK)
 session_notice.add_theme_constant_override("outline_size",3)
 root.add_child(session_notice)
 session.feedback.connect(func(message: String):
  print("APEX COOP FEEDBACK ",message)
  coop_status.text = message
  session_notice.text = message
  notice_timer = 3.0)
 weather_choice = OptionButton.new()
 weather_choice.position = Vector2(16,274)
 for label in ["Evolving","Calm","Breeze","Squall","Storm"]: weather_choice.add_item(label)
 weather_choice.custom_minimum_size = Vector2(180,38)
 root.add_child(weather_choice)
 weather_choice.item_selected.connect(func(index: int):
  if session.active: session.send_action("weather",float(index))
  else: $Weather.set_scenario(weather_choice.get_item_text(index)))
 var sound := Button.new()
 sound.text = "THUNDER: OFF"
 sound.position = Vector2(206,274)
 sound.custom_minimum_size = Vector2(150,38)
 root.add_child(sound)
 sound.pressed.connect(func():
  $Weather.audio_enabled = not $Weather.audio_enabled
  sound.text = "THUNDER: ON" if $Weather.audio_enabled else "THUNDER: OFF")
 # Keep the optional connection panel above weather controls.
 root.move_child(coop_panel,-1)
 vr_button = Button.new()
 vr_button.text = "VR UNAVAILABLE"
 vr_button.position = Vector2(428,56)
 vr_button.custom_minimum_size = Vector2(146,48)
 vr_button.add_theme_font_size_override("font_size",13)
 vr_button.disabled = true
 canvas.add_child(vr_button)
 vr = preload("res://scripts/vr_sailing.gd").new()
 vr.name = "OptionalVR"
 add_child(vr)
 vr.availability.connect(func(supported: bool):
  vr_button.disabled = not supported
  vr_button.text = "ENTER VR" if supported else "VR UNAVAILABLE")
 vr.message.connect(func(message: String): coop_status.text = "VR: "+message)
 vr.setup(self)
 vr_button.pressed.connect(func():
  if god_mode: _toggle_fly()
  if not vr.enter(): coop_status.text = "VR session could not start on this device.")

func _toggle_coop_panel() -> void:
 if god_mode: _toggle_fly()
 coop_panel.visible = not coop_panel.visible
 player.movement_enabled = not coop_panel.visible and not god_mode
 if coop_panel.visible:
  # Focus only after the previously hidden containers have completed layout.
  await get_tree().process_frame
  await get_tree().process_frame
  if coop_panel.is_visible_in_tree():
   coop_url.grab_focus()
   coop_url.select_all()
 print("APEX COOP PANEL ",coop_panel.visible)

func _session_action(action: String) -> void:
 match action:
  "JOIN":
   var error: Error = session.join(coop_url.text.strip_edges())
   if error!=OK: coop_status.text = "Join error: "+error_string(error)
  "HOST LAN":
   var error: Error = session.host()
   if error!=OK: coop_status.text = "Host error: "+error_string(error)
  "RELEASE STATION": session.send_action("release_station")
  "LEAVE": session.stop()
 if session.active:
  brace_ui.visible = true
  brace_status.visible = true

func _build_brace_controls(root: Control) -> void:
 brace_ui = GridContainer.new()
 brace_ui.columns = 3
 brace_ui.set_anchors_preset(Control.PRESET_TOP_RIGHT)
 brace_ui.offset_left = -356.0
 brace_ui.offset_right = -8.0
 brace_ui.offset_top = 248.0
 brace_ui.visible = boat.force_trial
 root.add_child(brace_ui)
 for label in ["PORT BRACE","BELAY","FREE","HAUL","EASE","CUT BRACE"]:
  var button := Button.new()
  button.text = label
  button.custom_minimum_size = Vector2(112,38)
  button.add_theme_font_size_override("font_size",13)
  brace_ui.add_child(button)
  if label=="PORT BRACE": brace_select = button
  if label=="HAUL" or label=="EASE":
   button.button_down.connect(_brace_pull.bind(-1.0 if label=="HAUL" else 1.0))
   button.button_up.connect(_brace_stop)
  else:
   button.pressed.connect(_brace_action.bind(label))
 brace_status = Label.new()
 brace_status.set_anchors_preset(Control.PRESET_TOP_RIGHT)
 brace_status.offset_left = -356.0
 brace_status.offset_right = -8.0
 brace_status.offset_top = 334.0
 brace_status.add_theme_font_size_override("font_size",14)
 brace_status.add_theme_color_override("font_outline_color",Color.BLACK)
 brace_status.add_theme_constant_override("outline_size",3)
 brace_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
 brace_status.visible = boat.force_trial
 root.add_child(brace_status)
 rig_control_toggle = Button.new()
 rig_control_toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
 rig_control_toggle.offset_left = -356.0
 rig_control_toggle.offset_right = -8.0
 rig_control_toggle.offset_top = 398.0
 rig_control_toggle.custom_minimum_size = Vector2(348,38)
 rig_control_toggle.visible = boat.force_trial
 rig_control_toggle.text = "CONTROL: YARD BRACES"
 rig_control_toggle.pressed.connect(_toggle_rig_control)
 root.add_child(rig_control_toggle)

func _controlled_line_rig() -> RefCounted:
 return $Boat/Mechanisms.cloth if clew_selected else $Boat/Mechanisms.brace

func _toggle_rig_control() -> void:
 _brace_stop()
 clew_selected = not clew_selected
 rig_control_toggle.text = "CONTROL: CLEW SHEETS" if clew_selected else "CONTROL: YARD BRACES"
 _update_rig_selection()
 print("APEX RIG CIRCUIT ","CLEW SHEETS" if clew_selected else "YARD BRACES")

func _update_rig_selection() -> void:
 brace_select.text = ("PORT" if selected_brace==0 else "STBD")+(" SHEET" if clew_selected else " BRACE")

func _brace_pull(direction: float) -> void:
 if session!=null and session.active:
  session.send_action("clew_pull" if clew_selected else "brace_pull",direction,selected_brace)
  return
 if boat.force_trial: _controlled_line_rig().set_hand(selected_brace,direction)

func _brace_stop() -> void:
 if session!=null and session.active:
  for prefix: String in ["brace_","clew_"]:
   session.send_action(prefix+"stop",0.0,0)
   session.send_action(prefix+"stop",0.0,1)
  return
 $Boat/Mechanisms.brace.stop_hands()
 $Boat/Mechanisms.cloth.stop_hands()

func _brace_action(action: String) -> void:
 if action!="PORT BRACE" and session!=null and session.active:
  var verb: String = {"BELAY":"belay","FREE":"free","CUT BRACE":"cut"}.get(action,"")
  if not verb.is_empty(): session.send_action(("clew_" if clew_selected else "brace_")+verb,0.0,selected_brace)
  return
 var rig := _controlled_line_rig()
 if not boat.force_trial: return
 match action:
  "PORT BRACE":
   _brace_stop()
   selected_brace = 1-selected_brace
   _update_rig_selection()
  "BELAY": rig.belay(selected_brace)
  "FREE": rig.release(selected_brace)
  "CUT BRACE": rig.cut(selected_brace)
 print("APEX BRACE CONTROL ",JSON.stringify({"action":action,"selected":selected_brace,"clew":clew_selected,"state":$Boat/Mechanisms.brace_report(),"sheets":$Boat/Mechanisms.cloth.lines}))

func _update_brace_status() -> void:
 var rig := _controlled_line_rig()
 if not boat.force_trial or rig.lines.size()!=2: return
 var line: Dictionary = rig.lines[selected_brace]
 var mode: String = ["BELAYED","IN HAND","RUNNING FREE","CUT"][int(line.mode)]
 if clew_selected:
  brace_status.text = "FORE CLEWS | %.0f / %.0f N\n%s | %.2f m available\nHaul / ease to shape the lower fore sail."%[rig.lines[0].tension,rig.lines[1].tension,mode,line.length]
 else:
  brace_status.text = "FORE LOWER YARD %.1f deg | %.0f / %.0f N\n%s | %.2f m available\nHaul one side; ease its opposing brace."%[rad_to_deg(rig.angle),rig.lines[0].tension,rig.lines[1].tension,mode,line.length]
 for button: Node in brace_ui.get_children():
  if button is Button and button.text.begins_with("CUT"):
   button.text = "CUT SHEET" if clew_selected else "CUT BRACE"

func _build_fly_controls(canvas: CanvasLayer) -> void:
 var toggle := Button.new()
 fly_toggle = toggle
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
 var vertical := HBoxContainer.new()
 vertical.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
 vertical.offset_left = -92.0
 vertical.offset_top = -78.0
 fly_root.add_child(vertical)
 for item in [["UP","up"],["DOWN","down"]]:
  var b := Button.new()
  b.text = item[0]
  b.custom_minimum_size = Vector2(88,65)
  vertical.add_child(b)
  b.button_down.connect(_fly_press.bind(item[1]))
  b.button_up.connect(_fly_release.bind(item[1]))
 var pin := Button.new()
 pin_button = pin
 pin.text = "PIN ISSUE"
 pin.position = Vector2(150, 56)
 pin.custom_minimum_size = Vector2(125, 48)
 canvas.add_child(pin)
 pin.pressed.connect(_pin_issue)
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

func _pin_issue() -> void:
 if not god_mode:
  _toggle_fly()
 _reset_fly_input()
 spatial_qa.begin_pin()

func _toggle_fly() -> void:
 if vr!=null and vr.active: return
 spatial_qa._cancel()
 god_mode = not god_mode
 _brace_stop()
 dragging = false
 deck_look_touch = -1
 _update_player_view()
 _reset_fly_input()
 active_walk_buttons.clear()
 _update_walk_vector()
 fly_ui.visible = god_mode
 normal_ui.visible = not god_mode
 photo_mode = false
 photo_ui.visible = true
 fly_toggle.visible = true
 pin_button.visible = true
 if coop_toggle!=null: coop_toggle.visible = true
 if vr_button!=null: vr_button.visible = true
 spatial_qa.export_button.visible = not spatial_qa.notes.is_empty()
 restore_hud_button.visible = false
 status.visible = true
 if god_mode:
  fly_yaw = orbit
  fly_pitch = pitch
  camera.global_position = boat.global_position + Vector3(0, 14, 29)
  camera.look_at(boat.global_position + Vector3.UP * 5.0)
  fly_yaw = camera.rotation.y
  fly_pitch = camera.rotation.x
 else:
  _deck_camera()

func _update_player_view() -> void:
 player.movement_enabled = not god_mode
 # Keep an imported character's own placeholder visibility decision intact.
 for child in player.get_children():
  if child is Node3D and child.name != "PlayerCollider":
   if not child.has_meta("trainer_visible"):
    child.set_meta("trainer_visible",child.visible)
   child.visible = bool(child.get_meta("trainer_visible")) if god_mode else false

func _deck_camera() -> void:
 if vr!=null and vr.active: return
 camera.global_position = player.global_position+Vector3.UP*0.65
 # Upright horizon for the desktop trainer; tracked XR pose will be a separate adapter.
 camera.global_rotation = Vector3(view_pitch,boat.global_rotation.y+view_yaw,0.0)

func _look(relative: Vector2) -> void:
 view_yaw -= relative.x*0.004
 view_pitch = clampf(view_pitch-relative.y*0.003,-1.35,1.35)

func _reset_fly_input() -> void:
 fly_buttons.clear()
 stick_move = Vector2.ZERO
 stick_look = Vector2.ZERO
 left_touch = -1
 right_touch = -1
 if is_instance_valid(stick_canvas):
  stick_canvas.queue_redraw()

func _toggle_photo() -> void:
 _brace_stop()
 photo_mode = not photo_mode
 _reset_fly_input()
 spatial_qa._cancel()
 fly_toggle.visible = not photo_mode
 pin_button.visible = not photo_mode
 if coop_toggle!=null: coop_toggle.visible = not photo_mode
 if vr_button!=null: vr_button.visible = not photo_mode
 spatial_qa.export_button.visible = not photo_mode and not spatial_qa.notes.is_empty()
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
 if session!=null and session.active:
  session.send_action(action)
  return
 _apply_command(action)
func _apply_command(action: String) -> void:
 if action in ["port","starboard"]: $Boat/Mechanisms.use_button_helm()
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
func _input(event: InputEvent) -> void:
 # A release over a UI control must still release the stick that owns this finger.
 if event is InputEventScreenTouch and not event.pressed:
  if event.index == deck_look_touch:
   deck_look_touch = -1
   dragging = false
  if event.index == left_touch:
   left_touch = -1
   stick_move = Vector2.ZERO
  if event.index == right_touch:
   right_touch = -1
   stick_look = Vector2.ZERO
  if is_instance_valid(stick_canvas):
   stick_canvas.queue_redraw()

func _notification(what: int) -> void:
 if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
  if is_node_ready(): _brace_stop()
  _reset_fly_input()
  dragging = false
  deck_look_touch = -1
  active_walk_buttons.clear()
  _update_walk_vector()

func _unhandled_input(event: InputEvent) -> void:
 if god_mode and spatial_qa.is_active():
  if spatial_qa.waiting_for_point and event is InputEventScreenTouch and event.pressed:
   spatial_qa.pick(event.position)
  elif spatial_qa.waiting_for_point and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
   spatial_qa.pick(event.position)
  return
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
  if event.pressed and deck_look_touch == -1 and event.position.x > get_viewport().get_visible_rect().size.x * 0.5:
   deck_look_touch = event.index
   dragging = true
 if event is InputEventScreenDrag and dragging and event.index == deck_look_touch:
  _look(event.relative)
 if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
  if god_mode:
   fly_yaw -= event.relative.x*0.004
   fly_pitch = clampf(fly_pitch-event.relative.y*0.003,-1.45,1.45)
  else:
   _look(event.relative)
func _process(delta: float) -> void:
 if god_mode:
  if spatial_qa.is_active():
   return
  _fly_step(delta)
  return
 if delta > 0.0001:
  _observed_speed = boat.global_position.distance_to(_last_boat_position) / delta
 _last_boat_position = boat.global_position
 _deck_camera()
 weather_choice.disabled = session.active and not session.is_host
 trial_button.text = "SHARED PHYSICS" if session.active else ("RETURN TO PROTOTYPE" if boat.force_trial else "PHYSICS TRIAL")
 brace_ui.visible = boat.force_trial
 brace_status.visible = boat.force_trial
 rig_control_toggle.visible = boat.force_trial
 notice_timer = maxf(0.0,notice_timer-delta)
 if notice_timer<=0 and session.active and session.connected:
  var owner := "unassigned"
  for station: String in session.stations.keys():
   if session.stations[station]==multiplayer.get_unique_id(): owner = station.replace("_"," ")
  var people: int = session.avatars.size()+1 if session.is_host else int(session.latest.get("people",{}).size())
  session_notice.text = "CO-OP | %d aboard | Your station: %s"%[people,owner]
 elif notice_timer<=0: session_notice.text = ""
 _update_brace_status()
 var tonnes: float = flooding_system.total_water_tonnes() if flooding_system != null else 0.0
 var helm := $Boat/Mechanisms
 var displayed_speed := Vector2(boat.linear_velocity.x,boat.linear_velocity.z).length() if boat.force_trial else _observed_speed
 var rope_state: String = "CONNECTED" if helm.steering_rope_intact else "CUT"
 status.text = ("FORCES |" if boat.force_trial else "PROTOTYPE |") + " %.1f m/s | RUDDER %.0f deg | LINK %s | FLOOD %.1f t" % [displayed_speed,rad_to_deg(helm.actual_rudder_angle),rope_state,tonnes]
 if boat.force_trial and not boat.hydro_report.is_empty():
  status.text += "\nBUOYANCY %.0f kN | RIG %.1f kN | LINES %.0f / %.0f N"%[boat.hydro_report.buoyancy.length()/1000.0,boat.rig_report.force.length()/1000.0,helm.port_line_tension,helm.starboard_line_tension]
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

func _toggle_force_trial() -> void:
 if session!=null and session.active:
  coop_status.text = "Shared ship simulation is controlled by the host."
  return
 _brace_stop()
 boat.set_force_trial(not boat.force_trial)
 trial_button.text = "RETURN TO PROTOTYPE" if boat.force_trial else "PHYSICS TRIAL"
 brace_ui.visible = boat.force_trial
 brace_status.visible = boat.force_trial
 rig_control_toggle.visible = boat.force_trial
