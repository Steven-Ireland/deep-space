class_name DerelictNav
extends RefCounted
## The ways through a derelict for what lives in it (GDD §12), worked out on the host when first
## needed (Derelict.nav): its rooms' floor in STEP squares, each open if a creature's body fits
## there clear of walls and furniture (a shape query against the derelict's own colliders),
## joined to its neighbours (diagonally only where no corner's in the way). Two grids:
##   walk   for moving: a shut door closes its doorway (a creature can't open one)
##   sound  for hearing: a shut door only muffles what's beyond it (the way through counts
##          DOOR_MUFFLE times as far)
## Points are in the derelict's own space, on its deck, so it holds however the derelict moves.

const STEP := 0.5
## Squares across a 4 m cell; the first square's middle from its cell's middle.
const SQUARES := 8
const FIRST := -Deck.CELL / 2 + STEP / 2
## A square is open if a body this wide (radius) fits there, from this high over the deck to this.
const BODY := 0.3
const BODY_LOW := 0.15
const BODY_HIGH := 0.95
const DOOR_MUFFLE := 3.0
## A doorway's squares lie within this of its middle: along the wall, and across it.
const DOORWAY := Vector2(1.0, 0.5)
## How far round a point to look for an open square, when it's on a solid one; what's found when
## there's none.
const NEAREST := 4
const NONE := Vector2i(-1000000, -1000000)

var walk := AStarGrid2D.new()
var sound := AStarGrid2D.new()
var _cells := {} # the derelict's room cells (Vector2i)
var _doors := {} # Door: its doorway's open squares
var _door_at := {} # square: the Door whose doorway it's in
var _shut := {} # Door: whether it was shut when last looked at


## The ways through `derelict`, from its colliders where it stands now.
static func build(derelict: Derelict) -> DerelictNav:
	var nav := DerelictNav.new()
	nav._build(derelict)
	return nav


func _build(derelict: Derelict) -> void:
	var low := -NONE
	var high := NONE
	for cell: Vector2i in derelict.cells:
		_cells[cell] = true
		low = low.min(cell)
		high = high.max(cell)
	var region := Rect2i(low * SQUARES, (high - low + Vector2i.ONE) * SQUARES)
	for grid: AStarGrid2D in [walk, sound]:
		grid.region = region
		grid.cell_size = Vector2(STEP, STEP)
		grid.offset = Vector2(FIRST, FIRST)
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		grid.update()
		grid.fill_solid_region(region, true)
	# Doors are left out of the queries: their doorways open and shut (refresh).
	var exclude: Array[RID] = []
	for door: Door in derelict.doors.values():
		var blocker := door.get_node_or_null("Blocker") as CollisionObject3D
		if blocker != null:
			exclude.append(blocker.get_rid())
	var query := PhysicsShapeQueryParameters3D.new()
	var body := CylinderShape3D.new()
	body.radius = BODY
	body.height = BODY_HIGH - BODY_LOW
	query.shape = body
	query.collision_mask = 1
	query.exclude = exclude
	var space := derelict.get_world_3d().direct_space_state
	var frame := derelict.global_transform
	for cell: Vector2i in _cells:
		for k in SQUARES:
			for l in SQUARES:
				var square := cell * SQUARES + Vector2i(k, l)
				var at := point_of(square)
				query.transform = frame * Transform3D(Basis(), at + Vector3.UP * (BODY_LOW + BODY_HIGH) / 2.0)
				if space.intersect_shape(query, 1).is_empty():
					walk.set_point_solid(square, false)
					sound.set_point_solid(square, false)
	for door: Door in derelict.doors.values():
		var squares: Array[Vector2i] = []
		var middle := square_of(door.position)
		for k in range(-3, 4):
			for l in range(-3, 4):
				var square := middle + Vector2i(k, l)
				if not walk.is_in_boundsv(square) or walk.is_point_solid(square):
					continue
				var off := point_of(square) - door.position
				if absf(off.dot(door.transform.basis.x)) < DOORWAY.x and absf(off.dot(door.transform.basis.z)) < DOORWAY.y:
					squares.append(square)
					_door_at[square] = door
		_doors[door] = squares
	refresh()


## Brings the doorways up to date with their doors: a shut door (or one shutting) is closed to a
## creature, and muffles sound through it.
func refresh() -> void:
	for door: Door in _doors:
		if not is_instance_valid(door):
			continue
		var shut := not door.open
		if _shut.get(door, not shut) == shut:
			continue
		_shut[door] = shut
		for square: Vector2i in _doors[door]:
			walk.set_point_solid(square, shut)
			sound.set_point_weight_scale(square, DOOR_MUFFLE if shut else 1.0)


## The square a point (the derelict's space) lies in.
static func square_of(at: Vector3) -> Vector2i:
	return Vector2i(floori((at.x - FIRST) / STEP + 0.5), floori((at.z - FIRST) / STEP + 0.5))


## A square's middle, on the deck.
static func point_of(square: Vector2i) -> Vector3:
	return Vector3(FIRST + square.x * STEP, 0.0, FIRST + square.y * STEP)


## Whether a point lies in one of the derelict's rooms.
func inside(at: Vector3) -> bool:
	return _cells.has(Vector2i(roundi(at.x / Deck.CELL), roundi(at.z / Deck.CELL)))


## The open square of `grid` nearest `at` (within NEAREST squares), or NONE.
func nearest_open(at: Vector3, grid: AStarGrid2D = walk) -> Vector2i:
	var middle := square_of(at)
	var best := NONE
	var best_distance := INF
	for k in range(-NEAREST, NEAREST + 1):
		for l in range(-NEAREST, NEAREST + 1):
			var square := middle + Vector2i(k, l)
			if not grid.is_in_boundsv(square) or grid.is_point_solid(square):
				continue
			var distance := point_of(square).distance_squared_to(Vector3(at.x, 0.0, at.z))
			if distance < best_distance:
				best_distance = distance
				best = square
	return best


static func found(square: Vector2i) -> bool:
	return square != NONE


## The way on foot from `from` to `to` (open squares' middles, `from` excluded), or none.
func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var start := nearest_open(from)
	var end := nearest_open(to)
	if not found(start) or not found(end):
		return out
	var ids := walk.get_id_path(start, end)
	for i in range(1, ids.size()):
		out.append(point_of(ids[i]))
	return out


## How far a sound from `from` has to carry to reach `to` through the rooms (a shut door counting
## DOOR_MUFFLE times its width), or INF if it can't, or not within `reach`.
func heard(from: Vector3, to: Vector3, reach: float) -> float:
	var straight := Vector2(from.x - to.x, from.z - to.z).length()
	if straight > reach:
		return INF
	var start := nearest_open(from, sound)
	var end := nearest_open(to, sound)
	if not found(start) or not found(end):
		return INF
	var ids := sound.get_id_path(start, end)
	if ids.is_empty():
		return INF
	var distance := 0.0
	for i in range(1, ids.size()):
		distance += Vector2(ids[i] - ids[i - 1]).length() * STEP * sound.get_point_weight_scale(ids[i])
	return distance


## When the way on foot from `from` to `to` is closed only by shut doors: the first of them on the
## way, and where to stand before it ([Door, Vector3]); otherwise [].
func door_between(from: Vector3, to: Vector3) -> Array:
	var start := nearest_open(from, sound)
	var end := nearest_open(to, sound)
	if not found(start) or not found(end):
		return []
	var ids := sound.get_id_path(start, end)
	for i in range(1, ids.size()):
		var door: Door = _door_at.get(ids[i])
		if door != null and _shut.get(door, false):
			return [door, point_of(ids[i - 1])]
	return []


## Somewhere open to wander to, within `within` metres of `from` and reachable on foot, or `from`
## itself if nowhere turns up.
func wander_point(from: Vector3, within: float, rng: RandomNumberGenerator) -> Vector3:
	var middle := square_of(from)
	var reach := int(within / STEP)
	for attempt in 16:
		var square := middle + Vector2i(rng.randi_range(-reach, reach), rng.randi_range(-reach, reach))
		if not walk.is_in_boundsv(square) or walk.is_point_solid(square):
			continue
		var start := nearest_open(from)
		if found(start) and not walk.get_id_path(start, square).is_empty():
			return point_of(square)
	return from
