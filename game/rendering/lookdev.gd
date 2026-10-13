extends Node3D
## A throwaway look-development room for checking the PSX pipeline (M0): a dark box of a room,
## textured crates, a flashlight cone and a flickering practical, under early fog.

const LIT := preload("res://game/rendering/psx_lit.gdshader")

## Off when the room is a backdrop for players, who bring their own cameras and lights.
@export var with_camera := true


func _ready() -> void:
	var model_path := Args.value("--model", "")
	if model_path != "":
		_inspect(model_path)
		return
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	var texture := NoiseTexture2D.new()
	texture.width = 64
	texture.height = 64
	texture.seamless = true
	texture.noise = noise

	var wall := _material(Color(0.55, 0.6, 0.62), texture)
	var crate := _material(Color(0.75, 0.55, 0.3), texture)
	_box(Vector3(12, 0.2, 16), Vector3(0, -0.1, 0), wall)
	_box(Vector3(12, 0.2, 16), Vector3(0, 3.1, 0), wall)
	_box(Vector3(0.2, 3, 16), Vector3(-6, 1.5, 0), wall)
	_box(Vector3(0.2, 3, 16), Vector3(6, 1.5, 0), wall)
	_box(Vector3(12, 3, 0.2), Vector3(0, 1.5, -8), wall)
	for i in 3:
		var crate_box := _box(Vector3.ONE, Vector3(-3 + i * 1.3, 0.5, -5 - (i % 3) * 1.5), crate)
		crate_box.rotation.y = i * 0.4
	var fuel_cell: PackedScene = load("res://assets/models/items/fuel_cell.glb")
	for i in 3:
		var cell := fuel_cell.instantiate()
		cell.position = Vector3(-0.7 + i * 0.75, 0, 2.2 - i * 0.35)
		cell.rotation.y = -0.5 + i * 0.6
		add_child(cell)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.05, 0.07, 0.1)
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color(0.0, 0.0, 0.0)
	environment.fog_depth_begin = 4.0
	environment.fog_depth_end = 18.0
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var practical := OmniLight3D.new()
	practical.position = Vector3(4, 2.6, -6)
	practical.omni_range = 5
	practical.light_color = Color(1.0, 0.2, 0.15)
	practical.light_energy = 2
	add_child(practical)

	if not with_camera:
		return
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.45, 4.2)
	camera.rotation_degrees.x = -14
	camera.fov = 75
	add_child(camera)
	var flashlight := SpotLight3D.new()
	flashlight.position = Vector3(0.25, -0.2, 0)
	flashlight.rotation_degrees = Vector3(-6, 4, 0)
	flashlight.spot_range = 16
	flashlight.spot_angle = 22
	flashlight.light_energy = 6
	flashlight.light_color = Color(1.0, 0.95, 0.85)
	flashlight.shadow_enabled = true
	camera.add_child(flashlight)



func _material(color: Color, texture: Texture2D) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = LIT
	material.set_shader_parameter("albedo", color)
	material.set_shader_parameter("albedo_texture", texture)
	return material


func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	add_child(instance)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	instance.add_child(body)
	return instance



## Model inspection (dev): `--model=<res path>` shows one model in a lit void, `--anim=<clip>` plays
## a clip paused at `--anim-time=<s>`. Pair with Dev's --view and --screenshot.
func _inspect(path: String) -> void:
	var model: Node3D = load(path).instantiate()
	add_child(model)
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clip := Args.value("--anim", "")
	if player != null:
		print("Clips: ", player.get_animation_list())
		if clip != "" and player.has_animation(clip):
			player.play(clip)
			player.seek(float(Args.value("--anim-time", "0")), true)
			player.pause()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.055, 0.065)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.35, 0.38)
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, 30, 0)
	key.light_energy = 1.4
	add_child(key)
