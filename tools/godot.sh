#!/usr/bin/env bash
# Runs the project's Godot (4.7.2). Override with GODOT=/path/to/godot.
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
exec "$GODOT" --path "$(cd "$(dirname "$0")/.." && pwd)" "$@"
