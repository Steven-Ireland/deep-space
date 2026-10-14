class_name CrewAnimation
extends AnimationTree
## Blends a crew rig's clips by what its crew member is doing: standing, walking and running in
## step, crouching, the right arm holding something or both arms carrying something big, the left
## raising the wrist cuff, and the right swinging a tool once (swing()). Used for the suit everyone
## else sees and the first-person arms. Set the blend values each frame; they're eased here.
##
## Walk, run and crouch-walk are one stride cycle a second each, left heel strike first (TECH §5),
## so they blend in step: `rate` is stride cycles a second, negative walking backwards.

## Seconds per stride cycle of each gait (art/blender/characters.py: WALK, RUN, SNEAK periods),
## and the ground a cycle covers there.
const WALK_PERIOD := 0.7
const RUN_PERIOD := 0.66
const SNEAK_PERIOD := 1.0
const WALK_SPEED := 2.2
const RUN_SPEED := 4.0
const SNEAK_SPEED := 1.2

## 0 standing .. 1 at walking pace (or crouch-walking pace, crouched).
var move := 0.0
## 0 walking .. 1 running.
var run := 0.0
## 0 standing .. 1 crouched.
var crouch := 0.0
## 0 .. 1 the wrist cuff raised.
var cuff := 0.0
## What the hands hold: "tool" (the right), "carry" (both) or "".
var hold := ""
## Which way the stride plays: 1 forward, -1 walking backwards.
var direction := 1.0

var _tool := 0.0
var _carry := 0.0
var _clips: PackedStringArray


## Takes over `player`'s clips. The tree sits beside the player so their tracks line up.
func setup(player: AnimationPlayer) -> void:
	_clips = player.get_animation_list()
	root_node = player.root_node
	anim_player = get_path_to(player)
	var tree := AnimationNodeBlendTree.new()
	var skeleton := _skeleton_path(player)
	var stand := _locomotion(tree, "idle", "walk", "run", "stand")
	var top := stand
	if _has("crouch"):
		tree.add_node("crouch", _clip("crouch"))
		tree.add_node("sneak", _clip("crouch_walk"))
		tree.add_node("sneak_pace", AnimationNodeTimeScale.new())
		tree.connect_node("sneak_pace", 0, "sneak")
		tree.add_node("low", AnimationNodeBlend2.new())
		tree.connect_node("low", 0, "crouch")
		tree.connect_node("low", 1, "sneak_pace")
		tree.add_node("posture", AnimationNodeBlend2.new())
		tree.connect_node("posture", 0, stand)
		tree.connect_node("posture", 1, "low")
		top = "posture"
	# The first-person arms' upper arms are arm.*, the suit's upper_arm.*.
	var first_person := player.get_animation("idle").find_track(NodePath("%s:arm.R" % skeleton), Animation.TYPE_ROTATION_3D) >= 0
	var upper := "arm" if first_person else "upper_arm"
	var right_arm := [upper + ".R", "forearm.R", "hand.R"]
	if _has("hold_tool"):
		tree.add_node("tool", _clip("hold_tool"))
		top = _layer(tree, top, "tool", "with_tool", skeleton, right_arm)
	if _has("hold_carry"):
		tree.add_node("carry", _clip("hold_carry"))
		top = _layer(tree, top, "carry", "with_carry", skeleton, right_arm + [upper + ".L", "forearm.L", "hand.L"])
	if _has("cuff"):
		tree.add_node("cuff", _clip("cuff"))
		var reading := [upper + ".L", "forearm.L", "hand.L"] + ([] if first_person else ["head", "chest"])
		top = _layer(tree, top, "cuff", "reading", skeleton, reading)
	if _has("swing"):
		var shot := AnimationNodeOneShot.new()
		shot.filter_enabled = true
		for bone: String in right_arm:
			shot.set_filter_path(NodePath("%s:%s" % [skeleton, bone]), true)
		shot.fadein_time = 0.04
		shot.fadeout_time = 0.1
		tree.add_node("swing_clip", _clip("swing"))
		tree.add_node("swing", shot)
		tree.connect_node("swing", 0, top)
		tree.connect_node("swing", 1, "swing_clip")
		top = "swing"
	tree.connect_node("output", 0, top)
	tree_root = tree
	active = true


## Eases the blends toward their targets, and plays the stride at `speed` m/s.
func step(delta: float, speed: float) -> void:
	var ease := 1.0 - exp(-delta * 10.0)
	_tool = lerpf(_tool, 1.0 if hold == "tool" else 0.0, ease)
	_carry = lerpf(_carry, 1.0 if hold == "carry" else 0.0, ease)
	set("parameters/gait/blend_amount", run)
	set("parameters/stand/blend_amount", move)
	set("parameters/pace/scale", direction * stride_rate(speed, run))
	if _has("crouch"):
		set("parameters/low/blend_amount", move)
		set("parameters/posture/blend_amount", crouch)
		set("parameters/sneak_pace/scale", direction / SNEAK_PERIOD)
	if _has("hold_tool"):
		set("parameters/with_tool/blend_amount", _tool)
	if _has("hold_carry"):
		set("parameters/with_carry/blend_amount", _carry)
	if _has("cuff"):
		set("parameters/reading/blend_amount", cuff * cuff * (3.0 - 2.0 * cuff))


## Plays the right arm's swing once, over whatever it's doing.
func swing() -> void:
	if _has("swing"):
		set("parameters/swing/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


## Stride cycles a second at `speed`: below walking pace the stride shortens (blended toward
## standing) at walking cadence; above it, the stride lengthens toward the run's.
static func stride_rate(speed: float, run_amount: float) -> float:
	if speed <= WALK_SPEED:
		return 1.0 / WALK_PERIOD
	var stride := lerpf(WALK_SPEED * WALK_PERIOD, RUN_SPEED * RUN_PERIOD, run_amount)
	return speed / stride


func _has(clip: String) -> bool:
	return clip in _clips


func _clip(name: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = name
	return node


## idle / walk / run: walk and run in step (they're the same length), played at `pace`.
func _locomotion(tree: AnimationNodeBlendTree, idle: String, walk: String, running: String, name: String) -> String:
	tree.add_node(idle, _clip(idle))
	tree.add_node(walk, _clip(walk))
	tree.add_node(running, _clip(running))
	var gait := AnimationNodeBlend2.new()
	gait.sync = true
	tree.add_node("gait", gait)
	tree.connect_node("gait", 0, walk)
	tree.connect_node("gait", 1, running)
	tree.add_node("pace", AnimationNodeTimeScale.new())
	tree.connect_node("pace", 0, "gait")
	tree.add_node(name, AnimationNodeBlend2.new())
	tree.connect_node(name, 0, idle)
	tree.connect_node(name, 1, "pace")
	return name


## `clip` over `under` on just `bones`.
func _layer(tree: AnimationNodeBlendTree, under: String, clip: String, name: String, skeleton: String, bones: Array) -> String:
	var blend := AnimationNodeBlend2.new()
	blend.filter_enabled = true
	for bone: String in bones:
		blend.set_filter_path(NodePath("%s:%s" % [skeleton, bone]), true)
	tree.add_node(name, blend)
	tree.connect_node(name, 0, under)
	tree.connect_node(name, 1, clip)
	return name


func _skeleton_path(player: AnimationPlayer) -> String:
	var path := String(player.get_animation(player.get_animation_list()[0]).track_get_path(0))
	return path.get_slice(":", 0)
