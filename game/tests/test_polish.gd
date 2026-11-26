extends GdUnitTestSuite
## Polish details: last-move trail, stuck-piece feedback, every sound present.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const BoardView := preload("res://games/aadupuli/board/board_view.gd")


func _board() -> BoardView:
	var b := BoardView.new()
	add_child(auto_free(b))
	b.layout(Vector2(1000, 1400))
	b.new_game()
	return b


func test_the_last_move_is_remembered_and_cleared_on_a_new_position() -> void:
	var b := _board()
	b._tap(19)
	assert_int(b.last_move).is_equal(R.encode(R.NONE, 19, R.NONE))
	b.new_game()
	assert_int(b.last_move).is_equal(-1)


func test_a_piece_with_nowhere_to_go_is_not_selected_and_says_so() -> void:
	var b := _board()
	var s := R.new_game()
	s.goats = 0
	for g: int in [19, 14, 20, 1, 2, 5, 6, 7, 12, 13, 18]:  # 11 on the hill + 4 captured = 15
		s.goats |= 1 << g
	s.tigers = PackedInt32Array([0, 3, 4])
	s.in_hand = 0
	s.captured = 4
	s.turn = R.GOAT
	s.counts = {R.position_key(s): 1}
	b.set_state(s)
	# Goat 19 is boxed in by goats at 14 and 20.
	var told := [false]
	b.no_moves.connect(func(_p: int) -> void: told[0] = true)
	b._tap(19)
	assert_bool(told[0]).is_true()
	assert_int(b.selected).is_equal(-1)


func test_every_sound_the_game_uses_is_present() -> void:
	for kind in ["place", "move", "capture", "win", "lose", "select", "solved", "nope", "seed"]:
		assert_bool(Sfx.STREAMS.has(kind)).override_failure_message(kind).is_true()
		assert_object(Sfx.STREAMS[kind]).override_failure_message(kind).is_not_null()
