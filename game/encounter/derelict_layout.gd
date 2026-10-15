class_name DerelictLayout
extends RoomLayout
## A derelict's plan (GDD §8.2, TECH §6), grown from its seed out of hand-built rooms
## (DerelictRooms) by RoomLayout, the same on every peer. Big enough that one tank of O2 won't see
## it all; a quarter of its doors shut, a few outer walls torn open. Dressed with each room's
## furniture, the scatter of decay, which emergency strobes still flash, and what lives here (often
## one thing, sometimes none, rarely two). Loot is spent from a budget that grows with the crew and
## the derelict's size (`loot`). It stands on one level; every derelict is vacuum throughout for
## now (GDD §17, 13). Its rooms are grouped into power sections, each with a breaker box (`_power`).

## Modules grown from the entry (besides the entry and the Prize): this many, plus the sector. Big
## enough that one tank of O2 won't see all of it, and the crew have to find their way back.
const SIZE := Vector2i(26, 34)
## How many loops, at most, and how far round (rooms) the long way must be for one.
const LOOPS := Vector2i(2, 5)
const LOOP_REACH := 3
## The Prize must be at least this many rooms in.
const PRIZE_DEPTH := 6
## Chances: a door starts shut; an outer wall is torn open.
const SHUT_CHANCE := 0.25
const BREACH_CHANCE := 0.1
## How many creatures (GDD §8.3: often one, sometimes none, rarely two): weights for 0, 1 and 2.
const CREATURES := [2, 7, 1]
## The loot budget's counts are for a derelict of this many rooms; a bigger one has more in
## proportion, so finds are as thin on the ground in any of them.
const BUDGET_ROOMS := 14.0

## Power sections (GDD §8.3): about one for every ROOMS_PER_SECTION rooms, SECTIONS at least and at
## most. A breaker box still holds a charged cell at CELL_CHANCE (the entry's section at
## ENTRY_CELL_CHANCE); at least one does and one doesn't.
const ROOMS_PER_SECTION := 9.0
const SECTIONS := Vector2i(3, 5)
const CELL_CHANCE := 0.5
const ENTRY_CELL_CHANCE := 0.75
## A breaker stands this far out from its cell's middle (on the wall's face), and this clear of the
## room's furniture and its strobes.
const BREAKER_OUT := 1.69
const BREAKER_CLEAR := 1.0
const STROBE_CLEAR := 0.6

## A secure store (GDD §8.3; DerelictRooms: vault): in VAULT_CHANCE of derelicts, a dead end off
## a corridor at least VAULT_DEPTH rooms in (and short of the Prize), its door locked; its lock
## panel on the corridor's side of that wall, LOCK_ALONG either way along it from the door's middle,
## standing LOCK_OUT from its cell's middle, clear of the corridor's furniture by LOCK_CLEAR.
const VAULT_CHANCE := 0.75
const VAULT_DEPTH := 3
const LOCK_ALONG := 1.45
const LOCK_OUT := 1.73
const LOCK_CLEAR := 0.8

## The emergency strobes ({at, failing, room}) and what lives here ({kind, at}), in the derelict's
## space.
var strobes: Array[Dictionary] = []
var creatures: Array[Dictionary] = []
## Each room's power section (an index, 0 the entry's; letters A, B... by how far in), how many
## sections there are, and their breaker boxes ({section, room, at: Transform3D, cell: whether it
## still holds a charged cell}), one a section.
var section_of: Array[int] = []
var sections := 0
var breakers: Array[Dictionary] = []
## The secure store: its room (-1 for none), its door's edge key, and where its lock panel stands.
var vault := -1
var vault_door := ""
var lock_at := Transform3D()


## The layout for `seed` (a derelict node's own), in `sector`.
static func generate(derelict_seed: int, in_sector := 1) -> DerelictLayout:
	var layout: DerelictLayout
	for n in 50:
		layout = DerelictLayout.new()
		if layout.grow(derelict_seed, in_sector, n):
			break
	return layout


func _modules() -> Dictionary:
	return DerelictRooms.MODULES


func _size() -> Vector2i:
	return SIZE


func _loops() -> Vector2i:
	return LOOPS


func _loop_reach() -> int:
	return LOOP_REACH


func _prize_depth() -> int:
	return PRIZE_DEPTH


func _shut_chance() -> float:
	return SHUT_CHANCE


func _breach_chance() -> float:
	return BREACH_CHANCE


## A derelict stands on one level.
func _allowed(cell: Vector3i) -> bool:
	return cell.x >= 0 and cell.y == 0


func _more_problems() -> Array[String]:
	var out: Array[String] = []
	if creatures.size() > 2:
		out.append("%d creatures" % creatures.size())
	if breakers.size() != sections:
		out.append("%d breakers for %d sections" % [breakers.size(), sections])
	if vault >= 0 and links[vault].size() != 1:
		out.append("the secure store has %d doors" % links[vault].size())
	return out


# --- Dressing ----------------------------------------------------------------------------------

func _dress(rng: RandomNumberGenerator) -> void:
	for index in rooms.size():
		var spec := module(rooms[index].type)
		var frame := frame_of(index)
		_furnish(index)
		for strobe: Array in spec.get("strobes", []):
			if index == prize or rng.randf() < DerelictRooms.STROBE_CHANCE:
				strobes.append({"at": frame * _local(strobe[0], strobe[1]), "failing": rng.randf() < DerelictRooms.FAILING_CHANCE, "room": index})
		for bit: Array in spec.get("scatter", []):
			if rng.randf() < DerelictRooms.SCATTER_CHANCE[bit[0]]:
				props.append({"model": DerelictRooms.SCATTER[bit[0]], "at": frame * _local(bit[1], bit[2]), "rack": [],
						"pose": ["death", 1.4] if bit[0] == "corpse" else [], "room": index})
	_creatures(rng)
	_vault(Seeds.rng(seed, "vault/%d" % attempt))
	_power(Seeds.rng(seed, "power/%d" % attempt))


## What lives here: in rooms at least two in from the entry (never the Prize room), on open floor.
## A Hanger hangs from the ceiling in the dark, its growth on the deck below; a Crawler waits.
func _creatures(rng: RandomNumberGenerator) -> void:
	var count := 0
	var roll := rng.randi_range(1, CREATURES.reduce(func(a: int, b: int) -> int: return a + b))
	while roll > CREATURES[count]:
		roll -= CREATURES[count]
		count += 1
	var depth := _depths()
	var dens := []
	for index in rooms.size():
		if index != prize and depth.get(index, 0) >= 2:
			for spot: Vector3 in module(rooms[index].type).get("open", []):
				dens.append([index, frame_of(index) * spot])
	var kinds := [&"crawler", &"hanger"]
	if rng.randf() < 0.5:
		kinds.reverse()
	var used := {}
	for i in count:
		var choices := dens.filter(func(den: Array) -> bool: return not used.has(den[0]))
		if choices.is_empty():
			return
		var den: Array = choices[rng.randi() % choices.size()]
		used[den[0]] = true
		var yaw := rng.randf() * TAU
		if kinds[i] == &"hanger":
			creatures.append({"kind": &"hanger", "at": Transform3D(Basis(Vector3.UP, yaw), den[1] + Vector3.UP * Deck.ROOM_HEIGHT)})
			props.append({"model": "derelict/dk_growth", "at": Transform3D(Basis(Vector3.UP, yaw), den[1]), "rack": [], "room": den[0]})
		else:
			creatures.append({"kind": &"crawler", "at": Transform3D(Basis(Vector3.UP, yaw), den[1])})


## The loot (GDD §8.2): a fuel cell, and finds from a budget that grows with the crew, each in a
## room that suits it: [{kind, at}] in the derelict's space, or {kind, rack} hung on the kit rack
## that's `props[rack]`. The same for the same crew.
func loot(crew: int) -> Array[Dictionary]:
	var rng := Seeds.rng(seed, "loot/%d/%d" % [attempt, crew])
	var out: Array[Dictionary] = []
	for type in DerelictRooms.FUEL_ROOMS:
		var index := _first(type)
		if index >= 0:
			var big: Array = module(type).big[0]
			out.append({"kind": &"fuel_cell", "at": frame_of(index) * _local(big[0], big[1])})
			break
	var spots := []
	for index in rooms.size():
		if index == vault:
			continue
		for spot: Vector3 in module(rooms[index].type).get("spots", []):
			spots.append([index, frame_of(index) * _local(spot, rng.randf() * 360.0)])
	for find: StringName in _budget(rng, crew):
		if spots.is_empty():
			break
		var weights := spots.map(func(spot: Array) -> float: return module(rooms[spot[0]].type).get("finds", {}).get(find, 1.0))
		var spot: Array = spots.pop_at(_weighted(rng, weights))
		out.append({"kind": _roll(rng, DerelictRooms.FINDS[find]), "at": spot[1]})
	out.append_array(_vault_loot(crew))
	# The Prize: the survey core in its cradle (GDD §8.3), always; taking it may set something off.
	var cradle := _prop_of(prize, module(&"prize").get("core", -1))
	if cradle >= 0:
		out.append({"kind": &"survey_core", "rack": cradle, "socket": "SOCKET_core", "prize": true})
	# A kit rack keeps a flare now and then: {kind, rack (the prop's index)}.
	for i in props.size():
		for kind: StringName in props[i].rack:
			if kind != &"survey_core" and rng.randf() < 0.5:
				out.append({"kind": kind, "rack": i})
	return out


## The index in `props` of room `index`'s `nth` prop from its module (-1 for none).
func _prop_of(index: int, nth: int) -> int:
	if nth < 0:
		return -1
	var seen := 0
	for i in props.size():
		if props[i].get("room", -1) == index and not props[i].has("pose"):
			if seen == nth:
				return i
			seen += 1
	return -1


## What the secure store holds (DerelictRooms.VAULT_FINDS), on its shelves: its own label, so the
## rest of the loot doesn't change for it.
func _vault_loot(crew: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if vault < 0:
		return out
	var rng := Seeds.rng(seed, "loot/vault/%d/%d" % [attempt, crew])
	var spots: Array = module(&"vault").spots.duplicate()
	var finds: Array = DerelictRooms.VAULT_FINDS.duplicate()
	for i in (crew - 1) / 2:
		finds.append(&"supplies")
	for find: StringName in finds:
		if spots.is_empty():
			break
		var spot: Vector3 = spots.pop_at(rng.randi() % spots.size())
		var table: Dictionary = DerelictRooms.WEAPONS if find == &"weapon" else DerelictRooms.FINDS[find]
		out.append({"kind": _roll(rng, table), "at": frame_of(vault) * _local(spot, rng.randf() * 360.0)})
	return out


## What's to be found, kind by kind (GDD §8.2: it grows with the crew), scaled to the derelict's
## size (a part of one rolled).
func _budget(rng: RandomNumberGenerator, crew: int) -> Array[StringName]:
	var counts := {&"salvage": 3.0 + crew, &"supplies": 1.0 + crew, &"lore": 1.5, &"power": 1.0, &"ammo": 0.5, &"tools": 1.5}
	var share := rooms.size() / BUDGET_ROOMS
	var out: Array[StringName] = []
	for find: StringName in counts:
		var many: float = counts[find] * share
		for i in floori(many) + (1 if rng.randf() < many - floorf(many) else 0):
			out.append(find)
	return out


# --- The secure store ------------------------------------------------------------------------------

## Adds the secure store, after everything else is grown and dressed (so nothing else about the
## derelict changes for it): off a corridor's free door, far enough in and short of the Prize, where
## its lock panel can stand beside the door. Its door starts shut, and is locked (Derelict).
func _vault(rng: RandomNumberGenerator) -> void:
	if rng.randf() >= VAULT_CHANCE:
		return
	var depth := _depths()
	var options := _open_doors().filter(func(door: Array) -> bool:
		return module(rooms[door[0]].type).kind == "corridor" and depth[door[0]] >= VAULT_DEPTH and depth[door[0]] + 1 < depth[prize])
	while not options.is_empty():
		var door: Array = options.pop_at(rng.randi() % options.size())
		if not _attach(rng, &"vault", door):
			continue
		var index := rooms.size() - 1
		# Not against a window or a breach already there: those face space.
		var against := false
		for cell: Vector3i in rooms[index].cells:
			for side in AROUND:
				var key := edge_key(cell, side)
				against = against or windows.has(key) or breaches.has(key)
		var panel: Variant = null if against else _lock_spot(door[0], door[1], door[2], rng)
		if panel == null:
			_unplace(index, door)
			continue
		vault = index
		vault_door = edge_key(door[1], door[2])
		lock_at = panel
		shut[vault_door] = true
		_furnish(index)
		var frame := frame_of(index)
		for strobe: Array in module(&"vault").get("strobes", []):
			strobes.append({"at": frame * _local(strobe[0], strobe[1]), "failing": false, "room": index})
		props.append({"model": "derelict/dk_lock_panel", "at": lock_at, "rack": [], "room": door[0], "lock": true})
		return


## Where the lock panel stands for a door on `side` of corridor `room`'s `cell`: on that wall's
## corridor face, a little way along from the door either side, clear of the corridor's furniture
## and strobes; or null.
func _lock_spot(room: int, cell: Vector3i, side: String, rng: RandomNumberGenerator) -> Variant:
	var out_dir := Vector3(SIDES[side])
	var along := Vector3(-out_dir.z, 0.0, out_dir.x)
	var yaw := atan2(-out_dir.x, -out_dir.z)
	var ways := [1.0, -1.0]
	if rng.randf() < 0.5:
		ways.reverse()
	for way: float in ways:
		var at: Vector3 = centre_of(cell) + out_dir * LOCK_OUT + along * LOCK_ALONG * way
		var clear := true
		for prop: Dictionary in props:
			if prop.get("room", -1) == room and _flat_distance(prop.at.origin, at) < LOCK_CLEAR:
				clear = false
		for strobe: Dictionary in strobes:
			if strobe.room == room and _flat_distance(strobe.at.origin, at) < STROBE_CLEAR:
				clear = false
		if clear:
			return Transform3D(Basis(Vector3.UP, yaw), at)
	return null


# --- Power ---------------------------------------------------------------------------------------

## Power sections (GDD §8.3): the entry's grown from the entry, the rest from the rooms farthest from
## any section begun so far, all at once through the doors, the smallest taking the next room at
## its edge, so each is all of a piece and they're about the same size. Lettered by how far in each
## begins. Then each section's breaker box, on a bare wall of
## the section's room nearest the way in, holding a charged cell or not.
func _power(rng: RandomNumberGenerator) -> void:
	var count := clampi(roundi(rooms.size() / ROOMS_PER_SECTION), SECTIONS.x, SECTIONS.y)
	var seeds: Array[int] = [0]
	var near := _hops_from(0)
	while seeds.size() < count:
		var far := -1
		var best := -1
		for index in rooms.size():
			var hops: int = near.get(index, 0)
			if index != prize and (hops > best or (hops == best and rng.randf() < 0.5)):
				best = hops
				far = index
		if far < 0 or best < 2:
			break
		seeds.append(far)
		var from_far := _hops_from(far)
		for index: int in near:
			near[index] = mini(near[index], from_far.get(index, 1 << 20))
	var depth := _depths()
	seeds.sort_custom(func(a: int, b: int) -> bool: return depth[a] < depth[b] or (depth[a] == depth[b] and a < b))
	sections = seeds.size()
	section_of.clear()
	section_of.resize(rooms.size())
	section_of.fill(-1)
	# Each section's edge: its rooms' neighbours not yet in any section, first found first. The
	# smallest section with an edge takes the next room off it, so they come out about even.
	var edges: Array = []
	var size: Array[int] = []
	for s in seeds.size():
		section_of[seeds[s]] = s
		edges.append(links[seeds[s]].duplicate())
		size.append(1)
	var placed := seeds.size()
	while placed < rooms.size():
		var grow := -1
		for s in seeds.size():
			while not edges[s].is_empty() and section_of[edges[s][0]] >= 0:
				edges[s].pop_front()
			if not edges[s].is_empty() and (grow < 0 or size[s] < size[grow]):
				grow = s
		if grow < 0:
			break
		var room: int = edges[grow].pop_front()
		section_of[room] = grow
		size[grow] += 1
		placed += 1
		for next: int in links[room]:
			if section_of[next] < 0:
				edges[grow].append(next)
	breakers.clear()
	for s in sections:
		var members := range(rooms.size()).filter(func(index: int) -> bool: return section_of[index] == s)
		members.sort_custom(func(a: int, b: int) -> bool: return depth[a] < depth[b] or (depth[a] == depth[b] and a < b))
		for index: int in members:
			var spots := _breaker_spots(index)
			if not spots.is_empty():
				var chance := ENTRY_CELL_CHANCE if s == 0 else CELL_CHANCE
				breakers.append({"section": s, "room": index, "at": spots[rng.randi() % spots.size()], "cell": rng.randf() < chance})
				break
	# At least one box still charged, and at least one wanting a cell.
	var charged := breakers.filter(func(box: Dictionary) -> bool: return box.cell).size()
	if charged == breakers.size() and not breakers.is_empty():
		breakers[-1].cell = false
	elif charged == 0 and not breakers.is_empty():
		breakers[0].cell = true


## How many rooms away from `from` each room is, through the joins.
func _hops_from(from: int) -> Dictionary:
	var hops := {from: 0}
	var queue := [from]
	while not queue.is_empty():
		var at: int = queue.pop_front()
		for next: int in links[at]:
			if not hops.has(next):
				hops[next] = hops[at] + 1
				queue.append(next)
	return hops


## Where a breaker box could hang in room `index`: on a bare outer or party wall (no door, window,
## breach or hatch in it), its middle or a metre either way along it, clear of the room's furniture,
## decay and strobes. Facing into the room.
func _breaker_spots(index: int) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	for cell: Vector3i in rooms[index].cells:
		for side in AROUND:
			var beyond: Vector3i = cell + SIDES[side]
			if room_of.get(beyond, -1) == index:
				continue
			var key := edge_key(cell, side)
			if joins.has(key) or windows.has(key) or breaches.has(key) or (cell == Vector3i.ZERO and side == "W"):
				continue
			var out_dir := Vector3(SIDES[side])
			var along := Vector3(-out_dir.z, 0.0, out_dir.x)
			var yaw := atan2(-out_dir.x, -out_dir.z)
			for offset in [0.0, -1.0, 1.0]:
				var at: Vector3 = centre_of(cell) + out_dir * BREAKER_OUT + along * offset
				if _clear_for_breaker(index, at):
					out.append(Transform3D(Basis(Vector3.UP, yaw), at))
	return out


func _clear_for_breaker(index: int, at: Vector3) -> bool:
	for prop: Dictionary in props:
		if prop.get("room", -1) == index and _flat_distance(prop.at.origin, at) < BREAKER_CLEAR:
			return false
	for strobe: Dictionary in strobes:
		if strobe.room == index and _flat_distance(strobe.at.origin, at) < STROBE_CLEAR:
			return false
	return true


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## The section a grid cell's room is in (-1 outside every room).
func section_at(cell: Vector3i) -> int:
	var index: int = room_of.get(cell, -1)
	return section_of[index] if index >= 0 and index < section_of.size() else -1


## A section's letter: A for the entry's, then on in.
static func letter(section: int) -> String:
	return "ABCDEFGH"[section] if section >= 0 and section < 8 else "?"


# --- For the Deck, and checking ----------------------------------------------------------------

func checksum() -> int:
	var boxes := breakers.map(func(box: Dictionary) -> Array: return [box.section, box.room, box.at.origin.snapped(Vector3.ONE * 0.01), box.cell])
	return hash([super.checksum(), creatures.size(), section_of, boxes, vault, vault_door])


## The plan as text for the host's log: each room's centre where it lies docked (the entry's cell
## at (20, 0, 0)) and what lives in it.
func describe_docked() -> String:
	return describe("Derelict", Transform3D(Basis(), Vector3(20, 0, 0)))


func _who(index: int) -> String:
	var tag := " [%s]" % letter(section_of[index]) if index < section_of.size() else ""
	for box in breakers:
		if box.room == index:
			tag += " breaker %s" % ("charged" if box.cell else "dead")
	var living := []
	for creature in creatures:
		var spot: Vector3 = creature.at.origin
		if room_of.get(Vector3i(roundi(spot.x / Deck.CELL), 0, roundi(spot.z / Deck.CELL)), -1) == index:
			living.append(creature.kind)
	return tag + (" " + ", ".join(living) if not living.is_empty() else "")
