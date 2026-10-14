class_name Airlock
extends Node
## An airlock (GDD §5, §8.1, §11): a chamber between an inner door to the station and an outer
## hatch, never both open. Cycling out, the inner door shuts and the chamber goes to whatever
## pressure lies beyond the hatch (venting, or filling from it), then the hatch swings open;
## cycling in, the hatch shuts, the chamber fills, the inner door opens. In between, with the lock
## in, the inner door opens and shuts like any other. The cycle lever in the chamber cycles it
## either way; a locked door's own controls (the inner door's panels, the hatch's handles) call it
## round to open that door. It won't cycle out while `outside_blocker` says why not (the docking
## collar: NO SEAL, with nothing sealed to it).
##
## The host owns its state and sends it to everyone on each change (and to each crew member who
## joins); the cycle's timer runs down on every peer and the host finishes it. Everyone works out
## the chamber's pressure, the doors and the readouts from it.

## Seconds a cycle takes: the door behind shutting first, then the pressure changing.
const CYCLE := 5.5
const SHUT := 1.3
## Seconds the cycle lever is held to pull it.
const LEVER_HOLD := 0.8
## The cycle panel's split-off parts (art/blender/rooms.py: cycle_panel), in its own space: the
## dial's centre (the needle turns about the face's normal, mid-scale pointing up, 270° of travel)
## and the lever's pivot (pulled down toward the operator).
const DIAL := Vector3(-0.12, 1.28, 0.015)
const LEVER_PIVOT := Vector3(0.0, 0.96, 0.05)
const LEVER_PULLED := deg_to_rad(65.0)
const LEVER_GRIP := Vector3(0.0, 1.06, 0.1)
const LEVER_SIZE := Vector3(0.3, 0.26, 0.2)

var inner: Door
var outer: Hatch
var chamber: Zone
## The pressure beyond the outer hatch now, 0..1 atmospheres.
var outside_pressure := func() -> float: return 0.0
## Why it can't cycle out now, or "".
var outside_blocker := func() -> String: return ""

## &"in" (the outer hatch shut, the inner door free), &"to_out", &"out" (the outer hatch open, the
## inner door locked shut), &"to_in"; the seconds left on a cycle under way, and the chamber's
## pressure as it began.
var state := &"in"
var left := 0.0
var from_pressure := 1.0

var _needle: Node3D
var _lever: Node3D
var _lever_switch: Switch
var _pull := 0.0
var _heard := &"" # the state last heard begin, so each cycle sounds once on every peer


## An airlock between `inner` and `outer` round `chamber`, run from `panel` (an rm_cycle_panel
## inside it): added to `parent`.
static func make(parent: Node, inner_door: Door, outer_hatch: Hatch, chamber_zone: Zone, panel: Node3D) -> Airlock:
	var airlock := Airlock.new()
	airlock.name = "Airlock"
	airlock.inner = inner_door
	airlock.outer = outer_hatch
	airlock.chamber = chamber_zone
	parent.add_child(airlock)
	airlock._fit_panel(panel)
	airlock._fit_controls()
	return airlock


func _ready() -> void:
	NetworkEvents.on_peer_join.connect(func(peer: int):
		if multiplayer.is_server():
			_state.rpc_id(peer, _pack()))


func _process(delta: float) -> void:
	left = maxf(0.0, left - delta)
	if multiplayer.is_server():
		if cycling() and left <= 0.0:
			state = &"out" if state == &"to_out" else &"in"
			if state == &"in" and inner != null:
				inner.open = true # through you go
			_broadcast()
		if state != &"in" and inner != null:
			inner.open = false
	if outer != null:
		outer.open = state == &"out"
	var now := pressure()
	if chamber != null:
		chamber.pressurized = now > 0.5
	if cycling() and _heard != state:
		_heard = state
		var to := _target()
		if absf(to - from_pressure) > 0.25 and chamber != null:
			Sound.airlock(chamber, to > from_pressure)
	elif not cycling():
		_heard = &""
	if _needle != null:
		_needle.rotation.z = (0.5 - now) * deg_to_rad(270.0)
	var player := get_tree().get_first_node_in_group(&"local_player") as Player
	var held := player.hold_progress(_lever_switch) if player != null and _lever_switch != null else 0.0
	_pull = move_toward(_pull, maxf(held, 1.0 if cycling() else 0.0), delta * 3.0)
	if _lever != null:
		_lever.rotation.x = LEVER_PULLED * _pull


func cycling() -> bool:
	return state == &"to_out" or state == &"to_in"


## The chamber's pressure now, 0..1 atmospheres.
func pressure() -> float:
	match state:
		&"in":
			return 1.0
		&"out":
			return outside_pressure.call()
	var done := clampf((CYCLE - left - SHUT) / (CYCLE - SHUT), 0.0, 1.0)
	return lerpf(from_pressure, _target(), smoothstep(0.0, 1.0, done))


## Where a cycle under way is taking the chamber's pressure.
func _target() -> float:
	return 1.0 if state == &"to_in" else outside_pressure.call()


## What a switch shows: `toward` &"in" for the inner door's (with the lock in, the door's own OPEN
## or CLOSE; otherwise calling the lock in), &"out" for the hatch's (calling it out), &"" for the
## lever (either way). "" hides it: the hatch already stands open.
func prompt(toward: StringName) -> String:
	if cycling():
		return "CYCLING"
	if toward == &"in" and state == &"in":
		return "CLOSE" if inner.open else "OPEN"
	if toward == &"out" and state == &"out":
		return ""
	if state == &"in":
		var blocker: String = outside_blocker.call()
		if blocker != "":
			return blocker
	return "CYCLE"


## Host: a switch toward `toward` (see prompt) was used: the inner door opened or shut, or the lock
## cycled, if it can.
func use(toward: StringName = &"") -> void:
	if not multiplayer.is_server():
		return
	match prompt(toward):
		"OPEN", "CLOSE":
			inner.open = not inner.open
		"CYCLE":
			_begin(&"to_out" if state == &"in" else &"to_in")


## Host: brings it in, whatever it's doing (the collar's letting go): the outer hatch shuts.
func force_in() -> void:
	if multiplayer.is_server() and (state == &"out" or state == &"to_out"):
		_begin(&"to_in")


func _begin(to: StringName) -> void:
	from_pressure = pressure()
	state = to
	if to == &"to_out" and inner != null:
		inner.open = false
	left = CYCLE
	_broadcast()


# --- The panel and the controls ---------------------------------------------------------------

## The cycle panel's needle and lever, on pivots, and the lever to pull.
func _fit_panel(panel: Node3D) -> void:
	if panel == null:
		return
	_needle = _pivot(panel, "cycle_needle", DIAL)
	_lever = _pivot(panel, "cycle_lever", LEVER_PIVOT)
	_lever_switch = _switch(panel, &"", Transform3D(Basis(), LEVER_GRIP), LEVER_SIZE)
	_lever_switch.hold = LEVER_HOLD
	_lever_switch.housing = panel


## The inner door's panels give way to the lock's switches; the outer hatch gets one on each face.
func _fit_controls() -> void:
	if inner != null:
		inner.managed = true
		for panel in inner.panels:
			var box := (panel.get_node("Shape") as CollisionShape3D).shape as BoxShape3D
			_switch(inner, &"in", panel.transform, box.size)
	if outer != null:
		for face in [-1.0, 1.0]:
			_switch(outer, &"out", Transform3D(Basis(), Vector3(0, Hatch.CENTRE, face * 0.22)), Vector3(1.6, 1.6, 0.1))


func _switch(parent: Node3D, toward: StringName, where: Transform3D, size: Vector3) -> Switch:
	var switch := Switch.new()
	switch.name = "Cycle" + ("Lever" if toward == &"" else toward.capitalize())
	switch.airlock = self
	switch.toward = toward
	switch.transform = where
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	switch.add_child(shape)
	parent.add_child(switch)
	switch.used.connect(func(_peer: int): use(toward))
	return switch


## Puts `model`'s mesh `part` on a pivot at `at` (model space), to turn.
static func _pivot(model: Node3D, part: String, at: Vector3) -> Node3D:
	var mesh := model.find_child(part, true, false) as Node3D
	if mesh == null:
		push_warning("Airlock: no %s on %s." % [part, model.name])
		return null
	var pivot := Node3D.new()
	pivot.name = part.capitalize().replace(" ", "") + "Pivot"
	model.add_child(pivot)
	pivot.position = at
	var where := mesh.global_transform
	mesh.get_parent().remove_child(mesh)
	pivot.add_child(mesh)
	mesh.global_transform = where
	return pivot


## What crew use: the lever, the inner door's panels, the hatch's handles.
class Switch extends Interactable:
	var airlock: Airlock
	var toward := &""

	func prompt(_player: Player) -> String:
		return airlock.prompt(toward)

	func usable_by(_player: Player) -> bool:
		return enabled and airlock.prompt(toward) in ["CYCLE", "OPEN", "CLOSE"]

	func _process(_delta: float) -> void:
		enabled = airlock.prompt(toward) != ""


# --- Keeping peers in step --------------------------------------------------------------------

func _broadcast() -> void:
	_state.rpc(_pack())


func _pack() -> Dictionary:
	return {"state": state, "left": left, "from": from_pressure}


@rpc("authority", "call_remote", "reliable")
func _state(data: Dictionary) -> void:
	state = data.state
	left = data.left
	from_pressure = data.from
