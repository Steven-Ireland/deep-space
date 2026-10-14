extends Node
## What the crew hear (GDD §15; an autoload, `Sound`): low-fi samples (tools/build_audio.py) on the
## buses in default_bus_layout.tres:
##   World    everything heard through the air: doors, footfalls, a teammate's lamp switch, the
##            consoles, the jump, and Ambient, the sound of the place itself. Out of the air it's
##            heavily low-passed: the vacuum rule, heard only through contact.
##   Suit     inside the helmet (the lamp's switch; breathing and the radio to come): clear anywhere.
## The ambience follows the crew member at this machine: the LANTERN's hum aboard (a comfort, and
## its absence a warning), a derelict's drone in one, nothing out in space. Aboard in a jump (Run,
## GDD §5) the hum drops out: the drive spools up, the tunnel's mouth booms, its roar takes the
## hum's place, and coming out the drive winds down; the hum comes back once it's over.

## The vacuum low-pass's cutoff out of the air and in it (Hz), and how fast it follows (per second).
const CUTOFF_VACUUM := 380.0
const CUTOFF_AIR := 20500.0
const MUFFLE_RATE := 10.0
## Each ambience's level in the air (dB), how much lower it is in vacuum, and how fast it fades
## from one to another.
const AMBIENT_DB := {&"lantern": -10.5, &"derelict": -10.5, &"tunnel": -2.5}
const VACUUM_DB := -13.5
const SILENT_DB := -80.0
const FADE_RATE := 3.0
## The jump's sounds' level (dB).
const JUMP_DB := -1.5
## Footfalls' level (dB), at a walk: well under everything else, or every step crowds the rest.
const STEP_DB := -10.0
## Sounds in the world play at full level within NEAR metres, falling off beyond.
const NEAR := 4.0

const LAMP_ON := preload("res://assets/audio/player/lamp_click_on.wav")
const LAMP_OFF := preload("res://assets/audio/player/lamp_click_off.wav")
const DOOR_OPEN := preload("res://assets/audio/foley/door_open.wav")
const DOOR_CLOSE := preload("res://assets/audio/foley/door_close.wav")
const LANDING := preload("res://assets/audio/foley/step_land.wav")
## Footfalls on each place's deck: the LANTERN's steel, a derelict's.
const STEPS := {
	&"lantern": [
		preload("res://assets/audio/foley/step_metal_01.wav"),
		preload("res://assets/audio/foley/step_metal_02.wav"),
		preload("res://assets/audio/foley/step_metal_03.wav"),
		preload("res://assets/audio/foley/step_metal_04.wav"),
	],
	&"derelict": [
		preload("res://assets/audio/foley/step_derelict_01.wav"),
		preload("res://assets/audio/foley/step_derelict_02.wav"),
		preload("res://assets/audio/foley/step_derelict_03.wav"),
		preload("res://assets/audio/foley/step_derelict_04.wav"),
	],
}
## Each ambience, looping: a place's, or the tunnel's in a jump.
const AMBIENCE := {
	&"lantern": preload("res://assets/audio/ambient/station_hum.wav"),
	&"derelict": preload("res://assets/audio/ambient/derelict_ambience.wav"),
	&"tunnel": preload("res://assets/audio/ambient/hyperspace_loop.wav"),
}
## What's heard as the jump reaches each stage: the drive spooling up from the lever, the tunnel's
## mouth going in, and coming out.
const JUMP := {
	&"spool": preload("res://assets/audio/ambient/jump_spool.wav"),
	&"tunnel": preload("res://assets/audio/ambient/jump_enter.wav"),
	&"arrival": preload("res://assets/audio/ambient/jump_exit.wav"),
}
## A console under the operator's hand: a press, a request sent, a request it can't make now.
const CONSOLE := {
	&"click": preload("res://assets/audio/foley/terminal_click.wav"),
	&"confirm": preload("res://assets/audio/foley/terminal_beep.wav"),
	&"refuse": preload("res://assets/audio/foley/terminal_error.wav"),
}
const CELL_SEATED := preload("res://assets/audio/foley/fuel_cell_load.wav")
const HATCH_OPEN := preload("res://assets/audio/foley/hatch_open.wav")
const HATCH_CLOSE := preload("res://assets/audio/foley/hatch_close.wav")
const AIRLOCK_VENT := preload("res://assets/audio/foley/airlock_vent.wav")
const AIRLOCK_FILL := preload("res://assets/audio/foley/airlock_fill.wav")
## The docking collar: the tube's motor running out or in, the hulls meeting, the clamps.
const COLLAR := {
	&"motor": preload("res://assets/audio/foley/collar_motor.wav"),
	&"contact": preload("res://assets/audio/foley/dock_contact.wav"),
	&"clamps": preload("res://assets/audio/foley/dock_clamps.wav"),
}
const TAKEN := preload("res://assets/audio/foley/item_pickup.wav")

var _vacuum: AudioEffectLowPassFilter
var _ambience := {} # ambience: its AudioStreamPlayer, always playing, faded in and out
var _stage := &"" # the jump's stage last heard (&"" none)


func _ready() -> void:
	_vacuum = AudioServer.get_bus_effect(AudioServer.get_bus_index(&"World"), 0)
	for place: StringName in AMBIENCE:
		var player := AudioStreamPlayer.new()
		player.name = "Ambience_" + place
		player.stream = AMBIENCE[place]
		player.bus = &"Ambient"
		player.volume_db = SILENT_DB
		add_child(player)
		player.play()
		_ambience[place] = player


func _process(delta: float) -> void:
	var crew := get_tree().get_first_node_in_group(&"local_player") as Player
	var place := place_of(crew) if crew != null else &""
	var stage := _stage_of(Run.of(self))
	_follow_jump(stage, place == &"lantern")
	if place == &"lantern" and stage != &"":
		place = &"tunnel" if stage == &"tunnel" else &""
	_listen(delta, place, crew != null and crew.in_vacuum)


## Eases toward what's heard: `ambience` (&"lantern", &"derelict", &"tunnel", or &"" for none), in
## vacuum or in the air.
func _listen(delta: float, ambience: StringName, vacuum: bool) -> void:
	_vacuum.cutoff_hz = lerpf(_vacuum.cutoff_hz, CUTOFF_VACUUM if vacuum else CUTOFF_AIR, 1.0 - exp(-delta * MUFFLE_RATE))
	var fade := 1.0 - exp(-delta * FADE_RATE)
	for each: StringName in _ambience:
		var level := SILENT_DB
		if each == ambience:
			level = AMBIENT_DB[each] + (VACUUM_DB if vacuum else 0.0)
		_ambience[each].volume_db = lerpf(_ambience[each].volume_db, level, fade)


## The jump's stage: &"spool", &"tunnel", &"arrival", or &"" with none under way.
static func _stage_of(run: Run) -> StringName:
	if run == null or not run.jumping():
		return &""
	if run.jump_elapsed() < Run.SPOOL:
		return &"spool"
	return &"tunnel" if run.in_tunnel() else &"arrival"


## Plays each stage of the jump as it's reached, for crew aboard; not for one joining partway.
func _follow_jump(stage: StringName, aboard: bool) -> void:
	if stage == _stage:
		return
	var joined := _stage == &"" and stage != &"spool"
	_stage = stage
	if aboard and not joined and JUMP.has(stage):
		_play(JUMP[stage], &"World", JUMP_DB)


## Where `crew` is, by the zone at their chest: &"lantern" aboard, &"derelict" in a derelict, or
## &"" out in space.
static func place_of(crew: Player) -> StringName:
	var zone := Zone.at(crew.get_world_3d(), crew.global_position + Vector3.UP * Player.CHEST_HEIGHT)
	if zone == null:
		return &""
	return &"lantern" if zone.get_parent().is_in_group(&"lantern") else &"derelict"


## A crew member's footfall on the deck under them: harder at a sprint, softer crouched, heavier
## carrying something big.
func footstep(crew: Player) -> void:
	var steps: Array = STEPS.get(place_of(crew), STEPS[&"lantern"])
	var volume := STEP_DB
	var pitch := randf_range(0.96, 1.05)
	if crew.sprinting:
		volume += 2.0
		pitch *= 1.03
	elif crew.crouching:
		volume -= 8.0
		pitch *= 0.94
	elif Items.two_handed(crew.held):
		volume += 1.5
		pitch *= 0.88
	_from(crew, steps.pick_random(), 24.0, volume, pitch)


## A crew member coming down from a jump or a fall: both boots at once.
func landing(crew: Player) -> void:
	_from(crew, LANDING, 28.0, 2.0, randf_range(0.97, 1.03))


## A crew member's helmet lamp switched on or off: in their own helmet, or from their head for
## anyone near.
func lamp_switch(crew: Player, on: bool) -> void:
	var stream := LAMP_ON if on else LAMP_OFF
	if crew.is_multiplayer_authority():
		_play(stream, &"Suit")
	else:
		_play_at(stream, crew.head, 18.0, 2.0)


## Something taken into a crew member's hands or onto their belt.
func taken(crew: Player) -> void:
	_from(crew, TAKEN, 10.0, 0.0, randf_range(0.97, 1.03))


## A fuel cell seating in a bay of the fuel rack (`bay`, where it sits).
func cell_seated(bay: Node3D) -> void:
	_play_at(CELL_SEATED, bay, 20.0)


## A console (`what`: a CONSOLE sound) from its screen.
func console(terminal: Terminal, what: StringName) -> void:
	_play_at(CONSOLE[what], terminal, 12.0, 0.0, 1.0, terminal.to_local(terminal.screen_centre()))


## A door sliding open or shut, from the middle of its opening.
func door(at: Node3D, opening: bool) -> void:
	_play_at(DOOR_OPEN if opening else DOOR_CLOSE, at, 28.0, 2.0, randf_range(0.97, 1.03), Vector3.UP * 1.15)


## A pressure hatch swinging open or shut, from its middle.
func hatch(at: Hatch, opening: bool) -> void:
	_play_at(HATCH_OPEN if opening else HATCH_CLOSE, at, 30.0, 2.0, randf_range(0.97, 1.03), Vector3.UP * Hatch.CENTRE)


## An airlock's chamber venting or filling, from the middle of it.
func airlock(chamber: Node3D, filling: bool) -> void:
	_play_at(AIRLOCK_FILL if filling else AIRLOCK_VENT, chamber, 24.0, 0.0)


## The docking collar (`what`: a COLLAR sound) from `along` metres out along its tube.
func collar(what: StringName, tube: Node3D, along: float) -> void:
	_play_at(COLLAR[what], tube, 40.0, 3.0, 1.0, Vector3(0, 1.2, along) / tube.scale)


## Plays `stream` from `crew`: in their own ears for the crew member at this machine, from where
## they stand for everyone else, heard up to `reach` metres away.
func _from(crew: Player, stream: AudioStream, reach: float, volume_db: float, pitch: float) -> void:
	if crew.is_multiplayer_authority():
		_play(stream, &"World", volume_db, pitch)
	else:
		_play_at(stream, crew, reach, volume_db, pitch)


## Plays `stream` once on `bus`, not placed in the world.
func _play(stream: AudioStream, bus: StringName, volume_db := 0.0, pitch := 1.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


## Plays `stream` once from `source` (`offset` from it, moving with it) through the air: full
## within NEAR metres, falling off beyond, silent past `reach`.
func _play_at(stream: AudioStream, source: Node3D, reach: float, volume_db := 0.0, pitch := 1.0, offset := Vector3.ZERO) -> void:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = &"World"
	player.unit_size = NEAR
	player.max_distance = reach
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.position = offset
	player.finished.connect(player.queue_free)
	source.add_child(player)
	player.play()
