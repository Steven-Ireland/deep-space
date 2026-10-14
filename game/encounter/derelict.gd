class_name Derelict
extends Deck
## A derelict alongside the LANTERN (GDD §8): a deck in the derelict kit, dead and dark, with one
## pressure hatch where the LANTERN's collar docks, its `entry`. Where it lies is the Collar's to
## say: out where it waits, drifting in, docked, drifting off again (`pose_to`). Anything loose
## aboard goes with it (the host moves it); crew aboard ride with it on their own machines (Player).
##
## It holds no air: its rooms are open to one another, so with no sealed sections or airlocks of
## its own, every one is vacuum (and whatever lives here doesn't need air). `vent` stays for the
## day one has sealed sections.
##
## It's built from its plan (DerelictLayout, grown from the node's seed on every peer): the rooms'
## walls, floors and ceilings in the derelict kit, its hull, and each room's dressing. The Crawler
## and the Hanger stand in posed where the plan puts them, until they come alive (M4).

const MODELS := "res://assets/models/%s.glb"

## Its plan; set it (`make`) before it enters the tree.
var layout: DerelictLayout
## How many crew its loot is stocked for (the host's count; the host puts it out, LooseItems).
var crew := 1

## The edge (Deck.build's "col,row,side" of a layout cell) where its entry hatch stands; set it
## before build().
var entry_opening := ""
## The entry hatch, and whether the derelict's vented.
var entry: Hatch
var vented := false
var _entry_cell := Vector2i.ZERO


## A derelict built from `plan`, stocked for `crew`.
static func make(plan: DerelictLayout, crew_size := 1) -> Derelict:
	var derelict := Derelict.new()
	derelict.layout = plan
	derelict.crew = crew_size
	return derelict


func _ready() -> void:
	if layout == null:
		return
	kit = "dk"
	lit = false
	entry_opening = layout.entry_opening()
	build(layout.rows(), layout.origin(), layout.openings())
	var shut := layout.shut_on(0)
	for key: String in doors:
		doors[key].open = not shut.has(key)
	_dress()


## The plan's dressing: furniture and decay, the strobes, the stand-in creatures, and the loot
## (markers the host puts the real things out at).
func _dress() -> void:
	var placed: Array[Node3D] = []
	for prop: Dictionary in layout.props:
		var node := _prop(prop.model, prop.at)
		placed.append(node)
		if not prop.get("pose", []).is_empty():
			_play(node, prop.pose[0], prop.pose[1])
	for strobe: Dictionary in layout.strobes:
		var light := Strobe.new()
		light.transform = strobe.at
		light.failing = strobe.failing
		add_child(light)
	for creature: Dictionary in layout.creatures:
		_play(_prop("creatures/cr_%s" % creature.kind, creature.at), "idle")
	for find: Dictionary in layout.loot(crew):
		if find.has("rack"):
			var socket := placed[find.rack].find_child("SOCKET_rack_%s" % find.kind, true, false) as Node3D
			if socket != null:
				rack(find.kind, socket.global_transform)
		else:
			stock(find.kind, find.at.origin, rad_to_deg(find.at.basis.get_euler().y))


func _prop(model: String, at: Transform3D) -> Node3D:
	var node: Node3D = load(MODELS % model).instantiate()
	node.transform = at
	add_child(node)
	_mark_interior(node)
	return node


## Holds `node`'s `clip` (at `at` seconds, paused; or playing, at -1).
func _play(node: Node, clip: String, at := -1.0) -> void:
	var player := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null or not player.has_animation(clip):
		return
	player.play(clip)
	if at >= 0.0:
		player.seek(at, true)
		player.pause()


## The derelict a world point is inside (in one of its rooms), or null.
static func at(world: World3D, point: Vector3) -> Derelict:
	var zone := Zone.at(world, point)
	return zone.get_parent() as Derelict if zone != null else null


func build(rows: PackedStringArray, origin: Vector2i, openings: Dictionary, dark: String = "") -> void:
	super.build(rows, origin, openings, dark)
	for zone: Zone in zones.values():
		zone.pressurized = false
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
