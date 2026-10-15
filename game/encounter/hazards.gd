class_name Hazards
extends Node3D
## A derelict's hazards (GDD §11), as its plan laid them out (DerelictLayout: hazards):
##   coolant spills  a torn cable hangs in each (dk_puddle). Dead, a mess; once its section has
##                   power, live: sparks, arcs crawling over it, a buzz anything listening hears.
##                   Anyone who steps in is electrocuted (SHOCK a jolt, "electrocuted"); a
##                   Crawler that blunders in is stunned, as by a prod
##   a leaking core  its drive room's core glows sick and vents; near it the suit's dose climbs
##                   (RAD_RATE a second beside it, falling off over RAD_FALLOFF), the Geiger counter
##                   chattering faster the nearer; a full dose is "irradiated"
##   faulty doors    with power, a door cycling on a dying circuit: open, a lurch, then it slams
##                   shut three times as fast as a door should (Door.faulty), its lamp stuttering;
##                   anyone in the doorway is crushed (CRUSH, "crushed")
## The host decides who's hurt and drives the doors; every peer shows them; each crew member's own
## machine keeps their dose (`irradiate`).

const PUDDLE := Vector2(0.8, 0.58)
const SHOCK := 0.3
const SHOCK_GAP := 0.6
const STUN_GAP := 4.0
const RAD_RATE := 0.012
const RAD_FALLOFF := 2.5
const RAD_REACH := 16.0
## Geiger clicks a second for each unit of dose a second.
const CLICKS := 900.0
const CRUSH := 0.5
## A faulty door's cycle: open, lurching, poised, slammed shut (seconds, each give or take a third).
const CYCLE := {&"open": 2.4, &"lurch": 0.22, &"poised": 0.7, &"shut": 1.8}
const SURFACE := Color(0.03, 0.08, 0.09)
const ARC := Color(0.55, 0.85, 1.0)
const CORE_GLOW := Color(0.55, 1.0, 0.3)

var derelict: Derelict
var layout: DerelictLayout
var spills: Array[Dictionary] = []
var _core: Node3D
var _core_light: OmniLight3D
var _doors: Array[Dictionary] = []
var _shocked := {}
var _check_in := 0.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "Hazards"
	add_to_group(&"hazards")
	derelict = get_parent() as Derelict
	layout = derelict.layout
	_rng.seed = hash([layout.seed, "hazards"])
	for prop: Node3D in derelict.fixtures.get("puddle", []):
		_fit_spill(prop)
	var cores: Array = derelict.fixtures.get("hot_core", [])
	if not cores.is_empty():
		_core = cores[0]
		_core_light = OmniLight3D.new()
		_core_light.light_color = CORE_GLOW
		_core_light.omni_range = 7.0
		_core_light.light_energy = 1.2
		_core_light.light_cull_mask = ~Deck.HULL_LAYER
		_core_light.position = Vector3.UP * 1.4
		_core.add_child(_core_light)
		var vapour := Effects.steam()
		vapour.amount = 20
		vapour.lifetime = 2.4
		vapour.initial_velocity_min = 0.3
		vapour.initial_velocity_max = 0.8
		vapour.color_ramp = Effects._fade(Color(0.5, 0.8, 0.4, 0.3), 0.5)
		_core.add_child(vapour)
		vapour.position = Vector3.UP * 2.3
		vapour.basis = Basis.looking_at(Vector3.UP, Vector3.FORWARD)
		vapour.emitting = true
	for key: String in layout.faulty:
		var door: Door = derelict.doors.get(RoomLayout.deck_key(key))
		if door != null:
			door.faulty = true
			_doors.append({"door": door, "phase": &"shut", "left": _rng.randf() * 2.0})


func _fit_spill(prop: Node3D) -> void:
	var surface := prop.find_child("puddle_surface", true, false) as MeshInstance3D
	var tip := prop.find_child("SOCKET_tip", true, false) as Node3D
	var material := ShaderMaterial.new()
	material.shader = preload("res://game/rendering/psx_unlit.gdshader")
	material.set_shader_parameter("albedo", SURFACE)
	if surface != null:
		surface.material_override = material
	var light := OmniLight3D.new()
	light.light_color = ARC
	light.omni_range = 4.0
	light.light_energy = 0.0
	light.light_cull_mask = ~Deck.HULL_LAYER
	light.position = Vector3.UP * 0.4
	prop.add_child(light)
	var sparks := Effects.sparks()
	sparks.emitting = false
	sparks.one_shot = true
	sparks.amount = 14
	prop.add_child(sparks)
	sparks.position = tip.position + Vector3.UP * 0.05 if tip != null else Vector3.UP * 0.1
	spills.append({"prop": prop, "material": material, "light": light, "sparks": sparks,
			"section": derelict.power.section_at(prop.global_position), "next": 0.0, "live": false})


func _process(delta: float) -> void:
	_time += delta
	for spill in spills:
		_show_spill(spill, delta)
	if _core_light != null:
		_core_light.light_energy = 1.0 + 0.35 * sin(_time * 11.0) * sin(_time * 3.7) + (0.6 if fmod(_time * 1.3, 1.0) < 0.05 else 0.0)
	if not multiplayer.is_server():
		return
	for each in _doors:
		_cycle(each, delta)
	_check_in -= delta
	if _check_in <= 0.0:
		_check_in = 0.1
		_shock_whoever()


# --- Coolant spills ------------------------------------------------------------------------------

## Whether `spill` is live: its section has power.
func _live(spill: Dictionary) -> bool:
	return spill.section >= 0 and derelict.power.powered(spill.section)


func _show_spill(spill: Dictionary, delta: float) -> void:
	var live := _live(spill)
	if live != spill.live:
		spill.live = live
		if live:
			Sound.event(&"arc", spill.prop)
	var material: ShaderMaterial = spill.material
	var light: OmniLight3D = spill.light
	if not live:
		material.set_shader_parameter("albedo", SURFACE)
		light.light_energy = 0.0
		return
	# Arcs crawl over it: the surface flashes, the light stutters; now and then the cable spits.
	var flash := randf() < 0.18
	material.set_shader_parameter("albedo", SURFACE.lerp(ARC, randf_range(0.25, 0.6) if flash else randf_range(0.0, 0.08)))
	light.light_energy = randf_range(1.2, 2.4) if flash else 0.15
	spill.next -= delta
	if spill.next <= 0.0:
		spill.next = randf_range(0.35, 1.4)
		(spill.sparks as CPUParticles3D).restart()
		Sound.event(&"arc", spill.prop)
		if multiplayer.is_server():
			Noises.make(self, spill.prop.global_position, &"buzz")


## Whether `point` (world) is in `spill`, on the deck.
func _in_spill(spill: Dictionary, point: Vector3) -> bool:
	var local: Vector3 = (spill.prop as Node3D).global_transform.affine_inverse() * point
	return absf(local.y) < 0.4 and pow(local.x / PUDDLE.x, 2) + pow(local.z / PUDDLE.y, 2) < 1.0


## Host: anyone standing in a live spill takes a jolt (now and then, while they're in it); a Crawler
## in one is stunned.
func _shock_whoever() -> void:
	var now := _time
	for spill in spills:
		if not _live(spill):
			continue
		for crew: Player in get_tree().get_nodes_in_group(&"crew"):
			if crew.dead or crew.floating or not _in_spill(spill, crew.global_position):
				continue
			if now - float(_shocked.get(crew.name, -INF)) < SHOCK_GAP:
				continue
			_shocked[crew.name] = now
			_zap.rpc(spill.prop.get_path())
			crew.hurt.rpc_id(crew.get_multiplayer_authority(), SHOCK, &"electrocuted")
		for creature in derelict.creatures():
			if creature is Crawler and creature.alive() and _in_spill(spill, creature.global_position):
				if now - float(_shocked.get(creature.name, -INF)) >= STUN_GAP:
					_shocked[creature.name] = now
					_zap.rpc(spill.prop.get_path())
					creature.struck(0.0, true, null)


## Everyone: a spill jolts someone: a flash and a crack.
@rpc("authority", "call_local", "reliable")
func _zap(at: NodePath) -> void:
	var prop := get_node_or_null(at) as Node3D
	if prop == null:
		return
	for spill in spills:
		if spill.prop == prop:
			(spill.sparks as CPUParticles3D).restart()
			(spill.light as OmniLight3D).light_energy = 4.0
	Sound.event(&"zap", prop)


# --- The leaking core ----------------------------------------------------------------------------

## The dose a second at `point` (world) from leaking cores aboard any derelict.
static func rate_at(tree: SceneTree, point: Vector3) -> float:
	var rate := 0.0
	for hazards: Hazards in tree.get_nodes_in_group(&"hazards"):
		if hazards._core == null:
			continue
		var far := (hazards._core.global_position + Vector3.UP * 1.2).distance_to(point)
		if far < RAD_REACH:
			rate += RAD_RATE / (1.0 + pow(far / RAD_FALLOFF, 2.0))
	return rate


## On `crew`'s own machine, every physics frame: the dose climbs where there's a leaking core, the
## Geiger counter chattering with it; a full dose kills.
static func irradiate(crew: Player, delta: float) -> void:
	var rate := rate_at(crew.get_tree(), crew.global_position + Vector3.UP * Player.CHEST_HEIGHT)
	crew.exposure = rate
	if rate <= 0.0:
		return
	crew.radiation = minf(1.0, crew.radiation + rate * delta)
	if randf() < rate * CLICKS * delta:
		Sound.geiger()
	if crew.radiation >= 1.0:
		crew.die(&"irradiated")


# --- Faulty doors --------------------------------------------------------------------------------

## Host: a faulty door's cycle, while it has power: open, a lurch toward shutting, poised, slammed
## shut (crushing whoever's in it), shut a while, open again.
func _cycle(each: Dictionary, delta: float) -> void:
	var door: Door = each.door
	if not door.powered or door.sealed or door.forced:
		return
	each.left -= delta
	if each.left > 0.0:
		return
	var next: StringName
	match each.phase:
		&"shut":
			next = &"open"
			door.open = true
		&"open":
			next = &"lurch"
			door.open = false
		&"lurch":
			next = &"poised"
			door.open = true
		&"poised":
			next = &"slam"
			door.open = false
			get_tree().create_timer(0.15).timeout.connect(_crush.bind(door))
		_:
			next = &"shut"
	each.phase = next
	each.left = CYCLE.get(next, 0.3) * _rng.randf_range(0.7, 1.3)


## Host: anyone in `door`'s doorway as it slams.
func _crush(door: Door) -> void:
	for crew: Player in get_tree().get_nodes_in_group(&"crew"):
		if crew.dead:
			continue
		var local := door.global_transform.affine_inverse() * crew.global_position
		if absf(local.x) < 1.0 and absf(local.z) < 0.45 and local.y < 2.0 and local.y > -0.5:
			crew.hurt.rpc_id(crew.get_multiplayer_authority(), CRUSH, &"crushed")
