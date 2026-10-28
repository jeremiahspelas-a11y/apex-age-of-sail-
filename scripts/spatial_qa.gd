extends Node
# Spatial QA: triangle-level picking on demand, with local anchors and portable JSON.
var boat: Node3D
var camera: Camera3D
var canvas: CanvasLayer
var waiting_for_point := false
var notes: Array[Dictionary] = []
var mesh_cache: Array[Dictionary] = []
var editor: TextEdit
var panel: Control
var hint: Label
var marker_root: Node3D
var export_button: Button

func setup(ship: Node3D, view: Camera3D, ui: CanvasLayer) -> void:
 boat = ship
 camera = view
 canvas = ui
 marker_root = Node3D.new()
 boat.add_child(marker_root)
 _collect_meshes(boat)
 export_button = Button.new()
 export_button.text = "EXPORT NOTES"
 export_button.position = Vector2(150, 110)
 export_button.custom_minimum_size = Vector2(140, 46)
 export_button.visible = false
 canvas.add_child(export_button)
 export_button.pressed.connect(_export_notes)
 panel = PanelContainer.new()
 panel.position = Vector2(12, 166)
 panel.custom_minimum_size = Vector2(310, 185)
 panel.visible = false
 canvas.add_child(panel)
 var column := VBoxContainer.new()
 panel.add_child(column)
 hint = Label.new()
 hint.text = "Tap a surface on the ship"
 column.add_child(hint)
 editor = TextEdit.new()
 editor.custom_minimum_size = Vector2(300, 90)
 editor.placeholder_text = "Describe what is wrong here"
 column.add_child(editor)
 var actions := HBoxContainer.new()
 column.add_child(actions)
 for item in [["SAVE", "_save_note"], ["EXPORT", "_export_notes"], ["CANCEL", "_cancel"]]:
  var button := Button.new()
  button.text = item[0]
  actions.add_child(button)
  button.pressed.connect(Callable(self, item[1]))

func _collect_meshes(node: Node) -> void:
 if node is MeshInstance3D:
  var mi := node as MeshInstance3D
  if mi.mesh != null:
   var faces := mi.mesh.get_faces()
   if faces.size() > 0:
    mesh_cache.append({"node": mi, "faces": faces})
 for child in node.get_children():
  _collect_meshes(child)

func begin_pin() -> void:
 waiting_for_point = true
 panel.visible = false
 hint.text = "Tap the ship to place a pin"
 editor.text = ""

var selected: Dictionary = {}

func pick(screen_position: Vector2) -> void:
 waiting_for_point = false
 panel.visible = true
 var origin := camera.project_ray_origin(screen_position)
 var ray := camera.project_ray_normal(screen_position)
 var best := INF
 selected = {}
 for item in mesh_cache:
  var mi: MeshInstance3D = item["node"]
  if not mi.is_visible_in_tree():
   continue
  var inverse := mi.global_transform.affine_inverse()
  var local_origin := inverse * origin
  var local_direction := (inverse.basis * ray).normalized()
  var bounds := mi.mesh.get_aabb()
  if not bounds.intersects_ray(local_origin, local_direction):
   continue
  var faces: PackedVector3Array = item["faces"]
  for i in range(0, faces.size(), 3):
   var hit: Variant = Geometry3D.ray_intersects_triangle(local_origin, local_direction, faces[i], faces[i+1], faces[i+2])
   if hit == null:
    continue
   var world_hit: Vector3 = mi.global_transform * hit
   var distance := origin.distance_to(world_hit)
   if distance < best:
    best = distance
    selected = {"mesh": mi, "local": hit, "world": world_hit, "triangle": i / 3}
 if selected.is_empty():
  hint.text = "No visible ship triangle hit. Try another spot."
  return
 hint.text = "Selected: " + (selected["mesh"] as MeshInstance3D).name
 _show_preview()

var preview: MeshInstance3D
func _show_preview() -> void:
 if is_instance_valid(preview):
  preview.queue_free()
 preview = MeshInstance3D.new()
 var sphere := SphereMesh.new()
 sphere.radius = 0.16
 sphere.height = 0.32
 preview.mesh = sphere
 (selected["mesh"] as MeshInstance3D).add_child(preview)
 preview.position = selected["local"]

func _save_note() -> void:
 if selected.is_empty():
  hint.text = "Select a ship surface first"
  return
 var mi := selected["mesh"] as MeshInstance3D
 var local: Vector3 = selected["local"]
 notes.append({
  "id": notes.size() + 1,
  "mesh_path": str(boat.get_path_to(mi)),
  "mesh_name": mi.name,
  "local_point": [local.x, local.y, local.z],
  "triangle": selected["triangle"],
  "description": editor.text,
  "camera_position": [camera.global_position.x, camera.global_position.y, camera.global_position.z],
  "camera_rotation": [camera.global_rotation.x, camera.global_rotation.y, camera.global_rotation.z]
 })
 if is_instance_valid(preview):
  preview = null
 export_button.visible = true
 panel.visible = false
 selected = {}
 print("APEX SPATIAL QA saved note ", notes.size())

func _export_notes() -> void:
 if notes.is_empty():
  hint.text = "Save a note before exporting"
  return
 var report := {"schema": "apex-spatial-qa-v1", "notes": notes}
 var bytes := JSON.stringify(report, "  ").to_utf8_buffer()
 if OS.has_feature("web"):
  JavaScriptBridge.download_buffer(bytes, "apex-spatial-qa.json", "application/json")
 else:
  var output := FileAccess.open("user://apex-spatial-qa.json", FileAccess.WRITE)
  if output != null:
   output.store_buffer(bytes)
 hint.text = "Exported " + str(notes.size()) + " notes"

func _cancel() -> void:
 waiting_for_point = false
 panel.visible = false
 selected = {}
 if is_instance_valid(preview):
  preview.queue_free()
