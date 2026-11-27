extends GdUnitTestSuite
## The Four in a Row board view (BUILD_PLAN.md G4.2): layout, tapping a column, the
## falling disc, the winning highlight, and moves that aren't allowed.

const F := preload("res://games/fourinrow/four_rules.gd")
const Board := preload("res://games/fourinrow/board/four_board_view.gd")

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
	board.human_moved.connect(func(col: int) -> void: moved.append(col))


func _settle() -> void:
	for i in 120:
		if not board.busy:
			return
		await get_tree().process_frame


func test_the_frame_fits_its_area_with_room_above_to_drop_from() -> void:
	assert_bool(Rect2(Vector2.ZERO, Vector2(1000, 1300)).encloses(board.frame)).is_true()
	assert_float(board.frame.position.y).is_greater(board.cell * 0.9)
	# Columns run left to right, rows bottom to top.
	assert_float(board.cell_pos(1, 0).x).is_greater(board.cell_pos(0, 0).x)
	assert_float(board.cell_pos(0, 1).y).is_less(board.cell_pos(0, 0).y)
	assert_bool(board.frame.has_point(board.cell_pos(0, 0))).is_true()
	assert_bool(board.frame.has_point(board.cell_pos(6, 5))).is_true()


func test_a_tap_anywhere_in_a_column_or_just_above_picks_that_column() -> void:
	for col in F.COLS:
		assert_int(board.column_at(board.cell_pos(col, 0))).is_equal(col)
		assert_int(board.column_at(board.cell_pos(col, 5))).is_equal(col)
		assert_int(board.column_at(board.cell_pos(col, 5) - Vector2(0, board.cell * 1.2))).is_equal(col)
	assert_int(board.column_at(Vector2(2, board.cell_pos(0, 0).y))).is_equal(-1)  # Off the side.
	assert_int(board.column_at(Vector2(500, 5))).is_equal(-1)  # Far above.


func test_tapping_a_column_drops_a_disc_that_falls_and_lands() -> void:
	board._tap(3)
	assert_array(moved).is_equal([3])
	assert_bool(board.busy).is_true()
	assert_int(F.owner_at(board.state, 3, 0)).is_equal(0)
	assert_int(board.state.turn).is_equal(1)
	await _settle()
	assert_bool(board.busy).is_false()
	assert_array(events).is_equal(["drop", "land"])


func test_moves_that_are_not_allowed_are_refused() -> void:
	for i in 6:
		board.play_move(0)
		board.skip()
	board._tap(0)  # Full column.
	assert_array(moved).is_empty()
	assert_bool(events.has("nope")).is_true()
	board.only_moves = PackedInt32Array([4])  # A lesson allows only column 4.
	board._tap(2)
	assert_array(moved).is_empty()
	board._tap(4)
	assert_array(moved).is_equal([4])


func test_a_tap_while_a_disc_falls_skips_to_where_it_lands() -> void:
	board._tap(5)
	assert_bool(board.busy).is_true()
	board._tap(1)  # Skips the first disc; does not drop a second one.
	assert_bool(board.busy).is_false()
	assert_int(board.state.moves_played).is_equal(1)
	assert_array(moved).is_equal([5])


func test_the_winning_four_light_up_once_the_last_disc_lands() -> void:
	for c: int in [0, 0, 1, 1, 2, 2]:
		board.play_move(c)
		board.skip()
	events.clear()
	board.play_move(3)
	assert_bool(board._win_cells.is_empty()).is_true()  # Not until it lands.
	await _settle()
	assert_array(events).is_equal(["drop", "land", "win"])
	assert_int(board._win_cells.size()).is_equal(4)
	board._tap(4)  # The game is over: nothing more to drop.
	assert_int(board.state.moves_played).is_equal(7)


func test_set_state_shows_a_position_at_once_with_its_win() -> void:
	var s := F.from_dict({"columns": [[1, 1, 1, 1], [0], [0], [0], [], [], []], "turn": 0})
	board.set_state(s)
	assert_bool(board.busy).is_false()
	assert_int(board._win_cells.size()).is_equal(4)
	board.set_state(F.new_game())
	assert_bool(board._win_cells.is_empty()).is_true()


func test_the_preview_shows_a_board_without_taking_taps() -> void:
	var p: FourPreview = auto_free(FourPreview.create(F.new_game(), 300.0, true))
	add_child(p)
	p.size = Vector2(500, 300)
	await get_tree().process_frame
	assert_bool(p.board.interactive).is_false()
	assert_bool(Rect2(Vector2.ZERO, p.size).encloses(p.board.frame)).is_true()
