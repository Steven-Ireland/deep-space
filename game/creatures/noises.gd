class_name Noises
## What the things living in a derelict hear (GDD §12): the Crawler hunts by sound alone. Noises is
## made wherever something happens: a crew member's footfalls (barely anything crouched, a lot at
## a sprint), a jump's landing, a door or hatch, something dropped or thrown landing, a tool
## striking, a shock prod's jolt, a burning flare's hiss. It's heard only on the host, where the
## creatures think: each one hears it if it carries that far to it, through the rooms
## (Creature.hear; a shut door muffles it).
##
## A noise is its kind (REACH), where it was, and who made it, if a crew member did: a creature
## that hears a crew member knows where they were, not where they've gone. A flare's hiss lures,
## but has no one behind it; it finds whoever holds it by getting close.

## How far each kind carries, in metres along the way through the rooms.
const REACH := {
	&"sneak": 1.5, # a footfall crouched
	&"step": 6.0, # walking
	&"heavy_step": 8.0, # walking with something big in both hands
	&"sprint": 16.0,
	&"land": 10.0, # coming down from a jump
	&"door": 18.0,
	&"hatch": 20.0,
	&"drop": 4.0, # something set down
	&"clatter": 12.0, # something thrown, landing (heavier, louder: Pickup scales it)
	&"swing": 3.0, # a tool's swing through the air
	&"hit": 12.0, # a tool striking something
	&"zap": 14.0, # a shock prod's jolt
	&"flare": 10.0, # a burning flare's hiss, every second
	&"bang": 16.0, # a creature beating on a door
	&"breaker": 18.0, # a breaker's switch thrown, or cut
	&"pry": 14.0, # a crowbar forcing a dead door, every heave
	&"buzz": 10.0, # a lock panel refusing a code
	&"alarm": 26.0, # an alarm sounding (a locked-out panel, security waking)
}


## Makes a noise of kind `what` at `at` (world space), by `source` (a crew member, or null),
## carrying `reach` metres if given (else its kind's). Only the host's creatures hear it, so it's
## nothing anywhere else.
static func make(from: Node, at: Vector3, what: StringName, source: Node = null, reach := -1.0) -> void:
	if from == null or not from.is_inside_tree() or not from.multiplayer.is_server():
		return
	var carries: float = reach if reach >= 0.0 else REACH.get(what, 6.0)
	for creature in from.get_tree().get_nodes_in_group(&"creatures"):
		if creature != source:
			creature.hear(at, carries, what, source)


## The noise a crew member's footfall makes, by their gait.
static func step_of(crew: Player) -> StringName:
	if crew.crouching:
		return &"sneak"
	if crew.sprinting:
		return &"sprint"
	return &"heavy_step" if Items.two_handed(crew.held) else &"step"
