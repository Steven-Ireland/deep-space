class_name DerelictLayout
extends RoomLayout
## A derelict's plan (GDD §8.2, TECH §6), grown from its seed out of hand-built rooms
## (DerelictRooms) by RoomLayout, the same on every peer. Big enough that one tank of O2 won't see
## it all; a quarter of its doors shut, a few outer walls torn open. Dressed with each room's
## furniture, the scatter of decay, which emergency strobes still flash, and what lives here (often
## one thing, sometimes none, rarely two). Loot is spent from a budget that grows with the crew and
## the derelict's size (`loot`). It stands on one level; every derelict is vacuum throughout for
## now (GDD §17, 13), and power zones come later.

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

## The emergency strobes ({at, failing, room}) and what lives here ({kind, at}), in the derelict's
## space.
var strobes: Array[Dictionary] = []
var creatures: Array[Dictionary] = []


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
		for spot: Vector3 in module(rooms[index].type).get("spots", []):
			spots.append([index, frame_of(index) * _local(spot, rng.randf() * 360.0)])
	for find: StringName in _budget(rng, crew):
		if spots.is_empty():
			break
		var weights := spots.map(func(spot: Array) -> float: return module(rooms[spot[0]].type).get("finds", {}).get(find, 1.0))
		var spot: Array = spots.pop_at(_weighted(rng, weights))
		out.append({"kind": _roll(rng, DerelictRooms.FINDS[find]), "at": spot[1]})
	# A kit rack keeps a flare now and then: {kind, rack (the prop's index)}.
	for i in props.size():
		for kind: StringName in props[i].rack:
			if rng.randf() < 0.5:
				out.append({"kind": kind, "rack": i})
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


# --- For the Deck, and checking ----------------------------------------------------------------

func checksum() -> int:
	return hash([super.checksum(), creatures.size()])


## The plan as text for the host's log: each room's centre where it lies docked (the entry's cell
## at (20, 0, 0)) and what lives in it.
func describe_docked() -> String:
	return describe("Derelict", Transform3D(Basis(), Vector3(20, 0, 0)))


func _who(index: int) -> String:
	var living := []
	for creature in creatures:
		var spot: Vector3 = creature.at.origin
		if room_of.get(Vector3i(roundi(spot.x / Deck.CELL), 0, roundi(spot.z / Deck.CELL)), -1) == index:
			living.append(creature.kind)
	return " " + ", ".join(living) if not living.is_empty() else ""
