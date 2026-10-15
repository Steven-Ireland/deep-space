#!/usr/bin/env bash
# Runs the headless tests (TECH §8): sector map rules, derelict and satellite layouts, generation determinism, audio,
# what lives in a derelict (the creatures), its power, what taking its Prize sets off (the events),
# the scene smoke test.
# Imports first, so new classes and built assets are known. Exits non-zero if any fails.
#   tools/test.sh            all of them
#   tools/test.sh smoke      those whose name contains "smoke"
set -uo pipefail
cd "$(dirname "$0")/.."
tools/godot.sh --headless --import >/dev/null 2>&1
status=0
for test in tests/test_*${1:-}*.gd; do
	tools/godot.sh --headless -s "$test" 2>&1 | grep -v '^\[DBG\]\|^Godot Engine\|^$\|ObjectDB instances were leaked\|resources still in use\|^   at: \(cleanup\|clear\) '
	[ "${PIPESTATUS[0]}" -eq 0 ] || status=1
done
exit $status
