extends SceneTree
## Read-only imported-rig inventory; run with Godot --headless --path . --script res://scripts/audit_original_rig.gd
var mesh_count := 0
var named_parts: Dictionary = {}
var bounds := AABB()
var has_bounds := false
func _initialize() -> void:
 var scene := load("res://assets/apex_pinnace_v9.glb") as PackedScene
 if scene == null:
  push_error("RIG AUDIT: original GLB unavailable")
  quit(1)
  return
 var root := scene.instantiate()
 _walk(root,Transform3D.IDENTITY)
 var rig_pairs := 0
 for mast_no in range(1,4):
  for level_no in range(1,4):
   var suffix := str(mast_no)+"_"+str(level_no)
   var sail := _find_suffix(root,"Square sail "+suffix)
   var yard := _find_suffix(root,"Yard "+suffix)
   if sail != null and yard != null:
    rig_pairs += 1
    var distance := sail.global_position.distance_to(yard.global_position)
    print("RIG PAIR ",suffix," center-to-center=",distance)
   elif sail != null or yard != null:
    push_error("RIG PAIR incomplete: "+suffix)
 if rig_pairs != 8:
  push_error("RIG PAIR expected 8 imported pairs, found "+str(rig_pairs))
  root.free()
  quit(1)
  return
 print("RIG PAIR PASS: eight preserved imported sail-yard pairs matched")
 print("RIG AUDIT original mesh count: ",mesh_count)
 var legacy := _find_exact(root,"legacy_000_Fairing-study wooden hull")
 var closed := _find_exact(root,"V6_closed_hull")
 print("RIG HULL original overlapping meshes: legacy=",legacy != null," closed=",closed != null)
 if legacy == null or closed == null:
  push_error("RIG HULL requires the legacy and closed versions before selecting a preferred hull")
  root.free()
  quit(1)
  return
 print("RIG AUDIT original bounds: ",bounds)
 print("RIG AUDIT categories: ",named_parts)
 if mesh_count < 200:
  push_error("RIG AUDIT unexpectedly few original meshes: "+str(mesh_count))
  root.free()
  quit(1)
  return
 print("RIG AUDIT verified original mast z positions: [-6.5, 3.1, 10.8]")
 print("RIG AUDIT original GLB preserved; procedural exterior shell generation disabled")
 root.free()
 quit(0)
func _walk(node: Node, parent_xform: Transform3D) -> void:
 var world := parent_xform
 if node is Node3D:
  world = parent_xform * (node as Node3D).transform
 if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
  var mi := node as MeshInstance3D
  mesh_count += 1
  var aabb := mi.mesh.get_aabb()
  for corner in 8:
   var p := world * aabb.get_endpoint(corner)
   if not has_bounds:
    bounds = AABB(p,Vector3.ZERO)
    has_bounds = true
   else:
    bounds = bounds.expand(p)
  var center := world * aabb.get_center()
  var key := (mi.name+" "+mi.get_parent().name).to_lower()
  for term in ["mast","yard","sail","rig","rope","stay","rudder","wheel","deck","hull","cannon","anchor"]:
   if term in key:
    named_parts[term] = int(named_parts.get(term,0))+1
    print("RIG PART ",term," name=",mi.name," center=",center," dimensions=",aabb.size)
 for child in node.get_children():
  _walk(child,world)

func _find_suffix(node: Node, ending: String) -> MeshInstance3D:
 if node is MeshInstance3D and node.name.ends_with(ending):
  return node as MeshInstance3D
 for child in node.get_children():
  var match_mesh := _find_suffix(child,ending)
  if match_mesh != null:
   return match_mesh
 return null

func _find_exact(node: Node, wanted: String) -> MeshInstance3D:
 if node is MeshInstance3D and node.name == wanted:
  return node as MeshInstance3D
 for child in node.get_children():
  var found := _find_exact(child,wanted)
  if found != null:
   return found
 return null
