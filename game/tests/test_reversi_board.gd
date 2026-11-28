extends GdUnitTestSuite
## The Reversi board view (BUILD_PLAN.md G5.2): layout, tapping a square, discs turning
## over one after another, the glowing dots, passing, and moves that aren't allowed.

const R := preload("res://games/reversi/reversi_rules.gd")
const Board := preload("res://games/reversi/board/reversi_board_view.gd")

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
	board.human_moved.connect(func(sq: int) -> void: moved.append(sq))


func _settle() -> void:
	for i in 120:
		if not board.busy:
			return
		await get_tree().process_frame


## Rows from the TOP down, as they read on screen.
func _pos(top_down: Array, turn := 0) -> R.State:
	var rows := top_down.duplicate()
	rows.reverse()
	return R.from_dict({"rows": rows, "turn": turn})


func test_the_tray_is_square_and_fits_its_area() -> void:
	assert_bool(Rect2(Vector2.ZERO, Vector2(1000, 1300)).encloses(board.frame)).is_true()
	assert_float(board.frame.size.x).is_equal_approx(board.frame.size.y, 0.01)
	# Columns run left to right, rows bottom to top.
	assert_float(board.cell_pos(1, 0).x).is_greater(board.cell_pos(0, 0).x)
	assert_float(board.cell_pos(0, 1).y).is_less(board.cell_pos(0, 0).y)


func test_a_tap_anywhere_in_a_square_picks_that_square() -> void:
	for sq in R.CELLS:
		var c := board.square_pos(sq)
		assert_int(board.square_at(c)).is_equal(sq)
		assert_int(board.square_at(c + Vector2(board.cell * 0.45, -board.cell * 0.45))).is_equal(sq)
	assert_int(board.square_at(board.frame.position + Vector2(2, 2))).is_equal(-1)  # The wooden border.
	assert_int(board.square_at(Vector2(500, 5))).is_equal(-1)  # Off the tray.


func test_the_dots_show_the_legal_moves_only_when_hints_are_on() -> void:
	assert_array(Array(board.hint_squares())).is_equal(Array(R.legal_moves(board.state)))
	board.show_hints = false
	assert_array(Array(board.hint_squares())).is_empty()
	board.show_hints = true
	board.interactive = false  # The computer's turn.
	assert_array(Array(board.hint_squares())).is_empty()


func test_tapping_a_legal_square_places_a_disc_and_turns_the_trapped_ones() -> void:
	var m: int = R.legal_moves(board.state)[0]
	board._tap(m)
	assert_array(moved).is_equal([m])
	assert_bool(board.busy).is_true()
	assert_int(R.discs(board.state, 0)).is_equal(4)
	assert_int(board.state.turn).is_equal(1)
	assert_array(Array(board.hint_squares())).is_empty()  # No dots while discs turn.
	await _settle()
	assert_bool(board.busy).is_false()
	assert_array(events).is_equal(["place", "flip"])


func test_discs_farther_along_a_line_turn_later() -> void:
	# Orange plays (0,3), flipping three cream discs to the right in a row.
	board.set_state(_pos([
		"........",
		"........",
		"........",
		"........",
		".1110...",
		"........",
		"........",
		"........",
	]))
	board.play_move(R.cell(0, 3))
	var near: float = board._flips[R.cell(1, 3)]
	var mid: float = board._flips[R.cell(2, 3)]
	var far: float = board._flips[R.cell(3, 3)]
	assert_float(mid).is_greater(near)
	assert_float(far).is_greater(mid)
	board.skip()
	assert_bool(board.busy).is_false()
	assert_int(R.discs(board.state, 1)).is_equal(0)


func test_squares_that_are_not_allowed_are_refused() -> void:
	board._tap(0)  # A corner, far from any disc.
	assert_array(moved).is_empty()
	assert_bool(events.has("nope")).is_true()
	board._tap(R.cell(3, 3))  # Taken.
	assert_array(moved).is_empty()
	var legal := R.legal_moves(board.state)
	board.only_moves = PackedInt32Array([legal[1]])  # A lesson allows only one square.
	board._tap(legal[0])
	assert_array(moved).is_empty()
	board._tap(legal[1])
	assert_array(moved).is_equal([legal[1]])


func test_a_tap_while_discs_turn_skips_to_the_end() -> void:
	board._tap(R.legal_moves(board.state)[0])
	assert_bool(board.busy).is_true()
	board._tap(R.legal_moves(board.state)[0])  # Skips; does not play a second move.
	assert_bool(board.busy).is_false()
	assert_int(board.state.moves_played).is_equal(1)
	assert_int(moved.size()).is_equal(1)


func test_a_pass_and_the_end_of_the_game_are_announced() -> void:
	# Cream to move has nothing; orange can still play.
	board.set_state(_pos(["........", "........", "........", "........", "........", "........", ".1......", "0......."], 1))
	board.play_move(R.PASS)
	assert_bool(board.busy).is_false()
	assert_int(board.state.turn).is_equal(0)
	board.play_move(R.cell(2, 2))  # Orange takes the last cream disc: nobody can move.
	await _settle()
	assert_array(events).is_equal(["pass", "place", "flip", "end"])


func test_undo_keeps_the_position_before_the_move() -> void:
	var seen: Array = []
	board.before_move.connect(func(s: R.State) -> void: seen.append(s))
	board._tap(R.legal_moves(board.state)[0])
	assert_int(seen.size()).is_equal(1)
	var prev: R.State = seen[0]
	assert_int(prev.moves_played).is_equal(0)
	assert_int(R.discs(prev, 0)).is_equal(2)


func test_the_preview_shows_a_board_without_taking_taps() -> void:
	var p: ReversiPreview = auto_free(ReversiPreview.create(R.new_game(), 300.0, true))
	add_child(p)
	p.size = Vector2(500, 300)
	await get_tree().process_frame
	assert_bool(p.board.interactive).is_false()
	assert_bool(Rect2(Vector2.ZERO, p.size).encloses(p.board.frame)).is_true()
