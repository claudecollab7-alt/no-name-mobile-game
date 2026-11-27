extends GdUnitTestSuite
## Four in a Row rules (BUILD_PLAN.md G4.1, DISCUSSION.md section 31) and the shared
## grid geometry.

const F := preload("res://games/fourinrow/four_rules.gd")


## Plays columns in order, alternating from player 0.
func _play(cols: Array) -> F.State:
	var s := F.new_game()
	for c: int in cols:
		assert_bool(F.can_drop(s, c)).override_failure_message("column %d not playable" % c).is_true()
		F.drop(s, c)
	return s


func _cells(pairs: Array) -> Array:
	var out: Array = []
	for p: Array in pairs:
		out.append(Grid.cell(F.COLS, p[0], p[1]))
	out.sort()
	return out


func test_a_7_by_6_board_has_69_lines_of_four() -> void:
	assert_int(Grid.lines(7, 6, 4).size()).is_equal(69)
	assert_int(Grid.cell(7, 3, 2)).is_equal(17)
	assert_int(Grid.col_of(7, 17)).is_equal(3)
	assert_int(Grid.row_of(7, 17)).is_equal(2)


func test_a_new_game_is_empty_with_every_column_open_and_first_to_move() -> void:
	var s := F.new_game()
	assert_int(s.turn).is_equal(0)
	assert_array(Array(F.legal_moves(s))).is_equal([0, 1, 2, 3, 4, 5, 6])
	assert_int(F.result(s)).is_equal(F.ONGOING)
	for col in F.COLS:
		for row in F.ROWS:
			assert_int(F.owner_at(s, col, row)).is_equal(-1)


func test_discs_fall_to_the_lowest_space_and_turns_alternate() -> void:
	var s := F.new_game()
	assert_int(F.drop(s, 3)).is_equal(0)
	assert_int(s.turn).is_equal(1)
	assert_int(F.drop(s, 3)).is_equal(1)
	assert_int(F.drop(s, 4)).is_equal(0)
	assert_int(F.owner_at(s, 3, 0)).is_equal(0)
	assert_int(F.owner_at(s, 3, 1)).is_equal(1)
	assert_int(F.owner_at(s, 4, 0)).is_equal(0)
	assert_int(s.moves_played).is_equal(3)
	assert_int(s.last_move).is_equal(4)


func test_a_full_column_cannot_be_played() -> void:
	var s := _play([2, 2, 2, 2, 2, 2])
	assert_bool(F.can_drop(s, 2)).is_false()
	assert_array(Array(F.legal_moves(s))).is_equal([0, 1, 3, 4, 5, 6])
	assert_bool(F.can_drop(s, -1)).is_false()
	assert_bool(F.can_drop(s, 7)).is_false()


func test_after_leaves_the_original_untouched() -> void:
	var s := _play([3])
	var a := F.after(s, 3)
	assert_int(s.moves_played).is_equal(1)
	assert_int(F.owner_at(s, 3, 1)).is_equal(-1)
	assert_int(F.owner_at(a, 3, 1)).is_equal(1)


func test_four_across_wins_and_is_highlighted() -> void:
	# First player builds 0-3 on the bottom row; second plays on top of them.
	var s := _play([0, 0, 1, 1, 2, 2, 3])
	assert_int(F.result(s)).is_equal(F.WIN_0)
	assert_array(Array(F.winning_cells(s))).is_equal(_cells([[0, 0], [1, 0], [2, 0], [3, 0]]))
	assert_array(Array(F.legal_moves(s))).is_empty()
	assert_bool(F.can_drop(s, 5)).is_false()


func test_four_up_wins() -> void:
	var s := _play([6, 0, 6, 0, 6, 0, 1, 0])  # Second player stacks column 0.
	assert_int(F.result(s)).is_equal(F.WIN_1)
	assert_array(Array(F.winning_cells(s))).is_equal(_cells([[0, 0], [0, 1], [0, 2], [0, 3]]))


func test_four_on_the_rising_diagonal_wins() -> void:
	# First player: (0,0) (1,1) (2,2) (3,3).
	var s := _play([0, 1, 1, 2, 2, 3, 2, 3, 3, 6, 3])
	assert_int(F.result(s)).is_equal(F.WIN_0)
	assert_array(Array(F.winning_cells(s))).is_equal(_cells([[0, 0], [1, 1], [2, 2], [3, 3]]))


func test_four_on_the_falling_diagonal_wins() -> void:
	# First player: (6,0) (5,1) (4,2) (3,3).
	var s := _play([6, 5, 5, 4, 4, 3, 4, 3, 3, 0, 3])
	assert_int(F.result(s)).is_equal(F.WIN_0)
	assert_array(Array(F.winning_cells(s))).is_equal(_cells([[6, 0], [5, 1], [4, 2], [3, 3]]))


func test_five_in_a_row_highlights_all_five() -> void:
	var s := F.from_dict({"columns": [[0], [0], [], [0], [0], [], []], "turn": 0})
	F.drop(s, 2)
	assert_int(F.result(s)).is_equal(F.WIN_0)
	assert_array(Array(F.winning_cells(s))).is_equal(_cells([[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]]))


func test_lines_never_wrap_from_one_column_to_the_next() -> void:
	# Top two of column 0 and bottom two of column 1 sit next to each other in the bits.
	var s := F.from_dict({"columns": [[1, 1, 1, 1, 0, 0], [0, 0], [], [], [], [], []], "turn": 1})
	assert_bool(F.has_four(s.bits[0])).is_false()
	# Nor does a disc at the top of one column join a diagonal starting at the next
	# column's bottom (the empty guard bit sits between them).
	var t := F.from_dict({"columns": [[1, 1, 1, 1, 1, 0], [0], [1, 0], [1, 1, 0], [], [], []], "turn": 1})
	assert_int(F.result(t)).is_equal(F.WIN_1)  # Column 0 has five of player 1...
	assert_bool(F.has_four(t.bits[0])).is_false()  # ...but player 0's scattered discs are not a line.


func test_a_full_board_without_four_is_a_draw() -> void:
	var columns: Array = []
	for col in F.COLS:
		var discs: Array = []
		for row in F.ROWS:
			discs.append((col + floori(row / 3.0)) % 2)
		columns.append(discs)
	var s := F.from_dict({"columns": columns, "turn": 0})
	assert_int(s.moves_played).is_equal(42)
	assert_int(F.result(s)).is_equal(F.DRAW)
	assert_array(Array(F.legal_moves(s))).is_empty()
	assert_array(Array(F.winning_cells(s))).is_empty()


func test_save_and_load_keep_the_position() -> void:
	var s := _play([3, 3, 4, 2, 5])
	var d := F.to_dict(s)
	assert_str(d["game"]).is_equal("fourinrow")
	var back := F.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_array(Array(back.bits)).is_equal(Array(s.bits))
	assert_array(Array(back.heights)).is_equal(Array(s.heights))
	assert_int(back.turn).is_equal(s.turn)
	assert_int(back.moves_played).is_equal(5)
	assert_int(back.last_move).is_equal(5)


func test_random_games_always_end_within_42_moves() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var seen := {}
	for g in 500:
		var s := F.new_game()
		while F.result(s) == F.ONGOING:
			var moves := F.legal_moves(s)
			assert_bool(moves.is_empty()).is_false()
			F.drop(s, moves[rng.randi_range(0, moves.size() - 1)])
		assert_int(s.moves_played).is_less_equal(42)
		var res := F.result(s)
		seen[res] = true
		if res != F.DRAW:
			assert_int(F.winning_cells(s).size()).is_greater_equal(4)
			# The winner made the last move.
			assert_int(1 - s.turn).is_equal(0 if res == F.WIN_0 else 1)
	assert_bool(seen.has(F.WIN_0) and seen.has(F.WIN_1)).is_true()
