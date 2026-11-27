extends SceneTree
## Self-play balance runner (BUILD_PLAN.md task 2.4): the computer plays itself at
## several capture targets and reports how often each side wins and how long games last.
## Both sides use the same search; a little randomness keeps games from repeating.
##
## From the repository root:
##   godot --headless --path game -s res://tools/self_play.gd -- --games=60 --depth=3 --targets=4,5,6,7
## Add --board=baghchal for Bagh-Chal.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const MAX_MOVES := 400

var board := "aadupuli"


func _init() -> void:
	var games := 60
	var depth := 3
	var targets: Array = [4, 5, 6, 7]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--games="):
			games = int(arg.trim_prefix("--games="))
		elif arg.begins_with("--depth="):
			depth = int(arg.trim_prefix("--depth="))
		elif arg.begins_with("--board="):
			board = arg.trim_prefix("--board=")
		elif arg.begins_with("--targets="):
			targets = Array(arg.trim_prefix("--targets=").split(",")).map(func(x: String) -> int: return int(x))
	print("Self-play on %s: %d games per target, search depth %d, both sides equal" % [board, games, depth])
	print("target | tigers win | goats win | unfinished | avg moves | avg captures | secs")
	for target: int in targets:
		_run(target, games, depth)
	quit()


func _run(target: int, games: int, depth: int) -> void:
	var start := Time.get_ticks_msec()
	var tigers := AadupuliOpponent.new(target * 1000 + 1)
	var goats := AadupuliOpponent.new(target * 1000 + 2)
	var tiger_wins := 0
	var goat_wins := 0
	var unfinished := 0
	var total_moves := 0
	var total_captures := 0
	for g in games:
		var s := R.new_game({"board": board, "capture_target": target})
		var n := 0
		while R.result(s) == R.ONGOING and n < MAX_MOVES:
			var ai := tigers if s.turn == R.TIGER else goats
			s = R.apply(s, ai.search(s, depth, 400, 0.08, 2))
			n += 1
		match R.result(s):
			R.TIGERS_WIN: tiger_wins += 1
			R.GOATS_WIN: goat_wins += 1
			_: unfinished += 1
		total_moves += n
		total_captures += s.captured
	print("%6d | %9.0f%% | %8.0f%% | %10d | %9.0f | %12.1f | %4d" % [
		target, 100.0 * tiger_wins / games, 100.0 * goat_wins / games, unfinished,
		float(total_moves) / games, float(total_captures) / games, (Time.get_ticks_msec() - start) / 1000])
