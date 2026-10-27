extends Node3D
## Material recovery for imported ship meshes without embedded texture assets.
## Geometry-based classification works even when Blender mesh names are generic.
@export var weather_path: NodePath = NodePath("../../Weather")
var surfaces: Array[StandardMaterial3D] = []
var baseline_roughness: Array[float] = []
var classifications: Dictionary = {}

func _ready() -> void:
 var visual := get_parent().get_node_or_null("HullVisual")
 if visual != null:
  _classify_tree(visual)
 print("APEX ship material classification: ", classifications)

func _classify_tree(node: Node) -> void:
 if node is MeshInstance3D:
  _assign_material(node as MeshInstance3D)
 for child in node.get_children():
  _classify_tree(child)

func _assign_material(mi: MeshInstance3D) -> void:
 if mi.mesh == null:
  return
 var key := (mi.name + " " + mi.get_parent().name).to_lower()
 var aabb := mi.mesh.get_aabb()
 var dimensions := aabb.size.abs() * mi.scale.abs()
 var dims := [dimensions.x, dimensions.y, dimensions.z]
 dims.sort()
 var smallest: float = max(dims[0], 0.0001)
 var middle: float = max(dims[1], 0.0001)
 var largest: float = dims[2]
 var thin_sheet := smallest < middle * 0.13 and middle > 0.6 and largest > 1.4
 var cord := middle < largest * 0.065 and largest > 1.2
 var category := "wood"
 if "sail" in key or "canvas" in key or "cloth" in key or (thin_sheet and dimensions.y > 1.0):
  category = "canvas"
 elif "rope" in key or "rig" in key or "line" in key or "stay" in key or cord:
  category = "rigging"
 elif "metal" in key or "cannon" in key or "iron" in key or "anchor" in key:
  category = "iron"
 elif "deck" in key or "plank" in key:
  category = "deck"
 elif "hull" in key or "keel" in key:
  category = "hull"
 classifications[category] = int(classifications.get(category, 0)) + 1
 var mat := StandardMaterial3D.new()
 mat.metallic = 0.0
 mat.roughness = 0.76
 match category:
  "canvas":
   mat.albedo_color = Color(0.76,0.69,0.53)
   mat.roughness = 0.96
   mat.cull_mode = BaseMaterial3D.CULL_DISABLED
  "rigging":
   mat.albedo_color = Color(0.28,0.20,0.12)
   mat.roughness = 0.92
  "iron":
   mat.albedo_color = Color(0.16,0.18,0.19)
   mat.metallic = 0.65
   mat.roughness = 0.43
  "deck":
   mat.albedo_color = Color(0.45,0.28,0.15)
  "hull":
   mat.albedo_color = Color(0.23,0.12,0.07)
  _:
   mat.albedo_color = Color(0.36,0.20,0.105)
 # Per-surface override is more reliable than a translucent white overlay.
 for surface in mi.mesh.get_surface_count():
  mi.set_surface_override_material(surface, mat)
 mi.material_override = mat
 mi.material_overlay = null
 surfaces.append(mat)
 baseline_roughness.append(mat.roughness)

func _process(_delta: float) -> void:
 var weather := get_node_or_null(weather_path)
 var wetness := 0.0
 if weather != null and weather.has_method("get_wetness"):
  wetness = clampf(weather.get_wetness(), 0.0, 1.0)
 for i in surfaces.size():
  surfaces[i].roughness = lerpf(baseline_roughness[i], maxf(0.18, baseline_roughness[i] * 0.55), wetness)
