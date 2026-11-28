extends GdUnitTestSuite
## Reversi lessons (BUILD_PLAN.md G5.6): each lesson's position and moves teach what it
## says, playing them through by tapping, the first-play offer, and the ways in (game
## page, rules card).

const R := preload("res://games/reversi/reversi_rules.gd")
const TutorialScreen := preload("res://shell/screens/reversi_tutorial_screen.gd")
const GamePage := preload("res://shell/screens/reversi_game_page.gd")
const DIRS := [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, 1], [1, -1], [-1, -1]]

var app: Node
var _saved := {}
var _saved_last := {}


func before_test() -> void:
	_saved = (Store.data["games"]["reversi"] as Dictionary).duplicate(true)
	_saved_last = (Store.data["last"] as Dictionary).duplicate(true)
	app = auto_free(load("res://main.tscn").instantiate())
	add_child(app)
	await get_tree().process_frame
	Modal.close_top(app)


func after_test() -> void:
	Store.data["games"]["reversi"] = _saved
	Store.data["last"] = _saved_last
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


## How many directions a move at `sq` flips in, counted square by square.
func _directions(s: R.State, sq: int) -> int:
	var n := 0
	var col := sq % 8
	var row := floori(sq / 8.0)
	for d: Array in DIRS:
		var c: int = col + d[0]
		var r: int = row + d[1]
		var run := 0
		while c >= 0 and c < 8 and r >= 0 and r < 8 and R.owner_at(s, c, r) == 1:
			run += 1
			c += d[0]
			r += d[1]
		if run > 0 and c >= 0 and c < 8 and r >= 0 and r < 8 and R.owner_at(s, c, r) == 0:
			n += 1
	return n


func test_every_lesson_is_a_live_position_with_orange_to_move() -> void:
	var steps := ReversiTutorial.steps()
	assert_int(steps.size()).is_equal(5)
	for step: Dictionary in steps:
		var s := ReversiTutorial.position(step)
		var name_of: String = step["title"]
		assert_int(s.turn).is_equal(0)
		assert_int(R.result(s)).override_failure_message(name_of).is_equal(R.ONGOING)
		assert_bool(ReversiTutorial.accepted(step).is_empty()).override_failure_message(name_of).is_false()
		assert_bool(ReversiTutorial.accepted(step).has(R.PASS)).is_false()
		for c in ReversiTutorial.focus_cells(step):
			assert_bool(ReversiTutorial.accepted(step).has(c)).override_failure_message(name_of).is_true()
	# The first lesson is the real starting position.
	var first := ReversiTutorial.position(steps[0])
	assert_array(Array(first.bits)).is_equal(Array(R.new_game().bits))


func test_each_lesson_move_teaches_its_point() -> void:
	for step: Dictionary in ReversiTutorial.steps():
		var s := ReversiTutorial.position(step)
		var name_of: String = step["title"]
		for m in ReversiTutorial.accepted(step):
			var flipped := R.after(s, m)
			var count := R.discs(flipped, 0) - R.discs(s, 0) - 1
			match str(step["check"]):
				"flip":
					assert_int(count).override_failure_message(name_of).is_greater(0)
				"line":
					assert_int(count).override_failure_message(name_of).is_greater_equal(3)
				"many":
					assert_int(_directions(s, m)).override_failure_message(name_of).is_greater_equal(5)
				"corner":
					assert_bool(m in [0, 7, 56, 63]).override_failure_message(name_of).is_true()
				"pass":
					assert_array(Array(R.legal_moves(flipped))).override_failure_message(name_of).is_equal([R.PASS])
				_:
					fail("unknown check in " + name_of)


func test_the_lessons_play_through_by_tapping_and_lead_into_a_game() -> void:
	Store.data["games"]["reversi"]["tutorial_done"] = false
	app.push(TutorialScreen.create())
	await _frames(2)
	var tut: Node = _top()
	assert_bool(_texts(tut).has("Learn Reversi")).is_true()
	var count := ReversiTutorial.steps().size()
	for i in count:
		var board: Node = tut.board
		board._tap(board.only_moves[0])
		for k in 200:
			await get_tree().process_frame
			if tut._done_card.visible:
				break
		assert_bool(tut._done_card.visible).override_failure_message("lesson %d not completed" % (i + 1)).is_true()
		if i < count - 1:
			tut._next()
			await _frames(1)
	# In the last lesson, cream's pass is shown on the board.
	assert_int(tut.board.state.last_move).is_equal(R.PASS)
	assert_int(tut.board.state.turn).is_equal(0)
	assert_bool(bool(Store.data["games"]["reversi"]["tutorial_done"])).is_true()
	tut._first_game()
	await _frames(1)
	assert_str(_top().get_script().resource_path).ends_with("reversi_play_screen.gd")
	assert_int(_top().me).is_equal(0)
	assert_str(_top().level).is_equal("easy")


func test_a_lesson_refuses_squares_that_do_not_teach_it() -> void:
	app.push(TutorialScreen.create())
	await _frames(2)
	var tut: Node = _top()
	tut.step_index = 3  # "Corners are safe": only the corner is allowed.
	tut._show_step()
	var other := -1
	for m in R.legal_moves(tut.board.state):
		if m != 0:
			other = m
	assert_int(other).is_not_equal(-1)  # There is another legal move to refuse.
	tut.board._tap(other)
	assert_int(R.discs(tut.board.state, 0)).is_equal(R.discs(ReversiTutorial.position(ReversiTutorial.steps()[3]), 0))
	assert_bool(tut._done_card.visible).is_false()


func test_the_first_play_offers_the_lessons_once() -> void:
	var g: Dictionary = Store.data["games"]["reversi"]
	g["tutorial_done"] = false
	g["tutorial_offered"] = false
	g["played"] = 0
	Store.set_last("mode", "pass")
	app.push(GamePage.create("reversi"))
	await _frames(2)
	var page: Node = _top()
	assert_bool(_texts(page).has("Learn to play")).is_true()
	page._start()
	await _frames(1)
	assert_bool(_texts(app).has("New to Reversi?")).is_true()
	(_buttons(app)["Learn first"] as Button).pressed.emit()
	await _frames(2)
	assert_str(_top().get_script().resource_path).ends_with("reversi_tutorial_screen.gd")
	app.pop()
	await _frames(2)
	page._start()  # Asked once only.
	await _frames(2)
	assert_str(_top().get_script().resource_path).ends_with("reversi_play_screen.gd")


func test_the_rules_card_opens_the_lessons() -> void:
	Games.how_to_play(app, "reversi")
	await _frames(1)
	(_buttons(app)["Try the tutorial"] as Button).pressed.emit()
	await _frames(2)
	assert_str(_top().get_script().resource_path).ends_with("reversi_tutorial_screen.gd")
