extends SceneTree
const Refit = preload("res://scripts/ship_refit.gd")
var failures: Array[String] = []
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:
  failures.append(message)
  push_error(message)
func key(p: Vector3) -> String:
 return "%.5f,%.5f,%.5f"%[p.x,p.y,p.z]
func check_envelope() -> void:
 var mesh := Refit.hull_mesh(true)
 var faces := mesh.get_faces()
 var edges: Dictionary = {}
 var signed_volume := 0.0
 for i in range(0,faces.size(),3):
  var a := faces[i]
  var b := faces[i+1]
  var c := faces[i+2]
  check((b-a).cross(c-a).length() > 0.000001,"Hull must not contain degenerate triangles")
  signed_volume += a.dot(b.cross(c))/6.0
  for pair in [[a,b],[b,c],[c,a]]:
   var ka := key(pair[0])
   var kb := key(pair[1])
   var edge := ka+"/"+kb if ka < kb else kb+"/"+ka
   edges[edge] = int(edges.get(edge,0))+1
 for count: int in edges.values():
  check(count == 2,"Closed reference envelope must have exactly two triangles per welded edge")
 check(absf(signed_volume) > 200.0,"Closed reference envelope must enclose positive displacement volume")
 var bounds := mesh.get_aabb()
 check(is_equal_approx(bounds.size.x,6.9) and is_equal_approx(bounds.size.z,26.2),"Refit must retain the measured V6 beam and length")
 check(is_equal_approx(bounds.position.y,-2.2),"Refit must retain the measured V6 draft bounds")
 print("SHIP ENVELOPE: volume=",absf(signed_volume)," m3; welded edges=",edges.size(),"; reference envelope only, not a buoyancy solver")
func ray(game: Node3D,x: float,z: float) -> Dictionary:
 var query := PhysicsRayQueryParameters3D.create(Vector3(x,6,z),Vector3(x,-3,z),1)
 return game.get_world_3d().direct_space_state.intersect_ray(query)
func run() -> void:
 check_envelope()
 var game: Node3D = load("res://physics_trial.tscn").instantiate()
 root.add_child(game)
 game.set_process(false)
 game.boat.set_physics_process(false)
 game.boat.transform = Transform3D.IDENTITY
 game.get_node("Weather").set_process(false)
 var mechanism: Node3D = game.get_node("Boat/Mechanisms")
 mechanism.set_process(false)
 var visual: Node = game.get_node("Boat/HullVisual")
 var materials: Node = game.get_node("Boat/Wetness")
 check(mechanism.rig_sails.size() == 8 and mechanism.rig_yards.size() == 8,"Exactly eight original sail/yard pairs must remain")
 check(materials.classifications.get("canvas",0) == 8,"Only the eight sails should be canvas")
 var structure := game.get_node("Boat/ShipStructure")
 for part in structure.find_children("*","MeshInstance3D",true,false):
  check(not str(part.get_parent().name).begins_with("Rib_"),"Original frames must not receive duplicate procedural rib meshes")
  if "DeckBeam_" in str(part.name):
   var box: AABB = part.mesh.get_aabb()
   box.position += part.position
   for opening: Rect2 in Refit.HATCHES:
    var footprint := Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z))
    check(not footprint.intersects(opening),"Deck beams must frame around rather than obstruct hatch openings")
 for name in ["legacy_000_Fairing-study wooden hull","legacy_001_Main deck","legacy_002_Raised quarterdeck","legacy_003_Forecastle"]:
  check(not Refit.find_mesh(visual,name).visible,"Superseded hull/deck must not overlap: "+name)
 var bowsprit := Refit.find_mesh(visual,"legacy_053_Bowsprit")
 check(bowsprit.visible and bowsprit.get_meta("ship_material_category") == "wood","Historical bowsprit must remain wooden and visible")
 for i in mechanism.rig_sails.size():
  var sail: MeshInstance3D = mechanism.rig_sails[i]
  var original: AABB = sail.get_meta("original_sail_bounds")
  var bounds := sail.mesh.get_aabb()
  check(sail.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() >= 200,"Sails must use subdivided cloth rather than solid wedges")
  check(is_equal_approx(bounds.size.x,original.size.x),"Sail span must be preserved")
  check(absf(bounds.end.y-original.end.y) < 0.001,"Sail head height must be preserved")
 for part in visual.find_children("*","MeshInstance3D",true,false):
  var n := str(part.name)
  if n.begins_with("shroud_tube"):
   check(part.has_meta("rig_collar"),"Standing shrouds must bind to measured mast collars")
  if n.begins_with("legacy_") and "Shroud" in n:
   check(not part.visible,"Displaced duplicate shrouds must be hidden")
  for mast in range(1,4):
   if n.ends_with("Mast "+str(mast)):
    check(is_equal_approx(part.mesh.get_aabb().position.y,Refit.MAST_STEP_Y),"Original mast must extend to its keelson step")
 for trim in [-1.5,0.0,1.5]:
  game.boat.sheet_angle = trim
  mechanism._process(2.0)
  for i in mechanism.yards.size():
   var pivot: Node3D = mechanism.yards[i]
   var socket: Vector3 = pivot.get_meta("rest_socket")
   var sail: MeshInstance3D = mechanism.rig_sails[i]
   var yard: MeshInstance3D = mechanism.rig_yards[i]
   check(pivot.position.is_equal_approx(socket),"Yard socket must remain on its mast during trim")
   var original: AABB = sail.get_meta("original_sail_bounds")
   if pivot==mechanism.loaded_yard:
    var head := Vector3(0,original.end.y,socket.z-mechanism.cloth.head_standoff)
    var axis := yard.to_global(yard.mesh.get_aabb().get_center())
    var radius := maxf(yard.mesh.get_aabb().size.y,yard.mesh.get_aabb().size.z)*0.5
    check(absf(sail.to_global(head).distance_to(axis)-radius-mechanism.cloth.contact_thickness-0.002)<0.001,"Fore head must stay at its forward-face lashing clearance while bracing")
    for side in 2:
     var end: Vector3 = pivot.to_global(mechanism.brace.rest_end(side))
     var actual_end := yard.mesh.get_aabb().get_center()
     actual_end.x = yard.mesh.get_aabb().position.x if side==0 else yard.mesh.get_aabb().end.x
     check(end.distance_to(yard.to_global(actual_end))<0.001,"Solved brace endpoint must stay on the relocated spar tip")
    continue
   var center := Vector3(0,original.end.y,socket.z)
   check(sail.to_global(center).distance_to(pivot.global_position) < 0.001,"Sail head must stay pinned to its yard pivot")
   var tip := Vector3(original.size.x*0.5,original.end.y,socket.z)
   check(sail.to_global(tip).distance_to(yard.to_global(tip)) < 0.001,"Sail and yard endpoints must remain attached while bracing")
 game.boat.rudder_input = 1.0
 mechanism._process(3.0)
 var wheel_ring: MeshInstance3D = null
 for part in mechanism.wheel.get_children():
  if part.name in ["v7_helm_wheel","v7_helm"]: wheel_ring = part
 check(wheel_ring != null,"Original helm ring must be articulated with its spokes and hub")
 if wheel_ring != null:
  check(wheel_ring.to_global(Vector3(0,2.95,10.8)).distance_to(mechanism.wheel.global_position) < 0.001,"Helm must rotate around its axle rather than the ship origin")
 check(mechanism.wheel.get_child_count() == 11,"Helm ring, eight spokes, hub and drum must rotate together")
 check(mechanism.rudder.position.is_equal_approx(Vector3(0,0.15,13.15)),"Rudder must remain on its stern hinge")
 check(not Refit.find_mesh(visual,"V9_rudder_blade").visible and not Refit.find_mesh(visual,"legacy_054_Rudder blade").visible,"Duplicate fixed rudder blades must be hidden")
 mechanism.toggle_doors()
 mechanism.toggle_hatches()
 mechanism._process(2.0)
 check(mechanism.doors.size() == 2 and mechanism.hatches.size() == 2,"Original doors and hatches must be bound without proxy duplicates")
 for door: Node3D in mechanism.doors:
  check(door.position.is_equal_approx(door.get_meta("rest_socket")),"Open door hinge must stay fixed")
 for hatch: Node3D in mechanism.hatches:
  check(hatch.position.is_equal_approx(hatch.get_meta("rest_socket")),"Open hatch hinge must stay fixed")
 await physics_frame
 await physics_frame
 for entry in [[1.2,0.0,Refit.MAIN_TOP],[0.0,-10.5,Refit.FORE_TOP],[1.2,10.0,Refit.QUARTER_TOP]]:
  var hit := ray(game,entry[0],entry[1])
  check(not hit.is_empty() and absf(hit.position.y-entry[2]) < 0.02,"Walk collision must meet the visible deck at "+str(entry))
 for z in [-4.0,2.0]:
  var hit := ray(game,0,z)
  check(not hit.is_empty() and absf(hit.position.y+1.07) < 0.02,"Open hatch must reveal the lower deck without a phantom floor")
 # Move the real player up both companion stair ramps.
 var player: CharacterBody3D = game.get_node("Player")
 player.movement_follows_view = false # construction routes are specified in ship axes
 player.position = Vector3(0,2.05,5.9)
 player.velocity = Vector3.ZERO
 player.motion_input = Vector2(0,1)
 for frame in range(110): await physics_frame
 player.motion_input = Vector2.ZERO
 check(player.position.z > 9.8 and player.is_on_floor(),"Player must be able to climb to the quarterdeck")
 check(absf(player.position.y-0.9-Refit.QUARTER_TOP) < 0.08,"Player feet must rest on the visible quarterdeck")
 player.position = Vector3(0,2.05,-7.0)
 player.velocity = Vector3.ZERO
 player.motion_input = Vector2(0,-1)
 for frame in range(110): await physics_frame
 player.motion_input = Vector2.ZERO
 check(player.position.z < -9.8 and player.is_on_floor(),"Player must be able to climb to the forecastle")
 check(absf(player.position.y-0.9-Refit.FORE_TOP) < 0.08,"Player feet must rest on the visible forecastle")
 game.free()
 if failures.is_empty():
  print("APEX SHIP CONSTRUCTION TEST PASS: hull envelope, fitted decks, material identity, eight cloth rigs, real hinges, hatch openings and stair traversal")
 quit(0 if failures.is_empty() else 1)
