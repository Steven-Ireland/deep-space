#!/usr/bin/env bash
# Renders one frame of the game from a fixed viewpoint and saves it, for checking art in context.
#   tools/shot.sh <out.png> <x,y,z,yaw,pitch> [extra game flags...]
set -euo pipefail
cd "$(dirname "$0")/.."
out="$1"; view="$2"; shift 2
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
"$GODOT" --path . --resolution 1280x720 -- --host --port=$((20000 + RANDOM % 20000)) --view="$view" --screenshot="$out" --frames=45 "$@" > /dev/null 2>&1 &
pid=$!
for _ in $(seq 1 40); do sleep 1; kill -0 $pid 2>/dev/null || break; done
kill $pid 2>/dev/null || true
