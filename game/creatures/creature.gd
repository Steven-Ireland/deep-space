class_name Creature
extends CharacterBody3D
## Something living in a derelict (GDD §12): few and singular, each a presence the crew has to
## think about for the whole encounter. The host runs it (TECH §2): what it hears (`hear`), what it
## does (each kind's `_think`, every physics frame), and its attacks on crew, which it tells their
## own machines (Player.hurt, Player.seize). Everyone else sees it through its StateSynchronizer,
## where it is smoothed by a TickInterpolator, playing what it's doing (`clip`, started again each
## time `acts` counts on) and heard doing it. Crew report striking it (`strike`); the host applies
## it.
##
## It belongs to its derelict: made from the plan on every peer under the same name (so the host's
## state finds it everywhere), a child of the derelict, in its space, so it rides with it. One that
## follows the crew aboard (Crawler) belongs to the LANTERN from then on: `deck` is wherever it is.

## Physics layers: "creatures" (solid to crew), and "hitboxes" (struck by a swing, in nobody's way).
const LAYER := 1 << 4
const HITBOX := 1 << 6
const MODELS := "res://assets/models/creatures/cr_%s.glb"
## How long after a derelict has docked before anything aboard stirs (its colliders settled, and
## the crew a moment to cross).
const STIR := 1.0

## Synced from the host: which way it faces, the clip it's playing and how fast, one-shot clips
## started so far, what it's doing (each kind's own), and how hurt it is (1 whole, 0 dead).
var yaw := 0.0
var clip := &"idle"
var clip_speed := 1.0
var acts := 0
var mode := &""
var health := 1.0
## Jolts from a shock prod so far, and blows struck on it: each heard by everyone.
var jolts := 0
var blows := 0

## Its derelict, and which it is there (its index in the plan); the deck it's on (its derelict, or
## the LANTERN once it's come aboard), whose space it moves in.
var derelict: Derelict
var deck: Deck
var index := 0
var model: Node3D
var _animation: AnimationPlayer
var _acts_seen := 0
var _clip_shown := &""
var _jolts_heard := 0
var _blows_heard := 0
var _settled := 0.0 # seconds it's been stirring (host)
var _busy := 0.0 # seconds left of a one-shot clip (host)
var _debug_in := 0.0


## A creature of `kind` (&"crawler", &"hanger") at `at` in its derelict, the plan's `index`th.
static func make(kind: StringName, at: Transform3D, number: int) -> Creature:
	var creature: Creature
	match kind:
		&"hanger":
			creature = Hanger.new()
		_:
			creature = Crawler.new()
	creature.name = "Creature%d" % number
	creature.index = number
	creature.transform = Transform3D(Basis(), at.origin)
	creature.yaw = at.basis.get_euler().y
	return creature


## The creature a collider belongs to (its body, or its hitbox), or null.
static func of(collider: Object) -> Creature:
	if collider is Creature:
		return collider
	if collider is Node and (collider as Node).get_parent() is Creature:
		return (collider as Node).get_parent()
	return null


## Its kind's name, for its model (cr_<kind>) and the log.
func kind() -> StringName:
	return &"creature"


func _ready() -> void:
	add_to_group(&"creatures")
	deck = get_parent() as Deck
	derelict = deck as Derelict
	model = load(MODELS % kind()).instantiate()
	add_child(model)
	Deck._mark_interior(model)
	_animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	rotation.y = yaw
	var sync := StateSynchronizer.new()
	sync.name = "StateSynchronizer"
	sync.root = self
	sync.properties = [":position", ":yaw", ":clip", ":clip_speed", ":acts", ":mode", ":health", ":jolts", ":blows"]
	add_child(sync)
	if not multiplayer.is_server():
		# Only where it's watched: the host moves it itself, every physics frame.
		var interpolator := TickInterpolator.new()
		interpolator.name = "TickInterpolator"
		interpolator.root = self
		interpolator.properties = [":position"]
		add_child(interpolator)
	_setup()


## Each kind's own making: its shapes, sockets.
func _setup() -> void:
	pass


func _process(delta: float) -> void:
	if Args.flag("--debug-creatures"):
		_debug_in -= delta
		if _debug_in <= 0.0:
			_debug_in = 1.0
			print("Creature %s (%s): %s, %s at %s" % [name, "host" if multiplayer.is_server() else "copy", mode, clip, position.snapped(Vector3.ONE * 0.01)])
	if multiplayer.is_server():
		rotation.y = yaw
	else:
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-delta * 14.0))
	_play()
	if jolts != _jolts_heard:
		_jolts_heard = jolts
		Sound.zap(self)
	if blows != _blows_heard:
		_blows_heard = blows
		Sound.flesh_hit(self)
	_sounds(delta)


## What it sounds like, on every peer (each kind's own).
func _sounds(_delta: float) -> void:
	pass


## Plays `clip` at `clip_speed`, from its start again when `acts` has counted on (a one-shot).
func _play() -> void:
	if _animation == null:
		return
	if clip != _clip_shown or acts != _acts_seen:
		_clip_shown = clip
		_acts_seen = acts
		if _animation.has_animation(clip):
			_animation.play(clip, 0.0)
			_animation.seek(0.0, true)
	_animation.speed_scale = clip_speed


## Host: plays `name` from its start (everywhere); a one-shot plays out before any loop takes over.
func act(name: StringName, speed := 1.0) -> void:
	clip = name
	clip_speed = speed
	acts += 1
	_busy = 0.0
	if _animation != null and _animation.has_animation(name):
		var animation := _animation.get_animation(name)
		if animation.loop_mode == Animation.LOOP_NONE:
			_busy = animation.length / speed


## Host: plays `name`, looping (left alone if it's already playing, or a one-shot is).
func loop(name: StringName, speed := 1.0) -> void:
	if _busy > 0.0:
		return
	clip = name
	clip_speed = speed


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or deck == null:
		return
	_busy -= delta
	if not _awake():
		_settled = 0.0
		return
	_settled += delta
	if _settled < STIR:
		return
	_think(delta)


## Whether it's stirring: in its derelict, once that's docked (Derelict.awake); aboard the
## LANTERN, always.
func _awake() -> bool:
	return not (deck is Derelict) or (deck as Derelict).awake()


## Everyone: it's come aboard `onto` (the LANTERN), keeping where it stands in the world: it
## belongs to that deck from now on.
@rpc("authority", "call_local", "reliable")
func _board(onto: NodePath) -> void:
	var lantern := get_node_or_null(onto) as Deck
	if lantern == null:
		return
	var at := global_transform
	get_parent().remove_child(self)
	lantern.add_child(self)
	global_transform = at
	yaw = rotation.y
	deck = lantern
	print("%s %s: aboard the LANTERN." % [String(kind()).capitalize(), name])


## Host: what it does now (each kind's own).
func _think(_delta: float) -> void:
	pass


## Whether it's still alive.
func alive() -> bool:
	return health > 0.0


# --- Senses ------------------------------------------------------------------------------------

## Host: a noise (Noises) of kind `what` at `at` (world space), carrying `reach` metres, made by
## `source` (a crew member, or null). Heard if it carries this far through its deck's rooms.
func hear(at: Vector3, reach: float, what: StringName, source: Node) -> void:
	if not listens() or not alive() or deck == null or not _awake() or _settled < STIR:
		return
	var from := deck.to_local(at)
	var nav := deck.nav()
	if not nav.inside(from):
		return
	var distance := nav.heard(from, position, reach)
	if distance < reach:
		_heard(from, 1.0 - distance / reach, what, source as Player)


## Whether it hears at all.
func listens() -> bool:
	return false


## Host: it heard `what` at `from` (its deck's space), `level` loud (0 at the edge of hearing,
## 1 at its source), made by `source` (a crew member, or null).
func _heard(_from: Vector3, _level: float, _what: StringName, _source: Player) -> void:
	pass


## The living crew on its deck, on the host.
func crew_aboard() -> Array[Player]:
	var out: Array[Player] = []
	for player: Player in get_tree().get_nodes_in_group(&"crew"):
		if not player.dead and on_deck(player):
			out.append(player)
	return out


## Whether `player` is on its deck (in one of its rooms).
func on_deck(player: Player) -> bool:
	var zone := Zone.at(get_world_3d(), player.global_position + Vector3.UP * Player.CHEST_HEIGHT)
	return zone != null and zone.get_parent() == deck


# --- Being struck ------------------------------------------------------------------------------

## How hard each tool strikes (a share of a creature's life); anything else, BLUNT.
const DAMAGE := {&"crowbar": 0.2, &"shock_prod": 0.1}
const BLUNT := 0.08


## On a crew member's machine: their swing struck it with a `kind` (Items) of tool, and `jolt`
## if it was a shock prod that spent a charge on it.
func strike(kind: StringName, jolt: bool) -> void:
	_struck.rpc_id(1, kind, jolt)


@rpc("any_peer", "call_local", "reliable")
func _struck(kind: StringName, jolt: bool) -> void:
	if not multiplayer.is_server() or not alive():
		return
	var peer := multiplayer.get_remote_sender_id()
	blows += 1
	if jolt:
		jolts += 1
	Noises.make(self, global_position + Vector3.UP * 0.5, &"zap" if jolt else &"hit", self)
	struck(DAMAGE.get(kind, BLUNT), jolt, Player.of_peer(get_tree(), 1 if peer == 0 else peer))


## Host: struck for `damage`, jolted by a shock prod or not, by `by` (each kind's own).
func struck(_damage: float, _jolt: bool, _by: Player) -> void:
	pass
