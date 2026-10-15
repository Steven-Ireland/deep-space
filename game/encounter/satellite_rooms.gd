class_name SatelliteRooms
## The rooms a relay satellite is assembled from (GDD §8.1, §8.3; TECH §5): hand-built modules on
## the 4 m grid, the same kind of data as DerelictRooms, grown into a satellite by SatelliteLayout
## (RoomLayout's way). A satellite is an earlier wave's relay in working order: unmanned, lit, clean,
## airless and weightless, its levels joined by hatchways through floors and ceilings, so a module's
## socket may lead up (U) or down (D) as well as through a wall. Its Deck builds them in the
## satellite kit (sk_*).
##
## Module space as in DerelictRooms: cell (c, r) of `cells` has its centre at (4c, 0, 4r); a module
## of several `levels` has level l's cells PITCH (4 m) higher. A wall's face stands 1.85 m from its
## cell's centre; a wall prop's origin stands 0.13 m plus its own back off the wall line (2 m).
##   kind     "entry", "corridor", "room" or "prize"
##   doors    "c,r,S" or "c,r,S,l": where it can join another (N, E, S, W, or U, D through the
##            ceiling or the floor). Nothing stands in a door's way (1.25 m either side, 1.2 m in),
##            nor under a hatchway's ring (1.1 m round its cell's middle)
##   hatch    the entry's: where crew come aboard from the LANTERN (W, toward it)
##   windows  walls that are windows when nothing's beyond them
##   props    [model (under assets/models), at, yaw (degrees; 0 faces south, +Z)]
##   spots    where loose things may be: weightless, they hang where they were left, on the deck,
##            on furniture or in mid-air
##   big      where a two-handed thing may be (the fuel cell)
##   finds    how likely each kind of find (FINDS) turns up here, against 1 elsewhere
##   weight   how often it's picked, and `most` how many a satellite has at most

const MODULES := {
	# Where crew come aboard: the EVA hatch to the west, the hatch's control panel beside it, and a
	# way on through every other wall, the ceiling and the floor.
	&"entry": {
		"name": "EVA HATCH", "kind": "entry", "cells": ["#"], "hatch": "0,0,W",
		"doors": ["0,0,N", "0,0,E", "0,0,S", "0,0,U", "0,0,D"],
		"props": [["rooms/rm_cycle_panel", Vector3(-1.73, 0, 1.6), 90.0]],
		"spots": [Vector3(1.35, 0.05, -1.35), Vector3(1.3, 1.5, 1.3)],
		"finds": {&"supplies": 1.5},
	},
	# A junction with a way through every face: the satellite's spine is built of them.
	&"node": {
		"name": "NODE", "kind": "corridor", "cells": ["#"], "weight": 5, "most": 6,
		"doors": ["0,0,N", "0,0,E", "0,0,S", "0,0,W", "0,0,U", "0,0,D"],
		"spots": [Vector3(1.4, 1.6, -1.4), Vector3(-1.4, 0.05, 1.4)],
	},
	&"passage": {
		"name": "PASSAGE", "kind": "corridor", "cells": ["##"], "weight": 2, "most": 4,
		"doors": ["0,0,W", "1,0,E", "0,0,N", "0,0,S", "1,0,N", "1,0,S"],
		"spots": [Vector3(2.0, 0.05, -1.4), Vector3(4.0, 1.8, 0.0), Vector3(1.5, 1.2, 1.5)],
	},
	# Two levels tall, a hatchway between: the way up and down, with doors off it on both.
	&"shaft": {
		"name": "SHAFT", "kind": "corridor", "levels": [["#"], ["#"]], "weight": 3, "most": 3,
		"doors": ["0,0,D,0", "0,0,N,0", "0,0,E,0", "0,0,S,0", "0,0,W,0", "0,0,U,1", "0,0,N,1", "0,0,E,1", "0,0,S,1", "0,0,W,1"],
		"spots": [Vector3(1.4, 1.2, 1.4), Vector3(-1.4, 5.5, -1.4)],
	},
	# Racks of relay electronics down both long walls, humming and blinking: salvage.
	&"equipment": {
		"name": "EQUIPMENT BAY", "kind": "room", "cells": ["##"], "weight": 3, "most": 3,
		"doors": ["0,0,W", "1,0,E", "1,0,U"],
		"props": [["satellite/sp_rack", Vector3(0.3, 0, -1.57), 0.0], ["satellite/sp_rack", Vector3(1.3, 0, -1.57), 0.0],
				["satellite/sp_rack", Vector3(2.7, 0, -1.57), 0.0], ["satellite/sp_rack", Vector3(3.7, 0, -1.57), 0.0],
				["satellite/sp_rack", Vector3(0.3, 0, 1.57), 180.0], ["satellite/sp_rack", Vector3(1.3, 0, 1.57), 180.0],
				["satellite/sp_rack", Vector3(2.7, 0, 1.57), 180.0]],
		"spots": [Vector3(2.0, 0.05, 0.0), Vector3(-0.4, 1.5, 0.0), Vector3(5.3, 0.05, 1.4), Vector3(4.4, 1.9, 1.2)],
		"finds": {&"salvage": 3.0, &"lore": 1.0},
	},
	# The relay's batteries, a bank against each wall.
	&"power": {
		"name": "POWER BAY", "kind": "room", "cells": ["#"], "weight": 2, "most": 2,
		"doors": ["0,0,W", "0,0,E", "0,0,D"],
		"props": [["satellite/sp_battery", Vector3(0, 0, -1.57), 0.0], ["satellite/sp_battery", Vector3(0, 0, 1.57), 180.0]],
		"spots": [Vector3(1.5, 0.05, 1.4), Vector3(0.3, 1.6, 1.15), Vector3(0.0, 1.05, -1.45)],
		"finds": {&"power": 4.0, &"salvage": 1.0},
	},
	# The relay's own console under its windows, live: what it hears and passes on.
	&"telemetry": {
		"name": "TELEMETRY", "kind": "room", "cells": ["##"], "weight": 2, "most": 1,
		"doors": ["0,0,W", "1,0,E", "1,0,S"], "windows": ["0,0,N", "1,0,N"],
		"props": [["satellite/sp_console", Vector3(2.0, 0, -1.52), 0.0], ["satellite/sp_rack", Vector3(0.0, 0, 1.57), 180.0],
				["satellite/sp_rack", Vector3(1.0, 0, 1.57), 180.0]],
		"spots": [Vector3(2.5, 1.0, -1.35), Vector3(-0.5, 0.05, 1.0), Vector3(4.0, 1.6, -0.2)],
		"finds": {&"lore": 4.0, &"ammo": 0.5},
	},
	# Maintenance stores: a working O2 rack, and cargo netting over spares.
	&"stowage": {
		"name": "STOWAGE", "kind": "room", "cells": ["#"], "weight": 2, "most": 2,
		"doors": ["0,0,N", "0,0,W", "0,0,U"],
		"props": [["rooms/rm_o2_rack", Vector3(1.7, 0, 0.3), -90.0], ["satellite/sp_stowage", Vector3(0.0, 0, 1.7), 180.0]],
		"spots": [Vector3(-1.3, 0.05, 1.3), Vector3(0.9, 1.5, 0.9), Vector3(1.3, 0.05, -1.3)],
		"finds": {&"supplies": 4.0},
	},
	# Station-keeping propellant: two spherical tanks in their cradles against the north wall, fed
	# from it; room for a fuel cell.
	&"propellant": {
		"name": "PROPELLANT", "kind": "room", "cells": ["##"], "weight": 2, "most": 1,
		"doors": ["0,0,W", "1,0,N", "1,0,S"],
		"props": [["satellite/sp_tank", Vector3(0.1, 0, -1.0), 0.0], ["satellite/sp_tank", Vector3(2.0, 0, -1.0), 0.0]],
		"spots": [Vector3(5.4, 0.05, 1.4), Vector3(-1.4, 0.05, -1.4), Vector3(1.05, 1.9, 1.3)],
		"big": [[Vector3(4.2, 0.02, 0.0), 80.0]],
		"finds": {&"power": 1.5, &"salvage": 1.0},
	},
	# The antenna's feed: waveguides rising from their switching gear into the ceiling, to the dish.
	&"feed": {
		"name": "FEED ROOM", "kind": "room", "cells": ["#"], "weight": 2, "most": 2,
		"doors": ["0,0,W", "0,0,E"],
		"props": [["satellite/sp_feed", Vector3(0, 0, 0), 0.0]],
		"spots": [Vector3(1.3, 0.05, -1.4), Vector3(-1.3, 1.6, 1.4), Vector3(0.0, 0.05, 1.4)],
		"finds": {&"salvage": 2.5},
	},
	# Where a maintenance crew once slept: a sleeping restraint on the wall, a desk and its log.
	&"shelter": {
		"name": "SHELTER", "kind": "room", "cells": ["#"], "weight": 1, "most": 1,
		"doors": ["0,0,S", "0,0,W"],
		"props": [["satellite/sp_bunk", Vector3(0.3, 0, -1.72), 0.0], ["rooms/rm_cabin_desk", Vector3(1.52, 0, -0.2), -90.0]],
		"spots": [Vector3(-0.6, 0.05, -1.2), Vector3(1.3, 0.85, 0.4), Vector3(0.0, 1.7, 0.6)],
		"finds": {&"supplies": 2.0, &"lore": 2.0},
	},
	# The relay core (the Prize, GDD §8.3): the machine the whole satellite serves, glowing in its
	# vault at the far end, its racks of data around it; a dead end. A survey core stands at its foot
	# (`core`): the charts it's been relaying.
	&"prize": {
		"name": "RELAY CORE", "kind": "prize", "cells": ["##"],
		"doors": ["0,0,W"],
		"props": [["satellite/sp_core", Vector3(4.2, 0, 0), -90.0], ["satellite/sp_rack", Vector3(1.6, 0, -1.57), 0.0],
				["satellite/sp_rack", Vector3(2.6, 0, -1.57), 0.0], ["satellite/sp_rack", Vector3(2.6, 0, 1.57), 180.0]],
		"spots": [Vector3(5.4, 0.05, -1.5), Vector3(5.4, 0.05, 1.5), Vector3(0.6, 1.5, -1.0), Vector3(2.9, 1.3, 0.2)],
		"big": [[Vector3(1.0, 0.02, 1.2), 80.0]],
		"core": [Vector3(3.05, 0.0, 0.0), -90.0],
		"finds": {&"lore": 3.0, &"tools": 2.0, &"ammo": 1.5},
	},
}

## What turns up, by kind of find: each kind's weight.
const FINDS := {
	&"salvage": {&"salvage_board": 3, &"salvage_pipes": 1, &"salvage_plates": 1},
	&"supplies": {&"o2_canister": 3, &"sealant": 2, &"flare": 1},
	&"lore": {&"data_core": 1},
	&"power": {&"power_cell": 1},
	&"tools": {&"crowbar": 1, &"shock_prod": 1, &"plasma_cutter": 1},
	&"ammo": {&"cartridge": 1},
}
## Where a fuel cell goes, when the satellite has one, first choice first (a module with a `big`
## spot).
const FUEL_ROOMS: Array[StringName] = [&"propellant", &"prize"]
## How likely a satellite is to have a fuel cell aboard.
const FUEL_CHANCE := 0.5


static func of(type: StringName) -> Dictionary:
	return MODULES[type]


## The module's cells, in its own space (c, level, r).
static func cells_of(type: StringName) -> Array[Vector3i]:
	return RoomLayout.cells_in(MODULES[type])
