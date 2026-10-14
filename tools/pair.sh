#!/usr/bin/env bash
# Two crew on one machine, for checking what a teammate looks like: a host and a client join, and
# the host saves a screenshot once the client is aboard (and `frames` more frames have passed, for
# the client to settle where its flags put it). The host's view is its own crew member's, or a
# fixed camera with --view.
#   tools/pair.sh <out.png> "<host flags>" "<client flags>" [frames]
#   tools/pair.sh shot.png "--view=-3.1,1.6,-2.5,180,0" "--at=-3,0,0.5 --look=0,0 --lamp"
#   tools/pair.sh shot.png "--at=4.4,0,18.3 --look=180,-10" "--at=4.2,0,20.4 --hold=crowbar"
# Logs go to $TMPDIR/deep-space-pair-{host,client}.log; errors in them are printed at the end (not
# "resources still in use at exit": a sound still playing when the game quits).
set -euo pipefail
cd "$(dirname "$0")/.."
out="$1"; host_flags="$2"; client_flags="$3"; frames="${4:-120}"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
logs="${TMPDIR:-/tmp}"
port=$((20000 + RANDOM % 20000))
# shellcheck disable=SC2086 # the flags are word lists
"$GODOT" --path . --resolution 960x540 -- --host --port="$port" $host_flags \
	--wait-crew=2 --frames="$frames" --screenshot="$out" > "$logs/deep-space-pair-host.log" 2>&1 &
host=$!
sleep 1.5
# shellcheck disable=SC2086
"$GODOT" --path . --resolution 480x270 -- --join=127.0.0.1 --port="$port" $client_flags \
	--quit-after=60 > "$logs/deep-space-pair-client.log" 2>&1 &
client=$!
for _ in $(seq 1 60); do sleep 1; kill -0 "$host" 2>/dev/null || break; done
kill "$host" "$client" 2>/dev/null || true
wait "$host" "$client" 2>/dev/null || true
grep -hE "SCRIPT ERROR|ERROR:|Screenshot" "$logs/deep-space-pair-host.log" "$logs/deep-space-pair-client.log" | grep -v "resources still in use" | sort | uniq -c | head -20 || true
