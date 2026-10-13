extends Node
## Hosting and joining a crew (an autoload, `Net`). A listen server over ENet: the host plays too.
## netfox's NetworkEvents starts NetworkTime once a peer is up, so this only makes the peer.
##
## Command-line flags (after `--`): `--host`, `--join=<address>`, `--port=<n>`. With none, the
## game hosts alone, so it can be played solo straight from the editor.

signal hosted
signal joined
signal failed(reason: String)
signal left

const DEFAULT_PORT := 7878
const MAX_CREW := 4


func _ready() -> void:
	multiplayer.connected_to_server.connect(func(): joined.emit())
	multiplayer.connection_failed.connect(func(): _fail("Couldn't reach the host."))
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if DisplayServer.get_name() == "headless" and not Args.flag("--host") and not Args.flag("--join"):
		return # tools and tests run headless without a session
	_start_from_command_line.call_deferred()


## Hosts a crew of up to MAX_CREW on `port`.
func host(port := DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_CREW - 1)
	if error != OK:
		_fail("Couldn't host on port %d (%s)." % [port, error_string(error)])
		return error
	multiplayer.multiplayer_peer = peer
	_title("Host")
	hosted.emit()
	return OK


## Joins the crew hosted at `address`.
func join(address: String, port := DEFAULT_PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		_fail("Couldn't connect to %s:%d (%s)." % [address, port, error_string(error)])
		return error
	multiplayer.multiplayer_peer = peer
	_title("Crew")
	return OK


func leave() -> void:
	multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	left.emit()


func is_host() -> bool:
	return multiplayer.is_server()


func _start_from_command_line() -> void:
	var port := int(Args.value("--port", str(DEFAULT_PORT)))
	if Args.flag("--join"):
		join(Args.value("--join", "127.0.0.1"), port)
	else:
		host(port)


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_fail("Lost the host.")
	left.emit()


func _fail(reason: String) -> void:
	push_warning(reason)
	failed.emit(reason)


func _title(role: String) -> void:
	if DisplayServer.get_name() != "headless":
		get_window().title = "%s — %s" % [ProjectSettings.get_setting("application/config/name"), role]

