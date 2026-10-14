class_name FuelRack
extends Node3D
## The drive room's fuel rack (GDD §5, §6), added to its model: three bays, each showing the cell
## loaded in it (the Run's fuel). Crew carrying a fuel cell load it into an empty bay; the drive
## burns the last one loaded at each jump.

const CELL := preload("res://assets/models/items/fuel_cell.glb")
## The box crew aim at over each bay's cradle, and where it sits above the bay's socket.
const BAY_SIZE := Vector3(0.5, 0.9, 0.5)
const BAY_RISE := 0.3

var _cells: Array[Node3D] = []


func _ready() -> void:
	var rack := get_parent() as Node3D
	for i in Run.BAYS:
		var socket := rack.find_child("SOCKET_bay_%d" % (i + 1), true, false) as Node3D
		if socket == null:
			push_warning("FuelRack: no SOCKET_bay_%d." % (i + 1))
			continue
		var cell: Node3D = CELL.instantiate()
		cell.visible = false
		socket.add_child(cell)
		Deck._mark_interior(cell)
		_cells.append(cell)
		var bay := Bay.new()
		bay.name = "Bay%d" % (i + 1)
		bay.index = i
		bay.housing = rack
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = BAY_SIZE
		shape.shape = box
		bay.add_child(shape)
		socket.add_child(bay)
		bay.position = Vector3.UP * BAY_RISE
	_connect.call_deferred()


func _connect() -> void:
	var run := Run.of(self)
	if run != null:
		run.changed.connect(_show)
		_show()


func _show() -> void:
	var run := Run.of(self)
	for i in _cells.size():
		_cells[i].visible = i < run.fuel.size() and run.fuel[i]


## An empty bay takes the cell a crew member carries: LOAD; otherwise it says what it holds.
class Bay extends Interactable:
	var index := 0

	func _loaded() -> bool:
		var run := Run.of(self)
		return run == null or (index < run.fuel.size() and run.fuel[index])

	func prompt(player: Player) -> String:
		if _loaded():
			return "LOADED"
		return "LOAD" if Items.kind_of(player.carrying) == &"fuel_cell" else "EMPTY"

	func usable_by(player: Player) -> bool:
		return enabled and not _loaded() and Items.kind_of(player.carrying) == &"fuel_cell"

	## On the loader's machine: the cell leaves their hands for the bay (the host fills it, or sets
	## the cell down in front if someone beat them to it).
	func request_use() -> void:
		var player := get_tree().get_first_node_in_group(&"local_player") as Player
		if player == null or Items.kind_of(player.carrying) != &"fuel_cell":
			return
		player.take_from_hands()
		var spill := Transform3D(global_basis, global_position + global_basis.z * 0.6)
		Run.of(self).load_cell(index, spill)
