class_name Derelict
extends Deck
## A derelict alongside the LANTERN (GDD §8): a deck in the derelict kit, dead and dark, with one
## pressure hatch where the LANTERN's collar docks, its `entry`. Where it lies is the Collar's to
## say: out where it waits, drifting in, docked, drifting off again (`pose_to`). Anything loose
## aboard goes with it (the host moves it); crew aboard ride with it on their own machines (Player).
##
## Its air is its own: the rooms built without `vacuum` hold some, stale, until it's cast off with
## its hatch open and it all vents (`vent`).

## The edge (Deck.build's "col,row,side" of a layout cell) where its entry hatch stands; set it
## before build().
var entry_opening := ""
## The entry hatch, and whether the derelict's vented.
var entry: Hatch
var vented := false
var _entry_cell := Vector2i.ZERO


## The derelict a world point is inside (in one of its rooms), or null.
static func at(world: World3D, point: Vector3) -> Derelict:
	var zone := Zone.at(world, point)
	return zone.get_parent() as Derelict if zone != null else null


func build(rows: PackedStringArray, origin: Vector2i, openings: Dictionary, dark: String = "") -> void:
	super.build(rows, origin, openings, dark)
	var parts := entry_opening.split(",")
	var cell := Vector2i(int(parts[0]), int(parts[1])) - origin
	var side: Vector2i = SIDES[parts[2]]
	_entry_cell = cell
	# The edge's key, as Deck keys it: by the cell south or east of it.
	var owner := cell if parts[2] in ["N", "W"] else cell + side
	entry = hatches.get("%d,%d,%s" % [owner.x, owner.y, "h" if side.x == 0 else "v"])
	if entry == null:
		push_error("Derelict: no hatch at %s." % entry_opening)


## Where the collar meets it, in its own space: on its entry hatch's wall line at the deck, facing
## out (-Z out of the derelict, Y up).
func dock_point() -> Transform3D:
	var piece := entry.get_parent() as Node3D
	var frame := piece.transform
	if entry.inward < 0.0:
		frame.basis = frame.basis * Basis(Vector3.UP, PI)
	return frame


## Whether the room inside its entry hatch holds air.
func entry_air() -> bool:
	var zone: Zone = zones.get(_entry_cell)
	return zone != null and zone.pressurized


## Its air's gone: cast off with the hatch open, every room is vacuum.
func vent() -> void:
	vented = true
	for zone: Zone in zones.values():
		zone.pressurized = false


## Moves it to `where` (in its parent's space), taking everything loose aboard with it: the host
## moves its Pickups (everyone else's follow the host's), and every peer its own copies of bodies.
func pose_to(where: Transform3D) -> void:
	if where.is_equal_approx(transform):
		return
	var moved := where * transform.affine_inverse()
	if is_inside_tree():
		var items := LooseItems.of(self)
		for thing in items.loose() if items != null else []:
			if (thing is LooseBody or multiplayer.is_server()) and Derelict.at(get_world_3d(), thing.centre() + Vector3.UP * 0.05) == self:
				thing.carry(moved)
	transform = where
