extends GdUnitTestSuite
## The computer opponent for Mancala (Kalah) and Pallanguzhi.

const S := preload("res://games/sowing/sowing_rules.gd")


func _random_game_vs(ai: SowingOpponent, game: Dictionary, level: String, ai_side: int, rng: RandomNumberGenerator, first: int) -> int:
	var s := S.new_game(game, first)
	while not s.over:
		var moves := S.legal_moves(s)
		var m: int
		if s.turn == ai_side:
			m = ai.choose_move(s, level, 120)
		else:
			m = moves[rng.randi_range(0, moves.size() - 1)]
		s = S.after(s, m)
	return S.result(s)


func test_every_level_always_returns_a_legal_move_in_both_games() -> void:
	var ai := SowingOpponent.new(1)
	for game: Dictionary in [S.KALAH, S.PALLANGUZHI]:
		var s := S.new_game(game)
		var i := 0
		while not s.over and i < 40:
			var level: String = ["easy", "medium", "hard"][i % 3]
			var m := ai.choose_move(s, level, 100)
			assert_bool(S.legal_moves(s).has(m)).is_true()
			s = S.after(s, m)
			i += 1


func test_kalah_takes_the_capture_that_wins_the_game() -> void:
	# Pit 0's seed lands in empty pit 1 and takes pit 10's five: 26 of 48 wins.
	# Pit 3 also captures, but only three seeds.
	var s := S.new_game(S.KALAH)
	s.pits = PackedInt32Array([1, 0, 0, 1, 0, 0, 2, 2, 2, 2, 5, 2])
	s.stores = PackedInt32Array([20, 11])
	var ai := SowingOpponent.new(2)
	assert_int(ai.choose_move(s, "easy")).is_equal(0)


func test_kalah_uses_an_extra_turn_to_set_up_the_win() -> void:
	# Pit 5's single seed lands in the store (19) for another turn; then pit 0 captures
	# six more: 25 of 48 wins. Capturing first only reaches 24, which is not yet a win.
	var s := S.new_game(S.KALAH)
	s.pits = PackedInt32Array([1, 0, 0, 0, 0, 1, 2, 2, 2, 2, 5, 2])
	s.stores = PackedInt32Array([18, 13])
	var ai := SowingOpponent.new(3)
	assert_int(ai.choose_move(s, "easy")).is_equal(5)


func test_scoring_counts_won_seeds_most() -> void:
	var ai := SowingOpponent.new(4)
	var s := S.new_game(S.KALAH)
	var ahead := s.copy()
	ahead.stores = PackedInt32Array([4, 0])
	ahead.pits[5] = 0
	assert_int(ai.evaluate(ahead)).is_greater(ai.evaluate(s))


func test_medium_beats_a_random_player_from_both_sides() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var ai := SowingOpponent.new(5)
	for game: Dictionary in [S.KALAH, S.PALLANGUZHI]:
		var wins := 0
		for g in 6:
			var side := g % 2
			var r := _random_game_vs(ai, game, "medium", side, rng, (g / 2) % 2)
			if r == (S.WIN_0 if side == 0 else S.WIN_1):
				wins += 1
		assert_int(wins).override_failure_message("%s: medium won %d of 6" % [game["id"], wins]).is_greater_equal(5)
