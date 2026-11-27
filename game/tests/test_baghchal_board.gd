extends GdUnitTestSuite
## The tiger board view drawing Bagh-Chal: square grid, taps, placing and jumping.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const BoardView := preload("res://games/aadupuli/board/board_view.gd")


func _board(board_id := "baghchal") -> BoardView:
	var b := BoardView.new()
	add_child(auto_free(b))
	b.layout(Vector2(1000, 1300))
	b.new_game({"board": board_id})
	return b


func test_the_points_form_an_even_square_grid() -> void:
	var b := _board()
	var gap := b.point_pos(1).x - b.point_pos(0).x
	assert_float(gap).is_greater(100.0)
	for r in 5:
		for c in 5:
			var p := b.point_pos(r * 5 + c)
			assert_float(p.x - b.point_pos(r * 5).x).is_equal_approx(gap * c, 0.5)
			assert_float(p.y - b.point_pos(c).y).is_equal_approx(gap * r, 0.5)
	assert_bool(b.plank.end.x <= 1000.0 and b.plank.position.x >= 0.0).is_true()


func test_four_tigers_stand_on_the_corners_and_a_tap_places_a_goat() -> void:
	var b := _board()
	assert_int(b.pieces.size()).is_equal(4)
	for corner: int in [0, 4, 20, 24]:
		assert_bool(b.pieces.has(corner)).is_true()
	b._tap(12)
	assert_bool(R.goat_at(b.state, 12)).is_true()
	assert_int(b.state.in_hand).is_equal(19)


func test_a_tiger_jumps_a_goat_on_the_diagonal_by_tapping() -> void:
	var b := _board()
	var s := R.new_game({"board": "baghchal"})
	s.goats = 1 << 6
	s.in_hand = 19
	s.turn = R.TIGER
	s.counts = {R.position_key(s): 1}
	b.set_state(s)
	b._tap(0)
	assert_int(b.selected).is_equal(0)
	b._tap(12)
	assert_int(b.state.captured).is_equal(1)
	assert_bool(b.pieces.has(12)).is_true()


func test_switching_boards_relays_out_tiger_and_goat_unchanged() -> void:
	var b := _board("aadupuli")
	var cave := b.point_pos(0)
	b.new_game({"board": "baghchal"})
	b.new_game({"board": "aadupuli"})
	assert_vector(b.point_pos(0)).is_equal(cave)
	assert_int(b.pieces.size()).is_equal(3)
