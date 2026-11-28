extends GdUnitTestSuite
## Checkers rules, English and International (BUILD_PLAN.md G6.1, DISCUSSION.md section
## 33): the start, men and kings in both rule sets, capture chains, crowning, optional
## captures, flying kings, wins, automatic draws, save and load, and a cross-check
## against a plain version of the rules written square by square on an 8 × 8 grid.

const C := preload("res://games/checkers/checkers_rules.gd")
const E := "english"
const I := "international"


## A position from pieces given as {Vector2i(col, row): "b" | "B" | "r" | "R"}.
func _pos(variant: String, pieces: Dictionary, turn := 0) -> C.State:
	var text := ""
	for sq in C.SQUARES:
		text += "."
	for at: Vector2i in pieces:
		var sq := C.square(at.x, at.y)
		assert_int(sq).override_failure_message("light square %s" % at).is_not_equal(-1)
		text = text.substr(0, sq) + str(pieces[at]) + text.substr(sq + 1)
	return C.from_dict({"variant": variant, "board": text, "turn": turn})


func _sq(col: int, row: int) -> int:
	return C.square(col, row)


func _path(points: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for p: Vector2i in points:
		out.append(_sq(p.x, p.y))
	return out


## The legal moves as a sorted list of paths, for comparing.
func _paths(s: C.State) -> Array:
	var out: Array = []
	for m: C.Move in C.legal_moves(s):
		out.append(Array(m.path))
	out.sort()
	return out


# ---------- A plain version of the rules, on an 8 × 8 grid ----------

const PLAIN_DIRS := [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]


func _grid(s: C.State) -> Dictionary:
	var g := {}
	for row in 8:
		for col in 8:
			if (col + row) % 2 == 0:
				g[Vector2i(col, row)] = ".bBrR"[s.board[row * 4 + floori(col / 2.0)]]
	return g


func _plain_moves(s: C.State) -> Array:
	var g := _grid(s)
	var me := ["b", "B"] if s.turn == 0 else ["r", "R"]
	var them := ["r", "R"] if s.turn == 0 else ["b", "B"]
	var up := 1 if s.turn == 0 else -1
	var out: Array = []
	for at: Vector2i in g:
		var piece: String = g[at]
		if not me.has(piece):
			continue
		var king := piece == piece.to_upper()
		var flying := king and s.variant == I
		# Steps.
		for d: Vector2i in PLAIN_DIRS:
			if not king and d.y != up:
				continue
			var to := at + d
			while g.has(to) and g[to] == ".":
				out.append([at, to])
				if not flying:
					break
				to += d
		# Captures.
		_plain_jumps(s, g, at, at, piece, king, [at], [], them, up, out)
	var result: Array = []
	for p: Array in out:
		var path: Array = []
		for v: Vector2i in p:
			path.append(v.y * 4 + floori(v.x / 2.0))
		result.append(path)
	result.sort()
	return result


func _plain_jumps(s: C.State, g: Dictionary, start: Vector2i, at: Vector2i, piece: String, king: bool,
		path: Array, taken: Array, them: Array, up: int, out: Array) -> void:
	var flying := king and s.variant == I
	var men_back := s.variant == I
	var found := false
	for d: Vector2i in PLAIN_DIRS:
		if not king and not men_back and d.y != up:
			continue
		var v := at + d
		if flying:
			while g.has(v) and (g[v] == "." or v == start):
				v += d
		if not g.has(v) or not them.has(g[v]) or taken.has(v):
			continue
		var land := v + d
		while g.has(land) and (g[land] == "." or land == start):
			found = true
			var p2 := path.duplicate()
			p2.append(land)
			var t2 := taken.duplicate()
			t2.append(v)
			var far := 7 if up == 1 else 0
			if s.variant == E and not king and land.y == far:
				out.append(p2)
			else:
				_plain_jumps(s, g, start, land, piece, king, p2, t2, them, up, out)
			if not flying:
				break
			land += d
	if not found and path.size() > 1:
		out.append(path)


# ---------- Tests ----------

func test_a_new_game_has_twelve_each_and_seven_opening_moves() -> void:
	for v: String in [E, I]:
		var s := C.new_game(v)
		assert_int(C.count(s, 0)).is_equal(12)
		assert_int(C.count(s, 1)).is_equal(12)
		assert_int(s.turn).is_equal(0)
		assert_int(C.result(s)).is_equal(C.ONGOING)
		assert_int(C.legal_moves(s).size()).override_failure_message(v).is_equal(7)
		assert_array(_paths(s)).is_equal(_plain_moves(s))
	# Squares: the dark ones only, numbered from the bottom left.
	assert_int(_sq(0, 0)).is_equal(0)
	assert_int(_sq(1, 0)).is_equal(-1)
	assert_int(_sq(7, 7)).is_equal(31)
	for sq in C.SQUARES:
		assert_int(_sq(C.col_of(sq), C.row_of(sq))).is_equal(sq)


func test_only_international_men_capture_backwards() -> void:
	var pieces := {Vector2i(3, 3): "b", Vector2i(2, 2): "r"}
	var back := _path([Vector2i(3, 3), Vector2i(1, 1)])
	assert_object(C.find_move(_pos(E, pieces), back)).is_null()
	var m := C.find_move(_pos(I, pieces), back)
	assert_object(m).is_not_null()
	assert_array(Array(m.captured)).is_equal([_sq(2, 2)])


func test_a_capture_chain_is_one_move_and_must_be_finished() -> void:
	# Black jumps (2,2) to (3,3), then can go on over (4,4) or over (2,4).
	var s := _pos(E, {Vector2i(1, 1): "b", Vector2i(2, 2): "r", Vector2i(4, 4): "r", Vector2i(2, 4): "r"})
	var captures: Array = C.legal_moves(s).filter(func(m: C.Move) -> bool: return m.is_capture())
	var paths: Array = captures.map(func(m: C.Move) -> Array: return Array(m.path))
	paths.sort()
	var expect := [Array(_path([Vector2i(1, 1), Vector2i(3, 3), Vector2i(5, 5)])), Array(_path([Vector2i(1, 1), Vector2i(3, 3), Vector2i(1, 5)]))]
	expect.sort()
	assert_array(paths).is_equal(expect)
	# Stopping halfway is not a move.
	assert_object(C.find_move(s, _path([Vector2i(1, 1), Vector2i(3, 3)]))).is_null()
	# Captures are optional: the plain step is still there.
	assert_object(C.find_move(s, _path([Vector2i(1, 1), Vector2i(0, 2)]))).is_not_null()
	# Both taken pieces go once the chain ends.
	var m := C.find_move(s, _path([Vector2i(1, 1), Vector2i(3, 3), Vector2i(5, 5)]))
	var a := C.after(s, m)
	assert_int(C.count(a, 1)).is_equal(1)
	assert_int(a.board[_sq(5, 5)]).is_equal(C.BLACK_MAN)


func test_english_crowning_ends_the_move_but_an_international_man_carries_on() -> void:
	# A black man jumps onto the far row; from there it could jump again (as a king, or
	# as an international man, which may capture backwards).
	var pieces := {Vector2i(3, 5): "b", Vector2i(4, 6): "r", Vector2i(6, 6): "r"}
	var to_crown := _path([Vector2i(3, 5), Vector2i(5, 7)])
	var english := C.find_move(_pos(E, pieces), to_crown)
	assert_object(english).is_not_null()
	assert_int(C.after(_pos(E, pieces), english).board[_sq(5, 7)]).is_equal(C.BLACK_KING)
	var intl := _pos(I, pieces)
	assert_object(C.find_move(intl, to_crown)).is_null()  # It must carry on.
	var on := C.find_move(intl, _path([Vector2i(3, 5), Vector2i(5, 7), Vector2i(7, 5)]))
	assert_object(on).is_not_null()
	assert_int(C.after(intl, on).board[_sq(7, 5)]).is_equal(C.BLACK_MAN)  # Passed through: still a man.


func test_international_kings_fly_and_english_kings_step() -> void:
	var pieces := {Vector2i(0, 0): "B", Vector2i(3, 3): "r", Vector2i(7, 1): "r"}
	var intl := _pos(I, pieces)
	var lands: Array = []
	for m: C.Move in C.legal_moves(intl):
		if m.is_capture():
			lands.append(m.to_sq())
	lands.sort()
	assert_array(lands).is_equal([_sq(4, 4), _sq(5, 5), _sq(6, 6), _sq(7, 7)])  # Any square beyond.
	assert_object(C.find_move(intl, _path([Vector2i(0, 0), Vector2i(2, 2)]))).is_not_null()  # A long step.
	var english := _pos(E, pieces)
	assert_array(_paths(english)).is_equal([Array(_path([Vector2i(0, 0), Vector2i(1, 1)]))])
	# Two pieces in a row can't be jumped, even by a flying king.
	var blocked := _pos(I, {Vector2i(0, 0): "B", Vector2i(3, 3): "r", Vector2i(4, 4): "r"})
	assert_bool(C.legal_moves(blocked).any(func(m: C.Move) -> bool: return m.is_capture())).is_false()


func test_you_win_by_taking_every_piece_or_leaving_no_move() -> void:
	var taken := _pos(E, {Vector2i(3, 3): "r"}, 0)
	assert_int(C.result(taken)).is_equal(C.WIN_1)
	assert_str(C.reason(taken)).is_equal("taken")
	# Black's only man is hemmed in: no step, and no square to land a jump on.
	var stuck := _pos(E, {Vector2i(0, 0): "b", Vector2i(1, 1): "r", Vector2i(2, 2): "r"}, 0)
	assert_int(C.result(stuck)).is_equal(C.WIN_1)
	assert_str(C.reason(stuck)).is_equal("blocked")
	assert_int(C.result(_pos(I, {Vector2i(3, 3): "b"}, 1))).is_equal(C.WIN_0)


func test_a_third_repetition_is_a_draw() -> void:
	var s := _pos(E, {Vector2i(0, 0): "B", Vector2i(7, 7): "R"})
	var shuffle := [
		[Vector2i(0, 0), Vector2i(1, 1)], [Vector2i(7, 7), Vector2i(6, 6)],
		[Vector2i(1, 1), Vector2i(0, 0)], [Vector2i(6, 6), Vector2i(7, 7)],
	]
	for round_no in 2:
		assert_int(C.result(s)).is_equal(C.ONGOING)
		for p: Array in shuffle:
			C.play(s, C.find_move(s, _path(p)))
	assert_int(C.result(s)).is_equal(C.DRAW)
	assert_str(C.reason(s)).is_equal("repeated")
	assert_array(C.legal_moves(s)).is_empty()


func test_fifty_moves_without_a_capture_or_a_man_moving_is_a_draw() -> void:
	var d := C.to_dict(_pos(E, {Vector2i(0, 0): "B", Vector2i(7, 7): "R", Vector2i(6, 2): "b"}))
	d["quiet"] = 49
	var s := C.from_dict(d)
	C.play(s, C.find_move(s, _path([Vector2i(0, 0), Vector2i(1, 1)])))  # A king move.
	assert_int(C.result(s)).is_equal(C.DRAW)
	assert_str(C.reason(s)).is_equal("quiet")
	d["quiet"] = 49
	var s2 := C.from_dict(d)
	C.play(s2, C.find_move(s2, _path([Vector2i(6, 2), Vector2i(7, 3)])))  # A man moving resets it.
	assert_int(s2.quiet).is_equal(0)
	assert_int(C.result(s2)).is_equal(C.ONGOING)


func test_save_and_load_keep_the_position_and_its_history() -> void:
	var s := C.new_game(I)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 10:
		var moves := C.legal_moves(s)
		C.play(s, moves[rng.randi_range(0, moves.size() - 1)])
	var back := C.from_dict(JSON.parse_string(JSON.stringify(C.to_dict(s))))
	assert_str(back.variant).is_equal(I)
	assert_array(Array(back.board)).is_equal(Array(s.board))
	assert_int(back.turn).is_equal(s.turn)
	assert_int(back.quiet).is_equal(s.quiet)
	assert_array(Array(back.history)).is_equal(Array(s.history))
	assert_array(Array(back.last_move)).is_equal(Array(s.last_move))
	assert_str(C.to_dict(s)["game"]).is_equal("checkers")


func test_the_rules_agree_with_a_plain_version_in_random_games() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var checked := 0
	var captures := 0
	var kings := 0
	for v: String in [E, I]:
		for g in 30:
			var s := C.new_game(v)
			while C.result(s) == C.ONGOING:
				var moves := C.legal_moves(s)
				assert_array(_paths(s)).override_failure_message("%s game %d move %d" % [v, g, s.moves_played]).is_equal(_plain_moves(s))
				checked += 1
				# Prefer captures, so chains and kings turn up often.
				var caps := moves.filter(func(m: C.Move) -> bool: return m.is_capture())
				var pick: C.Move = caps[rng.randi_range(0, caps.size() - 1)] if not caps.is_empty() and rng.randf() < 0.7 else moves[rng.randi_range(0, moves.size() - 1)]
				if pick.captured.size() >= 2:
					captures += 1
				C.play(s, pick)
				if C.is_king(s.board[pick.to_sq()]):
					kings += 1
	assert_int(checked).is_greater(2000)
	assert_int(captures).is_greater(20)  # Multi-jumps were tested.
	assert_int(kings).is_greater(50)


func test_random_games_always_end() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var seen := {}
	for v: String in [E, I]:
		for g in 60:
			var s := C.new_game(v)
			var n := 0
			while C.result(s) == C.ONGOING and n < 2000:
				var moves := C.legal_moves(s)
				C.play(s, moves[rng.randi_range(0, moves.size() - 1)])
				n += 1
			assert_int(n).is_less(2000)
			seen[C.reason(s)] = true
	assert_bool(seen.has("taken") or seen.has("blocked")).is_true()
