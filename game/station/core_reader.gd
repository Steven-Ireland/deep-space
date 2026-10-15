class_name CoreReader
extends Node3D
## The LANTERN's core reader (GDD §6; art/blender/rooms.py: rm_core_reader), beside the science
## station: where the crew seat a survey core they've carried back from a derelict or a relay. With
## one in their arms, INSERT CORE: it's read for Run.SCAN_TIME, its READ lamp blinking and the core's
## chart glowing, then the jumps on from here are identified (Run, the Nav Chart, the chart table).
## The spent core stays seated till the next jump. One a system: a second won't be taken once the
## jumps are charted. Its SEAT lamp is green while it'll take a core, amber with one seated.

const CORE := preload("res://assets/models/items/it_survey_core.glb")
const LAMP_GREEN := preload("res://assets/materials/lk_lamp_open.tres")
const LAMP_AMBER := preload("res://assets/materials/lk_lamp_shut.tres")
const LAMP_DEAD := preload("res://assets/materials/lk_lamp_dead.tres")
## The box crew aim at over the well, in the reader's space.
const SLOT_AT := Vector3(0, 0.95, 0.0)
const SLOT_SIZE := Vector3(0.62, 0.5, 0.56)

var _core: Node3D
var _lamp_seat: MeshInstance3D
var _lamp_read: MeshInstance3D
var _time := 0.0


## A reader fitted to `prop` (an rm_core_reader).
static func fit(prop: Node3D) -> CoreReader:
	var reader := CoreReader.new()
	reader.name = "CoreReader"
	prop.add_child(reader)
	return reader


func _ready() -> void:
	var prop := get_parent() as Node3D
	_lamp_seat = prop.find_child("lamp_seat", true, false) as MeshInstance3D
	_lamp_read = prop.find_child("lamp_read", true, false) as MeshInstance3D
	var socket := prop.find_child("SOCKET_core", true, false) as Node3D
	if socket != null:
		_core = CORE.instantiate()
		_core.visible = false
		socket.add_child(_core)
		Deck._mark_interior(_core)
	var slot := Slot.new()
	slot.name = "Slot"
	slot.housing = prop
	slot.position = SLOT_AT
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SLOT_SIZE
	shape.shape = box
	slot.add_child(shape)
	add_child(slot)


func _process(delta: float) -> void:
	_time += delta
	var run := Run.of(self)
	if run == null:
		return
	if _core != null:
		_core.visible = run.core_seated
	if _lamp_seat != null:
		_lamp_seat.material_override = LAMP_AMBER if run.core_seated else (LAMP_GREEN if run.can_read() else LAMP_DEAD)
	if _lamp_read != null:
		if run.scanning():
			_lamp_read.material_override = LAMP_AMBER if fmod(_time, 0.4) < 0.2 else LAMP_DEAD
		else:
			_lamp_read.material_override = LAMP_GREEN if run.scanned else LAMP_DEAD


## The well on top: INSERT CORE with one in both arms; otherwise what it's doing.
class Slot extends Interactable:
	func prompt(player: Player) -> String:
		var run := Run.of(self)
		if run == null:
			return "NO CORE"
		if Items.kind_of(player.carrying) == &"survey_core":
			if run.can_read():
				return "INSERT CORE"
			return "JUMPING" if run.jumping() else ("CHARTED" if run.scanned else "BUSY")
		if run.scanning():
			return "READING"
		return "CHARTED" if run.scanned else "NO CORE"

	func usable_by(player: Player) -> bool:
		var run := Run.of(self)
		return enabled and run != null and run.can_read() and Items.kind_of(player.carrying) == &"survey_core"

	## On the carrier's machine: the core leaves their arms for the reader (the host reads it, or
	## sets it down in front if it can't).
	func request_use() -> void:
		var player := Player.local(get_tree())
		if player == null or Items.kind_of(player.carrying) != &"survey_core":
			return
		player.take_from_hands()
		var spill := Transform3D(player.global_basis, player.global_position + player.global_basis * Vector3(0, 0.6, -0.8))
		Run.of(self).read_core(spill)
		Sound.cell_seated(self)
