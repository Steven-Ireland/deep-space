class_name Door
extends Node3D
## A sliding bulkhead door (lk_door) in a door wall. Crew open and close it from either side
## (DoorPanel); the host applies it and the state replicates (MultiplayerSynchronizer, so late
## joiners see it too). The wall's status lamp shows green when open, amber when shut, red when
## sealed, dark without power. Everyone hears it open and shut (Sound.door).
##
## In a derelict a door needs its section's power (DerelictPower sets `powered`): dead, it's stuck
## as it is, and a shut one can only be forced open with a crowbar (`forced`: its leaves jammed most
## of the way apart, for good). Sealed, it says why (`seal_text`): SEALED, LOCKED (a vault),
## LOCKDOWN (a crowbar forces it), VENTING, BUCKLED (PrizeEvent).

const OPEN_GAP := 0.9 # how far each leaf slides, metres
const SPEED := 1.8 # metres per second: heavy, not instant
## Forced open, the leaves stop this share of the way (jammed), and wrench apart this fast.
const FORCED_GAP := 0.72
const FORCED_SPEED := 3.0

const LAMP_OPEN := preload("res://assets/materials/lk_lamp_open.tres")
const LAMP_SHUT := preload("res://assets/materials/lk_lamp_shut.tres")
const LAMP_SEALED := preload("res://assets/materials/lk_lamp_sealed.tres")
const LAMP_DEAD := preload("res://assets/materials/lk_lamp_dead.tres")
## What a door locked down by a derelict's security says (PrizeEvent): a crowbar forces it.
const LOCKDOWN := "LOCKDOWN"

@export var open := false:
	set(value):
		if value != open and _live:
			Sound.door(self, value)
			Noises.make(self, global_position, &"door")
		open = value
		_update_state()
@export var sealed := false:
	set(value):
		sealed = value
		_update_state()
## Whether it has power (always, aboard the LANTERN; a derelict's from its section's).
@export var powered := true:
	set(value):
		powered = value
		_update_state()
## Forced open with a crowbar (a dead door): it stays open, jammed.
@export var forced := false
## Faulty (a derelict's hazard, Hazards): with power it cycles on a dying circuit, the host working
## it; it slams shut SLAM times as fast as it should, and its lamp stutters.
@export var faulty := false
const SLAM := 3.0
## What its panels say while it's sealed.
@export var seal_text := "SEALED":
	set(value):
		seal_text = value
		_update_state()

## The wall's status_lamp mesh (set by the Deck).
var lamp: MeshInstance3D
## Whether it's had a frame yet: until then it's being built, and starts as it's set, at once and
## silently (a derelict's doors are made open or shut).
var _live := false

@onready var left: Node3D = $Leaves.find_child("leaf_left", true, false)
@onready var right: Node3D = $Leaves.find_child("leaf_right", true, false)
@onready var blocker: CollisionShape3D = $Blocker/Shape
@onready var panels: Array[DoorPanel] = [$PanelFront, $PanelBack]


func _ready() -> void:
	for panel in panels:
		panel.used.connect(_on_used)
	_update_state()


func _process(delta: float) -> void:
	var gap := OPEN_GAP * (FORCED_GAP if forced else 1.0)
	var target := gap if open else 0.0
	var speed := FORCED_SPEED if forced else SPEED * (SLAM if faulty and not open else 1.0)
	var slide := speed * delta if _live else OPEN_GAP
	_live = true
	left.position.x = move_toward(left.position.x, -target, slide)
	right.position.x = move_toward(right.position.x, target, slide)
	# Solid until it's nearly open, so nobody slips through a closing door.
	blocker.disabled = left.position.x < -gap * 0.8
	if faulty and powered and not sealed and lamp != null:
		# A dying circuit: its lamp won't hold steady.
		lamp.material_override = LAMP_DEAD if randf() < 0.3 else (LAMP_OPEN if open else LAMP_SHUT)


## Host: a panel's been used by `peer`: with power, the door opens or shuts; without, a crew member
## heaving at it with a crowbar forces it open, for good.
func _on_used(peer: int) -> void:
	var player := Player.of_peer(get_tree(), peer)
	if sealed:
		if seal_text == LOCKDOWN and player != null and player.held == &"crowbar":
			sealed = false
			forced = true
			open = true
			print("Door %s: forced out of its lockdown." % name)
		return
	if powered:
		if not faulty:
			open = not open
		return
	if not open and player != null and player.held == &"crowbar":
		forced = true
		open = true
		print("Door %s: forced open." % name)


## A crowbar heaving at it (DoorPanel.heave): everyone hears it, and so does anything listening.
@rpc("any_peer", "call_local", "reliable")
func heaved() -> void:
	Sound.pry(self)
	Noises.make(self, global_position + Vector3.UP * 1.15, &"pry", Player.of_peer(get_tree(), maxi(1, multiplayer.get_remote_sender_id())))


func _update_state() -> void:
	if not is_node_ready():
		return
	for panel in panels:
		panel.verb = seal_text if sealed else ("CLOSE" if open else "OPEN")
		panel.enabled = true
	if lamp != null:
		lamp.material_override = LAMP_SEALED if sealed else (LAMP_DEAD if not powered else (LAMP_OPEN if open else LAMP_SHUT))
