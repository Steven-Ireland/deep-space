class_name PrizeEvent
extends Node3D
## What taking a derelict's Prize sets off (GDD §8.3), as its plan rolled it (DerelictLayout.event).
## Often nothing. Otherwise, START after the Prize leaves its cradle:
##   security  the alarm: beacons by the doors out of the Prize's section turn, those doors lock
##             down (LOCKDOWN: a crowbar forces one, slowly and loudly: DoorPanel), the section's
##             sentries wake (Sentry), and the noise carries to anything listening; the system
##             stands down LOCKDOWN_TIME later
##   vent      the seal the Prize was part of fails: hissing, and SEAL_WARNING later the wall by its
##             cradle blows out. The air goes after it: a gale toward the hole through the rooms
##             that held it, stripping O2 from suits and wearing them, dragging loose things, and
##             at the hole itself, out into space ("spaced"); the doors round those rooms slam and
##             stay sealed till it's spent (VENT_TIME); then they're vacuum like the rest
##   collapse  the structure gives: the deck shakes, debris comes down on the way back (each fall
##             warned by a trickle of dust first; under it, "crushed"), and a door on the way back
##             buckles shut under a heap of fallen ceiling, so the way back is another way
##   nest      the nest outside the Prize's room swells and bursts, and a Crawler comes out of it
##             after whoever took the Prize
## The host starts it (Derelict.prize_taken) and tells everyone (`_begin`); each peer plays it out on
## its own clock from there. The host decides what matters (doors, blows, the creature); each crew
## member's own machine what the gale does to them (`buffet`). Everyone feels it shake
## (`shake_for`).

const START := 1.2
const LOCKDOWN_TIME := 75.0
const SENTRY_WAKE := 1.6
const ALARM_EVERY := 5.0
const SEAL_WARNING := 3.0
const VENT_TIME := 10.0
## The gale: how fast it carries someone at the hole (m/s), and how far from it it still reaches;
## seconds of O2 it strips from a suit a second, and how hard it wears one; how near the hole is
## out of it.
const GALE_DRIFT := 2.6
const GALE_REACH := 10.0
const GALE_O2 := 6.0
const GALE_WEAR := 0.06
const SPACED := 1.2
## Debris: the first fall, the gap between falls, the dust's warning, the drop; how near a fall
## crushes, and how badly. The door buckles BUCKLE_AT in, its heap warned HEAP_WARN before.
const FIRST_FALL := 0.8
const FALL_EVERY := 1.7
const WARN := 1.3
const DROP := 0.45
const CRUSH_REACH := 0.95
const CRUSH := 0.6
const BUCKLE_AT := 2.6
const HEAP_WARN := 1.8
const HEAP_DROP := 0.55
const NEST_SWELL := 2.6
## The Crawler that hatches: its number among the derelict's creatures (past any in the plan).
const HATCHLING := 100

const DEBRIS := preload("res://assets/models/derelict/dk_debris.glb")
const HEAP := preload("res://assets/models/derelict/dk_heap.glb")
const BLOWOUT := preload("res://assets/models/derelict/dk_wall_blowout.glb")

var derelict: Derelict
var layout: DerelictLayout
var kind := &""
var begun := false
## Seconds since it began, and who took the Prize (their peer; 0 unknown).
var elapsed := 0.0
var carrier := 0

var sentries: Array[Sentry] = []
var beacons: Array[AlarmBeacon] = []
var _done := {}
var _speaker: Node3D
var _nest: Node3D
var _sac: Node3D
var _hole := Vector3.ZERO
var _into := Vector3.ZERO
var _sealed := {}
var _gale := 0.0
var _gust: CPUParticles3D
var _hiss: Array[CPUParticles3D] = []
var _shake := 0.0
var _alarm_in := 0.0
var _push_in := 0.0
var _time := 0.0


func _ready() -> void:
	name = "PrizeEvent"
	add_to_group(&"prize_events")
	derelict = get_parent() as Derelict
	layout = derelict.layout
	kind = layout.event
	if layout.prize >= 0:
		_speaker = Node3D.new()
		_speaker.position = layout.centre_of(layout.rooms[layout.prize].cells[0]) + Vector3.UP * 1.0
		add_child(_speaker)
	match kind:
		&"security":
			var posts: Array = derelict.fixtures.get("sentry", [])
			for i in posts.size():
				sentries.append(Sentry.fit(posts[i], i))
			for key: String in layout.lockdown:
				_hang_beacons(RoomLayout.deck_key(key))
		&"nest":
			var nests: Array = derelict.fixtures.get("nest", [])
			if not nests.is_empty():
				_nest = nests[0]
				_sac = _nest.find_child("nest_sac", true, false) as Node3D
		&"vent":
			for index in layout.sealed:
				_sealed[index] = true
				for cell: Vector3i in layout.rooms[index].cells:
					var zone: Zone = derelict.zones.get(Vector2i(cell.x, cell.z))
					if zone != null:
						zone.pressurized = true
			var join := _edge(layout.blowout)
			_hole = join[0] + Vector3.UP * 1.3
			_into = join[1]
	NetworkEvents.on_peer_join.connect(func(peer: int):
		if multiplayer.is_server() and begun:
			_begin.rpc_id(peer, carrier, elapsed))
	if Args.flag("--prize-taken") and multiplayer.is_server():
		get_tree().create_timer(float(Args.value("--prize-taken", "2"))).timeout.connect(func():
			derelict.prize_taken(Player.local(get_tree())))


## Host: the Prize is gone from its cradle, taken by `by`.
func begin(by: Player) -> void:
	if begun or kind == &"":
		return
	print("Derelict: the Prize's event: %s." % kind)
	_begin.rpc(int(str(by.name)) if by != null else 0, 0.0)


@rpc("authority", "call_local", "reliable")
func _begin(peer: int, at: float) -> void:
	begun = true
	carrier = peer
	elapsed = at


func _process(delta: float) -> void:
	_time += delta
	_shake = maxf(0.0, _shake - delta * 0.6)
	if kind == &"nest" and not begun and _sac != null:
		_sac.scale = Vector3.ONE * (1.0 + 0.03 * sin(_time * 1.3))
	if not begun:
		return
	elapsed += delta
	match kind:
		&"security":
			_security(delta)
		&"vent":
			_vent(delta)
		&"collapse":
			_collapse()
		&"nest":
			_hatch_out()


## Whether step `key` is due (`at` seconds in) and hasn't happened yet: then it has.
func _due(key: String, at: float) -> bool:
	if elapsed < at or _done.has(key):
		return false
	_done[key] = true
	return true


## A notice on the visor of the crew member at this machine, if they're aboard.
func _tell(text: String, level: int) -> void:
	var player := Player.local(get_tree())
	if player != null and Derelict.at(player.get_world_3d(), player.global_position + Vector3.UP * Player.CHEST_HEIGHT) == derelict:
		Player.tell(get_tree(), text, level)


# --- Security --------------------------------------------------------------------------------

func _security(delta: float) -> void:
	var section := DerelictLayout.letter(layout.section_of[layout.prize])
	if _due("alarm", START):
		_tell("SECURITY ALERT", 2)
		for beacon in beacons:
			beacon.on = true
		Sound.alarm(_speaker, LOCKDOWN_TIME)
		if multiplayer.is_server():
			for key: String in layout.lockdown:
				var door: Door = derelict.doors.get(RoomLayout.deck_key(key))
				if door != null:
					door.open = false
					door.seal_text = "LOCKDOWN"
					door.sealed = true
	if _due("lockdown", START + 1.0) and not layout.lockdown.is_empty():
		_tell("SECTION %s  LOCKDOWN" % section, 2)
	if _due("sentries", START + SENTRY_WAKE) and multiplayer.is_server():
		for sentry in sentries:
			sentry.wake()
	var over := elapsed >= START + LOCKDOWN_TIME
	if multiplayer.is_server() and elapsed >= START and not over:
		_alarm_in -= delta
		if _alarm_in <= 0.0:
			_alarm_in = ALARM_EVERY
			Noises.make(self, _speaker.global_position, &"alarm")
	if _due("stand_down", START + LOCKDOWN_TIME):
		_tell("LOCKDOWN LIFTED", 0)
		for beacon in beacons:
			beacon.on = false
		if multiplayer.is_server():
			for sentry in sentries:
				sentry.stand_down()
			for key: String in layout.lockdown:
				var door: Door = derelict.doors.get(RoomLayout.deck_key(key))
				if door != null and door.sealed and door.seal_text == "LOCKDOWN":
					door.sealed = false


## A beacon either side of the door at `key` (the Deck's), on the wall beside its frame, high up.
func _hang_beacons(key: String) -> void:
	var door: Door = derelict.doors.get(key)
	if door == null:
		return
	for face: float in [1.0, -1.0]:
		var beacon := AlarmBeacon.new()
		var out := door.transform.basis.z * face
		var along := door.transform.basis.x
		beacon.transform = Transform3D(Basis(Vector3.UP, atan2(out.x, out.z)), door.position + out * 0.15 + along * 1.55 * face + Vector3.UP * 2.2)
		derelict.add_child(beacon)
		beacons.append(beacon)


# --- Depressurization --------------------------------------------------------------------------

func _vent(delta: float) -> void:
	var blown := START + SEAL_WARNING
	if _due("seal", START):
		_tell("SEAL FAILURE", 2)
		Sound.event(&"groan", _speaker)
		_shake = 0.25
		for i in 3:
			var hiss := Effects.steam()
			hiss.amount = 14
			hiss.initial_velocity_max = 2.5
			var along := Vector3(-_into.z, 0, _into.x)
			derelict.add_child(hiss)
			hiss.position = _hole + along * (i - 1) * 0.9 + Vector3.UP * (0.6 - i * 0.5) + _into * 0.2
			hiss.basis = Basis.looking_at(_into + Vector3.UP * 0.3, Vector3.UP)
			hiss.emitting = true
			_hiss.append(hiss)
	if _due("blowout", blown):
		_blow_out()
	if elapsed < blown:
		return
	_gale = pow(clampf(1.0 - (elapsed - blown) / VENT_TIME, 0.0, 1.0), 1.5)
	if _gust != null:
		_gust.speed_scale = maxf(0.05, _gale)
		_gust.emitting = _gale > 0.08
	if multiplayer.is_server() and _gale > 0.05:
		_push_in -= delta
		if _push_in <= 0.0:
			_push_in = 0.25
			_drag_loose(0.25)
	if _due("vented", blown + VENT_TIME):
		_tell("SECTION VENTED", 1)
		if multiplayer.is_server():
			for key in _vent_doors():
				var door: Door = derelict.doors.get(RoomLayout.deck_key(key))
				if door != null and door.seal_text == "VENTING":
					door.sealed = false


## The wall goes: its piece (and the hull plating behind it) for a blown-out one, the air out of
## every room that held it, the doors round them slammed and sealed, the gale.
func _blow_out() -> void:
	var key := RoomLayout.deck_key(layout.blowout)
	var edge := _edge(layout.blowout)
	var at: Vector3 = edge[0]
	for child in derelict.get_children():
		if child is Node3D and child != self and (child as Node3D).position.is_equal_approx(at) and not child is Door:
			child.queue_free()
	var wall: Node3D = BLOWOUT.instantiate()
	wall.name = "blowout_" + key.replace(",", "_")
	wall.transform = Transform3D(Basis(Vector3.UP, atan2(_into.x, _into.z)), at)
	derelict.add_child(wall)
	Deck._mark_interior(wall)
	for hiss in _hiss:
		hiss.emitting = false
	Sound.event(&"blowout", _speaker)
	_shake = 0.9
	_tell("HULL BREACH", 2)
	for index in layout.sealed:
		for cell: Vector3i in layout.rooms[index].cells:
			var zone: Zone = derelict.zones.get(Vector2i(cell.x, cell.z))
			if zone != null:
				zone.pressurized = false
	# A burst of debris and frost out through the hole, then the air streaming after it.
	var burst := Effects.steam()
	burst.amount = 60
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.initial_velocity_min = 6.0
	burst.initial_velocity_max = 12.0
	derelict.add_child(burst)
	burst.position = _hole
	burst.basis = Basis.looking_at(-_into, Vector3.UP)
	burst.emitting = true
	_gust = Effects.dust()
	_gust.amount = 90
	_gust.lifetime = 0.9
	_gust.gravity = Vector3.ZERO
	_gust.direction = Vector3(0, 0, -1)
	_gust.spread = 8.0
	_gust.initial_velocity_min = 5.0
	_gust.initial_velocity_max = 8.0
	_gust.emission_box_extents = Vector3(1.6, 1.0, 0.1)
	derelict.add_child(_gust)
	_gust.basis = Basis.looking_at(-_into, Vector3.UP)
	_gust.position = _hole + _into * 4.5
	_gust.emitting = true
	if multiplayer.is_server():
		for door_key in _vent_doors():
			var door: Door = derelict.doors.get(RoomLayout.deck_key(door_key))
			if door != null:
				door.open = false
				door.seal_text = "VENTING"
				door.sealed = true


func _vent_doors() -> Array[String]:
	return layout.vent_doors.filter(func(key: String) -> bool: return key != layout.vault_door)


## Host: the gale drags what's loose in the rooms that held air toward the hole.
func _drag_loose(seconds: float) -> void:
	var items := LooseItems.of(self)
	if items == null:
		return
	for thing in items.loose():
		if thing is Pickup and _in_sealed(thing.global_position):
			var drift := _drift(thing.global_position)
			(thing as Pickup).apply_central_impulse(drift * (thing as Pickup).mass * seconds * 2.0)


## Whether `point` (world) is in a room that held air.
func _in_sealed(point: Vector3) -> bool:
	var local := derelict.to_local(point)
	var cell := Vector3i(roundi(local.x / Deck.CELL), 0, roundi(local.z / Deck.CELL))
	return _sealed.has(layout.room_of.get(cell, -1))


## How the gale carries something at `point` (world): toward the hole, faster nearer it.
func _drift(point: Vector3) -> Vector3:
	var local := derelict.to_local(point)
	var to := _hole - local
	to.y = 0.0
	var far := to.length()
	var pull := GALE_DRIFT * _gale * clampf(1.0 - far / GALE_REACH, 0.15, 1.0)
	return derelict.global_basis * (to.normalized() * pull) if far > 0.01 else Vector3.ZERO


## The edge `key` (a layout edge key)'s middle on the deck and the way into its room, in the
## derelict's space.
func _edge(key: String) -> Array:
	for index in layout.rooms.size():
		for cell: Vector3i in layout.rooms[index].cells:
			for side: String in RoomLayout.AROUND:
				if RoomLayout.edge_key(cell, side) == key:
					var out := Vector3(RoomLayout.SIDES[side])
					return [layout.centre_of(cell) + out * Deck.CELL / 2.0, -out]
	return [Vector3.ZERO, Vector3.FORWARD]


# --- Structural breach -------------------------------------------------------------------------

func _collapse() -> void:
	if _due("groan", START):
		_tell("STRUCTURAL FAILURE", 2)
		Sound.event(&"groan", _speaker)
		_shake = 0.6
	for i in layout.falls.size():
		var at := START + FIRST_FALL + i * FALL_EVERY
		var spot: Transform3D = layout.falls[i]
		if _due("dust%d" % i, at - WARN):
			_trickle(spot.origin, 0.4, WARN + 0.4)
			Sound.event(&"creak", _speaker, _speaker.to_local(derelict.to_global(spot.origin)))
		if _due("fall%d" % i, at):
			_drop(DEBRIS.instantiate(), spot, DROP, CRUSH, CRUSH_REACH, false)
	if layout.buckle != "":
		var at := START + BUCKLE_AT
		if _due("heap_dust", at - HEAP_WARN):
			_trickle(layout.heap.origin, 1.1, HEAP_WARN + 0.6)
			Sound.event(&"groan", _speaker, _speaker.to_local(derelict.to_global(layout.heap.origin)))
		if _due("buckle", at):
			var door: Door = derelict.doors.get(RoomLayout.deck_key(layout.buckle))
			if door != null:
				var leaves := door.get_node_or_null("Leaves") as Node3D
				if leaves != null:
					leaves.rotation = Vector3(0.03, 0, 0.05)
				if multiplayer.is_server():
					door.open = false
					door.seal_text = "BUCKLED"
					door.sealed = true
			_drop(HEAP.instantiate(), layout.heap, HEAP_DROP, 1.0, 0.0, true)
			_shake = 1.0


## Grit trickling from the ceiling over `at` (the derelict's space), `wide` each way, for `seconds`.
func _trickle(at: Vector3, wide: float, seconds: float) -> void:
	var dust := Effects.dust()
	dust.amount = 70
	dust.scale_amount_min = 1.2
	dust.scale_amount_max = 3.0
	dust.emission_box_extents = Vector3(wide, 0.05, wide)
	derelict.add_child(dust)
	dust.position = at + Vector3.UP * (Deck.ROOM_HEIGHT - 0.1)
	dust.emitting = true
	get_tree().create_timer(seconds).timeout.connect(func():
		if is_instance_valid(dust):
			dust.emitting = false
			get_tree().create_timer(dust.lifetime).timeout.connect(dust.queue_free))


## `thing` falls from the ceiling to stand at `where` (the derelict's space) in `seconds`: solid
## once it's down, with a crash and a cloud. The host crushes anyone under it: within `reach` of
## where it lands, or (`boxed`) inside its footprint.
func _drop(thing: Node3D, where: Transform3D, seconds: float, blow: float, reach: float, boxed: bool) -> void:
	var shapes := thing.find_children("*", "CollisionShape3D", true, false)
	for shape: CollisionShape3D in shapes:
		shape.disabled = true
	thing.transform = Transform3D(where.basis, where.origin + Vector3.UP * (Deck.ROOM_HEIGHT - 0.4))
	derelict.add_child(thing)
	Deck._mark_interior(thing)
	var tween := create_tween()
	tween.tween_property(thing, "position", where.origin, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		for shape: CollisionShape3D in shapes:
			shape.disabled = false
		Sound.event(&"collapse" if boxed else &"fall", thing)
		_shake = maxf(_shake, 0.9 if boxed else 0.45)
		var cloud := Effects.dust()
		cloud.direction = Vector3.UP
		cloud.spread = 80.0
		cloud.gravity = Vector3(0, -1.0, 0)
		cloud.initial_velocity_min = 0.5
		cloud.initial_velocity_max = 1.8
		cloud.one_shot = true
		cloud.explosiveness = 0.9
		cloud.amount = 90 if boxed else 50
		cloud.scale_amount_min = 1.5
		cloud.scale_amount_max = 4.0
		cloud.emission_box_extents = Vector3(1.2, 0.1, 0.7) if boxed else Vector3(0.6, 0.1, 0.6)
		thing.add_child(cloud)
		cloud.position = Vector3.UP * 0.2
		cloud.emitting = true
		if multiplayer.is_server():
			_crush(thing.global_transform, blow, reach, boxed))


## Host: anyone under what's just come down at `where` (world) takes `blow`.
func _crush(where: Transform3D, blow: float, reach: float, boxed: bool) -> void:
	for crew: Player in get_tree().get_nodes_in_group(&"crew"):
		if crew.dead:
			continue
		var local := where.affine_inverse() * crew.global_position
		var under := (absf(local.x) < 1.3 and absf(local.z) < 0.8) if boxed else Vector2(local.x, local.z).length() < reach
		if under and absf(local.y) < 1.5:
			crew.hurt.rpc_id(crew.get_multiplayer_authority(), blow, &"crushed")


# --- Infestation -------------------------------------------------------------------------------

func _hatch_out() -> void:
	if _sac == null:
		return
	var burst_at := START + NEST_SWELL
	if elapsed < burst_at:
		if _due("stir", START):
			Sound.event(&"stir", _nest)
		var swell := clampf((elapsed - START) / NEST_SWELL, 0.0, 1.0)
		var throb := sin(_time * lerpf(4.0, 14.0, swell)) * lerpf(0.02, 0.07, swell)
		_sac.scale = Vector3(1.0 + swell * 0.18 + throb, 1.0 + swell * 0.28 + throb, 1.0 + swell * 0.18 + throb)
		return
	if _due("burst", burst_at):
		_sac.visible = false
		var spores := Effects.spores()
		_nest.add_child(spores)
		spores.position = Vector3.UP * 0.45
		spores.emitting = true
		var gore := Effects.steam()
		gore.amount = 30
		gore.one_shot = true
		gore.explosiveness = 0.9
		gore.direction = Vector3.UP
		gore.spread = 70.0
		gore.initial_velocity_max = 3.0
		_nest.add_child(gore)
		gore.position = Vector3.UP * 0.4
		gore.emitting = true
		Sound.event(&"burst", _nest)
		_shake = maxf(_shake, 0.2)
		if multiplayer.is_server():
			var prey := Player.of_peer(get_tree(), carrier)
			var face := 0.0
			if prey != null:
				var to := derelict.to_local(prey.global_position) - layout.nest.origin
				face = atan2(to.x, to.z)
			_hatch.rpc(face)


## Everyone: a Crawler comes out of the nest, facing `yaw`; the host sets it on whoever took the
## Prize (or whoever's nearest, if they're gone).
@rpc("authority", "call_local", "reliable")
func _hatch(yaw: float) -> void:
	var crawler := Creature.make(&"crawler", Transform3D(Basis(Vector3.UP, yaw), layout.nest.origin), HATCHLING)
	derelict.add_child(crawler)
	if not multiplayer.is_server():
		return
	get_tree().create_timer(Creature.STIR + 0.3).timeout.connect(func():
		if not is_instance_valid(crawler):
			return
		var prey := Player.of_peer(get_tree(), carrier)
		if prey == null or prey.dead:
			for crew: Player in get_tree().get_nodes_in_group(&"crew"):
				if not crew.dead and (prey == null or prey.dead or crew.global_position.distance_to(crawler.global_position) < prey.global_position.distance_to(crawler.global_position)):
					prey = crew
		if prey != null:
			(crawler as Crawler).provoke(prey))


# --- What the crew feel ------------------------------------------------------------------------

## How hard the deck under `crew` is shaking (as a jump's shake): any event's aboard their derelict.
static func shake_for(crew: Player) -> float:
	var most := 0.0
	for event: PrizeEvent in crew.get_tree().get_nodes_in_group(&"prize_events"):
		if event.begun and event._shake > 0.0 and event.derelict.global_position.distance_to(crew.global_position) < 200.0 \
				and Derelict.at(crew.get_world_3d(), crew.global_position + Vector3.UP * Player.CHEST_HEIGHT) == event.derelict:
			most = maxf(most, event._shake)
	return most


## How the gale carries `crew` (m/s, world), if they're in it.
static func gale_on(crew: Player) -> Vector3:
	for event: PrizeEvent in crew.get_tree().get_nodes_in_group(&"prize_events"):
		if event.kind == &"vent" and event._gale > 0.0 and event._in_sealed(crew.global_position):
			return event._drift(crew.global_position)
	return Vector3.ZERO


## On `crew`'s own machine, every physics frame: the gale strips their suit's O2 and wears it, and
## at the hole it takes them.
static func buffet(crew: Player, delta: float) -> void:
	for event: PrizeEvent in crew.get_tree().get_nodes_in_group(&"prize_events"):
		if event.kind != &"vent" or event._gale <= 0.0 or not event._in_sealed(crew.global_position):
			continue
		crew.o2 = maxf(0.0, crew.o2 - GALE_O2 * event._gale * delta)
		crew.wear(GALE_WEAR * event._gale * delta)
		var local := event.derelict.to_local(crew.global_position)
		if event._gale > 0.25 and Vector2(local.x - event._hole.x, local.z - event._hole.z).length() < SPACED:
			crew.die(&"spaced")
		return
