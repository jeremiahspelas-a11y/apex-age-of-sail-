extends Node3D
## Optional WebXR adapter. Hardware acceptance is required before claiming VR readiness.
signal availability(supported: bool)
signal message(text: String)
const HandInput = preload("res://scripts/vr_hand_input.gd")
var game: Node3D
var interface: WebXRInterface
var origin: XROrigin3D
var camera: XRCamera3D
var active := false
var supported := false
var comfort_horizon := true
var controllers: Dictionary = {}
var grips: Dictionary = {}
var clew_grips: Dictionary = {}
var command_clock := 0.0
var training_prompt := ""
var training_hint: Label3D
var feedback_text := ""
var feedback_left := 0.0
func setup(root: Node3D) -> void:
 game = root
 game.session.feedback.connect(func(text: String):
  feedback_text = text
  feedback_left = 3.0)
 origin = XROrigin3D.new()
 add_child(origin)
 camera = XRCamera3D.new()
 camera.current = false
 origin.add_child(camera)
 interface = XRServer.find_interface("WebXR") as WebXRInterface
 if interface==null:
  availability.emit(false)
  return
 interface.session_supported.connect(func(mode: String,value: bool):
  if mode=="immersive-vr": supported = value; availability.emit(value))
 interface.session_started.connect(_started)
 interface.session_ended.connect(_ended)
 interface.session_failed.connect(func(reason: String): message.emit(reason); _ended())
 interface.squeezestart.connect(_grab)
 interface.squeezeend.connect(_release)
 interface.selectstart.connect(_belay_near_pin)
 interface.visibility_state_changed.connect(func():
  if interface.visibility_state!="visible": _release_all())
 interface.is_session_supported("immersive-vr")
func enter() -> bool:
 if not supported or interface==null: return false
 interface.session_mode = "immersive-vr"
 interface.requested_reference_space_types = "local-floor, local"
 interface.required_features = "local-floor"
 interface.optional_features = "bounded-floor"
 return interface.initialize()
func _started() -> void:
 if not game.boat.force_trial: game._toggle_force_trial()
 active = true
 get_viewport().use_xr = true
 camera.make_current()
 game.player.view = camera
 game.player.read_keyboard = false
 game.hud_layer.visible = false
 var hint := Label3D.new()
 training_hint = hint
 hint.text = "Grip: wheel / rope tail\nTrigger at pin: belay\nThumbstick: walk"
 hint.font_size = 20
 hint.pixel_size = 0.0015
 hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 hint.width = 470
 hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 game.boat.add_child(hint)
 _place_origin()
func _ended() -> void:
 _release_all()
 active = false
 get_viewport().use_xr = false
 game.camera.make_current()
 game.player.view = game.camera
 game.player.read_keyboard = true
 game.player.motion_input = Vector2.ZERO
 game.hud_layer.visible = true
 if is_instance_valid(training_hint): training_hint.queue_free()
 for child in camera.get_children(): child.queue_free()
 training_hint = null
 training_prompt = ""
func _place_origin() -> void:
 origin.global_position = game.player.global_position-Vector3.UP*0.9
 if interface!=null and interface.reference_space_type=="local": origin.global_position += Vector3.UP*1.6
 origin.global_basis = Basis(Vector3.UP,game.boat.global_rotation.y+game.view_yaw) if comfort_horizon else game.boat.global_basis*Basis(Vector3.UP,game.view_yaw)
func _controller(id: int) -> XRController3D:
 if controllers.has(id): return controllers[id]
 if interface==null: return null
 var tracker := interface.get_input_source_tracker(id)
 if tracker==null: return null
 var node := XRController3D.new()
 node.tracker = tracker.name
 node.pose = "grip"
 origin.add_child(node)
 var visual := MeshInstance3D.new()
 var sphere := SphereMesh.new()
 sphere.radius = 0.04
 sphere.height = 0.08
 visual.mesh = sphere
 node.add_child(visual)
 var label := Label3D.new()
 label.name = "NearbyStationHint"
 label.font_size = 22
 label.pixel_size = 0.0012
 label.position = Vector3(0,0.10,0)
 label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 node.add_child(label)
 controllers[id] = node
 return node
func _grab(id: int) -> void:
 if not active: return
 var hand := _controller(id)
 if hand==null: return
 var rig: Node3D = game.boat.get_node("Mechanisms")
 var input := HandInput.new()
 # Wheel-plane coordinates must exclude the wheel's own changing rotation.
 var wheel_point: Vector3 = game.boat.to_local(hand.global_position)-rig.wheel.position
 if input.grab_wheel(wheel_point,rig.helm.wheel_angle):
  grips[id] = input
  return
 for i in rig.brace.lines.size():
  var pin: Vector3 = rig.loaded_yard.position+rig.brace.lines[i].belay
  if input.grab_brace(i,game.boat.to_local(hand.global_position),pin):
   grips[id] = input
   return
 for i in rig.cloth.lines.size():
  if input.grab_brace(i,game.boat.to_local(hand.global_position),rig.cloth.lines[i].belay):
   grips[id] = input
   clew_grips[id] = true
   return
func _dispatch(action: String,value: float = 0.0,index: int = 0) -> void:
 if game.session.active:
  game.session.send_action(action,value,index)
  return
 var rig: Node3D = game.boat.get_node("Mechanisms")
 match action:
  "helm_torque": rig.set_helm_torque(value)
  "brace_pull": rig.brace.set_hand(index,value)
  "brace_free": rig.brace.release(index)
  "brace_belay": rig.brace.belay(index)
  "clew_pull": rig.cloth.set_hand(index,value)
  "clew_free": rig.cloth.release(index)
  "clew_belay": rig.cloth.belay(index)
func _release(id: int) -> void:
 if not grips.has(id): return
 var input: RefCounted = grips[id]
 if input.wheel_held: _dispatch("helm_torque",0.0)
 if input.brace_held>=0: _dispatch("clew_free" if clew_grips.has(id) else "brace_free",0.0,input.brace_held)
 input.release()
 grips.erase(id)
 clew_grips.erase(id)
func _release_all() -> void:
 for id: int in grips.keys(): _release(id)
func _belay_near_pin(id: int) -> void:
 var hand := _controller(id)
 if hand==null: return
 var rig: Node3D = game.boat.get_node("Mechanisms")
 var p: Vector3 = game.boat.to_local(hand.global_position)
 for i in rig.brace.lines.size():
  if p.distance_to(rig.loaded_yard.position+rig.brace.lines[i].belay)<0.45:
   # Belay before clearing the grip so a later squeeze release cannot free it.
   _release(id)
   _dispatch("brace_belay",0.0,i)
   return
 for i in rig.cloth.lines.size():
  if p.distance_to(rig.cloth.lines[i].belay)<0.45:
   _release(id)
   _dispatch("clew_belay",0.0,i)
   return
func hint_at(point: Vector3,id: int = -1) -> String:
 var rig: Node3D = game.boat.get_node("Mechanisms")
 if grips.has(id):
  var held: RefCounted = grips[id]
  if held.wheel_held: return "WHEEL GRIPPED\nTurn your hand / release to let go"
  return "ROPE IN HAND\nPull away: haul / feed back: ease\nTrigger at pin: belay"
 var probe := HandInput.new()
 if probe.grab_wheel(point-rig.wheel.position,rig.helm.wheel_angle):
  return "STEERING WHEEL\nSqueeze the rim to grip"
 for i in rig.cloth.lines.size():
  if point.distance_to(rig.cloth.lines[i].belay)<0.4:
   return ("PORT" if i==0 else "STARBOARD")+" CLEW SHEET\nSqueeze: grip / trigger: belay"
 for i in rig.brace.lines.size():
  if point.distance_to(rig.loaded_yard.position+rig.brace.lines[i].belay)<0.4:
   return ("PORT" if i==0 else "STARBOARD")+" YARD BRACE\nSqueeze: grip / trigger: belay"
 return ""
func _physics_process(delta: float) -> void:
 if not active: return
 _place_origin()
 feedback_left = maxf(0,feedback_left-delta)
 if training_hint!=null:
  var rig: Node3D = game.boat.get_node("Mechanisms")
  training_hint.text = feedback_text if feedback_left>0 else (training_prompt if not training_prompt.is_empty() else "Grip: wheel / rope tail | Trigger at pin: belay | Thumbstick: walk")
  training_hint.text += "\nRudder %.1f deg | Fore sheets %.0f / %.0f N"%[rad_to_deg(rig.actual_rudder_angle),rig.cloth.lines[0].tension,rig.cloth.lines[1].tension]
  var point: Vector3 = rig.wheel.position
  if game.lesson!=null and game.lesson.active:
   point = game.lesson.deck.stations[game.lesson.target_index].point
  training_hint.position = point+Vector3.UP*0.65
  training_hint.visible = game.player.global_position.distance_to(training_hint.global_position)<5.0
 for id in range(16):
  if interface.is_input_source_active(id): _controller(id)
 for id: int in controllers.keys():
  controllers[id].visible = interface.is_input_source_active(id)
  if controllers[id].visible:
   var label: Label3D = controllers[id].get_node("NearbyStationHint")
   label.text = hint_at(game.boat.to_local(controllers[id].global_position),id)
 for id: int in grips.keys():
  if not interface.is_input_source_active(id): _release(id)
 command_clock += delta
 if command_clock<0.05: return
 var dt := command_clock
 command_clock = 0.0
 var rig: Node3D = game.boat.get_node("Mechanisms")
 var torque := 0.0
 var wheel_gripped := false
 for id: int in grips.keys():
  var input: RefCounted = grips[id]
  var hand: XRController3D = controllers[id]
  var p: Vector3 = game.boat.to_local(hand.global_position)
  if input.wheel_held:
   var distance: Vector3 = p-rig.wheel.position
   if distance.length()>1.4 or absf(distance.z)>0.8:
    _release(id)
    continue
   wheel_gripped = true
   torque += input.wheel_torque(p-rig.wheel.position,rig.helm.wheel_angle,rig.helm.wheel_velocity)
  elif input.brace_held>=0:
   var i: int = input.brace_held
   var line_rig: RefCounted = rig.cloth if clew_grips.has(id) else rig.brace
   var pin: Vector3 = line_rig.lines[i].belay+(Vector3.ZERO if clew_grips.has(id) else rig.loaded_yard.position)
   if p.distance_to(pin)>1.6:
    _release(id)
    continue
   var axis: Vector3 = line_rig.lines[i].lead-line_rig.lines[i].belay
   _dispatch("clew_pull" if clew_grips.has(id) else "brace_pull",input.brace_pull(p,axis,dt),i)
 if wheel_gripped: _dispatch("helm_torque",clampf(torque,-129.6,129.6))
 game.player.motion_input = Vector2.ZERO
 for hand: XRController3D in controllers.values():
  var value: Variant = hand.get_input("thumbstick")
  if value is Vector2 and value.length()>0.15:
   game.player.motion_input = value.limit_length(1.0)
