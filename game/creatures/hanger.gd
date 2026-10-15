class_name Hanger
extends Creature
## THE HANGER (GDD §12): the ceiling trap. It hangs from the ceiling over its growth, its tendrils
## down nearly to the deck, seen only in a lamp beam (in the dark, only their beads show, low over
## the deck). It doesn't hear and doesn't move. Whoever walks into its tendrils is yanked up into
## them (Player.seize) and dies within Player.HELD seconds unless it's struck: then it drops them
## and draws its tendrils up for a while. A shock prod's jolt makes it let go and recoil longer;
## three blows from a crowbar kill it. What it does (`mode`):
##   set       hanging, waiting
##   holding   someone in its tendrils
##   recoil    struck: tendrils drawn up, nobody caught however near, for RECOIL seconds
##   sated     fed: drawn up for SATED seconds
##   dead

## A crew member this near its middle (metres across the deck) has walked into its tendrils.
const TOUCH := 0.5
## Seconds drawn up after a blow, after a jolt, and after it's fed; then it lets its tendrils down
## again, over LOWER seconds, before anyone can be caught.
const RECOIL := 6.0
const JOLTED := 12.0
const SATED := 25.0
const LOWER := 1.5
## Seconds its tendrils take to snap shut round someone (its grab).
const GRAB := 0.6
## Where its maw is, under its body (it hangs from its origin, on the ceiling), and where a crew
## member it holds is drawn to: their feet this far under it, their head up in its tendrils.
const MAW := Vector3(0.0, -0.62, 0.0)
const HOLD_FEET := Vector3(0.0, -2.62, 0.0)
## Its tendrils, for a swing to strike: from under its body down to near the deck.
const TENDRIL_TOP := -0.6
const TENDRIL_BOTTOM := -2.9

## Host: who it holds, and the time left in what it's doing.
var victim: Player
var _left := 0.0
var _lowering := false
var _touch_in := 0.0
var _tendrils: CollisionShape3D
## What it sounds like, on every peer.
var _mode_heard := &""
var _creak_in := 4.0


func kind() -> StringName:
	return &"hanger"


func _setup() -> void:
	collision_layer = 0
	collision_mask = 0
	var hitbox := StaticBody3D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = HITBOX
	hitbox.collision_mask = 0
	var body := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.45
	body.shape = sphere
	body.position = Vector3(0, -0.35, 0)
	hitbox.add_child(body)
	_tendrils = CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.3
	cylinder.height = TENDRIL_TOP - TENDRIL_BOTTOM
	_tendrils.shape = cylinder
	_tendrils.position = Vector3(0, (TENDRIL_TOP + TENDRIL_BOTTOM) / 2.0, 0)
	hitbox.add_child(_tendrils)
	add_child(hitbox)
	mode = &"set"


func _process(delta: float) -> void:
	super._process(delta)
	# Its tendrils are only there to strike while they hang down (or hold someone).
	_tendrils.disabled = mode in [&"recoil", &"sated", &"dead"]


## Where a crew member it holds is drawn to: their feet, in the world.
func hold_point() -> Vector3:
	return global_transform * HOLD_FEET


## Its maw, in the world: what someone it holds is made to look up into.
func maw() -> Vector3:
	return global_transform * MAW


# --- Thinking (host) ---------------------------------------------------------------------------

func _think(delta: float) -> void:
	if not alive():
		return
	_left -= delta
	match mode:
		&"set":
			loop(&"idle")
			_touch_in -= delta
			if _touch_in <= 0.0:
				_touch_in = 0.05
				_touched()
		&"holding":
			if _left <= 0.0:
				loop(&"hold") # once its tendrils have snapped shut (grab)
			if victim == null or not is_instance_valid(victim) or victim.dead:
				# Fed: the body drops from its tendrils (it fell where they died), and it draws up.
				victim = null
				_draw_up(SATED)
		&"recoil", &"sated":
			if _left <= 0.0 and not _lowering:
				_lowering = true
				act(&"lower")
				_left = LOWER
			elif _left <= 0.0:
				_lowering = false
				mode = &"set"


## Whether anyone's walked into its tendrils: the first is caught.
func _touched() -> void:
	for player in crew_aboard():
		if player.seized:
			continue
		var off := derelict.to_local(player.global_position) - position
		if Vector2(off.x, off.z).length() < TOUCH:
			_catch(player)
			return


func _catch(player: Player) -> void:
	victim = player
	mode = &"holding"
	act(&"grab")
	_left = GRAB
	print("Hanger %s: caught %s." % [name, player.crew_name()])
	player.seize.rpc_id(player.get_multiplayer_authority(), get_path())


## Lets go of whoever it holds, and draws its tendrils up for `seconds` (fed, slowly; struck, the
## blow's recoil does it).
func _draw_up(seconds: float) -> void:
	if victim != null and is_instance_valid(victim):
		victim.release.rpc_id(victim.get_multiplayer_authority())
	victim = null
	mode = &"sated" if seconds == SATED else &"recoil"
	if mode == &"sated":
		act(&"draw")
	_left = seconds
	_lowering = false


# --- Struck (host) -----------------------------------------------------------------------------

## Struck by anyone (whoever it holds too, if they can swing): it drops them and draws up.
func struck(damage: float, jolt: bool, _by: Player) -> void:
	health = maxf(0.0, health - damage * 1.7)
	if health < 0.01:
		health = 0.0
		if victim != null and is_instance_valid(victim):
			victim.release.rpc_id(victim.get_multiplayer_authority())
		victim = null
		mode = &"dead"
		act(&"death")
		print("Hanger %s: dead." % name)
		return
	act(&"hurt")
	_draw_up(JOLTED if jolt else RECOIL)


# --- What it sounds like (every peer) ------------------------------------------------------------

func _sounds(delta: float) -> void:
	if mode != _mode_heard:
		_mode_heard = mode
		match mode:
			&"holding":
				Sound.creature(self, &"hanger_grab")
			&"recoil":
				Sound.creature(self, &"hanger_hurt")
			&"dead":
				Sound.creature(self, &"hanger_death")
	if mode == &"set":
		_creak_in -= delta
		if _creak_in <= 0.0:
			_creak_in = randf_range(5.0, 11.0)
			Sound.creature(self, &"hanger_creak")
