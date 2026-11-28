extends GdUnitTestSuite
## The Checkers board view (BUILD_PLAN.md G6.2): layout and turning the board round,
## picking a piece and its landing squares, tapping through a capture chain, putting a
## piece back, moves that aren't allowed, the move playing out, crowning, and the end.

const C := preload("res://games/checkers/checkers_rules.gd")
const Board := preload("res://games/checkers/board/checkers_board_view.gd")

var board: Board
var events: Array = []
var moved: Array = []


func before_test() -> void:
	events = []
	moved = []
	board = auto_free(Board.new())
	add_child(board)
	board.layout(Vector2(1000, 1300))
	board.new_game()
	board.played.connect(func(kind: String) -> void: events.append(kind))
	board.human_moved.connect(func(path: PackedInt32Array) -> void: moved.append(Array(path)))


func _settle() -> void:
	for i in 200:
		if not board.busy:
			return
		await get_tree().process_frame


func _sq(col: int, row: int) -> int:
	return C.square(col, row)


func _pos(variant: String, pieces: Dictionary, turn := 0) -> C.State:
	var cells: Array = []
	cells.resize(C.SQUARES)
	cells.fill(".")
	for at: Vector2i in pieces:
		cells[_sq(at.x, at.y)] = pieces[at]
	return C.from_dict({"variant": variant, "board": "".join(cells), "turn": turn})


func test_the_board_fits_and_turns_round_for_red() -> void:
	assert_bool(Rect2(Vector2.ZERO, Vector2(1000, 1300)).encloses(board.frame)).is_true()
	assert_float(board.square_pos(_sq(0, 0)).y).is_greater(board.square_pos(_sq(1, 7)).y)  # Black at the bottom.
	for sq in C.SQUARES:
		assert_int(board.square_at(board.square_pos(sq))).is_equal(sq)
	board.flipped = true
	assert_float(board.square_pos(_sq(0, 0)).y).is_less(board.square_pos(_sq(1, 7)).y)  # Red at the bottom.
	for sq in C.SQUARES:
		assert_int(board.square_at(board.square_pos(sq))).is_equal(sq)
	# Light squares and the border take no taps.
	var light := board.cell_pos(1, 0)
	assert_int(board.square_at(light)).is_equal(-1)
	assert_int(board.square_at(board.frame.position + Vector2(3, 3))).is_equal(-1)


func test_picking_a_piece_shows_where_it_can_go_and_a_tap_there_moves_it() -> void:
	assert_int(board.movable().size()).is_equal(4)  # The front row of four.
	board._tap(_sq(2, 2))
	var t := Array(board.targets())
	t.sort()
	assert_array(t).is_equal([_sq(1, 3), _sq(3, 3)])
	board._tap(_sq(3, 3))
	assert_array(moved).is_equal([[_sq(2, 2), _sq(3, 3)]])
	assert_bool(board.busy).is_true()
	assert_int(board.state.turn).is_equal(1)
	await _settle()
	assert_bool(board.busy).is_false()
	assert_array(events).is_equal(["pick", "move"])


func test_a_capture_chain_is_tapped_one_landing_at_a_time() -> void:
	board.set_state(_pos(C.ENGLISH, {Vector2i(1, 1): "b", Vector2i(2, 2): "r", Vector2i(4, 4): "r", Vector2i(2, 4): "r"}))
	board._tap(_sq(1, 1))
	assert_bool(board.targets().has(_sq(3, 3))).is_true()  # The jump...
	assert_bool(board.targets().has(_sq(0, 2))).is_true()  # ...or the plain step (captures are optional).
	board._tap(_sq(3, 3))
	assert_array(moved).is_empty()  # Not finished: the chain goes on.
	assert_array(Array(board._taken_so_far())).is_equal([_sq(2, 2)])
	var t := Array(board.targets())
	t.sort()
	assert_array(t).is_equal([_sq(1, 5), _sq(5, 5)])
	board._tap(_sq(5, 5))
	assert_array(moved).is_equal([[_sq(1, 1), _sq(3, 3), _sq(5, 5)]])
	await _settle()
	assert_int(C.count(board.state, 1)).is_equal(1)
	assert_int(events.count("capture")).is_equal(1)  # Only the last hop was still to show.


func test_tapping_the_piece_again_puts_it_back_and_wrong_squares_are_refused() -> void:
	board._tap(_sq(0, 0))  # Can't move: hemmed in by its own pieces.
	assert_bool(events.has("nope")).is_true()
	board._tap(_sq(2, 2))
	board._tap(_sq(4, 4))  # Not one of its landing squares.
	assert_array(moved).is_empty()
	board._tap(_sq(2, 2))  # Put it back.
	assert_bool(board.targets().is_empty()).is_true()
	board._tap(_sq(4, 2))  # Pick another piece instead.
	assert_bool(board.targets().has(_sq(5, 3))).is_true()
	# A lesson can allow only one move.
	board._tap(_sq(4, 2))
	board.only_moves = [PackedInt32Array([_sq(6, 2), _sq(7, 3)])]
	assert_array(Array(board.movable())).is_equal([_sq(6, 2)])


func test_a_man_reaching_the_far_row_is_crowned_once_it_lands() -> void:
	board.set_state(_pos(C.ENGLISH, {Vector2i(2, 6): "b", Vector2i(5, 5): "r"}))
	board.play_move(PackedInt32Array([_sq(2, 6), _sq(1, 7)]))
	assert_bool(events.has("crown")).is_false()  # Not until it lands.
	await _settle()
	assert_bool(events.has("crown")).is_true()
	assert_int(board.state.board[_sq(1, 7)]).is_equal(C.BLACK_KING)


func test_a_tap_while_a_move_plays_skips_to_its_end() -> void:
	board.play_move(PackedInt32Array([_sq(2, 2), _sq(3, 3)]))
	assert_bool(board.busy).is_true()
	board._tap(_sq(5, 5))
	assert_bool(board.busy).is_false()
	assert_int(board.state.moves_played).is_equal(1)


func test_the_last_capture_ends_the_game() -> void:
	board.set_state(_pos(C.INTERNATIONAL, {Vector2i(0, 0): "B", Vector2i(3, 3): "r"}))
	board.play_move(PackedInt32Array([_sq(0, 0), _sq(5, 5)]))  # A flying king takes from afar.
	await _settle()
	assert_bool(events.has("end")).is_true()
	assert_int(C.result(board.state)).is_equal(C.WIN_0)
	board._tap(_sq(5, 5))  # The game is over: nothing more to pick.
	assert_bool(board.targets().is_empty()).is_true()


func test_the_preview_shows_a_board_without_taking_taps() -> void:
	var p: CheckersPreview = auto_free(CheckersPreview.create(C.new_game(), 300.0, true))
	add_child(p)
	p.size = Vector2(500, 300)
	await get_tree().process_frame
	assert_bool(p.board.interactive).is_false()
	assert_bool(Rect2(Vector2.ZERO, p.size).encloses(p.board.frame)).is_true()
