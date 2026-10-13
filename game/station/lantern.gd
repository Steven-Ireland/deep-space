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


func _ready() -> void:
	add_to_group(&"lantern")
	build(PackedStringArray(ROWS), ORIGIN, OPENINGS, "M")
	# The med bay is offline until it's upgraded (GDD §5): sealed and dark.
	var med_bay: Door = doors.get("1,5,v")
	if med_bay != null:
		med_bay.sealed = true
	_open_collar()
	_furnish_bridge()
	_furnish_rooms()
	_place_cameras()
	_hull_features()


## The room a world position is in, by name (for the vitals board), or OUTSIDE.
func room_at(at: Vector3) -> String:
	var cell := Vector2i(roundi(at.x / CELL), roundi(at.z / CELL))
	return ROOM_NAMES.get(cells.get(cell, ""), "OUTSIDE")


## Docked: the collar's hatch is retracted so the derelict alongside is open to walk into.
func _open_collar() -> void:
	for piece in get_children():
		if piece.name.begins_with("hatch_") and piece.position.x > 13.0:
			var door := piece.find_child("hatch_door", true, false) as Node3D
			if door != null:
				door.visible = false


## The bridge stations (GDD §5): helm and science face the viewport; ops and engineering stand
## against the aft wall; the captain's chair on its dais between them, facing fore.
func _furnish_bridge() -> void:
	_prop("br_helm", Vector3(-3.0, 0, -4.3), 0.0, [["screen_nav", "nav_screen", Vector2i(320, 240), GREEN]])
	_prop("br_science", Vector3(3.2, 0, -4.3), 0.0, [
		["screen_scan", "scan_screen", Vector2i(240, 240), GREEN],
		["screen_survey", "survey_screen", Vector2i(320, 240), GREEN]])
	var ops := [["screen_cams", "cams_screen", Vector2i(160, 120), GREEN]]
	for i in 4:
		ops.append(["screen_vitals_%d" % (i + 1), "vitals_screen", Vector2i(192, 144), GREEN, {"slot": i}])
	_prop("br_ops", Vector3(-3.4, 0, 5.3), 180.0, ops)
	_prop("br_engineering", Vector3(3.4, 0, 5.3), 180.0, [["screen_power", "power_screen", Vector2i(320, 240), AMBER]])
	_prop("br_dais", Vector3(0, 0, -0.4), 0.0, [])
	_prop("br_chair", Vector3(0, 0.16, -0.2), 180.0, [])


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
	# Suit room (-8, 0): lockers along the hull, the O2 rack opposite, a bench between.
	for i in 4:
		_prop("rm_suit_locker", Vector3(-9.125 + i * 0.75, 0, -1.55), 0.0, [])
	_prop("rm_o2_rack", Vector3(-8.0, 0, 1.7), 180.0, [])
	_prop("rm_bench", Vector3(-8.0, 0, 0.85), 0.0, [])
	_prop("rm_cycle_panel", Vector3(-9.73, 0, -1.6), 90.0, [["screen_airlock", "status_screen", Vector2i(160, 120), GREEN,
			{"title": "AIRLOCK", "lines": [["CHAMBER", "DIM"], ["PRESSURIZED", "GREEN"], ["OUTER SEALED", "GREEN"]], "prompt": "READY"}]])
	_beacon(Vector3(-12, 2.6, 0))
	# Docking port (8, 0) and collar (12, 0): the dock panel by the collar door, cargo waiting.
	_prop("rm_cycle_panel", Vector3(9.73, 0, 1.6), -90.0, [["screen_airlock", "status_screen", Vector2i(160, 120), GREEN,
			{"title": "DOCKING", "lines": [["COLLAR", "DIM"], ["RETRACTED", "AMBER"], ["NO CONTACT", "DIM"]], "prompt": "AWAITING TARGET"}]])
	_prop("rm_crate", Vector3(6.9, 0, -1.2), 10.0, [])
	_prop("rm_crate", Vector3(7.75, 0, -1.25), -6.0, [])
	_prop("rm_crate", Vector3(7.3, 0.8, -1.2), 25.0, [])
	_beacon(Vector3(12, 2.6, 0))
	# Drive room (8..12, 4): the jump drive and the fuel rack that feeds it.
	_prop("rm_drive_core", Vector3(11.6, 0, 4.0), 0.0, [])
	_prop("rm_fuel_rack", Vector3(8.0, 0, 5.45), 180.0, [])
	var core := OmniLight3D.new()
	core.light_color = Color(0.7, 1.0, 0.35)
	core.light_energy = 1.6
	core.omni_range = 6.0
	core.position = Vector3(11.6, 1.6, 4.0)
	add_child(core)
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
	# Stores (-4, 20): two racks of spares, crates.
	_prop("rm_shelf", Vector3(-4.4, 0, 18.4), 0.0, [])
	_prop("rm_shelf", Vector3(-4.4, 0, 21.6), 180.0, [])
	_prop("rm_crate", Vector3(-2.9, 0, 20.0), 30.0, [])
	# Med bay (4, 20): the pod, offline and dark until it's upgraded.
	_prop("rm_med_pod", Vector3(4.2, 0, 20.0), 0.0, [["screen_med", "status_screen", Vector2i(160, 120), Color(1, 0.3, 0.2),
			{"title": "MED POD", "lines": [["OFFLINE", "RED"], ["UPGRADE REQUIRED", "DIM"]]}]])


## The hull's hero pieces: the comms mast over the bridge, thrusters at the aft corners, the name.
func _hull_features() -> void:
	_hull_piece("hl_mast", Vector3(2.5, 3.45, 2.5), 30.0)
	_hull_piece("hl_name", Vector3(0, 3.5, -1.5), 0.0)
	_hull_piece("hl_thruster", Vector3(14.6, 1.4, 5.5), 0.0)
	_hull_piece("hl_thruster", Vector3(-14.6, 1.4, 5.5), 0.0)
	_hull_piece("hl_thruster", Vector3(2.6, 1.4, 22.6), 0.0)
	_hull_piece("hl_thruster", Vector3(-2.6, 1.4, 22.6), 0.0)


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


## Fixed station cameras (OPS's camera monitor; dead crew's eyes later).
func _place_cameras() -> void:
	for spec in [["Corridor", Vector3(0, 2.5, 6.6), Vector3(0, 0.9, 16)],
			["Docking Port", Vector3(9.5, 2.5, -1.5), Vector3(6, 0.8, 1.0)],
			["Drive Room", Vector3(13.5, 2.5, 2.5), Vector3(8.5, 0.8, 5.0)]]:
		var camera := Marker3D.new()
		camera.name = spec[0]
		camera.add_to_group(&"station_camera")
		add_child(camera)
		camera.look_at_from_position(spec[1], spec[2])
