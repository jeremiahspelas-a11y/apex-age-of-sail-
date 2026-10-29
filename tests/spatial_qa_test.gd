extends SceneTree
## Interaction regressions: real triangle picking plus the game's input/mode state.
var failures: Array[String] = []
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:
  failures.append(message)
  push_error(message)
func run() -> void:
 root.size = Vector2i(960, 540)
 var ship := Node3D.new()
 root.add_child(ship)
 var mesh := MeshInstance3D.new()
 mesh.name = "TestHull"
 mesh.mesh = BoxMesh.new()
 ship.add_child(mesh)
 var view := Camera3D.new()
 root.add_child(view)
 view.position.z = 5.0
 view.current = true
 var layer := CanvasLayer.new()
 root.add_child(layer)
 var qa: Node = load("res://scripts/spatial_qa.gd").new()
 root.add_child(qa)
 qa.setup(ship, view, layer)
 await process_frame
 var center := root.get_visible_rect().size * 0.5
 # Runtime mesh replacement must refresh triangle geometry (cloth/rope adapters do this).
 var replacement := BoxMesh.new()
 replacement.size = Vector3(1,1,3)
 mesh.mesh = replacement
 qa.begin_pin()
 qa.pick(Vector2.ZERO)
 check(qa.waiting_for_point and qa.selected.is_empty(), "A miss must allow another tap")
 qa.pick(center)
 check(not qa.waiting_for_point and not qa.selected.is_empty(), "Center ray must hit the box triangle")
 check(qa.selected.local.z>1.4,"Picking must use replaced mesh faces, not stale original triangles")
 for frame in 4: await process_frame
 check(root.gui_get_focus_owner()==qa.editor,"Picking a surface must focus the description after layout")
 qa.editor.text = "   "
 qa._save_note()
 check(qa.notes.is_empty() and qa.is_active(), "Blank notes must not save")
 qa.editor.text = "  Hull seam gap  "
 var marker: MeshInstance3D = qa.preview
 qa._save_note()
 check(qa.notes.size() == 1 and not qa.is_active(), "Save must return to flying")
 check(qa.notes[0].description == "Hull seam gap", "Export must preserve the note text")
 check(marker.get_child(0) is Label3D and marker.get_child(0).text == "1", "Saved markers must be numbered")
 var anchor := marker.global_position
 ship.position = Vector3(2, 3, 4)
 check(marker.global_position.is_equal_approx(anchor + ship.position), "Pin must move with its ship mesh")
 ship.position = Vector3.ZERO
 qa.begin_pin()
 qa._save_note()
 check(qa.selected.is_empty() and qa.notes.size() == 1, "Starting a pin must not reuse an earlier selection")
 qa.pick(center)
 var cancelled: MeshInstance3D = qa.preview
 qa._cancel()
 check(not qa.is_active() and not cancelled.visible and qa.notes.size() == 1, "Cancel must remove only the unsaved preview")
 for frame in 4: await process_frame
 check(root.gui_get_focus_owner()!=qa.editor,"Cancel must not allow pending layout focus to reopen the editor")
 qa._export_notes()
 var report: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://apex-spatial-qa.json"))
 check(report != null and report.schema == "apex-spatial-qa-v1" and report.notes.size() == 1, "JSON export must contain saved notes only")
 var note: Dictionary = report.notes[0]
 check(note.mesh_name == "TestHull" and note.local_point.size() == 3 and note.triangle >= 0, "Export must identify the actual mesh and triangle anchor")
 qa.free()
 layer.free()
 ship.free()
 view.free()
 var game: Node3D = load("res://physics_trial.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.set_process(false)
 game._toggle_fly()
 var left := InputEventScreenTouch.new()
 left.index = 3
 left.position = Vector2(92, root.size.y - 100)
 left.pressed = true
 game._unhandled_input(left)
 var right := InputEventScreenTouch.new()
 right.index = 7
 right.position = Vector2(root.size.x - 92, root.size.y - 100)
 right.pressed = true
 game._unhandled_input(right)
 var drag := InputEventScreenDrag.new()
 drag.index = 3
 drag.position = left.position + Vector2(0, -40)
 game._unhandled_input(drag)
 drag.index = 7
 drag.position = right.position + Vector2(30, -20)
 game._unhandled_input(drag)
 check(game.stick_move.length() > 0.1 and game.stick_look.length() > 0.1, "Independent fingers must drive both sticks")
 # _input sees a release even if a GUI control consumes the event later.
 right.pressed = false
 game._input(right)
 check(game.right_touch == -1 and game.stick_look == Vector2.ZERO and game.left_touch == 3, "Release over UI must clear only its owning stick")
 game._pin_issue()
 check(game.left_touch == -1 and game.stick_move == Vector2.ZERO, "Pinning must clear held flight input")
 game.spatial_qa.waiting_for_point = false
 game.spatial_qa.panel.visible = true
 game.stick_move = Vector2(0, -1)
 var before: Vector3 = game.camera.global_position
 game._process(1.0)
 check(game.camera.global_position == before, "Camera must remain fixed while editing a note")
 game._toggle_photo()
 check(not game.spatial_qa.is_active() and not game.pin_button.visible and game.restore_hud_button.visible, "Photo mode must cancel pinning and retain SHOW HUD")
 game._toggle_photo()
 check(game.pin_button.visible and not game.restore_hud_button.visible, "SHOW HUD must restore the controls")
 game._pin_issue()
 game._toggle_fly()
 check(not game.god_mode and not game.spatial_qa.is_active(), "Returning to walk must cancel annotation")
 game.free()
 if failures.is_empty():
  print("APEX SPATIAL QA TEST PASS: triangle picking, save/cancel/export, markers, dual sticks, editing freeze, mode cleanup")
 quit(0 if failures.is_empty() else 1)
