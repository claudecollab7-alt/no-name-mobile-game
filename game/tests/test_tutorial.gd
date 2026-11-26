extends GdUnitTestSuite
## The "learn by playing" tutorial: lesson data, the screen, and placing with hints off.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const BoardView := preload("res://games/aadupuli/board/board_view.gd")
const TutorialScreen := preload("res://shell/screens/tutorial_screen.gd")

var app: Node


func before_test() -> void:
	app = auto_free(load("res://main.tscn").instantiate())
	add_child(app)
	await get_tree().process_frame
	Modal.close_top(app)


func _top() -> Node:
	return app._stack[-1] if not app._stack.is_empty() else null


func test_every_lesson_has_a_valid_position_and_moves_to_accept() -> void:
	for step: Dictionary in AadupuliTutorial.steps():
		var s := AadupuliTutorial.position(step)
		assert_int(R.goats_on_board(s) + s.in_hand + s.captured).override_failure_message(step["title"]).is_equal(15)
		assert_int(R.result(s)).override_failure_message(step["title"]).is_equal(R.ONGOING)
		assert_bool(AadupuliTutorial.accepted(step).is_empty()).override_failure_message(step["title"]).is_false()


func test_the_capture_lesson_captures_and_the_trap_lesson_wins() -> void:
	var steps := AadupuliTutorial.steps()
	var cap: Dictionary = steps[2]
	var after_cap := R.apply(AadupuliTutorial.position(cap), AadupuliTutorial.accepted(cap)[0])
	assert_int(after_cap.captured).is_equal(1)
	var trap: Dictionary = steps[4]
	var after_trap := R.apply(AadupuliTutorial.position(trap), AadupuliTutorial.accepted(trap)[0])
	assert_int(R.result(after_trap)).is_equal(R.GOATS_WIN)


func test_the_tutorial_can_be_played_from_start_to_finish_by_tapping() -> void:
	Store.data["tutorial_done"] = false
	app.push(TutorialScreen.new())
	await get_tree().process_frame
	await get_tree().process_frame
	var tut: Node = _top()
	for i in AadupuliTutorial.steps().size():
		var board: Node = tut.board
		var m: int = board.only_moves[0]
		if R.move_from(m) != R.NONE:
			board._tap(R.move_from(m))
		board._tap(R.move_to(m))
		await get_tree().process_frame
		assert_bool(tut._done_card.visible).override_failure_message("lesson %d not completed" % (i + 1)).is_true()
		if i < AadupuliTutorial.steps().size() - 1:
			tut._next()
			await get_tree().process_frame
	assert_bool(bool(Store.data["tutorial_done"])).is_true()
	tut._first_game()
	await get_tree().process_frame
	assert_str(_top().get_script().resource_path).ends_with("play_screen.gd")


func test_tutorial_refuses_moves_that_do_not_teach_the_lesson() -> void:
	app.push(TutorialScreen.new())
	await get_tree().process_frame
	var tut: Node = _top()
	tut.step_index = 2  # "Jump to capture": only the jump is allowed.
	tut._show_step()
	var board: Node = tut.board
	board._tap(4)  # Another tiger...
	board._tap(10)  # ...stepping somewhere else.
	assert_int(board.state.moves_played).is_equal(0)
	assert_bool(tut._done_card.visible).is_false()


func test_goats_can_be_placed_with_move_hints_switched_off() -> void:
	var board := BoardView.new()
	board.show_hints = false
	add_child(auto_free(board))
	board.layout(Vector2(1000, 1400))
	board.new_game()
	board._tap(19)
	assert_bool(R.goat_at(board.state, 19)).is_true()
