class_name Run
extends Node
## The run (GDD §4–7, TECH §2): its seed, the sector being crossed and where the LANTERN is in it,
## what the Nav Chart shows, the route plotted, the cells in the drive room's fuel rack, what the
## science station has scanned and surveyed, and the jump under way. The host owns it and sends
## all of it to everyone whenever it changes, and to each crew member who joins. Every peer charts
## the sector and builds each star system from the seed itself, and tells the host its checksum,
## so a peer that drew something different shows up.
##
## Crew report what they do at the stations (plot a route, start a scan or a survey, load a cell,
## pull the Jump Lever); the host applies it, refusing only what conflicts with how things stand.
## Each peer shows the world the run says the LANTERN is in: that system's star and planets, the
## derelict alongside if there is one (the sample derelict, a stand-in until the generator and
## docking, M4), or hyperspace in the middle of a jump.

## Something in the run changed (on every peer, after the host's word arrives).
signal changed

const NOWHERE := Vector2i(-1, -1)
## The route on from a sector's boss: the next sector's departure.
const NEXT_SECTOR := Vector2i(0, SectorMap.BOSS_ROW + 1)
const SECTORS := 3
## Bays in the drive room's fuel rack, all loaded at the start of a run (GDD §6).
const BAYS := 3
## Seconds the long-range scan takes, a planet survey, and skimming fuel or drawing it at a depot.
const SCAN_TIME := 8.0
const SURVEY_TIME := 5.0
const REFUEL_TIME := 20.0
## A jump, lever to arrival (GDD §5): SPOOL seconds of the drive winding up (the station shakes,
## the lights go red), the tunnel, and ARRIVAL seconds coming out into the new system. The whole
## lasts between JUMP_TIME's two figures, rolled for each jump.
const JUMP_TIME := Vector2(10.0, 20.0)
const SPOOL := 3.0
const ARRIVAL := 2.0

const SAMPLE_DERELICT := preload("res://game/encounter/derelict_sample.gd")

## Where the world is shown: the star system and the encounter alongside the station.
@export var system: StarSystem
@export var encounter: Node3D

var seed := 0
var sector := 1
var map: SectorMap
## The node the LANTERN is at.
var at := SectorMap.start()
## The node plotted for the next jump, or NOWHERE.
var route := NOWHERE
## Nodes on the Nav Chart: the boss from the start, every system visited, and what scans revealed.
var charted: Array[Vector2i] = []
## The systems visited this sector, in order.
var visited: Array[Vector2i] = []
## Whether this system's long-range scan has run, and how long it has left if it's running.
var scanned := false
var scan_left := 0.0
## The fuel rack's bays: whether each holds a cell.
var fuel: Array[bool] = []
## This system's planets surveyed (their indices), the one being surveyed and how long it has left,
## and the Survey Data gathered this run.
var surveyed: Array[int] = []
var survey_target := -1
var survey_left := 0.0
var survey_data := 0
## Whether this system's gas giant has been skimmed (or its depot drawn on), and how long the one
## under way has left.
var refuelled := false
var refuel_left := 0.0
## The jump under way: where to, how long it has left, and how long it lasts.
var jump_to := NOWHERE
var jump_left := 0.0
var jump_time := 0.0

var started := false
# Host: whether a scan or a refuel is under way (their timers run down on every peer; only the host
# finishes them).
var _scanning := false
var _refuelling := false
# What the world shows: the node built, or NOWHERE for hyperspace.
var _shown := NOWHERE
var _shown_sector := 0


static func of(node: Node) -> Run:
	return node.get_tree().get_first_node_in_group(&"run") as Run


func _ready() -> void:
	add_to_group(&"run")
	NetworkEvents.on_server_start.connect(_begin)
	NetworkEvents.on_peer_join.connect(func(peer: int):
		if multiplayer.is_server() and started:
			_state.rpc_id(peer, _pack()))


## Host: a fresh run, from `--run-seed` or a new seed.
func _begin() -> void:
	seed = int(Args.value("--run-seed", str(randi())))
	sector = 1
	map = SectorMap.generate(seed, sector)
	at = SectorMap.start()
	charted.assign([at, SectorMap.boss()])
	visited.assign([at])
	fuel.assign([true, true, true])
	started = true
	print("Run: seed %d." % seed)
	_broadcast()
	_dev_flags()


## Dev flags (Dev): `--scanned` starts with this system scanned; `--route` with the first jump
## plotted too; `--jump` jumps along it a second in (whoever's where).
func _dev_flags() -> void:
	if Args.flag("--scanned") or Args.flag("--route") or Args.flag("--jump"):
		_finish_scan()
	if Args.flag("--route") or Args.flag("--jump"):
		route = jumps()[0]
		_broadcast()
	if Args.flag("--jump"):
		await get_tree().create_timer(1.0).timeout
		jump()


func _process(delta: float) -> void:
	if not started:
		return
	scan_left = maxf(0.0, scan_left - delta)
	survey_left = maxf(0.0, survey_left - delta)
	refuel_left = maxf(0.0, refuel_left - delta)
	jump_left = maxf(0.0, jump_left - delta)
	_show_world()
	if not multiplayer.is_server():
		return
	if survey_target >= 0 and survey_left <= 0.0:
		_finish_survey()
	elif jump_to != NOWHERE and jump_left <= 0.0:
		_arrive()
	elif scan_left <= 0.0 and _scanning:
		_finish_scan()
	elif refuel_left <= 0.0 and _refuelling:
		_finish_refuel()


# --- Reading the run -------------------------------------------------------------------------

## The node type here (SectorMap.TYPES), "start" or "boss".
func here() -> StringName:
	return map.type_of(at) if map != null else &""


## Where a jump from here can go: the next row's systems, or on from the boss to the next sector.
func jumps() -> Array[Vector2i]:
	if map == null:
		return []
	if at == SectorMap.boss():
		var on: Array[Vector2i] = []
		if sector < SECTORS:
			on.append(NEXT_SECTOR)
		return on
	return map.next_of(at)


func fuel_left() -> int:
	return fuel.count(true)


## Whether a jump is under way.
func jumping() -> bool:
	return jump_to != NOWHERE


## Seconds into the jump under way.
func jump_elapsed() -> float:
	return jump_time - jump_left


## Whether the station is in the tunnel (between spooling up and arriving).
func in_tunnel() -> bool:
	return jumping() and jump_elapsed() >= SPOOL and jump_left > ARRIVAL


## Why the Jump Lever won't engage now, or "" when it will (GDD §5): a route plotted, a cell
## loaded, and everyone aboard (the collar seals behind them).
func jump_blocker() -> String:
	if not started:
		return "NO DRIVE"
	if jumping():
		return "JUMPING"
	if route == NOWHERE:
		return "NO ROUTE"
	if fuel_left() == 0:
		return "NO FUEL"
	if _refuelling:
		return "REFUELLING"
	if not _crew_aboard():
		return "CREW OFF STATION"
	return ""


## How hard the station shakes now, 0..1: building as the drive spools, a rumble through the
## tunnel, a lurch on arrival.
func shake() -> float:
	if not jumping():
		return 0.0
	var t := jump_elapsed()
	if t < SPOOL:
		return 0.15 + 0.6 * (t / SPOOL) * (t / SPOOL)
	if jump_left > ARRIVAL:
		return 0.18 + 0.5 * maxf(0.0, 1.0 - (t - SPOOL) / 0.6)
	return 0.7 * (jump_left / ARRIVAL)


## How red the station's lights are now, 0..1 (GDD §5: the lights go red for the jump).
func alarm() -> float:
	if not jumping():
		return 0.0
	var t := jump_elapsed()
	return clampf(minf(t / 0.6, jump_left / 1.0), 0.0, 1.0)


## How bright the flash is at the tunnel's mouth, going in and coming out, 0..1.
func flash() -> float:
	if not jumping():
		return 0.0
	var into := absf(jump_elapsed() - SPOOL)
	var out := absf(jump_left - ARRIVAL)
	return clampf(1.0 - minf(into, out) / 0.5, 0.0, 1.0)


## The star system's seed at `node` of `chart` (`--system-seed` overrides the run's first).
func system_seed(node: Vector2i, chart: SectorMap = null) -> int:
	if chart == null:
		chart = map
	if node == SectorMap.start() and chart.sector == 1 and Args.flag("--system-seed"):
		return int(Args.value("--system-seed", "1"))
	return chart.node(node).get("seed", 0)


## What the long-range scan identifies here (GDD §6): the oddity's name, and what it is.
func oddity() -> Array[String]:
	return Oddities.of(here(), system_seed(at), system)


## A checksum of what this peer generated: the chart and the system shown.
func checksum() -> int:
	return hash([map.checksum() if map != null else 0, system.checksum() if system != null else 0])


# --- Crew at the stations (reported to the host) ---------------------------------------------

## The Nav Chart: plot the next jump to `node` (one of jumps(), charted).
func plot(node: Vector2i) -> void:
	_plot.rpc_id(1, node)


@rpc("any_peer", "call_local", "reliable")
func _plot(node: Vector2i) -> void:
	if multiplayer.is_server() and not jumping() and node in jumps() and (node in charted or (node == NEXT_SECTOR and scanned)):
		route = node
		_broadcast()


## The long-range scanner: scan this system.
func scan() -> void:
	_scan.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _scan() -> void:
	if multiplayer.is_server() and not scanned and not _scanning and not jumping():
		_scanning = true
		scan_left = SCAN_TIME
		_broadcast()


func scanning() -> bool:
	return scan_left > 0.0 or _scanning


func _finish_scan() -> void:
	_scanning = false
	scanned = true
	print("Run: scanned %s; jumps to %s." % [at, jumps()])
	for node in jumps():
		if node != NEXT_SECTOR and node not in charted:
			charted.append(node)
	_broadcast()


## The Survey Console: survey planet `planet` of this system.
func survey(planet: int) -> void:
	_survey.rpc_id(1, planet)


@rpc("any_peer", "call_local", "reliable")
func _survey(planet: int) -> void:
	if not multiplayer.is_server() or survey_target >= 0 or jumping() or planet in surveyed:
		return
	if planet < 0 or planet >= system.planets.size():
		return
	survey_target = planet
	survey_left = SURVEY_TIME
	_broadcast()


func _finish_survey() -> void:
	if survey_target < system.planets.size():
		surveyed.append(survey_target)
		survey_data += system.planets[survey_target].traits.data
	survey_target = -1
	_broadcast()


## Engineering: skim fuel from this system's gas giant, or draw it from its depot, into an empty
## bay; once a system.
func refuel() -> void:
	_refuel.rpc_id(1)


func can_refuel() -> bool:
	return SectorMap.info(here()).get("refuel", false) and not refuelled and not jumping() and fuel_left() < BAYS


func refuelling() -> bool:
	return refuel_left > 0.0 or _refuelling


@rpc("any_peer", "call_local", "reliable")
func _refuel() -> void:
	if multiplayer.is_server() and can_refuel() and not _refuelling:
		_refuelling = true
		refuel_left = REFUEL_TIME
		_broadcast()


func _finish_refuel() -> void:
	_refuelling = false
	refuelled = true
	var bay := fuel.find(false)
	if bay >= 0:
		fuel[bay] = true
	_broadcast()


## The fuel rack: a crew member has put the cell they carried into `bay`. If it's been filled in
## the meantime, the cell is set down in front of it instead.
func load_cell(bay: int, spill: Transform3D) -> void:
	_load_cell.rpc_id(1, bay, spill)


@rpc("any_peer", "call_local", "reliable")
func _load_cell(bay: int, spill: Transform3D) -> void:
	if not multiplayer.is_server():
		return
	if bay >= 0 and bay < fuel.size() and not fuel[bay]:
		fuel[bay] = true
		_broadcast()
	else:
		LooseItems.of(self).put(Items.make(&"fuel_cell"), spill)


## Host: the Jump Lever has been held: the drive burns a cell and the station jumps to the route.
func jump() -> void:
	if not multiplayer.is_server() or jump_blocker() != "":
		return
	var bay := fuel.rfind(true)
	fuel[bay] = false
	jump_to = route
	route = NOWHERE
	var roll := Seeds.rng(seed, "sector%d/jump/%d/%d" % [sector, at.x, at.y])
	jump_time = roll.randf_range(JUMP_TIME.x, JUMP_TIME.y)
	jump_left = jump_time
	print("Run: jumping from %s to %s (%.1f s)." % [at, jump_to, jump_time])
	survey_target = -1
	survey_left = 0.0
	_scanning = false
	scan_left = 0.0
	_broadcast()


## Host: the jump's done: the LANTERN is in its new system, with everything to scan again.
func _arrive() -> void:
	if jump_to == NEXT_SECTOR:
		sector += 1
		map = SectorMap.generate(seed, sector)
		at = SectorMap.start()
		charted.assign([at, SectorMap.boss()])
		visited.clear()
	else:
		at = jump_to
		if at not in charted:
			charted.append(at)
	visited.append(at)
	print("Run: arrived at %s, a %s." % [at, here()])
	jump_to = NOWHERE
	jump_left = 0.0
	scanned = false
	surveyed.clear()
	refuelled = false
	_broadcast()


func _crew_aboard() -> bool:
	var lantern := get_tree().get_first_node_in_group(&"lantern")
	for player: Player in get_tree().get_nodes_in_group(&"crew"):
		if lantern != null and lantern.room_at(player.global_position) == "OUTSIDE":
			return false
	return true


# --- Keeping peers in step -------------------------------------------------------------------

func _broadcast() -> void:
	_state.rpc(_pack())
	changed.emit()


func _pack() -> Dictionary:
	return {"seed": seed, "sector": sector, "at": at, "route": route, "charted": charted, "visited": visited, "scanned": scanned,
			"scan_left": scan_left, "fuel": fuel, "surveyed": surveyed, "survey_target": survey_target,
			"survey_left": survey_left, "survey_data": survey_data, "refuelled": refuelled, "refuel_left": refuel_left,
			"jump_to": jump_to, "jump_left": jump_left, "jump_time": jump_time}


@rpc("authority", "call_remote", "reliable")
func _state(data: Dictionary) -> void:
	var fresh: bool = not started or data.seed != seed or data.sector != sector
	seed = data.seed
	sector = data.sector
	if fresh:
		map = SectorMap.generate(seed, sector)
	at = data.at
	route = data.route
	charted.assign(data.charted)
	visited.assign(data.visited)
	scanned = data.scanned
	scan_left = data.scan_left
	fuel.assign(data.fuel)
	surveyed.assign(data.surveyed)
	survey_target = data.survey_target
	survey_left = data.survey_left
	survey_data = data.survey_data
	refuelled = data.refuelled
	refuel_left = data.refuel_left
	jump_to = data.jump_to
	jump_left = data.jump_left
	jump_time = data.jump_time
	started = true
	_show_world()
	changed.emit()
	if fresh:
		_report.rpc_id(1, map.checksum())


## A crew member's machine tells the host the chart it drew.
@rpc("any_peer", "call_remote", "reliable")
func _report(chart: int) -> void:
	if chart != map.checksum():
		push_warning("Run: peer %d charted a different sector (%d, not %d)." % [multiplayer.get_remote_sender_id(), chart, map.checksum()])


# --- Showing the world -----------------------------------------------------------------------

## The world shows where the run is: during a jump, the old system while the drive spools, then
## hyperspace, then the new system for the last of it.
func _show_world() -> void:
	var where := at
	var where_sector := sector
	if jumping():
		if jump_elapsed() >= SPOOL:
			where = NOWHERE
		if jump_left <= ARRIVAL:
			where = jump_to if jump_to != NEXT_SECTOR else SectorMap.start()
			where_sector = sector + (1 if jump_to == NEXT_SECTOR else 0)
	if system != null:
		system.tunnel_flash = flash()
	if where == _shown and where_sector == _shown_sector:
		return
	_shown = where
	_shown_sector = where_sector
	_clear_encounter()
	if where == NOWHERE:
		if system != null:
			system.hyperspace()
		return
	var chart := map if where_sector == sector else SectorMap.generate(seed, where_sector)
	var type := chart.type_of(where)
	if system != null:
		system.generate(system_seed(where, chart), "gas giant" if type == &"gas_giant" else "")
	if type == &"derelict" or (where == SectorMap.start() and where_sector == 1 and Args.flag("--derelict")):
		_dock_sample()


## Docks the sample derelict at the collar (a stand-in for docking, M4); the host puts out its loot.
func _dock_sample() -> void:
	if encounter == null:
		return
	var derelict := Node3D.new()
	derelict.set_script(SAMPLE_DERELICT)
	derelict.name = "SampleDerelict"
	encounter.add_child(derelict)
	_dock(true)
	if multiplayer.is_server():
		LooseItems.of(self).stock(derelict)


## Casts off whatever's alongside: the collar seals, and the host clears away everything loose
## that isn't aboard (left behind with it).
func _clear_encounter() -> void:
	if encounter == null:
		return
	for child in encounter.get_children():
		child.queue_free()
	_dock(false)
	if multiplayer.is_server():
		LooseItems.of(self).clear_outside()


func _dock(docked: bool) -> void:
	var lantern := get_tree().get_first_node_in_group(&"lantern")
	if lantern != null:
		lantern.dock(docked)
