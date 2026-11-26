extends GdUnitTestSuite
## Rule tests for Tiger & Goat (BUILD_PLAN.md task 1.4). Every rule has a test.

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


func _has_move(s: R.State, from: int, to: int, over := R.NONE) -> bool:
	return R.legal_moves(s).has(R.encode(from, to, over))


# ---------- Board ----------

func test_board_has_23_points_and_38_connections() -> void:
	var links := 0
	for p in R.POINT_COUNT:
		links += R.neighbours(p).size()
	assert_int(R.POINTS.size()).is_equal(23)
	assert_int(links / 2).is_equal(38)


func test_every_connection_is_two_way() -> void:
	for p in R.POINT_COUNT:
		for n in R.neighbours(p):
			assert_bool(R.neighbours(n).has(p)).override_failure_message("%d-%d is one-way" % [p, n]).is_true()


func test_top_point_connects_down_the_four_fan_lines() -> void:
	assert_array(Array(R.neighbours(0))).contains_exactly_in_any_order([2, 3, 4, 5])


# ---------- Start ----------

func test_new_game_starts_with_tigers_on_top_and_centre_and_goats_to_place() -> void:
	var s := R.new_game()
	assert_array(Array(s.tigers)).contains_exactly_in_any_order([0, 3, 4])
	assert_int(s.goats).is_equal(0)
	assert_int(s.in_hand).is_equal(15)
	assert_int(s.turn).is_equal(R.GOAT)


func test_goats_move_first_by_placing_on_any_empty_point() -> void:
	var moves := R.legal_moves(R.new_game())
	assert_int(moves.size()).is_equal(20)
	for m in moves:
		assert_int(R.move_from(m)).is_equal(R.NONE)


# ---------- Goats ----------

func test_goats_cannot_move_while_any_are_in_hand() -> void:
	var s := _state([0, 3, 4], [19], 14, R.GOAT)
	for m in R.legal_moves(s):
		assert_int(R.move_from(m)).is_equal(R.NONE)


func test_goats_move_one_step_along_a_line_once_all_are_placed() -> void:
	var s := _state([0, 3, 4], [19], 0, R.GOAT)
	assert_bool(_has_move(s, 19, 20)).is_true()
	assert_bool(_has_move(s, 19, 14)).is_true()
	assert_bool(_has_move(s, 19, 13)).is_false()


func test_goats_never_jump() -> void:
	var s := _state([0, 3, 4], [19, 20], 0, R.GOAT)
	assert_bool(_has_move(s, 19, 21)).is_false()


# ---------- Tigers ----------

func test_tigers_move_from_their_first_turn() -> void:
	var s := R.apply(R.new_game(), R.encode(R.NONE, 19, R.NONE))
	assert_int(s.turn).is_equal(R.TIGER)
	assert_bool(_has_move(s, 0, 2)).is_true()


func test_tiger_jumps_a_goat_to_the_empty_point_beyond_and_captures_it() -> void:
	var s := _state([3, 13, 18], [9], 5, R.TIGER)
	var m := R.encode(3, 15, 9)
	assert_bool(R.legal_moves(s).has(m)).is_true()
	var after := R.apply(s, m)
	assert_bool(R.goat_at(after, 9)).is_false()
	assert_bool(R.tiger_at(after, 15)).is_true()
	assert_int(after.captured).is_equal(1)


func test_tiger_cannot_jump_when_the_landing_point_is_taken() -> void:
	var s := _state([3, 13, 18], [9, 15], 5, R.TIGER)
	assert_bool(_has_move(s, 3, 15, 9)).is_false()


func test_tiger_cannot_jump_another_tiger() -> void:
	var s := _state([3, 9, 18], [], 5, R.TIGER)
	assert_bool(_has_move(s, 3, 15, 9)).is_false()


func test_tiger_cannot_jump_two_goats_or_off_a_line() -> void:
	var s := _state([3, 13, 18], [9, 15], 5, R.TIGER)
	assert_bool(_has_move(s, 3, 20, 9)).is_false()
	# 2, 3, 4 are on one row but 2-9 is not a line, so no jump from 2 over 9.
	var t := _state([2, 13, 18], [9], 5, R.TIGER)
	for m in R.legal_moves(t):
		assert_int(R.move_over(m)).is_not_equal(9)


func test_capturing_is_optional() -> void:
	var s := _state([3, 13, 18], [9], 5, R.TIGER)
	assert_bool(_has_move(s, 3, 2)).is_true()


func test_one_jump_per_turn_then_goats_play() -> void:
	var s := _state([3, 13, 18], [9, 20], 5, R.TIGER)
	var after := R.apply(s, R.encode(3, 15, 9))
	assert_int(after.turn).is_equal(R.GOAT)


# ---------- Winning ----------

func test_tigers_win_exactly_at_the_capture_target() -> void:
	var s := _state([3, 13, 18], [9, 1], 0, R.TIGER, 4)
	assert_int(R.result(s)).is_equal(R.ONGOING)
	var after := R.apply(s, R.encode(3, 15, 9))
	assert_int(after.captured).is_equal(5)
	assert_int(R.result(after)).is_equal(R.TIGERS_WIN)


func test_goats_win_when_no_tiger_can_move() -> void:
	# Tiger alone at 19 boxed in by goats at 14 and 20, with 8 and 21 behind them.
	var s := _state([19, 19, 19], [14, 20, 8, 21], 0, R.TIGER)
	s.tigers = PackedInt32Array([19])
	s.counts = {R.position_key(s): 1}
	assert_int(R.result(s)).is_equal(R.GOATS_WIN)


func test_goats_can_win_during_placement() -> void:
	var s := _state([19], [14, 20, 8, 21], 7, R.TIGER)
	assert_int(R.result(s)).is_equal(R.GOATS_WIN)


func test_tigers_win_when_goats_have_no_legal_move() -> void:
	# Goat at 19 hemmed in by tigers at 14 and 20 and with no other goats.
	var s := _state([14, 20, 0], [19, 8, 21], 0, R.GOAT)
	# 8 and 21 can move, so take them away: only the trapped goat remains.
	s.goats = 1 << 19
	s.counts = {R.position_key(s): 1}
	assert_int(R.result(s)).is_equal(R.TIGERS_WIN)


# ---------- No repeats (D12) ----------

func test_a_move_that_would_repeat_a_position_a_third_time_is_not_allowed() -> void:
	var s := _state([0, 3, 4], [19, 22], 0, R.GOAT)
	var shuffle := [R.encode(19, 20, R.NONE), R.encode(0, 2, R.NONE), R.encode(20, 19, R.NONE), R.encode(2, 0, R.NONE)]
	for m: int in shuffle:  # Back to the start position: it has now occurred twice.
		s = R.apply(s, m)
	assert_int(s.counts[R.position_key(s)]).is_equal(2)
	s = R.apply(s, shuffle[0])
	s = R.apply(s, shuffle[1])
	s = R.apply(s, shuffle[2])
	# Moving the tiger back to 0 would recreate the start position a third time.
	assert_bool(_has_move(s, 2, 0)).is_false()
	assert_bool(_has_move(s, 2, 8)).is_true()  # Any other move is still fine.


# ---------- Invariants and saving ----------

func test_random_games_always_finish_and_keep_all_15_goats_accounted_for() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for g in 150:
		var s := R.new_game()
		var guard := 0
		while R.result(s) == R.ONGOING and guard < 600:
			var moves := R.legal_moves(s)
			s = R.apply(s, moves[rng.randi_range(0, moves.size() - 1)])
			assert_int(R.goats_on_board(s) + s.in_hand + s.captured).is_equal(15)
			guard += 1
		assert_int(R.result(s)).is_not_equal(R.ONGOING)


func test_saving_and_loading_a_state_gives_back_the_same_state() -> void:
	var s := R.new_game()
	for m: int in [R.encode(R.NONE, 19, R.NONE), R.encode(0, 2, R.NONE), R.encode(R.NONE, 20, R.NONE)]:
		s = R.apply(s, m)
	var back := R.from_dict(JSON.parse_string(JSON.stringify(R.to_dict(s))))
	assert_dict(R.to_dict(back)).is_equal(R.to_dict(s))
	assert_array(Array(R.legal_moves(back))).is_equal(Array(R.legal_moves(s)))


# ---------- Holding out (D59) ----------

func test_goats_win_when_tigers_make_40_moves_without_a_capture() -> void:
	var s := _state([0, 3, 4], [19, 22], 0, R.TIGER)
	s.quiet = 39
	assert_int(R.result(s)).is_equal(R.ONGOING)
	var after := R.apply(s, R.encode(0, 2, R.NONE))
	assert_int(after.quiet).is_equal(40)
	assert_bool(R.held(after)).is_true()
	assert_int(R.result(after)).is_equal(R.GOATS_WIN)


func test_a_capture_resets_the_holding_out_count() -> void:
	var s := _state([3, 13, 18], [9], 0, R.TIGER)
	s.quiet = 30
	assert_int(R.apply(s, R.encode(3, 15, 9)).quiet).is_equal(0)


func test_tiger_moves_during_placement_do_not_count() -> void:
	var s := _state([0, 3, 4], [19], 14, R.TIGER)
	assert_int(R.apply(s, R.encode(0, 2, R.NONE)).quiet).is_equal(0)
	assert_int(R.quiet_left(s)).is_equal(-1)


func test_holding_out_count_survives_save_and_load() -> void:
	var s := _state([0, 3, 4], [19], 0, R.TIGER)
	s.quiet = 17
	assert_int(R.from_dict(JSON.parse_string(JSON.stringify(R.to_dict(s)))).quiet).is_equal(17)
