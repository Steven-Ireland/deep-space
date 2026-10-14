class_name Items
## What crew carry (GDD §9.4, §13): each kind's name, model, belt icon, and how it sits in the
## hand. The belt and the hand hold kinds (StringNames); &"" is nothing.
##
## Each sits in its hand pitched up by a tilt (degrees), which the arm's hold pose then carries
## (art/blender/characters.py):
##   `tilt`, in the first-person fist: 0 lies along the fist, as a torch does; a tool's handle runs
##     up across it, the way a fist holds a hammer (ARM_TOOL solves the arms' tool hold for 75°).
##   `glove`, in the suit's glove: 0 runs across it (HOLDS solves the torch hold for the
##     flashlight's glove tilt, and the tool hold for 0).
## A tool's few degrees either way from its hold's are how it angles from the others.

const KINDS := {
	&"flashlight": {"name": "FLASHLIGHT", "model": "res://assets/models/items/it_flashlight.glb", "hold": "torch", "tilt": 0.0, "glove": -40.0},
	&"crowbar": {"name": "CROWBAR", "model": "res://assets/models/items/it_crowbar.glb", "hold": "tool", "tilt": 70.0, "glove": 5.0},
	&"shock_prod": {"name": "SHOCK PROD", "model": "res://assets/models/weapons/wp_shock_prod.glb", "hold": "tool", "tilt": 70.0, "glove": -20.0},
	&"flare": {"name": "FLARE", "model": "res://assets/models/items/it_flare.glb", "hold": "tool", "tilt": 80.0, "glove": -10.0},
}

## The Tier 0 starting kit (GDD §13), in belt order.
const STARTING_BELT: Array[StringName] = [&"flashlight", &"crowbar", &"shock_prod", &"flare"]


static func display_name(kind: StringName) -> String:
	return KINDS[kind].name if KINDS.has(kind) else ""


## How the arm holds it: "torch" (raised and pointed ahead), "tool" (carried low), or "".
static func hold_style(kind: StringName) -> String:
	return KINDS[kind].hold if KINDS.has(kind) else ""


## The belt icon: a white silhouette the visor tints (rendered with the model, TECH §5).
static func icon(kind: StringName) -> Texture2D:
	var path := "res://assets/icons/%s.png" % String(KINDS[kind].model).get_file().get_basename() if KINDS.has(kind) else ""
	return load(path) if path != "" and ResourceLoader.exists(path) else null


## An instance of `kind` held at `grip` (a hand's grip socket): the item's own `SOCKET_grip` on
## the hand's, pitched up by its tilt for that hand (the suit's `glove`, or the first-person fist).
## Held things never cast shadows, so a flashlight can't shade its own beam.
static func hold(kind: StringName, grip: Node3D, glove := false) -> Node3D:
	if not KINDS.has(kind) or grip == null:
		return null
	var item: Node3D = load(KINDS[kind].model).instantiate()
	item.name = "Held"
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(-float(KINDS[kind].glove if glove else KINDS[kind].tilt)))
	item.transform = Transform3D(tilt, tilt * -grip_offset(item))
	grip.add_child(item)
	for mesh: GeometryInstance3D in item.find_children("*", "GeometryInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return item


## Where an item's grip is, in its own space: its `SOCKET_grip`, or its origin.
static func grip_offset(item: Node3D) -> Vector3:
	var socket := item.find_child("SOCKET_grip", true, false) as Node3D
	return socket.position if socket != null else Vector3.ZERO
