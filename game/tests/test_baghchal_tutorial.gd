extends GdUnitTestSuite
## Bagh-Chal lessons (BUILD_PLAN.md G3.6): the lesson data, playing them through by
## tapping, the first-play offer, and the ways in (game page, rules card).

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const TutorialScreen := preload("res://shell/screens/tutorial_screen.gd")
const GamePage := preload("res://shell/screens/game_page.gd")

var app: Node
var _saved := {}


func before_test() -> void:
	_saved = (Store.data["games"]["baghchal"] as Dictionary).duplicate(true)
	app = auto_free(load("res://main.tscn").instantiate())
	add_child(app)
	await get_tree().process_frame
	Modal.close_top(app)


func after_test() -> void:
	Store.data["games"]["baghchal"] = _saved
	Store.save_data()


func _top() -> Node:
	return app._stack[-1] if not app._stack.is_empty() else null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _texts(root: Node) -> Array:
	var out: Array = []
	for l in root.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out


func _buttons(root: Node) -> Dictionary:
	var out := {}
	for b in root.find_children("*", "Button", true, false):
		out[(b as Button).text] = b
	return out


func test_every_lesson_is_on_the_bagh_chal_board_with_twenty_goats() -> void:
	var steps := AadupuliTutorial.steps("baghchal")
	assert_int(steps.size()).is_equal(5)
	for step: Dictionary in steps:
		var s := AadupuliTutorial.position(step)
		assert_str(s.board).override_failure_message(step["title"]).is_equal("baghchal")
		assert_int(s.tigers.size()).is_equal(4)
		assert_int(R.goats_on_board(s) + s.in_hand + s.captured).override_failure_message(step["title"]).is_equal(20)
		assert_int(R.result(s)).override_failure_message(step["title"]).is_equal(R.ONGOING)
		assert_bool(AadupuliTutorial.accepted(step).is_empty()).override_failure_message(step["title"]).is_false()


func test_each_lesson_move_teaches_its_point() -> void:
	var steps := AadupuliTutorial.steps("baghchal")
	# Tigers step along lines: three ways out of the corner, diagonal included.
	assert_int(AadupuliTutorial.accepted(steps[1]).size()).is_equal(3)
	# The jump captures.
	var cap: Dictionary = steps[2]
	assert_int(R.apply(AadupuliTutorial.position(cap), AadupuliTutorial.accepted(cap)[0]).captured).is_equal(1)
	# Guarding leaves the tigers no capture.
	var guard: Dictionary = steps[3]
	var guarded := R.apply(AadupuliTutorial.position(guard), AadupuliTutorial.accepted(guard)[0])
	assert_bool(Array(R.legal_moves(guarded)).any(func(m: int) -> bool: return R.move_over(m) != R.NONE)).is_false()
	# The last goat step traps every tiger.
	var trap: Dictionary = steps[4]
	assert_int(R.result(R.apply(AadupuliTutorial.position(trap), AadupuliTutorial.accepted(trap)[0]))).is_equal(R.GOATS_WIN)


func test_the_lessons_play_through_by_tapping_and_lead_into_a_bagh_chal_game() -> void:
	Store.data["games"]["baghchal"]["tutorial_done"] = false
	var tiger_done := bool(Store.data["tutorial_done"])
	app.push(TutorialScreen.create("baghchal"))
	await _frames(2)
	var tut: Node = _top()
	assert_bool(_texts(tut).has("Learn Bagh-Chal")).is_true()
	var count := AadupuliTutorial.steps("baghchal").size()
	for i in count:
		var board: Node = tut.board
		assert_str(board.state.board).is_equal("baghchal")
		var m: int = board.only_moves[0]
		if R.move_from(m) != R.NONE:
			board._tap(R.move_from(m))
		board._tap(R.move_to(m))
		await _frames(1)
		assert_bool(tut._done_card.visible).override_failure_message("lesson %d not completed" % (i + 1)).is_true()
		if i < count - 1:
			tut._next()
			await _frames(1)
	assert_bool(bool(Store.data["games"]["baghchal"]["tutorial_done"])).is_true()
	assert_bool(bool(Store.data["tutorial_done"])).is_equal(tiger_done)  # Tiger & Goat's is its own.
	tut._first_game()
	await _frames(1)
	assert_str(_top().get_script().resource_path).ends_with("/play_screen.gd")
	assert_str(_top().board_id).is_equal("baghchal")
	assert_str(_top().board.state.board).is_equal("baghchal")


func test_the_first_play_offers_the_lessons_once() -> void:
	var g: Dictionary = Store.data["games"]["baghchal"]
	g["tutorial_done"] = false
	g["tutorial_offered"] = false
	g["played"] = 0
	Store.set_last("mode", "pass")
	app.push(GamePage.create("baghchal"))
	await _frames(2)
	var page: Node = _top()
	page._start()
	await _frames(1)
	assert_bool(_texts(app).has("New to Bagh-Chal?")).is_true()
	var buttons := _buttons(app)
	assert_bool(buttons.has("Learn first")).is_true()
	(buttons["Learn first"] as Button).pressed.emit()
	await _frames(2)
	assert_str(_top().get_script().resource_path).ends_with("tutorial_screen.gd")
	assert_str(_top().board_id).is_equal("baghchal")
	app.pop()
	await _frames(2)
	# Asked once only: the next Play goes straight to the game.
	page._start()
	await _frames(2)
	assert_str(_top().get_script().resource_path).ends_with("/play_screen.gd")


func test_the_page_and_rules_card_open_the_bagh_chal_lessons() -> void:
	app.push(GamePage.create("baghchal"))
	await _frames(2)
	assert_bool(_texts(_top()).has("Learn to play")).is_true()
	_top()._learn()
	await _frames(1)
	assert_str(_top().board_id).is_equal("baghchal")
	app.pop()
	await _frames(1)
	Modal.how_to_play(app, "baghchal")
	await _frames(1)
	var buttons := _buttons(app)
	assert_bool(buttons.has("Try the tutorial")).is_true()
	(buttons["Try the tutorial"] as Button).pressed.emit()
	await _frames(2)
	assert_str(_top().get_script().resource_path).ends_with("tutorial_screen.gd")
	assert_str(_top().board_id).is_equal("baghchal")


func test_a_piece_lands_on_its_point_when_the_board_resizes_mid_move() -> void:
	# A lesson's result card appears as the move animates and shrinks the board.
	var board: Node = auto_free(preload("res://games/aadupuli/board/board_view.gd").new())
	add_child(board)
	board.layout(Vector2(1000, 1400))
	board.new_game({"board": "baghchal"})
	board.play_move(R.encode(R.NONE, 12, R.NONE))
	board.play_move(R.encode(0, 6, R.NONE))
	board.layout(Vector2(1000, 1100))
	await get_tree().create_timer(0.6).timeout
	assert_vector((board.pieces[6] as Node2D).position).is_equal_approx(board.point_pos(6), Vector2(0.5, 0.5))
