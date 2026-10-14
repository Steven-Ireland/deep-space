class_name Player
extends CharacterBody3D
## A crew member (GDD §9). The owning peer moves it on netfox's tick: slow, weighty movement with
## real acceleration, short jumps, crouching under pipes. Everyone else sees it through its
## StateSynchronizer, with TickInterpolator smoothing its position (TECH §2): its suit walking in
## step, whatever's in its hand, its flashlight's beam, its wrist cuff when raised. Mouse look is
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

## Emitted on the owner's machine when the belt or the held slot changes (the visor shows it).
signal belt_changed

## Synced from the owner (StateSynchronizer).
var look := Vector2.ZERO # yaw, pitch in radians
var flashlight_on := false
var crouching := false
var sprinting := false
## The item kind in the right hand (Items), and whether the wrist cuff is raised to read.
var held := &""
var cuff_up := false

## The belt (GDD §9.4) on the owner's machine: four slots of item kinds, `slot` the one in hand.
var belt: Array[StringName] = Items.STARTING_BELT.duplicate()
var slot := 0

## The Interactable under the crosshair, on the owner's machine.
var aimed_at: Interactable
## The terminal this crew member is working at, if any (GDD §10).
var operating: Terminal
var _camera_tween: Tween

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Flashlight
@onready var body_visual: Node3D = $Body
@onready var shape: CollisionShape3D = $Shape
@onready var view_model: Node3D = $Head/Camera3D/ViewModel

var _animation: CrewAnimation # the arms (owner) or the suit (everyone else)
var _pose: CrewPose
var _held_item: Node3D
var _shown := &"-"
var _lens: Node3D
var _lens_material: ShaderMaterial
var _cuff_screen: MeshInstance3D
var _stride := 0.0 # stride cycles walked, for the head bob
var _bob := 0.0
var _legs_yaw := 0.0
var _crouch := 0.0
var _cuff := 0.0


func _enter_tree() -> void:
	set_multiplayer_authority(int(str(name)))


func _ready() -> void:
	add_to_group(&"crew")
	var local := is_multiplayer_authority()
	camera.current = local
	body_visual.visible = not local
	view_model.visible = local
	look.x = rotation.y
	flashlight.top_level = true
	if local:
		add_to_group(&"local_player")
		_equip_view_model()
		_animation = _animate_rig(view_model)
		held = belt[slot]
		_apply_dev_flags()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var hud := preload("res://game/player/visor_hud.tscn").instantiate()
		hud.player = self
		add_child(hud)
	else:
		_animation = _animate_rig(body_visual)
		_pose = CrewPose.new()
		body_visual.find_child("Skeleton3D", true, false).add_child(_pose)
		_cuff_screen = body_visual.find_child("cuff_screen", true, false) as MeshInstance3D
	NetworkTime.on_tick.connect(_tick)


func _exit_tree() -> void:
	if NetworkTime.on_tick.is_connected(_tick):
		NetworkTime.on_tick.disconnect(_tick)


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
		_flashlight_key()
	elif event.is_action_pressed("interact") and aimed_at != null:
		aimed_at.request_use()
	elif event.is_action_pressed("slot_next"):
		select_slot(posmod(slot + 1, belt.size()))
	elif event.is_action_pressed("slot_prev"):
		select_slot(posmod(slot - 1, belt.size()))
	else:
		for i in belt.size():
			if event.is_action_pressed("slot_%d" % (i + 1)):
				select_slot(i)


## Moves the crew member straight to `at`, without smoothing the jump (owner only).
func teleport(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	# netfox restores its last recorded state before each tick: record this one as both ends.
	var interpolator: TickInterpolator = $TickInterpolator
	interpolator.push_state()
	interpolator.push_state()
	interpolator.teleport()


## Takes the item in belt slot `index` in hand (GDD §9.4).
func select_slot(index: int) -> void:
	slot = index
	held = belt[slot]
	belt_changed.emit()


## F: the flashlight on or off, drawing it from the belt first if something else is in hand.
func _flashlight_key() -> void:
	if held == &"flashlight":
		flashlight_on = not flashlight_on
		return
	var index := belt.find(&"flashlight")
	if index >= 0:
		select_slot(index)
		flashlight_on = true


func _process(delta: float) -> void:
	if is_multiplayer_authority():
		rotation.y = look.x
		head.rotation.x = look.y
		cuff_up = (Input.is_action_pressed("cuff") or Args.flag("--cuff")) and operating == null
		if operating == null:
			_update_aim()
		else:
			aimed_at = null
	else:
		var follow := 1.0 - exp(-delta * 18.0)
		rotation.y = lerp_angle(rotation.y, look.x, follow)
		head.rotation.x = lerp_angle(head.rotation.x, look.y, follow)
	if held != _shown:
		_show_held()
	_animate(delta)
	_place_flashlight()
	var eye := CROUCH_EYE_HEIGHT if crouching else EYE_HEIGHT
	head.position.y = move_toward(head.position.y, eye, delta * 3.0)
	_head_bob(delta)


func _tick(delta: float, _tick_number: int) -> void:
	if not is_multiplayer_authority():
		_fit_shape()
		return
	crouching = Input.is_action_pressed("crouch") or Args.flag("--crouch") or (crouching and not _can_stand())
	_fit_shape()
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var moving := Args.value("--move", "")
	if moving != "":
		var v := moving.split_floats(",")
		input = Vector2(v[0], v[1])
	if operating != null:
		input = Vector2.ZERO
	sprinting = (Input.is_action_pressed("sprint") or Args.flag("--sprint")) and not crouching and input.y < -0.1
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


## The usable thing under the crosshair: the nearest Interactable within reach, unless something
## solid stands in front of it, other than its own housing (a console's box round its screens).
func _update_aim() -> void:
	aimed_at = null
	var from := camera.global_position
	var to := from - camera.global_basis.z * REACH
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, Interactable.LAYER)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := space.intersect_ray(query)
	var thing := hit.get("collider") as Interactable
	if thing == null or not thing.enabled:
		return
	var reach := from.distance_to(hit.position)
	var exclude: Array[RID] = [get_rid()]
	for i in 4:
		var solid := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1, exclude))
		if solid.is_empty() or from.distance_to(solid.position) >= reach - 0.02:
			aimed_at = thing
			return
		var body := solid.collider as Node
		if thing.housing == null or not (body == thing.housing or thing.housing.is_ancestor_of(body)):
			return
		exclude.append(solid.rid)


## The camera dips at each footfall and sways with the stride, in step with the arms and legs.
func _head_bob(delta: float) -> void:
	if not is_multiplayer_authority() or camera.top_level:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	var target := clampf(speed / SPRINT_SPEED, 0.0, 1.0) if is_on_floor() and speed > 0.3 else 0.0
	_bob = lerpf(_bob, target, 1.0 - exp(-delta * 6.0))
	var dip := 0.5 + 0.5 * cos(_stride * TAU * 2.0)
	camera.position = Vector3(sin(_stride * TAU) * 0.012, -dip * 0.03, 0) * _bob


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
## sets the starting view; `--at=<x>,<y>,<z>` the starting spot; `--hold=<kind>` puts an item
## in hand. For checking builds unattended.
func _apply_dev_flags() -> void:
	if Args.flag("--flashlight"):
		flashlight_on = true
	var at := Args.value("--at", "")
	if at != "":
		var v := at.split_floats(",")
		teleport(Vector3(v[0], v[1], v[2]))
	var kind := StringName(Args.value("--hold", ""))
	if belt.has(kind):
		select_slot(belt.find(kind))
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


## The first-person arms: shadowless (they'd shade the flashlight in them), the wrist cuff's
## screen live.
func _equip_view_model() -> void:
	for mesh: GeometryInstance3D in view_model.find_children("*", "GeometryInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cuff := Terminal.new()
	cuff.screen_mesh_name = "screen_cuff"
	cuff.screen_script = preload("res://game/terminals/screens/cuff_screen.gd")
	cuff.resolution = Vector2i(48, 56)
	cuff.interactive = false
	view_model.find_child("Arms", true, false).add_child(cuff)


func _animate_rig(rig: Node3D) -> CrewAnimation:
	var player := rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		return null
	var tree := CrewAnimation.new()
	player.get_parent().add_child(tree)
	tree.setup(player)
	return tree


## Puts what's held in the hand: the first-person fist for the owner, the suit's glove for the rest.
func _show_held() -> void:
	if _held_item != null:
		_held_item.queue_free()
		_held_item = null
	_shown = held
	if Args.flag("--debug-crew"):
		print("Crew %s (%s): holds %s" % [name, "own" if is_multiplayer_authority() else "remote", held])
	var rig := view_model if is_multiplayer_authority() else body_visual
	_held_item = Items.hold(held, rig.find_child("SOCKET_grip", true, false) as Node3D)
	_lens = null
	_lens_material = null
	if _held_item != null:
		_lens = _held_item.find_child("SOCKET_light", true, false) as Node3D
		var glass := _held_item.find_child("lens", true, false) as MeshInstance3D
		if glass != null and glass.get_active_material(0) is ShaderMaterial:
			_lens_material = glass.get_active_material(0).duplicate()
			glass.material_override = _lens_material


## The flashlight shines from the torch's lens, where the torch points; the owner's from the torch
## in their fist, everyone else's from the torch in the suit's glove, aimed where its wearer looks.
## Never through a wall the lens has been pushed into.
func _place_flashlight() -> void:
	var on := flashlight_on and held == &"flashlight" and _lens != null
	flashlight.visible = on
	if _lens_material != null:
		_lens_material.set_shader_parameter("energy", 2.0 if on else 0.15)
	if _held_item != null and not is_multiplayer_authority() and held == &"flashlight":
		_held_item.global_basis = head.global_basis * Basis(Vector3.UP, PI)
	if not on:
		return
	var forward := _held_item.global_basis.z.normalized()
	var eye := head.global_position
	var lens := _lens.global_position + forward * 0.04
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(eye, lens, 1, [get_rid()])
	var blocked := space.intersect_ray(query)
	if not blocked.is_empty():
		lens = blocked.position + (eye - lens).normalized() * 0.06
	flashlight.global_transform = Transform3D(Basis.looking_at(forward, _held_item.global_basis.y), lens)


## Arms (owner) and suit (everyone else) blend their clips by what the crew member's doing.
func _animate(delta: float) -> void:
	var ease := 1.0 - exp(-delta * 8.0)
	_crouch = lerpf(_crouch, 1.0 if crouching else 0.0, ease)
	_cuff = move_toward(_cuff, 1.0 if cuff_up else 0.0, delta / 0.3)
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	var speed := horizontal.length()
	var local := global_basis.inverse() * horizontal # forward -Z, left -X
	var backward := local.z > 0.35 * speed and speed > 0.3
	var rate := CrewAnimation.stride_rate(speed, clampf((speed - WALK_SPEED) / (SPRINT_SPEED - WALK_SPEED), 0.0, 1.0))
	if crouching:
		rate = 1.0 / CrewAnimation.SNEAK_PERIOD
	if speed > 0.3:
		_stride += delta * rate
	if _cuff_screen != null:
		_cuff_screen.visible = _cuff > 0.3
	if _animation == null:
		return
	_animation.move = clampf(speed / (CROUCH_SPEED if crouching else WALK_SPEED), 0.0, 1.0)
	_animation.run = clampf((speed - WALK_SPEED) / (SPRINT_SPEED - WALK_SPEED), 0.0, 1.0)
	_animation.crouch = _crouch
	_animation.cuff = _cuff
	_animation.hold = Items.hold_style(held)
	_animation.direction = -1.0 if backward else 1.0
	_animation.step(delta, speed)
	if _pose != null:
		# The legs face the way they're going (backwards: the way they're backing), the body the
		# way it looks.
		var wanted := 0.0
		if speed > 0.3:
			wanted = atan2(local.x, local.z) if backward else atan2(-local.x, -local.z)
			wanted = clampf(wanted, -1.2, 1.2)
		_legs_yaw = lerp_angle(_legs_yaw, wanted, ease)
		_pose.legs_yaw = _legs_yaw
		_pose.pitch = head.rotation.x
		_pose.torch = 1.0 if Items.hold_style(held) == "torch" else 0.0
