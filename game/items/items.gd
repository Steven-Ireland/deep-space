class_name Items
## What crew carry (GDD §9.4, §13): each kind's name, model, belt icon, weight, and how it sits in
## the hand. A thing carried is a record, a Dictionary with its `kind` (a StringName here) and any
## state of its own; {} is nothing. The belt and the hands hold records; a loose one lies in the
## world as a Pickup.
##
## Small things go on the belt and are held in the right hand, pitched up by a tilt (degrees),
## which the arm's hold pose then carries (art/blender/characters.py):
##   `tilt`, in the first-person fist: 0 lies along the fist; a tool's handle runs up across it,
##     the way a fist holds a hammer (ARM_TOOL solves the arms' tool hold for 75°).
##   `glove`, in the suit's glove: 0 runs across it (HOLDS solves the tool hold for 0).
## A tool's few degrees either way from its hold's are how it angles from the others. Big things
## ("carry") take both hands and never go on the belt: they sit upright between the hands, their
## `SOCKET_grip` (midway between their handles) on the rig's `SOCKET_carry`.
##
## `mass` is in kilograms: heavy things don't fly far when thrown. `use` is what LMB does with it
## in hand (GDD §9.5): "swing" a tool, "refill" the suit's O2 (used up), "strike" a flare (it
## burns, its record's `burn` the seconds left), "patch" a breached suit (sealant, used up), "read"
## a data core into the suit's LOGS (its record's `log`, Lore; it's kept, to upload). A thing
## with `charges` (the shock prod) is made full, its record's `charge` the jolts left; the lamp
## charger in the suit room fills it again. `desc` is what the suit panel says of it.

const KINDS := {
	# Tier 0 kit and Tier 1 weapons.
	&"crowbar": {"name": "CROWBAR", "model": "res://assets/models/items/it_crowbar.glb", "hold": "tool", "tilt": 70.0, "glove": 5.0, "use": "swing", "mass": 2.5, "desc": "Forged steel, a hooked claw at one end. Swing it; force a dead door with it."},
	&"shock_prod": {"name": "SHOCK PROD", "model": "res://assets/models/weapons/wp_shock_prod.glb", "hold": "tool", "tilt": 70.0, "glove": -20.0, "use": "swing", "mass": 1.5, "charges": 3, "desc": "A stock prod from a cargo deck. Three jolts drop anything living for a moment. Charges at the lamp charger."},
	&"flare": {"name": "FLARE", "model": "res://assets/models/items/it_flare.glb", "hold": "tool", "tilt": 80.0, "glove": -10.0, "use": "strike", "mass": 0.3, "desc": "A red chemical flare. Strike it to burn for a minute: light, and a hiss that carries."},
	&"plasma_cutter": {"name": "PLASMA CUTTER", "model": "res://assets/models/weapons/wp_plasma_cutter.glb", "hold": "tool", "tilt": -60.0, "glove": 0.0, "mass": 3.0, "desc": "A mining cutter: a tight plasma arc for hull plate. Runs on energy cartridges."},
	&"rivet_driver": {"name": "RIVET DRIVER", "model": "res://assets/models/weapons/wp_rivet_driver.glb", "hold": "tool", "tilt": -60.0, "glove": 0.0, "mass": 3.5, "desc": "Drives one heavy bolt at a time. Loud. Runs on energy cartridges."},
	# Supplies and loot.
	&"o2_canister": {"name": "O2 CANISTER", "model": "res://assets/models/items/it_o2_canister.glb", "hold": "tool", "tilt": 165.0, "glove": 0.0, "use": "refill", "mass": 3.0, "desc": "Bottled breathing gas. Use it to top the suit up by three minutes."},
	&"sealant": {"name": "SEALANT", "model": "res://assets/models/items/it_sealant.glb", "hold": "tool", "tilt": 0.0, "glove": 0.0, "use": "patch", "mass": 0.5, "desc": "A can of quick-set suit sealant. Use it on a breach to stop the leak."},
	&"power_cell": {"name": "POWER CELL", "model": "res://assets/models/items/it_power_cell.glb", "hold": "tool", "tilt": 0.0, "glove": 0.0, "mass": 6.0, "desc": "A charged cell from an earlier wave's stores. Seat it in a breaker box to power a section."},
	&"data_core": {"name": "DATA CORE", "model": "res://assets/models/items/it_data_core.glb", "hold": "tool", "tilt": 0.0, "glove": 0.0, "use": "read", "mass": 0.8, "data": 30, "desc": "A ship's memory, sealed in a shock case. Read it from the suit; upload it at the Survey Console."},
	&"cartridge": {"name": "CARTRIDGE", "model": "res://assets/models/items/it_cartridge.glb", "hold": "tool", "tilt": 0.0, "glove": 0.0, "mass": 0.3, "desc": "An energy cartridge: the one round every weapon takes. Rare."},
	&"salvage_pipes": {"name": "SALVAGE", "value": 12, "model": "res://assets/models/items/it_salvage_pipes.glb", "hold": "tool", "tilt": 0.0, "glove": 0.0, "mass": 2.5, "desc": "Copper and steel pipe runs, torn out whole. Feed it to the recycler."},
	&"salvage_board": {"name": "SALVAGE", "value": 18, "model": "res://assets/models/items/it_salvage_board.glb", "hold": "tool", "tilt": 0.0, "glove": 0.0, "mass": 1.0, "desc": "A circuit board, its chips still socketed. Feed it to the recycler."},
	&"salvage_plates": {"name": "SALVAGE", "value": 10, "model": "res://assets/models/items/it_salvage_plates.glb", "hold": "tool", "tilt": 0.0, "glove": 0.0, "mass": 3.0, "desc": "Alloy plate, stripped from a bulkhead. Feed it to the recycler."},
	# Big things, carried in both hands. A dead crew member's body (GDD §11) is a Ragdoll, lying
	# loose as a LooseBody; its record says whose it is ({kind, peer, crew}).
	&"survey_core": {"name": "SURVEY CORE", "model": "res://assets/models/items/it_survey_core.glb", "hold": "carry", "tilt": 0.0, "glove": 0.0, "mass": 32.0, "desc": "An earlier wave's astrogation memory: the charts they made. Seat it in the core reader on the bridge to see where the next jumps lead."},
	&"fuel_cell": {"name": "FUEL CELL", "model": "res://assets/models/items/fuel_cell.glb", "hold": "carry", "tilt": 0.0, "glove": 0.0, "mass": 30.0, "desc": "A class IV warp fuel cell. One jump. Load it into the drive room's fuel rack."},
	&"body": {"name": "BODY", "model": "res://assets/models/characters/ch_suit.glb", "hold": "carry", "tilt": 0.0, "glove": 0.0, "mass": 90.0, "desc": "A crew member. The med bay can bring them back."},
}

## Slots on the belt (GDD §9.4). Everyone starts with it empty: the crew's one crowbar and one
## flare are racked in the docking port, and the rest is found.
const BELT_SLOTS := 4


## A new record of `kind` (or nothing, for &""): full, if it holds a charge.
static func make(kind: StringName) -> Dictionary:
	if not KINDS.has(kind):
		return {}
	var record := {"kind": kind}
	if KINDS[kind].has("charges"):
		record.charge = KINDS[kind].charges
	# Salvage is worth its scrap, a data core its Survey Data: each piece a little more or less.
	if KINDS[kind].has("value"):
		record.value = roundi(KINDS[kind].value * randf_range(0.75, 1.25))
	if KINDS[kind].has("data"):
		record.data = roundi(KINDS[kind].data * randf_range(0.7, 1.3))
	return record


## The charges `kind` holds full (0 for none), and those left in `record`.
static func charges(kind: StringName) -> int:
	return KINDS[kind].get("charges", 0) if KINDS.has(kind) else 0


static func charge(record: Dictionary) -> int:
	return record.get("charge", 0)


static func kind_of(record: Dictionary) -> StringName:
	return record.get("kind", &"")


static func display_name(kind: StringName) -> String:
	return KINDS[kind].name if KINDS.has(kind) else ""


## A line or two on what it is and what it's for (the suit panel).
static func description(kind: StringName) -> String:
	return KINDS[kind].get("desc", "") if KINDS.has(kind) else ""


## How the arm holds it: "tool" (carried low in the right hand), "carry" (both hands), or "".
static func hold_style(kind: StringName) -> String:
	return KINDS[kind].hold if KINDS.has(kind) else ""


## Whether it takes both hands, and so never goes on the belt.
static func two_handed(kind: StringName) -> bool:
	return hold_style(kind) == "carry"


static func use_of(kind: StringName) -> String:
	return KINDS[kind].get("use", "") if KINDS.has(kind) else ""


## Whether `record` is a struck flare still burning.
static func burning(record: Dictionary) -> bool:
	return record.get("burn", 0.0) > 0.0


static func mass(kind: StringName) -> float:
	return KINDS[kind].mass if KINDS.has(kind) else 1.0


static func model(kind: StringName) -> PackedScene:
	return load(KINDS[kind].model) if KINDS.has(kind) else null


## The belt icon: a white silhouette the visor tints (rendered with the model, TECH §5).
static func icon(kind: StringName) -> Texture2D:
	var path := "res://assets/icons/%s.png" % String(KINDS[kind].model).get_file().get_basename() if KINDS.has(kind) else ""
	return load(path) if path != "" and ResourceLoader.exists(path) else null


## An instance of `kind` held by `rig` (the first-person arms, or the suit with `glove`): the
## item's own `SOCKET_grip` on the rig's (the right hand's, or SOCKET_carry for a big thing),
## pitched up by its tilt for that hand. Held things never cast shadows, so they can't shade the
## lamp's light on what's ahead. A body's carried across the arms (`_carried_body`).
static func hold(kind: StringName, rig: Node3D, glove := false) -> Node3D:
	if not KINDS.has(kind):
		return null
	var grip := rig.find_child("SOCKET_carry" if two_handed(kind) else "SOCKET_grip", true, false) as Node3D
	if grip == null:
		return null
	if kind == &"body":
		return _carried_body(grip, rig, glove)
	var item: Node3D = model(kind).instantiate()
	item.name = "Held"
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(-float(KINDS[kind].glove if glove else KINDS[kind].tilt)))
	item.transform = Transform3D(tilt, tilt * -grip_offset(item))
	grip.add_child(item)
	for mesh: GeometryInstance3D in item.find_children("*", "GeometryInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return item


## A body carried in both arms: lying across them face up, its middle in the hands, its head to the
## carrier's right. Its torso's held; its head and limbs hang and swing (they touch nothing). In
## first person it rides out ahead of the hands, so its chest and helmet show across the bottom of
## the view (FIRST_PERSON_BODY, in the camera's space).
const FIRST_PERSON_BODY := Vector3(0, -0.5, -0.62)


static func _carried_body(grip: Node3D, rig: Node3D, glove: bool) -> Node3D:
	var body := Ragdoll.new()
	body.name = "Held"
	grip.add_child(body)
	# The carrier's frame: the rig's parent (the camera, or the crew member), -Z ahead.
	var carrier := rig.get_parent_node_3d().global_basis.orthonormalized()
	var lying := Basis(-carrier.z, carrier.x, -carrier.y)
	var middle := Vector3(0, 1.08, 0)
	var at := grip.global_position if glove else rig.get_parent_node_3d().global_transform * FIRST_PERSON_BODY
	body.global_transform = Transform3D(lying, at - lying * middle)
	for bone in body.bones:
		bone.collision_layer = 0
		bone.collision_mask = 0
	for mesh: GeometryInstance3D in body.find_children("*", "GeometryInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.hold_torso = true
	body.go_limp()
	return body


## Where an item's grip is, in its own space: its `SOCKET_grip`, or its origin.
static func grip_offset(item: Node3D) -> Vector3:
	var socket := item.find_child("SOCKET_grip", true, false) as Node3D
	return socket.position if socket != null else Vector3.ZERO


## The box round an item's meshes, in its own space.
static func bounds(item: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in item.find_children("*", "MeshInstance3D", true, false):
		var local := item.global_transform.affine_inverse() * mesh.global_transform if item.is_inside_tree() else _relative(item, mesh)
		var part := local * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


## `node`'s transform relative to `ancestor`, outside the scene tree.
static func _relative(ancestor: Node3D, node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var at: Node = node
	while at != null and at != ancestor:
		if at is Node3D:
			t = (at as Node3D).transform * t
		at = at.get_parent()
	return t
