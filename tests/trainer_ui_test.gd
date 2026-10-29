extends SceneTree
var failures: Array[String] = []
var game: Node3D
var lesson: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok:
  failures.append(message)
  if failures.size()<20: push_error(message)
func settle() -> void:
 lesson._process(0.016)
 lesson._layout()
 for frame in 3: await process_frame
 lesson._layout()
 for frame in 2: await process_frame
func inspect_layout(label: String) -> void:
 var screen := Rect2(Vector2.ZERO,Vector2(root.size))
 var controls: Array[Dictionary] = []
 for node in lesson.hud.find_children("*","Control",true,false):
  if not node.is_visible_in_tree(): continue
  if lesson.menu_layer.visible and not lesson.menu_layer.is_ancestor_of(node): continue
  if not (node is BaseButton or node==lesson.touch_pad): continue
  var rect: Rect2 = node.get_global_rect()
  if node is BaseButton:
   check(rect.size.y>=47.9,label+": touch target shorter than 48 px: "+str(node.name))
  # Deliberately scrollable menu/start content may lie beyond its scroll viewport.
  var ancestor: Node = node.get_parent()
  while ancestor!=null and ancestor!=lesson.hud:
   if ancestor is ScrollContainer: rect = rect.intersection(ancestor.get_global_rect())
   ancestor = ancestor.get_parent()
  if not rect.has_area(): continue
  check(screen.grow(0.2).encloses(rect),label+": visible target outside viewport: "+str(node.name)+" "+str(rect))
  for other: Dictionary in controls:
   var intersection := rect.intersection(other.rect)
   check(not intersection.has_area() or intersection.get_area()<1,label+": targets overlap: "+str(node.name)+" / "+other.name)
  controls.append({"name":str(node.name),"rect":rect})
 if not lesson.menu_layer.visible and lesson.station_panel.visible:
  var overlap: Rect2 = lesson.objective.get_global_rect().intersection(lesson.station_panel.get_global_rect())
  check(not overlap.has_area(),label+": task card and station panel overlap")
  if lesson.touch_pad.visible:
   check(not lesson.touch_pad.get_global_rect().intersects(lesson.objective.get_global_rect()),label+": move pad and task card overlap")
func run() -> void:
 root.size = Vector2i(960,540)
 game = load("res://physics_trial.tscn").instantiate()
 root.add_child(game)
 lesson = game.lesson
 lesson.start_lesson()
 game.set_process(false)
 game.boat.freeze = true
 game.boat.set_physics_process(false)
 game.player.set_physics_process(false)
 game.get_node("Weather").set_process(false)
 lesson.set_process(false)
 var deck: Node = lesson.deck
 for viewport: Vector2i in [Vector2i(960,540),Vector2i(800,360),Vector2i(640,360),Vector2i(390,844)]:
  root.size = viewport
  for touch: bool in [false,true]:
   lesson.touch_mode = touch
   lesson.touch_toggle.set_pressed_no_signal(touch)
   deck.release()
   game.player.global_position = game.boat.to_global(Vector3(1.2,2.04,0))
   await settle()
   check(not lesson.station_panel.visible,"No disabled station panel should persist away from fittings")
   inspect_layout("%s touch=%s walking"%[viewport,touch])
   game.player.global_position = game.boat.to_global(Vector3(-1.7,2.04,-2.9))
   await settle()
   check(lesson.use_button.visible and lesson.station_panel.visible,"Nearby fitting must offer Take hold")
   inspect_layout("%s touch=%s nearby"%[viewport,touch])
   check(deck.take(1),"Sheet must be reachable for UI fixture")
   await settle()
   check(lesson.rope_actions.visible and not lesson.wheel_actions.visible,"A held rope must expose only rope actions")
   inspect_layout("%s touch=%s rope"%[viewport,touch])
   deck.release()
   game.player.global_position = game.boat.to_global(Vector3(1,3.26,11.35))
   check(deck.take(0),"Wheel must be reachable for UI fixture")
   await settle()
   check(lesson.wheel_actions.visible and not lesson.rope_actions.visible,"A held wheel must expose only wheel actions")
   inspect_layout("%s touch=%s wheel"%[viewport,touch])
   lesson._open_menu()
   await settle()
   check(paused and not game.player.movement_enabled,"Menu must pause solo simulation and release movement input")
   inspect_layout("%s touch=%s menu"%[viewport,touch])
   lesson._close_menu()
   lesson._toggle_details()
   await settle()
   check(lesson.details_open and lesson.menu_layer.visible and not lesson.restart_button.visible,"Step explanation must be a focused modal")
   inspect_layout("%s touch=%s explanation"%[viewport,touch])
   lesson._close_menu()
 # Exercise actual resize notifications, not only explicit layout calls.
 deck.release()
 game.player.global_position = game.boat.to_global(Vector3(1.2,2.04,0))
 lesson.set_process(true)
 root.size = Vector2i(960,540)
 for frame in 6: await process_frame
 root.size = Vector2i(640,360)
 for frame in 8: await process_frame
 check(lesson.objective.size.x<190,"Compact resize must settle its new minimum width without a manual second layout call")
 inspect_layout("automatic compact resize")
 root.size = Vector2i(960,540)
 for frame in 8: await process_frame
 game.player.global_position = game.boat.to_global(Vector3(-1.7,2.04,-2.9))
 for frame in 8: await process_frame
 inspect_layout("automatic nearby transition")
 check(deck.take(1),"Automatic station transition fixture must take sheet")
 for frame in 8: await process_frame
 inspect_layout("automatic held transition")
 lesson.set_process(false)
 # Real ownership rules for simultaneous move/look fingers.
 root.size = Vector2i(960,540)
 deck.release()
 lesson.touch_mode = true
 game.player.global_position = game.boat.to_global(Vector3(1.2,2.04,0))
 await settle()
 var touch := InputEventScreenTouch.new()
 touch.pressed = true
 touch.index = 3
 touch.position = Vector2(62,18)
 lesson.touch_pad._gui_input(touch)
 check(lesson.touch_pad.finger_id==3 and game.player.motion_input.y<-.9,"Move pad must drive gaze-relative walking")
 # Browsers can emit an emulated mouse press before the original touch event.
 lesson.touch_pad.reset()
 var mouse := InputEventMouseButton.new()
 mouse.pressed = true
 mouse.button_index = MOUSE_BUTTON_LEFT
 mouse.position = Vector2(62,18)
 lesson.touch_pad._gui_input(mouse)
 check(lesson.touch_pad.finger_id==-2,"Mouse fallback fixture must own its drag")
 touch.position = lesson.touch_pad.get_global_rect().position+Vector2(62,18)
 game._input(touch)
 check(lesson.touch_pad.finger_id==3,"Real touch must supersede its emulated mouse without losing finger identity")
 touch.index = 4
 touch.position = Vector2(700,250)
 game._unhandled_input(touch)
 var yaw: float = game.view_yaw
 var head_pitch: float = game.view_pitch
 var drag := InputEventScreenDrag.new()
 drag.index = 4
 drag.position = Vector2(720,260)
 drag.relative = Vector2(720,260) # deliberately bad initial browser-relative delta
 game._input(drag)
 check(absf(game.view_yaw-(yaw-0.08))<0.0001 and absf(game.view_pitch-(head_pitch-0.03))<0.0001,"Touch look must use captured absolute displacement, avoiding a first-swipe jump")
 touch.index = 3
 touch.pressed = false
 game._input(touch)
 check(lesson.touch_pad.finger_id==-1 and game.player.motion_input==Vector2.ZERO,"Move finger must release even over another control")
 check(game.dragging and game.deck_look_touch==4,"Move release must preserve the look finger")
 touch.index = 4
 game._input(touch)
 check(not game.dragging,"Look finger must release independently")
 lesson.enter_workshop()
 check(not paused and not lesson.hud.visible,"Engineering tools must restore their own UI without a paused world")
 game.free()
 await process_frame
 if failures.is_empty(): print("APEX TRAINER UI TEST PASS: 48 viewport/input/state layouts, contextual controls, 48px targets, scroll clipping, modal pause and independent touch ownership")
 quit(0 if failures.is_empty() else 1)
