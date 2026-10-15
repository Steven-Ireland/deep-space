class_name DerelictPower
extends Node
## A derelict's power (GDD §8.3): its sections (DerelictLayout), each dead until its breaker box
## (Breaker) has a charged cell seated and its switch thrown. A section with power has:
##   - its lights: a cold practical in every room cell, coming up with a stutter when the power
##     does (most then steady, some failing and flickering on, some broken for good), the fixture's
##     diffuser lit under it
##   - its doors: they open and shut from their panels again. Dead, a door's stuck as it is, though
##     a crowbar can force a shut one (Door)
##   - its fittings: an O2 rack, a lamp charger (TopUp), a vault's lock
## and live hazards (Hazards). Throwing a switch is loud, and heard (Noises).
##
## The host owns which sections hold a cell and are switched on, sends it to everyone on each
## change (and to each crew member who joins); crew report throwing a switch, seating a cell or
## taking one out. Every peer lights, powers and shows it all from that.

## A section's power came or went (every peer).
signal changed(section: int)

## The practicals: their colour, how bright, how far they reach; seconds the lights take to come up
## (each starts at its own moment within it, stutters, then holds), and the share that are broken
## or failing.
const LIGHT_COLOUR := Color(0.74, 0.84, 1.0)
const LIGHT_ENERGY := 0.8
const LIGHT_RANGE := 6.5
const RISE := 1.4
const STUTTER := 0.35
const BROKEN := 0.2
const FAILING := 0.2
## The diffuser's lit face under each fixture (art/blender/station_kit.py: ceiling, the derelict's:
## a 2.1 x 0.6 m diffuser whose underside is 2.88 m up), just under it, behind its grille's bars.
const DIFFUSER := Vector2(2.08, 0.58)
const DIFFUSER_AT := Vector3(0, 2.877, 0)
const DIFFUSER_COLOUR := Color(0.62, 0.7, 0.8)
const UNLIT := preload("res://game/rendering/psx_unlit.gdshader")
## How far a breaker's switch thrown is heard.
const THROW_REACH := 18.0

var derelict: Derelict
## Per section: whether a charged cell is seated in its breaker, and whether its switch is thrown.
var cells: Array[bool] = []
var on: Array[bool] = []
var breakers: Array[Breaker] = []

## Per section, its lights: [OmniLight3D, glow mesh, kind (0 steady, 1 failing, 2 broken), its
## moment to come up (0..1 of RISE)].
var _lights := {}
## Per section, seconds since its power came up (its lights stutter up over RISE), or -1 when dead.
var _risen := {}
## Per section, whether its lights are all out already (dead, and shown so).
var _dark := {}
var _glow: ShaderMaterial
var _time := 0.0


func _init() -> void:
	name = "Power"


func _ready() -> void:
	derelict = get_parent() as Derelict
	var layout := derelict.layout
	for box: Dictionary in layout.breakers:
		cells.append(box.cell)
		on.append(false)
	while cells.size() < layout.sections:
		cells.append(false)
		on.append(false)
	_glow = ShaderMaterial.new()
	_glow.shader = UNLIT
	_glow.set_shader_parameter("albedo", DIFFUSER_COLOUR)
	_glow.set_shader_parameter("albedo_texture", _grille())
	_make_lights()
	_fit_breakers()
	NetworkEvents.on_peer_join.connect(func(peer: int):
		if multiplayer.is_server():
			_state.rpc_id(peer, _pack()))
	_dev_power.call_deferred()
	_apply(-1, false)


## Whether section `section` has power.
func powered(section: int) -> bool:
	return section >= 0 and section < cells.size() and cells[section] and on[section]


## Whether there's power at `point` (world space): in a powered section's room.
func powered_at(point: Vector3) -> bool:
	return powered(section_at(point))


## The section at `point` (world space), or -1 outside the derelict's rooms.
func section_at(point: Vector3) -> int:
	var local := derelict.to_local(point)
	return derelict.layout.section_at(Vector3i(roundi(local.x / Deck.CELL), 0, roundi(local.z / Deck.CELL)))


## The section of a grid cell of the derelict's deck.
func section_of_cell(cell: Vector2i) -> int:
	return derelict.layout.section_at(Vector3i(cell.x, 0, cell.y))


# --- Crew at a breaker (reported to the host) ----------------------------------------------------

## A crew member threw section `section`'s switch (on, or off again).
func throw(section: int) -> void:
	_throw.rpc_id(1, section)


@rpc("any_peer", "call_local", "reliable")
func _throw(section: int) -> void:
	if not multiplayer.is_server() or section < 0 or section >= on.size():
		return
	on[section] = not on[section]
	Noises.make(self, breakers[section].global_position if section < breakers.size() else derelict.global_position, &"breaker")
	print("Derelict: section %s switched %s%s." % [DerelictLayout.letter(section), "on" if on[section] else "off",
			"" if cells[section] else " (no cell)"])
	_broadcast(section)


## On the crew member's machine: they seat the cell in their hand in section `section`'s breaker.
func insert(section: int, spill: Transform3D) -> void:
	_insert.rpc_id(1, section, spill)


@rpc("any_peer", "call_local", "reliable")
func _insert(section: int, spill: Transform3D) -> void:
	if not multiplayer.is_server():
		return
	if section >= 0 and section < cells.size() and not cells[section]:
		cells[section] = true
		_broadcast(section)
	else:
		LooseItems.of(self).put(Items.make(&"power_cell"), spill)


## A crew member takes the cell out of section `section`'s breaker (its switch off).
func take(section: int) -> void:
	_take.rpc_id(1, section)


@rpc("any_peer", "call_local", "reliable")
func _take(section: int) -> void:
	if not multiplayer.is_server() or section < 0 or section >= cells.size() or not cells[section] or on[section]:
		return
	var peer := multiplayer.get_remote_sender_id()
	var player := Player.of_peer(get_tree(), 1 if peer == 0 else peer)
	if player == null:
		return
	cells[section] = false
	player.receive.rpc_id(player.get_multiplayer_authority(), Items.make(&"power_cell"))
	_broadcast(section)


## Dev (`--powered`): every section with a cell switched on; `--powered=all` seats a cell in every
## breaker first.
func _dev_power() -> void:
	if not multiplayer.is_server() or not Args.flag("--powered"):
		return
	for s in cells.size():
		if Args.value("--powered", "") == "all":
			cells[s] = true
		on[s] = cells[s]
	_broadcast(-1)


# --- Showing it ---------------------------------------------------------------------------------

## A practical in every room cell's fixture, off, each with its diffuser's glow; some broken, some
## failing (the same on every peer: from the derelict's seed and the cell).
func _make_lights() -> void:
	var box := QuadMesh.new()
	box.size = DIFFUSER
	for cell: Vector2i in derelict.cells:
		var section := section_of_cell(cell)
		if section < 0:
			continue
		var roll := Seeds.rng(derelict.layout.seed, "light/%d/%d" % [cell.x, cell.y])
		var r := roll.randf()
		var kind := 2 if r < BROKEN else (1 if r < BROKEN + FAILING else 0)
		if derelict.layout.room_of.get(Vector3i(cell.x, 0, cell.y), -1) in derelict.layout.dark:
			kind = 2 # a Hanger's room: its lights are dead for good
		var light := OmniLight3D.new()
		light.position = Deck.centre_of(cell) + Vector3(0, 2.75, 0)
		light.light_color = LIGHT_COLOUR
		light.light_energy = LIGHT_ENERGY
		light.omni_range = LIGHT_RANGE
		light.omni_attenuation = 1.4
		light.shadow_enabled = false
		light.light_cull_mask = ~Deck.HULL_LAYER
		light.visible = false
		derelict.add_child(light)
		var glow := MeshInstance3D.new()
		glow.mesh = box
		glow.material_override = _glow
		glow.position = Deck.centre_of(cell) + DIFFUSER_AT
		glow.rotation.x = PI / 2.0 # facing down
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.layers = Deck.INTERIOR_LAYER
		glow.visible = false
		derelict.add_child(glow)
		if not _lights.has(section):
			_lights[section] = []
		_lights[section].append([light, glow, kind, roll.randf()])


## The lit diffuser's face: frosted, brighter along its middle, under its grille's dark bars (one
## every 7 of its 64 texels across 2.08 m: about the LANTERN's 0.25 m) and frame.
static func _grille() -> ImageTexture:
	var image := Image.create(64, 16, false, Image.FORMAT_RGB8)
	for x in 64:
		for y in 16:
			var across := absf(y - 7.5) / 7.5
			var frost := 1.0 - 0.25 * across * across
			var bar := x % 7 == 3
			var edge := x < 2 or x > 61 or y == 0 or y == 15
			var level := 0.22 if edge else (0.35 if bar else frost)
			image.set_pixel(x, y, Color(level, level, level))
	return ImageTexture.create_from_image(image)


## A breaker in each box the plan placed, the prop the derelict dressed it with.
func _fit_breakers() -> void:
	for box: Dictionary in derelict.layout.breakers:
		var prop: Node3D = load(Derelict.MODELS % "derelict/dk_breaker").instantiate()
		prop.name = "Breaker%s" % DerelictLayout.letter(box.section)
		prop.transform = box.at
		derelict.add_child(prop)
		Deck._mark_interior(prop)
		var breaker := Breaker.fit(prop, self, box.section)
		while breakers.size() <= box.section:
			breakers.append(null)
		breakers[box.section] = breaker


func _process(delta: float) -> void:
	_time += delta
	for section: int in _lights:
		var lit := powered(section)
		var risen: float = _risen.get(section, -1.0)
		if lit:
			risen = risen + delta if risen >= 0.0 else 0.0
		else:
			risen = -1.0
		_risen[section] = risen
		if not lit and _dark.get(section, false):
			continue
		for each: Array in _lights[section]:
			_show_light(each, lit, risen)
		_dark[section] = not lit


## One practical: dark without power; with it, up at its own moment with a stutter, then steady,
## or failing (stuttering on), or never (broken).
func _show_light(each: Array, lit: bool, risen: float) -> void:
	var light: OmniLight3D = each[0]
	var glow: MeshInstance3D = each[1]
	var kind: int = each[2]
	var on_at: float = each[3] * RISE
	var shown := false
	var level := 1.0
	if lit and kind != 2 and risen >= on_at:
		var since := risen - on_at
		if since < STUTTER:
			shown = fmod(since * 23.0 + each[3] * 7.0, 1.0) < 0.5
		elif kind == 1:
			var t: float = _time * 9.0 + each[3] * 40.0
			shown = sin(t) * sin(t * 0.37 + 1.1) > -0.35
			level = 0.75
		else:
			shown = true
	light.visible = shown
	light.light_energy = LIGHT_ENERGY * level
	glow.visible = shown


## Brings everything that depends on the power up to date: the doors (powered from either side),
## the breakers' switches and lamps; and tells crew aboard what changed (`section`, or -1 for none
## to tell, as at the start).
func _apply(section: int, tell: bool) -> void:
	for key: String in derelict.doors:
		var door: Door = derelict.doors[key]
		door.powered = _door_powered(key)
	for breaker in breakers:
		if breaker != null:
			breaker.show_state(tell)
	if section >= 0:
		changed.emit(section)
	if not tell or section < 0:
		return
	var local := Player.local(get_tree())
	if local == null or Derelict.at(local.get_world_3d(), local.global_position + Vector3.UP * Player.CHEST_HEIGHT) != derelict:
		return
	var letter := DerelictLayout.letter(section)
	if powered(section):
		Player.tell(get_tree(), "SECTION %s  POWER RESTORED" % letter)
	elif on[section] and not cells[section]:
		Player.tell(get_tree(), "SECTION %s  NO CELL" % letter, 1)
	else:
		Player.tell(get_tree(), "SECTION %s  POWER DOWN" % letter, 1)


## Whether the door at `key` ("x,z,axis" of its deck) has power: from the room on either side.
func _door_powered(key: String) -> bool:
	var parts := key.split(",")
	var cell := Vector2i(int(parts[0]), int(parts[1]))
	var other := cell + (Vector2i(0, -1) if parts[2] == "h" else Vector2i(-1, 0))
	return powered(section_of_cell(cell)) or powered(section_of_cell(other))


# --- Keeping peers in step ----------------------------------------------------------------------

func _broadcast(section: int) -> void:
	_state.rpc(_pack(), section)


func _pack() -> Dictionary:
	return {"cells": cells, "on": on}


@rpc("authority", "call_local", "reliable")
func _state(data: Dictionary, section := -1) -> void:
	var was_powered := range(cells.size()).map(func(s: int) -> bool: return powered(s))
	cells.assign(data.cells)
	on.assign(data.on)
	_apply(section, section >= 0)
	for s in cells.size():
		if s < was_powered.size() and was_powered[s] != powered(s) and section < 0:
			changed.emit(s)
