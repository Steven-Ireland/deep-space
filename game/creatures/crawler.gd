class_name Crawler
extends Creature
## THE CRAWLER (GDD §12): the sound hunter. Eyeless, on all fours, maybe once crew. It hears what
## the crew do (Noises) and nothing they don't: a lamp beam means nothing to it, and a crew member
## standing still is nowhere until it's close enough to feel them (FEEL). What it does (`mode`):
##   wait     still in the dark, clicking; now and then it ambles somewhere near (prowl)
##   prowl    ambling
##   listen   gone to where it heard something, head sweeping; a flare's hiss holds it there
##   hunt     after a crew member it heard, fast, to where it last heard them
##   lunge    springs at them from a few metres
##   swipe    a blow from in front; from behind, a grab: the end of them (`grab`)
##   recover  a moment after a lunge or a blow, open to theirs
##   bang     beating at a shut door between it and them: it can't open one
##   stunned  jolted by a shock prod, down and twitching
##   dead     struck down, or crushed in a door shut on it
## Two of its blows kill (GDD §12); five from a crowbar kill it, if the crew can land them.

## Speeds (m/s): ambling, going to a noise, hunting (a walk can't outpace it; a sprint can), and
## how fast it turns (radians a second). Its crawl's stride: metres a cycle of the clip.
const PROWL_SPEED := 0.7
const LISTEN_SPEED := 1.5
const HUNT_SPEED := 3.4
const TURN := 6.0
const STRIDE := 0.67
## Crew within this (metres, on its own deck) are felt, whatever noise they make or don't.
const FEEL := 1.7
## A crew member's noise at least this loud (0..1, Creature.hear) sets it hunting; quieter, it goes
## to listen, and hunts if it hears them again.
const HUNT_LEVEL := 0.5
## Hunting: it springs from LUNGE_NEAR to LUNGE_FAR metres when it heard its prey within LUNGE_HEARD
## seconds and its run is clear; the clip carries it LUNGE_REACH metres, its jaws biting LUNGE_HIT
## seconds in, anything within BITE of them. Nearer than SWIPE, it strikes (SWIPE_HIT seconds in,
## at anything within SWIPE_REACH in front); from behind (facing away past BEHIND), it grabs.
const LUNGE_FAR := 3.0
const LUNGE_NEAR := 2.2
const LUNGE_HEARD := 0.8
const LUNGE_TIME := 0.7
const LUNGE_REACH := 1.6
const LUNGE_HIT := 0.48
const BITE := 0.9
const SWIPE := 1.6
const SWIPE_TIME := 0.5
const SWIPE_HIT := 0.25
const SWIPE_REACH := 1.9
const BEHIND := -0.25
## A blow takes this much of a crew member's health: two kill.
const WOUND := 0.5
## Seconds it stands open after a lunge, and after a blow.
const LUNGE_RECOVER := 1.4
const SWIPE_RECOVER := 0.8
## How long a shock prod's jolt keeps it down; a blow that lands while it winds up a strike stops
## it, no more than once in FLINCH_GAP seconds.
const STUN := 5.0
const FLINCH_GAP := 1.5
## Hunting with nothing heard of its prey for LOST seconds, at the last place it heard them, it
## searches there (listen) for SEARCH seconds, then gives up. At a shut door it beats on it for
## BANG seconds, a blow every BANG_EVERY.
const LOST := 2.5
const SEARCH := 5.0
const BANG := 5.0
const BANG_EVERY := 0.7
## Waiting, it stirs after WAIT seconds (a range), and ambles up to PROWL metres.
const WAIT := Vector2(12.0, 35.0)
const PROWL := 8.0
## Its jaws, in its own space (it faces +Z), and how its body sits: the model's middle on its
## origin, so it turns about its middle.
const JAWS := Vector3(0.0, 0.55, 0.85)
const MODEL_BACK := -0.2
## Where a move's got to (`_go`).
enum { MOVING, THERE, NO_WAY }

## Host: who it's after and where it last heard them (its derelict's space), how loud, and how long
## ago; where it's going and the way there; the time left in what it's doing.
var prey: Player
var prey_at := Vector3.ZERO
var _prey_level := 0.0
var _since_heard := 0.0
var _goal := Vector3.ZERO
var _route := PackedVector3Array()
var _route_goal := Vector3(INF, INF, INF)
var _route_age := 0.0
var _left := 0.0
var _struck_yet := false
var _lured := false # listening to a flare
var _flinched := 0.0
var _feel_in := 0.0
var _rng := RandomNumberGenerator.new()
var _door: Door
## What it sounds like, on every peer.
var _mode_heard := &""
var _acts_heard := 0
var _gait := 0.0
var _click_in := 3.0


func kind() -> StringName:
	return &"crawler"


func listens() -> bool:
	return true


func _setup() -> void:
	model.position.z = MODEL_BACK
	collision_layer = LAYER
	collision_mask = 1 | 2 # the world, and crew: it stops against them, never in them
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var body := CollisionShape3D.new()
	body.name = "Shape"
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.32
	cylinder.height = 0.8
	body.shape = cylinder
	body.position = Vector3(0, 0.5, 0)
	add_child(body)
	# What a swing strikes: its whole length, head to haunches.
	var hitbox := StaticBody3D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = HITBOX
	hitbox.collision_mask = 0
	var box := CollisionShape3D.new()
	var size := BoxShape3D.new()
	size.size = Vector3(0.7, 0.85, 1.75)
	box.shape = size
	box.position = Vector3(0, 0.45, 0.05)
	hitbox.add_child(box)
	add_child(hitbox)
	mode = &"wait"
	_rng.seed = hash([derelict.layout.seed if derelict != null and derelict.layout != null else 0, index, "crawler"])
	_left = _rng.randf_range(WAIT.x, WAIT.y)


# --- Thinking (host) ---------------------------------------------------------------------------

func _think(delta: float) -> void:
	if not alive():
		velocity = Vector3.ZERO
		return
	_since_heard += delta
	_flinched = maxf(0.0, _flinched - delta)
	_left -= delta
	_route_age += delta
	if _crushed():
		return
	_feel(delta)
	match mode:
		&"wait":
			loop(&"idle")
			if _left <= 0.0:
				_goal = derelict.nav().wander_point(position, PROWL, _rng)
				_set_mode(&"prowl")
		&"prowl":
			if _go(delta, PROWL_SPEED) != MOVING:
				_rest()
		&"listen":
			if _go(delta, LISTEN_SPEED) != MOVING:
				loop(&"investigate")
				if _left <= 0.0:
					_lured = false
					_rest()
			else:
				_left = SEARCH
		&"hunt":
			_hunt(delta)
		&"lunge":
			_lunge()
		&"swipe":
			_swipe()
		&"bang":
			_bang(delta)
		&"recover", &"stunned":
			if mode == &"stunned":
				loop(&"stunned")
			else:
				loop(&"idle")
			if _left <= 0.0:
				_set_mode(&"hunt" if prey != null and not prey.dead else &"listen")
				_left = SEARCH
				_goal = prey_at if prey != null else position


func _set_mode(next: StringName) -> void:
	mode = next
	_route_goal = Vector3(INF, INF, INF)


## Back to waiting where it is.
func _rest() -> void:
	prey = null
	_set_mode(&"wait")
	_left = _rng.randf_range(WAIT.x, WAIT.y)
	velocity = Vector3.ZERO


func _hunt(delta: float) -> void:
	if prey == null or prey.dead or not is_instance_valid(prey):
		prey = null
		_search(prey_at)
		return
	var flat := _flat(prey_at - position)
	var heard_now := _since_heard < LUNGE_HEARD
	if flat.length() < SWIPE and heard_now:
		_strike()
		return
	if heard_now and flat.length() >= LUNGE_NEAR and flat.length() <= LUNGE_FAR and _clear_run(flat):
		_spring(flat)
		return
	_goal = prey_at
	var got := _go(delta, HUNT_SPEED)
	if got == NO_WAY:
		var door := derelict.nav().door_between(position, prey_at)
		if not door.is_empty():
			_door = door[0]
			_goal = door[1]
			_set_mode(&"bang")
			_left = BANG
			return
		_search(position)
		return
	if got == THERE and _since_heard > LOST:
		_search(prey_at)


## Goes to look round `at`, listening, for SEARCH seconds.
func _search(at: Vector3) -> void:
	_goal = at
	_set_mode(&"listen")
	_left = SEARCH


func _spring(towards: Vector3) -> void:
	_face(towards, INF)
	velocity = Vector3.ZERO
	_set_mode(&"lunge")
	act(&"lunge")
	_left = LUNGE_TIME
	_struck_yet = false


func _lunge() -> void:
	var into := LUNGE_TIME - _left
	if not _struck_yet and into >= LUNGE_HIT:
		# Its jaws, where the spring has carried them by now (the clip's: coiled for its first 35%,
		# then springing): the first crew member they meet is bitten.
		var spring := clampf((into / LUNGE_TIME - 0.35) / 0.65, 0.0, 1.0)
		var jaws := position + _forward() * (LUNGE_REACH * spring) + Basis(Vector3.UP, yaw) * JAWS
		var victim := _nearest_to(_flat(jaws), BITE)
		if victim != null:
			_struck_yet = true
			victim.hurt.rpc_id(victim.get_multiplayer_authority(), WOUND, &"crawler")
	if _left <= 0.0:
		# The clip's spring carried its body ahead: it lands there (short of anything solid).
		var landed := derelict.global_basis * (_forward() * LUNGE_REACH)
		move_and_collide(landed)
		position.y = 0.0
		act(&"idle")
		_set_mode(&"recover")
		_left = LUNGE_RECOVER


func _strike() -> void:
	velocity = Vector3.ZERO
	_face(_flat(prey_at - position), INF)
	_set_mode(&"swipe")
	act(&"attack")
	_left = SWIPE_TIME
	_struck_yet = false


func _swipe() -> void:
	if not _struck_yet and SWIPE_TIME - _left >= SWIPE_HIT:
		_struck_yet = true
		var victim := _nearest_to(position, SWIPE_REACH, true)
		if victim != null:
			# Its back to it: a grab, and the end of them. Facing it: a blow.
			var facing := -Basis(Vector3.UP, victim.look.x).z
			var to_it := (global_position - victim.global_position)
			to_it.y = 0.0
			var grab := facing.dot(to_it.normalized()) < BEHIND
			victim.hurt.rpc_id(victim.get_multiplayer_authority(), 1.0 if grab else WOUND, &"grabbed" if grab else &"crawler")
	if _left <= 0.0:
		_set_mode(&"recover")
		_left = SWIPE_RECOVER


func _bang(delta: float) -> void:
	if _door == null or not is_instance_valid(_door) or _door.open or _left <= 0.0:
		_door = null
		_search(position)
		return
	if _go(delta, HUNT_SPEED) == MOVING:
		return
	_face(_flat(_door.position - position), delta)
	if fmod(_left, BANG_EVERY) < delta:
		act(&"attack", 1.4)
		Noises.make(self, global_position, &"bang", self)


## Moves toward `_goal` at `speed` along the way through the rooms: MOVING, THERE, or NO_WAY (there's
## no way there on foot).
func _go(delta: float, speed: float) -> int:
	var nav := derelict.nav()
	if _goal.distance_to(_route_goal) > 0.75 or _route_age > 1.0:
		_route = nav.path(position, _goal)
		_route_goal = _goal
		_route_age = 0.0
	while not _route.is_empty() and _flat(_route[0] - position).length() < 0.3:
		_route.remove_at(0)
	if _route.is_empty():
		velocity = Vector3.ZERO
		if mode != &"listen":
			loop(&"idle")
		if _flat(_goal - position).length() < 0.6:
			return THERE
		return NO_WAY if nav.path(position, _goal).is_empty() else THERE
	var way := _flat(_route[0] - position)
	_face(way, delta)
	var ahead := clampf(_forward().dot(way.normalized()), 0.15, 1.0)
	var local := way.normalized() * speed * ahead
	velocity = derelict.global_basis * local
	move_and_slide()
	position.y = 0.0
	loop(&"crawl", maxf(0.4, speed * ahead / STRIDE))
	return MOVING


## Turns toward `way` (its derelict's space), at TURN radians a second (or at once, `delta` INF).
func _face(way: Vector3, delta: float) -> void:
	if way.length() < 0.01:
		return
	var wanted := atan2(way.x, way.z)
	var turn := wrapf(wanted - yaw, -PI, PI)
	yaw = wrapf(yaw + clampf(turn, -TURN * delta, TURN * delta) if delta != INF else wanted, -PI, PI)


func _forward() -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Whether its lunge has a clear run along `way` (nothing solid in its path, LUNGE_REACH and more).
func _clear_run(way: Vector3) -> bool:
	var from := derelict.to_global(position + Vector3.UP * 0.5)
	var to := derelict.to_global(position + Vector3.UP * 0.5 + way.normalized() * (LUNGE_REACH + 0.6))
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## The living crew member nearest `at` (its derelict's space) within `reach`, `ahead` of it only if
## asked; or null.
func _nearest_to(at: Vector3, reach: float, ahead := false) -> Player:
	var best: Player = null
	var best_distance := reach
	for player in crew_aboard():
		var off := _flat(derelict.to_local(player.global_position) - at)
		if ahead and off.length() > 0.3 and _forward().dot(off.normalized()) < 0.2:
			continue
		if off.length() < best_distance:
			best_distance = off.length()
			best = player
	return best


## Crew close by are felt, noise or none: as if heard, as loud as can be.
func _feel(delta: float) -> void:
	_feel_in -= delta
	if _feel_in > 0.0 or mode in [&"stunned", &"lunge", &"swipe"]:
		return
	_feel_in = 0.2
	for player in crew_aboard():
		var at := derelict.to_local(player.global_position)
		if _flat(at - position).length() < FEEL:
			_heard(at, 1.0, &"felt", player)


## Shut in a door: a door shutting on it while it's in the doorway crushes it.
func _crushed() -> bool:
	for door: Door in derelict.doors.values():
		if door.open or door.blocker.disabled:
			continue
		var off := position - door.position
		if absf(off.dot(door.transform.basis.x)) < 0.9 and absf(off.dot(door.transform.basis.z)) < 0.35:
			_die()
			return true
	return false


func _die() -> void:
	health = 0.0
	velocity = Vector3.ZERO
	_set_mode(&"dead")
	act(&"death")
	collision_layer = 0
	$Hitbox.collision_layer = 0
	print("Crawler %s: dead." % name)


# --- Senses (host) -----------------------------------------------------------------------------

func _heard(from: Vector3, level: float, what: StringName, source: Player) -> void:
	if mode in [&"dead", &"stunned"]:
		return
	if source == null or source.dead:
		# A noise with no one behind it: a door, something landing, a flare's hiss. Hunting, it
		# pays it no mind; otherwise it goes to listen, and a flare holds it.
		if mode in [&"wait", &"prowl", &"listen"] and (what == &"flare" or not _lured):
			_lured = what == &"flare"
			_search(from)
		return
	if mode in [&"hunt", &"bang", &"lunge", &"swipe", &"recover"]:
		if source == prey:
			prey_at = from
			_prey_level = level
			_since_heard = 0.0
			if mode == &"bang" and _door != null and derelict.nav().door_between(position, prey_at).is_empty():
				_set_mode(&"hunt")
		elif prey == null or _since_heard > LOST or level > _prey_level + 0.25:
			_chase(source, from, level)
		return
	if mode == &"listen" and _lured and level < HUNT_LEVEL:
		return
	if level >= HUNT_LEVEL or mode == &"listen":
		_chase(source, from, level)
	else:
		_search(from)


## Hunts `who` as if it had just heard them where they stand (Dev: --provoke).
func provoke(who: Player) -> void:
	_chase(who, derelict.to_local(who.global_position), 1.0)


## Hunts `who`, heard at `from`, `level` loud.
func _chase(who: Player, from: Vector3, level: float) -> void:
	if mode != &"hunt":
		print("Crawler %s: hunting %s." % [name, who.crew_name()])
	prey = who
	prey_at = from
	_prey_level = level
	_since_heard = 0.0
	_lured = false
	if mode in [&"wait", &"prowl", &"listen", &"bang"]:
		_set_mode(&"hunt")


# --- Struck (host) -----------------------------------------------------------------------------

func struck(damage: float, jolt: bool, by: Player) -> void:
	health = maxf(0.0, health - damage)
	if health < 0.01:
		_die()
		return
	if by != null and not by.dead:
		# Whoever struck it, it knows where they are.
		prey = by
		prey_at = derelict.to_local(by.global_position)
		_since_heard = 0.0
	if jolt:
		velocity = Vector3.ZERO
		_set_mode(&"stunned")
		act(&"stunned")
		_left = STUN
		return
	if mode == &"swipe" and not _struck_yet and _flinched <= 0.0:
		# Struck while it winds up: the blow never comes.
		_flinched = FLINCH_GAP
		_set_mode(&"recover")
		act(&"hurt")
		_left = SWIPE_RECOVER
		return
	if mode in [&"wait", &"prowl", &"listen"]:
		_set_mode(&"hunt")


# --- What it sounds like (every peer) ------------------------------------------------------------

func _sounds(delta: float) -> void:
	if mode != _mode_heard:
		var was := _mode_heard
		_mode_heard = mode
		match mode:
			&"hunt":
				if was in [&"", &"wait", &"prowl", &"listen"]:
					Sound.creature(self, &"crawler_shriek")
			&"dead":
				Sound.creature(self, &"crawler_death")
			&"stunned":
				Sound.creature(self, &"crawler_stunned")
	if acts != _acts_heard:
		_acts_heard = acts
		match clip:
			&"lunge":
				Sound.creature(self, &"crawler_lunge")
			&"attack":
				Sound.creature(self, &"crawler_bang" if mode == &"bang" else &"crawler_snarl")
			&"hurt":
				Sound.creature(self, &"crawler_hurt")
	if clip == &"crawl":
		_gait += delta * clip_speed * 2.0
		if _gait >= 1.0:
			_gait = fmod(_gait, 1.0)
			Sound.creature(self, &"crawler_step")
	if mode in [&"wait", &"listen", &"prowl"]:
		_click_in -= delta
		if _click_in <= 0.0:
			_click_in = randf_range(2.5, 6.0)
			Sound.creature(self, &"crawler_click")
