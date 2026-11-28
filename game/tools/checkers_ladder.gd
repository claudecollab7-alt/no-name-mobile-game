extends SceneTree
## Level ladder for the Checkers computer (BUILD_PLAN.md G6.3): each pairing plays half
## its games with each level moving first, so a level's strength shows both ways.
##   godot --headless --path game -s res://tools/checkers_ladder.gd -- --games=20 --variant=english
## --pairs=easy:medium,medium:hard picks the pairings; --ms caps thinking time (0: the
## level's own); --open=2 starts each game with that many random moves; --set=king:180
## overrides scoring weights for the first-named level only (A/B tests); "dN" is a fixed
## look-ahead of N moves; "random" plays any legal move; "greedy" takes the most pieces.

const C := preload("res://games/checkers/checkers_rules.gd")

var tuning := {}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	var games := 20
	var ms := 0
	var open := 2
	var variants := [C.ENGLISH, C.INTERNATIONAL]
	var pairs := ["easy:greedy", "medium:easy", "hard:medium"]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--games="):
			games = int(arg.trim_prefix("--games="))
		elif arg.begins_with("--ms="):
			ms = int(arg.trim_prefix("--ms="))
		elif arg.begins_with("--open="):
			open = int(arg.trim_prefix("--open="))
		elif arg.begins_with("--variant="):
			variants = [arg.trim_prefix("--variant=")]
		elif arg.begins_with("--set="):
			for kv: String in arg.trim_prefix("--set=").split(","):
				tuning[kv.get_slice(":", 0)] = int(kv.get_slice(":", 1))
		elif arg.begins_with("--pairs="):
			pairs = Array(arg.trim_prefix("--pairs=").split(","))
	print("Checkers ladder: %d games per pairing, %d random opening moves, thinking %s %s" % [
		games, open, "capped at %d ms" % ms if ms > 0 else "at each level's own time", tuning])
	for v: String in variants:
		for p: String in pairs:
			var lv := p.split(":")
			_match(v, lv[0], lv[1], games, ms, open)
	quit()


func _choose(ai: CheckersOpponent, s: C.State, level: String, ms: int) -> PackedInt32Array:
	var moves := C.legal_moves(s)
	if level == "random":
		return (moves[_rng.randi_range(0, moves.size() - 1)] as C.Move).path
	if level == "greedy":
		var most := -1
		var pick: Array = []
		for m: C.Move in moves:
			if m.captured.size() > most:
				most = m.captured.size()
				pick = [m]
			elif m.captured.size() == most:
				pick.append(m)
		return (pick[_rng.randi_range(0, pick.size() - 1)] as C.Move).path
	if level.begins_with("d"):
		return ai.search(s, int(level.substr(1)), ms if ms > 0 else 20000, 0.0, 1)
	return ai.choose_move(s, level, ms)


## Half the games `a` moves first, half second.
func _match(variant: String, a: String, b: String, games: int, ms: int, open: int) -> void:
	var t0 := Time.get_ticks_msec()
	var ai_a := CheckersOpponent.new(31)
	var ai_b := CheckersOpponent.new(47)
	ai_a.tuning = tuning
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	_rng.seed = 5
	var a_wins := [0, 0]  ## a's wins moving first, moving second
	var b_wins := 0
	var draws := 0
	var reasons := {}
	var moves_total := 0
	var depth := [0, 0]
	var turns := [0, 0]
	var think := [0, 0]
	var nodes := [0, 0]
	var busy := [0, 0]
	for g in games:
		var a_first := g % 2 == 0
		var s := C.new_game(variant)
		for i in open:
			var opening := C.legal_moves(s)
			C.play(s, opening[rng.randi_range(0, opening.size() - 1)])
		while C.result(s) == C.ONGOING:
			var a_moves := (s.turn == 0) == a_first
			var ai := ai_a if a_moves else ai_b
			var who := 0 if a_moves else 1
			var t1 := Time.get_ticks_msec()
			ai.nodes = 0
			ai.depth_reached = 0
			var path := _choose(ai, s, a if a_moves else b, ms)
			var took := Time.get_ticks_msec() - t1
			var m := C.find_move(s, path)
			if m == null:
				push_error("illegal move %s" % path)
				quit(1)
				return
			C.play(s, m)
			think[who] = maxi(think[who], took)
			busy[who] += took
			nodes[who] += ai.nodes
			if ai.depth_reached > 0:
				depth[who] += ai.depth_reached
				turns[who] += 1
		var res := C.result(s)
		reasons[C.reason(s)] = int(reasons.get(C.reason(s), 0)) + 1
		moves_total += s.moves_played
		if res == C.DRAW:
			draws += 1
		elif (res == C.WIN_0) == a_first:
			a_wins[0 if a_first else 1] += 1
		else:
			b_wins += 1
	var half := floori(games / 2.0)
	print("%-13s %-6s vs %-6s | %-6s won %d/%d first, %d/%d second | %-6s won %d | draws %d %s | avg %d moves | look-ahead %.1f / %.1f | longest think %d / %d ms | %d / %d nodes a second | %ds" % [
		variant, a, b, a, a_wins[0], games - half, a_wins[1], half, b, b_wins, draws, reasons,
		floori(moves_total / float(games)), float(depth[0]) / maxi(1, turns[0]), float(depth[1]) / maxi(1, turns[1]),
		think[0], think[1], floori(nodes[0] * 1000.0 / maxi(1, busy[0])), floori(nodes[1] * 1000.0 / maxi(1, busy[1])),
		floori((Time.get_ticks_msec() - t0) / 1000.0)])
