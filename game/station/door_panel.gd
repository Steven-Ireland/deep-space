class_name DoorPanel
extends Interactable
## A door's panel, one each side (Door): OPEN or CLOSE while the door has power; with none (a dead
## derelict section, GDD §8.3) it's stuck as it is: NO POWER, unless it's shut and the crew member
## has a crowbar in hand, when they can PRY it open, heaving at it for PRY_TIME (loud: every heave
## is heard, Noises). Sealed, it says why (SEALED, LOCKED, LOCKDOWN, VENTING, BUCKLED); a crowbar
## can FORCE a locked-down one, heaving for FORCE_TIME. A faulty one with power is nobody's to work
## (FAULT): it cycles on its own (Hazards).

## Seconds of heaving with a crowbar to force a dead door open, and a locked-down one (GDD §8.3:
## its bolts sheared, not just its leaves).
const PRY_TIME := 2.4
const FORCE_TIME := 5.0

var door: Door


func _ready() -> void:
	door = get_parent() as Door


func _prying(player: Player) -> bool:
	return not door.powered and not door.open and not door.sealed and player.held == &"crowbar"


## Whether `player` can force it out of a lockdown: a crowbar in hand.
func _forcing(player: Player) -> bool:
	return door.sealed and door.seal_text == Door.LOCKDOWN and player.held == &"crowbar"


func prompt(player: Player) -> String:
	if _forcing(player):
		return "FORCE"
	if door.sealed:
		return door.seal_text
	if door.powered and door.faulty:
		return "FAULT"
	if door.powered:
		return "CLOSE" if door.open else "OPEN"
	return "PRY" if _prying(player) else "NO POWER"


func usable_by(player: Player) -> bool:
	return enabled and ((not door.sealed and ((door.powered and not door.faulty) or _prying(player))) or _forcing(player))


func hold_for(player: Player) -> float:
	return FORCE_TIME if _forcing(player) else (PRY_TIME if _prying(player) else 0.0)


## On the prier's machine: a heave of the crowbar at the door, heard by everyone.
func heave() -> void:
	door.heaved.rpc()
