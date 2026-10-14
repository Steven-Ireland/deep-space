class_name Collar
extends Node3D
## The LANTERN's docking collar (GDD §5, §8.1, §8.3): how a derelict comes alongside and goes again.
## At a derelict node it waits out off the starboard bow, visible from the bridge's side port.
## Hold the COLLAR lever on the dock panel (the docking port, beside the collar's airlock) and the
## collar's tractor beam draws it in to line up, the collar's tube runs out to its hatch, the hulls meet, the clamps bite
## and the collar opens its hatch: docked, and the dock panel's EXT PRESS gauge reads what it holds.
## Crew cycle the collar's airlock (Airlock) to go across. Hold the lever again to undock: the
## siren sounds for COUNTDOWN seconds (hold again to abort) while the airlock cycles in, then the
## tube lets go and the beam pushes the derelict back out with its hatch open, venting, carrying whoever's
## still aboard. They breathe their suits' O2 until the crew docks again for them.
##
## The host owns the stage and sends it to everyone on each change (and to each crew member who
## joins); its timer runs down on every peer and the host finishes it. Every peer poses the
## derelict, the tube, the hatches, the panel and the siren from it.

## Seconds the derelict drifts in from where it waits (or back out), the tube runs out to it (or
## back in), the clamps take from contact to its hatch standing open, and the siren sounds.
const DRIFT := 16.0
const EXTEND := 3.0
const CLAMP := 4.5
const HATCH_AT := 2.0 # into CLAMP, the derelict's hatch starts to swing
const COUNTDOWN := 10.0
## Where the derelict waits: metres out along the collar's axis where it lines up for the last of
## the way in, and from there, how far off and how it's turned.
const LINE_UP := 14.0
const WAITING := Vector3(24.0, 0.0, -32.0)
const WAITING_YAW := deg_to_rad(-35.0)
## The tube's length, wall line to wall line (art/blender/hull.py: COLLAR_LENGTH), and how short it
## is drawn retracted.
const LENGTH := 4.0
const STOWED := 0.12
## The dock panel's split-off parts (art/blender/rooms.py: dock_panel), in its own space.
const DIAL := Vector3(-0.14, 1.47, 0.012)
const LEVER_PIVOT := Vector3(0.0, 0.9, 0.075)
const LEVER_GRIP := Vector3(0.0, 0.9, 0.2)
const LEVER_SIZE := Vector3(0.36, 0.8, 0.3)
const LEVER_HOLD := 2.0
## A jolt through the deck at contact.
const CONTACT_SHAKE := 0.5
## The tractor beam: where it leaves the collar (out past the hull's hatch collar, in the hatch
## piece's space), its colour, and the light it throws on the derelict's hull.
const BEAM_FROM := Vector3(0, 1.15, 1.1)
const BEAM_COLOUR := Color(0.55, 0.85, 1.0)
const BEAM_LIGHT := 3.0

const TUBE := preload("res://assets/models/hull/lk_collar_tube.glb")
const BEAM_SHADER := preload("res://game/rendering/tractor_beam.gdshader")
const SIREN := preload("res://assets/audio/ambient/dock_siren.wav")
const LAMP_GREEN := preload("res://assets/materials/lk_lamp_open.tres")
const LAMP_AMBER := preload("res://assets/materials/lk_lamp_shut.tres")
const LAMP_RED := preload("res://assets/materials/lk_lamp_sealed.tres")

## &"away", &"approach" (drifting in, then the tube running out), &"clamp", &"docked",
## &"countdown" (the siren), &"depart" (the tube in, then drifting off); the seconds left in it;
## and whether the derelict's vented (cast off with its hatch open).
var stage := &"away"
var left := 0.0
var vented := false

## The derelict in this system, attached by the Run on every peer (null with none).
var derelict: Derelict
## The LANTERN's collar hatch (the airlock's outer door) and the airlock.
var hatch: Hatch
var airlock: Airlock

var _mouth: Transform3D # where the derelict's hatch meets the tube's far end
var _tube: Node3D
var _tube_bodies: Array[CollisionShape3D] = []
var _tube_zone: CollisionShape3D
var _tube_light: OmniLight3D
var _zone: Zone
var _beam: MeshInstance3D
var _beam_light: SpotLight3D
var _lever: Node3D
var _lever_switch: DockLever
var _thrown := 0.0
var _needle: Node3D
var _lamp_contact: MeshInstance3D
var _lamp_seal: MeshInstance3D
var _siren: AudioStreamPlayer3D
var _beacons: Array[Beacon] = []
var _heard_stage := &"" # the stage last heard, so each cue sounds once on every peer
var _heard_elapsed := 0.0
var _contact_at := -100.0 # seconds (ticks) of the last contact, for the jolt


static func of(node: Node) -> Collar:
	return node.get_tree().get_first_node_in_group(&"collar") as Collar


## Fits the collar to `lantern` at its collar `hatch_piece` (whose +Z faces out), run from
## `dock_panel` (an rm_dock_panel), its airlock round `chamber` behind `inner`.
static func make(lantern: Deck, hatch_piece: Node3D, dock_panel: Node3D, inner: Door, chamber: Zone, cycle_panel: Node3D) -> Collar:
	var collar := Collar.new()
	collar.name = "Collar"
	lantern.add_child(collar)
	collar.hatch = hatch_piece.get_node("Hatch") as Hatch
	collar._mouth = Transform3D(hatch_piece.transform.basis, hatch_piece.transform.origin + hatch_piece.transform.basis.z * LENGTH)
	collar._fit_tube(lantern, hatch_piece.transform)
	collar._fit_beam(lantern, hatch_piece.transform)
	collar._fit_panel(dock_panel)
	collar.airlock = Airlock.make(collar, inner, collar.hatch, chamber, cycle_panel)
	collar.airlock.outside_pressure = collar.outside_pressure
	collar.airlock.outside_blocker = collar._lock_blocker
	return collar


func _ready() -> void:
	add_to_group(&"collar")
	NetworkEvents.on_peer_join.connect(func(peer: int):
		if multiplayer.is_server():
			_state.rpc_id(peer, _pack()))


## The derelict alongside, on this peer (or none): it's posed where the stage says at once.
func attach(alongside: Derelict) -> void:
	derelict = alongside
	_heard_stage = &""
	_show()


## Host: a new derelict's alongside (or none), waiting out where it is, or `docked` already (dev:
## --derelict).
func reset(docked: bool) -> void:
	if not multiplayer.is_server():
		return
	stage = &"docked" if docked else &"away"
	left = 0.0
	vented = false
	_broadcast()


## Host: the station's leaving (a jump): the collar seals itself and lets go at once, the airlock
## cycling in, whatever's docked left behind.
func cast_off() -> void:
	if not multiplayer.is_server() or stage == &"away" or stage == &"depart":
		return
	airlock.force_in()
	_release()


# --- Reading the collar ----------------------------------------------------------------------

## Seconds into the stage.
func elapsed() -> float:
	return _length(stage) - left


static func _length(of: StringName) -> float:
	match of:
		&"approach", &"depart":
			return DRIFT + EXTEND
		&"clamp":
			return CLAMP
		&"countdown":
			return COUNTDOWN
	return 0.0


## Whether the tube's run out and sealed to the derelict's hull.
func sealed() -> bool:
	return stage == &"clamp" or stage == &"docked" or stage == &"countdown"


## Whether the derelict's hatch stands open (the collar opened it; cast off, it's left open).
func derelict_hatch_open() -> bool:
	return stage == &"docked" or stage == &"countdown" or (stage == &"clamp" and elapsed() >= HATCH_AT) or vented


## The pressure in the tube, beyond the airlock's outer hatch: whatever the derelict's entry holds
## once its hatch is open, vacuum otherwise.
func outside_pressure() -> float:
	if derelict == null or not sealed() or not derelict_hatch_open():
		return 0.0
	return 1.0 if derelict.entry_air() else 0.0


## How far the tube's run out, 0..1.
func extension() -> float:
	match stage:
		&"approach":
			return clampf((elapsed() - DRIFT) / EXTEND, 0.0, 1.0)
		&"clamp", &"docked", &"countdown":
			return 1.0
		&"depart":
			return clampf(1.0 - elapsed() / EXTEND, 0.0, 1.0)
	return 0.0


## How hard the deck jolts now, 0..1 (the hulls meeting).
func shake() -> float:
	var since := Time.get_ticks_msec() / 1000.0 - _contact_at
	return CONTACT_SHAKE * exp(-since * 3.0) if since < 1.5 else 0.0


## Whether a world point's in the tube, run out.
func in_tube(point: Vector3) -> bool:
	if extension() < 1.0:
		return false
	var local := _tube.global_transform.affine_inverse() * point
	return absf(local.x) < 1.1 and local.y > -0.5 and local.y < 2.6 and local.z > 0.0 and local.z < LENGTH


## What the COLLAR lever does now, or why it won't.
func lever_prompt() -> String:
	var run := Run.of(self)
	if run != null and run.jumping():
		return "JUMPING"
	match stage:
		&"away":
			return "DOCK" if derelict != null else "NO TARGET"
		&"approach", &"clamp":
			return "DOCKING"
		&"docked":
			return "UNDOCK"
		&"countdown":
			return "ABORT"
	return "UNDOCKING"


# --- The lever (reported to the host) --------------------------------------------------------

## Host: the lever's been held: dock, undock, or abort the countdown.
func _lever_used() -> void:
	if not multiplayer.is_server():
		return
	match lever_prompt():
		"DOCK":
			_go(&"approach")
		"UNDOCK":
			airlock.force_in()
			_go(&"countdown")
		"ABORT":
			_go(&"docked")


func _release() -> void:
	vented = vented or derelict_hatch_open()
	_go(&"depart")


func _go(to: StringName) -> void:
	stage = to
	left = _length(to)
	_broadcast()


func _process(delta: float) -> void:
	left = maxf(0.0, left - delta)
	if multiplayer.is_server() and left <= 0.0:
		match stage:
			&"approach":
				_go(&"clamp")
			&"clamp":
				_go(&"docked")
			&"countdown":
				_release()
			&"depart":
				_go(&"away")
	_show()
	_cues()


# --- Showing it -------------------------------------------------------------------------------

func _show() -> void:
	var out := extension()
	if _tube != null:
		_tube.visible = out > 0.0
		_tube.scale = Vector3(1, 1, lerpf(STOWED, 1.0, out))
		for body in _tube_bodies:
			body.disabled = out < 1.0
		_tube_zone.disabled = out < 1.0
		_tube_light.visible = out >= 1.0
		_zone.pressurized = outside_pressure() > 0.5
	if derelict != null:
		derelict.pose_to(_pose())
		if vented and not derelict.vented:
			derelict.vent()
		if derelict.entry != null:
			derelict.entry.open = derelict_hatch_open()
	_show_beam()
	_show_panel()


## How strong the tractor beam is now, 0..1, and which way it pulls (+1 in, -1 off): on while the
## derelict drifts, easing up and down at either end.
func beam() -> Vector2:
	var t := elapsed()
	match stage:
		&"approach":
			return Vector2(smoothstep(0.0, 1.5, t) * (1.0 - smoothstep(DRIFT - 2.0, DRIFT, t)), 1.0)
		&"depart":
			var u := t - EXTEND
			return Vector2(smoothstep(0.0, 1.5, u) * (1.0 - smoothstep(DRIFT - 3.0, DRIFT, u)), -1.0)
	return Vector2.ZERO


## The beam from the collar to the derelict's hatch, and its light on the derelict's hull.
func _show_beam() -> void:
	var now := beam()
	var on := now.x > 0.0 and derelict != null and derelict.entry != null
	_beam.visible = on
	_beam_light.visible = on
	if not on:
		return
	var from := _beam.global_position
	var to := derelict.entry.centre()
	if from.distance_to(to) < 0.5:
		return
	_beam.look_at(to, Vector3.UP)
	_beam_light.look_at(to, Vector3.UP)
	var flicker := 0.92 + 0.08 * sin(Time.get_ticks_msec() / 1000.0 * 31.0)
	_beam.set_instance_shader_parameter(&"reach", from.distance_to(to))
	_beam.set_instance_shader_parameter(&"power", now.x * flicker)
	_beam.set_instance_shader_parameter(&"flow", now.y)
	_beam_light.light_energy = BEAM_LIGHT * now.x * flicker
	_beam_light.spot_range = from.distance_to(to) + 8.0


## Where the derelict lies now (its root, in the LANTERN's space, which is the world's).
func _pose() -> Transform3D:
	var docked := _mouth * derelict.dock_point().affine_inverse()
	var lined_up := Transform3D(docked.basis, docked.origin + _mouth.basis.z * LINE_UP)
	var waiting := Transform3D(Basis(Vector3.UP, WAITING_YAW) * lined_up.basis, lined_up.origin + WAITING)
	var t := elapsed()
	match stage:
		&"approach":
			var u := clampf(t / DRIFT, 0.0, 1.0)
			if u < 0.7:
				return waiting.interpolate_with(lined_up, smoothstep(0.0, 1.0, u / 0.7))
			var v := (u - 0.7) / 0.3
			return lined_up.interpolate_with(docked, 1.0 - (1.0 - v) * (1.0 - v))
		&"depart":
			var u := clampf((t - EXTEND) / DRIFT, 0.0, 1.0)
			if u < 0.3:
				var v := u / 0.3
				return docked.interpolate_with(lined_up, v * v)
			return lined_up.interpolate_with(waiting, smoothstep(0.0, 1.0, (u - 0.3) / 0.7))
		&"away":
			return waiting
	return docked


## The dock panel: the lever where the collar stands (or partway, held), the EXT PRESS needle, the
## CONTACT and SEAL lamps, the beacons.
func _show_panel() -> void:
	var player := get_tree().get_first_node_in_group(&"local_player") as Player
	var down := 1.0 if stage in [&"approach", &"clamp", &"docked"] else 0.0
	var held := player.hold_progress(_lever_switch) if player != null and _lever_switch != null else 0.0
	var target := lerpf(down, 1.0 - down, held * 0.6)
	_thrown = move_toward(_thrown, target, get_process_delta_time() * 2.5)
	if _lever != null:
		_lever.rotation.x = PI * _thrown
	if _needle != null:
		_needle.rotation.z = lerp_angle(_needle.rotation.z, (0.5 - outside_pressure()) * deg_to_rad(270.0), 0.05)
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 0.8) < 0.45
	_lamp(_lamp_contact, LAMP_GREEN if sealed() else (LAMP_AMBER if stage == &"approach" and blink else null))
	var seal: Material = null
	match stage:
		&"clamp":
			seal = LAMP_AMBER
		&"docked":
			seal = LAMP_GREEN
		&"countdown":
			seal = LAMP_RED if blink else null
	_lamp(_lamp_seal, seal)
	for beacon in _beacons:
		beacon.alarm = stage == &"countdown"


func _lamp(lamp: MeshInstance3D, material: Material) -> void:
	if lamp != null:
		lamp.visible = material != null
		lamp.material_override = material


## What everyone hears as it happens (not what happened before they joined): the tube's motor
## running out and in, the hulls meeting and the clamps, the siren through the countdown.
func _cues() -> void:
	var t := elapsed()
	if _heard_stage != &"":
		if stage == &"approach" and _heard_elapsed < DRIFT and t >= DRIFT:
			Sound.collar(&"motor", _tube, LENGTH / 2)
		if stage != _heard_stage:
			match stage:
				&"clamp":
					Sound.collar(&"contact", _tube, LENGTH)
					Sound.collar(&"clamps", _tube, LENGTH)
					_contact_at = Time.get_ticks_msec() / 1000.0
				&"depart":
					Sound.collar(&"motor", _tube, LENGTH / 2)
	if stage == &"depart" and _heard_stage != &"depart":
		_leave_tube()
	_heard_stage = stage
	_heard_elapsed = t
	if _siren != null:
		var sounding := stage == &"countdown"
		if sounding and not _siren.playing:
			_siren.play()
		elif not sounding and _siren.playing:
			_siren.stop()


## The tube's letting go: the crew member at this machine, if they're still in it, steps out of
## it to the nearer end (the station's, or the derelict's).
func _leave_tube() -> void:
	var player := get_tree().get_first_node_in_group(&"local_player") as Player
	if player == null or _tube == null:
		return
	var local := _tube.global_transform.affine_inverse() * player.global_position
	if absf(local.x) < 1.1 and local.z > 0.0 and local.z < LENGTH:
		var end := -0.9 if local.z < LENGTH / 2 else LENGTH + 0.9
		player.teleport(_tube.global_transform * Vector3(0, 0, end))


# --- Fitting it -------------------------------------------------------------------------------

## The tube, stowed at the hatch (it runs out along the piece's +Z), its walkway and walls solid
## only once it's run out; its air, its light.
func _fit_tube(lantern: Deck, at: Transform3D) -> void:
	_tube = TUBE.instantiate()
	_tube.name = "CollarTube"
	_tube.transform = at
	lantern.add_child(_tube)
	Deck._mark_interior(_tube)
	for shape: CollisionShape3D in _tube.find_children("*", "CollisionShape3D", true, false):
		_tube_bodies.append(shape)
	_zone = Zone.make(at * Vector3(0, Deck.ROOM_HEIGHT / 2, LENGTH / 2), Vector3(2.4, Deck.ROOM_HEIGHT, LENGTH), false)
	_zone.name = "Zone_collar_tube"
	_zone.basis = at.basis
	lantern.add_child(_zone)
	_tube_zone = _zone.get_child(0) as CollisionShape3D
	_tube_light = OmniLight3D.new()
	_tube_light.name = "TubeLight"
	_tube_light.light_color = Color(1.0, 0.8, 0.55)
	_tube_light.light_energy = 0.9
	_tube_light.omni_range = 4.0
	_tube_light.light_cull_mask = ~Deck.HULL_LAYER
	_tube_light.position = Vector3(0, 2.3, LENGTH / 2)
	_tube.add_child(_tube_light)
	_siren = AudioStreamPlayer3D.new()
	_siren.name = "Siren"
	_siren.stream = SIREN
	_siren.bus = &"World"
	_siren.unit_size = 6.0
	_siren.max_distance = 40.0
	_siren.volume_db = -4.0
	_siren.position = Vector3(0, 2.4, -2.0) # over the collar's airlock
	_tube.add_child(_siren)


## The tractor beam: a cone from the collar's mouth (it turns to follow the derelict), and a light
## along it that falls on hulls alone.
func _fit_beam(lantern: Deck, at: Transform3D) -> void:
	var material := ShaderMaterial.new()
	material.shader = BEAM_SHADER
	material.set_shader_parameter("colour", BEAM_COLOUR)
	_beam = MeshInstance3D.new()
	_beam.name = "TractorBeam"
	_beam.mesh = LampBeam._tube(24)
	_beam.material_override = material
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.custom_aabb = AABB(Vector3(-12, -12, -120), Vector3(24, 24, 121))
	_beam.position = at * BEAM_FROM
	_beam.visible = false
	lantern.add_child(_beam)
	_beam_light = SpotLight3D.new()
	_beam_light.name = "TractorLight"
	_beam_light.light_color = BEAM_COLOUR
	_beam_light.spot_angle = 6.0
	_beam_light.spot_attenuation = 0.4
	_beam_light.light_cull_mask = Deck.HULL_LAYER
	_beam_light.position = _beam.position
	_beam_light.visible = false
	lantern.add_child(_beam_light)


## The dock panel's lever on its pivot, the switch to hold, the needle, the lamps; the beacons over
## the docking port and the collar.
func _fit_panel(panel: Node3D) -> void:
	_lever = Airlock._pivot(panel, "dock_lever", LEVER_PIVOT)
	_needle = Airlock._pivot(panel, "dock_needle", DIAL)
	_lamp_contact = panel.find_child("lamp_contact", true, false) as MeshInstance3D
	_lamp_seal = panel.find_child("lamp_seal", true, false) as MeshInstance3D
	_lever_switch = DockLever.new()
	_lever_switch.name = "CollarLever"
	_lever_switch.collar = self
	_lever_switch.hold = LEVER_HOLD
	_lever_switch.housing = panel
	_lever_switch.position = LEVER_GRIP
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = LEVER_SIZE
	shape.shape = box
	_lever_switch.add_child(shape)
	panel.add_child(_lever_switch)
	_lever_switch.used.connect(func(_peer: int): _lever_used())
	for beacon in get_parent().get_children():
		if beacon is Beacon and beacon.position.x > 0.0:
			_beacons.append(beacon)


## The COLLAR lever, held: what it'll do (or why not) on the visor.
class DockLever extends Interactable:
	var collar: Collar

	func prompt(_player: Player) -> String:
		return collar.lever_prompt()

	func usable_by(_player: Player) -> bool:
		return enabled and collar.lever_prompt() in ["DOCK", "UNDOCK", "ABORT"]


## Why the airlock won't cycle out to the tube now, or "".
func _lock_blocker() -> String:
	var run := Run.of(self)
	if run != null and run.jumping():
		return "JUMPING"
	if stage == &"countdown" or stage == &"depart":
		return "UNDOCKING"
	if stage != &"docked":
		return "NO SEAL"
	return ""


# --- Keeping peers in step --------------------------------------------------------------------

func _broadcast() -> void:
	_state.rpc(_pack())


func _pack() -> Dictionary:
	return {"stage": stage, "left": left, "vented": vented}


@rpc("authority", "call_remote", "reliable")
func _state(data: Dictionary) -> void:
	stage = data.stage
	left = data.left
	vented = data.vented
