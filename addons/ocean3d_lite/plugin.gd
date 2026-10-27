@tool
extends EditorPlugin
func _enable_plugin() -> void:
 add_autoload_singleton("Ocean", "res://addons/ocean3d_lite/ocean.gd")
func _disable_plugin() -> void:
 remove_autoload_singleton("Ocean")
