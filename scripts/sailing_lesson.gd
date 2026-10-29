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
var welcome_start: Button
func setup(root: Node3D) -> void:
 game = root
 deck = Stations.new()
 deck.name = "DeckStations"
 add_child(deck)
 deck.setup(game)
 hud = Control.new()
 hud.name = "FirstWatchHUD"
 hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
 game.hud_layer.add_child(hud)
 _build_welcome()
 _build_lesson()
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
 get_viewport().size_changed.connect(_layout)
 _layout()
 var skip := DisplayServer.get_name()=="headless"
 if OS.has_feature("web"):
  skip = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('mode') === 'workshop' || new URLSearchParams(location.search).get('simulation') === 'forces'"))
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--serve="): skip = true
 if skip: enter_workshop()
 else:
  _show_welcome()
  _report_welcome.call_deferred()
func _report_welcome() -> void:
 await get_tree().process_frame
 await get_tree().process_frame
 if welcome.visible:
  var point := welcome_start.get_global_rect().get_center()
  print("APEX LESSON WELCOME ",JSON.stringify({"start":[point.x,point.y]}))
func _layout() -> void:
 var view := get_viewport().get_visible_rect().size
 var width := minf(520,view.x-32)
 welcome.custom_minimum_size.x = width
 welcome.offset_left = -width*0.5
 welcome.offset_right = width*0.5
 welcome.offset_top = -minf(230,view.y*0.5-16)
 for node in welcome.get_child(0).get_children():
  if node is Label: node.custom_minimum_size.x = width-28
 var narrow := view.x<760
 objective.position.y = 72 if narrow else 16
 objective.custom_minimum_size.x = minf(360,view.x-32)
 for label: Label in [objective_title,instruction,navigation,wind_label]: label.custom_minimum_size.x = minf(332,view.x-60)
 station_panel.offset_top = -224-(74 if narrow else 0)
 station_panel.offset_bottom = -16-(74 if narrow else 0)
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
 welcome = _panel(hud,490)
 welcome.set_anchors_preset(Control.PRESET_CENTER)
 welcome.offset_left = -245
 welcome.offset_right = 245
 welcome.offset_top = -180
 welcome.offset_bottom = 180
 var column := VBoxContainer.new()
 column.add_theme_constant_override("separation",12)
 welcome.add_child(column)
 _label(column,"APEX  /  FIRST WATCH",452,26)
 _label(column,"Learn aboard the ship",452,20)
 _label(column,"Haul and belay a fore sheet, then walk aft and operate the steering wheel.\n\nWalk: arrows or bottom buttons. Look: right-drag or swipe the open right side. Follow the gold station labels.",452)
 welcome_start = _button(column,"START FIRST LESSON",start_lesson)
 welcome_vr = _button(column,"VR: CHECKING HEADSET",_enter_vr)
 _button(column,"OPEN WORKSHOP / FREE INSPECTION",enter_workshop)
 _label(column,"Development build · One deforming sail; remaining rigging is incomplete. Restart resets the practice ship.",452,13)
func _build_lesson() -> void:
 objective = _panel(hud,360)
 objective.position = Vector2(16,16)
 var column := VBoxContainer.new()
 column.add_theme_constant_override("separation",8)
 objective.add_child(column)
 objective_title = _label(column,"FIRST WATCH",332,20)
 instruction = _label(column,"",332)
 navigation = _label(column,"",332,14)
 wind_label = _label(column,"",332,14)
 var toolbar := HBoxContainer.new()
 toolbar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
 toolbar.offset_left = -364
 toolbar.offset_right = -16
 toolbar.offset_top = 16
 hud.add_child(toolbar)
 lesson_vr = _button(toolbar,"VR",_enter_vr)
 _button(toolbar,"RESTART",start_lesson)
 _button(toolbar,"WORKSHOP",enter_workshop)
 var walking := HBoxContainer.new()
 walking.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
 walking.offset_left = 16
 walking.offset_top = -68
 hud.add_child(walking)
 for item: Array in [["LEFT","◀"],["FORWARD","▲"],["BACK","▼"],["RIGHT","▶"]]:
  var b := _button(walking,item[0],func(): pass)
  b.custom_minimum_size = Vector2(70,52)
  b.button_down.connect(game._walk_input.bind(item[1]))
  b.button_up.connect(game._walk_release.bind(item[1]))
 station_panel = _panel(hud,292)
 station_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
 station_panel.offset_left = -308
 station_panel.offset_right = -16
 station_panel.offset_top = -224
 station_panel.offset_bottom = -16
 var station_column := VBoxContainer.new()
 station_column.add_theme_constant_override("separation",6)
 station_panel.add_child(station_column)
 station_title = _label(station_column,"",264,18)
 station_status = _label(station_column,"",264,14)
 use_button = _button(station_column,"USE STATION [R]",_use_nearest)
 rope_actions = HBoxContainer.new()
 station_column.add_child(rope_actions)
 for item: Array in [["HAUL",-1.0],["EASE",1.0]]:
  var b := _button(rope_actions,item[0],func(): pass)
  b.button_down.connect(deck.pull.bind(item[1]))
  b.button_up.connect(deck.stop_hands)
 _button(rope_actions,"BELAY [B]",_belay)
 wheel_actions = HBoxContainer.new()
 station_column.add_child(wheel_actions)
 for item: Array in [["PORT [A]",-1.0],["STBD [D]",1.0]]:
  var b := _button(wheel_actions,item[0],func(): pass)
  b.button_down.connect(deck.pull.bind(item[1]))
  b.button_up.connect(deck.stop_hands)
 leave_button = _button(station_column,"LEAVE STATION [R]",deck.release)
func _enter_vr() -> void:
 if not game.vr.supported: return
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
 if game.session.active:
  game.coop_status.text = "Leave co-op before starting this solo lesson."
  return
 if game.god_mode: game._toggle_fly()
 game.photo_mode = false
 game.player.movement_enabled = true
 deck.release()
 _keys.clear()
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
 for node in hud.get_children(): node.visible = node!=welcome
 marker.visible = true
 _hide_workshop()
 _log_state()
func _use_nearest() -> void:
 if deck.current>=0: deck.release()
 else: deck.take(deck.nearest())
func _belay() -> void:
 deck.belay()
func _station_changed() -> void:
 _keys.clear()
 if active: _log_state()
func release_event(event: InputEvent) -> void:
 if not active: return
 if event is InputEventKey and not event.pressed and event.keycode in [KEY_A,KEY_D,KEY_Q,KEY_E]:
  _keys.erase(event.keycode)
  _keyboard_pull()
func handle_input(event: InputEvent) -> bool:
 if not active: return not workshop and event is InputEventKey
 if not event is InputEventKey: return false
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
 for b: Button in [welcome_vr,lesson_vr]:
  b.disabled = not game.vr.supported
  b.text = "ENTER VR" if game.vr.supported else ("VR UNAVAILABLE" if b==lesson_vr else "VR: HEADSET BROWSER REQUIRED")
  b.tooltip_text = "Open in a WebXR-capable headset browser. Desktop and touch controls remain available."
 if workshop: return
 _hide_workshop()
 if not active: return
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
  game.vr.training_prompt = titles[stage]+"\n"+text[stage]
 objective_title.text = titles[stage]
 instruction.text = text[stage]
 var station: Dictionary = deck.stations[target_index]
 var p: Vector3 = game.boat.to_local(game.player.global_position)
 var distance := Vector2(p.x-station.point.x,p.z-station.point.z).length()
 navigation.text = ("%.1f m to %s"%[distance,station.label]) if stage<6 else "Free practice · RESTART repeats this introduction."
 marker.position = station.point+Vector3.UP*0.95
 marker.text = ("PORT FORE SHEET" if target_index==1 else "STEERING WHEEL")+"\n%.1f m"%distance
 marker.visible = stage<6
 var relative: Vector3 = game.boat.global_basis.inverse()*(game.boat.wind_world-game.boat.linear_velocity)
 var incoming := -relative
 var angle := rad_to_deg(acos(clampf(Vector3.FORWARD.dot(incoming.normalized()),-1,1)))
 var side := "STARBOARD" if incoming.x>=0 else "PORT"
 wind_label.text = "WIND FROM %s · %.0f° off bow · %.1f m/s\nBow = front / Port = left / Starboard = right"%[side,angle,relative.length()]
 _update_station_panel()
 log_clock += delta
 if log_clock>=0.5:
  log_clock = 0.0
  _log_state()
func _update_station_panel() -> void:
 var nearby: int = deck.nearest()
 var current: int = deck.current
 var selected: int = current if current>=0 else nearby
 use_button.visible = current<0
 use_button.disabled = nearby<0
 leave_button.visible = current>=0
 rope_actions.visible = current>=0 and deck.stations[current].kind!="helm"
 wheel_actions.visible = current>=0 and deck.stations[current].kind=="helm"
 station_title.text = deck.stations[selected].label if selected>=0 else "Walk to a fitting"
 station_status.text = "Stand beside the gold marker.\nSwipe the open right side to look."
 if selected>=0:
  var station: Dictionary = deck.stations[selected]
  if station.kind=="helm":
   station_status.text = "Wheel %.0f° / Rudder %.1f°\nSteering lines %.0f / %.0f N"%[rad_to_deg(deck.mechanics.helm.wheel_angle),rad_to_deg(deck.mechanics.actual_rudder_angle),deck.mechanics.port_line_tension,deck.mechanics.starboard_line_tension]
  else:
   var rig: RefCounted = deck.mechanics.cloth if station.kind=="clew" else deck.mechanics.brace
   var line: Dictionary = rig.lines[station.index]
   station_status.text = "%s · %.2f m · %.0f N\n%s"%[["BELAYED","IN HAND","RUNNING FREE","CUT"][int(line.mode)],line.length,line.tension,"Q: haul / E: ease / B: belay" if current>=0 else "Use this pin to work its rope."]
func _log_state() -> void:
 if not active: return
 var p: Vector3 = game.boat.to_local(game.player.global_position)
 var state := {"stage":stage,"station":deck.current,"nearby":deck.nearest(),"player":[p.x,p.y,p.z],"yaw":game.view_yaw,"sheet_m":deck.mechanics.cloth.lines[0].length,"sheet_mode":deck.mechanics.cloth.lines[0].mode,"rudder_deg":rad_to_deg(deck.mechanics.actual_rudder_angle),"use":[use_button.get_global_rect().get_center().x,use_button.get_global_rect().get_center().y],"force_trial":game.boat.force_trial}
 print("APEX LESSON STATE ",JSON.stringify(state))
func _notification(what: int) -> void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT and deck!=null:
  _keys.clear()
  deck.stop_hands()
