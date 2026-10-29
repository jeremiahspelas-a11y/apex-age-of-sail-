extends Control
## One owned finger moves; the game's open right side independently owns looking.
signal moved(axis: Vector2)
var finger_id := -1
var axis := Vector2.ZERO
func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_STOP
 custom_minimum_size = Vector2(124,124)
func _update(point: Vector2) -> void:
 axis = ((point-size*0.5)/44.0).limit_length(1.0)
 moved.emit(axis)
 queue_redraw()
func capture_screen_touch(index: int,point: Vector2) -> bool:
 if not is_visible_in_tree() or not get_global_rect().has_point(point) or finger_id not in [-1,-2]: return false
 finger_id = index
 _update(point-get_global_rect().position)
 return true
func drag_screen_touch(index: int,point: Vector2) -> bool:
 if finger_id!=index: return false
 _update(point-get_global_rect().position)
 return true
func release_finger(index: int) -> void:
 if finger_id!=index: return
 reset()
func reset() -> void:
 finger_id = -1
 axis = Vector2.ZERO
 moved.emit(axis)
 queue_redraw()
func _gui_input(event: InputEvent) -> void:
 if event is InputEventScreenTouch:
  if event.pressed and finger_id in [-1,-2]:
   finger_id = event.index
   _update(event.position)
  elif not event.pressed: release_finger(event.index)
  accept_event()
 elif event is InputEventScreenDrag and event.index==finger_id:
  _update(event.position)
  accept_event()
 elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed and finger_id==-1: finger_id = -2; _update(event.position)
  elif not event.pressed and finger_id==-2: reset()
  accept_event()
 elif event is InputEventMouseMotion and finger_id==-2:
  _update(event.position)
  accept_event()
func _draw() -> void:
 var center := size*0.5
 draw_circle(center,49,Color(0.025,0.055,0.065,0.65))
 draw_arc(center,48,0,TAU,48,Color(0.78,0.80,0.73,0.65),1.5)
 for direction: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
  draw_line(center+direction*33,center+direction*39,Color(0.78,0.80,0.73,0.7),2.0)
 draw_circle(center+axis*36,20,Color(0.77,0.68,0.42,0.85) if finger_id!=-1 else Color(0.73,0.77,0.73,0.65))
