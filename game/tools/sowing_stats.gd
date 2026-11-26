extends SceneTree
## Quick balance check for the sowing games: game length, first-player advantage,
## draws, and how often relay sowing hits the safety stop. Two kinds of players:
## random, and greedy (takes the move that gains the most seeds right now).
##   godot --headless --path game -s res://tools/sowing_stats.gd -- --games=1000

const S := preload("res://games/sowing/sowing_rules.gd")


func _init() -> void:
	var games := 1000
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--games="):
			games = int(arg.trim_prefix("--games="))
	print("game        | players | first wins | second wins | draws | avg moves | longest | safety stops")
	for game: Dictionary in [S.KALAH, S.PALLANGUZHI]:
		for kind in ["random", "greedy"]:
			_run(game, kind, games)
	quit()


func _run(game: Dictionary, kind: String, games: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var first := 0
	var second := 0
	var draws := 0
	var total_moves := 0
	var longest := 0
	var stops := 0
	for g in games:
		var s := S.new_game(game, 0)
		var n := 0
		while not s.over and n < 2000:
			var moves := S.legal_moves(s)
			var m: int = moves[rng.randi_range(0, moves.size() - 1)]
			if kind == "greedy":
				m = _greedy(s, moves, rng)
			var r := S.apply(s, m)
			var drops: int = (r[1] as Array).filter(func(st: Array) -> bool: return st[0] == S.DROP).size()
			if drops >= S.MAX_DROPS:
				stops += 1
			s = r[0]
			n += 1
		total_moves += n
		longest = maxi(longest, n)
		match S.result(s):
			S.WIN_0: first += 1
			S.WIN_1: second += 1
			_: draws += 1
	print("%-11s | %-7s | %9.0f%% | %10.0f%% | %4.0f%% | %9.0f | %7d | %d" % [
		game["id"], kind, 100.0 * first / games, 100.0 * second / games, 100.0 * draws / games,
		float(total_moves) / games, longest, stops])


func _greedy(s: S.State, moves: PackedInt32Array, rng: RandomNumberGenerator) -> int:
	var me := s.turn
	var best := -1000
	var choice: Array = []
	for m in moves:
		var a := S.after(s, m)
		var gain := a.stores[me] - s.stores[me] + (3 if a.turn == me and not a.over else 0)
		if gain > best:
			best = gain
			choice = [m]
		elif gain == best:
			choice.append(m)
	return choice[rng.randi_range(0, choice.size() - 1)]
