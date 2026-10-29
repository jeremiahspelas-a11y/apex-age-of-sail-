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
var export_button: Button
var save_button: Button
var _focus_frames := 0

func setup(ship: Node3D, view: Camera3D, ui: CanvasLayer) -> void:
 boat = ship
 camera = view
 canvas = ui
 _collect_meshes(boat)
 export_button = Button.new()
 export_button.text = "EXPORT NOTES"
 export_button.position = Vector2(150, 110)
 export_button.custom_minimum_size = Vector2(140, 46)
 export_button.visible = false
 canvas.add_child(export_button)
 export_button.pressed.connect(_export_notes)
 panel = PanelContainer.new()
 var background := StyleBoxFlat.new()
 background.bg_color = Color(0.06, 0.08, 0.1, 0.96)
 panel.add_theme_stylebox_override("panel", background)
 panel.position = Vector2(12, 166)
 panel.custom_minimum_size = Vector2(310, 185)
 panel.visible = false
 canvas.add_child(panel)
 var column := VBoxContainer.new()
 panel.add_child(column)
 hint = Label.new()
 hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
  button.custom_minimum_size = Vector2(90, 48)
  if item[1] == "_save_note":
   save_button = button
  button.pressed.connect(Callable(self, item[1]))

func _collect_meshes(node: Node) -> void:
 if node is MeshInstance3D:
  var mi := node as MeshInstance3D
  var faces := mi.mesh.get_faces() if mi.mesh!=null else PackedVector3Array()
  mesh_cache.append({"node":mi,"faces":faces,"resource":mi.mesh})
 for child in node.get_children():
  _collect_meshes(child)

func is_active() -> bool:
 return waiting_for_point or panel.visible

func begin_pin() -> void:
 _cancel()
 waiting_for_point = true
 panel.visible = true
 hint.text = "Tap the ship to place a pin"
 editor.text = ""
 editor.visible = false
 save_button.disabled = true
 print("APEX SPATIAL QA WAITING")

var selected: Dictionary = {}

func pick(screen_position: Vector2) -> void:
 if not waiting_for_point:
  return
 panel.visible = true
 var origin := camera.project_ray_origin(screen_position)
 var ray := camera.project_ray_normal(screen_position)
 var best := INF
 selected = {}
 for item in mesh_cache:
  var mi: MeshInstance3D = item["node"]
  if not is_instance_valid(mi) or mi.mesh==null or not mi.is_visible_in_tree():
   continue
  var inverse := mi.global_transform.affine_inverse()
  var local_origin := inverse * origin
  var local_direction := (inverse.basis * ray).normalized()
  var bounds := mi.mesh.get_aabb()
  if bounds.intersects_ray(local_origin, local_direction) == null:
   continue
  if mi.mesh!=item.resource:
   item.resource = mi.mesh
   item.faces = mi.mesh.get_faces()
  var faces: PackedVector3Array = item["faces"]
  for i in range(0, faces.size(), 3):
   var hit: Variant = Geometry3D.ray_intersects_triangle(local_origin, local_direction, faces[i], faces[i+1], faces[i+2])
   if hit == null:
    continue
   var world_hit: Vector3 = mi.global_transform * hit
   var distance := origin.distance_to(world_hit)
   if distance < best:
    best = distance
    selected = {"mesh": mi, "local": hit, "world": world_hit, "triangle": int(i / 3)}
 if selected.is_empty():
  hint.text = "Missed the ship. Tap another spot."
  return
 waiting_for_point = false
 editor.visible = true
 save_button.disabled = false
 hint.text = "Selected: " + (selected["mesh"] as MeshInstance3D).name
 _show_preview()
 _focus_frames = 2
 set_process(true)

func _process(_delta: float) -> void:
 if _focus_frames<=0:
  set_process(false)
  return
 _focus_frames -= 1
 if _focus_frames>0: return
 set_process(false)
 if not panel.is_visible_in_tree() or waiting_for_point or selected.is_empty(): return
 editor.grab_focus()
 var save_center := save_button.get_global_rect().get_center()
 var export_center := export_button.get_global_rect().get_center()
 print("APEX SPATIAL QA EDITOR READY ",JSON.stringify({"save_center":[save_center.x,save_center.y],"export_center":[export_center.x,export_center.y]}))

var preview: MeshInstance3D
func _show_preview() -> void:
 _clear_preview()
 preview = MeshInstance3D.new()
 var sphere := SphereMesh.new()
 sphere.radius = 0.16
 sphere.height = 0.32
 preview.mesh = sphere
 var material := StandardMaterial3D.new()
 material.albedo_color = Color(1.0, 0.35, 0.06)
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 preview.material_override = material
 (selected["mesh"] as MeshInstance3D).add_child(preview)
 preview.position = selected["local"]

func _save_note() -> void:
 if waiting_for_point or selected.is_empty():
  hint.text = "Select a ship surface first"
  return
 if editor.text.strip_edges().is_empty():
  hint.text = "Describe the issue before saving"
  return
 var mi := selected["mesh"] as MeshInstance3D
 var local: Vector3 = selected["local"]
 notes.append({
  "id": notes.size() + 1,
  "mesh_path": str(boat.get_path_to(mi)),
  "mesh_name": mi.name,
  "local_point": [local.x, local.y, local.z],
  "triangle": selected["triangle"],
  "description": editor.text.strip_edges(),
  "camera_position": [camera.global_position.x, camera.global_position.y, camera.global_position.z],
  "camera_rotation": [camera.global_rotation.x, camera.global_rotation.y, camera.global_rotation.z]
 })
 if is_instance_valid(preview):
  var label := Label3D.new()
  label.text = str(notes.size())
  label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
  label.position.y = 0.4
  label.font_size = 64
  preview.add_child(label)
  preview = null
 export_button.visible = true
 panel.visible = false
 editor.release_focus()
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
 _focus_frames = 0
 set_process(false)
 waiting_for_point = false
 panel.visible = false
 selected = {}
 editor.release_focus()
 _clear_preview()

func _clear_preview() -> void:
 if is_instance_valid(preview):
  preview.visible = false
  preview.queue_free()
 preview = null
