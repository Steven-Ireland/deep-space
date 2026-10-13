class_name Player
extends CharacterBody3D
## A crew member (GDD §9). The owning peer moves it on netfox's tick: slow, weighty movement with
## real acceleration, short jumps, crouching under pipes. Everyone else sees it through its
## StateSynchronizer, with TickInterpolator smoothing its position (TECH §2). Mouse look is
## applied immediately every frame, never smoothed.

const WALK_SPEED := 2.2
const SPRINT_SPEED := 4.0
const CROUCH_SPEED := 1.2
const ACCELERATION := 9.0 # m/s² toward the target speed, on the ground
const BRAKING := 14.0
const AIR_CONTROL := 0.12
const JUMP_SPEED := 3.0
const GRAVITY := 9.8
const MOUSE_SENSITIVITY := 0.0022
const PITCH_LIMIT := 1.45
const EYE_HEIGHT := 1.62
const CROUCH_EYE_HEIGHT := 1.0
const HEIGHT := 1.8
const CROUCH_HEIGHT := 1.2
const REACH := 2.2

## Synced from the owner (StateSynchronizer).
var look := Vector2.ZERO # yaw, pitch in radians
var flashlight_on := false
var crouching := false
var sprinting := false

## The Interactable under the crosshair, on the owner's machine.
var aimed_at: Interactable
## The terminal this crew member is working at, if any (GDD §10).
var operating: Terminal
var _terminal_cursor := Vector2(-1, -1)
var _camera_tween: Tween

var _bob := 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Flashlight
@onready var body_visual: Node3D = $Body
@onready var shape: CollisionShape3D = $Shape
@onready var aim: RayCast3D = $Head/Camera3D/Aim


func _enter_tree() -> void:
	set_multiplayer_authority(int(str(name)))


func _ready() -> void:
	add_to_group(&"crew")
	var local := is_multiplayer_authority()
	camera.current = local
	body_visual.visible = not local
	look.x = rotation.y
	aim.target_position = Vector3(0, 0, -REACH)
	aim.enabled = local
	if local:
		add_to_group(&"local_player")
		_apply_dev_flags()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var hud := preload("res://game/player/visor_hud.tscn").instantiate()
		hud.player = self
		add_child(hud)
	NetworkTime.on_tick.connect(_tick)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if operating != null:
		_terminal_input(event)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look.x -= event.relative.x * MOUSE_SENSITIVITY
		look.y = clampf(look.y - event.relative.y * MOUSE_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("flashlight"):
		flashlight_on = not flashlight_on
	elif event.is_action_pressed("interact") and aimed_at != null:
		aimed_at.request_use()


func _process(delta: float) -> void:
	if is_multiplayer_authority():
		rotation.y = look.x
		head.rotation.x = look.y
		if operating == null:
			_update_aim()
		else:
			aimed_at = null
	else:
		var follow := 1.0 - exp(-delta * 18.0)
		rotation.y = lerp_angle(rotation.y, look.x, follow)
		head.rotation.x = lerp_angle(head.rotation.x, look.y, follow)
	flashlight.visible = flashlight_on
	var eye := CROUCH_EYE_HEIGHT if crouching else EYE_HEIGHT
	head.position.y = move_toward(head.position.y, eye, delta * 3.0)
	_head_bob(delta)


func _tick(delta: float, _tick_number: int) -> void:
	if not is_multiplayer_authority():
		_fit_shape()
		return
	crouching = Input.is_action_pressed("crouch") or (crouching and not _can_stand())
	_fit_shape()
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if operating != null:
		input = Vector2.ZERO
	sprinting = Input.is_action_pressed("sprint") and not crouching and input.y < -0.1
	var speed := CROUCH_SPEED if crouching else (SPRINT_SPEED if sprinting else WALK_SPEED)
	var wish := (Basis(Vector3.UP, look.x) * Vector3(input.x, 0, input.y)).limit_length(1.0) * speed

	var horizontal := Vector3(velocity.x, 0, velocity.z)
	var rate := (ACCELERATION if wish.length() > 0.01 else BRAKING) * (1.0 if is_on_floor() else AIR_CONTROL)
	horizontal = horizontal.move_toward(wish, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		if Input.is_action_just_pressed("jump") and not crouching:
			velocity.y = JUMP_SPEED
	else:
		velocity.y -= GRAVITY * delta

	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor


func _update_aim() -> void:
	aimed_at = null
	if aim.is_colliding() and aim.get_collider() is Interactable:
		var target := aim.get_collider() as Interactable
		if target.enabled:
			aimed_at = target


func _head_bob(delta: float) -> void:
	if not is_multiplayer_authority() or camera.top_level:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and speed > 0.3:
		_bob += delta * speed * 2.6
	else:
		_bob = lerpf(_bob, roundf(_bob / PI) * PI, 1.0 - exp(-delta * 6.0))
	var amount := clampf(speed / SPRINT_SPEED, 0.0, 1.0)
	camera.position = Vector3(cos(_bob) * 0.012, absf(sin(_bob)) * 0.03, 0) * amount


func _fit_shape() -> void:
	var capsule := shape.shape as CapsuleShape3D
	capsule.height = CROUCH_HEIGHT if crouching else HEIGHT
	shape.position.y = capsule.height / 2.0


func _can_stand() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = HEIGHT
	query.shape = capsule
	query.transform = Transform3D(Basis(), global_position + Vector3.UP * (HEIGHT / 2.0 + 0.02))
	query.exclude = [get_rid()]
	query.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## Dev flags (Dev): `--flashlight` starts with the light on; `--look=<yaw>,<pitch>` (degrees)
## sets the starting view. For checking builds unattended.
func _apply_dev_flags() -> void:
	if Args.flag("--flashlight"):
		flashlight_on = true
	var target := Args.value("--operate", "")
	if target != "":
		_operate_when_ready.call_deferred(target)
	var view := Args.value("--look", "")
	if view != "":
		var angles := view.split_floats(",")
		look = Vector2(deg_to_rad(angles[0]), deg_to_rad(angles[1] if angles.size() > 1 else 0.0))


## Steps up to `terminal`: the camera eases in until its screen fills the view, and the mouse
## drives the screen's cursor. Interact or pause steps back.
func operate(terminal: Terminal) -> void:
	if operating != null:
		return
	operating = terminal
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var start := camera.global_transform
	camera.top_level = true
	camera.global_transform = start
	_ease_camera(terminal.view_transform(camera.fov))


func leave_terminal() -> void:
	if operating == null:
		return
	operating.screen.cursor = Vector2(-1, -1)
	operating = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _ease_camera(head.global_transform)
	if operating == null:
		camera.top_level = false
		camera.transform = Transform3D.IDENTITY


func _ease_camera(to: Transform3D) -> Signal:
	if _camera_tween != null:
		_camera_tween.kill()
	_camera_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(camera, "global_transform", to, 0.45)
	return _camera_tween.finished


func _terminal_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("interact"):
		leave_terminal()
		return
	if event is InputEventMouse:
		var mouse: Vector2 = event.position
		var at := operating.pointer(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
		operating.screen.cursor = at
		if at.x >= 0:
			operating.push(event, at)
	elif event is InputEventKey:
		operating.push(event, Vector2.ZERO)


func _operate_when_ready(screen_mesh: String) -> void:
	for i in 20:
		await get_tree().process_frame
	for terminal: Terminal in get_tree().get_root().find_children("*", "Terminal", true, false):
		if terminal.screen_mesh_name == screen_mesh:
			operate(terminal)
			return
