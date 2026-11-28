extends GdUnitTestSuite
## Reversi rules (BUILD_PLAN.md G5.1, DISCUSSION.md section 32): the start, flips in all
## eight directions, no wrapping round the edges, the corner square that holds the sign
## bit, passing, the end of the game, save and load, and a cross-check of the bitboards
## against a plain square-by-square version of the rules.

const R := preload("res://games/reversi/reversi_rules.gd")


## Rows from the TOP down, as they read on screen ("." empty, "0" orange, "1" cream).
func _pos(top_down: Array, turn := 0) -> R.State:
	var rows := top_down.duplicate()
	rows.reverse()
	return R.from_dict({"rows": rows, "turn": turn})


func _sq(col: int, row: int) -> int:
	return R.cell(col, row)


# ---------- A plain version of the rules, square by square ----------

const ALL := [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, 1], [1, -1], [-1, -1]]


func _plain_flips(s: R.State, col: int, row: int) -> Array:
	var me := s.turn
	if R.owner_at(s, col, row) != -1:
		return []
	var out: Array = []
	for d: Array in ALL:
		var line: Array = []
		var c: int = col + d[0]
		var r: int = row + d[1]
		while c >= 0 and c < 8 and r >= 0 and r < 8 and R.owner_at(s, c, r) == 1 - me:
			line.append(_sq(c, r))
			c += d[0]
			r += d[1]
		if not line.is_empty() and c >= 0 and c < 8 and r >= 0 and r < 8 and R.owner_at(s, c, r) == me:
			out.append_array(line)
	out.sort()
	return out


func _plain_moves(s: R.State) -> Array:
	var out: Array = []
	for row in 8:
		for col in 8:
			if not _plain_flips(s, col, row).is_empty():
				out.append(_sq(col, row))
	return out


# ---------- Tests ----------

func test_a_new_game_has_four_centre_discs_and_four_opening_moves() -> void:
	var s := R.new_game()
	assert_int(R.discs(s, 0)).is_equal(2)
	assert_int(R.discs(s, 1)).is_equal(2)
	assert_int(s.turn).is_equal(0)
	assert_int(R.result(s)).is_equal(R.ONGOING)
	assert_array(Array(R.legal_moves(s))).is_equal(_plain_moves(s))
	assert_int(R.legal_moves(s).size()).is_equal(4)


func test_a_move_flips_the_trapped_line_and_passes_the_turn() -> void:
	var s := R.new_game()
	var m: int = R.legal_moves(s)[0]
	var flipped := R.play(s, m)
	assert_int(flipped.size()).is_equal(1)
	assert_int(R.discs(s, 0)).is_equal(4)
	assert_int(R.discs(s, 1)).is_equal(1)
	assert_int(s.turn).is_equal(1)
	assert_int(s.last_move).is_equal(m)
	assert_int(s.moves_played).is_equal(1)


func test_one_disc_can_flip_in_all_eight_directions() -> void:
	# The empty square (3,4) is ringed by cream, each line closed by orange.
	var s := _pos([
		"........",
		".0.0.0..",
		"..111...",
		".01.10..",
		"..111...",
		".0.0.0..",
		"........",
		"........",
	])
	var centre := _sq(3, 4)
	var flipped := R.play(s, centre)
	assert_int(flipped.size()).is_equal(8)
	assert_int(R.discs(s, 1)).is_equal(0)


func test_lines_never_wrap_round_the_edge_of_the_board() -> void:
	# Cream on the right edge of one row, orange at the left edge of the row above:
	# next to each other in the bits, but not on a line.
	var s := _pos([
		"........",
		"........",
		"........",
		"0.......",
		".......1",
		"........",
		"........",
		"........",
	])
	assert_bool(R.legal_moves(s).has(_sq(6, 3))).is_false()
	assert_array(Array(R.legal_moves(s))).is_equal(_plain_moves(s))


func test_the_top_corner_square_works_despite_holding_the_sign_bit() -> void:
	# Square 63 is the top-right corner. Orange takes it, flipping west and south.
	var s := _pos([
		".....01.",
		".......1",
		".......1",
		".......0",
		"........",
		"........",
		"........",
		"........",
	])
	assert_bool(R.legal_moves(s).has(63)).is_true()
	var flipped := R.play(s, 63)
	assert_array(Array(flipped)).is_equal([47, 55, 62])
	assert_int(R.owner_at(s, 7, 7)).is_equal(0)
	assert_int(R.discs(s, 1)).is_equal(0)


func test_a_player_with_no_move_must_pass() -> void:
	# Orange holds the corner, which can never be flanked, so cream to move has nothing
	# to play; orange can still flank cream's disc diagonally.
	var s := _pos([
		"........",
		"........",
		"........",
		"........",
		"........",
		"........",
		".1......",
		"0.......",
	], 1)
	assert_array(Array(R.legal_moves(s))).is_equal([R.PASS])
	assert_int(R.result(s)).is_equal(R.ONGOING)
	assert_array(Array(R.play(s, R.PASS))).is_empty()
	assert_int(s.turn).is_equal(0)
	assert_int(s.last_move).is_equal(R.PASS)


func test_the_game_ends_when_neither_player_can_move() -> void:
	var only_orange := _pos(["00000000", "........", "........", "........", "........", "........", "........", "........"], 1)
	assert_int(R.result(only_orange)).is_equal(R.WIN_0)
	assert_array(Array(R.legal_moves(only_orange))).is_empty()
	var rows: Array = []
	for r in 8:
		rows.append("00001111")  # A full board, 32 each.
	assert_int(R.result(_pos(rows))).is_equal(R.DRAW)
	rows[0] = "11111111"
	assert_int(R.result(_pos(rows))).is_equal(R.WIN_1)


func test_save_and_load_keep_the_position() -> void:
	var s := R.new_game()
	for i in 6:
		R.play(s, R.legal_moves(s)[0])
	var back := R.from_dict(JSON.parse_string(JSON.stringify(R.to_dict(s))))
	assert_array(Array(back.bits)).is_equal(Array(s.bits))
	assert_int(back.turn).is_equal(s.turn)
	assert_int(back.moves_played).is_equal(6)
	assert_int(back.last_move).is_equal(s.last_move)
	assert_str(R.to_dict(s)["game"]).is_equal("reversi")


func test_the_bitboards_agree_with_plain_rules_in_hundreds_of_positions() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var checked := 0
	for g in 40:
		var s := R.new_game()
		while R.result(s) == R.ONGOING:
			var moves := R.legal_moves(s)
			if moves[0] != R.PASS:
				assert_array(Array(moves)).is_equal(_plain_moves(s))
				var m: int = moves[rng.randi_range(0, moves.size() - 1)]
				var expect := _plain_flips(s, m % 8, floori(m / 8.0))
				var flipped := Array(R.play(s, m))
				assert_array(flipped).is_equal(expect)
				checked += 1
			else:
				assert_array(_plain_moves(s)).is_empty()
				R.play(s, R.PASS)
	assert_int(checked).is_greater(1500)


func test_random_games_always_end_with_a_full_count() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var seen := {}
	for g in 300:
		var s := R.new_game()
		var n := 0
		while R.result(s) == R.ONGOING and n < 200:
			var moves := R.legal_moves(s)
			R.play(s, moves[rng.randi_range(0, moves.size() - 1)])
			n += 1
		assert_int(n).is_less(200)
		assert_int(R.discs(s, 0) + R.discs(s, 1)).is_less_equal(64)
		assert_int(s.bits[0] & s.bits[1]).is_equal(0)
		seen[R.result(s)] = true
	assert_bool(seen.has(R.WIN_0) and seen.has(R.WIN_1)).is_true()
