class_name Player
extends CharacterBody3D
## A crew member (GDD §9). The owning peer moves it on netfox's tick: slow, weighty movement with
## real acceleration, short jumps, crouching under pipes. Everyone else sees it through its
## StateSynchronizer, with TickInterpolator smoothing its position (TECH §2): its suit walking in
## step, whatever's in its hand, its helmet lamp's beam, its wrist cuff when raised. Mouse look is
## applied immediately every frame, never smoothed.

const WALK_SPEED := 2.2
const SPRINT_SPEED := 4.0
const CROUCH_SPEED := 1.2
const CARRY_SPEED := 1.6 # with something heavy in both hands; no sprinting
const ACCELERATION := 9.0 # m/s² toward the target speed, on the ground
const BRAKING := 14.0
const AIR_CONTROL := 0.12
const JUMP_SPEED := 3.0
## How long a press of jump is kept for the movement tick to act on: ticks come 30 times a second,
## fewer than frames, so a press read on the tick itself was usually missed. Pressed just before
## landing, it jumps on touching down.
const JUMP_BUFFER := 0.2
## Seconds the crosshair can slip off a thing being held (the Jump Lever) before the hold's lost.
const HOLD_SLACK := 0.3
const GRAVITY := 9.8
## A fall at least this fast (m/s) comes down with a thump (Sound.landing): a jump, not a step down.
const LAND_SPEED := 1.8
const MOUSE_SENSITIVITY := 0.0022
const PITCH_LIMIT := 1.45
const EYE_HEIGHT := 1.62
const CROUCH_EYE_HEIGHT := 1.0
const HEIGHT := 1.8
const CROUCH_HEIGHT := 1.2
const REACH := 2.2
## Where the helmet lamp's lens is from the eye (art/blender/characters.py: LAMP): on the left of
## the helmet, a little above the eye and in front of it.
const LAMP_OFFSET := Vector3(-0.2, 0.1, -0.127)
## Metres ahead the lamp is aimed to cross the line of sight: nearer than that, its spot sits a
## little left of where you look; beyond it, a little right.
const LAMP_CONVERGE := 6.0
## Letting go (Q): a tap sets the thing down; held longer than THROW_AFTER, it's thrown, harder
## the longer it's held, up to THROW_MAX after THROW_WIND more seconds. Heavy things go less far.
const THROW_AFTER := 0.2
const THROW_WIND := 0.6
const THROW_MIN := 3.0
const THROW_MAX := 9.0
const DROP_SPEED := 0.6
## Suit O2 at base capacity, in seconds of breathing out of the air (GDD §9.2), and how many times
## faster a sprint uses it. With none left, health runs out over SUFFOCATION seconds.
const O2_CAPACITY := 360.0
const SPRINT_BREATH := 3.0
const SUFFOCATION := 20.0
## Where the suit takes its breath, above the feet: in the chest, for which zone it's in.
const CHEST_HEIGHT := 1.2
## The helmet lamp's battery (GDD §9.3): LAMP_LIFE seconds lit on a full charge. Below LAMP_LOW it
## flickers; flat, it goes out until it's charged in the suit room.
const LAMP_LIFE := 360.0
const LAMP_LOW := 0.15
## Using things (LMB): a swing takes SWING_TIME and lands SWING_HIT in, on whatever's within
## SWING_REACH, knocking loose things with SWING_IMPULSE (N·s). A canister gives CANISTER_O2
## seconds of O2; a struck flare burns FLARE_BURN seconds.
const SWING_TIME := 0.6
const SWING_HIT := 0.36
const SWING_REACH := 1.5
const SWING_IMPULSE := 5.0
const CANISTER_O2 := 180.0
const FLARE_BURN := 60.0
## The camera's shake at full strength in a jump: metres, and radians.
const SHAKE_MOVE := 0.012
const SHAKE_TURN := 0.012

## Emitted on the owner's machine when the belt, the slot drawn or what's carried changes (the
## visor shows it).
signal belt_changed

## Synced from the owner (StateSynchronizer).
var look := Vector2.ZERO # yaw, pitch in radians
var lamp_on := false
var crouching := false
var sprinting := false
## The kind of item in hand (Items), whether it's burning (a struck flare), and whether the wrist
## cuff is raised to read.
var held := &""
var held_lit := false
var cuff_up := false
## Swings so far: each new one plays the swing for everyone.
var swings := 0
## The suit (GDD §9.2): O2 left in seconds, health 0..1, and whether it's breathing for its wearer
## (out of the air).
var o2 := O2_CAPACITY
var health := 1.0
var in_vacuum := false
## The helmet lamp's charge, 0..1.
var battery := 1.0
## Whether they're on the ground (only the owner's body moves, so only it knows): footfalls and
## landings are heard by everyone.
var grounded := true
## Dead (GDD §11), and why: &"suffocated", or &"lost" (left behind when the station jumped: no body
## to bring home). Their body lies where they fell (a LooseBody); they watch through the station's
## cameras (Spectator) until the med bay brings them back (revive).
var dead := false
var cause := &""

## The belt (GDD §9.4) on the owner's machine: four slots of item records ({} is empty), `slot` the
## one drawn into the hand.
var belt: Array[Dictionary] = []
var slot := 0
## A big thing held in both hands ({} when there's none), on the owner's machine. While carrying,
## nothing comes off the belt.
var carrying := {}

## The Interactable under the crosshair, on the owner's machine.
var aimed_at: Interactable
## The thing interact is being held on (one that takes a hold, like the Jump Lever), and how long.
var _holding: Interactable
var _hold_time := 0.0
var _hold_lost := 0.0 # seconds the crosshair has been off it
## The terminal this crew member is working at, if any (GDD §10).
var operating: Terminal
var _camera_tween: Tween

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var lamp: SpotLight3D = $Head/Lamp
@onready var body_visual: Node3D = $Body
@onready var shape: CollisionShape3D = $Shape
@onready var view_model: Node3D = $Head/Camera3D/ViewModel

var _animation: CrewAnimation # the arms (owner) or the suit (everyone else)
var _pose: CrewPose
var _held_item: Node3D
var _shown := &"-"
var _lamp_socket: Node3D # the suit's helmet lamp, everyone else's view
var _lens_material: ShaderMaterial
var _cuff_screen: MeshInstance3D
var _stride := 0.0 # stride cycles walked, for the head bob
var _bob := 0.0
var _legs_yaw := 0.0
var _crouch := 0.0
var _cuff := 0.0
var _winding := -1.0 # seconds Q has been held, or -1
var _jump_wanted := 0.0 # seconds left on a press of jump not yet acted on
var _swing_left := 0.0
var _swings_seen := 0
var _shown_lit := false
var _flame: Flame
var _spine_material: ShaderMaterial
var _lamp_energy := 0.0
var _lamp_phase := 0.0
var _footfalls := 0 # heel strikes so far: two a stride cycle
var _fall := 0.0 # m/s, while in the air
var _was_grounded := true
var _lamp_heard := false
var _spectator: Spectator
var _riding: Derelict # the derelict they're aboard, and where it was at their last tick
var _ride_from := Transform3D()


func _init() -> void:
	for i in Items.BELT_SLOTS:
		belt.append({})


func _enter_tree() -> void:
	set_multiplayer_authority(int(str(name)))


func _ready() -> void:
	add_to_group(&"crew")
	var local := is_multiplayer_authority()
	camera.current = local
	body_visual.visible = not local
	view_model.visible = local
	look.x = rotation.y
	lamp.top_level = true
	_lamp_energy = lamp.light_energy
	_lamp_phase = randf() * 100.0
	if local:
		add_to_group(&"local_player")
		_equip_view_model()
		_animation = _animate_rig(view_model)
		_update_held()
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
		_lamp_socket = body_visual.find_child("SOCKET_lamp", true, false) as Node3D
		var spine := body_visual.find_child("spine_lights", true, false) as MeshInstance3D
		if spine != null and spine.get_active_material(0) is ShaderMaterial:
			_spine_material = spine.get_active_material(0).duplicate()
			spine.material_override = _spine_material
		var glass := body_visual.find_child("lamp_lens", true, false) as MeshInstance3D
		if glass != null and glass.get_active_material(0) is ShaderMaterial:
			_lens_material = glass.get_active_material(0).duplicate()
			glass.material_override = _lens_material
		var beam := LampBeam.new()
		beam.holder = self
		lamp.add_child(beam)
	NetworkTime.on_tick.connect(_tick)


func _exit_tree() -> void:
	if NetworkTime.on_tick.is_connected(_tick):
		NetworkTime.on_tick.disconnect(_tick)


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority() or dead:
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
	elif event.is_action_pressed("jump"):
		_jump_wanted = JUMP_BUFFER
	elif event.is_action_pressed("lamp"):
		lamp_on = not lamp_on and battery > 0.0
	elif event.is_action_pressed("interact") and aimed_at != null and aimed_at.usable_by(self):
		if aimed_at.hold > 0.0:
			_holding = aimed_at
			_hold_time = 0.0
			_hold_lost = 0.0
		else:
			aimed_at.request_use()
	elif event.is_action_pressed("use") and not cuff_up:
		use_held()
	elif event.is_action_pressed("drop") and not in_hands().is_empty():
		_winding = 0.0
	elif event.is_action_released("drop") and _winding >= 0.0:
		let_go(_winding)
		_winding = -1.0
	elif event.is_action_pressed("slot_next"):
		select_slot(posmod(slot + 1, belt.size()))
	elif event.is_action_pressed("slot_prev"):
		select_slot(posmod(slot - 1, belt.size()))
	else:
		for i in belt.size():
			if event.is_action_pressed("slot_%d" % (i + 1)):
				select_slot(i)


## The crew member playing as `peer`, or null.
static func of_peer(tree: SceneTree, peer: int) -> Player:
	for player: Player in tree.get_nodes_in_group(&"crew"):
		if player.name == str(peer):
			return player
	return null


## Which crew member they are, by the order they came aboard: CREW 1 to 4 (the Vitals board's tiles).
func crew_name() -> String:
	var crew := get_tree().get_nodes_in_group(&"crew")
	crew.sort_custom(func(a, b): return int(str(a.name)) < int(str(b.name)))
	return "CREW %d" % (crew.find(self) + 1)


## They die (GDD §11), on their own machine: everything they had drops round their body where they
## fell (`lost`: with no body, it's all gone with them), and their eyes go to the station.
func die(why: StringName) -> void:
	if dead or not is_multiplayer_authority():
		return
	if operating != null:
		leave_terminal()
	var had: Array[Dictionary] = []
	for record in belt + [carrying]:
		if not record.is_empty():
			had.append(record)
	for i in belt.size():
		belt[i] = {}
	carrying = {}
	_update_held()
	dead = true
	cause = why
	health = 0.0
	lamp_on = false
	cuff_up = false
	if why != &"lost":
		var body := {"kind": &"body", "peer": int(str(name)), "crew": crew_name()}
		LooseItems.of(self).fall(body, had, Transform3D(Basis(Vector3.UP, look.x), global_position), velocity)
	velocity = Vector3.ZERO
	print("Crew %s: dead (%s)." % [crew_name(), why])
	_spectator = Spectator.new()
	_spectator.player = self
	add_child(_spectator)


## The host tells their machine the med bay's brought them back (GDD §11): standing at `at`, the
## suit full, the belt empty, their eyes their own again.
@rpc("any_peer", "call_local", "reliable")
func revive(at: Transform3D) -> void:
	if multiplayer.get_remote_sender_id() > 1 or not is_multiplayer_authority():
		return
	dead = false
	cause = &""
	health = 1.0
	o2 = O2_CAPACITY
	battery = 1.0
	teleport(at.origin)
	look = Vector2(at.basis.get_euler().y, 0.0)
	if _spectator != null:
		_spectator.queue_free()
		_spectator = null
	camera.make_current()
	print("Crew %s: brought back." % crew_name())


## Beats a minute (the cuff, the Vitals board): resting, up with effort, racing as the air runs
## out or as health fails; nothing, dead.
func heart_rate() -> float:
	if health <= 0.0:
		return 0.0
	var speed := Vector2(velocity.x, velocity.z).length()
	var bpm := 68.0 + speed * 18.0 + (25.0 if sprinting else 0.0)
	var low := O2_CAPACITY * 0.25
	if in_vacuum and o2 < low:
		bpm += 30.0 * (1.0 - o2 / low)
	return bpm + (1.0 - health) * 50.0


## Tops the suit's O2 up by `seconds`, or all the way.
func refill(seconds := O2_CAPACITY) -> void:
	o2 = minf(O2_CAPACITY, o2 + seconds)


## LMB (GDD §9.5) with what's in hand: swing a tool, refill the suit from a canister (used up), or
## strike a flare.
func use_held() -> void:
	var record := in_hands()
	match Items.use_of(Items.kind_of(record)):
		"swing":
			if _swing_left > 0.0:
				return
			swings += 1
			_swing_left = SWING_TIME
			get_tree().create_timer(SWING_HIT).timeout.connect(_land_swing)
		"refill":
			refill(CANISTER_O2)
			belt[slot] = {}
			_update_held()
		"strike":
			if not record.has("burn"):
				record.burn = FLARE_BURN
				_update_held()


## The swing lands on whatever's in front within reach: a loose thing gets knocked away (the host
## applies it). Creatures, hatches and the rest come later.
func _land_swing() -> void:
	var view := _view()
	var forward := -view.basis.z
	var hit := get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(view.origin, view.origin + forward * SWING_REACH, 1 | Pickup.LAYER, [get_rid()]))
	if hit.get("collider") is Pickup:
		LooseItems.of(self).whack(hit.collider, (forward + Vector3.UP * 0.3).normalized() * SWING_IMPULSE, hit.position)


## The host tells this crew member's machine they've topped up at the station: "o2" at the O2
## rack, "lamp" at the lamp charger.
@rpc("any_peer", "call_local", "reliable")
func top_up(what: String) -> void:
	if multiplayer.get_remote_sender_id() > 1 or not is_multiplayer_authority():
		return
	match what:
		"o2":
			refill()
		"lamp":
			battery = 1.0


## Moves the crew member straight to `at`, without smoothing the jump (owner only).
func teleport(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	# netfox restores its last recorded state before each tick: record this one as both ends.
	var interpolator: TickInterpolator = $TickInterpolator
	interpolator.push_state()
	interpolator.push_state()
	interpolator.teleport()


## Draws the item in belt slot `index` into the hand (GDD §9.4): not while carrying.
func select_slot(index: int) -> void:
	if not carrying.is_empty():
		return
	slot = index
	_update_held()


## What's in the hands: the thing carried, or the item drawn from the belt ({} for nothing).
func in_hands() -> Dictionary:
	return carrying if not carrying.is_empty() else belt[slot]


## The belt slot a small thing taken now would go in: the one drawn if it's empty, otherwise the
## first empty one; -1 when the belt is full.
func free_slot() -> int:
	if belt[slot].is_empty():
		return slot
	for i in belt.size():
		if belt[i].is_empty():
			return i
	return -1


## Whether there's room to take a `kind` now: not with something carried; a big thing needs the
## hands, a small thing a free slot.
func room_for(kind: StringName) -> bool:
	if not carrying.is_empty():
		return false
	return Items.two_handed(kind) or free_slot() >= 0


## The host hands this crew member something they took (LooseItems.take): a big thing into both
## hands, a small one into its slot, drawn. If there's no room by now (two takes in flight), it's
## let go again at once.
@rpc("any_peer", "call_local", "reliable")
func receive(record: Dictionary) -> void:
	if multiplayer.get_remote_sender_id() > 1 or not is_multiplayer_authority():
		return
	var kind := Items.kind_of(record)
	if not room_for(kind):
		LooseItems.of(self).let_go(record, _release_point(), Vector3.ZERO)
		return
	if Items.two_handed(kind):
		carrying = record
	else:
		slot = free_slot()
		belt[slot] = record
	_update_held()
	Sound.taken(self)


## Takes what's in the hands out of them without letting go of it into the world (it's gone into
## something: a cell into the fuel rack), and returns it.
func take_from_hands() -> Dictionary:
	var record := in_hands()
	if not carrying.is_empty():
		carrying = {}
	else:
		belt[slot] = {}
	_update_held()
	return record


## Q: sets down what's in the hands, or throws it if Q was held longer than a tap: the longer, the
## harder, though heavy things don't go far. It leaves from just ahead of the eye, never through a
## wall, carrying the crew member's own speed.
func let_go(held_for: float) -> void:
	var record := in_hands()
	if record.is_empty():
		return
	# A body leaves the arms lying as it was carried, and falls from there.
	var body_at := _held_item.global_transform if _held_item is Ragdoll else Transform3D()
	if not carrying.is_empty():
		carrying = {}
	else:
		belt[slot] = {}
	_update_held()
	var heft := clampf(sqrt(3.0 / Items.mass(Items.kind_of(record))), 0.25, 1.0)
	var push := DROP_SPEED
	if held_for >= THROW_AFTER:
		push = lerpf(THROW_MIN, THROW_MAX, clampf((held_for - THROW_AFTER) / THROW_WIND, 0.0, 1.0)) * heft
	var forward := -_view().basis.z
	var launch := Vector3(velocity.x, 0.0, velocity.z) + forward * push + Vector3.UP * push * 0.15
	LooseItems.of(self).let_go(record, body_at if Items.kind_of(record) == &"body" else _release_point(), launch)


## Where a thing let go leaves the hand: ahead of the eye and a little below it, facing the way the
## crew member faces, short of anything solid in between.
func _release_point() -> Transform3D:
	var view := _view()
	var forward := -view.basis.z
	var out := view.origin + forward * 0.5 - view.basis.y * 0.3
	var hit := get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(view.origin, out + forward * 0.2, 1, [get_rid()]))
	if not hit.is_empty():
		out = view.origin.lerp(hit.position, 0.5)
	return Transform3D(Basis(Vector3.UP, look.x), out)


## The eye: the camera's, or the head's while the camera's away at a terminal.
func _view() -> Transform3D:
	return head.global_transform if camera.top_level else camera.global_transform


## `held` follows what's in the hands, and the visor hears of the change.
func _update_held() -> void:
	held = Items.kind_of(in_hands())
	held_lit = Items.burning(in_hands())
	belt_changed.emit()


## Struck flares burn down wherever they're carried, and are gone once they're out.
func _burn_flares(delta: float) -> void:
	var out := false
	for i in belt.size():
		if belt[i].has("burn"):
			belt[i].burn -= delta
			if belt[i].burn <= 0.0:
				belt[i] = {}
				out = true
	if out:
		_update_held()
	if _flame != null:
		_flame.strength = in_hands().get("burn", 0.0) / FLARE_BURN


func _process(delta: float) -> void:
	# The dead leave no one standing: their body's a LooseBody now.
	shape.disabled = dead
	body_visual.visible = not is_multiplayer_authority() and not dead
	view_model.visible = is_multiplayer_authority() and not dead
	if is_multiplayer_authority():
		rotation.y = look.x
		head.rotation.x = look.y
		cuff_up = (Input.is_action_pressed("cuff") or Args.flag("--cuff")) and operating == null and carrying.is_empty() and not dead
		if _winding >= 0.0:
			_winding += delta
		_jump_wanted = maxf(0.0, _jump_wanted - delta)
		_swing_left = maxf(0.0, _swing_left - delta)
		_burn_flares(delta)
		if operating == null and not dead:
			_update_aim()
		else:
			aimed_at = null
		_keep_holding(delta)
	else:
		var follow := 1.0 - exp(-delta * 18.0)
		rotation.y = lerp_angle(rotation.y, look.x, follow)
		head.rotation.x = lerp_angle(head.rotation.x, look.y, follow)
	if held != _shown or held_lit != _shown_lit:
		_show_held()
	_animate(delta)
	_make_sounds()
	_place_lamp()
	_light_spine()
	var eye := CROUCH_EYE_HEIGHT if crouching else EYE_HEIGHT
	head.position.y = move_toward(head.position.y, eye, delta * 3.0)
	_head_bob(delta)


func _tick(delta: float, _tick_number: int) -> void:
	if not is_multiplayer_authority():
		_fit_shape()
		return
	if dead:
		velocity = Vector3.ZERO
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
	var heavy := not carrying.is_empty()
	sprinting = (Input.is_action_pressed("sprint") or Args.flag("--sprint")) and not crouching and not heavy and input.y < -0.1
	var speed := CROUCH_SPEED if crouching else (SPRINT_SPEED if sprinting else WALK_SPEED)
	if heavy:
		speed = minf(speed, CARRY_SPEED)
	var wish := (Basis(Vector3.UP, look.x) * Vector3(input.x, 0, input.y)).limit_length(1.0) * speed

	var horizontal := Vector3(velocity.x, 0, velocity.z)
	var rate := (ACCELERATION if wish.length() > 0.01 else BRAKING) * (1.0 if is_on_floor() else AIR_CONTROL)
	horizontal = horizontal.move_toward(wish, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		if _jump_wanted > 0.0 and not crouching:
			velocity.y = JUMP_SPEED
			_jump_wanted = 0.0
	else:
		velocity.y -= GRAVITY * delta

	_ride()
	velocity *= NetworkTime.physics_factor
	move_and_slide()
	velocity /= NetworkTime.physics_factor
	grounded = is_on_floor()
	_breathe(delta)
	if health <= 0.0:
		die(&"suffocated")
	_left_behind()
	if lamp_on:
		battery = maxf(0.0, battery - delta / LAMP_LIFE)
		lamp_on = battery > 0.0


## Off the station as it goes into the tunnel (GDD §8.3): left behind, and lost.
func _left_behind() -> void:
	var run := Run.of(self)
	var lantern := get_tree().get_first_node_in_group(&"lantern")
	if run != null and lantern != null and run.in_tunnel() and lantern.room_at(global_position) == "OUTSIDE":
		die(&"lost")


## Aboard a derelict that's moving (drifting in, or off again with them still in it), they move
## with it: carried by however far it's gone since their last tick, and turned with it.
func _ride() -> void:
	if _riding != null and is_instance_valid(_riding):
		var moved := _riding.global_transform * _ride_from.affine_inverse()
		if not moved.is_equal_approx(Transform3D.IDENTITY):
			global_position = moved * global_position
			velocity = moved.basis * velocity
			look.x += moved.basis.get_euler().y
	_riding = Derelict.at(get_world_3d(), global_position + Vector3.UP * CHEST_HEIGHT)
	if _riding != null:
		_ride_from = _riding.global_transform


## The suit breathes for its wearer wherever there's no air (GDD §9.2): O2 runs down, faster at a
## sprint; with none left, health runs out.
func _breathe(delta: float) -> void:
	in_vacuum = not Zone.has_air(get_world_3d(), global_position + Vector3.UP * CHEST_HEIGHT)
	if not in_vacuum:
		return
	o2 = maxf(0.0, o2 - delta * (SPRINT_BREATH if sprinting else 1.0))
	if o2 <= 0.0:
		health = maxf(0.0, health - delta / SUFFOCATION)


## Interact held on a thing that takes a hold: used once it's been held long enough, given up if
## interact is let go, it can't be used now, or the crosshair is off it for longer than HOLD_SLACK
## (a small handle is easy to slip off for a moment).
func _keep_holding(delta: float) -> void:
	if _holding == null:
		return
	_hold_lost = 0.0 if aimed_at == _holding else _hold_lost + delta
	if not Input.is_action_pressed("interact") or _hold_lost > HOLD_SLACK or not _holding.usable_by(self):
		_holding = null
		return
	_hold_time += delta
	if _hold_time >= _holding.hold:
		_holding.request_use()
		_holding = null


## How far through its hold `thing` is, 0..1 (0 when it isn't being held).
func hold_progress(thing: Interactable) -> float:
	return clampf(_hold_time / thing.hold, 0.0, 1.0) if _holding == thing and thing.hold > 0.0 else 0.0


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


## The camera dips at each footfall and sways with the stride, in step with the arms and legs; and
## shakes with the station in a jump (GDD §5), and as a derelict's hull meets the collar.
func _head_bob(delta: float) -> void:
	if not is_multiplayer_authority() or camera.top_level:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	var target := clampf(speed / SPRINT_SPEED, 0.0, 1.0) if is_on_floor() and speed > 0.3 else 0.0
	_bob = lerpf(_bob, target, 1.0 - exp(-delta * 6.0))
	var dip := 0.5 + 0.5 * cos(_stride * TAU * 2.0)
	camera.position = Vector3(sin(_stride * TAU) * 0.012, -dip * 0.03, 0) * _bob
	var run := Run.of(self)
	var collar := Collar.of(self)
	var shake := maxf(run.shake() if run != null else 0.0, collar.shake() if collar != null else 0.0)
	if shake > 0.0:
		var t := Time.get_ticks_msec() / 1000.0
		var jolt := Vector3(sin(t * 37.0) + sin(t * 23.0 + 1.3), sin(t * 29.0 + 2.1) + sin(t * 41.0), sin(t * 19.0 + 0.7)) * 0.5
		camera.position += jolt * SHAKE_MOVE * shake
		camera.rotation = Vector3(jolt.y, jolt.x, jolt.z) * SHAKE_TURN * shake
	else:
		camera.rotation = Vector3.ZERO


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


## Dev flags (Dev): `--lamp` starts with the helmet lamp on; `--look=<yaw>,<pitch>` (degrees)
## sets the starting view; `--at=<x>,<y>,<z>` the starting spot; `--belt=<kind>,...` what's on the
## belt; `--hold=<kind>` puts an item in hand; `--take` and `--throw` act a little later. For
## checking builds unattended.
func _apply_dev_flags() -> void:
	if Args.flag("--lamp"):
		lamp_on = true
	var at := Args.value("--at", "")
	if at != "":
		var v := at.split_floats(",")
		teleport(Vector3(v[0], v[1], v[2]))
	var kit := Args.value("--belt", "")
	if kit != "":
		var kinds := kit.split(",")
		for i in belt.size():
			belt[i] = Items.make(StringName(kinds[i])) if i < kinds.size() else {}
		_update_held()
	var kind := StringName(Args.value("--hold", ""))
	if Items.KINDS.has(kind):
		_dev_hold(kind)
	if Args.flag("--take") or Args.flag("--use") or Args.flag("--throw"):
		_dev_actions.call_deferred()
	_dev_suit()
	if Args.flag("--die"):
		get_tree().create_timer(float(Args.value("--die", "1"))).timeout.connect(func(): die(&"suffocated"))
	var target := Args.value("--operate", "")
	if target != "":
		_operate_when_ready.call_deferred(target)
	var view := Args.value("--look", "")
	if view != "":
		var angles := view.split_floats(",")
		look = Vector2(deg_to_rad(angles[0]), deg_to_rad(angles[1] if angles.size() > 1 else 0.0))


## `--o2=<seconds>`, `--health=<0..1>` and `--battery=<0..1>`: how the suit starts.
func _dev_suit() -> void:
	o2 = float(Args.value("--o2", str(O2_CAPACITY)))
	health = float(Args.value("--health", "1"))
	battery = float(Args.value("--battery", "1"))


## `--hold`: a `kind` in hand: drawn from the belt if it's there, carried if it's big, otherwise put
## in a free slot (or the last) and drawn.
func _dev_hold(kind: StringName) -> void:
	if Items.two_handed(kind):
		carrying = Items.make(kind)
	else:
		var index := belt.find_custom(func(record: Dictionary) -> bool: return Items.kind_of(record) == kind)
		if index < 0:
			index = free_slot() if free_slot() >= 0 else belt.size() - 1
			belt[index] = Items.make(kind)
		slot = index
	_update_held()


## `--take`: a second in, takes what's under the crosshair; `--use`: half a second later, uses
## what's in hand; `--throw=<seconds>`: a second after that, lets go of it as if Q were held that
## long (0 sets it down).
func _dev_actions() -> void:
	await get_tree().create_timer(1.0).timeout
	if Args.flag("--take") and aimed_at != null and aimed_at.usable_by(self):
		aimed_at.request_use()
	await get_tree().create_timer(0.5).timeout
	if Args.flag("--use"):
		use_held()
	await get_tree().create_timer(1.0).timeout
	if Args.flag("--throw"):
		let_go(float(Args.value("--throw", "0")))


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


## The first-person arms: shadowless (they'd shade the lamp's light on what's in hand), the wrist
## cuff's screen live.
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
	var own := is_multiplayer_authority()
	var rig := view_model if own else body_visual
	_held_item = Items.hold(held, rig, not own)
	_shown_lit = held_lit
	_flame = Flame.light(_held_item) if held_lit and _held_item != null else null


## The helmet lamp shines from its lens on the left of the helmet, aimed to cross the line of sight
## LAMP_CONVERGE ahead: the owner's beside their eye (bobbing with the view), everyone else's from
## the suit's lamp, which the head carries. Never through a wall the lens has been pushed into.
## Everyone else also sees its beam in the air and its glare (LampBeam, riding the light).
func _place_lamp() -> void:
	lamp.visible = lamp_on
	var power := _lamp_flicker() if lamp_on else 0.0
	lamp.light_energy = _lamp_energy * power
	if _lens_material != null:
		_lens_material.set_shader_parameter("energy", lerpf(0.15, 2.0, power))
	if not lamp_on:
		return
	var view := head.global_transform
	if is_multiplayer_authority() and not camera.top_level:
		view = camera.global_transform
	var lens := view * LAMP_OFFSET
	if _lamp_socket != null:
		lens = _lamp_socket.global_position
	var space := get_world_3d().direct_space_state
	var blocked := space.intersect_ray(PhysicsRayQueryParameters3D.create(view.origin, lens, 1, [get_rid()]))
	if not blocked.is_empty():
		lens = blocked.position + (view.origin - lens).normalized() * 0.06
	var target := view.origin - view.basis.z * LAMP_CONVERGE
	lamp.global_transform = Transform3D(Basis.looking_at(target - lens, view.basis.y), lens)


## How bright the lamp burns, 0..1: steady until the battery's low, then dropping out in stutters,
## more often as it runs down. (Everyone works it out from the synced charge, so a teammate's lamp
## flickers too, if not in step.)
func _lamp_flicker() -> float:
	if battery >= LAMP_LOW:
		return 1.0
	var t := Time.get_ticks_msec() / 1000.0 + _lamp_phase
	var noise := sin(t * 7.3) * sin(t * 2.9 + 1.7) * sin(t * 13.1)
	var failing := 1.0 - battery / LAMP_LOW # 0 just low .. 1 flat
	if noise > 0.35 - failing * 0.6:
		return 0.12
	return 0.85 + 0.15 * sin(t * 40.0)


## The spine lights down a suit's back (GDD §10) tell the crew how its wearer is: green, amber,
## then red and blinking as health falls; dark, dead.
func _light_spine() -> void:
	if _spine_material == null:
		return
	var colour := Color(0.3, 1.0, 0.45)
	if health <= 0.0:
		colour = Color(0.04, 0.05, 0.04)
	elif health < 0.3:
		colour = Color(1.0, 0.25, 0.15) if fmod(Time.get_ticks_msec() / 1000.0, 0.6) < 0.35 else Color(0.25, 0.06, 0.04)
	elif health < 0.6:
		colour = Color(1.0, 0.7, 0.2)
	_spine_material.set_shader_parameter("albedo", colour)


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
	if swings != _swings_seen:
		_swings_seen = swings
		_animation.swing()
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


## What a crew member sounds like (GDD §15), on every peer: a footfall at each heel strike of the
## stride while on the ground, a thump coming down from a jump or a fall, and the helmet lamp's
## switch (not when it goes out flat).
func _make_sounds() -> void:
	var footfalls := floori(_stride * 2.0)
	if footfalls != _footfalls:
		_footfalls = footfalls
		if grounded:
			Sound.footstep(self)
	if grounded and not _was_grounded and _fall >= LAND_SPEED:
		Sound.landing(self)
	_was_grounded = grounded
	_fall = 0.0 if grounded else -velocity.y
	if lamp_on != _lamp_heard:
		_lamp_heard = lamp_on
		if lamp_on or battery > 0.0:
			Sound.lamp_switch(self, lamp_on)
