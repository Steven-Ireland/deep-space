extends SceneTree
## Writes the game's input map into project.godot (GDD §9.5), so it stays readable here instead of
## as serialized events. Run: godot --headless --path . -s tools/setup_input.gd

const KEYS := {
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_CTRL, KEY_C],
	"jump": [KEY_SPACE],
	"interact": [KEY_E],
	"lamp": [KEY_F],
	"drop": [KEY_Q],
	"slot_1": [KEY_1],
	"slot_2": [KEY_2],
	"slot_3": [KEY_3],
	"slot_4": [KEY_4],
	"cuff": [KEY_TAB],
	"pause": [KEY_ESCAPE],
}
const BUTTONS := {
	"use": [MOUSE_BUTTON_LEFT],
	"alt_use": [MOUSE_BUTTON_RIGHT],
	"slot_next": [MOUSE_BUTTON_WHEEL_DOWN],
	"slot_prev": [MOUSE_BUTTON_WHEEL_UP],
}


func _init() -> void:
	for action in KEYS:
		var events: Array[InputEvent] = []
		for key in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			events.append(event)
		_set_action(action, events)
	for action in BUTTONS:
		var events: Array[InputEvent] = []
		for button in BUTTONS[action]:
			var event := InputEventMouseButton.new()
			event.button_index = button
			events.append(event)
		_set_action(action, events)
	var error := ProjectSettings.save()
	print("Input map saved: %s" % error_string(error))
	quit()


func _set_action(action: String, events: Array[InputEvent]) -> void:
	ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})
