extends GdUnitTestSuite
## The computer opponent on Bagh-Chal (BUILD_PLAN.md G3.3, DISCUSSION.md section 30).

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")


func _bagh(tigers: Array, goats: Array, in_hand: int, turn: int, captured := 0) -> R.State:
	var s := R.new_game({"board": "baghchal"})
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
	var s := R.new_game({"board": "baghchal"})
	for i in 30:
		if R.result(s) != R.ONGOING:
			break
		var level: String = ["easy", "medium", "hard"][i % 3]
		var m := ai.choose_move(s, level, 150)
		assert_bool(R.legal_moves(s).has(m)).is_true()
		s = R.apply(s, m)


func test_even_a_one_move_look_ahead_never_places_a_goat_into_a_jump() -> void:
	# Next to a corner tiger with the point beyond empty: the tiger would jump it at once.
	var unsafe := [1, 5, 6, 3, 9, 8, 15, 21, 16, 23, 19, 18]
	for seed_value in range(1, 11):
		var ai := AadupuliOpponent.new(seed_value)
		var m := ai.search(R.new_game({"board": "baghchal"}), 1, 500)
		assert_bool(R.move_to(m) in unsafe).is_false()


func test_tiger_takes_the_winning_fifth_goat() -> void:
	var ai := AadupuliOpponent.new(2)
	var s := _bagh([0, 4, 20, 24], [1, 13, 17], 0, R.TIGER, 4)
	assert_int(ai.choose_move(s, "easy")).is_equal(R.encode(0, 2, 1))


func test_goats_close_the_last_gap_to_trap_the_tigers() -> void:
	# A lone tiger in the corner; the goat stepping 7 -> 6 leaves it no move or jump.
	var ai := AadupuliOpponent.new(3)
	var s := _bagh([0], [1, 2, 5, 10, 12, 7], 0, R.GOAT)
	var after := R.apply(s, ai.choose_move(s, "medium"))
	assert_int(R.result(after)).is_equal(R.GOATS_WIN)


func test_goats_on_the_edge_score_safer_than_goats_in_the_middle() -> void:
	var ai := AadupuliOpponent.new(4)
	var edge := _bagh([0, 4, 20, 24], [2, 10, 14, 22], 16, R.TIGER)
	var middle := _bagh([0, 4, 20, 24], [7, 11, 13, 17], 16, R.TIGER)
	assert_int(ai.evaluate_for_tigers(edge)).is_less(ai.evaluate_for_tigers(middle))


func test_medium_beats_a_random_player_from_both_sides() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var ai := AadupuliOpponent.new(5)
	var wins := 0
	var games := 4
	for g in games:
		var ai_side := R.TIGER if g % 2 == 0 else R.GOAT
		var s := R.new_game({"board": "baghchal"})
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
