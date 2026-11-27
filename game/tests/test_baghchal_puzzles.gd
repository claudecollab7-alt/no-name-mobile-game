extends GdUnitTestSuite
## Bagh-Chal puzzles (BUILD_PLAN.md G3.7): every one proven to have exactly one right
## first move, solvable against the toughest defence; the page card, the puzzle screen,
## and solved puzzles remembered in order, easiest first.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const PuzzleScreen := preload("res://shell/screens/puzzle_screen.gd")
const GamePage := preload("res://shell/screens/game_page.gd")

var app: Node
var _saved: Array = []


func before_test() -> void:
	_saved = (Store.puzzles_solved("baghchal") as Array).duplicate()
	app = auto_free(load("res://main.tscn").instantiate())
	add_child(app)
	await get_tree().process_frame
	Modal.close_top(app)


func after_test() -> void:
	Store.data["games"]["baghchal"]["puzzles_solved"] = _saved
	Store.save_data()


func _top() -> Node:
	return app._stack[-1] if not app._stack.is_empty() else null


func _texts(root: Node) -> Array:
	var out: Array = []
	for l in root.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out


func test_there_are_enough_puzzles_of_every_kind_on_the_bagh_chal_board() -> void:
	var all: Array = BaghchalPuzzleData.PUZZLES
	assert_int(all.size()).is_greater_equal(100)
	for goal in ["safe", "capture", "trap"]:
		assert_bool(all.any(func(p: Dictionary) -> bool: return p["goal"] == goal)).override_failure_message("no %s puzzles" % goal).is_true()
	assert_bool(all.any(func(p: Dictionary) -> bool: return p["goal"] == "trap" and int(p["n"]) == 2)).override_failure_message("no trap in 2").is_true()
	for i in all.size():
		assert_int(int(all[i]["id"])).is_equal(i + 1)
		if i > 0:
			assert_bool(int(all[i]["difficulty"]) >= int(all[i - 1]["difficulty"])).override_failure_message("not easiest first").is_true()


func test_every_puzzle_has_one_answer_and_can_be_solved_against_the_best_defence() -> void:
	for p: Dictionary in BaghchalPuzzleData.PUZZLES:
		var s := AadupuliPuzzles.position(p)
		var label := "puzzle %d" % int(p["id"])
		assert_str(s.board).override_failure_message(label).is_equal("baghchal")
		assert_int(s.tigers.size()).override_failure_message(label).is_equal(4)
		assert_int(R.goats_on_board(s) + s.in_hand + s.captured).override_failure_message(label).is_equal(20)
		assert_int(R.result(s)).override_failure_message(label).is_equal(R.ONGOING)
		var wins := AadupuliPuzzles.winning_moves(p, s, int(p["n"]))
		assert_array(Array(wins)).override_failure_message(label + " should have exactly its answer").is_equal([int(p["answer"])])
		var left := int(p["n"])
		var move := int(p["answer"])
		var solved := false
		for i in left:
			var prev := s
			s = R.apply(s, move)
			if AadupuliPuzzles.is_solved(p, prev, s):
				solved = true
				break
			left -= 1
			s = R.apply(s, AadupuliPuzzles.toughest_reply(p, s, left))
			var next := AadupuliPuzzles.winning_moves(p, s, left)
			assert_bool(next.is_empty()).override_failure_message(label + " lost its forced line").is_false()
			move = next[0]
		assert_bool(solved).override_failure_message(label + " was not solved in time").is_true()


func test_the_page_card_opens_the_first_unsolved_puzzle_and_solving_moves_on() -> void:
	Store.data["games"]["baghchal"]["puzzles_solved"] = []
	app.push(GamePage.create("baghchal"))
	await get_tree().process_frame
	await get_tree().process_frame
	var page: Node = _top()
	var total := BaghchalPuzzleData.PUZZLES.size()
	assert_bool(_texts(page).has("%d puzzles, easiest first  ·  0 solved" % total)).is_true()
	page._open_puzzles()
	await get_tree().process_frame
	await get_tree().process_frame
	var screen: Node = _top()
	assert_str(screen.get_script().resource_path).ends_with("puzzle_screen.gd")
	assert_int(int(screen.puzzle["id"])).is_equal(1)
	assert_str(screen.board.state.board).is_equal("baghchal")
	assert_bool(_texts(screen).has("Bagh-Chal puzzle 1")).is_true()
	# Solve it with the answer (puzzle 1 is a one-move puzzle, easiest first).
	var a := int(screen.puzzle["answer"])
	if R.move_from(a) != R.NONE:
		screen.board._tap(R.move_from(a))
	screen.board._tap(R.move_to(a))
	await get_tree().process_frame
	assert_bool(screen._end_card.visible).is_true()
	assert_array(Store.puzzles_solved("baghchal")).contains([1])
	# Next puzzle is the next unsolved one, still Bagh-Chal.
	var next_button: Button = null
	for b in screen.find_children("*", "Button", true, false):
		if (b as Button).text == "Next puzzle":
			next_button = b
	assert_object(next_button).is_not_null()
	next_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(int(_top().puzzle["id"])).is_equal(2)
	assert_str(_top().game).is_equal("baghchal")
	# Back on the page, the count is up to date.
	app.pop()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(_texts(page).has("%d puzzles, easiest first  ·  1 solved" % total)).is_true()


func test_tiger_and_goat_has_no_puzzle_card_on_its_page() -> void:
	# Its puzzles live in the daily puzzle.
	app.push(GamePage.create("aadupuli"))
	await get_tree().process_frame
	assert_bool(_texts(_top()).has("Puzzles")).is_false()
