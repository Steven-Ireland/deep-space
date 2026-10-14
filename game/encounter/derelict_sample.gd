extends Deck
## A sample derelict docked at the LANTERN's starboard collar (GDD §8): a hand-placed stand-in for
## the generator (M4), to judge the look and feel of a dead station. Built in the derelict kit,
## unlit except for red emergency strobes; furnished with debris, cable spills, a breach, a breaker
## box, a dead crew member, alien growth with a Hanger above it, a Crawler, and the Prize; stocked
## with salvage and supplies to take back.
##
##   E entry  C corridor  R room  X side room  P prize room

const ROWS := [
	".RR.",
	"ECR.",
	".CXX",
	".PP.",
]
## Layout cell (0, 1), the entry, sits at grid (4, 0): just outside the LANTERN's collar hatch.
const ORIGIN := Vector2i(-4, 1)

const OPENINGS := {
	"0,1,W": "open", # the docking collar
	"0,1,E": "door", "1,1,N": "door", "1,2,E": "door", "1,2,S": "door",
	"1,0,N": "breach", "2,2,N": "breach",
}

const MODELS := "res://assets/models/%s.glb"


func _ready() -> void:
	kit = "dk"
	lit = false
	# The breached rooms are open to space; the rest holds the air let in through the collar.
	vacuum = "RX"
	build(PackedStringArray(ROWS), ORIGIN, OPENINGS)
	for door: Door in doors.values():
		door.open = true
	_dress()


func _dress() -> void:
	# Entry: the collar's mouth, a strobe, cables brushing the helmet.
	_strobe(Vector3(16, 2.3, -1.7), 0.0)
	_prop("derelict/dk_cables", Vector3(16.6, 3.0, 0.8), 30.0)
	# Corridor: debris, a breach, a failing strobe.
	_prop("derelict/dk_debris", Vector3(20.4, 0, 3.2), 70.0)
	_strobe(Vector3(21.7, 2.3, 4.5), -90.0, true)
	_prop("derelict/dk_cables", Vector3(19.5, 3.0, 1.5), -10.0)
	# The L-shaped room: a dead crew member by the breaker box, a Crawler waiting in the dark.
	_prop("derelict/dk_breaker", Vector3(22.0, 0, -5.8), 0.0)
	var corpse := _prop("characters/ch_suit", Vector3(21.2, 0.05, -4.6), 160.0)
	_play(corpse, "death", 1.4)
	_prop("rooms/rm_crate", Vector3(25.1, 0, -5.0), 20.0)
	_prop("rooms/rm_crate", Vector3(25.2, 0.8, -5.1), 55.0)
	var crawler := _prop("creatures/cr_crawler", Vector3(24.6, 0, -1.5), 210.0)
	_play(crawler, "idle")
	_strobe(Vector3(26.0, 2.3, -6.0 + 0.2), 180.0)
	# Side room: the growth, and the Hanger over it.
	_prop("derelict/dk_growth", Vector3(26.5, 0, 4.2), 0.0)
	var hanger := _prop("creatures/cr_hanger", Vector3(26.0, 3.0, 4.0), 0.0)
	_play(hanger, "idle")
	_prop("derelict/dk_cables", Vector3(28.3, 3.0, 5.2), 90.0)
	# Prize room: the jump core on its sled, cables still trailing.
	_prop("derelict/dk_prize_core", Vector3(22.0, 0, 8.5), 75.0)
	_strobe(Vector3(23.6, 2.3, 10.0 - 0.2), 180.0, true)
	_prop("rooms/rm_crate", Vector3(19.0, 0, 9.4), -15.0)
	# Loot: what the dead crew member had on them, salvage strewn about, a power cell by the
	# breaker, a data core left on the crates, a cartridge on the crate by the Prize.
	stock(&"o2_canister", Vector3(20.5, 0.02, -3.9), 30.0)
	stock(&"plasma_cutter", Vector3(21.9, 0.02, -3.7), 40.0)
	stock(&"power_cell", Vector3(22.8, 0.02, -5.3), 10.0)
	stock(&"data_core", Vector3(25.2, 1.62, -5.1), 0.0)
	stock(&"salvage_pipes", Vector3(19.3, 0.02, 2.6), 80.0)
	stock(&"salvage_board", Vector3(16.8, 0.02, -1.2), 25.0)
	stock(&"salvage_plates", Vector3(28.4, 0.02, 3.0), -30.0)
	stock(&"cartridge", Vector3(19.0, 0.82, 9.4), 60.0)
	stock(&"sealant", Vector3(23.8, 0.02, 9.4), 0.0)
	stock(&"fuel_cell", Vector3(20.4, 0.02, 7.3), -10.0)


func _prop(model: String, at: Vector3, yaw: float) -> Node3D:
	var node: Node3D = load(MODELS % model).instantiate()
	node.position = at
	node.rotation.y = deg_to_rad(yaw)
	add_child(node)
	_mark_interior(node)
	return node


func _strobe(at: Vector3, yaw: float, failing := false) -> void:
	var strobe := Strobe.new()
	strobe.position = at
	strobe.rotation.y = deg_to_rad(yaw)
	strobe.failing = failing
	add_child(strobe)


func _play(node: Node, clip: String, at := -1.0) -> void:
	var player := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null or not player.has_animation(clip):
		return
	player.play(clip)
	if at >= 0.0:
		player.seek(at, true)
		player.pause()
