extends GdUnitTestSuite
## Four in a Row lessons (BUILD_PLAN.md G4.6): the lesson positions, playing them through
## by tapping, the first-play offer, and the ways in (game page, rules card).

const F := preload("res://games/fourinrow/four_rules.gd")
const TutorialScreen := preload("res://shell/screens/four_tutorial_screen.gd")
const GamePage := preload("res://shell/screens/four_game_page.gd")

var app: Node
var _saved := {}
var _saved_last := {}


func before_test() -> void:
	_saved = (Store.data["games"]["fourinrow"] as Dictionary).duplicate(true)
	_saved_last = (Store.data["last"] as Dictionary).duplicate(true)
	app = auto_free(load("res://main.tscn").instantiate())
	add_child(app)
	await get_tree().process_frame
	Modal.close_top(app)


func after_test() -> void:
	Store.data["games"]["fourinrow"] = _saved
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


## True if cream, moving now, could make four at once.
func _cream_wins_now(s: F.State) -> bool:
	var c := s.copy()
	c.turn = 1
	for m in F.legal_moves(c):
		if F.result(F.after(c, m)) == F.WIN_1:
			return true
	return false


func test_every_lesson_is_a_fair_position_with_orange_to_move() -> void:
	var steps := FourTutorial.steps()
	assert_int(steps.size()).is_equal(4)
	for step: Dictionary in steps:
		var s := FourTutorial.position(step)
		var name_of: String = step["title"]
		var orange := 0
		var cream := 0
		for col in F.COLS:
			for row in F.ROWS:
				match F.owner_at(s, col, row):
					0: orange += 1
					1: cream += 1
		assert_int(orange).override_failure_message(name_of).is_equal(cream)  # Orange moved first, so it's orange's turn.
		assert_int(s.turn).is_equal(0)
		assert_int(F.result(s)).override_failure_message(name_of).is_equal(F.ONGOING)
		assert_bool(FourTutorial.accepted(step).is_empty()).override_failure_message(name_of).is_false()
		for c in FourTutorial.focus_cells(step):
			assert_bool(c >= 0 and c < F.CELLS).is_true()


func test_each_lesson_move_teaches_its_point() -> void:
	for step: Dictionary in FourTutorial.steps():
		var s := FourTutorial.position(step)
		var name_of: String = step["title"]
		for m in FourTutorial.accepted(step):
			var after := F.after(s, m)
			if step["wins"]:
				assert_int(F.result(after)).override_failure_message(name_of).is_equal(F.WIN_0)
			else:
				assert_int(F.result(after)).override_failure_message(name_of).is_equal(F.ONGOING)
				assert_bool(_cream_wins_now(after)).override_failure_message(name_of + ": cream can still win").is_false()
		# No distracting threat from cream in the lessons where you make four.
		if step["wins"]:
			assert_bool(_cream_wins_now(s)).override_failure_message(name_of).is_false()
	# The blocking lesson really has a threat to block.
	var block: Dictionary = FourTutorial.steps()[2]
	assert_bool(_cream_wins_now(FourTutorial.position(block))).is_true()


func test_the_lessons_play_through_by_tapping_and_lead_into_a_game() -> void:
	Store.data["games"]["fourinrow"]["tutorial_done"] = false
	app.push(TutorialScreen.create())
	await _frames(2)
	var tut: Node = _top()
	assert_bool(_texts(tut).has("Learn Four in a Row")).is_true()
	var count := FourTutorial.steps().size()
	for i in count:
		var board: Node = tut.board
		board._tap(board.only_moves[0])
		for k in 120:
			await get_tree().process_frame
			if tut._done_card.visible:
				break
		assert_bool(tut._done_card.visible).override_failure_message("lesson %d not completed" % (i + 1)).is_true()
		if i < count - 1:
			tut._next()
			await _frames(1)
	assert_bool(bool(Store.data["games"]["fourinrow"]["tutorial_done"])).is_true()
	tut._first_game()
	await _frames(1)
	assert_str(_top().get_script().resource_path).ends_with("four_play_screen.gd")
	assert_int(_top().me).is_equal(0)
	assert_str(_top().level).is_equal("easy")


func test_a_lesson_refuses_columns_that_do_not_teach_it() -> void:
	app.push(TutorialScreen.create())
	await _frames(2)
	var tut: Node = _top()
	tut.step_index = 2  # "Block their three": only the block is allowed.
	tut._show_step()
	tut.board._tap(0)
	assert_int(tut.board.state.moves_played).is_equal(6)
	assert_bool(tut._done_card.visible).is_false()


func test_the_first_play_offers_the_lessons_once() -> void:
	var g: Dictionary = Store.data["games"]["fourinrow"]
	g["tutorial_done"] = false
	g["tutorial_offered"] = false
	g["played"] = 0
	Store.set_last("mode", "pass")
	app.push(GamePage.create("fourinrow"))
	await _frames(2)
	var page: Node = _top()
	assert_bool(_texts(page).has("Learn to play")).is_true()
	page._start()
	await _frames(1)
	assert_bool(_texts(app).has("New to Four in a Row?")).is_true()
	(_buttons(app)["Learn first"] as Button).pressed.emit()
	await _frames(2)
	assert_str(_top().get_script().resource_path).ends_with("four_tutorial_screen.gd")
	app.pop()
	await _frames(2)
	page._start()  # Asked once only.
	await _frames(2)
	assert_str(_top().get_script().resource_path).ends_with("four_play_screen.gd")


func test_the_rules_card_opens_the_lessons() -> void:
	Games.how_to_play(app, "fourinrow")
	await _frames(1)
	(_buttons(app)["Try the tutorial"] as Button).pressed.emit()
	await _frames(2)
	assert_str(_top().get_script().resource_path).ends_with("four_tutorial_screen.gd")
