class_name DerelictRooms
## The rooms a derelict is assembled from (GDD §8.2, TECH §5): hand-built modules on the 4 m grid,
## each with its footprint, the edges where it can join another (its door sockets), and how it's
## furnished. DerelictLayout grows a derelict from them; the derelict's Deck builds their walls,
## floors and ceilings in the derelict kit.
##
## A module is authored in its own space: cell (c, r) of `cells` (rows run north to south, '#' a
## cell) has its centre at (4c, 0, 4r), so cell (0, 0) is at the origin, and a wall's face stands
## 1.85 m from its cell's centre. Placed, a module turns by quarter turns about its origin.
##   kind     "entry", "corridor", "room" or "prize"
##   doors    "c,r,S": where it can join another module (N, E, S, W of cell c, r). Nothing stands in
##            a door's way: 1.25 m either side of its middle, 1.2 m into the room
##   hatch    the entry's: where the LANTERN's collar docks (W, toward the LANTERN)
##   windows  walls that are windows when nothing's beyond them
##   props    [model (under assets/models), at, yaw (degrees; 0 faces south, +Z)]; a kit rack's
##            fourth element lists what may hang on it
##   strobes  [at, yaw]: emergency strobes on the walls, each lit or not
##   scatter  [what, at, yaw]: decay that may or may not be there ("cables" from the ceiling,
##            "debris" on the deck, a "corpse": one of an earlier wave's crew)
##   spots    where loose things may lie: on the deck (y 0.05) or on furniture
##   big      where a two-handed thing may stand (the fuel cell)
##   open     clear floor, for what lives here (a Crawler on it, a Hanger above it)
##   finds    how likely each kind of find (FINDS) turns up here, against 1 elsewhere
##   weight   how often it's picked, and `most` how many a derelict has at most

const MODULES := {
	&"entry": {
		"name": "AIRLOCK", "kind": "entry", "cells": ["#"], "hatch": "0,0,W",
		"doors": ["0,0,N", "0,0,E", "0,0,S"],
		"props": [["rooms/rm_cycle_panel", Vector3(-1.73, 0, 1.6), 90.0]],
		"strobes": [[Vector3(-1.81, 2.3, -1.5), 90.0]],
		"scatter": [["cables", Vector3(0.5, 3.0, -0.6), 30.0]],
		"spots": [Vector3(1.35, 0.05, -1.35), Vector3(-1.3, 0.05, -1.3), Vector3(1.35, 0.05, 1.35)],
		"finds": {&"supplies": 1.5},
	},
	&"corridor": {
		"name": "CORRIDOR", "kind": "corridor", "cells": ["##"], "weight": 6, "most": 12,
		"doors": ["0,0,W", "1,0,E", "0,0,N", "0,0,S", "1,0,N", "1,0,S"],
		"strobes": [[Vector3(2.0, 2.3, -1.81), 0.0]],
		"scatter": [["cables", Vector3(1.4, 3.0, 0.5), 80.0], ["cables", Vector3(4.6, 3.0, -0.6), -20.0],
				["debris", Vector3(2.0, 0, 0.95), 90.0]],
		"spots": [Vector3(2.0, 0.05, -1.4), Vector3(-1.4, 0.05, 1.4), Vector3(5.4, 0.05, -1.4)],
		"open": [Vector3(4.0, 0, 0), Vector3(0, 0, 0)],
	},
	&"junction": {
		"name": "CORRIDOR", "kind": "corridor", "cells": ["#"], "weight": 3, "most": 8,
		"doors": ["0,0,N", "0,0,E", "0,0,S", "0,0,W"],
		"strobes": [[Vector3(1.55, 2.3, -1.81), 0.0]],
		"scatter": [["cables", Vector3(-0.5, 3.0, 0.4), 50.0]],
		"spots": [Vector3(-1.4, 0.05, -1.4), Vector3(1.4, 0.05, 1.4)],
		"open": [Vector3(0, 0, 0)],
	},
	&"bend": {
		"name": "CORRIDOR", "kind": "corridor", "cells": ["##", ".#"], "weight": 3, "most": 8,
		"doors": ["0,0,W", "0,0,N", "0,0,S", "1,0,N", "1,0,E", "1,1,E", "1,1,W", "1,1,S"],
		"strobes": [[Vector3(2.0, 2.3, -1.81), 0.0]],
		"scatter": [["cables", Vector3(4.3, 3.0, 2.0), 10.0]],
		"spots": [Vector3(1.6, 0.05, 1.5), Vector3(5.4, 0.05, 5.4)],
		"open": [Vector3(4.0, 0, 0)],
	},
	# Bunks along the north wall, lockers and a desk with its dead log terminal along the south.
	&"quarters": {
		"name": "CREW QUARTERS", "kind": "room", "cells": ["##"], "weight": 3, "most": 5,
		"doors": ["0,0,W", "1,0,E", "0,0,S"],
		"props": [["rooms/rm_bunk", Vector3(0, 0, -1.37), 0.0], ["rooms/rm_bunk", Vector3(4, 0, -1.37), 0.0],
				["rooms/rm_cabin_desk", Vector3(4.3, 0, 1.52), 180.0],
				["rooms/rm_suit_locker", Vector3(5.45, 0, 1.55), 180.0], ["rooms/rm_suit_locker", Vector3(2.8, 0, 1.55), 180.0]],
		"strobes": [[Vector3(2.0, 2.3, -1.81), 0.0]],
		"scatter": [["corpse", Vector3(1.8, 0.05, 0.4), 200.0], ["cables", Vector3(0.6, 3.0, 0.4), 70.0]],
		"spots": [Vector3(0.4, 0.7, -1.35), Vector3(4.4, 0.7, -1.4), Vector3(1.6, 0.05, 1.3), Vector3(3.0, 0.05, -0.2),
				Vector3(-1.3, 0.05, 1.4)],
		"open": [Vector3(2.0, 0, 0.1)],
		"finds": {&"supplies": 2.0, &"lore": 2.0, &"tools": 0.5},
	},
	# Shelving on two walls, crates stacked against the others and in the middle.
	&"cargo": {
		"name": "CARGO HOLD", "kind": "room", "cells": ["##", "##"], "weight": 3, "most": 5,
		"doors": ["0,0,W", "1,0,N", "1,1,E", "0,1,S"],
		"props": [["rooms/rm_shelf", Vector3(0, 0, -1.61), 0.0], ["rooms/rm_shelf", Vector3(-1.61, 0, 4.0), 90.0],
				["rooms/rm_crate", Vector3(3.0, 0, 5.4), 0.0], ["rooms/rm_crate", Vector3(3.85, 0, 5.42), 4.0],
				["rooms/rm_crate", Vector3(3.4, 0.8, 5.4), 20.0], ["rooms/rm_crate", Vector3(5.4, 0, 0.25), 10.0],
				["rooms/rm_crate", Vector3(5.42, 0, 1.1), -5.0], ["rooms/rm_crate", Vector3(1.7, 0, 1.8), 15.0],
				["rooms/rm_crate", Vector3(2.55, 0, 2.1), -10.0], ["rooms/rm_crate", Vector3(2.0, 0.8, 1.95), 40.0]],
		"strobes": [[Vector3(-1.81, 2.3, 4.0), 90.0], [Vector3(5.81, 2.3, -1.2), -90.0]],
		"scatter": [["cables", Vector3(2.0, 3.0, -0.4), 0.0], ["corpse", Vector3(1.2, 0.05, 0.4), 30.0]],
		"spots": [Vector3(0.35, 0.2, -1.6), Vector3(-0.6, 0.7, -1.6), Vector3(-1.6, 1.2, 3.7), Vector3(3.4, 1.65, 5.4),
				Vector3(5.42, 0.85, 1.1), Vector3(0.5, 0.05, 0.6), Vector3(4.8, 0.05, 2.0), Vector3(-0.5, 0.05, 3.0)],
		"big": [[Vector3(4.2, 0.02, 3.4), 20.0]],
		"open": [Vector3(0.6, 0, 3.2), Vector3(3.8, 0, -0.2)],
		"finds": {&"salvage": 3.0, &"power": 2.0, &"ammo": 1.5},
	},
	# The med pod against the north wall, a shelf of supplies, an O2 rack.
	&"infirmary": {
		"name": "INFIRMARY", "kind": "room", "cells": ["##"], "weight": 2, "most": 2,
		"doors": ["0,0,W", "0,0,N", "1,0,S"],
		"props": [["rooms/rm_med_pod", Vector3(4.2, 0, -0.95), 0.0], ["rooms/rm_shelf", Vector3(0, 0, 1.61), 180.0],
				["rooms/rm_o2_rack", Vector3(5.7, 0, 0.9), -90.0]],
		"strobes": [[Vector3(5.81, 2.3, -1.0), -90.0]],
		"scatter": [["corpse", Vector3(1.6, 0.05, -0.3), 120.0], ["cables", Vector3(2.0, 3.0, 0.5), 20.0]],
		"spots": [Vector3(-0.4, 0.2, 1.6), Vector3(0.35, 1.2, 1.6), Vector3(0.6, 0.7, 1.6), Vector3(3.0, 0.05, 1.2),
				Vector3(-1.4, 0.05, -1.4)],
		"open": [Vector3(2.0, 0, 0.6)],
		"finds": {&"supplies": 4.0},
	},
	# A workbench, the recycler and fabricator, and the kit board, a flare maybe still on it.
	&"workshop": {
		"name": "MACHINE SHOP", "kind": "room", "cells": ["##"], "weight": 2, "most": 2,
		"doors": ["0,0,W", "1,0,E", "1,0,N"],
		"props": [["rooms/rm_workbench", Vector3(0, 0, -1.47), 0.0], ["rooms/rm_recycler", Vector3(0.2, 0, 1.21), 180.0],
				["rooms/rm_fabricator", Vector3(4.3, 0, 1.35), 180.0],
				["rooms/rm_kit_rack", Vector3(2.2, 0.3, 1.67), 180.0, [&"flare"]]],
		"strobes": [[Vector3(1.6, 2.3, -1.81), 0.0]],
		"scatter": [["cables", Vector3(3.2, 3.0, -0.2), 40.0]],
		"spots": [Vector3(-0.5, 0.97, -1.4), Vector3(0.4, 0.97, -1.3), Vector3(2.2, 0.05, 0.2), Vector3(5.45, 0.05, 1.45)],
		"open": [Vector3(2.2, 0, -0.2)],
		"finds": {&"tools": 3.0, &"ammo": 2.0},
	},
	# The dead drive and its empty fuel rack; a section breaker on the wall.
	&"drive": {
		"name": "DRIVE ROOM", "kind": "room", "cells": ["##", "##"], "weight": 2, "most": 1,
		"doors": ["0,0,W", "1,0,N", "0,1,S"],
		"props": [["rooms/rm_drive_core", Vector3(4.3, 0, 4.3), 0.0], ["rooms/rm_fuel_rack", Vector3(0, 0, -1.45), 0.0],
				["derelict/dk_breaker", Vector3(-1.69, 0, 4.4), 90.0],
				["rooms/rm_crate", Vector3(5.42, 0, 0.3), 6.0], ["rooms/rm_crate", Vector3(5.4, 0, 1.15), -8.0]],
		"strobes": [[Vector3(2.6, 2.3, 5.81), 180.0], [Vector3(-1.81, 2.3, -1.55), 90.0]],
		"scatter": [["cables", Vector3(2.0, 3.0, 2.0), 45.0], ["debris", Vector3(1.0, 0, 3.2), 30.0],
				["corpse", Vector3(2.6, 0.05, 1.0), 300.0]],
		"spots": [Vector3(-1.3, 0.05, 2.6), Vector3(2.2, 0.05, -1.4), Vector3(5.4, 0.85, 1.15), Vector3(2.0, 0.05, 4.6)],
		"big": [[Vector3(1.5, 0.02, -1.2), 10.0]],
		"open": [Vector3(1.6, 0, 1.8)],
		"finds": {&"power": 2.0, &"tools": 1.0},
	},
	# The earlier wave's bridge: helm and science under the windows, ops and engineering on the side
	# walls, the chart table between them, all dark.
	&"control": {
		"name": "CONTROL", "kind": "room", "cells": ["##", "##"], "weight": 2, "most": 1,
		"doors": ["0,1,W", "1,1,E", "0,1,S"], "windows": ["0,0,N", "1,0,N"],
		"props": [["bridge/br_helm", Vector3(0, 0, -1.24), 0.0], ["bridge/br_science", Vector3(4.0, 0, -1.26), 0.0],
				["bridge/br_ops", Vector3(-1.44, 0, 0.3), 90.0], ["bridge/br_engineering", Vector3(5.45, 0, 0.3), -90.0],
				["bridge/br_chart_table", Vector3(2.0, 0, 2.6), 0.0]],
		"strobes": [[Vector3(4.6, 2.3, 5.81), 180.0], [Vector3(2.0, 2.3, -1.81), 0.0]],
		"scatter": [["corpse", Vector3(2.9, 0.05, 0.8), 250.0], ["cables", Vector3(0.5, 3.0, 2.8), 20.0],
				["debris", Vector3(4.4, 0, 3.6), 60.0]],
		"spots": [Vector3(1.0, 0.05, 0.3), Vector3(3.2, 0.05, 3.8), Vector3(-1.3, 0.05, 2.2), Vector3(2.3, 0.9, 2.4)],
		"open": [Vector3(2.0, 0, 0.6)],
		"finds": {&"lore": 4.0, &"ammo": 1.0},
	},
	# Suit lockers down one wall, an O2 rack and a lamp charger opposite, a bench.
	&"suits": {
		"name": "SUIT STORAGE", "kind": "room", "cells": ["#", "#"], "weight": 2, "most": 2,
		"doors": ["0,0,N", "0,1,S", "0,1,E"],
		"props": [["rooms/rm_suit_locker", Vector3(-1.55, 0, -1.45), 90.0], ["rooms/rm_suit_locker", Vector3(-1.55, 0, -0.7), 90.0],
				["rooms/rm_suit_locker", Vector3(-1.55, 0, 0.05), 90.0], ["rooms/rm_suit_locker", Vector3(-1.55, 0, 0.8), 90.0],
				["rooms/rm_suit_locker", Vector3(-1.55, 0, 3.0), 90.0], ["rooms/rm_suit_locker", Vector3(-1.55, 0, 3.75), 90.0],
				["rooms/rm_o2_rack", Vector3(1.7, 0, -0.6), -90.0], ["rooms/rm_lamp_charger", Vector3(1.67, 0, 1.0), -90.0],
				["rooms/rm_bench", Vector3(0.1, 0, 3.6), 90.0]],
		"strobes": [[Vector3(1.81, 2.3, -1.4), -90.0]],
		"scatter": [["corpse", Vector3(0.6, 0.05, 0.2), 80.0], ["cables", Vector3(0.0, 3.0, 2.0), 0.0]],
		"spots": [Vector3(1.3, 0.05, 1.6), Vector3(0.5, 0.5, 3.4), Vector3(1.2, 0.05, -1.5)],
		"open": [Vector3(0.3, 0, 0.0)],
		"finds": {&"supplies": 4.0, &"tools": 1.0},
	},
	# The Prize (GDD §8.3) on its sled, torn out of the ceiling's feeds; a dead end.
	&"prize": {
		"name": "PRIZE", "kind": "prize", "cells": ["##"],
		"doors": ["0,0,W"],
		"props": [["derelict/dk_prize_core", Vector3(4.0, 0, 0), -90.0], ["derelict/dk_cables", Vector3(5.2, 3.0, 0.2), 90.0],
				["derelict/dk_cables", Vector3(2.6, 3.0, -1.0), 10.0],
				["rooms/rm_crate", Vector3(0.9, 0, -1.4), 8.0], ["rooms/rm_crate", Vector3(0.9, 0.8, -1.4), 30.0],
				["rooms/rm_crate", Vector3(1.5, 0, 1.4), -12.0]],
		"strobes": [[Vector3(2.0, 2.3, -1.81), 0.0], [Vector3(5.0, 2.3, 1.81), 180.0]],
		"spots": [Vector3(1.5, 0.85, 1.4), Vector3(5.4, 0.05, -1.5), Vector3(5.4, 0.05, 1.5)],
		"big": [[Vector3(2.0, 0.02, 1.2), 80.0]],
		"finds": {&"ammo": 3.0, &"tools": 2.0, &"lore": 1.0},
	},
}

## What turns up, by kind of find: each kind's weight.
const FINDS := {
	&"salvage": {&"salvage_pipes": 1, &"salvage_board": 1, &"salvage_plates": 1},
	&"supplies": {&"o2_canister": 2, &"sealant": 1, &"flare": 1},
	&"lore": {&"data_core": 1},
	&"power": {&"power_cell": 1},
	&"tools": {&"shock_prod": 3, &"crowbar": 2, &"plasma_cutter": 1, &"rivet_driver": 1},
	&"ammo": {&"cartridge": 1},
}
## Where the fuel cell goes, first choice first (a module with a `big` spot).
const FUEL_ROOMS: Array[StringName] = [&"drive", &"cargo", &"prize"]

const SCATTER := {
	"cables": "derelict/dk_cables",
	"debris": "derelict/dk_debris",
	"corpse": "characters/ch_suit",
}
## How likely each kind of scatter is, where a module has a place for it.
const SCATTER_CHANCE := {"cables": 0.55, "debris": 0.4, "corpse": 0.3}
## How likely each strobe is to be lit (the Prize room's always are), and to be failing.
const STROBE_CHANCE := 0.7
const FAILING_CHANCE := 0.3


static func of(type: StringName) -> Dictionary:
	return MODULES[type]


## The module's cells, in its own space.
static func cells_of(type: StringName) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var rows: Array = MODULES[type].cells
	for r in rows.size():
		for c in rows[r].length():
			if rows[r][c] == "#":
				out.append(Vector2i(c, r))
	return out
