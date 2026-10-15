class_name SuitPanel
extends CanvasLayer
## The suit panel (GDD §10): Tab opens it across the visor, Tab or Esc closes it. The world goes on
## behind it: crew can still walk with it open, but not look round, use or take anything. Drawn on
## the visor's pixel grid (as the HUD is) in the suit's phosphor, with its own cursor.
##   GEAR  the suit itself, turning slowly (a live render: what's worn, what's in hand); its
##         equipment (the helmet lamp, switched here too; the EVA harness; the communicator; what's
##         carried in both hands); the belt's four slots, to draw from (click), reorder (drag one
##         onto another), set down (drag it off the panel, or RMB); and the slot in hand's details:
##         what it is, its state, DRAW, USE and DROP.
##   SUIT  vitals (the heart's trace, health, O2 and what it's using, the suit's integrity, the
##         lamp's battery, the harness's propellant, the dose rate) and the rest of the crew as the
##         suits' link carries them: how they are, their O2, where they are.
##   LOGS  what's been read from data cores (Lore), newest first; pick one to read it.
## Two-handed things aren't the belt's: they're only shown (and set down) under HANDS.

const COLOUR := Color(0.72, 0.95, 0.78)
const DIM := Color(0.3, 0.48, 0.36)
const AMBER := Color(1.0, 0.74, 0.3)
const RED := Color(1.0, 0.32, 0.22)
const DARK := Color(0.02, 0.05, 0.03)
const FONT := preload("res://assets/fonts/VT323-Regular.ttf")
const FONT_SIZE := 16
const SUIT := preload("res://assets/models/characters/ch_suit.glb")
## The panel on the visor's 480 x 270 grid, its tab strip and its body.
const GRID := Vector2i(480, 270)
const FRAME := Rect2(36, 18, 408, 234)
const BODY_TOP := 42.0
const TABS: Array[StringName] = [&"gear", &"suit", &"logs"]
## Seconds it takes to unfold across the visor, and to fold away.
const UNFOLD := 0.16
const FOLD := 0.1
## The suit's render: its size, where it stands.
const DOLL := Rect2(44, 46, 88, 148)
## The equipment rows, the belt's slots and the details pane (GEAR).
const EQUIPMENT_X := 140.0
const EQUIPMENT_ROW := 33.0
const BELT_AT := Vector2(140, 182)
const SLOT := 36.0
const SLOT_GAP := 3.0
const DETAILS := Rect2(300, 46, 136, 196)
## Pixels the mouse must move with a slot held before it's a drag, not a click.
const DRAG := 3.0
## Lines of a log shown at once.
const LOG_LINES := 9

var player: Player
var is_open := false
var tab := &"gear"

var _unfold := 0.0
var _time := 0.0
var _mouse := Vector2(-100, -100)
## Where clicks land: [Rect2, what] from the last draw.
var _hits: Array = []
## A belt slot pressed (its index, -1 for none), where, and whether it's become a drag.
var _pressed := -1
var _press_at := Vector2.ZERO
var _dragging := false
var _log := 0
var _log_scroll := 0
var _unread := 0
var _trace := PackedFloat32Array()
var _icons := {}
var _turn := 0.0 # the suit render's yaw, turning slowly

var _container: SubViewportContainer
var _canvas: Control
var _doll_view: SubViewport
var _doll: Node3D
var _doll_animation: CrewAnimation
var _doll_held: Node3D
var _doll_kind := &"-"
var _doll_harness: Node3D
var _doll_lens: ShaderMaterial
var _doll_spine: ShaderMaterial


func _ready() -> void:
	layer = 11
	_container = SubViewportContainer.new()
	_container.name = "Screen"
	_container.stretch = true
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.stretch_shrink = Psx.block
	add_child(_container)
	get_window().size_changed.connect(func(): _container.stretch_shrink = Psx.block)
	var viewport := SubViewport.new()
	viewport.name = "Viewport"
	viewport.transparent_bg = true
	viewport.size = GRID
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_container.add_child(viewport)
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_panel)
	_canvas.gui_input.connect(_input_on_panel)
	viewport.add_child(_canvas)
	_make_doll()
	player.logs_changed.connect(func(): _unread += 1)
	visible = false


## Opens it, or closes it.
func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open or player.dead or player.operating != null or player.seized:
		return
	is_open = true
	visible = true
	_container.mouse_filter = Control.MOUSE_FILTER_STOP
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_doll_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_pressed = -1
	_dragging = false
	if tab == &"logs":
		_unread = 0
	Sound.ui(&"open")


func close() -> void:
	if not is_open:
		return
	is_open = false
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if player.operating == null and not player.dead:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_pressed = -1
	_dragging = false
	Sound.ui(&"close")


func _process(delta: float) -> void:
	_time += delta
	if is_open and (player.dead or player.operating != null or player.seized):
		close()
	_unfold = move_toward(_unfold, 1.0 if is_open else 0.0, delta / (UNFOLD if is_open else FOLD))
	visible = _unfold > 0.0
	if not visible:
		_doll_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_follow_trace()
	_pose_doll(delta)
	_canvas.queue_redraw()


# --- Input -------------------------------------------------------------------------------------

func _input_on_panel(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseMotion:
		_mouse = event.position
		if _pressed >= 0 and not _dragging and _mouse.distance_to(_press_at) > DRAG:
			_dragging = true
	elif event is InputEventMouseButton:
		_mouse = event.position
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			_press(_hit(_mouse))
		elif not button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			_release(_hit(_mouse))
		elif button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
			var under: Variant = _hit(_mouse)
			if under is int:
				_drop(under)
		elif button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and tab == &"logs":
			_log_scroll = maxi(0, _log_scroll + (1 if button.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1))
	_canvas.accept_event()


## What's under `at`: a belt slot (its index), or a control's name (a StringName), or null.
func _hit(at: Vector2) -> Variant:
	for hit in _hits:
		if (hit[0] as Rect2).has_point(at):
			return hit[1]
	return null


func _press(what: Variant) -> void:
	if what is int:
		_pressed = what
		_press_at = _mouse
		_dragging = false
		return
	if what == null:
		return
	var name := String(what)
	if name.begins_with("tab_"):
		var next := StringName(name.trim_prefix("tab_"))
		if next != tab:
			tab = next
			Sound.ui(&"tick")
			if tab == &"logs":
				_unread = 0
	elif name.begins_with("log_"):
		_log = int(name.trim_prefix("log_"))
		_log_scroll = 0
		Sound.ui(&"tick")
	elif name == "lamp":
		player.switch_lamp()
		Sound.ui(&"tick")
	elif name == "use":
		player.use_slot(player.slot)
		Sound.ui(&"tick")
	elif name == "drop":
		_drop(player.slot)
	elif name == "drop_carry":
		player.let_go(0.0)
		Sound.ui(&"move")
	elif name == "close":
		close()


## A slot let go of over `what`: a click on it draws it; a drag onto another slot swaps them; a
## drag off the panel sets it down.
func _release(what: Variant) -> void:
	if _pressed < 0:
		return
	var from := _pressed
	_pressed = -1
	if not _dragging:
		if not player.carrying.is_empty():
			Sound.ui(&"deny")
			return
		player.select_slot(from)
		Sound.ui(&"tick")
		return
	_dragging = false
	if what is int and what != from:
		if player.carrying.is_empty():
			player.swap_slots(from, what)
			Sound.ui(&"move")
		else:
			Sound.ui(&"deny")
	elif not FRAME.has_point(_mouse):
		_drop(from)


func _drop(index: int) -> void:
	if not player.carrying.is_empty() or player.belt[index].is_empty():
		Sound.ui(&"deny")
		return
	player.drop_slot(index)
	Sound.ui(&"move")


# --- Drawing -----------------------------------------------------------------------------------

func _draw_panel() -> void:
	_hits.clear()
	if _unfold <= 0.0:
		return
	# Unfolding: the frame opens from a bright line across the middle of the visor.
	var t := _unfold
	var frame := FRAME
	if t < 1.0:
		var height := maxf(2.0, FRAME.size.y * ease(t, 0.4))
		frame = Rect2(FRAME.position.x, FRAME.get_center().y - height / 2.0, FRAME.size.x, height)
		_canvas.draw_rect(frame, Color(DARK, 0.85 * t))
		_canvas.draw_rect(frame.grow(-0.5), Color(COLOUR, t), false, 1.0)
		return
	_canvas.draw_rect(frame, Color(DARK, 0.9))
	# Scanlines across the projection, and a slow bright band rolling down it.
	for y in range(int(frame.position.y), int(frame.end.y), 2):
		_canvas.draw_line(Vector2(frame.position.x, y), Vector2(frame.end.x, y), Color(COLOUR, 0.025))
	var band := fmod(_time * 40.0, frame.size.y + 40.0) - 20.0
	_canvas.draw_rect(Rect2(frame.position.x, frame.position.y + band, frame.size.x, 6).intersection(frame), Color(COLOUR, 0.03))
	_brackets(frame)
	_draw_tabs()
	match tab:
		&"gear":
			_draw_gear()
		&"suit":
			_draw_vitals()
		&"logs":
			_draw_logs()
	_draw_footer()
	_draw_dragged()
	_draw_cursor()


## The frame's corners, bracketed like a sight's.
func _brackets(r: Rect2) -> void:
	var c := Color(COLOUR, 0.9)
	for corner in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		var sx := 1.0 if corner.x == r.position.x else -1.0
		var sy := 1.0 if corner.y == r.position.y else -1.0
		var at: Vector2 = corner + Vector2(0.5 * sx, 0.5 * sy)
		_canvas.draw_line(at, at + Vector2(10 * sx, 0), c, 1.0)
		_canvas.draw_line(at, at + Vector2(0, 10 * sy), c, 1.0)
	_canvas.draw_rect(r.grow(-0.5), Color(COLOUR, 0.25), false, 1.0)


func _draw_tabs() -> void:
	var x := FRAME.position.x + 8.0
	var y := FRAME.position.y + 5.0
	for each in TABS:
		var label := String(each).to_upper()
		var width := _text_width(label) + 12.0
		var rect := Rect2(x, y, width, 15)
		var current := each == tab
		var hover := rect.has_point(_mouse)
		if current:
			_canvas.draw_rect(rect, Color(COLOUR, 0.9))
		elif hover:
			_canvas.draw_rect(rect, Color(COLOUR, 0.15))
		_canvas.draw_rect(rect.grow(-0.5), Color(COLOUR, 0.6 if not current else 0.9), false, 1.0)
		_text(Vector2(x + 6, y + 12), label, DARK if current else COLOUR)
		if each == &"logs" and _unread > 0 and not current:
			_canvas.draw_rect(Rect2(rect.end.x - 4, rect.position.y + 2, 3, 3), AMBER if fmod(_time, 0.8) < 0.5 else Color(AMBER, 0.3))
		_hits.append([rect, StringName("tab_" + each)])
		x += width + 4.0
	var title := "%s  SURVEY SUIT" % player.crew_name()
	_text(Vector2(FRAME.end.x - 10 - _text_width(title), y + 12), title, DIM)
	_canvas.draw_line(Vector2(FRAME.position.x + 4, BODY_TOP - 3), Vector2(FRAME.end.x - 4, BODY_TOP - 3), Color(COLOUR, 0.3))


func _draw_footer() -> void:
	var hint := {&"gear": "CLICK DRAW  DRAG REORDER  DRAG OUT OR RMB DROP  TAB CLOSE",
			&"suit": "VITALS FROM THE SUIT  CREW FROM THE SUITS' LINK  TAB CLOSE",
			&"logs": "CLICK A LOG TO READ IT  WHEEL SCROLLS  TAB CLOSE"}[tab] as String
	Glyphs.draw(_canvas, hint, Vector2(FRAME.position.x + 8, FRAME.end.y - 9), Color(COLOUR, 0.45))


# --- GEAR --------------------------------------------------------------------------------------

func _draw_gear() -> void:
	_canvas.draw_rect(DOLL, Color(COLOUR, 0.04))
	_canvas.draw_texture(_doll_view.get_texture(), DOLL.position)
	_canvas.draw_rect(DOLL.grow(-0.5), Color(COLOUR, 0.2), false, 1.0)
	# A turntable ring under the suit's feet.
	var base := Vector2(DOLL.get_center().x, DOLL.end.y - 9)
	for i in 3:
		_canvas.draw_arc(base, 26.0 - i * 6, 0.0, TAU, 24, Color(COLOUR, 0.12 - i * 0.03), 1.0)
	_label(Vector2(DOLL.position.x, DOLL.end.y + 4), "HANDS")
	var hands := Rect2(DOLL.position.x, DOLL.end.y + 11, DOLL.size.x, 34)
	_draw_hands(hands)
	_label(Vector2(EQUIPMENT_X, BODY_TOP + 4), "EQUIPMENT")
	var y := BODY_TOP + 12.0
	_equipment(Vector2(EQUIPMENT_X, y), "lamp", "HELMET LAMP", _lamp_status(), player.battery,
			COLOUR if player.battery > Player.LAMP_LOW else AMBER, true)
	y += EQUIPMENT_ROW
	_equipment(Vector2(EQUIPMENT_X, y), "harness", "EVA HARNESS", "RCS %d%%" % ceili(player.rcs / Player.RCS_FUEL * 100.0) if player.harness else "NOT WORN",
			player.rcs / Player.RCS_FUEL if player.harness else -1.0, COLOUR, false)
	y += EQUIPMENT_ROW
	var talking := not Sound.talking().is_empty()
	_equipment(Vector2(EQUIPMENT_X, y), "comms", "COMMUNICATOR", "HOLD V TO TALK" if not talking else ("SENDING" if player.cuff_up else "RECEIVING"),
			-1.0, AMBER if player.cuff_up else COLOUR, false)
	_label(Vector2(BELT_AT.x, BELT_AT.y - 10), "BELT")
	for i in player.belt.size():
		_belt_slot(i)
	_draw_details()


func _lamp_status() -> String:
	if player.battery <= 0.0:
		return "FLAT"
	return "%s  %d%%" % ["ON" if player.lamp_on else "OFF", ceili(player.battery * 100.0)]


## An equipment row at `at`: its icon in a box, its name and state, a bar for `fraction` (none if
## negative); clickable (the lamp, to switch it) if `toggles`.
func _equipment(at: Vector2, icon: String, name: String, state: String, fraction: float, colour: Color, toggles: bool) -> void:
	var row := Rect2(at, Vector2(152, 29))
	var hover := toggles and row.has_point(_mouse)
	if hover:
		_canvas.draw_rect(row, Color(COLOUR, 0.08))
	var box := Rect2(at, Vector2(29, 29))
	_canvas.draw_rect(box, Color(DARK, 0.6))
	_canvas.draw_rect(box.grow(-0.5), Color(COLOUR, 0.5), false, 1.0)
	_draw_icon(icon, box.grow(-6), colour)
	_text(at + Vector2(35, 11), name, COLOUR)
	_text(at + Vector2(35, 24), state, colour if state != "NOT WORN" else DIM)
	if fraction >= 0.0:
		var bar := Rect2(at + Vector2(102, 17), Vector2(48, 5))
		_canvas.draw_rect(bar.grow(-0.5), Color(colour, 0.4), false, 1.0)
		_canvas.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * clampf(fraction, 0.0, 1.0)), bar.size.y)), Color(colour, 0.85))
	if toggles:
		_hits.append([row, &"lamp"])


## What's carried in both hands, with DROP; or that they're free.
func _draw_hands(r: Rect2) -> void:
	_canvas.draw_rect(r, Color(DARK, 0.6))
	_canvas.draw_rect(r.grow(-0.5), Color(COLOUR, 0.35), false, 1.0)
	if player.carrying.is_empty():
		Glyphs.draw(_canvas, "FREE", r.position + Vector2(6, 15), DIM)
		return
	var kind := Items.kind_of(player.carrying)
	var icon := _icon(kind)
	if icon != null:
		_canvas.draw_texture(icon, r.position + Vector2(4, 9), COLOUR)
	var name := Items.display_name(kind)
	if kind == &"body":
		name = String(player.carrying.get("crew", "BODY"))
	Glyphs.draw(_canvas, name, r.position + Vector2(24, 7), COLOUR)
	_button(Rect2(r.position.x + 24, r.position.y + 17, 40, 12), "DROP", &"drop_carry", true)


## Belt slot `i`: its number, its thing's icon, raised and bright if it's the one in hand.
func _belt_slot(i: int) -> void:
	var rect := Rect2(BELT_AT + Vector2(i * (SLOT + SLOT_GAP), 0), Vector2(SLOT, SLOT))
	var record := player.belt[i]
	var in_hand := i == player.slot and player.carrying.is_empty()
	var hover := rect.has_point(_mouse)
	var dragged := _dragging and _pressed == i
	if in_hand:
		rect.position.y -= 3
	_canvas.draw_rect(rect, Color(DARK, 0.7))
	if hover and not dragged:
		_canvas.draw_rect(rect, Color(COLOUR, 0.1))
	_canvas.draw_rect(rect.grow(-0.5), Color(COLOUR, 0.95 if in_hand else (0.6 if hover else 0.35)), false, 1.0)
	if in_hand:
		_canvas.draw_rect(Rect2(rect.position + Vector2(2, rect.size.y - 3), Vector2(rect.size.x - 4, 1)), COLOUR)
	if not record.is_empty() and not dragged:
		_draw_item(record, rect, 1.0 if in_hand else 0.65)
	# The slot's number on a dark tab in its corner, over whatever's in it.
	_canvas.draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(6, 7)), Color(DARK, 0.9))
	Glyphs.draw(_canvas, str(i + 1), rect.position + Vector2(2, 2), Color(COLOUR, 0.9 if in_hand else 0.5))
	_hits.append([rect, i])


## An item's icon in the middle of `rect`, twice its size; its charge, or its burn, along the slot's
## foot.
func _draw_item(record: Dictionary, rect: Rect2, alpha: float) -> void:
	var kind := Items.kind_of(record)
	var icon := _icon(kind)
	if icon != null:
		var size := Vector2(icon.get_size()) * 2.0
		_canvas.draw_texture_rect(icon, Rect2((rect.get_center() - size / 2.0).floor() + Vector2(1, 1), size), false, Color(COLOUR, alpha))
	var charges := Items.charges(kind)
	for c in charges:
		var lit := c < Items.charge(record)
		_canvas.draw_rect(Rect2(rect.end - Vector2(5 + c * 4, 6), Vector2(3, 3)), Color(AMBER if lit else DIM, alpha))
	if Items.burning(record):
		var left: float = record.burn / Player.FLARE_BURN
		_canvas.draw_rect(Rect2(rect.position + Vector2(3, rect.size.y - 6), Vector2((rect.size.x - 6) * left, 2)), Color(RED, alpha))


## The details of what's in the hand's slot (or hovered): name, what it is, its state, and what
## can be done with it.
func _draw_details() -> void:
	var r := DETAILS
	_canvas.draw_rect(r, Color(DARK, 0.5))
	_canvas.draw_rect(r.grow(-0.5), Color(COLOUR, 0.3), false, 1.0)
	# A slot under the cursor is the one described; otherwise what's carried, or the slot in hand.
	var under: Variant = _hit(_mouse)
	var index: int = under if under is int and not _dragging else player.slot
	var record := player.belt[index]
	if not player.carrying.is_empty() and not (under is int):
		record = player.carrying
	var kind := Items.kind_of(record)
	var at := r.position + Vector2(6, 2)
	if record.is_empty():
		_label(at + Vector2(0, 4), "SLOT %d" % (index + 1))
		_text(at + Vector2(0, 26), "EMPTY", DIM)
		_wrap(at + Vector2(0, 44), "Take things with E. Anything small goes on the belt: tools, supplies, salvage, data.", r.size.x - 12, DIM, 6)
		return
	_label(at + Vector2(0, 4), "SLOT %d" % (index + 1) if record != player.carrying else "HANDS")
	_text(at + Vector2(0, 24), Items.display_name(kind) if kind != &"body" else String(record.get("crew", "BODY")), COLOUR)
	var line := 38.0
	for fact in _facts(record):
		Glyphs.draw(_canvas, fact[0], at + Vector2(0, line), DIM)
		Glyphs.draw(_canvas, fact[1], at + Vector2(52, line), fact[2])
		line += 8.0
	_wrap(at + Vector2(0, line + 12), Items.description(kind), r.size.x - 12, Color(COLOUR, 0.8), 6)
	if record == player.carrying:
		_button(Rect2(r.position.x + 6, r.end.y - 18, 40, 13), "DROP", &"drop_carry", true)
		return
	var usable := Items.use_of(kind) != "" and Items.use_of(kind) != "swing"
	var x := r.position.x + 6
	var drawn := index == player.slot
	_button(Rect2(x, r.end.y - 18, 40, 13), "DRAWN" if drawn else "DRAW", &"", not drawn, index)
	_button(Rect2(x + 44, r.end.y - 18, 38, 13), _use_label(kind), &"use", usable and drawn)
	_button(Rect2(x + 86, r.end.y - 18, 40, 13), "DROP", &"drop", drawn)


func _use_label(kind: StringName) -> String:
	match Items.use_of(kind):
		"refill":
			return "FILL"
		"patch":
			return "SEAL"
		"read":
			return "READ"
		"strike":
			return "LIGHT"
	return "USE"


## What's worth knowing of a thing, as [label, value, colour] rows.
func _facts(record: Dictionary) -> Array:
	var kind := Items.kind_of(record)
	var out := [["MASS", "%.1f KG" % Items.mass(kind), COLOUR]]
	if Items.charges(kind) > 0:
		var charge := Items.charge(record)
		out.append(["CHARGE", "%d / %d" % [charge, Items.charges(kind)], COLOUR if charge > 0 else RED])
	if Items.burning(record):
		var left := ceili(record.burn)
		out.append(["BURNING", "%d:%02d" % [left / 60, left % 60], RED])
	elif kind == &"flare":
		out.append(["BURN", "1:00", COLOUR])
	if record.has("value"):
		out.append(["SCRAP", "%d" % int(record.value), AMBER])
	if kind == &"data_core":
		var read: bool = record.has("log") and player.logs.has(int(record.log))
		out.append(["LOG", "READ" if read else "UNREAD", COLOUR if read else AMBER])
	if Items.two_handed(kind):
		out.append(["CARRY", "BOTH HANDS", AMBER])
	return out


## A button: lit and clickable when `enabled` (its click is `action`, or slot `slot` to draw it).
func _button(rect: Rect2, label: String, action: StringName, enabled: bool, slot := -1) -> void:
	var hover := enabled and rect.has_point(_mouse)
	if hover:
		_canvas.draw_rect(rect, Color(COLOUR, 0.85))
	_canvas.draw_rect(rect.grow(-0.5), Color(COLOUR, 0.75 if enabled else 0.2), false, 1.0)
	var width := Glyphs.width(label)
	Glyphs.draw(_canvas, label, (rect.get_center() - Vector2(width, 5) / 2.0).floor(), DARK if hover else Color(COLOUR, 1.0 if enabled else 0.3))
	if enabled:
		_hits.push_front([rect, slot if slot >= 0 else action])


# --- SUIT --------------------------------------------------------------------------------------

func _draw_vitals() -> void:
	var left := Rect2(FRAME.position.x + 8, BODY_TOP + 4, 196, 196)
	_label(left.position, "VITALS")
	# The heart's trace: a spike each beat, scrolling; flat, dead.
	var ecg := Rect2(left.position + Vector2(0, 8), Vector2(left.size.x, 40))
	_canvas.draw_rect(ecg, Color(DARK, 0.6))
	_canvas.draw_rect(ecg.grow(-0.5), Color(COLOUR, 0.3), false, 1.0)
	var mid := ecg.get_center().y
	var colour := COLOUR if player.health > 0.3 else RED
	for i in range(1, _trace.size()):
		_canvas.draw_line(Vector2(ecg.position.x + 2 + (i - 1) * 2, mid + _trace[i - 1] * 15), Vector2(ecg.position.x + 2 + i * 2, mid + _trace[i] * 15), colour, 1.0)
	var bpm := player.heart_rate()
	_text(ecg.position + Vector2(ecg.size.x - 52, 13), "%3d BPM" % int(bpm), colour)
	var y := ecg.end.y + 8
	var o2 := player.o2 / Player.O2_CAPACITY
	var left_o2 := ceili(player.o2)
	var rows := [
		["HEALTH", player.health, "%d%%" % roundi(player.health * 100.0), COLOUR if player.health > 0.6 else (AMBER if player.health > 0.3 else RED)],
		["O2", o2, "%d:%02d" % [left_o2 / 60, left_o2 % 60], COLOUR if o2 > 0.25 else (AMBER if o2 > 0.1 else RED)],
		["SUIT", player.integrity, "BREACH" if player.breached else "%d%%" % roundi(player.integrity * 100.0), RED if player.breached else (COLOUR if player.integrity > 0.5 else AMBER)],
		["LAMP", player.battery, "%d%%" % ceili(player.battery * 100.0), COLOUR if player.battery > Player.LAMP_LOW else AMBER],
		["RCS", player.rcs / Player.RCS_FUEL if player.harness else 0.0, "%d%%" % ceili(player.rcs / Player.RCS_FUEL * 100.0) if player.harness else "--", COLOUR if player.harness else DIM],
		["RAD", player.radiation, "%.1f" % (player.radiation * 10.0) if player.radiation > 0.0 else "CLEAR", COLOUR if player.radiation < 0.25 else (AMBER if player.radiation < 0.6 else RED)],
	]
	for row in rows:
		_text(Vector2(left.position.x, y + 11), row[0], DIM)
		var bar := Rect2(left.position.x + 54, y + 4, 80, 6)
		for c in 16:
			var cell := Rect2(bar.position + Vector2(c * 5, 0), Vector2(4, bar.size.y))
			if row[1] > c / 16.0:
				_canvas.draw_rect(cell, Color(row[3], 0.85))
			else:
				_canvas.draw_rect(cell.grow(-0.5), Color(row[3], 0.25), false, 1.0)
		_text(Vector2(bar.end.x + 8, y + 11), row[2], row[3])
		y += 17
	var air := "BREATHING FROM SUIT  %.1fX" % player.o2_rate() if player.in_vacuum else "BREATHING AIR"
	Glyphs.draw(_canvas, air, Vector2(left.position.x, y + 4), AMBER if player.in_vacuum else DIM)
	Glyphs.draw(_canvas, "LOCATION  " + player.whereabouts(), Vector2(left.position.x, y + 14), DIM)
	# The rest of the crew.
	var right := Rect2(FRAME.position.x + 214, BODY_TOP + 4, 186, 196)
	_label(right.position, "CREW")
	var crew := player.get_tree().get_nodes_in_group(&"crew")
	crew.sort_custom(func(a, b): return int(str(a.name)) < int(str(b.name)))
	var cy := right.position.y + 10
	for mate: Player in crew:
		var tile := Rect2(right.position.x, cy, right.size.x, 34)
		_canvas.draw_rect(tile, Color(DARK, 0.5))
		_canvas.draw_rect(tile.grow(-0.5), Color(COLOUR, 0.6 if mate == player else 0.25), false, 1.0)
		var condition := mate.condition()
		var tint := COLOUR if condition == "OK" else (AMBER if condition == "HURT" else RED)
		_canvas.draw_rect(Rect2(tile.position + Vector2(4, 5), Vector2(4, 24)), Color(Player.spine_colour(mate.health if not mate.dead else 0.0), 0.9))
		_text(tile.position + Vector2(13, 12), mate.crew_name() + ("  (YOU)" if mate == player else ""), COLOUR)
		Glyphs.draw(_canvas, condition, tile.position + Vector2(13, 18), tint)
		if not mate.dead:
			Glyphs.draw(_canvas, "O2 %d%%" % roundi(mate.o2 / Player.O2_CAPACITY * 100.0), tile.position + Vector2(13, 26), DIM)
			Glyphs.draw(_canvas, mate.whereabouts(), tile.position + Vector2(70, 26), DIM)
		elif mate.cause != &"":
			Glyphs.draw(_canvas, Player.CAUSES.get(mate.cause, String(mate.cause).to_upper()), tile.position + Vector2(13, 26), Color(RED, 0.8))
		if mate.cuff_up and not mate.dead:
			Glyphs.draw(_canvas, "TX", tile.position + Vector2(tile.size.x - 14, 4), AMBER)
		cy += 38


## The heart's trace on the SUIT tab, one point a frame.
func _follow_trace() -> void:
	var bpm := player.heart_rate()
	var beat := fmod(_time * bpm / 60.0, 1.0)
	var spike := 0.0
	if bpm > 0.0:
		if beat < 0.04:
			spike = -1.0
		elif beat < 0.08:
			spike = 0.6
		elif beat > 0.3 and beat < 0.4:
			spike = -0.15
	_trace.append(spike + randf_range(-0.03, 0.03))
	if _trace.size() > 96:
		_trace.remove_at(0)


# --- LOGS --------------------------------------------------------------------------------------

func _draw_logs() -> void:
	var list := Rect2(FRAME.position.x + 8, BODY_TOP + 4, 138, 192)
	_label(list.position, "READ %d" % player.logs.size())
	if player.logs.is_empty():
		_wrap(list.position + Vector2(0, 26), "No logs. Data cores turn up in derelicts and relays: take one, then READ it from the belt.", 360,
				DIM, 6)
		return
	_log = clampi(_log, 0, player.logs.size() - 1)
	var y := list.position.y + 10
	for i in range(player.logs.size() - 1, maxi(-1, player.logs.size() - 13), -1):
		var row := Rect2(list.position.x, y, list.size.x, 13)
		var current := i == _log
		if current:
			_canvas.draw_rect(row, Color(COLOUR, 0.85))
		elif row.has_point(_mouse):
			_canvas.draw_rect(row, Color(COLOUR, 0.12))
		var title := Lore.title(player.logs[i])
		if Glyphs.width(title) > row.size.x - 6:
			while Glyphs.width(title + "..") > row.size.x - 6:
				title = title.left(-1)
			title += ".."
		Glyphs.draw(_canvas, title, row.position + Vector2(3, 4), DARK if current else COLOUR)
		_hits.append([row, StringName("log_%d" % i)])
		y += 14
	var page := Rect2(FRAME.position.x + 154, BODY_TOP + 4, 246, 192)
	_canvas.draw_rect(page, Color(DARK, 0.5))
	_canvas.draw_rect(page.grow(-0.5), Color(COLOUR, 0.3), false, 1.0)
	var entry: int = player.logs[_log]
	_text(page.position + Vector2(6, 14), Lore.title(entry), COLOUR)
	Glyphs.draw(_canvas, Lore.source(entry), page.position + Vector2(6, 20), AMBER)
	var lines := _wrapped(Lore.text(entry), page.size.x - 12)
	_log_scroll = clampi(_log_scroll, 0, maxi(0, lines.size() - LOG_LINES))
	for i in range(_log_scroll, mini(lines.size(), _log_scroll + LOG_LINES)):
		_text(page.position + Vector2(6, 42 + (i - _log_scroll) * 15), lines[i], Color(COLOUR, 0.9))
	if lines.size() > LOG_LINES:
		Glyphs.draw(_canvas, "MORE", page.end - Vector2(22, 9), DIM)


# --- The suit render ---------------------------------------------------------------------------

## The suit on its turntable: a ch_suit in a world of its own, lit warm from the front and with a
## phosphor rim from behind, rendered at the panel's own few pixels.
func _make_doll() -> void:
	_doll_view = SubViewport.new()
	_doll_view.name = "Doll"
	_doll_view.size = Vector2i(DOLL.size)
	_doll_view.own_world_3d = true
	_doll_view.transparent_bg = true
	_doll_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_doll_view)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.32, 0.4, 0.36)
	environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
	_doll_view.add_child(world)
	var camera := Camera3D.new()
	camera.fov = 26.0
	camera.position = Vector3(0, 1.0, 4.5)
	camera.look_at_from_position(camera.position, Vector3(0, 0.93, 0))
	_doll_view.add_child(camera)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.86, 0.7)
	key.light_energy = 1.3
	key.rotation = Vector3(deg_to_rad(-25), deg_to_rad(30), 0)
	_doll_view.add_child(key)
	var rim := OmniLight3D.new()
	rim.light_color = Color(0.45, 1.0, 0.6)
	rim.light_energy = 2.5
	rim.omni_range = 5.0
	rim.position = Vector3(-0.9, 1.8, -1.6)
	_doll_view.add_child(rim)
	_doll = SUIT.instantiate()
	_doll_view.add_child(_doll)
	var animation := _doll.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation != null:
		_doll_animation = CrewAnimation.new()
		animation.get_parent().add_child(_doll_animation)
		_doll_animation.setup(animation)
	var lens := _doll.find_child("lamp_lens", true, false) as MeshInstance3D
	if lens != null and lens.get_active_material(0) is ShaderMaterial:
		_doll_lens = lens.get_active_material(0).duplicate()
		lens.material_override = _doll_lens
	var spine := _doll.find_child("spine_lights", true, false) as MeshInstance3D
	if spine != null and spine.get_active_material(0) is ShaderMaterial:
		_doll_spine = spine.get_active_material(0).duplicate()
		spine.material_override = _doll_spine
	_doll_harness = Player.fit_harness(_doll)


## The suit shows what the crew member's wearing and holding, and turns slowly to and fro.
func _pose_doll(delta: float) -> void:
	_turn += delta
	_doll.rotation.y = sin(_turn * 0.5) * 0.6 + 0.25
	var kind := player.held
	if kind != _doll_kind:
		_doll_kind = kind
		if _doll_held != null:
			_doll_held.queue_free()
		_doll_held = Items.hold(kind, _doll, true) if kind != &"body" else null
	if _doll_harness != null:
		_doll_harness.visible = player.harness
	if _doll_lens != null:
		_doll_lens.set_shader_parameter("energy", 2.0 if player.lamp_on else 0.15)
	if _doll_spine != null:
		_doll_spine.set_shader_parameter("albedo", Player.spine_colour(player.health))
	if _doll_animation != null:
		_doll_animation.move = 0.0
		_doll_animation.hold = Items.hold_style(kind)
		_doll_animation.cuff = 1.0 if player.cuff_up else 0.0
		_doll_animation.step(delta, 0.0)


# --- Little helpers ----------------------------------------------------------------------------

## The thing being dragged, under the cursor.
func _draw_dragged() -> void:
	if not _dragging or _pressed < 0 or player.belt[_pressed].is_empty():
		return
	var rect := Rect2(_mouse - Vector2(SLOT, SLOT) / 2.0, Vector2(SLOT, SLOT))
	_canvas.draw_rect(rect, Color(DARK, 0.6))
	_canvas.draw_rect(rect.grow(-0.5), Color(COLOUR if FRAME.has_point(_mouse) else AMBER, 0.8), false, 1.0)
	_draw_item(player.belt[_pressed], rect, 1.0)
	if not FRAME.has_point(_mouse):
		Glyphs.draw(_canvas, "DROP", rect.position + Vector2(9, SLOT + 3), AMBER)


## The panel's own cursor: a small phosphor cross with a dot.
func _draw_cursor() -> void:
	var at := _mouse.floor()
	_canvas.draw_rect(Rect2(at - Vector2(4, 0), Vector2(3, 1)), COLOUR)
	_canvas.draw_rect(Rect2(at + Vector2(2, 0), Vector2(3, 1)), COLOUR)
	_canvas.draw_rect(Rect2(at - Vector2(0, 4), Vector2(1, 3)), COLOUR)
	_canvas.draw_rect(Rect2(at + Vector2(0, 2), Vector2(1, 3)), COLOUR)
	_canvas.draw_rect(Rect2(at, Vector2(1, 1)), Color.WHITE)


func _text(at: Vector2, value: String, colour: Color) -> void:
	_canvas.draw_string(FONT, at.floor(), value, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, colour)


func _text_width(value: String) -> float:
	return FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x


## A small heading in the pixel font, with a short rule after it.
func _label(at: Vector2, value: String) -> void:
	Glyphs.draw(_canvas, value, at.floor(), DIM)
	var end := at.x + Glyphs.width(value) + 4
	_canvas.draw_line(Vector2(end, at.y + 2.5).floor(), Vector2(end + 16, at.y + 2.5).floor(), Color(DIM, 0.8))


## `value` broken into lines no wider than `width`.
func _wrapped(value: String, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in value.split(" ", false):
		var trial := word if line == "" else line + " " + word
		if _text_width(trial) > width and line != "":
			out.append(line)
			line = word
		else:
			line = trial
	if line != "":
		out.append(line)
	return out


## Text wrapped to `width` from `at`, at most `most` lines.
func _wrap(at: Vector2, value: String, width: float, colour: Color, most: int) -> void:
	var lines := _wrapped(value, width)
	for i in mini(lines.size(), most):
		_text(at + Vector2(0, i * 14), lines[i], colour)


## An equipment icon drawn in pixels: the helmet lamp, the EVA harness, the communicator.
func _draw_icon(which: String, r: Rect2, colour: Color) -> void:
	var c := r.get_center().floor()
	match which:
		"lamp":
			# A helmet in profile, its lamp at the front, and the beam when it's on.
			_canvas.draw_arc(c + Vector2(-1, 2), 7.0, PI, TAU, 10, colour, 1.0)
			_canvas.draw_line(c + Vector2(-8, 2), c + Vector2(6, 2), colour, 1.0)
			_canvas.draw_rect(Rect2(c + Vector2(5, -3), Vector2(3, 4)), colour)
			if player.lamp_on:
				for k in 3:
					_canvas.draw_line(c + Vector2(9, -1), c + Vector2(13, -5 + k * 4), Color(colour, 0.7), 1.0)
		"harness":
			# The pack: two tanks side by side, straps over, nozzles at the corners.
			_canvas.draw_rect(Rect2(c + Vector2(-6, -7), Vector2(5, 13)).grow(-0.5), colour, false, 1.0)
			_canvas.draw_rect(Rect2(c + Vector2(1, -7), Vector2(5, 13)).grow(-0.5), colour, false, 1.0)
			_canvas.draw_line(c + Vector2(-7, -3), c + Vector2(7, -3), colour, 1.0)
			for corner in [Vector2(-8, -8), Vector2(7, -8), Vector2(-8, 6), Vector2(7, 6)]:
				_canvas.draw_rect(Rect2(c + corner, Vector2(2, 2)), colour)
		"comms":
			# The cuff on a wrist, its screen, and waves off it while the channel's open.
			_canvas.draw_rect(Rect2(c + Vector2(-7, -2), Vector2(9, 7)).grow(-0.5), colour, false, 1.0)
			_canvas.draw_rect(Rect2(c + Vector2(-5, 0), Vector2(5, 3)), colour)
			_canvas.draw_line(c + Vector2(-9, 5), c + Vector2(4, 5), Color(colour, 0.6), 1.0)
			var waves := 3 if not Sound.talking().is_empty() and fmod(_time, 0.5) < 0.35 else 1
			for k in waves:
				_canvas.draw_arc(c + Vector2(2, 0), 4.0 + k * 3.0, -PI / 3.0, PI / 3.0, 5, Color(colour, 0.9 - k * 0.25), 1.0)


func _icon(kind: StringName) -> Texture2D:
	if not _icons.has(kind):
		_icons[kind] = Items.icon(kind)
	return _icons[kind]
