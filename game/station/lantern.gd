extends Deck
## Deep Survey Station LANTERN (GDD §5): one deck, the bridge at its heart. Rooms branch off the
## bridge; a rear corridor of small rooms runs aft. Fore is -Z, port is -X.
##
##   B bridge        S suit room     A EVA airlock     W workshop
##   D docking port  K docking collar R drive room      C rear corridor
##   1-4 crew cabins T stores         M med bay

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
	build(PackedStringArray(ROWS), ORIGIN, OPENINGS, "M")
	# The med bay is offline until it's upgraded (GDD §5): sealed and dark.
	var med_bay: Door = doors.get("1,5,v")
	if med_bay != null:
		med_bay.sealed = true
