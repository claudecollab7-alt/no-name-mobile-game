#!/usr/bin/env bash
# Runs the game's automated tests (gdUnit4) headless. Usage, from the repository root:
#   bash tools/run_tests.sh
# Exit codes (gdUnit4): 0 all passed, 100 failures, 101 passed but warnings/orphans, 105 parse error.
set -u
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/../game" || exit 1
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
