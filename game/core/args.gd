class_name Args
## The game's own command-line flags: whatever follows `--` when launching Godot.


## Whether `name` was passed, bare (`--host`) or with a value (`--join=1.2.3.4`).
static func flag(name: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == name or arg.begins_with(name + "="):
			return true
	return false


## The value passed as `name=<value>`, or `default`.
static func value(name: String, default := "") -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(name + "="):
			return arg.trim_prefix(name + "=")
	return default
