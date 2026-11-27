extends GdUnitTestSuite
## Bagh-Chal rules on the shared tiger engine (DISCUSSION.md section 30).

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


func _has_capture_over(s: R.State, over: int) -> bool:
	for m in R.legal_moves(s):
		if R.move_over(m) == over:
			return true
	return false


func test_the_game_starts_with_four_corner_tigers_and_twenty_goats_to_place() -> void:
	var s := R.new_game({"board": "baghchal"})
	assert_int(R.point_count(s)).is_equal(25)
	assert_array(Array(s.tigers)).is_equal([0, 4, 20, 24])
	assert_int(s.in_hand).is_equal(20)
	assert_int(s.turn).is_equal(R.GOAT)
	assert_int(R.legal_moves(s).size()).is_equal(21)  # Any empty point.


func test_diagonals_run_through_every_other_point_only() -> void:
	assert_array(Array(R.neighbours(12, "baghchal"))).contains_exactly_in_any_order([7, 11, 13, 17, 6, 8, 16, 18])
	assert_array(Array(R.neighbours(0, "baghchal"))).contains_exactly_in_any_order([1, 5, 6])
	assert_array(Array(R.neighbours(2, "baghchal"))).contains_exactly_in_any_order([1, 3, 7, 6, 8])
	assert_array(Array(R.neighbours(5, "baghchal"))).contains_exactly_in_any_order([0, 6, 10])  # No diagonal here.
	assert_array(Array(R.neighbours(7, "baghchal"))).contains_exactly_in_any_order([2, 6, 8, 12])
	var links := 0
	for p in 25:
		links += R.neighbours(p, "baghchal").size()
		for n in R.neighbours(p, "baghchal"):
			assert_bool(R.neighbours(n, "baghchal").has(p)).is_true()
	assert_int(links / 2).is_equal(56)  # 40 along rows and columns, 16 diagonal.


func test_tigers_jump_a_goat_along_any_line_and_may_do_so_while_goats_are_placed() -> void:
	var s := _bagh([0, 4, 20, 24], [6], 19, R.TIGER)
	assert_bool(R.legal_moves(s).has(R.encode(0, 12, 6))).is_true()  # Diagonal jump.
	var after := R.apply(s, R.encode(0, 12, 6))
	assert_int(after.captured).is_equal(1)
	assert_bool(R.goat_at(after, 6)).is_false()


func test_a_goat_in_a_corner_can_never_be_jumped() -> void:
	var s := _bagh([1, 5, 6, 24], [0], 19, R.TIGER)
	assert_bool(_has_capture_over(s, 0)).is_false()


func test_no_diagonal_jump_through_a_point_without_diagonals() -> void:
	# Tiger on 1, goat on 7 (no diagonal links 1 and 7), point 13 empty: no jump.
	var s := _bagh([1, 20, 24, 4], [7], 19, R.TIGER)
	assert_bool(_has_capture_over(s, 7)).is_false()


func test_tigers_win_with_five_captures_and_goats_win_by_blocking_every_tiger() -> void:
	var s := _bagh([0, 4, 20, 24], [6], 15, R.TIGER, 4)
	assert_int(R.result(R.apply(s, R.encode(0, 12, 6)))).is_equal(R.TIGERS_WIN)
	# Every tiger is boxed in: each corner's neighbours and jump landings are full.
	var goats := [1, 2, 5, 10, 6, 12, 3, 9, 8, 14, 15, 21, 16, 22, 19, 23, 18]
	var blocked := _bagh([0, 4, 20, 24], goats, 0, R.TIGER)
	assert_int(R.result(blocked)).is_equal(R.GOATS_WIN)


func test_once_all_goats_are_placed_a_move_back_to_an_earlier_position_is_not_allowed() -> void:
	var s := _bagh([0, 4, 20, 24], [7, 11, 13, 17], 0, R.GOAT)
	var step := R.encode(7, 12, R.NONE)
	assert_bool(R.legal_moves(s).has(step)).is_true()
	s.counts[R.position_key(R.apply(s, step, false))] = 1  # That position happened before.
	assert_bool(R.legal_moves(s).has(step)).is_false()  # D66: once is enough.


func test_in_real_play_no_position_ever_comes_back_after_placement() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var s := R.new_game({"board": "baghchal"})
	var after_placing := 0
	while R.result(s) == R.ONGOING and after_placing < 60:
		var moves := R.legal_moves(s)
		if s.in_hand == 0:
			after_placing += 1
			for m in moves:
				assert_bool(s.counts.has(R.position_key(R.apply(s, m, false)))).is_false()
		s = R.apply(s, moves[rng.randi_range(0, moves.size() - 1)])


func test_tiger_and_goat_keeps_its_own_rules() -> void:
	var s := R.new_game()
	assert_str(s.board).is_equal("aadupuli")
	assert_int(R.point_count(s)).is_equal(23)
	assert_int(s.repeat_limit).is_equal(3)
	assert_int(s.quiet_limit).is_equal(40)


func test_saving_and_loading_keeps_the_board() -> void:
	var s := R.apply(R.new_game({"board": "baghchal"}), R.encode(R.NONE, 12, R.NONE))
	var back := R.from_dict(JSON.parse_string(JSON.stringify(R.to_dict(s))))
	assert_str(back.board).is_equal("baghchal")
	assert_int(R.position_key(back)).is_equal(R.position_key(s))


func test_random_bagh_chal_games_always_end() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for g in 40:
		var s := R.new_game({"board": "baghchal"})
		var guard := 0
		while R.result(s) == R.ONGOING and guard < 3000:
			var moves := R.legal_moves(s)
			s = R.apply(s, moves[rng.randi_range(0, moves.size() - 1)])
			guard += 1
		assert_int(R.result(s)).override_failure_message("game %d did not end" % g).is_not_equal(R.ONGOING)
