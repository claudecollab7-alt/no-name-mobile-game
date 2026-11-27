extends SceneTree
## Level ladder for the Four in a Row computer (BUILD_PLAN.md G4.3): each pairing plays
## half its games with each level moving first, so a level's strength shows both ways.
##   godot --headless --path game -s res://tools/four_ladder.gd -- --games=20
## --pairs=easy:medium,medium:hard picks the pairings; --ms caps thinking time (0: the
## level's own); --open=2 starts each game with that many random moves, so evenly matched
## levels don't replay the same game; --set=threat:50,parity:20 overrides scoring weights
## for the first-named level only (A/B tests); "dN" is a fixed look-ahead of N moves.

const F := preload("res://games/fourinrow/four_rules.gd")

var tuning := {}


func _init() -> void:
	var games := 20
	var ms := 0
	var open := 2
	var pairs := ["easy:easy", "medium:medium", "hard:hard", "medium:easy", "hard:medium"]
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
	print("Four in a Row ladder: %d games per pairing, %d random opening moves, thinking %s %s" % [
		games, open, "capped at %d ms" % ms if ms > 0 else "at each level's own time", tuning])
	for p: String in pairs:
		var lv := p.split(":")
		_match(lv[0], lv[1], games, ms, open)
	quit()


func _choose(ai: FourOpponent, s: F.State, level: String, ms: int) -> int:
	if level.begins_with("d"):
		return ai.search(s, int(level.substr(1)), ms if ms > 0 else 10000, 0.0, 1)
	return ai.choose_move(s, level, ms)


## Half the games `a` moves first, half second.
func _match(a: String, b: String, games: int, ms: int, open: int) -> void:
	var t0 := Time.get_ticks_msec()
	var ai_a := FourOpponent.new(31)
	var ai_b := FourOpponent.new(47)
	ai_a.tuning = tuning
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var a_wins := [0, 0]  ## a's wins moving first, moving second
	var b_wins := [0, 0]
	var draws := 0
	var first_wins := 0
	var moves := 0
	var depth := [0, 0]  ## a, b: summed look-ahead reached
	var turns := [0, 0]
	var think := [0, 0]  ## a, b: longest think, ms
	for g in games:
		var a_first := g % 2 == 0
		var s := F.new_game()
		for i in open:
			var opening := F.legal_moves(s)
			F.drop(s, opening[rng.randi_range(0, opening.size() - 1)])
		while F.result(s) == F.ONGOING:
			var a_moves := (s.turn == 0) == a_first
			var ai := ai_a if a_moves else ai_b
			var who := 0 if a_moves else 1
			var t1 := Time.get_ticks_msec()
			F.drop(s, _choose(ai, s, a if a_moves else b, ms))
			think[who] = maxi(think[who], Time.get_ticks_msec() - t1)
			if ai.depth_reached > 0:
				depth[who] += ai.depth_reached
				turns[who] += 1
		var res := F.result(s)
		moves += s.moves_played
		if res == F.DRAW:
			draws += 1
			continue
		var first_won := res == F.WIN_0
		if first_won:
			first_wins += 1
		if first_won == a_first:
			a_wins[0 if a_first else 1] += 1
		else:
			b_wins[1 if a_first else 0] += 1
	var half := games / 2
	print("%-6s vs %-6s | %-6s won %d/%d moving first, %d/%d second | %-6s won %d | draws %d | first player won %d of %d | avg %d moves | look-ahead %.1f / %.1f | longest think %d / %d ms | %ds" % [
		a, b, a, a_wins[0], games - half, a_wins[1], half, b, b_wins[0] + b_wins[1], draws, first_wins, games,
		moves / maxi(1, games), float(depth[0]) / maxi(1, turns[0]), float(depth[1]) / maxi(1, turns[1]),
		think[0], think[1], (Time.get_ticks_msec() - t0) / 1000])
