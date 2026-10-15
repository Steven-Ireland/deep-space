class_name VaultLock
extends Node
## A secure store's lock (GDD §8.3): its door LOCKED until its code's given at the lock panel
## outside it (dk_lock_panel; a Terminal running LockScreen), which needs its section's power. The
## code is DIGITS of SYMBOLS symbols, none twice, drawn from the derelict's seed. Each guess is
## answered by how many are right and in place, and how many right but out of place, and every wrong
## one buzzes, loud enough to carry (Noises). After TRIES wrong, the panel locks out for LOCKOUT
## seconds, sounding an alarm for ALARM of them that anything listening hears, and keys itself
## afresh. Given right, the door unlocks and opens.
##
## The host owns it and sends its state to everyone on each change (and to each crew member who
## joins); crew report their guesses.

const DIGITS := 3
const SYMBOLS := 6
const TRIES := 6
const LOCKOUT := 40.0
const ALARM := 12.0
## How often the alarm's heard while it sounds.
const ALARM_EVERY := 2.0

const LAMP_GREEN := preload("res://assets/materials/lk_lamp_open.tres")
const LAMP_RED := preload("res://assets/materials/lk_lamp_sealed.tres")
const LAMP_DEAD := preload("res://assets/materials/lk_lamp_dead.tres")

var derelict: Derelict
var door: Door
var panel: Node3D
var terminal: Terminal
## The code (host; every peer can draw it, but only the host answers), the guesses made since it
## was keyed ([[symbols], in place, out of place]), the lockout's seconds left, whether it's open,
## and how many times it's been keyed afresh.
var code: Array[int] = []
var guesses: Array = []
var lockout := 0.0
var open := false
var keyed := 0
var _lamp: MeshInstance3D
var _alarm_in := 0.0
var _time := 0.0


## The lock on `the_door`, run from the lock panel `prop`, in `owner_derelict`.
static func make(owner_derelict: Derelict, the_door: Door, prop: Node3D) -> VaultLock:
	var lock := VaultLock.new()
	lock.name = "VaultLock"
	lock.derelict = owner_derelict
	lock.door = the_door
	lock.panel = prop
	owner_derelict.add_child(lock)
	return lock


func _ready() -> void:
	door.sealed = true
	door.seal_text = "LOCKED"
	_lamp = panel.find_child("lamp_lock", true, false) as MeshInstance3D
	terminal = Terminal.new()
	terminal.name = "Terminal_screen_lock"
	terminal.screen_mesh_name = "screen_lock"
	terminal.screen_script = preload("res://game/terminals/screens/lock_screen.gd")
	terminal.resolution = Vector2i(240, 180)
	terminal.glow = Color(0.4, 1.0, 0.5)
	terminal.verb = "UNLOCK"
	terminal.screen_settings = {"lock": self}
	terminal.powered = func() -> bool: return live()
	panel.add_child(terminal)
	_key()
	NetworkEvents.on_peer_join.connect(func(peer: int):
		if multiplayer.is_server():
			_state.rpc_id(peer, _pack()))


## Whether its panel has power (its section's).
func live() -> bool:
	return derelict.power != null and derelict.power.powered_at(panel.global_position)


## Draws the code for this keying from the derelict's seed.
func _key() -> void:
	var rng := Seeds.rng(derelict.layout.seed, "vault/code/%d" % keyed)
	var symbols := range(1, SYMBOLS + 1)
	code.clear()
	for i in DIGITS:
		code.append(symbols.pop_at(rng.randi() % symbols.size()))


## How a guess scores against the code: [in place, out of place].
static func score(guess: Array, against: Array) -> Array[int]:
	var placed := 0
	var present := 0
	for i in guess.size():
		if guess[i] == against[i]:
			placed += 1
		elif guess[i] in against:
			present += 1
	return [placed, present]


## Tries left before it locks out.
func tries_left() -> int:
	return TRIES - guesses.size()


## On the operator's machine: they enter `symbols` at the panel.
func guess(symbols: Array) -> void:
	_guess.rpc_id(1, symbols)


@rpc("any_peer", "call_local", "reliable")
func _guess(symbols: Array) -> void:
	if not multiplayer.is_server() or open or lockout > 0.0 or not live() or symbols.size() != DIGITS:
		return
	var result := score(symbols, code)
	guesses.append([symbols.duplicate(), result[0], result[1]])
	if result[0] == DIGITS:
		open = true
		door.sealed = false
		door.open = true
		print("Vault: opened.")
	else:
		Noises.make(panel, panel.global_position + panel.global_basis * Vector3(0, 1.4, 0.2), &"buzz")
		if guesses.size() >= TRIES:
			lockout = LOCKOUT
			_alarm_in = 0.0
			print("Vault: locked out.")
	_broadcast(true)


func _process(delta: float) -> void:
	_time += delta
	if lockout > 0.0:
		lockout = maxf(0.0, lockout - delta)
		if multiplayer.is_server():
			_alarm_in -= delta
			if LOCKOUT - lockout < ALARM and _alarm_in <= 0.0:
				_alarm_in = ALARM_EVERY
				Noises.make(panel, panel.global_position, &"alarm")
			if lockout <= 0.0:
				keyed += 1
				_key()
				guesses.clear()
				_broadcast(false)
	if _lamp != null:
		if not live():
			_lamp.material_override = LAMP_DEAD
		elif open:
			_lamp.material_override = LAMP_GREEN
		else:
			_lamp.material_override = LAMP_RED if lockout <= 0.0 or fmod(_time, 0.4) < 0.2 else LAMP_DEAD


# --- Keeping peers in step ----------------------------------------------------------------------

func _broadcast(answered: bool) -> void:
	_state.rpc(_pack(), answered)


func _pack() -> Dictionary:
	return {"guesses": guesses, "lockout": lockout, "open": open, "keyed": keyed}


@rpc("authority", "call_local", "reliable")
func _state(data: Dictionary, answered := false) -> void:
	var was_open := open
	var was_out := lockout > 0.0
	guesses = data.guesses
	lockout = data.lockout
	open = data.open
	if data.keyed != keyed:
		keyed = data.keyed
		_key()
	if not answered:
		return
	if open and not was_open:
		Sound.console(terminal, &"confirm")
		_tell("SECURE STORE  ACCESS GRANTED", 0)
	elif lockout > 0.0 and not was_out:
		Sound.alarm(panel, ALARM)
		_tell("SECURE STORE  LOCKOUT  SECURITY ALERTED", 2)
	elif not open:
		Sound.console(terminal, &"refuse")


## Tells crew aboard the derelict near the store.
func _tell(text: String, level: int) -> void:
	var local := Player.local(get_tree())
	if local != null and local.global_position.distance_to(panel.global_position) < 24.0:
		Player.tell(get_tree(), text, level)
