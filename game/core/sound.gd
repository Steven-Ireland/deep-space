extends Node
## What the crew hear (GDD §15; an autoload, `Sound`): low-fi samples (tools/build_audio.py) on the
## buses in default_bus_layout.tres:
##   World    everything heard through the air: doors, footfalls, a teammate's lamp switch, the
##            consoles, the jump, and Ambient, the sound of the place itself. Out of the air it's
##            heavily low-passed: the vacuum rule, heard only through contact.
##   Suit     inside the helmet (the lamp's switch, the EVA harness's jets, the suit panel, the
##            dosimeter, a breach's hiss; breathing to come): clear anywhere.
##   Radio    the communicator (GDD §10): the channel keyed and released, its hiss while it's open
##            (and the crew's voices, to come: TECH §2); clear anywhere. Its spectrum is read for
##            the cuff's waterfall and the visor's bars (radio_spectrum).
## The ambience follows the crew member at this machine: the LANTERN's hum aboard (a comfort, and
## its absence a warning), a derelict's drone in one, a working relay's whine and fans in a
## satellite, nothing out in space. Aboard in a jump (Run,
## GDD §5) the hum drops out: the drive spools up, the tunnel's mouth booms, its roar takes the
## hum's place, and coming out the drive winds down; the hum comes back once it's over.

## The vacuum low-pass's cutoff out of the air and in it (Hz), and how fast it follows (per second).
const CUTOFF_VACUUM := 380.0
const CUTOFF_AIR := 20500.0
const MUFFLE_RATE := 10.0
## Each ambience's level in the air (dB), how much lower it is in vacuum, and how fast it fades
## from one to another.
const AMBIENT_DB := {&"lantern": -10.5, &"derelict": -10.5, &"satellite": -9.0, &"tunnel": -2.5}
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
	&"satellite": preload("res://assets/audio/ambient/satellite_hum.wav"),
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
## The EVA harness (GDD §8.1): its jets' hiss (a loop played at their push), clipping it on or off,
## and a suit knocking into something, weightless.
const JETS := preload("res://assets/audio/foley/rcs_jet.wav")
const HARNESS := preload("res://assets/audio/foley/harness_clip.wav")
const BUMP := preload("res://assets/audio/foley/suit_bump.wav")
const JETS_DB := -7.0
## Something loose landing (GDD §9.4): small things, and big ones (a fuel cell, a body).
const CLATTER := [
	preload("res://assets/audio/foley/item_clatter_01.wav"),
	preload("res://assets/audio/foley/item_clatter_02.wav"),
	preload("res://assets/audio/foley/item_clatter_03.wav"),
]
const CLATTER_HEAVY := preload("res://assets/audio/foley/item_clatter_heavy.wav")
## A tool striking something solid; striking flesh; a shock prod's jolt.
const TOOL_STRIKE := [
	preload("res://assets/audio/foley/tool_strike_01.wav"),
	preload("res://assets/audio/foley/tool_strike_02.wav"),
]
const FLESH_HIT := [
	preload("res://assets/audio/foley/flesh_hit_01.wav"),
	preload("res://assets/audio/foley/flesh_hit_02.wav"),
]
const ZAP := preload("res://assets/audio/foley/prod_zap.wav")
## What the creatures sound like (GDD §15: mostly heard before they're seen): each sound, how far
## it carries (metres) and its level (dB). Some have several takes, picked at random.
const CREATURE := {
	&"crawler_click": [[preload("res://assets/audio/creatures/crawler_click_01.wav"),
			preload("res://assets/audio/creatures/crawler_click_02.wav"),
			preload("res://assets/audio/creatures/crawler_click_03.wav")], 22.0, -4.0],
	&"crawler_step": [[preload("res://assets/audio/creatures/crawler_step_01.wav"),
			preload("res://assets/audio/creatures/crawler_step_02.wav"),
			preload("res://assets/audio/creatures/crawler_step_03.wav")], 16.0, -8.0],
	&"crawler_shriek": [[preload("res://assets/audio/creatures/crawler_shriek.wav")], 40.0, 2.0],
	&"crawler_lunge": [[preload("res://assets/audio/creatures/crawler_lunge.wav")], 24.0, 0.0],
	&"crawler_snarl": [[preload("res://assets/audio/creatures/crawler_snarl.wav")], 20.0, 0.0],
	&"crawler_hurt": [[preload("res://assets/audio/creatures/crawler_hurt.wav")], 24.0, 0.0],
	&"crawler_death": [[preload("res://assets/audio/creatures/crawler_death.wav")], 30.0, 0.0],
	&"crawler_stunned": [[preload("res://assets/audio/creatures/crawler_stunned.wav")], 20.0, -2.0],
	&"crawler_bang": [[preload("res://assets/audio/creatures/crawler_bang.wav")], 36.0, 2.0],
	&"hanger_creak": [[preload("res://assets/audio/creatures/hanger_creak.wav")], 12.0, -6.0],
	&"hanger_grab": [[preload("res://assets/audio/creatures/hanger_grab.wav")], 24.0, 2.0],
	&"hanger_hurt": [[preload("res://assets/audio/creatures/hanger_hurt.wav")], 24.0, 0.0],
	&"hanger_death": [[preload("res://assets/audio/creatures/hanger_death.wav")], 24.0, 0.0],
}
## The suit's alarm when its wearer's struck, and its monitor flatlining when they die (in their
## helmet; the Vitals board flatlines too).
const SUIT_WOUND := preload("res://assets/audio/player/suit_wound.wav")
const FLATLINE := preload("res://assets/audio/player/flatline.wav")
## A breached suit leaking out of the air (a loop played while it leaks), the dosimeter's tick, and
## what using something up sounds like (Player.used).
const SUIT_LEAK := preload("res://assets/audio/player/suit_leak.wav")
const LEAK_DB := -9.0
const GEIGER := preload("res://assets/audio/player/geiger_click.wav")
const USED := {
	&"o2_canister": preload("res://assets/audio/foley/canister_refill.wav"),
	&"sealant": preload("res://assets/audio/foley/sealant_patch.wav"),
}
## The suit panel (GDD §10) on the visor: opening, closing, a pick, a thing moved between slots.
const UI := {
	&"open": preload("res://assets/audio/ui/ui_open.wav"),
	&"close": preload("res://assets/audio/ui/ui_close.wav"),
	&"tick": preload("res://assets/audio/ui/ui_tick.wav"),
	&"move": preload("res://assets/audio/ui/ui_move.wav"),
	&"deny": preload("res://assets/audio/foley/terminal_error.wav"),
	&"read": preload("res://assets/audio/foley/terminal_beep.wav"),
}
## The communicator (the wrist cuff): the channel keyed open and released, and an open channel's
## hiss, on the Radio bus (heard clear anywhere, as the suit's own).
const RADIO := {
	&"open": preload("res://assets/audio/ui/radio_open.wav"),
	&"close": preload("res://assets/audio/ui/radio_close.wav"),
}
const RADIO_STATIC := preload("res://assets/audio/ui/radio_static.wav")
const STATIC_DB := -22.0

var _vacuum: AudioEffectLowPassFilter
var _ambience := {} # ambience: its AudioStreamPlayer, always playing, faded in and out
var _stage := &"" # the jump's stage last heard (&"" none)
var _keyed := {} # each crew member on the channel at the last look
var _static: AudioStreamPlayer
var _spectrum: AudioEffectSpectrumAnalyzerInstance


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
	_static = AudioStreamPlayer.new()
	_static.name = "RadioStatic"
	_static.stream = RADIO_STATIC
	_static.bus = &"Radio"
	_static.volume_db = SILENT_DB
	add_child(_static)
	_static.play()
	var radio := AudioServer.get_bus_index(&"Radio")
	if radio >= 0 and AudioServer.get_bus_effect_count(radio) > 0:
		_spectrum = AudioServer.get_bus_effect_instance(radio, 0) as AudioEffectSpectrumAnalyzerInstance


func _process(delta: float) -> void:
	_follow_radio(delta)
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


## Where `crew` is, by the zone at their chest: &"lantern" aboard, &"derelict" in a derelict,
## &"satellite" in a relay, or &"" out in space.
static func place_of(crew: Player) -> StringName:
	var zone := Zone.at(crew.get_world_3d(), crew.global_position + Vector3.UP * Player.CHEST_HEIGHT)
	if zone == null:
		return &""
	if zone.get_parent().is_in_group(&"lantern"):
		return &"lantern"
	return &"satellite" if zone.get_parent().get_parent() is Satellite else &"derelict"


## The crew on the communicator's channel now (their cuff keyed: GDD §10), in crew order.
func talking() -> Array[Player]:
	var out: Array[Player] = []
	var crew := get_tree().get_nodes_in_group(&"crew")
	crew.sort_custom(func(a, b): return int(str(a.name)) < int(str(b.name)))
	for player: Player in crew:
		if player.cuff_up and not player.dead:
			out.append(player)
	return out


## The channel keyed and released, heard by everyone as each crew member keys it; its hiss while
## anyone's on it.
func _follow_radio(delta: float) -> void:
	var on := talking()
	for player in on:
		if not _keyed.has(player):
			radio(true)
	for player: Player in _keyed:
		if not is_instance_valid(player) or player not in on:
			radio(false)
	_keyed.clear()
	for player in on:
		_keyed[player] = true
	var level := STATIC_DB if not on.is_empty() else SILENT_DB
	_static.volume_db = lerpf(_static.volume_db, level, 1.0 - exp(-delta * 20.0))


## What's on the channel now: `bands` levels (0 .. about 1), log-spaced from 150 Hz to 4 kHz, the
## radio's passband.
func radio_spectrum(bands: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(bands)
	if _spectrum == null:
		return out
	for i in bands:
		var low := 150.0 * pow(4000.0 / 150.0, float(i) / bands)
		var high := 150.0 * pow(4000.0 / 150.0, float(i + 1) / bands)
		var magnitude := _spectrum.get_magnitude_for_frequency_range(low, high).length()
		out[i] = clampf((linear_to_db(maxf(magnitude, 1e-6)) + 72.0) / 60.0, 0.0, 1.0)
	return out


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


## A crew member putting the EVA harness on or stowing it, at the rack.
func harness(crew: Player) -> void:
	_from(crew, HARNESS, 12.0, 0.0, randf_range(0.97, 1.03))


## A crew member knocking into something, weightless: in their own suit, or from where they hit.
func bump(crew: Player) -> void:
	if crew.is_multiplayer_authority():
		_play(BUMP, &"Suit", -2.0, randf_range(0.95, 1.05))
	else:
		_play_at(BUMP, crew, 16.0, -2.0, randf_range(0.95, 1.05), Vector3.UP * Player.CHEST_HEIGHT)


## The EVA harness's jets on `crew`, looping silently until they fire (jets_level): in the
## wearer's helmet, or from their back for anyone near. Returns the player, for jets_level.
func jets(crew: Player) -> Node:
	var player: Node
	if crew.is_multiplayer_authority():
		player = AudioStreamPlayer.new()
		player.bus = &"Suit"
	else:
		var placed := AudioStreamPlayer3D.new()
		placed.bus = &"World"
		placed.unit_size = NEAR
		placed.max_distance = 20.0
		placed.position = Vector3.UP * Player.CHEST_HEIGHT
		player = placed
	player.name = "Jets"
	player.stream = JETS
	player.set("volume_db", SILENT_DB)
	crew.add_child(player)
	player.play()
	return player


## How hard the jets are firing, 0..1: their hiss follows it at once (valves, not a fade).
static func jets_level(player: Node, level: float) -> void:
	player.set("volume_db", JETS_DB + linear_to_db(level) if level > 0.02 else SILENT_DB)


## Something loose (`thing`, `mass` kg) landing, `strength` hard (0..1): heavier, deeper and farther.
func clatter(thing: Node3D, mass: float, strength: float) -> void:
	var heavy := mass >= 20.0
	var stream: AudioStream = CLATTER_HEAVY if heavy else CLATTER.pick_random()
	var volume := linear_to_db(clampf(strength, 0.1, 1.0)) + (2.0 if heavy else -2.0)
	_play_at(stream, thing, 22.0 if heavy else 16.0, volume, randf_range(0.92, 1.08) * (1.0 if mass > 1.0 else 1.2))


## A crew member's tool striking something solid at `at` (world space).
func tool_strike(crew: Player, at: Vector3) -> void:
	_play_at(TOOL_STRIKE.pick_random(), crew, 20.0, 0.0, randf_range(0.94, 1.06), crew.to_local(at))


## A blow landing on a creature.
func flesh_hit(creature: Creature) -> void:
	_play_at(FLESH_HIT.pick_random(), creature, 18.0, 0.0, randf_range(0.92, 1.08), Vector3.UP * 0.5)


## A shock prod's jolt, at the creature it struck.
func zap(creature: Creature) -> void:
	_play_at(ZAP, creature, 24.0, 2.0, randf_range(0.96, 1.04), Vector3.UP * 0.5)


## A creature's sound (`what`, a CREATURE key), from where it is.
func creature(source: Creature, what: StringName) -> void:
	var entry: Array = CREATURE[what]
	var offset := Vector3.UP * (0.5 if source is Crawler else -0.6)
	_play_at((entry[0] as Array).pick_random(), source, entry[1], entry[2], randf_range(0.95, 1.05), offset)


## A crew member struck by a creature: the blow on their suit, and its alarm (in their helmet).
func wounded(crew: Player) -> void:
	if crew.is_multiplayer_authority():
		_play(SUIT_WOUND, &"Suit", 0.0)
	else:
		_play_at(SUIT_WOUND, crew, 14.0, -4.0, 1.0, Vector3.UP * Player.CHEST_HEIGHT)


## A crew member using something up (`kind`: an O2 canister into the suit, a patch of sealant):
## in their own helmet, or from them for anyone near.
func used(crew: Player, kind: StringName) -> void:
	if not USED.has(kind):
		return
	if crew.is_multiplayer_authority():
		_play(USED[kind], &"Suit", -2.0, randf_range(0.97, 1.03))
	else:
		_play_at(USED[kind], crew, 12.0, -2.0, randf_range(0.97, 1.03), Vector3.UP * Player.CHEST_HEIGHT)


## A breached suit's leak on `crew`, looping silently until it leaks (leak_level): in the wearer's
## helmet, or from their suit for anyone near. Returns the player, for leak_level.
func leak(crew: Player) -> Node:
	return _loop_on(crew, SUIT_LEAK, "Leak", 10.0)


static func leak_level(player: Node, on: bool) -> void:
	player.set("volume_db", LEAK_DB if on else SILENT_DB)


## The suit's dosimeter ticking once, in its wearer's helmet.
func geiger() -> void:
	_play(GEIGER, &"Suit", -4.0, randf_range(0.9, 1.1))


## The suit panel (`what`: a UI sound), on the visor.
func ui(what: StringName) -> void:
	_play(UI[what], &"Suit", -6.0)


## The communicator keyed open or released (by anyone on the channel: everyone hears it).
func radio(opening: bool) -> void:
	_play(RADIO[&"open" if opening else &"close"], &"Radio", -4.0)


## A looping `stream` on `crew`, silent until its level is set: in their helmet (the Suit bus), or
## from their chest through the air for everyone else, heard to `reach` metres.
func _loop_on(crew: Player, stream: AudioStream, label: String, reach: float) -> Node:
	var player: Node
	if crew.is_multiplayer_authority():
		player = AudioStreamPlayer.new()
		player.bus = &"Suit"
	else:
		var placed := AudioStreamPlayer3D.new()
		placed.bus = &"World"
		placed.unit_size = NEAR
		placed.max_distance = reach
		placed.position = Vector3.UP * Player.CHEST_HEIGHT
		player = placed
	player.name = label
	player.stream = stream
	player.set("volume_db", SILENT_DB)
	crew.add_child(player)
	player.play()
	return player


## A crew member dying (`why`, Player.cause): their suit's monitor flatlining in their helmet.
func died(crew: Player, _why: StringName) -> void:
	if crew.is_multiplayer_authority():
		_play(FLATLINE, &"Suit", -6.0)


## The Vitals board flatlining (`terminal`), as a crew member dies.
func flatline(terminal: Terminal) -> void:
	_play_at(FLATLINE, terminal, 14.0, -4.0, 1.0, terminal.to_local(terminal.screen_centre()))


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
