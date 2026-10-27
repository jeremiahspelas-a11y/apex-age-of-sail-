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
 print("RIG AUDIT original mesh count: ",mesh_count)
 print("RIG AUDIT original bounds: ",bounds)
 print("RIG AUDIT categories: ",named_parts)
 if mesh_count < 200:
  push_error("RIG AUDIT unexpectedly few original meshes: "+str(mesh_count))
  root.free()
  quit(1)
  return
 print("RIG AUDIT procedural mast collider z: [-5.5, 1.2, 8.0]")
 print("RIG AUDIT animated yard z: [-6.5, 0.0, 6.0]")
 print("RIG AUDIT working rudder z: 13.6; shell stern z: 10.9")
 print("RIG AUDIT WARNING: procedural hull overlays original imported geometry; visual and collision overlap unverified")
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
