extends GdUnitTestSuite
## The Checkers computer (BUILD_PLAN.md G6.3): its own move finder agrees with the rules
## in both rule sets, moves are taken back exactly, legal moves at every level, free
## pieces taken, pieces not given away, a win taken, and quick enough to play.

const C := preload("res://games/checkers/checkers_rules.gd")


func _sq(col: int, row: int) -> int:
	return C.square(col, row)


func _pos(variant: String, pieces: Dictionary, turn := 0) -> C.State:
	var cells: Array = []
	cells.resize(C.SQUARES)
	cells.fill(".")
	for at: Vector2i in pieces:
		cells[_sq(at.x, at.y)] = pieces[at]
	return C.from_dict({"variant": variant, "board": "".join(cells), "turn": turn})


## A move as [from, to, sorted captures], for comparing the two move finders.
func _sig(from: int, to: int, caps: Array) -> Array:
	var c := caps.duplicate()
	c.sort()
	return [from, to, c]


func test_its_move_finder_agrees_with_the_rules_and_takes_moves_back_exactly() -> void:
	var ai := CheckersOpponent.new(1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var checked := 0
	for v: String in [C.ENGLISH, C.INTERNATIONAL]:
		for g in 12:
			var s := C.new_game(v)
			while C.result(s) == C.ONGOING:
				ai._variant = v
				ai._board = s.board.duplicate()
				ai._key = ai._hash()
				var mine: Array = ai._moves(s.turn).map(func(m: PackedInt32Array) -> Array: return _sig(m[0], m[1], Array(m.slice(2))))
				var theirs: Array = C.legal_moves(s).map(func(m: C.Move) -> Array: return _sig(m.from_sq(), m.to_sq(), Array(m.captured)))
				mine.sort()
				theirs.sort()
				# Chains through different squares that take the same pieces count once.
				var unique: Array = []
				for t: Array in theirs:
					if unique.is_empty() or unique[unique.size() - 1] != t:
						unique.append(t)
				var unique_mine: Array = []
				for t: Array in mine:
					if unique_mine.is_empty() or unique_mine[unique_mine.size() - 1] != t:
						unique_mine.append(t)
				assert_array(unique_mine).override_failure_message("%s move %d" % [v, s.moves_played]).is_equal(unique)
				# Every move, played and taken back, leaves the board and its key as they were.
				var before := ai._board.duplicate()
				var key := ai._key
				for m: PackedInt32Array in ai._moves(s.turn):
					var undo := ai._make(m)
					assert_int(ai._key).is_equal(ai._hash())
					ai._unmake(m, undo)
				assert_array(Array(ai._board)).is_equal(Array(before))
				assert_int(ai._key).is_equal(key)
				checked += 1
				var legal := C.legal_moves(s)
				C.play(s, legal[rng.randi_range(0, legal.size() - 1)])
	assert_int(checked).is_greater(800)


func test_every_level_plays_a_legal_move_in_both_rule_sets() -> void:
	var ai := CheckersOpponent.new(3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for v: String in [C.ENGLISH, C.INTERNATIONAL]:
		for level in ["easy", "medium", "hard"]:
			var s := C.new_game(v)
			for i in 6:
				if C.result(s) != C.ONGOING:
					break
				var path := ai.choose_move(s, level, 200)
				var m := C.find_move(s, path)
				assert_object(m).override_failure_message("%s %s played %s" % [v, level, path]).is_not_null()
				C.play(s, m)
				if C.result(s) != C.ONGOING:
					break
				var moves := C.legal_moves(s)
				C.play(s, moves[rng.randi_range(0, moves.size() - 1)])


func test_medium_and_hard_take_a_free_piece() -> void:
	# Black can jump the red man at (3,3); nothing can take back.
	var s := _pos(C.ENGLISH, {Vector2i(2, 2): "b", Vector2i(3, 3): "r", Vector2i(7, 7): "r", Vector2i(0, 0): "b"})
	for level in ["medium", "hard"]:
		for seed_value in [1, 2, 3]:
			var path := CheckersOpponent.new(seed_value).choose_move(s, level)
			assert_array(Array(path)).override_failure_message(level).is_equal([_sq(2, 2), _sq(4, 4)])


func test_medium_and_hard_do_not_give_a_piece_away() -> void:
	# Stepping to (3,3) lets the red man at (4,4) jump it; (1,3) is safe.
	var s := _pos(C.ENGLISH, {Vector2i(2, 2): "b", Vector2i(4, 4): "r", Vector2i(7, 7): "r"})
	for level in ["medium", "hard"]:
		for seed_value in [1, 2, 3]:
			var path := CheckersOpponent.new(seed_value).choose_move(s, level)
			assert_array(Array(path)).override_failure_message(level).is_equal([_sq(2, 2), _sq(1, 3)])


func test_every_level_takes_the_last_piece_to_win() -> void:
	var s := _pos(C.INTERNATIONAL, {Vector2i(0, 0): "B", Vector2i(4, 4): "r", Vector2i(2, 0): "b"})
	for level in ["easy", "medium", "hard"]:
		var path := CheckersOpponent.new(2).choose_move(s, level)
		var m := C.find_move(s, path)
		assert_bool(m != null and m.is_capture()).override_failure_message(level).is_true()
		assert_int(C.result(C.after(s, m))).is_equal(C.WIN_0)


func test_every_level_answers_in_good_time() -> void:
	for v: String in [C.ENGLISH, C.INTERNATIONAL]:
		var s := C.new_game(v)
		for i in 4:
			C.play(s, C.legal_moves(s)[0])
		for level in ["easy", "medium", "hard"]:
			var t := Time.get_ticks_msec()
			CheckersOpponent.new(2).choose_move(s, level)
			var limit := int(CheckersOpponent.LEVELS[level]["time_ms"]) + 500
			assert_int(Time.get_ticks_msec() - t).override_failure_message("%s %s" % [v, level]).is_less(limit)
