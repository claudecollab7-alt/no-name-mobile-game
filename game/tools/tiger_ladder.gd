extends SceneTree
## Level ladder for the tiger-and-goat computer: each pairing plays half its games with
## each side, so a level's strength shows as tigers and as goats.
##   godot --headless --path game -s res://tools/tiger_ladder.gd -- --board=baghchal --games=10 --ms=300
## --pairs=easy:medium,medium:hard,hard:hard picks the pairings; --ms caps thinking time (0: the level's own);
## --set=edge:20,fork:600 overrides scoring weights for both sides while tuning.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const MAX_MOVES := 400

var tuning := {}


func _init() -> void:
	var board := "baghchal"
	var games := 10
	var ms := 300
	var pairs := ["easy:easy", "medium:medium", "hard:hard", "easy:medium", "medium:hard"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--board="):
			board = arg.trim_prefix("--board=")
		elif arg.begins_with("--games="):
			games = int(arg.trim_prefix("--games="))
		elif arg.begins_with("--ms="):
			ms = int(arg.trim_prefix("--ms="))
		elif arg.begins_with("--set="):
			for kv: String in arg.trim_prefix("--set=").split(","):
				tuning[kv.get_slice(":", 0)] = int(kv.get_slice(":", 1))
		elif arg.begins_with("--pairs="):
			pairs = Array(arg.trim_prefix("--pairs=").split(","))
	print("Ladder on %s: %d games per pairing, thinking capped at %d ms %s" % [board, games, ms, tuning])
	for p: String in pairs:
		var lv := p.split(":")
		_match(board, lv[0], lv[1], games, ms)
	quit()


## A level name like "d5" means a fixed look-ahead (5 moves) with medium's slips.
func _choose(ai: AadupuliOpponent, s: R.State, level: String, ms: int) -> int:
	if level.begins_with("d"):
		return ai.search(s, int(level.substr(1)), ms if ms > 0 else 10000, 0.1, 2)
	return ai.choose_move(s, level, ms)


## Half the games a plays tigers, half goats.
func _match(board: String, a: String, b: String, games: int, ms: int) -> void:
	var t0 := Time.get_ticks_msec()
	var ai_a := AadupuliOpponent.new(31)
	var ai_b := AadupuliOpponent.new(47)
	ai_a.tuning = tuning
	ai_b.tuning = tuning
	var a_tiger_wins := 0
	var a_goat_wins := 0
	var tiger_wins := 0
	var moves := 0
	var caps := 0
	var depth := [0, 0]  ## goats, tigers: summed look-ahead reached
	var turns := [0, 0]
	var think := [0, 0]  ## longest think, ms
	for g in games:
		var a_tigers := g % 2 == 0
		var s := R.new_game({"board": board})
		var n := 0
		while R.result(s) == R.ONGOING and n < MAX_MOVES:
			var a_moves := (s.turn == R.TIGER) == a_tigers
			var ai := ai_a if a_moves else ai_b
			var side := s.turn
			var t1 := Time.get_ticks_msec()
			s = R.apply(s, _choose(ai, s, a if a_moves else b, ms))
			think[side] = maxi(think[side], Time.get_ticks_msec() - t1)
			if ai.depth_reached > 0:
				depth[side] += ai.depth_reached
				turns[side] += 1
			n += 1
		var tigers_won := R.result(s) == R.TIGERS_WIN
		if tigers_won:
			tiger_wins += 1
		if a_tigers and tigers_won:
			a_tiger_wins += 1
		elif not a_tigers and R.result(s) == R.GOATS_WIN:
			a_goat_wins += 1
		moves += n
		caps += s.captured
	var half := games / 2
	print("%-6s vs %-6s | %-6s won %d/%d as tigers, %d/%d as goats | tigers won %d of %d | avg %d moves, %.1f captures | look-ahead goats %.1f tigers %.1f | longest think %d / %d ms | %ds" % [
		a, b, a, a_tiger_wins, games - half, a_goat_wins, half, tiger_wins, games,
		moves / games, float(caps) / games, float(depth[0]) / maxi(1, turns[0]),
		float(depth[1]) / maxi(1, turns[1]), think[0], think[1], (Time.get_ticks_msec() - t0) / 1000])
