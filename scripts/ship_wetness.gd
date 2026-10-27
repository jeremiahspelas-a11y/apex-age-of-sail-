extends Node3D
## Runtime overlay wet specular treatment on all imported ship mesh surfaces.
@export var weather_path: NodePath = NodePath("../../Weather")
var overlays: Array[StandardMaterial3D] = []
func _ready() -> void:
 var visual := get_parent().get_node_or_null("HullVisual")
 if visual: _collect(visual)
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
