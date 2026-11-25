#!/usr/bin/env bash
# Starts the Tiger & Goat online server (WebSocket) without a window.
# Usage, from the repository root:  bash tools/run_server.sh [port]   (default 9080)
GODOT="${GODOT:-godot}"
PORT="${1:-9080}"
cd "$(dirname "$0")/../game" || exit 1
exec "$GODOT" --headless --path . res://server/server.tscn -- --port="$PORT"
