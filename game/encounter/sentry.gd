class_name Sentry
extends Node3D
## A security sentry (art/blender/events.py: dk_sentry; GDD §8.3), hung from a derelict's ceiling
## in its Prize's section. Folded and dark until the security system wakes (`wake`); then its head
## swings down, its eye lights and its beam sweeps the room. Whoever it sees within RANGE it turns
## to and paints with its sight for LOCK_TIME, then fires a BURST at them (each shot that finds
## them: SHOT of their health, "shot"), again and again while they're in its sight. It stands down
## (`stand_down`) when the lockdown lifts; knocked out (struck BLOWS times with a crowbar, or once
## with a prod's jolt) its head hangs and it sparks.
##
## The host decides all of it (who it sees, the shots, the blows) and tells everyone (`_show`,
## `_shot`); every peer turns its head after its target on its own, so it moves smoothly
## everywhere.

const RANGE := 14.0
const LOCK_TIME := 0.9
const BURST := 3
const SHOT_GAP := 0.13
const COOLDOWN := 1.1
## Seconds it keeps after someone it's lost before it sweeps again.
const LOST := 1.6
const SHOT := 0.1
## How hard a crowbar's blow knocks it (a share of its working), and how many from new.
const BLOW := 0.34
## How fast it turns (radians a second), and its head's rest pitch, folded pitch and slumped pitch
## (radians, down positive).
const TURN := 2.6
const REST_PITCH := 0.35
const FOLDED_PITCH := -1.05
const SLUMPED_PITCH := 0.75
const WAKE_TIME := 1.2
## Its sweep while it watches: how far either way it looks, and how fast.
const SWEEP := 0.9
const SWEEP_RATE := 0.55
const LAMP_RED := preload("res://assets/materials/lk_lamp_sealed.tres")
const LAMP_DEAD := preload("res://assets/materials/lk_lamp_dead.tres")
const BEAM_COLOUR := Color(1.0, 0.12, 0.08)
## The crew's physics layer (its sight stops on them).
const CREW_LAYER := 2

## What it's doing (host's, shown everywhere): &"folded", &"watch", &"lock", &"fire", &"down".
var state := &"folded"
## Its target's peer (0 none).
var target := 0
var health := 1.0

var _yaw_node: Node3D
var _head: Node3D
var _eye: MeshInstance3D
var _muzzle: Node3D
var _beam: SpotLight3D
var _sight: MeshInstance3D
var _flash: OmniLight3D
var _sparks: CPUParticles3D
var _yaw := 0.0
var _pitch := FOLDED_PITCH
var _time := 0.0
var _woke_at := -1.0
var _phase := 0.0
## Host: how long it's had its target in sight, since it last saw them, till its next shot, shots
## left in the burst.
var _seen := 0.0
var _unseen := 0.0
var _next := 0.0
var _shots := 0
var _flash_left := 0.0


## A sentry fitted to `prop` (a dk_sentry).
static func fit(prop: Node3D, number: int) -> Sentry:
	var sentry := Sentry.new()
	sentry.name = "Sentry%d" % number
	prop.add_child(sentry)
	return sentry


## The sentry a collider belongs to (its hitbox), or null.
static func of(collider: Object) -> Sentry:
	return collider.get_meta(&"sentry") as Sentry if collider != null and collider.has_meta(&"sentry") else null


func _ready() -> void:
	var prop := get_parent() as Node3D
	_phase = float(absi(hash(name)) % 1000) / 1000.0 * TAU
	var mount := prop.find_child("dk_sentry", true, false) as Node3D
	var yaw_part := prop.find_child("sentry_yaw", true, false) as Node3D
	var head_part := prop.find_child("sentry_head", true, false) as Node3D
	_eye = prop.find_child("sentry_eye", true, false) as MeshInstance3D
	var pivot := prop.find_child("SOCKET_pitch", true, false) as Node3D
	var muzzle := prop.find_child("SOCKET_muzzle", true, false) as Node3D
	if mount == null or yaw_part == null or head_part == null or pivot == null:
		push_error("Sentry: %s lacks its parts." % prop.name)
		return
	# Rebuild it as a little rig: a yaw node at the origin carrying the yoke, and a head node at
	# the pitch pivot carrying the head, its eye and its muzzle.
	_yaw_node = Node3D.new()
	_yaw_node.name = "Yaw"
	prop.add_child(_yaw_node)
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = pivot.position
	_yaw_node.add_child(_head)
	yaw_part.reparent(_yaw_node, false)
	for part: Node3D in [head_part, _eye]:
		if part != null:
			part.reparent(_head, false)
			part.position -= pivot.position
	_muzzle = Node3D.new()
	_head.add_child(_muzzle)
	_muzzle.position = (muzzle.position if muzzle != null else Vector3(0, pivot.position.y, 0.38)) - pivot.position
	if _eye != null:
		_eye.material_override = LAMP_DEAD
	# Its beam, its sight, its muzzle flash.
	_beam = SpotLight3D.new()
	_beam.light_color = BEAM_COLOUR
	_beam.spot_range = RANGE
	_beam.spot_angle = 13.0
	_beam.light_energy = 0.0
	_beam.light_cull_mask = ~Deck.HULL_LAYER
	_beam.position = Vector3(0, 0.035, 0.2)
	_beam.rotation.y = PI # a spot shines down its -Z; the head looks down +Z
	_head.add_child(_beam)
	_sight = MeshInstance3D.new()
	var line := BoxMesh.new()
	line.size = Vector3(0.006, 0.006, 1.0)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(1.0, 0.15, 0.1, 0.8)
	line.material = glow
	_sight.mesh = line
	_sight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sight.visible = false
	_sight.top_level = true
	add_child(_sight)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.75, 0.45)
	_flash.omni_range = 5.0
	_flash.light_energy = 0.0
	_flash.light_cull_mask = ~Deck.HULL_LAYER
	_muzzle.add_child(_flash)
	# What a swing strikes: a box round its head.
	var hitbox := StaticBody3D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = Creature.HITBOX
	hitbox.collision_mask = 0
	hitbox.set_meta(&"sentry", self)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.38, 0.34, 0.5)
	shape.shape = box
	hitbox.add_child(shape)
	_head.add_child(hitbox)
	hitbox.position = Vector3(0, 0, 0.04)
	_pose()


## Host: the security system's awake: it unfolds and starts watching.
func wake() -> void:
	if state == &"folded":
		_show.rpc(&"watch", 0)


## Host: the lockdown's lifted: it folds away (unless it's been knocked out).
func stand_down() -> void:
	if state != &"down" and state != &"folded":
		_show.rpc(&"folded", 0)


## Whether it's awake and dangerous.
func live() -> bool:
	return state in [&"watch", &"lock", &"fire"]


func _process(delta: float) -> void:
	if _head == null:
		return
	_time += delta
	if multiplayer.is_server() and live() and _time - _woke_at > WAKE_TIME:
		_think(delta)
	_aim(delta)
	_pose()
	_show_sight()
	_flash_left = maxf(0.0, _flash_left - delta)
	_flash.light_energy = 3.0 * _flash_left / 0.06


# --- What it does (host) ---------------------------------------------------------------------

func _think(delta: float) -> void:
	var prey := Player.of_peer(get_tree(), target) if target != 0 else null
	if prey != null and (prey.dead or not _sees(prey)):
		_unseen += delta
		_seen = 0.0
		if _unseen > LOST:
			_show.rpc(&"watch", 0)
		return
	if prey == null:
		var nearest := _nearest_seen()
		if nearest != null:
			_unseen = 0.0
			_seen = 0.0
			_show.rpc(&"lock", int(str(nearest.name)))
			Noises.make(self, global_position, &"buzz")
		return
	_unseen = 0.0
	_seen += delta
	match state:
		&"lock":
			if _seen >= LOCK_TIME and _facing(prey):
				_shots = BURST
				_next = 0.0
				_show.rpc(&"fire", target)
		&"fire":
			_next -= delta
			if _next <= 0.0 and _shots > 0:
				_shots -= 1
				_next = SHOT_GAP
				_fire(prey)
			elif _shots <= 0 and _next <= -COOLDOWN:
				_seen = LOCK_TIME * 0.5
				_show.rpc(&"lock", target)


## Whether it can see `crew`: within RANGE, nothing solid between its muzzle and their chest.
func _sees(crew: Player) -> bool:
	var chest := crew.global_position + Vector3.UP * Player.CHEST_HEIGHT
	var from := _head.global_position
	if from.distance_to(chest) > RANGE:
		return false
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, chest, 1))
	return hit.is_empty()


func _nearest_seen() -> Player:
	var best: Player = null
	for crew: Player in get_tree().get_nodes_in_group(&"crew"):
		if not crew.dead and _sees(crew) and (best == null or _distance(crew) < _distance(best)):
			best = crew
	return best


func _distance(crew: Player) -> float:
	return crew.global_position.distance_to(global_position)


## Whether its head's turned onto `crew` (near enough to shoot).
func _facing(crew: Player) -> bool:
	var to := (crew.global_position + Vector3.UP * Player.CHEST_HEIGHT) - _muzzle.global_position
	return _head.global_basis.z.angle_to(to) < 0.12


## A shot at `crew`: it finds them if they're still in its sight.
func _fire(crew: Player) -> void:
	var chest := crew.global_position + Vector3.UP * Player.CHEST_HEIGHT
	var hit := _sees(crew)
	var at := chest
	if not hit:
		var ray := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(_muzzle.global_position, chest, 1))
		at = ray.position if not ray.is_empty() else chest
	_shot.rpc(at, hit)
	Noises.make(self, global_position, &"alarm")
	if hit:
		crew.hurt.rpc_id(crew.get_multiplayer_authority(), SHOT, &"shot")


## On the host, from a crew member's machine: their swing struck it with a `kind` of tool (`jolt`:
## a prod with charge left).
func strike(kind: StringName, jolt: bool) -> void:
	_struck.rpc_id(1, kind, jolt)


@rpc("any_peer", "call_local", "reliable")
func _struck(kind: StringName, jolt: bool) -> void:
	if not multiplayer.is_server() or state == &"down":
		return
	_clang.rpc()
	if jolt:
		health = 0.0
	else:
		health -= BLOW if kind == &"crowbar" else BLOW * 0.4
	if health <= 0.0:
		_show.rpc(&"down", 0)
	elif live() and target == 0:
		# Struck from under it: it turns on whoever did it.
		var peer := multiplayer.get_remote_sender_id()
		_show.rpc(&"lock", 1 if peer == 0 else peer)


# --- Shown everywhere ------------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _show(next: StringName, peer: int) -> void:
	var was := state
	state = next
	target = peer
	if was == &"folded" and live():
		_woke_at = _time
		Sound.event(&"sentry_wake", self)
	elif next == &"lock" and was != &"fire":
		Sound.event(&"sentry_lock", self)
	elif next == &"down" and was != &"down":
		Sound.event(&"sentry_down", self)
		_sparks = Effects.sparks()
		_head.add_child(_sparks)
		_sparks.emitting = true
		get_tree().create_timer(2.5).timeout.connect(func():
			if is_instance_valid(_sparks):
				_sparks.emitting = false)
	if _eye != null:
		_eye.material_override = LAMP_RED if live() else LAMP_DEAD


@rpc("authority", "call_local", "reliable")
func _shot(at: Vector3, hit: bool) -> void:
	Sound.event(&"sentry_fire", self)
	_flash_left = 0.06
	var tracer := MeshInstance3D.new()
	var line := BoxMesh.new()
	var from := _muzzle.global_position
	line.size = Vector3(0.012, 0.012, from.distance_to(at))
	line.material = (_sight.mesh as BoxMesh).material.duplicate()
	(line.material as StandardMaterial3D).albedo_color = Color(1.0, 0.8, 0.5, 0.9)
	tracer.mesh = line
	tracer.top_level = true
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tracer)
	tracer.global_transform = _line(from, at)
	get_tree().create_timer(0.05).timeout.connect(tracer.queue_free)
	if not hit:
		var sparks := Effects.sparks()
		sparks.one_shot = true
		sparks.amount = 10
		get_parent().add_child(sparks)
		sparks.global_position = at
		sparks.emitting = true
		get_tree().create_timer(1.0).timeout.connect(sparks.queue_free)


@rpc("authority", "call_local", "reliable")
func _clang() -> void:
	Sound.event(&"sentry_hit", self)


## Turns its head after what it's doing: folded, up against the ceiling; watching, sweeping;
## locked on or firing, after its target; down, hanging.
func _aim(delta: float) -> void:
	var yaw_goal := _yaw
	var pitch_goal := _pitch
	var turn := TURN
	match state:
		&"folded":
			pitch_goal = FOLDED_PITCH
			turn = 1.5
		&"down":
			pitch_goal = SLUMPED_PITCH
			turn = 4.0
		&"watch":
			yaw_goal = sin(_time * SWEEP_RATE + _phase) * SWEEP
			pitch_goal = REST_PITCH
			turn = 1.2 if _time - _woke_at > WAKE_TIME else 3.0
		_:
			var prey := Player.of_peer(get_tree(), target)
			if prey != null:
				var to := global_transform.affine_inverse() * (prey.global_position + Vector3.UP * Player.CHEST_HEIGHT) - _head.position
				yaw_goal = atan2(to.x, to.z)
				pitch_goal = atan2(-to.y, Vector2(to.x, to.z).length())
	_yaw = _yaw + clampf(angle_difference(_yaw, yaw_goal), -turn * delta, turn * delta)
	_pitch = move_toward(_pitch, pitch_goal, turn * delta)


func _pose() -> void:
	if _yaw_node == null:
		return
	_yaw_node.rotation = Vector3(0, _yaw, 0)
	_head.rotation = Vector3(_pitch, 0, 0)
	var awake := live()
	_beam.light_energy = move_toward(_beam.light_energy, (2.4 if state != &"fire" else 3.2) if awake else 0.0, 0.2)


## Its sight: a red line from its eye to whatever's in front of it, while it's locked on.
func _show_sight() -> void:
	var showing := state == &"lock" and fmod(_time * 10.0, 1.0) < 0.8
	_sight.visible = showing
	if not showing:
		return
	var from := _muzzle.global_position
	var ahead := from + _head.global_basis.z * RANGE
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, ahead, 1 | CREW_LAYER))
	var to: Vector3 = hit.position if not hit.is_empty() else ahead
	(_sight.mesh as BoxMesh).size.z = maxf(0.01, from.distance_to(to))
	_sight.global_transform = _line(from, to)


## The transform that stretches a unit box along Z from `from` to `to`.
static func _line(from: Vector3, to: Vector3) -> Transform3D:
	var along := to - from
	var basis := Basis.looking_at(along.normalized(), Vector3.UP if absf(along.normalized().y) < 0.99 else Vector3.RIGHT)
	return Transform3D(basis, (from + to) / 2.0)
