extends Node3D
## Named fitting materials take precedence over shape guesses: spars are wood, not canvas.
@export var weather_path: NodePath = NodePath("../../Weather")
const SURFACE_SHADER = preload("res://shaders/ship_surface.gdshader")
const CANVAS_SHADER = preload("res://shaders/ship_canvas.gdshader")
var surfaces: Array[ShaderMaterial] = []
var classifications: Dictionary = {}
var material_cache: Dictionary = {}

func _ready() -> void:
 var visual := get_parent()
 if visual != null:
  _classify_tree(visual)
 print("APEX ship material classification: ",classifications)

func _classify_tree(node: Node) -> void:
 if node is MeshInstance3D:
  _assign_material(node as MeshInstance3D)
 for child in node.get_children():
  _classify_tree(child)

func category_for(mi: MeshInstance3D) -> String:
 var key := str(mi.name).to_lower()
 if "square sail" in key or "canvas" in key or "cloth" in key:
  return "canvas"
 if "cannon" in key or "iron" in key or "anchor" in key or "metal" in key:
  return "iron"
 # Explicit structural names prevent the old thin-sheet/cord heuristics painting
 # the bowsprit and helm white or treating masts and yards as rope.
 for term in ["mast","yard","bowsprit","wheel","spoke","hub","rudder","stair","rail","bulwark","frame","coaming","beam","door","hatch"]:
  if term in key: return "wood"
 for term in ["rope","shroud","stay","rigging","line"]:
  if term in key: return "rigging"
 if "woodensides" in key: return "hull"
 if "deck" in key or "plank" in key:
  return "deck"
 if "hull" in key or "keel" in key:
  return "hull"
 return "wood"

func _assign_material(mi: MeshInstance3D) -> void:
 if mi.mesh == null: return
 var category := category_for(mi)
 classifications[category] = int(classifications.get(category,0))+1
 var dimensions := mi.mesh.get_aabb().size.abs()
 var axis := 2
 if dimensions.y > dimensions.x and dimensions.y > dimensions.z: axis = 1
 elif dimensions.x > dimensions.z: axis = 0
 if category in ["deck","hull"]: axis = 2
 var cache_key := category+str(axis)
 var material: ShaderMaterial = material_cache.get(cache_key)
 if material == null:
  material = ShaderMaterial.new()
  material.shader = CANVAS_SHADER if category == "canvas" else SURFACE_SHADER
  material.set_shader_parameter("grain_axis",axis)
  material.set_shader_parameter("timber_map",preload("res://assets/materials/timber_detail.png"))
  material.set_shader_parameter("canvas_map",preload("res://assets/materials/canvas_detail.png"))
  material.set_shader_parameter("hemp_map",preload("res://assets/materials/hemp_detail.png"))
  var kind := 0
  var color := Color(0.40,0.27,0.15)
  match category:
   "deck":
    kind = 1
    color = Color(0.49,0.36,0.23)
   "hull":
    kind = 2
    color = Color(0.32,0.20,0.115)
   "rigging":
    kind = 3
    color = Color(0.30,0.24,0.16)
   "iron":
    kind = 4
    color = Color(0.11,0.13,0.14)
   "canvas":
    kind = 5
    color = Color(0.76,0.71,0.59)
  material.set_shader_parameter("surface_kind",kind)
  material.set_shader_parameter("base_color",color)
  material_cache[cache_key] = material
  surfaces.append(material)
 mi.material_override = material
 mi.material_overlay = null
 mi.set_meta("ship_material_category",category)

func _process(_delta: float) -> void:
 var weather := get_node_or_null(weather_path)
 var wetness := 0.0
 if weather != null and weather.has_method("get_wetness"):
  wetness = clampf(weather.get_wetness(),0.0,1.0)
 var boat := get_parent()
 var wind: Vector3 = boat.get("wind_world")
 for material in surfaces:
  material.set_shader_parameter("wetness",wetness)
  material.set_shader_parameter("wind_strength",clampf(wind.length()/14.0,0.0,1.0))
