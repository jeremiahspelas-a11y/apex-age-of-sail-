extends Node3D
const CHARACTER_PATH := "res://assets/crew/character.glb"
func _ready() -> void:
 if not ResourceLoader.exists(CHARACTER_PATH):
  return
 var packed := load(CHARACTER_PATH) as PackedScene
 if packed == null:
  push_warning("Crew GLB is not a PackedScene")
  return
 var character := packed.instantiate()
 add_child(character)
 var placeholder := get_parent().get_node_or_null("CrewSkeleton")
 if placeholder != null:
  placeholder.visible = false
