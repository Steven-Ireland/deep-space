class_name Breaker
extends Node3D
## A section's breaker box (GDD §8.3; art/blender/derelict.py: dk_breaker), fitted to its prop:
##   - its knife switch: THROW it (a short hold) to bring the section back, if a charged cell's
##     seated; thrown, CUT it to make the section dead again. It swings up into its clips, or down
##     and out of them, on every peer
##   - its cradle: with a power cell in hand, INSERT CELL; with a cell seated and the switch cut,
##     TAKE CELL (to carry it to another section)
##   - its lamps: PWR green while the section has power; CELL amber with a cell seated, red blinking
##     with none
##   - its section's letter on the plate under SECTION
## What it does is DerelictPower's to apply (on the host); this is the box crew see and use.

## How long the switch is held to throw it, how far it swings down when it's cut (radians, out
## from the wall), and how long the swing takes.
const THROW_HOLD := 0.5
const CUT_ANGLE := deg_to_rad(140.0)
const SWING := 0.3
## The boxes crew aim at: the switch (round its handle), and the cradle.
const SWITCH_BOX := Vector3(0.36, 0.36, 0.2)
const SWITCH_AT := Vector3(0, 1.36, 0.12)
const BAY_BOX := Vector3(0.56, 0.24, 0.36)
const BAY_AT := Vector3(-0.02, 0.84, 0.16)

const CELL := preload("res://assets/models/items/it_power_cell.glb")
const FONT := preload("res://assets/fonts/VT323-Regular.ttf")
const LAMP_GREEN := preload("res://assets/materials/lk_lamp_open.tres")
const LAMP_AMBER := preload("res://assets/materials/lk_lamp_shut.tres")
const LAMP_RED := preload("res://assets/materials/lk_lamp_sealed.tres")
const LAMP_DEAD := preload("res://assets/materials/lk_lamp_dead.tres")

var power: DerelictPower
var section := 0
var _pivot: Node3D
var _cell: Node3D
var _lamp_power: MeshInstance3D
var _lamp_cell: MeshInstance3D
var _angle := 0.0
var _shown_on := false
var _shown_cell := false
var _time := 0.0


## A breaker for `section` of `power`, fitted to `prop` (a dk_breaker).
static func fit(prop: Node3D, owner_power: DerelictPower, which: int) -> Breaker:
	var breaker := Breaker.new()
	breaker.name = "Breaker"
	breaker.power = owner_power
	breaker.section = which
	prop.add_child(breaker)
	return breaker


func _ready() -> void:
	var prop := get_parent() as Node3D
	var handle := prop.find_child("breaker_handle", true, false) as Node3D
	var hinge := prop.find_child("SOCKET_hinge", true, false) as Node3D
	if handle != null and hinge != null:
		_pivot = Node3D.new()
		_pivot.name = "Hinge"
		prop.add_child(_pivot)
		_pivot.global_transform = Transform3D(prop.global_basis, hinge.global_position)
		var at := handle.global_transform
		handle.get_parent().remove_child(handle)
		_pivot.add_child(handle)
		handle.global_transform = at
	_lamp_power = prop.find_child("lamp_power", true, false) as MeshInstance3D
	_lamp_cell = prop.find_child("lamp_cell", true, false) as MeshInstance3D
	var socket := prop.find_child("SOCKET_cell", true, false) as Node3D
	if socket != null:
		_cell = CELL.instantiate()
		socket.add_child(_cell)
		Deck._mark_interior(_cell)
	var plate := prop.find_child("SOCKET_letter", true, false) as Node3D
	if plate != null:
		var letter := Label3D.new()
		letter.text = DerelictLayout.letter(section)
		letter.font = FONT
		letter.font_size = 40
		letter.pixel_size = 0.0016
		letter.modulate = Color(0.08, 0.07, 0.06)
		letter.outline_size = 0
		letter.position = Vector3(0, 0, 0.004)
		letter.layers = Deck.INTERIOR_LAYER
		plate.add_child(letter)
	var lever := Switch.new()
	lever.name = "Switch"
	lever.breaker = self
	lever.hold = THROW_HOLD
	lever.housing = prop
	_box(lever, SWITCH_BOX, SWITCH_AT)
	var bay := Bay.new()
	bay.name = "Bay"
	bay.breaker = self
	bay.housing = prop
	_box(bay, BAY_BOX, BAY_AT)
	show_state(false)
	_angle = 0.0 if _on() else CUT_ANGLE
	_place_handle()


func _box(point: Interactable, size: Vector3, at: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	point.add_child(shape)
	point.position = at
	add_child(point)


func _on() -> bool:
	return power.on[section] if section < power.on.size() else false


func _seated() -> bool:
	return power.cells[section] if section < power.cells.size() else false


## Shows what the section's power state is: the cell in its cradle, the lamps; and, if `heard`,
## the switch's throw and a cell seating, as everyone hears them.
func show_state(heard: bool) -> void:
	var thrown := _on()
	var seated := _seated()
	if _cell != null:
		_cell.visible = seated
	if heard and thrown != _shown_on:
		Sound.breaker(self, thrown)
	if heard and seated and not _shown_cell:
		Sound.cell_seated(self)
	_shown_on = thrown
	_shown_cell = seated


func _process(delta: float) -> void:
	_time += delta
	var target := 0.0 if _on() else CUT_ANGLE
	_angle = move_toward(_angle, target, CUT_ANGLE / SWING * delta)
	_place_handle()
	if _lamp_power != null:
		_lamp_power.material_override = LAMP_GREEN if power.powered(section) else LAMP_DEAD
	if _lamp_cell != null:
		if _seated():
			_lamp_cell.material_override = LAMP_AMBER
		else:
			_lamp_cell.material_override = LAMP_RED if fmod(_time, 1.2) < 0.6 else LAMP_DEAD


func _place_handle() -> void:
	if _pivot != null:
		_pivot.rotation.x = _angle


## The knife switch: THROW (on), CUT (off).
class Switch extends Interactable:
	var breaker: Breaker

	func prompt(_player: Player) -> String:
		return "CUT" if breaker._on() else "THROW"

	func request_use() -> void:
		breaker.power.throw(breaker.section)


## The cradle: INSERT CELL with one in hand; TAKE CELL from it once the switch is cut.
class Bay extends Interactable:
	var breaker: Breaker

	func prompt(player: Player) -> String:
		if breaker._seated():
			return "SWITCH ON" if breaker._on() else "TAKE CELL"
		return "INSERT CELL" if player.held == &"power_cell" else "NO CELL"

	func usable_by(player: Player) -> bool:
		if not enabled:
			return false
		if breaker._seated():
			return not breaker._on() and player.room_for(&"power_cell")
		return player.held == &"power_cell"

	## On the crew member's machine: the cell goes from their hand into the cradle; or out of it
	## into their hand (the host hands it over).
	func request_use() -> void:
		var player := Player.local(get_tree())
		if player == null:
			return
		if breaker._seated():
			breaker.power.take(breaker.section)
			return
		if player.held != &"power_cell":
			return
		player.take_from_hands()
		var spill := Transform3D(global_basis, global_position + global_basis.z * 0.5)
		breaker.power.insert(breaker.section, spill)
