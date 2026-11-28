extends GdUnitTestSuite
## The Reversi computer (BUILD_PLAN.md G5.3): its quick move finder agrees with the rules,
## legal moves at every level, corners taken, corners not given away, passing, a won
## ending played out perfectly, and quick enough to play.

const R := preload("res://games/reversi/reversi_rules.gd")


## Rows from the TOP down, as they read on screen.
func _pos(top_down: Array, turn := 0) -> R.State:
	var rows := top_down.duplicate()
	rows.reverse()
	return R.from_dict({"rows": rows, "turn": turn})


func test_the_quick_move_finder_agrees_with_the_rules() -> void:
	ReversiOpponent.new(1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var checked := 0
	for g in 30:
		var s := R.new_game()
		while R.result(s) == R.ONGOING:
			var me: int = s.bits[s.turn]
			var opp: int = s.bits[1 - s.turn]
			assert_int(ReversiOpponent.moves(me, opp)).is_equal(R.moves_mask(me, opp))
			assert_int(ReversiOpponent.pop(me | opp)).is_equal(R.count(me | opp))
			var legal := R.legal_moves(s)
			var m: int = legal[rng.randi_range(0, legal.size() - 1)]
			if m != R.PASS:
				assert_int(ReversiOpponent.flips(me, opp, 1 << m)).is_equal(R.flips_mask(me, opp, 1 << m))
				checked += 1
			R.play(s, m)
	assert_int(checked).is_greater(1000)
	# The sign bit counts like any other.
	assert_int(ReversiOpponent.pop(1 << 63)).is_equal(1)
	assert_int(ReversiOpponent.pop(-1)).is_equal(64)


func test_every_level_plays_a_legal_move() -> void:
	var ai := ReversiOpponent.new(3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for level in ["easy", "medium", "hard"]:
		var s := R.new_game()
		for i in 8:
			if R.result(s) != R.ONGOING:
				break
			var m := ai.choose_move(s, level, 200)
			assert_bool(R.legal_moves(s).has(m)).override_failure_message("%s played %d" % [level, m]).is_true()
			R.play(s, m)
			if R.result(s) != R.ONGOING:
				break
			var moves := R.legal_moves(s)
			R.play(s, moves[rng.randi_range(0, moves.size() - 1)])


func test_medium_and_hard_take_a_corner_that_is_offered() -> void:
	# Orange can take the bottom-left corner (0,0) through the cream diagonal.
	var s := _pos([
		"........",
		"........",
		"........",
		"...0....",
		"...01...",
		"..10....",
		".1......",
		"........",
	])
	assert_bool(R.legal_moves(s).has(0)).is_true()
	for level in ["medium", "hard"]:
		for seed_value in [1, 2, 3]:
			assert_int(ReversiOpponent.new(seed_value).choose_move(s, level)).override_failure_message(level).is_equal(0)


func test_hard_does_not_hand_over_a_corner() -> void:
	# After some random opening moves, Hard never plays the square diagonally next to an
	# empty corner when it has other moves.
	var x_squares := [R.cell(1, 1), R.cell(6, 1), R.cell(1, 6), R.cell(6, 6)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var ai := ReversiOpponent.new(5)
	for g in 6:
		var s := R.new_game()
		for i in 10:
			var moves := R.legal_moves(s)
			R.play(s, moves[rng.randi_range(0, moves.size() - 1)])
		if R.result(s) != R.ONGOING or R.legal_moves(s)[0] == R.PASS:
			continue
		var m := ai.choose_move(s, "hard", 400)
		var others := Array(R.legal_moves(s)).filter(func(q: int) -> bool: return not x_squares.has(q))
		if not others.is_empty():
			assert_bool(x_squares.has(m)).override_failure_message("X square %d" % m).is_false()


func test_a_player_with_no_move_passes() -> void:
	var s := _pos(["........", "........", "........", "........", "........", "........", ".1......", "0......."], 1)
	assert_int(ReversiOpponent.new(1).choose_move(s, "hard")).is_equal(R.PASS)


func test_hard_plays_the_ending_perfectly() -> void:
	# Few empty squares left: Hard searches to the end and finds the best final count,
	# checked against a plain search of every line on the rules.
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var tried := 0
	for g in 40:
		var s := R.new_game()
		while R.result(s) == R.ONGOING and R.discs(s, 0) + R.discs(s, 1) < 57:
			var moves := R.legal_moves(s)
			R.play(s, moves[rng.randi_range(0, moves.size() - 1)])
		if R.result(s) != R.ONGOING or R.legal_moves(s)[0] == R.PASS:
			continue
		var best := -99
		for m in R.legal_moves(s):
			best = maxi(best, -_plain_best(R.after(s, m)))
		var pick := ReversiOpponent.new(1).choose_move(s, "hard")
		var got := -_plain_best(R.after(s, pick))
		# A win is a win: Hard may stop at any winning move, but never throws one away.
		if best > 0:
			assert_int(got).override_failure_message("game %d" % g).is_greater(0)
		else:
			assert_int(got).override_failure_message("game %d" % g).is_equal(best)
		tried += 1
		if tried >= 4:
			break
	assert_int(tried).is_equal(4)


## The best final disc difference for the player to move, by trying every line.
func _plain_best(s: R.State) -> int:
	if R.result(s) != R.ONGOING:
		return R.discs(s, s.turn) - R.discs(s, 1 - s.turn)
	var best := -99
	for m in R.legal_moves(s):
		best = maxi(best, -_plain_best(R.after(s, m)))
	return best


func test_every_level_answers_in_good_time() -> void:
	var s := R.new_game()
	for i in 4:
		R.play(s, R.legal_moves(s)[0])
	for level in ["easy", "medium", "hard"]:
		var t := Time.get_ticks_msec()
		ReversiOpponent.new(2).choose_move(s, level)
		var limit := int(ReversiOpponent.LEVELS[level]["time_ms"]) + 400
		assert_int(Time.get_ticks_msec() - t).override_failure_message(level).is_less(limit)
