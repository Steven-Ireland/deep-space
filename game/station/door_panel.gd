class_name DoorPanel
extends Interactable
## A door's panel, one each side (Door): OPEN or CLOSE while the door has power; with none (a dead
## derelict section, GDD §8.3) it's stuck as it is: NO POWER, unless it's shut and the crew member
## has a crowbar in hand, when they can PRY it open, heaving at it for PRY_TIME (loud: every heave
## is heard, Noises). Sealed, it says why (SEALED, LOCKED, LOCKDOWN, BUCKLED).

## Seconds of heaving with a crowbar to force a dead door open.
const PRY_TIME := 2.4

var door: Door


func _ready() -> void:
	door = get_parent() as Door


func _prying(player: Player) -> bool:
	return not door.powered and not door.open and not door.sealed and player.held == &"crowbar"


func prompt(player: Player) -> String:
	if door.sealed:
		return door.seal_text
	if door.powered:
		return "CLOSE" if door.open else "OPEN"
	return "PRY" if _prying(player) else "NO POWER"


func usable_by(player: Player) -> bool:
	return enabled and not door.sealed and (door.powered or _prying(player))


func hold_for(player: Player) -> float:
	return PRY_TIME if _prying(player) else 0.0


## On the prier's machine: a heave of the crowbar at the door, heard by everyone.
func heave() -> void:
	door.heaved.rpc()
