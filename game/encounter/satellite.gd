class_name Satellite
extends Node3D
## A relay satellite alongside (GDD §3, §8.1, §8.3): an earlier wave's relay still in working order,
## grown from its node's seed (SatelliteLayout) on every peer and built here. A Deck per level in the
## satellite kit (sk_*), lit cold white, airless and weightless, the levels joined by hatchways;
## its rooms furnished and its machines running (the telemetry console live, the racks flickering
## with traffic, the core glowing, an O2 rack that still refills a suit); outside, its solar wings
## with their navigation lamps, its dish, its mast's strobe, and the floodlights and beacon over its
## EVA hatch. The LANTERN holds position off it (Run sets it out to port, its hatch toward the
## LANTERN's EVA airlock), and crew cross to it on EVA.
##
## Its hatch opens and shuts by hand, from either side. The host owns whether it's open and sends it
## to everyone, and to each crew member who joins. Its loot is stocked as markers the host puts out
## (LooseItems.stock); weightless, everything hangs where it was left.

const MODELS := "res://assets/models/%s.glb"
const SCREENS := "res://game/terminals/screens/%s.gd"
const GREEN := Color(0.4, 1.0, 0.5)
## Its rooms' light: cold white, unlike the LANTERN's sodium.
const LIGHT := Color(0.78, 0.9, 1.0)
const LIGHT_ENERGY := 1.15
## Navigation lamps on the wing tips (red north, green south), the mast's strobe, the hatch's
## amber approach beacon: each [colour, period, share of it lit].
const NAV_RED := [Color(1.0, 0.18, 0.12), 1.6, 0.18]
const NAV_GREEN := [Color(0.2, 1.0, 0.35), 1.6, 0.18]
const STROBE := [Color(1.0, 1.0, 0.95), 2.3, 0.06]
const BEACON := [Color(1.0, 0.62, 0.18), 1.0, 0.5]
## The core's light, and the floodlights over the hatch.
const CORE_GLOW := Color(0.45, 0.85, 1.0)
const FLOOD := Color(1.0, 0.95, 0.85)
const UNLIT := preload("res://game/rendering/psx_unlit.gdshader")

## Its plan; set it (`make`) before it enters the tree.
var layout: SatelliteLayout
## How many crew its loot is stocked for (the host's count; the host puts it out, LooseItems).
var crew := 1
## Its name on the long-range scan (RELAY K-42), and how long it's been up, in years.
var code := "RELAY"
var years := 30.0
## Each level's Deck, by level.
var levels := {}
## The EVA hatch, and whether it stands open (the host's word).
var entry: Hatch
var hatch_open := false

var _blinking: Array = [] # [lamp mesh or null, light or null, period, lit share, phase]
var _activity: Array[MeshInstance3D] = []
var _core_lights: Array[OmniLight3D] = []
var _time := 0.0


## A satellite built from `plan`, stocked for `crew`.
static func make(plan: SatelliteLayout, crew_size := 1) -> Satellite:
	var satellite := Satellite.new()
	satellite.layout = plan
	satellite.crew = crew_size
	return satellite


func _ready() -> void:
	if layout == null:
		return
	add_to_group(&"satellite")
	code = Oddities.of(&"relay", layout.seed, null)[0]
	years = 24.0 + Seeds.rng(layout.seed, "satellite/years").randf() * 18.0
	_build()
	_fit_hatch()
	_dress()
	_mount()
	NetworkEvents.on_peer_join.connect(func(peer: int):
		if multiplayer.is_server():
			_state.rpc_id(peer, hatch_open))


## A Deck per level, stacked: weightless and airless, lit, its hatchways and plating fitted to the
## levels over and under it.
func _build() -> void:
	var marks := RoomLayout.MARKS.substr(0, layout.rooms.size())
	var shift := layout.origin()
	for level in layout.levels():
		var deck := Deck.new()
		deck.name = "Level%d" % level if level >= 0 else "LevelMinus%d" % -level
		deck.kit = "sk"
		deck.light_colour = LIGHT
		deck.light_energy = LIGHT_ENERGY
		deck.vacuum = marks
		deck.weight = 0.0
		deck.hatch_up.assign(layout.hatchways(level))
		deck.hatch_down.assign(layout.hatchways(level - 1))
		for cell: Vector3i in layout.room_of:
			if cell.y == level + 1:
				deck.roofed[Vector2i(cell.x, cell.z)] = true
			elif cell.y == level - 1:
				deck.floored[Vector2i(cell.x, cell.z)] = true
		deck.position.y = level * RoomLayout.PITCH
		add_child(deck)
		deck.build(layout.rows(level), shift, layout.openings(level))
		var shut := layout.shut_on(level)
		for key: String in deck.doors:
			deck.doors[key].open = not shut.has(key)
		levels[level] = deck


## The EVA hatch, on the entry's west wall: handles on both faces to open and shut it by hand.
func _fit_hatch() -> void:
	var deck: Deck = levels[0]
	entry = deck.hatches.get("0,0,v")
	if entry == null:
		push_error("Satellite: no hatch at its entry.")
		return
	for face in [-1.0, 1.0]:
		var handle := HatchHandle.new()
		handle.name = "HatchHandle%s" % ("In" if face > 0 else "Out")
		handle.satellite = self
		handle.position = Vector3(0, Hatch.CENTRE, face * 0.22)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(1.6, 1.6, 0.1)
		shape.shape = box
		handle.add_child(shape)
		entry.add_child(handle)
		handle.used.connect(func(_peer: int): _toggle_hatch())


func _process(delta: float) -> void:
	_time += delta
	if entry != null:
		entry.open = hatch_open
	for lamp: Array in _blinking:
		var on: bool = fmod(_time + lamp[4], lamp[2]) < lamp[2] * lamp[3]
		if lamp[0] != null:
			lamp[0].visible = on
		if lamp[1] != null:
			lamp[1].visible = on
	# Traffic: each activity lamp flickers on its own.
	for mesh in _activity:
		if randf() < delta * 6.0:
			mesh.visible = not mesh.visible
	for light in _core_lights:
		light.light_energy = 1.4 + 0.25 * sin(_time * 1.3) + 0.1 * sin(_time * 7.1)


# --- Inside ------------------------------------------------------------------------------------

## The rooms' furniture and machines, and the loot (markers the host stocks).
func _dress() -> void:
	for prop: Dictionary in layout.props:
		var node: Node3D = load(MODELS % prop.model).instantiate()
		node.transform = prop.at
		add_child(node)
		Deck._mark_interior(node)
		match String(prop.model).get_file():
			"sp_console":
				_terminal(node, "screen_telemetry", "telemetry_screen", Vector2i(320, 240), {"years": years})
			"rm_cabin_desk":
				_terminal(node, "screen_log", "status_screen", Vector2i(160, 120), {"title": "SHELTER", "lines": [["MAINT LOG", "DIM"],
						["LAST ENTRY", "DIM"], ["%dY AGO" % roundi(years - 2.0), "AMBER"]], "prompt": "_"})
			"rm_cycle_panel":
				_terminal(node, "screen_airlock", "status_screen", Vector2i(160, 120), {"title": "EVA HATCH",
						"lines": [["CABIN", "DIM"], ["VACUUM", "AMBER"], ["NO PRESSURE", "DIM"]], "prompt": "MIND YOUR SUIT"})
			"rm_o2_rack":
				TopUp.fit(node, "REFILL", Vector3(0, 1.1, 0.16), Vector2(1.4, 1.4), "o2")
			"sp_rack":
				var lamps := node.find_child("activity", true, false) as MeshInstance3D
				if lamps != null:
					_activity.append(lamps)
			"sp_core":
				var glow := OmniLight3D.new()
				glow.name = "CoreGlow"
				glow.light_color = CORE_GLOW
				glow.omni_range = 5.5
				glow.omni_attenuation = 1.3
				glow.light_cull_mask = ~Deck.HULL_LAYER
				(node.find_child("SOCKET_glow", true, false) as Node3D).add_child(glow)
				_core_lights.append(glow)
	for find: Dictionary in layout.loot(crew):
		var spot := Marker3D.new()
		spot.name = "Stock_%s" % find.kind
		spot.transform = find.at
		spot.set_meta(&"kind", find.kind)
		spot.set_meta(&"racked", find.get("racked", false))
		spot.add_to_group(&"loot")
		add_child(spot)


func _terminal(prop: Node3D, mesh: String, script: String, resolution: Vector2i, settings: Dictionary) -> void:
	var terminal := Terminal.new()
	terminal.name = "Terminal_" + mesh
	terminal.screen_mesh_name = mesh
	terminal.screen_script = load(SCREENS % script)
	terminal.resolution = resolution
	terminal.glow = GREEN
	settings["station"] = code
	terminal.screen_settings = settings
	prop.add_child(terminal)


# --- Outside -----------------------------------------------------------------------------------

## What's mounted on the hull (SatelliteLayout.exterior), the wing tips' and mast's lamps, and the
## floodlights and beacon over the hatch, on the hull's layer (the star lights it; the rooms'
## lights don't).
func _mount() -> void:
	for part: Dictionary in layout.exterior:
		var node: Node3D = load(MODELS % part.model).instantiate()
		node.transform = part.at
		add_child(node)
		for mesh: VisualInstance3D in node.find_children("*", "VisualInstance3D", true, false):
			mesh.layers = Deck.HULL_LAYER
		match String(part.model).get_file():
			"sh_solar_wing":
				# North wing red, south green.
				_blinker(node, "nav_lamp", "SOCKET_nav", NAV_RED if part.at.basis.z.z < 0.0 else NAV_GREEN, 4.0)
			"sh_mast":
				_blinker(node, "beacon_lamp", "SOCKET_beacon", STROBE, 9.0)
	var hull: Node3D = null
	for piece in levels[0].get_children():
		if piece is Node3D and piece.find_child("SOCKET_flood_l", true, false) != null:
			hull = piece
	if hull == null:
		return
	_blinker(hull, "beacon_lamp", "SOCKET_beacon", BEACON, 5.0)
	for side in ["l", "r"]:
		var socket := hull.find_child("SOCKET_flood_%s" % side, true, false) as Node3D
		var lens := hull.find_child("flood_%s" % side, true, false) as MeshInstance3D
		if lens != null:
			lens.material_override = _unlit(FLOOD, 2.0)
		var flood := SpotLight3D.new()
		flood.name = "Flood_%s" % side
		flood.light_color = FLOOD
		flood.light_energy = 4.0
		flood.spot_range = 22.0
		flood.spot_angle = 26.0
		flood.spot_attenuation = 1.1
		flood.light_cull_mask = Deck.HULL_LAYER | 1
		socket.add_child(flood)
		# Out from the hull and a little down, onto the way across.
		var out := hull.global_basis.z
		flood.look_at(flood.global_position + out - Vector3.UP * 0.35, Vector3.UP)


## A blinking lamp on `node`: its lens (the mesh `lamp`) lit in its colour, and a little light at
## `socket` reaching `reach` metres, on and off together.
func _blinker(node: Node3D, lamp: String, socket: String, spec: Array, reach: float) -> void:
	var lens := node.find_child(lamp, true, false) as MeshInstance3D
	if lens != null:
		lens.material_override = _unlit(spec[0], 2.5)
	var light := OmniLight3D.new()
	light.light_color = spec[0]
	light.light_energy = 2.0
	light.omni_range = reach
	light.light_cull_mask = Deck.HULL_LAYER | 1
	var at := node.find_child(socket, true, false) as Node3D
	(at if at != null else node).add_child(light)
	_blinking.append([lens, light, spec[1], spec[2], randf() * spec[1]])


static func _unlit(colour: Color, energy: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = UNLIT
	material.set_shader_parameter("albedo", colour)
	material.set_shader_parameter("energy", energy)
	return material


# --- Where things are ----------------------------------------------------------------------------

## The satellite a world point is inside (in one of its rooms or hatchways), or null.
static func at(world: World3D, point: Vector3) -> Satellite:
	var zone := Zone.at(world, point)
	return zone.get_parent().get_parent() as Satellite if zone != null and zone.get_parent() != null else null


## Where it stands for a LANTERN whose EVA hatch is centred at `hatch` and faces `out` into space:
## seeded off that way, 20 to 28 m, a little fore or aft, above or below, its own hatch turned to
## face the airlock's.
static func placement(plan: SatelliteLayout, hatch: Vector3, out: Vector3) -> Transform3D:
	var rng := Seeds.rng(plan.seed, "satellite/place")
	out = Vector3(out.x, 0, out.z).normalized()
	var across := Vector3.UP.cross(out).normalized()
	var mouth := hatch + out * rng.randf_range(20.0, 28.0) + across * rng.randf_range(-10.0, 6.0) + Vector3.UP * rng.randf_range(-2.0, 4.0)
	var back := hatch - mouth
	# Its hatch faces its own -X: turned so that points back at the airlock.
	var basis := Basis(Vector3.UP, atan2(back.z, -back.x))
	return Transform3D(basis, mouth - basis * Vector3(-Deck.CELL / 2, Hatch.CENTRE, 0))


# --- The hatch (reported to the host) ------------------------------------------------------------

## Host: a handle was used: the hatch opens or shuts.
func _toggle_hatch() -> void:
	if not multiplayer.is_server():
		return
	hatch_open = not hatch_open
	_state.rpc(hatch_open)


@rpc("authority", "call_remote", "reliable")
func _state(open: bool) -> void:
	hatch_open = open


## The hatch's handles: OPEN or CLOSE.
class HatchHandle extends Interactable:
	var satellite: Satellite

	func prompt(_player: Player) -> String:
		return "CLOSE" if satellite.hatch_open else "OPEN"
