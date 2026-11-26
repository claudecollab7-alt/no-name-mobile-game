extends SceneTree
## Level ladder and first-move edge for the sowing opponent, plus how deep "hard" sees.
##   godot --headless --path game -s res://tools/sowing_self_play.gd -- --games=12 --ms=250
## Players swap sides and who moves first every game.

const S := preload("res://games/sowing/sowing_rules.gd")
const AI := preload("res://games/sowing/ai/sowing_opponent.gd")


func _init() -> void:
	var games := 12
	var ms := 250
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--games="):
			games = int(arg.trim_prefix("--games="))
		elif arg.begins_with("--ms="):
			ms = int(arg.trim_prefix("--ms="))
	for game: Dictionary in [S.KALAH, S.PALLANGUZHI]:
		for cap in [1200, 700]:
			var ai := AI.new(11)  # Fresh each time: a remembered search would look instant.
			var t0 := Time.get_ticks_msec()
			ai.choose_move(S.new_game(game), "hard", cap)
			print("%s hard at the start, %d ms: depth %d, %d positions, %d ms" % [game["id"], cap, ai.depth_reached, ai.nodes, Time.get_ticks_msec() - t0])
		_match(game, "easy", "medium", games, ms)
		_match(game, "medium", "hard", games, ms)
		_match(game, "hard", "hard", games, ms)
	quit()


func _match(game: Dictionary, a: String, b: String, games: int, ms: int) -> void:
	var ai := AI.new(21)
	var a_wins := 0
	var b_wins := 0
	var draws := 0
	var first_wins := 0
	var margin := 0
	for g in games:
		var a_side := g % 2
		var first := (g / 2) % 2
		var s := S.new_game(game, first)
		while not s.over:
			var level := a if s.turn == a_side else b
			s = S.after(s, ai.choose_move(s, level, ms))
		var r := S.result(s)
		if r == S.DRAW:
			draws += 1
		elif (r == S.WIN_0) == (a_side == 0):
			a_wins += 1
		else:
			b_wins += 1
		if (r == S.WIN_0 and first == 0) or (r == S.WIN_1 and first == 1):
			first_wins += 1
		margin += absi(s.stores[0] - s.stores[1])
	print("%-11s %-6s vs %-6s: %2d - %2d, %d draws | first player won %d of %d | average margin %.1f" % [
		game["id"], a, b, a_wins, b_wins, draws, first_wins, games, float(margin) / games])
