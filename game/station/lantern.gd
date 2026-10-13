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
}


func _ready() -> void:
	add_to_group(&"lantern")
	build(PackedStringArray(ROWS), ORIGIN, OPENINGS, "M")
	# The med bay is offline until it's upgraded (GDD §5): sealed and dark.
	var med_bay: Door = doors.get("1,5,v")
	if med_bay != null:
		med_bay.sealed = true
	_furnish_bridge()
	_place_cameras()


## The room a world position is in, by name (for the vitals board), or OUTSIDE.
func room_at(at: Vector3) -> String:
	var cell := Vector2i(roundi(at.x / CELL), roundi(at.z / CELL))
	return ROOM_NAMES.get(cells.get(cell, ""), "OUTSIDE")


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
	var prop: Node3D = load(BRIDGE % model).instantiate()
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
