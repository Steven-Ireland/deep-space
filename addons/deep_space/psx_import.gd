@tool
extends EditorScenePostImportPlugin
## Gives models built in art/blender their PSX materials (TECH §5): each glTF material named
## <name> is swapped for res://assets/materials/<name>.tres, which the Blender pipeline writes
## beside the model with its baked textures.

const MATERIALS := "res://assets/materials/%s.tres"


func _post_process(scene: Node) -> void:
	_swap_materials(scene)


func _swap_materials(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for i in node.mesh.get_surface_count():
			var material: Material = node.mesh.surface_get_material(i)
			if material == null:
				continue
			var path := MATERIALS % material.resource_name
			if ResourceLoader.exists(path):
				node.mesh.surface_set_material(i, load(path))
			else:
				push_warning("No PSX material at %s for %s." % [path, node.name])
	for child in node.get_children():
		_swap_materials(child)
