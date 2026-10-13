#!/usr/bin/env bash
# Launches a local crew for testing: one host plus N clients (default 1) joining it, tiled across
# the screen by netfox's window tiler. Ctrl-C closes them all.
#   tools/run.sh            host + 1 client
#   tools/run.sh 3          host + 3 clients (a full crew)
#   tools/run.sh 0          host alone
set -euo pipefail
cd "$(dirname "$0")/.."
clients="${1:-1}"
pids=()
trap 'kill "${pids[@]}" 2>/dev/null || true' EXIT INT TERM
tools/godot.sh -- --host & pids+=($!)
sleep 1
for ((i = 0; i < clients; i++)); do
	tools/godot.sh -- --join=127.0.0.1 & pids+=($!)
done
wait
