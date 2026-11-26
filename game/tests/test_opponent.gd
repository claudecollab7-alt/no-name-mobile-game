extends GdUnitTestSuite
## The computer opponent (BUILD_PLAN.md tasks 2.1-2.3).

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")


func _state(tigers: Array, goats: Array, in_hand: int, turn: int, captured := 0) -> R.State:
	var s := R.new_game()
	s.tigers = PackedInt32Array(tigers)
	s.goats = 0
	for p: int in goats:
		s.goats |= 1 << p
	s.in_hand = in_hand
	s.turn = turn
	s.captured = captured
	s.counts = {R.position_key(s): 1}
	return s


func test_every_level_always_returns_a_legal_move() -> void:
	var ai := AadupuliOpponent.new(1)
	var s := R.new_game()
	for i in 30:
		if R.result(s) != R.ONGOING:
			break
		var level: String = ["easy", "medium", "hard"][i % 3]
		var m := ai.choose_move(s, level, 150)
		assert_bool(R.legal_moves(s).has(m)).is_true()
		s = R.apply(s, m)


func test_tiger_takes_the_winning_capture() -> void:
	var ai := AadupuliOpponent.new(2)
	var s := _state([3, 13, 18], [9, 1], 0, R.TIGER, 4)
	assert_int(ai.choose_move(s, "easy")).is_equal(R.encode(3, 15, 9))


func test_goats_close_the_last_gap_to_win() -> void:
	# Tiger alone at 19 can only escape to 20; goats can fill 20 from 21? No: from 15.
	var ai := AadupuliOpponent.new(3)
	var s := _state([19], [14, 8, 15, 21, 16], 0, R.GOAT)
	var m := ai.choose_move(s, "medium")
	var after := R.apply(s, m)
	assert_int(R.result(after)).is_equal(R.GOATS_WIN)


func test_scoring_prefers_safe_goats_to_exposed_ones() -> void:
	var ai := AadupuliOpponent.new(4)
	var exposed := _state([0, 3, 4], [9], 14, R.TIGER)  # Goat at 9 can be jumped from 3.
	var safe := _state([0, 3, 4], [19], 14, R.TIGER)
	assert_int(ai.evaluate_for_tigers(exposed)).is_greater(ai.evaluate_for_tigers(safe))


func test_medium_beats_a_random_player_from_both_sides() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var ai := AadupuliOpponent.new(5)
	var wins := 0
	var games := 8
	for g in games:
		var ai_side := R.TIGER if g % 2 == 0 else R.GOAT
		var s := R.new_game()
		var moves_played := 0
		while R.result(s) == R.ONGOING and moves_played < 300:
			var m: int
			if s.turn == ai_side:
				m = ai.search(s, 3, 400)
			else:
				var legal := R.legal_moves(s)
				m = legal[rng.randi_range(0, legal.size() - 1)]
			s = R.apply(s, m)
			moves_played += 1
		var res := R.result(s)
		if (res == R.TIGERS_WIN and ai_side == R.TIGER) or (res == R.GOATS_WIN and ai_side == R.GOAT):
			wins += 1
	assert_int(wins).is_equal(games)
