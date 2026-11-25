@echo off
rem Starts the Tiger & Goat online server (WebSocket) without a window.
rem Usage, from the repository root:  tools\run_server.cmd [port]   (default 9080)
set PORT=%1
if "%PORT%"=="" set PORT=9080
pushd "%~dp0..\game"
call godot --headless --path . res://server/server.tscn -- --port=%PORT%
popd
