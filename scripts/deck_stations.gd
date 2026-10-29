extends Node
## Desktop/touch adapter for the existing mechanical cores. Positions follow the hull.
## Proximity is a local interaction affordance; network authorization remains CrewSession.
const Refit = preload("res://scripts/ship_refit.gd")
var game: Node3D
var stations: Array[Dictionary] = []
var current := -1
var held := 0.0
var command_clock := 0.0
var mechanics: Node3D
signal changed
func setup(root: Node3D) -> void:
 game = root
 mechanics = game.boat.get_node("Mechanisms")
 stations.append({"id":"helm","label":"Steering wheel","point":mechanics.wheel.position,"deck":Refit.QUARTER_TOP,"kind":"helm","index":0})
 for side in 2:
  var label := "Port" if side==0 else "Starboard"
  stations.append({"id":"clew_%d"%side,"label":label+" fore clew sheet","point":mechanics.cloth.lines[side].belay,"deck":Refit.MAIN_TOP,"kind":"clew","index":side})
  stations.append({"id":"brace_%d"%side,"label":label+" foreyard brace","point":mechanics.loaded_yard.position+mechanics.brace.lines[side].belay,"deck":Refit.MAIN_TOP,"kind":"brace","index":side})
func can_reach(index: int) -> bool:
 if index<0 or index>=stations.size() or game.god_mode or game.photo_mode: return false
 if game.coop_panel.visible or (game.vr!=null and game.vr.active): return false
 var p: Vector3 = game.boat.to_local(game.player.global_position)
 var station: Dictionary = stations[index]
 # Require the player to stand on the station's deck, avoiding use through floors.
 if absf(p.y-0.9-float(station.deck))>0.65: return false
 var offset: Vector3 = station.point-p
 return Vector2(offset.x,offset.z).length()<=1.65
func nearest() -> int:
 var result := -1
 var distance := INF
 for i in stations.size():
  if not can_reach(i): continue
  var d: float = game.player.global_position.distance_squared_to(game.boat.to_global(stations[i].point))
  if d<distance: result = i; distance = d
 return result
func take(index: int) -> bool:
 if not can_reach(index) or not game.boat.force_trial: return false
 release()
 current = index
 print("APEX STATION TAKEN ",stations[index].id)
 changed.emit()
 return true
func _dispatch(action: String,value: float = 0.0,index: int = 0) -> void:
 if game.session.active:
  game.session.send_action(action,value,index)
  return
 match action:
  "helm_torque": mechanics.set_helm_torque(value)
  "clew_pull": mechanics.cloth.set_hand(index,value)
  "clew_stop": mechanics.cloth.lines[index].pull = 0.0
  "clew_belay": mechanics.cloth.belay(index)
  "clew_free": mechanics.cloth.release(index)
  "brace_pull": mechanics.brace.set_hand(index,value)
  "brace_stop": mechanics.brace.lines[index].pull = 0.0
  "brace_belay": mechanics.brace.belay(index)
  "brace_free": mechanics.brace.release(index)
func pull(value: float) -> void:
 if current<0 or not can_reach(current): return
 held = clampf(value,-1,1)
 _apply_held()
func _apply_held() -> void:
 if current<0: return
 var station: Dictionary = stations[current]
 if station.kind=="helm": _dispatch("helm_torque",held*120.0)
 elif absf(held)>0.0: _dispatch(station.kind+"_pull",held,station.index)
 else: _dispatch(station.kind+"_stop",0.0,station.index)
func stop_hands() -> void:
 held = 0.0
 _apply_held()
func belay() -> void:
 if current<0 or not can_reach(current): return
 var station: Dictionary = stations[current]
 stop_hands()
 if station.kind!="helm": _dispatch(station.kind+"_belay",0.0,station.index)
func let_run() -> void:
 if current<0 or not can_reach(current): return
 var station: Dictionary = stations[current]
 stop_hands()
 if station.kind!="helm": _dispatch(station.kind+"_free",0.0,station.index)
func release() -> void:
 if current<0: return
 var station: Dictionary = stations[current]
 stop_hands()
 # Leaving a hand-held line frees its tail. A belayed line remains secured.
 if station.kind!="helm":
  var rig: RefCounted = mechanics.cloth if station.kind=="clew" else mechanics.brace
  if rig.lines[station.index].mode==1: _dispatch(station.kind+"_free",0.0,station.index)
 if game.session.active: game.session.send_action("release_station")
 current = -1
 changed.emit()
func _physics_process(delta: float) -> void:
 if game==null or current<0: return
 if not can_reach(current): release(); return
 command_clock += delta
 if command_clock>=0.05:
  command_clock = 0.0
  # Refresh held network commands; the server still owns exclusive stations.
  if absf(held)>0.0: _apply_held()
func _notification(what: int) -> void:
 if what==NOTIFICATION_APPLICATION_FOCUS_OUT and game!=null: stop_hands()
