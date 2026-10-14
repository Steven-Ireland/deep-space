extends Deck
## Deep Survey Station LANTERN (GDD §5): one deck, the bridge at its heart. Rooms branch off the
## bridge; a rear corridor of small rooms runs aft. Fore is -Z, port is -X.
##
##   B bridge        S suit room     A EVA airlock     W workshop
##   D docking port  K docking collar R drive room      C rear corridor
##   1-4 crew cabins T stores         M med bay

const ROOM_NAMES := {
	"B": "BRIDGE", "S": "SUIT ROOM", "A": "AIRLOCK", "W": "WORKSHOP", "D": "DOCKING PORT", "K": "COLLAR",
	"R": "DRIVE ROOM", "C": "CORRIDOR", "1": "CABIN 1", "2": "CABIN 2", "3": "CABIN 3", "4": "CABIN 4",
	"T": "STORES", "M": "MED BAY",
}

const BRIDGE := "res://assets/models/bridge/%s.glb"
const ROOMS := "res://assets/models/rooms/%s.glb"
const SCREENS := "res://game/terminals/screens/%s.gd"
const GREEN := Color(0.4, 1.0, 0.5)
const AMBER := Color(1.0, 0.7, 0.3)
## The lights in a jump (GDD §5): red, pulsing slowly; the fixtures' diffusers glow red with them.
const ALARM := Color(1.0, 0.12, 0.07)
const ALARM_GLOW := Color(1.0, 0.16, 0.1)
## The drive core's green glow, at rest.
const DRIVE_GLOW := 1.6

const ROWS := [
	"..BBB..",
	"ASBBBDK",
	"WWBBBRR",
	"...C...",
	"..1C2..",
	"..3C4..",
	"..TCM..",
]
## The bridge's centre cell sits at the world origin.
const ORIGIN := Vector2i(3, 1)

const OPENINGS := {
	# The forward viewport, and side ports at the bridge's fore corners.
	"2,0,N": "viewport", "3,0,N": "viewport", "4,0,N": "viewport",
	"2,0,W": "window", "4,0,E": "window",
	# Rooms off the bridge.
	"2,1,W": "door", "1,1,W": "door", "2,2,W": "door", "4,1,E": "door", "5,1,E": "door", "4,2,E": "door",
	"3,2,S": "door",
	# The rear corridor's rooms.
	"3,4,W": "door", "3,4,E": "door", "3,5,W": "door", "3,5,E": "door", "3,6,W": "door", "3,6,E": "door",
	# Looking out: the docking port, the cabins, the corridor's aft end.
	"5,1,N": "window", "2,4,W": "window", "4,4,E": "window", "2,5,W": "window", "4,5,E": "window",
	"3,6,S": "window",
	# Outer pressure hatches: the EVA airlock to port, the docking collar to starboard.
	"0,1,W": "hatch", "6,1,E": "hatch",
}

var _alarm_shown := 0.0
var _drive_glow: OmniLight3D
var _fixtures: Array[ShaderMaterial] = []
var _dock_panel: Node3D
var _cycle_panel: Node3D


func _ready() -> void:
	add_to_group(&"lantern")
	build(PackedStringArray(ROWS), ORIGIN, OPENINGS)
	_furnish_bridge()
	_furnish_rooms()
	_place_cameras()
	_hull_features()
	# The docking collar, its airlock the collar room, behind the door from the docking port.
	Collar.make(self, hatches["4,0,v"].get_parent(), _dock_panel, doors["3,0,v"], zones[Vector2i(3, 0)], _cycle_panel)
	_find_fixtures()


## The jump, aboard (GDD §5): the lights go red and pulse while the station shakes, and the drive
## core blazes.
func _process(_delta: float) -> void:
	var run := Run.of(self)
	var alarm := run.alarm() if run != null else 0.0
	if alarm == 0.0 and _alarm_shown == 0.0:
		return
	_alarm_shown = alarm
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * TAU * 0.7)
	for light in lights:
		light.light_color = light_colour.lerp(ALARM, alarm)
		light.light_energy = light_energy * lerpf(1.0, 0.55 + 0.45 * pulse, alarm)
	if _drive_glow != null:
		_drive_glow.light_energy = DRIVE_GLOW * (1.0 + 2.5 * alarm * (0.7 + 0.3 * pulse))
	for fixture in _fixtures:
		fixture.set_shader_parameter("emission_tint", Color.WHITE.lerp(ALARM_GLOW * (0.6 + 0.4 * pulse), alarm))


## The glowing materials of the ceiling fixtures (shared by every ceiling), to tint in a jump.
func _find_fixtures() -> void:
	if ceilings.is_empty():
		return
	for mesh: MeshInstance3D in ceilings[0].find_children("*", "MeshInstance3D", true, false):
		for i in mesh.get_surface_override_material_count():
			var material := mesh.get_active_material(i) as ShaderMaterial
			if material != null and material.get_shader_parameter("emission_texture") != null and material not in _fixtures:
				_fixtures.append(material)


## The room a world position is in, by name (for the vitals board), or OUTSIDE. The collar's tube,
## run out, is the COLLAR too.
func room_at(at: Vector3) -> String:
	var cell := Vector2i(roundi(at.x / CELL), roundi(at.z / CELL))
	var room: String = ROOM_NAMES.get(cells.get(cell, ""), "OUTSIDE")
	if room == "OUTSIDE":
		var collar := Collar.of(self)
		if collar != null and collar.in_tube(at):
			return ROOM_NAMES["K"]
	return room


## The bridge stations (GDD §5): helm and science face the viewport; ops and engineering stand
## against the aft wall; the chart table between them, its hologram the sector chart.
func _furnish_bridge() -> void:
	var helm := _prop("br_helm", Vector3(-3.0, 0, -4.3), 0.0, [["screen_nav", "nav_screen", Vector2i(320, 240), GREEN]])
	JumpLever.fit(helm)
	_prop("br_science", Vector3(3.2, 0, -4.3), 0.0, [
		["screen_scan", "scan_screen", Vector2i(240, 240), GREEN],
		["screen_survey", "survey_screen", Vector2i(320, 240), GREEN]])
	var ops := [["screen_cams", "cams_screen", Vector2i(160, 120), GREEN]]
	for i in 4:
		ops.append(["screen_vitals_%d" % (i + 1), "vitals_screen", Vector2i(192, 144), GREEN, {"slot": i}])
	_prop("br_ops", Vector3(-3.4, 0, 5.3), 180.0, ops)
	_prop("br_engineering", Vector3(3.4, 0, 5.3), 180.0, [["screen_power", "power_screen", Vector2i(320, 240), AMBER]])
	var table := _prop("br_chart_table", Vector3(0, 0, -0.4), 0.0, [])
	table.find_child("SOCKET_holo", true, false).add_child(ChartTable.new())


## A bridge prop at `at`, turned `yaw` degrees, with live terminals on its screens:
## each [screen mesh, screen script, resolution, glow colour, (settings)].
func _prop(model: String, at: Vector3, yaw: float, terminals: Array) -> Node3D:
	var path := BRIDGE % model if model.begins_with("br_") else ROOMS % model
	var prop: Node3D = load(path).instantiate()
	prop.position = at
	prop.rotation.y = deg_to_rad(yaw)
	add_child(prop)
	for spec: Array in terminals:
		var terminal := Terminal.new()
		terminal.name = "Terminal_" + spec[0]
		terminal.screen_mesh_name = spec[0]
		terminal.screen_script = load(SCREENS % spec[1])
		terminal.resolution = spec[2]
		terminal.glow = spec[3]
		if spec.size() > 4:
			terminal.screen_settings = spec[4]
		prop.add_child(terminal)
	_mark_interior(prop)
	return prop


## Every other room's furnishings (GDD §5). Positions are world metres: a cell's centre is its grid
## coordinate times 4; walls stand 2 m either side, 0.15 m thick.
func _furnish_rooms() -> void:
	# Suit room (-8, 0): lockers along the aft wall, the O2 rack opposite, a bench between. The
	# airlock's cycle panel beside the hatch stays in clear view of the room.
	for i in 4:
		_prop("rm_suit_locker", Vector3(-9.125 + i * 0.75, 0, 1.55), 180.0, [])
	_wall_point(_prop("rm_o2_rack", Vector3(-8.0, 0, -1.7), 0.0, []), "REFILL", Vector3(0, 1.1, 0.16), Vector2(1.4, 1.4), "o2")
	_wall_point(_prop("rm_lamp_charger", Vector3(-6.6, 0, -1.67), 0.0, []), "CHARGE", Vector3(0, 1.4, -0.03), Vector2(0.4, 0.6), "lamp")
	_prop("rm_bench", Vector3(-8.0, 0, -0.85), 0.0, [])
	_prop("rm_cycle_panel", Vector3(-9.73, 0, -1.6), 90.0, [["screen_airlock", "status_screen", Vector2i(160, 120), GREEN,
			{"title": "AIRLOCK", "lines": [["CHAMBER", "DIM"], ["PRESSURIZED", "GREEN"], ["OUTER SEALED", "GREEN"]], "prompt": "READY"}]])
	_beacon(Vector3(-12, 2.6, 0))
	# Docking port (8, 0) and collar (12, 0): the dock panel by the collar's airlock door, cargo
	# waiting; inside the collar room (the airlock's chamber), its cycle panel by the outer hatch.
	_dock_panel = _prop("rm_dock_panel", Vector3(9.71, 0, 1.6), -90.0, [["screen_dock", "dock_screen", Vector2i(192, 144), GREEN]])
	_cycle_panel = _prop("rm_cycle_panel", Vector3(13.73, 0, 1.6), -90.0, [["screen_airlock", "airlock_screen", Vector2i(160, 120), GREEN]])
	_prop("rm_crate", Vector3(6.9, 0, -1.2), 10.0, [])
	_prop("rm_crate", Vector3(7.75, 0, -1.25), -6.0, [])
	_prop("rm_crate", Vector3(7.3, 0.8, -1.2), 25.0, [])
	# The kit rack on the aft wall, passed on the way out: the crew's one crowbar and one flare.
	var kit := _prop("rm_kit_rack", Vector3(8.4, 0.3, 1.67), 180.0, [])
	for kind in [&"crowbar", &"flare"]:
		rack(kind, (kit.find_child("SOCKET_rack_%s" % kind, true, false) as Node3D).global_transform)
	stock(&"power_cell", Vector3(8.6, 0.0, -1.35), -20.0)
	_beacon(Vector3(12, 2.6, 0))
	# Drive room (8..12, 4): the jump drive and the fuel rack that feeds it, loaded with the run's
	# cells.
	_prop("rm_drive_core", Vector3(11.6, 0, 4.0), 0.0, [])
	_prop("rm_fuel_rack", Vector3(8.0, 0, 5.45), 180.0, []).add_child(FuelRack.new())
	_drive_glow = OmniLight3D.new()
	_drive_glow.name = "DriveGlow"
	_drive_glow.light_color = Color(0.7, 1.0, 0.35)
	_drive_glow.light_energy = DRIVE_GLOW
	_drive_glow.omni_range = 6.0
	_drive_glow.position = Vector3(11.6, 1.6, 4.0)
	add_child(_drive_glow)
	# Workshop (-12..-8, 4): recycler, fabricator, workbench.
	_prop("rm_recycler", Vector3(-13.3, 0, 3.4), 90.0, [["screen_salvage", "status_screen", Vector2i(160, 96), AMBER,
			{"title": "SALVAGE", "figure": "0000"}]])
	_prop("rm_fabricator", Vector3(-11.0, 0, 5.35), 180.0, [["screen_fab", "status_screen", Vector2i(160, 120), GREEN,
			{"title": "FABRICATOR", "lines": [["SALVAGE  0", "AMBER"], ["NO PLANS", "DIM"]], "prompt": "INSERT SALVAGE"}]])
	_prop("rm_workbench", Vector3(-8.4, 0, 2.53), 0.0, [])
	_prop("rm_crate", Vector3(-13.2, 0, 5.3), 15.0, [])
	# Cabins: a bunk along one wall, a desk with the crew's log terminal opposite.
	for cabin in [[-4, 12, 1], [4, 12, 2], [-4, 16, 3], [4, 16, 4]]:
		var x: float = cabin[0]
		var z: float = cabin[1]
		_prop("rm_bunk", Vector3(x - 0.4 * signf(x), 0, z - 1.37), 0.0, [])
		_prop("rm_cabin_desk", Vector3(x - 0.3 * signf(x), 0, z + 1.52), 180.0, [["screen_log", "status_screen", Vector2i(160, 120), GREEN,
				{"title": "CREW %d" % cabin[2], "lines": [["PERSONAL LOG", "DIM"], ["DAY 0001", "GREEN"], ["NO ENTRIES", "DIM"]], "prompt": "_"}]])
	# Stores (-4, 20): two racks of spares, crates. O2 canisters stand on the fore rack's bottom
	# shelf, sealant on its third, for the taking.
	_prop("rm_shelf", Vector3(-4.4, 0, 18.4), 0.0, [])
	_prop("rm_shelf", Vector3(-4.4, 0, 21.6), 180.0, [])
	_prop("rm_crate", Vector3(-2.9, 0, 20.0), 30.0, [])
	for i in 3:
		stock(&"o2_canister", Vector3(-5.1 + i * 0.25, 0.17, 18.42), 10.0 * i)
		stock(&"sealant", Vector3(-4.25 + i * 0.16, 1.17, 18.45), -15.0 * i)
	# Med bay (4, 20): the pod, where the dead come back (online from the start, for now: GDD §17).
	MedBay.make(_prop("rm_med_pod", Vector3(4.2, 0, 20.0), 0.0, [["screen_med", "med_screen", Vector2i(160, 120), GREEN]]))


## Where crew top up their suit (GDD §5, §9): `verb` across the front of `fitting` (`size`, at
## `centre` in its own space), topping up `what` (Player.top_up: "o2" at the O2 rack, "lamp" at
## the lamp charger).
func _wall_point(fitting: Node3D, verb: String, centre: Vector3, size: Vector2, what: String) -> void:
	var point := Interactable.new()
	point.name = verb.capitalize()
	point.verb = verb
	point.housing = fitting
	point.position = centre
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, size.y, 0.06)
	shape.shape = box
	point.add_child(shape)
	fitting.add_child(point)
	point.used.connect(func(peer: int):
		var player := Player.of_peer(get_tree(), peer)
		if player != null:
			player.top_up.rpc_id(peer, what))


## The hull's hero pieces: the comms mast over the bridge, the name, and thruster pods on the aft
## faces of the wings and the stern (each stands 0.95 m off the plating, which is 0.56 m out from
## the wall line; art/blender/hull.py).
func _hull_features() -> void:
	_hull_piece("hl_mast", Vector3(2.5, 3.48, 2.5), 30.0)
	_hull_piece("hl_name", Vector3(0, 3.53, -1.5), 0.0)
	for x in [11.0, -11.0]:
		_hull_piece("hl_thruster", Vector3(x, 1.4, 6.0 + 0.56 + 0.95), 0.0)
	for x in [2.6, -2.6]:
		_hull_piece("hl_thruster", Vector3(x, 1.4, 22.0 + 0.56 + 0.95), 0.0)


func _hull_piece(model: String, at: Vector3, yaw: float) -> void:
	var piece: Node3D = load("res://assets/models/hull/%s.glb" % model).instantiate()
	piece.position = at
	piece.rotation.y = deg_to_rad(yaw)
	add_child(piece)
	for mesh: VisualInstance3D in piece.find_children("*", "VisualInstance3D", true, false):
		mesh.layers = HULL_LAYER


func _beacon(at: Vector3) -> void:
	var beacon := Beacon.new()
	beacon.position = at
	add_child(beacon)


## Fixed station cameras (OPS's camera monitor; dead crew's eyes, GDD §11).
func _place_cameras() -> void:
	for spec in [["Bridge", Vector3(4.8, 2.6, 5.5), Vector3(-1.5, 0.8, -3.0)],
			["Corridor", Vector3(0, 2.5, 6.6), Vector3(0, 0.9, 16)],
			["Docking Port", Vector3(9.5, 2.5, -1.5), Vector3(6, 0.8, 1.0)],
			["Collar", Vector3(10.6, 2.5, -1.5), Vector3(13.6, 1.0, 0.6)],
			["Drive Room", Vector3(13.5, 2.5, 2.5), Vector3(8.5, 0.8, 5.0)],
			["Med Bay", Vector3(2.5, 2.5, 21.5), Vector3(4.8, 0.5, 19.6)]]:
		var camera := Marker3D.new()
		camera.name = spec[0]
		camera.add_to_group(&"station_camera")
		add_child(camera)
		camera.look_at_from_position(spec[1], spec[2])
