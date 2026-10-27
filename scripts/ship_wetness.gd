extends Node3D
## Runtime overlay wet specular treatment on all imported ship mesh surfaces.
@export var weather_path: NodePath = NodePath("../../Weather")
var overlays: Array[StandardMaterial3D] = []
func _ready() -> void:
 var visual := get_parent().get_node_or_null("HullVisual")
 if visual:
  _apply_ship_materials(visual)
  _collect(visual)
func _collect(node: Node) -> void:
 if node is MeshInstance3D:
  var mat := StandardMaterial3D.new()
  mat.albedo_color = Color(0.20,0.16,0.12,0.0)
  mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
  mat.roughness = 0.16
  mat.metallic = 0.0
  mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
  mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
  node.material_overlay = mat
  overlays.append(mat)
 for child in node.get_children(): _collect(child)
func _process(_delta: float) -> void:
 var weather := get_node_or_null(weather_path)
 var amount := 0.0
 if weather and weather.has_method("get_wetness"): amount = weather.get_wetness()
 for mat in overlays:
  mat.albedo_color.a = amount * 0.12

## The imported GLB has geometry but no usable skin textures. Give each mesh
## a deterministic physically based material instead of unlit white defaults.
func _apply_ship_materials(node: Node) -> void:
 if node is MeshInstance3D:
  var mi := node as MeshInstance3D
  var key := (mi.name + " " + str(mi.get_parent().name)).to_lower()
  var mat := StandardMaterial3D.new()
  mat.roughness = 0.79
  var wood := Color(0.30,0.16,0.085)
  if "sail" in key or "canvas" in key or "cloth" in key:
   mat.albedo_color = Color(0.79,0.73,0.58)
   mat.roughness = 0.93
   mat.cull_mode = BaseMaterial3D.CULL_DISABLED
  elif "rope" in key or "rig" in key or "line" in key:
   mat.albedo_color = Color(0.40,0.30,0.18)
  elif "metal" in key or "cannon" in key or "iron" in key:
   mat.albedo_color = Color(0.14,0.16,0.17)
   mat.metallic = 0.72
   mat.roughness = 0.41
  elif "deck" in key or "plank" in key:
   mat.albedo_color = Color(0.46,0.29,0.15)
  elif "hull" in key or "boat" in key or "ship" in key:
   mat.albedo_color = Color(0.21,0.11,0.065)
  else:
   mat.albedo_color = wood
  mi.material_override = mat
 for child in node.get_children():
  _apply_ship_materials(child)
