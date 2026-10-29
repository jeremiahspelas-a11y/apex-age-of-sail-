extends Node
## A first-watch lesson over actual rope and steering state, with proximity-operated stations.
const Stations = preload("res://scripts/deck_stations.gd")
var game: Node3D
var deck: Node
var active := false
var workshop := false
var stage := 0
var starting_sheet := 0.0
var centered_seconds := 0.0
var log_clock := 0.0
var hud: Control
var welcome: PanelContainer
var objective: PanelContainer
var objective_title: Label
var instruction: Label
var wind_label: Label
var navigation: Label
var station_panel: PanelContainer
var station_title: Label
var station_status: Label
var use_button: Button
var rope_actions: HBoxContainer
var wheel_actions: HBoxContainer
var leave_button: Button
var marker: Label3D
var target_index := 1 # port clew (stations alternate sheet/brace by side)
var _keys: Dictionary = {}
var lesson_vr: Button
var welcome_vr: Button
var welcome_content: VBoxContainer
var menu_content: VBoxContainer
var welcome_scroll: ScrollContainer
var menu_scroll: ScrollContainer
var welcome_start: Button
var progress: ProgressBar
var short_action: Label
var eyebrow: Label
var details_button: Button
var lesson_menu: Button
var menu_layer: Control
var menu_panel: PanelContainer
var menu_help: Label
var menu_heading: Label
var menu_extra: Array[Control] = []
var menu_vr: Button
var resume_button: Button
var restart_button: Button
var touch_toggle: CheckButton
var touch_pad: Control
var keyboard_hint: Label
var station_header: HBoxContainer
var station_meter: Control
var touch_mode := false
var details_open := false
var _move_keys: Dictionary = {}
var _motion_owned := false
var _layout_key := ""
var _layout_frames := 0
var _welcome_report_pending := false
var _menu_report_pending := false
func setup(root: Node3D) -> void:
 game = root
 process_mode = Node.PROCESS_MODE_ALWAYS
 deck = Stations.new()
 deck.name = "DeckStations"
 deck.process_mode = Node.PROCESS_MODE_PAUSABLE
 add_child(deck)
 deck.setup(game)
 hud = Control.new()
 hud.name = "FirstWatchHUD"
 hud.process_mode = Node.PROCESS_MODE_ALWAYS
 hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
 game.hud_layer.add_child(hud)
 _build_welcome()
 _build_lesson()
 _build_menu()
 marker = Label3D.new()
 marker.name = "LessonStationMarker"
 marker.font_size = 36
 marker.pixel_size = 0.006
 marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 marker.modulate = Color(1.0,0.83,0.36)
 marker.outline_size = 6
 marker.no_depth_test = false
 game.boat.add_child(marker)
 marker.visible = false
 deck.changed.connect(_station_changed)
 if OS.has_feature("web"):
  touch_mode = bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0 || matchMedia('(pointer: coarse)').matches"))
 touch_toggle.button_pressed = touch_mode
 get_viewport().size_changed.connect(_viewport_resized)
 _layout()
 _settle_layout()
 var skip := DisplayServer.get_name()=="headless"
 if OS.has_feature("web"):
  skip = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('mode') === 'workshop' || new URLSearchParams(location.search).get('simulation') === 'forces'"))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--serve="): skip = true
 if skip: enter_workshop()
 else:
  _show_welcome()
  _report_welcome()
func _report_welcome() -> void:
 _welcome_report_pending = true
 _settle_layout()
func _tick_layout() -> void:
 if _layout_frames<=0: return
 _layout_frames -= 1
 if _layout_frames in [2,0]: _layout()
 if _layout_frames!=0: return
 if _welcome_report_pending and welcome.visible:
  print("APEX LESSON WELCOME ",JSON.stringify({"start":_center(welcome_start)}))
 if _menu_report_pending and menu_layer.visible:
  print("APEX LESSON MENU ",JSON.stringify({"details":details_open,"resume":_center(resume_button),"touch":_center(touch_toggle),"restart":_center(restart_button)}))
 _welcome_report_pending = false
 _menu_report_pending = false
func _viewport_resized() -> void:
 touch_pad.reset()
 game.dragging = false
 game.deck_look_touch = -1
 _layout()
 _settle_layout()
 _layout_key = ""
func _layout() -> void:
 var view := get_viewport().get_visible_rect().size
 var narrow := view.x<700 and view.y>view.x
 var width := minf(480,view.x-32)
 for item: Array in [[welcome,welcome_content],[menu_panel,menu_content]]:
  var panel: PanelContainer = item[0]
  var content: VBoxContainer = item[1]
  panel.custom_minimum_size = Vector2(width,0)
  for node in content.get_children():
   if node is Label: node.custom_minimum_size.x = width-28
  var height := minf(content.get_combined_minimum_size().y+28,view.y-32)
  panel.offset_left = -width*0.5
  panel.offset_right = width*0.5
  panel.offset_top = -height*0.5
  panel.offset_bottom = height*0.5
  panel.size = Vector2(width,height)
 objective.position = Vector2(16,16)
 var objective_width := minf(360,view.x-124 if not narrow else view.x-32)
 if view.y<420:
  objective_width = minf(320,view.x-minf(416,maxf(164,view.x-180))-48)
 navigation.visible = view.y>=420 or view.x>=760
 if narrow: objective.position.y = 80
 short_action.visible = view.y>=420
 objective.custom_minimum_size.x = objective_width
 objective.size.x = objective_width
 for label: Label in [eyebrow,short_action,instruction,navigation,wind_label]:
  label.custom_minimum_size.x = objective_width-28
 objective_title.custom_minimum_size.x = 0
 station_panel.custom_minimum_size.x = 0
 var using_station: bool = deck.current>=0
 var panel_width := minf(416,view.x-32)
 if (touch_mode and not (narrow and using_station)) or view.y<420: panel_width = minf(416,maxf(164,view.x-180))
 station_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT if (touch_mode and not (narrow and using_station)) or view.y<420 else Control.PRESET_CENTER_BOTTOM)
 if (touch_mode and not (narrow and using_station)) or view.y<420:
  station_panel.offset_left = -panel_width-16
  station_panel.offset_right = -16
 else:
  station_panel.offset_left = -panel_width*0.5
  station_panel.offset_right = panel_width*0.5
 var panel_height := 196.0 if using_station else 76.0
 station_panel.offset_top = -panel_height-16
 station_panel.offset_bottom = -16
 station_panel.size = Vector2(panel_width,panel_height)
 touch_pad.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
 touch_pad.offset_left = 16
 touch_pad.offset_right = 140
 touch_pad.offset_bottom = -228 if narrow and using_station else -16
 touch_pad.offset_top = touch_pad.offset_bottom-124
 touch_pad.visible = active and touch_mode and not menu_layer.visible
 keyboard_hint.visible = active and not touch_mode and not menu_layer.visible and deck.current<0 and not (view.x<800 and deck.nearest()>=0)
 keyboard_hint.custom_minimum_size.x = 224
 keyboard_hint.size.x = 224
 keyboard_hint.position = Vector2(16,view.y-76)
 # The desktop hint moves above a full-width station card on narrow screens.
 if narrow and using_station: keyboard_hint.position.y = view.y-218
 menu_help.text = instruction.text+"\n\n"+wind_label.text if details_open else ("Move: thumb pad. Look: drag the open right side.
At a fitting: tap Take hold, then hold its action buttons. Let go or walk away to leave." if touch_mode else "Move: WASD or arrows. Look: right-drag.
R: take hold / let go. Q/E: haul/ease a rope.
A/D: turn a held wheel. B: belay. Esc: menu.")
func _settle_layout() -> void:
 # Owned frame countdown: freeing/changing view cancels pending work automatically.
 _layout_frames = 4
 _menu_report_pending = menu_layer.visible
func _toggle_details() -> void:
 _open_menu(true)
func _open_menu(explain: bool = false) -> void:
 if not active: return
 details_open = explain
 menu_heading.text = "About this step" if explain else "Watch menu"
 resume_button.text = "BACK TO SHIP" if explain else "RESUME"
 touch_toggle.visible = not explain
 restart_button.visible = not explain
 for node in menu_extra: node.visible = not explain
 menu_vr.visible = game.vr.supported and not explain
 _keys.clear()
 _move_keys.clear()
 deck.stop_hands()
 touch_pad.reset()
 game.player.motion_input = Vector2.ZERO
 game.player.movement_enabled = false
 game.dragging = false
 game.deck_look_touch = -1
 menu_layer.visible = true
 get_tree().paused = true
 menu_scroll.scroll_vertical = 0
 _layout()
 _settle_layout()
func _close_menu() -> void:
 if menu_layer==null: return
 get_tree().paused = false
 menu_layer.visible = false
 _layout_frames = 0
 _menu_report_pending = false
 _welcome_report_pending = false
 details_open = false
 if game!=null: game.player.movement_enabled = active and not game.god_mode
 _layout_key = ""
func _unhandled_input(event: InputEvent) -> void:
 if menu_layer!=null and menu_layer.visible and event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
  _close_menu()
  get_viewport().set_input_as_handled()
func _panel(parent: Control,width: float) -> PanelContainer:
 var panel := PanelContainer.new()
 panel.custom_minimum_size.x = width
 var style := StyleBoxFlat.new()
 style.bg_color = Color(0.035,0.065,0.075,0.96)
 style.border_color = Color(0.43,0.37,0.22)
 style.set_border_width_all(1)
 style.set_corner_radius_all(6)
 for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]: style.set_content_margin(side,14)
 panel.add_theme_stylebox_override("panel",style)
 parent.add_child(panel)
 return panel
func _label(parent: Node,text: String,width: float,font_size: int = 16) -> Label:
 var label := Label.new()
 label.text = text
 label.custom_minimum_size.x = width
 label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size",font_size)
 label.add_theme_color_override("font_color",Color(0.91,0.89,0.81))
 parent.add_child(label)
 return label
func _button(parent: Node,text: String,callback: Callable) -> Button:
 var button := Button.new()
 button.text = text
 button.custom_minimum_size.y = 48
 button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 button.focus_mode = Control.FOCUS_NONE
 button.add_theme_font_size_override("font_size",16)
 for state: String in ["normal","hover","pressed","disabled"]:
  var style := StyleBoxFlat.new()
  style.bg_color = {"normal":Color(0.10,0.16,0.17,0.96),"hover":Color(0.17,0.25,0.25),"pressed":Color(0.34,0.29,0.15),"disabled":Color(0.07,0.10,0.11,0.65)}[state]
  style.border_color = Color(0.37,0.42,0.36)
  style.set_border_width_all(1)
  style.set_corner_radius_all(4)
  style.content_margin_left = 8
  style.content_margin_right = 8
  button.add_theme_stylebox_override(state,style)
 parent.add_child(button)
 button.pressed.connect(callback)
 return button
func _build_welcome() -> void:
 welcome = _panel(hud,480)
 welcome.set_anchors_preset(Control.PRESET_CENTER)
 welcome_scroll = ScrollContainer.new()
 welcome_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 welcome.add_child(welcome_scroll)
 var column := VBoxContainer.new()
 welcome_content = column
 column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 column.add_theme_constant_override("separation",12)
 welcome_scroll.add_child(column)
 _label(column,"APEX  /  AGE OF SAIL",420,14)
 _label(column,"Your first watch",420,30)
 _label(column,"Learn at the fittings: secure a sail's sheet, walk the deck, and take the wheel.",420,18)
 welcome_start = _button(column,"START GUIDED LESSON",start_lesson)
 welcome_vr = _button(column,"ENTER WITH VR",_enter_vr)
 _label(column,"Desktop: WASD / arrows to walk, right-drag to look.
Phone: move with the thumb pad, swipe right to look.",420,14)
 _label(column,"Early training build · One sail has cloth physics; the full rig is still in development.",420,13)
func _build_lesson() -> void:
 objective = _panel(hud,360)
 var column := VBoxContainer.new()
 column.add_theme_constant_override("separation",6)
 objective.add_child(column)
 eyebrow = _label(column,"FIRST WATCH",332,12)
 var heading := HBoxContainer.new()
 heading.add_theme_constant_override("separation",8)
 column.add_child(heading)
 objective_title = _label(heading,"",0,20)
 objective_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 details_button = _button(heading,"?",_toggle_details)
 details_button.custom_minimum_size = Vector2(48,48)
 details_button.size_flags_horizontal = Control.SIZE_SHRINK_END
 details_button.tooltip_text = "Explain this step"
 short_action = _label(column,"",332,15)
 navigation = _label(column,"",332,13)
 progress = ProgressBar.new()
 progress.custom_minimum_size.y = 4
 progress.show_percentage = false
 progress.max_value = 6
 column.add_child(progress)
 instruction = _label(column,"",332,15)
 instruction.visible = false
 wind_label = _label(column,"",332,13)
 wind_label.visible = false
 lesson_menu = _button(hud,"MENU",_open_menu)
 lesson_menu.set_anchors_preset(Control.PRESET_TOP_RIGHT)
 lesson_menu.offset_left = -96
 lesson_menu.offset_right = -16
 lesson_menu.offset_top = 16
 lesson_menu.offset_bottom = 64
 lesson_menu.size_flags_horizontal = Control.SIZE_SHRINK_END
 lesson_vr = lesson_menu # VR entry is an explicit option inside the menu.
 keyboard_hint = _label(hud,"WASD / arrows · walk\nRight-drag · look\nR · take hold",224,13)
 keyboard_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
 touch_pad = preload("res://scripts/deck_touch_pad.gd").new()
 hud.add_child(touch_pad)
 touch_pad.moved.connect(_touch_motion)
 station_panel = _panel(hud,0)
 var station_column := VBoxContainer.new()
 station_column.add_theme_constant_override("separation",6)
 station_panel.add_child(station_column)
 station_header = HBoxContainer.new()
 station_column.add_child(station_header)
 station_title = _label(station_header,"",0,17)
 station_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 leave_button = _button(station_header,"×",deck.release)
 leave_button.custom_minimum_size = Vector2(48,48)
 leave_button.size_flags_horizontal = Control.SIZE_SHRINK_END
 leave_button.tooltip_text = "Let go of this station (R)"
 station_status = _label(station_column,"",0,14)
 station_meter = Control.new()
 station_meter.custom_minimum_size.y = 22
 station_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
 station_column.add_child(station_meter)
 station_meter.draw.connect(_draw_rudder)
 use_button = _button(station_column,"TAKE HOLD",_use_nearest)
 rope_actions = HBoxContainer.new()
 rope_actions.add_theme_constant_override("separation",8)
 station_column.add_child(rope_actions)
 for item: Array in [["HAUL",-1.0],["EASE",1.0]]:
  var b := _button(rope_actions,item[0],func(): pass)
  b.button_down.connect(deck.pull.bind(item[1]))
  b.button_up.connect(deck.stop_hands)
 var belay_button := _button(rope_actions,"BELAY",_belay)
 var gold := StyleBoxFlat.new()
 gold.bg_color = Color(0.38,0.30,0.13)
 gold.set_corner_radius_all(4)
 belay_button.add_theme_stylebox_override("normal",gold)
 wheel_actions = HBoxContainer.new()
 wheel_actions.add_theme_constant_override("separation",8)
 station_column.add_child(wheel_actions)
 for item: Array in [["PORT",-1.0],["STARBOARD",1.0]]:
  var b := _button(wheel_actions,item[0],func(): pass)
  b.button_down.connect(deck.pull.bind(item[1]))
  b.button_up.connect(deck.stop_hands)
func _build_menu() -> void:
 menu_layer = Control.new()
 menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 hud.add_child(menu_layer)
 var shade := ColorRect.new()
 shade.color = Color(0.015,0.025,0.03,0.78)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 menu_layer.add_child(shade)
 menu_panel = _panel(menu_layer,480)
 menu_panel.set_anchors_preset(Control.PRESET_CENTER)
 menu_scroll = ScrollContainer.new()
 menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 menu_panel.add_child(menu_scroll)
 var column := VBoxContainer.new()
 menu_content = column
 column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 column.add_theme_constant_override("separation",10)
 menu_scroll.add_child(column)
 menu_heading = _label(column,"Watch menu",420,26)
 resume_button = _button(column,"RESUME",_close_menu)
 menu_help = _label(column,"",420,14)
 touch_toggle = CheckButton.new()
 touch_toggle.text = "Show touch controls"
 touch_toggle.custom_minimum_size.y = 48
 column.add_child(touch_toggle)
 touch_toggle.toggled.connect(func(value: bool): touch_mode = value; touch_pad.reset(); _layout())
 restart_button = _button(column,"RESTART LESSON",start_lesson)
 menu_vr = _button(column,"ENTER VR",_enter_vr)
 menu_extra.append(_button(column,"ENGINEERING TOOLS",enter_workshop))
 menu_extra.append(_button(column,"RETURN TO START",_show_welcome))
 menu_layer.visible = false
func _touch_motion(value: Vector2) -> void:
 if game==null or not active or menu_layer.visible: return
 _motion_owned = true
 game.player.motion_input = value
func _draw_rudder() -> void:
 var width := station_meter.size.x
 var y := 11.0
 station_meter.draw_line(Vector2(8,y),Vector2(width-8,y),Color(0.42,0.50,0.49),2)
 for value in [-32.0,0.0,32.0]:
  var x := remap(value,-32,32,8,width-8)
  station_meter.draw_line(Vector2(x,y-5),Vector2(x,y+5),Color(0.75,0.78,0.72),1.5)
 var x := remap(clampf(rad_to_deg(deck.mechanics.actual_rudder_angle),-32,32),-32,32,8,width-8)
 station_meter.draw_circle(Vector2(x,y),5,Color(0.92,0.74,0.35))
func _enter_vr() -> void:
 if not game.vr.supported: return
 _close_menu()
 if not active: start_lesson()
 if active: game.vr.enter()
func _engaged(index: int) -> bool:
 if not game.vr.active: return deck.current==index
 var station: Dictionary = deck.stations[index]
 for id: int in game.vr.grips.keys():
  var hand: RefCounted = game.vr.grips[id]
  if station.kind=="helm" and hand.wheel_held: return true
  if station.kind!="helm" and hand.brace_held==station.index:
   if (station.kind=="clew")==game.vr.clew_grips.has(id): return true
 return false
func _show_welcome() -> void:
 _close_menu()
 deck.release()
 touch_pad.reset()
 game.player.movement_enabled = false
 active = false
 workshop = false
 hud.visible = true
 welcome.visible = true
 objective.visible = false
 for node in hud.get_children():
  if node!=welcome: node.visible = false
 _hide_workshop()
func _hide_workshop() -> void:
 game.normal_ui.visible = false
 game.status.visible = false
 for node in [game.fly_toggle,game.pin_button,game.photo_ui,game.restore_hud_button,game.coop_toggle,game.vr_button]: node.visible = false
 game.spatial_qa.export_button.visible = false
func enter_workshop() -> void:
 _close_menu()
 touch_pad.reset()
 game.player.movement_enabled = not game.god_mode
 deck.release()
 active = false
 workshop = true
 if marker!=null: marker.visible = false
 hud.visible = false
 game.normal_ui.visible = true
 game.status.visible = true
 for node in [game.fly_toggle,game.pin_button,game.photo_ui,game.coop_toggle,game.vr_button]: node.visible = true
 # A workshop route back into the trainer, without another page load.
 if not game.normal_ui.has_node("StartFirstWatch"):
  var b := Button.new()
  b.name = "StartFirstWatch"
  b.text = "SAILING LESSON"
  b.position = Vector2(16,354)
  b.custom_minimum_size = Vector2(180,42)
  game.normal_ui.add_child(b)
  b.pressed.connect(start_lesson)
func start_lesson() -> void:
 _close_menu()
 if game.session.active:
  game.coop_status.text = "Leave co-op before starting this solo lesson."
  return
 if game.god_mode: game._toggle_fly()
 game.photo_mode = false
 game.player.movement_enabled = true
 deck.release()
 _keys.clear()
 _move_keys.clear()
 _motion_owned = false
 touch_pad.reset()
 game.active_walk_buttons.clear()
 game._update_walk_vector()
 game._brace_stop()
 game.rudder = 0.0
 game.boat.rudder_input = 0.0
 var rig: Node3D = deck.mechanics
 rig.reset_clew_sheets()
 rig.helm.connected = true
 rig.helm.wheel_angle = 0.0
 rig.helm.wheel_velocity = 0.0
 rig.helm.rudder_angle = 0.0
 rig.helm.rudder_velocity = 0.0
 rig.set_helm_torque(0.0)
 if game.flooding_system!=null:
  for compartment: Dictionary in game.flooding_system.compartments:
   compartment.water = 0.0
   compartment.leak_area = 0.0
   compartment.integrity = 1.0
  game.flooding_system.water_m3 = 0.0
 game.boat.set_force_trial(true)
 var weather: Node = game.get_node("Weather")
 weather.set_scenario("Calm")
 weather.state = weather.field.sample(Vector2.ZERO,Ocean.time)
 weather.sea_scale = weather.state.target_sea_scale
 weather._apply_state(0.0)
 game.weather_choice.select(1)
 # Start on the main deck beside the first lesson station, with actual deck walking.
 game.player.global_position = game.boat.to_global(Vector3(-0.2,2.04,-1.3))
 game.player.velocity = Vector3.ZERO
 game.player._old_ship_transform = game.boat.global_transform
 game.player._has_ship_transform = true
 game.view_yaw = 0.95
 game.view_pitch = -0.12
 game._deck_camera()
 starting_sheet = deck.mechanics.cloth.lines[0].length
 centered_seconds = 0.0
 stage = 0
 target_index = 1
 active = true
 workshop = false
 hud.visible = true
 for node in hud.get_children(): node.visible = node!=welcome and node!=menu_layer
 details_open = false
 instruction.visible = false
 wind_label.visible = false
 details_button.text = "?"
 _layout_key = ""
 marker.visible = true
 _settle_layout()
 _hide_workshop()
 _log_state()
func _use_nearest() -> void:
 if deck.current>=0: deck.release()
 else: deck.take(deck.nearest())
func _belay() -> void:
 deck.belay()
func _station_changed() -> void:
 _keys.clear()
 _move_keys.clear()
 if _motion_owned: game.player.motion_input = Vector2.ZERO
 _motion_owned = false
 _layout_key = ""
 if active: _log_state()
func release_event(event: InputEvent) -> void:
 if not active: return
 if event is InputEventScreenTouch:
  if event.pressed and not touch_mode:
   touch_mode = true
   touch_toggle.button_pressed = true
   _layout_key = ""
  if event.pressed and touch_pad.capture_screen_touch(event.index,event.position):
   get_viewport().set_input_as_handled()
  elif not event.pressed: touch_pad.release_finger(event.index)
 if event is InputEventScreenDrag and touch_pad.drag_screen_touch(event.index,event.position):
  get_viewport().set_input_as_handled()
 if event is InputEventKey and not event.pressed:
  _move_keys.erase(event.keycode)
  _update_keyboard_walk()
 if event is InputEventKey and not event.pressed and event.keycode in [KEY_A,KEY_D,KEY_Q,KEY_E]:
  _keys.erase(event.keycode)
  _keyboard_pull()
func handle_input(event: InputEvent) -> bool:
 if not active: return not workshop and event is InputEventKey
 if not event is InputEventKey: return false
 if menu_layer.visible: return true
 if event.pressed and event.keycode==KEY_ESCAPE: _open_menu(); return true
 if deck.current<0 and event.keycode in [KEY_W,KEY_A,KEY_S,KEY_D]:
  if event.pressed: _move_keys[event.keycode] = true
  else: _move_keys.erase(event.keycode)
  _update_keyboard_walk()
  return true
 if event.echo: return true
 if event.keycode in [KEY_A,KEY_D,KEY_Q,KEY_E]:
  if event.pressed: _keys[event.keycode] = true
  else: _keys.erase(event.keycode)
  _keyboard_pull()
  return true
 if event.pressed:
  if event.keycode==KEY_R: _use_nearest(); return true
  if event.keycode==KEY_B: _belay(); return true
 return event.keycode in [KEY_W,KEY_S,KEY_F,KEY_P]
func _update_keyboard_walk() -> void:
 var axis := Vector2.ZERO
 if _move_keys.has(KEY_A): axis.x -= 1
 if _move_keys.has(KEY_D): axis.x += 1
 if _move_keys.has(KEY_W): axis.y -= 1
 if _move_keys.has(KEY_S): axis.y += 1
 if axis.length()>0.01 or _motion_owned:
  _motion_owned = axis.length()>0.01
  game.player.motion_input = axis.normalized() if _motion_owned else touch_pad.axis
func _keyboard_pull() -> void:
 var value := 0.0
 if deck.current>=0:
  var wheel: bool = deck.stations[deck.current].kind=="helm"
  if _keys.has(KEY_A if wheel else KEY_Q): value -= 1.0
  if _keys.has(KEY_D if wheel else KEY_E): value += 1.0
 if is_zero_approx(value): deck.stop_hands()
 else: deck.pull(value)
func _advance(value: int) -> void:
 stage = value
 if stage>=3: target_index = 0
 _log_state()
func _process(delta: float) -> void:
 if game==null: return
 _tick_layout()
 welcome_vr.visible = game.vr.supported and welcome.visible
 menu_vr.visible = game.vr.supported and not details_open
 if workshop: return
 _hide_workshop()
 if not active or menu_layer.visible: return
 var lines: Array = deck.mechanics.cloth.lines
 match stage:
  0:
   if _engaged(1):
    starting_sheet = lines[0].length
    _advance(1)
  1:
   if starting_sheet-float(lines[0].length)>=0.12 and lines[0].mode==1: _advance(2)
  2:
   if starting_sheet-float(lines[0].length)>=0.10 and lines[0].mode==0: _advance(3)
  3:
   if _engaged(0): _advance(4)
  4:
   if _engaged(0) and rad_to_deg(deck.mechanics.actual_rudder_angle)>=5.0: _advance(5)
  5:
   if _engaged(0) and absf(rad_to_deg(deck.mechanics.actual_rudder_angle))<=2.0:
    centered_seconds += delta
    if centered_seconds>=0.8: _advance(6)
   else: centered_seconds = 0.0
 var titles := ["01 / FIND THE FORE SHEET","02 / HAUL THE SHEET","03 / BELAY THE SHEET","04 / WALK AFT TO THE WHEEL","05 / PUT THE HELM TO STARBOARD","06 / BRING THE RUDDER AMIDSHIPS","FIRST WATCH COMPLETE"]
 var text := ["Follow the gold label to the PORT FORE SHEET. Stand beside its pin and choose USE STATION. A sheet holds a sail's lower corner, called its clew.","Hold HAUL (or Q) to shorten the sheet by 12 cm. Watch the line and the lower fore sail take the load. This hand can slip if the load is too high.","Choose BELAY (or B) to secure the sheet at the pin. Stopping your pull alone does not secure a rope.","Leave the sheet station. Walk aft along the deck, up the central quarterdeck stairs, then beside the wheel. USE STATION takes hold of it. Braces, along the way, turn a yard.","Hold STBD (or D) until the actual rudder reaches 5 degrees. The wheel pulls steering lines, which move the tiller and rudder. Watch the readout respond.","Use PORT (or A) in short pulls. Bring the actual rudder within 2 degrees of center and hold it there. The wheel may backdrive when released.","You hauled and secured a real simulated sheet, walked between stations, and operated the wheel transmission. Keep practicing at the five stations. A rudder turns the ship only when water flows past it."]
 if game.vr.active:
  text[0] = "Walk to the PORT FORE SHEET. Squeeze beside the pin to grip the tail. A sheet holds the sail's lower corner (clew)."
  text[1] = "Keep squeezing and draw the rope away from its block to haul 12 cm. Feed your hand back toward the block to ease."
  text[2] = "Press the trigger beside the pin to BELAY. Letting go without belaying frees the rope."
  text[3] = "Go aft, up the central quarterdeck stairs. Squeeze the wheel rim to take hold. Thumbstick: walk."
  text[4] = "Squeeze and turn the wheel clockwise until the actual rudder reaches 5 degrees to starboard."
  text[5] = "Turn back toward port. Center the actual rudder within 2 degrees. Hold it there; the wheel can backdrive."
  game.vr.training_prompt = titles[stage]+"\n"+["Find the port fore-sheet pin.","Grip; pull away from the block to haul.","Trigger beside the pin to belay.","Go aft and up the stairs to the wheel.","Grip and turn clockwise to starboard.","Counter-steer; center within 2 degrees.","Introduction complete; practice freely."][stage]
 var compact_titles := ["Find the fore sheet","Haul the sheet","Belay the sheet","Take the wheel","Turn to starboard","Center the rudder","First watch complete"]
 var actions := ["Walk to the marked port pin.","Hold Haul to take in 12 cm.","Secure the sheet on its pin.","Go aft, up the central stairs.","Hold Starboard until rudder reaches 5°.","Counter-steer; hold within 2°.","Practice at any of the five stations."]
 eyebrow.text = "FIRST WATCH  ·  %d OF 6"%mini(stage+1,6) if stage<6 else "INTRODUCTION COMPLETE"
 objective_title.text = compact_titles[stage]
 short_action.text = actions[stage]
 progress.value = stage
 instruction.text = text[stage]
 var station: Dictionary = deck.stations[target_index]
 var p: Vector3 = game.boat.to_local(game.player.global_position)
 var distance := Vector2(p.x-station.point.x,p.z-station.point.z).length()
 navigation.text = "%s  ·  %.1f m"%[station.label,distance]
 if stage==1: navigation.text = "Taken in: %.0f / 12 cm"%[maxf(0,starting_sheet-float(lines[0].length))*100]
 elif stage==2: navigation.text = "Belay holds the rope after you let go."
 elif stage in [4,5]: navigation.text = "Actual rudder: %+.1f°"%rad_to_deg(deck.mechanics.actual_rudder_angle)
 elif stage==6: navigation.text = "Open the menu to repeat the introduction."
 marker.position = station.point+Vector3.UP*0.95
 marker.text = ("PORT FORE SHEET" if target_index==1 else "STEERING WHEEL")+"\n%.1f m"%distance
 marker.visible = stage<6
 var relative: Vector3 = game.boat.global_basis.inverse()*(game.boat.wind_world-game.boat.linear_velocity)
 var incoming := -relative
 var angle := rad_to_deg(acos(clampf(Vector3.FORWARD.dot(incoming.normalized()),-1,1)))
 var side := "STARBOARD" if incoming.x>=0 else "PORT"
 wind_label.text = "Wind from %s · %.0f° off bow · %.1f m/s\nPort = left / Starboard = right"%[side.to_lower(),angle,relative.length()]
 _update_station_panel()
 var layout_key := "%s/%s/%s"%[touch_mode,deck.current>=0,deck.nearest()>=0]
 if layout_key!=_layout_key:
  _layout_key = layout_key
  objective.reset_size()
  _layout()
  _settle_layout()
 log_clock += delta
 if log_clock>=0.5:
  log_clock = 0.0
  _log_state()
func _update_station_panel() -> void:
 var nearby: int = deck.nearest()
 var current: int = deck.current
 var selected: int = current if current>=0 else nearby
 station_panel.visible = selected>=0
 use_button.visible = current<0
 use_button.disabled = nearby<0
 station_header.visible = current>=0
 station_status.visible = current>=0
 station_meter.visible = current>=0 and deck.stations[current].kind=="helm"
 rope_actions.visible = current>=0 and deck.stations[current].kind!="helm"
 wheel_actions.visible = current>=0 and deck.stations[current].kind=="helm"
 if selected<0: return
 var station: Dictionary = deck.stations[selected]
 station_title.text = station.label.replace("fore clew","fore")
 use_button.text = "TAKE WHEEL" if station.kind=="helm" else ("TAKE SHEET" if station.kind=="clew" else "TAKE BRACE")
 if not touch_mode: use_button.text += "  [R]"
 if station.kind=="helm":
  station_status.text = "Rudder %+.1f° · %s"%[rad_to_deg(deck.mechanics.actual_rudder_angle),"Starboard" if deck.mechanics.actual_rudder_angle>0 else "Port"]
  station_meter.queue_redraw()
 else:
  var rig: RefCounted = deck.mechanics.cloth if station.kind=="clew" else deck.mechanics.brace
  var line: Dictionary = rig.lines[station.index]
  station_status.text = "%s · %.2f m · %.0f N"%[["Belayed","In hand","Running free","Cut"][int(line.mode)],line.length,line.tension]
 keyboard_hint.text = "WASD / arrows · walk\nRight-drag · look\nR · take hold"
func _log_state() -> void:
 if not active: return
 var p: Vector3 = game.boat.to_local(game.player.global_position)
 var state := {"stage":stage,"station":deck.current,"nearby":deck.nearest(),"player":[p.x,p.y,p.z],"yaw":game.view_yaw,"sheet_m":deck.mechanics.cloth.lines[0].length,"sheet_mode":deck.mechanics.cloth.lines[0].mode,"rudder_deg":rad_to_deg(deck.mechanics.actual_rudder_angle),"use":[use_button.get_global_rect().get_center().x,use_button.get_global_rect().get_center().y],"force_trial":game.boat.force_trial}
 state["menu_button"] = _center(lesson_menu)
 state["touch_mode"] = touch_mode
 state["touch_owner"] = touch_pad.finger_id
 state["look_owner"] = game.deck_look_touch
 state["move_axis"] = [game.player.motion_input.x,game.player.motion_input.y]
 state["hold_buttons"] = [_center(rope_actions.get_child(0)),_center(rope_actions.get_child(1)),_center(rope_actions.get_child(2))]
 print("APEX LESSON STATE ",JSON.stringify(state))
func _center(control: Control) -> Array:
 var point := control.get_global_rect().get_center()
 return [point.x,point.y]
func _notification(what: int) -> void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT and deck!=null:
  _keys.clear()
  _move_keys.clear()
  touch_pad.reset()
  deck.stop_hands()
