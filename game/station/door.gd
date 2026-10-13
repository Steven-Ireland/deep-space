class_name Door
extends Node3D
## A sliding bulkhead door (lk_door) in a door wall. Crew open and close it from either side; the
## host applies it and the state replicates (MultiplayerSynchronizer, so late joiners see it too).
## The wall's status lamp shows green when open, amber when shut, red when sealed.

const OPEN_GAP := 0.9 # how far each leaf slides, metres
const SPEED := 1.8 # metres per second: heavy, not instant

const LAMP_OPEN := preload("res://assets/materials/lk_lamp_open.tres")
const LAMP_SHUT := preload("res://assets/materials/lk_lamp_shut.tres")
const LAMP_SEALED := preload("res://assets/materials/lk_lamp_sealed.tres")

@export var open := false:
	set(value):
		open = value
		_update_state()
@export var sealed := false:
	set(value):
		sealed = value
		_update_state()

## The wall's status_lamp mesh (set by the Deck).
var lamp: MeshInstance3D

@onready var left: Node3D = $Leaves.find_child("leaf_left", true, false)
@onready var right: Node3D = $Leaves.find_child("leaf_right", true, false)
@onready var blocker: CollisionShape3D = $Blocker/Shape
@onready var panels: Array[Interactable] = [$PanelFront, $PanelBack]


func _ready() -> void:
	for panel in panels:
		panel.used.connect(_on_used)
	_update_state()


func _process(delta: float) -> void:
	var target := OPEN_GAP if open else 0.0
	left.position.x = move_toward(left.position.x, -target, SPEED * delta)
	right.position.x = move_toward(right.position.x, target, SPEED * delta)
	# Solid until it's nearly open, so nobody slips through a closing door.
	blocker.disabled = left.position.x < -OPEN_GAP * 0.8


func _on_used(_peer: int) -> void:
	if not sealed:
		open = not open


func _update_state() -> void:
	if not is_node_ready():
		return
	for panel in panels:
		panel.verb = "SEALED" if sealed else ("CLOSE" if open else "OPEN")
		panel.enabled = not sealed
	if lamp != null:
		lamp.material_override = LAMP_SEALED if sealed else (LAMP_OPEN if open else LAMP_SHUT)
