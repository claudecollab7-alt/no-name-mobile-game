extends SceneTree
## Level ladder for the Reversi computer (BUILD_PLAN.md G5.3): each pairing plays half
## its games with each level moving first, so a level's strength shows both ways.
##   godot --headless --path game -s res://tools/reversi_ladder.gd -- --games=20
## --pairs=easy:medium,medium:hard picks the pairings; --ms caps thinking time (0: the
## level's own); --open=4 starts each game with that many random moves, so evenly matched
## levels don't replay the same game; --set=corner:40,mobility:8 overrides scoring weights
## for the first-named level only (A/B tests); "dN" is a fixed look-ahead of N moves;
## "random" plays any legal move; "greedy" the move that flips the most.

const R := preload("res://games/reversi/reversi_rules.gd")

var tuning := {}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	var games := 20
	var ms := 0
	var open := 4
	var pairs := ["easy:greedy", "medium:easy", "hard:medium"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--games="):
			games = int(arg.trim_prefix("--games="))
		elif arg.begins_with("--ms="):
			ms = int(arg.trim_prefix("--ms="))
		elif arg.begins_with("--open="):
			open = int(arg.trim_prefix("--open="))
		elif arg.begins_with("--set="):
			for kv: String in arg.trim_prefix("--set=").split(","):
				tuning[kv.get_slice(":", 0)] = int(kv.get_slice(":", 1))
		elif arg.begins_with("--pairs="):
			pairs = Array(arg.trim_prefix("--pairs=").split(","))
	print("Reversi ladder: %d games per pairing, %d random opening moves, thinking %s %s" % [
		games, open, "capped at %d ms" % ms if ms > 0 else "at each level's own time", tuning])
	for p: String in pairs:
		var lv := p.split(":")
		_match(lv[0], lv[1], games, ms, open)
	quit()


func _choose(ai: ReversiOpponent, s: R.State, level: String, ms: int) -> int:
	if level == "random":
		var moves := R.legal_moves(s)
		return moves[_rng.randi_range(0, moves.size() - 1)]
	if level == "greedy":
		var best := -1
		var most := -1
		for m in R.legal_moves(s):
			var n := 0 if m == R.PASS else R.play(s.copy(), m).size() * 10 + _rng.randi_range(0, 9)
			if n > most:
				most = n
				best = m
		return best
	if level.begins_with("d"):
		return ai.search(s, int(level.substr(1)), ms if ms > 0 else 20000, 0.0, 1)
	return ai.choose_move(s, level, ms)


## Half the games `a` moves first, half second.
func _match(a: String, b: String, games: int, ms: int, open: int) -> void:
	var t0 := Time.get_ticks_msec()
	var ai_a := ReversiOpponent.new(31)
	var ai_b := ReversiOpponent.new(47)
	ai_a.tuning = tuning
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	_rng.seed = 5
	var a_wins := [0, 0]  ## a's wins moving first, moving second
	var b_wins := 0
	var draws := 0
	var margin := 0  ## a's discs less b's, summed
	var depth := [0, 0]  ## a, b: summed look-ahead reached
	var turns := [0, 0]
	var think := [0, 0]  ## a, b: longest think, ms
	var nodes := [0, 0]
	var busy := [0, 0]  ## a, b: total ms thinking
	for g in games:
		var a_first := g % 2 == 0
		var s := R.new_game()
		for i in open:
			var opening := R.legal_moves(s)
			R.play(s, opening[rng.randi_range(0, opening.size() - 1)])
		while R.result(s) == R.ONGOING:
			var a_moves := (s.turn == 0) == a_first
			var ai := ai_a if a_moves else ai_b
			var who := 0 if a_moves else 1
			var t1 := Time.get_ticks_msec()
			ai.nodes = 0
			ai.depth_reached = 0
			var m := _choose(ai, s, a if a_moves else b, ms)
			var took := Time.get_ticks_msec() - t1
			if not R.legal_moves(s).has(m):
				push_error("illegal move %d" % m)
				quit(1)
				return
			R.play(s, m)
			think[who] = maxi(think[who], took)
			busy[who] += took
			nodes[who] += ai.nodes
			if ai.depth_reached > 0:
				depth[who] += ai.depth_reached
				turns[who] += 1
		var res := R.result(s)
		var a_side := 0 if a_first else 1
		margin += R.discs(s, a_side) - R.discs(s, 1 - a_side)
		if res == R.DRAW:
			draws += 1
		elif (res == R.WIN_0) == a_first:
			a_wins[0 if a_first else 1] += 1
		else:
			b_wins += 1
	var half := floori(games / 2.0)
	print("%-6s vs %-6s | %-6s won %d/%d moving first, %d/%d second | %-6s won %d | draws %d | margin %+.1f discs | look-ahead %.1f / %.1f | longest think %d / %d ms | %d / %d nodes a second | %ds" % [
		a, b, a, a_wins[0], games - half, a_wins[1], half, b, b_wins, draws, float(margin) / games,
		float(depth[0]) / maxi(1, turns[0]), float(depth[1]) / maxi(1, turns[1]), think[0], think[1],
		floori(nodes[0] * 1000.0 / maxi(1, busy[0])), floori(nodes[1] * 1000.0 / maxi(1, busy[1])), floori((Time.get_ticks_msec() - t0) / 1000.0)])
