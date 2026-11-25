@echo off
rem Runs the game's automated tests (gdUnit4) headless. Usage, from the repository root: tools\run_tests.cmd
rem Exit codes (gdUnit4): 0 all passed, 100 failures, 101 passed but warnings/orphans, 105 parse error.
pushd "%~dp0..\game"
call godot --headless --path . --import >nul 2>&1
call godot --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
set RESULT=%ERRORLEVEL%
popd
exit /b %RESULT%
