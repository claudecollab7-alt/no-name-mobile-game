extends GdUnitTestSuite
## Four in a Row puzzles (BUILD_PLAN.md G4.7): every one has exactly one right first move
## (proven twice: by the quick bitboard proofs, and again by a plain solver on the game
## rules), each can be solved against the toughest defence, and the page card and
## puzzle screen work through them in order.

const F := preload("res://games/fourinrow/four_rules.gd")
const PuzzleScreen := preload("res://shell/screens/four_puzzle_screen.gd")
const GamePage := preload("res://shell/screens/four_game_page.gd")

var app: Node
var _saved: Array = []


func before_test() -> void:
	_saved = (Store.puzzles_solved("fourinrow") as Array).duplicate()
	app = auto_free(load("res://main.tscn").instantiate())
	add_child(app)
	await get_tree().process_frame
	Modal.close_top(app)


func after_test() -> void:
	Store.data["games"]["fourinrow"]["puzzles_solved"] = _saved
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


# ---------- A plain solver on the game rules, independent of the bitboard proofs ----------

## Can the player to move make four within n of their moves, whatever the opponent does?
func _plain_win(s: F.State, n: int) -> bool:
	for m in F.legal_moves(s):
		if _plain_forces(s, m, n):
			return true
	return false


func _plain_forces(s: F.State, m: int, n: int) -> bool:
	var me := s.turn
	var a := F.after(s, m)
	var res := F.result(a)
	if res != F.ONGOING:
		return res == (F.WIN_0 if me == 0 else F.WIN_1)
	if n <= 1:
		return false
	for r in F.legal_moves(a):
		var b := F.after(a, r)
		if F.result(b) != F.ONGOING or not _plain_win(b, n - 1):
			return false
	return true


func test_there_are_enough_puzzles_of_every_kind() -> void:
	var all: Array = FourPuzzleData.PUZZLES
	assert_int(all.size()).is_greater_equal(100)
	for kind: Array in [["win", 1], ["win", 2], ["win", 3], ["save", 1]]:
		assert_bool(all.any(func(p: Dictionary) -> bool: return p["goal"] == kind[0] and int(p["n"]) == kind[1])).override_failure_message(str(kind)).is_true()
	assert_bool(all.any(func(p: Dictionary) -> bool: return int(p["turn"]) == 1)).is_true()  # Some as cream.
	for i in all.size():
		assert_int(int(all[i]["id"])).is_equal(i + 1)
		if i > 0:
			assert_bool(int(all[i]["difficulty"]) >= int(all[i - 1]["difficulty"])).is_true()


func test_every_puzzle_has_one_answer_and_can_be_solved_against_the_best_defence() -> void:
	for p: Dictionary in FourPuzzleData.PUZZLES:
		var s := FourPuzzles.position(p)
		var label := "puzzle %d" % int(p["id"])
		assert_int(F.result(s)).override_failure_message(label).is_equal(F.ONGOING)
		var orange := 0
		var cream := 0
		for col in F.COLS:
			for row in F.ROWS:
				match F.owner_at(s, col, row):
					0: orange += 1
					1: cream += 1
		assert_int(orange - cream).override_failure_message(label + ": disc counts").is_equal(int(p["turn"]))
		var good := FourPuzzles.good_moves(p, s, int(p["n"]))
		assert_array(Array(good)).override_failure_message(label + " should have exactly its answer").is_equal([int(p["answer"])])
		if p["goal"] == "save":
			continue
		var mover := s.turn
		var left := int(p["n"])
		var move := int(p["answer"])
		var solved := false
		for i in left:
			s = F.after(s, move)
			if FourPuzzles.is_solved(p, s, mover):
				solved = true
				break
			left -= 1
			s = F.after(s, FourPuzzles.toughest_reply(s, left))
			var next := FourPuzzles.win_moves(s, left)
			assert_bool(next.is_empty()).override_failure_message(label + " lost its forced line").is_false()
			move = next[0]
		assert_bool(solved).override_failure_message(label + " was not solved in time").is_true()


func test_a_plain_solver_agrees_with_every_answer() -> void:
	for p: Dictionary in FourPuzzleData.PUZZLES:
		var s := FourPuzzles.position(p)
		var label := "puzzle %d" % int(p["id"])
		var answer := int(p["answer"])
		for m in F.legal_moves(s):
			var ok: bool
			if p["goal"] == "save":
				ok = not _plain_win(F.after(s, m), FourPuzzles.SAVE_DEPTH)
			else:
				ok = _plain_forces(s, m, int(p["n"]))
			assert_bool(ok).override_failure_message("%s: column %d" % [label, m]).is_equal(m == answer)


func test_the_page_card_opens_the_first_unsolved_puzzle_and_solving_moves_on() -> void:
	Store.data["games"]["fourinrow"]["puzzles_solved"] = []
	app.push(GamePage.create("fourinrow"))
	await _frames(2)
	var page: Node = _top()
	var total := FourPuzzleData.PUZZLES.size()
	assert_bool(_texts(page).has("%d puzzles, easiest first  ·  0 solved" % total)).is_true()
	page._open_puzzles()
	await _frames(2)
	var screen: Node = _top()
	assert_str(screen.get_script().resource_path).ends_with("four_puzzle_screen.gd")
	assert_int(int(screen.puzzle["id"])).is_equal(1)
	assert_bool(_texts(screen).has("Four in a Row puzzle 1")).is_true()
	screen.board._tap(int(screen.puzzle["answer"]))  # Puzzle 1 is a one-move puzzle.
	await _frames(1)
	assert_bool(screen._end_card.visible).is_true()
	assert_array(Store.puzzles_solved("fourinrow")).contains([1])
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


func test_a_wrong_save_shows_their_threat_and_counts_a_try() -> void:
	var p: Dictionary = FourPuzzleData.PUZZLES.filter(func(x: Dictionary) -> bool: return x["goal"] == "save")[0]
	app.push(PuzzleScreen.create(p))
	await _frames(2)
	var screen: Node = _top()
	var wrong := -1
	for m in F.legal_moves(screen.board.state):
		if m != int(p["answer"]):
			wrong = m
			break
	screen.board._tap(wrong)
	assert_str(screen._feedback.text).is_equal("Not quite: now they can force four.")
	await get_tree().create_timer(2.8).timeout
	assert_int(screen.tries).is_equal(2)
	assert_int(screen.board.state.moves_played).is_equal(FourPuzzles.position(p).moves_played)  # Reset.
	screen.board._tap(int(p["answer"]))
	await _frames(1)
	assert_bool(screen._end_card.visible).is_true()


func test_a_win_in_two_is_answered_by_the_computer_then_finished() -> void:
	var p: Dictionary = FourPuzzleData.PUZZLES.filter(func(x: Dictionary) -> bool: return x["goal"] == "win" and int(x["n"]) == 2)[0]
	app.push(PuzzleScreen.create(p))
	await _frames(2)
	var screen: Node = _top()
	var start: int = screen.board.state.moves_played
	screen.board._tap(int(p["answer"]))
	for i in 200:
		await get_tree().process_frame
		if screen.board.state.moves_played == start + 2 and not screen._busy:
			break
	assert_int(screen.board.state.moves_played).is_equal(start + 2)  # Yours and the computer's.
	var finish := FourPuzzles.win_moves(screen.board.state, 1)
	assert_bool(finish.is_empty()).is_false()
	screen.board.skip()
	screen.board._tap(finish[0])
	await _frames(1)
	assert_bool(screen._end_card.visible).is_true()
