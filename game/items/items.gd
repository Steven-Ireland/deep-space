class_name Items
## What crew carry (GDD §9.4, §13): each kind's name, model, belt icon, and how it sits in the
## hand. The belt and the hand hold kinds (StringNames); &"" is nothing.

const KINDS := {
	&"flashlight": {"name": "FLASHLIGHT", "model": "res://assets/models/items/it_flashlight.glb", "hold": "torch", "tilt": 0.0},
	&"crowbar": {"name": "CROWBAR", "model": "res://assets/models/items/it_crowbar.glb", "hold": "tool", "tilt": 38.0},
	&"shock_prod": {"name": "SHOCK PROD", "model": "res://assets/models/weapons/wp_shock_prod.glb", "hold": "tool", "tilt": 30.0},
	&"flare": {"name": "FLARE", "model": "res://assets/models/items/it_flare.glb", "hold": "tool", "tilt": 20.0},
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
## the hand's, pitched up by its tilt. Held things never cast shadows, so a flashlight can't
## shade its own beam.
static func hold(kind: StringName, grip: Node3D) -> Node3D:
	if not KINDS.has(kind) or grip == null:
		return null
	var item: Node3D = load(KINDS[kind].model).instantiate()
	item.name = "Held"
	var socket := item.find_child("SOCKET_grip", true, false) as Node3D
	var offset := socket.position if socket != null else Vector3.ZERO
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(-float(KINDS[kind].tilt)))
	item.transform = Transform3D(tilt, tilt * -offset)
	grip.add_child(item)
	for mesh: GeometryInstance3D in item.find_children("*", "GeometryInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return item
