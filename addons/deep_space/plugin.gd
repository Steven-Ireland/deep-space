@tool
extends EditorPlugin

var _psx_import := preload("res://addons/deep_space/psx_import.gd").new()


func _enter_tree() -> void:
	add_scene_post_import_plugin(_psx_import)


func _exit_tree() -> void:
	remove_scene_post_import_plugin(_psx_import)
