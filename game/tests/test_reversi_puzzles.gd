extends GdUnitTestSuite
## Reversi puzzles (BUILD_PLAN.md G5.7): every one has exactly one right first move
## (proven by the quick bitboard search, and again for the short ones by a plain search
## on the game rules), the endings can be won against the best defence, and the page
## card and puzzle screen work through them in order.

const R := preload("res://games/reversi/reversi_rules.gd")
const PuzzleScreen := preload("res://shell/screens/reversi_puzzle_screen.gd")
const GamePage := preload("res://shell/screens/reversi_game_page.gd")

var app: Node
var _saved: Array = []


func before_test() -> void:
	_saved = (Store.puzzles_solved("reversi") as Array).duplicate()
	app = auto_free(load("res://main.tscn").instantiate())
	add_child(app)
	await get_tree().process_frame
	Modal.close_top(app)


func after_test() -> void:
	Store.data["games"]["reversi"]["puzzles_solved"] = _saved
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


## The final disc difference for the player to move with best play, trying every line
## on the plain rules.
func _plain_best(s: R.State) -> int:
	if R.result(s) != R.ONGOING:
		return R.discs(s, s.turn) - R.discs(s, 1 - s.turn)
	var best := -99
	for m in R.legal_moves(s):
		best = maxi(best, -_plain_best(R.after(s, m)))
	return best


func test_there_are_enough_puzzles_of_every_kind_easiest_first() -> void:
	var all := ReversiPuzzleData.PUZZLES
	assert_int(all.size()).is_equal(130)
	var by_level := {}
	var last := 0
	for i in all.size():
		var p: Dictionary = all[i]
		assert_int(int(p["id"])).is_equal(i + 1)
		assert_int(int(p["difficulty"])).is_greater_equal(last)
		last = int(p["difficulty"])
		by_level[last] = int(by_level.get(last, 0)) + 1
	assert_dict(by_level).is_equal({1: 25, 2: 30, 3: 30, 4: 25, 5: 20})
	assert_int(all.filter(func(p: Dictionary) -> bool: return p["goal"] == "pass").size()).is_equal(25)
	# Both colours get puzzles.
	assert_int(all.filter(func(p: Dictionary) -> bool: return int(p["turn"]) == 1).size()).is_greater(20)


func test_every_puzzle_has_exactly_one_answer() -> void:
	for p: Dictionary in ReversiPuzzleData.PUZZLES:
		var s := ReversiPuzzles.position(p)
		var label := "puzzle %d" % int(p["id"])
		assert_int(R.result(s)).override_failure_message(label).is_equal(R.ONGOING)
		assert_int(ReversiPuzzles.empties(s)).override_failure_message(label).is_equal(int(p["empties"]))
		assert_int(R.legal_moves(s).size()).override_failure_message(label).is_greater_equal(3)
		var good := ReversiPuzzles.good_moves(p, s)
		assert_array(Array(good)).override_failure_message(label).is_equal([int(p["answer"])])


func test_plain_rules_agree_with_the_short_answers() -> void:
	var checked := 0
	for p: Dictionary in ReversiPuzzleData.PUZZLES:
		var s := ReversiPuzzles.position(p)
		var label := "puzzle %d" % int(p["id"])
		if p["goal"] == "pass":
			for m in R.legal_moves(s):
				var leaves_pass := Array(R.legal_moves(R.after(s, m))) == [R.PASS]
				assert_bool(leaves_pass).override_failure_message(label).is_equal(m == int(p["answer"]))
			checked += 1
		elif int(p["empties"]) <= 6:
			for m in R.legal_moves(s):
				var wins := -_plain_best(R.after(s, m)) > 0
				assert_bool(wins).override_failure_message("%s, move %d" % [label, m]).is_equal(m == int(p["answer"]))
			checked += 1
	assert_int(checked).is_greater_equal(40)


func test_the_page_card_opens_the_first_unsolved_puzzle_and_solving_moves_on() -> void:
	Store.data["games"]["reversi"]["puzzles_solved"] = []
	app.push(GamePage.create("reversi"))
	await _frames(2)
	var page: Node = _top()
	var total := ReversiPuzzleData.PUZZLES.size()
	assert_bool(_texts(page).has("%d puzzles, easiest first  ·  0 solved" % total)).is_true()
	page._open_puzzles()
	await _frames(2)
	var screen: Node = _top()
	assert_str(screen.get_script().resource_path).ends_with("reversi_puzzle_screen.gd")
	assert_int(int(screen.puzzle["id"])).is_equal(1)
	assert_bool(_texts(screen).has("Reversi puzzle 1")).is_true()
	screen.board._tap(int(screen.puzzle["answer"]))  # Puzzle 1 is a one-move "make them pass".
	await _frames(1)
	assert_bool(screen._end_card.visible).is_true()
	assert_array(Store.puzzles_solved("reversi")).contains([1])
	var next_button: Button = null
	for b in screen.find_children("*", "Button", true, false):
		if (b as Button).text == "Next puzzle":
			next_button = b
	next_button.pressed.emit()
	await _frames(2)
	assert_int(int(_top().puzzle["id"])).is_equal(2)
	app.pop()
	await _frames(2)
	assert_bool(_texts(page).has("%d puzzles, easiest first  ·  1 solved" % total)).is_true()


func test_a_wrong_move_is_explained_and_counts_a_try() -> void:
	var p: Dictionary = ReversiPuzzleData.PUZZLES[0]
	app.push(PuzzleScreen.create(p))
	await _frames(2)
	var screen: Node = _top()
	var wrong := -1
	for m in R.legal_moves(screen.board.state):
		if m != int(p["answer"]):
			wrong = m
			break
	screen.board._tap(wrong)
	assert_str(screen._feedback.text).is_equal("Not quite: they can still play.")
	await get_tree().create_timer(2.8).timeout
	assert_int(screen.tries).is_equal(2)
	assert_array(Array(screen.board.state.bits)).is_equal(Array(ReversiPuzzles.position(p).bits))  # Reset.
	screen.board._tap(int(p["answer"]))
	await _frames(1)
	assert_bool(screen._end_card.visible).is_true()


func test_an_ending_is_played_out_against_the_defence_and_won() -> void:
	var p: Dictionary = ReversiPuzzleData.PUZZLES.filter(func(x: Dictionary) -> bool: return x["goal"] == "win")[0]
	app.push(PuzzleScreen.create(p))
	await _frames(2)
	var screen: Node = _top()
	screen.board._tap(int(p["answer"]))
	var stop := Time.get_ticks_msec() + 30000
	while not screen._end_card.visible and Time.get_ticks_msec() < stop:
		screen.board.skip()
		if screen.board.interactive and not screen._busy:
			var good := ReversiPuzzles.win_moves(screen.board.state)
			assert_bool(good.is_empty()).is_false()
			screen.board._tap(good[0])
		await get_tree().process_frame
	assert_bool(screen._end_card.visible).is_true()
	var mover := int(p["turn"])
	assert_int(R.result(screen.board.state)).is_equal(R.WIN_0 if mover == 0 else R.WIN_1)
