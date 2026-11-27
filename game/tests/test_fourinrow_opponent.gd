extends GdUnitTestSuite
## The Four in a Row computer (BUILD_PLAN.md G4.3, D71): legal moves at every level,
## wins taken, threats blocked, traps avoided and set, and quick enough to play.

const F := preload("res://games/fourinrow/four_rules.gd")


## Columns of discs from the bottom up (0 first player, 1 second); `turn` to move.
func _pos(columns: Array, turn: int) -> F.State:
	return F.from_dict({"columns": columns, "turn": turn})


func test_every_level_plays_a_legal_move() -> void:
	var ai := FourOpponent.new(3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for level in ["easy", "medium", "hard"]:
		var s := F.new_game()
		for i in 10:
			var m := ai.choose_move(s, level, 300)
			assert_bool(F.legal_moves(s).has(m)).override_failure_message("%s played %d" % [level, m]).is_true()
			F.drop(s, m)
			if F.result(s) != F.ONGOING:
				break
			var moves := F.legal_moves(s)
			F.drop(s, moves[rng.randi_range(0, moves.size() - 1)])
			if F.result(s) != F.ONGOING:
				break


func test_threat_spaces_are_found_in_every_direction() -> void:
	FourOpponent.new(1)
	var s := _pos([[0], [0], [0], [], [], [], []], 1)  # Three across the bottom.
	var mask: int = s.bits[0] | s.bits[1]
	assert_int(FourOpponent.winning_spaces(s.bits[0], mask)).is_equal(F.bit(3, 0))
	var up := _pos([[0, 0, 0], [], [], [], [], [], []], 1)
	assert_int(FourOpponent.winning_spaces(up.bits[0], up.bits[0])).is_equal(F.bit(0, 3))
	# A diagonal with its gap in the middle: (0,0) (1,1) _ (3,3).
	var diag := _pos([[0], [1, 0], [1, 1], [1, 1, 1, 0], [], [], []], 1)
	var dmask: int = diag.bits[0] | diag.bits[1]
	assert_int(FourOpponent.winning_spaces(diag.bits[0], dmask) & F.bit(2, 2)).is_equal(F.bit(2, 2))


func test_every_level_takes_a_win_that_is_there() -> void:
	var s := _pos([[0], [0], [0], [], [], [1, 1], [1]], 0)
	for level in ["easy", "medium", "hard"]:
		for seed_value in [1, 2, 3, 4, 5]:
			assert_int(FourOpponent.new(seed_value).choose_move(s, level)).override_failure_message(level).is_equal(3)


func test_medium_and_hard_block_a_win_that_is_coming() -> void:
	# Second player has three up column 5; first player must block on top.
	var s := _pos([[0], [0], [], [], [], [1, 1, 1], []], 0)
	for level in ["medium", "hard"]:
		for seed_value in [1, 2, 3]:
			assert_int(FourOpponent.new(seed_value).choose_move(s, level)).override_failure_message(level).is_equal(5)


func test_hard_never_drops_a_disc_under_the_opponents_winning_space() -> void:
	# Second player has (1,1) (2,1) (3,1) and threatens (4,1): first player must not
	# fill (4,0) below it and hand it over.
	var s := _pos([[0, 0], [0, 1], [0, 1], [1, 1], [], [], []], 0)
	var mask: int = s.bits[0] | s.bits[1]
	FourOpponent.new(1)
	assert_int(FourOpponent.winning_spaces(s.bits[1], mask) & F.bit(4, 1)).is_equal(F.bit(4, 1))
	for seed_value in [1, 2, 3]:
		assert_int(FourOpponent.new(seed_value).choose_move(s, "hard")).is_not_equal(4)


func test_hard_sets_up_two_threats_at_once() -> void:
	# First player has (2,0) (3,0) with open ends: 1 or 4 makes a three both ends can complete.
	var s := _pos([[], [], [0, 1], [0, 1], [], [], []], 0)
	for seed_value in [1, 2, 3]:
		assert_bool(FourOpponent.new(seed_value).choose_move(s, "hard") in [1, 4]).is_true()


func test_an_open_three_scores_better_than_nothing() -> void:
	var ai := FourOpponent.new(1)
	var s := _pos([[], [0], [0], [0], [], [1, 1], [1]], 0)
	var mask: int = s.bits[0] | s.bits[1]
	assert_int(ai.evaluate(s.bits[0], mask)).is_greater(0)
	assert_int(ai.evaluate(s.bits[1], mask)).is_less(0)


func test_hard_answers_within_its_time() -> void:
	var ai := FourOpponent.new(1)
	var s := F.new_game()
	F.drop(s, 3)
	var t := Time.get_ticks_msec()
	ai.choose_move(s, "hard")
	assert_int(Time.get_ticks_msec() - t).is_less(1700)
	assert_int(ai.depth_reached).is_greater_equal(6)


func test_medium_beats_a_random_player_moving_first_or_second() -> void:
	var ai := FourOpponent.new(5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for g in 6:
		var ai_first := g % 2 == 0
		var s := F.new_game()
		while F.result(s) == F.ONGOING:
			if (s.turn == 0) == ai_first:
				F.drop(s, ai.choose_move(s, "medium", 300))
			else:
				var moves := F.legal_moves(s)
				F.drop(s, moves[rng.randi_range(0, moves.size() - 1)])
		assert_int(F.result(s)).is_equal(F.WIN_0 if ai_first else F.WIN_1)
