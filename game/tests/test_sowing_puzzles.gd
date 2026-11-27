extends GdUnitTestSuite
## Seed-game puzzles: every shipped puzzle is proven, the puzzle screen accepts the
## solution and refuses wrong moves, and progress is remembered.

const S := preload("res://games/sowing/sowing_rules.gd")

var app: Node


func before_test() -> void:
	app = auto_free(load("res://main.tscn").instantiate())
	add_child(app)
	await _frames(3)
	Modal.close_top(app)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _top() -> Node:
	return app._stack[-1] if not app._stack.is_empty() else null


func test_every_puzzle_has_exactly_one_right_first_move() -> void:
	for id: String in ["kalah", "pallanguzhi"]:
		var all: Array = SowingPuzzleData.PUZZLES[id]
		assert_int(all.size()).is_greater_equal(100)
		var total := S.total_seeds(S.new_game(S.config_for(id)))
		for p: Dictionary in all:
			var s := SowingPuzzles.position(id, p)
			var label := "%s puzzle %d" % [id, int(p["id"])]
			assert_int(S.total_seeds(s)).override_failure_message(label).is_equal(total)
			var right: PackedInt32Array
			if str(p["goal"]) == "most":
				assert_int(SowingPuzzles.best_gain(s)).override_failure_message(label).is_equal(int(p["target"]))
				right = SowingPuzzles.gain_moves(s, int(p["target"]))
			else:
				right = SowingPuzzles.win_moves(s, int(p["n"]))
				if int(p["n"]) == 2:
					assert_bool(SowingPuzzles.win_moves(s, 1).is_empty()).override_failure_message(label).is_true()
			assert_array(Array(right)).override_failure_message(label).is_equal([int(p["answer"])])


## Plays the solution on the screen, move by move, letting the computer reply.
func _solve_on_screen(screen: Node) -> void:
	var guard := 0
	while not screen._end_card.visible and guard < 40:
		guard += 1
		if not screen.board.interactive:
			screen.board.skip()
			await _frames(2)
			continue
		var good := SowingPuzzles.good_moves(screen.puzzle, screen.board.state, screen._left)
		screen.board._tap(good[0])
		screen.board.skip()
		await _frames(2)
		await get_tree().create_timer(0.7).timeout  # The computer's reply, if any.


func test_the_screen_accepts_the_solution_for_each_kind_of_puzzle() -> void:
	for id: String in ["kalah", "pallanguzhi"]:
		var all: Array = SowingPuzzleData.PUZZLES[id]
		for kind: Array in [["most", 0], ["win", 1], ["win", 2]]:
			var p: Dictionary = all.filter(func(q: Dictionary) -> bool:
				return q["goal"] == kind[0] and (kind[1] == 0 or int(q["n"]) == kind[1]))[0]
			app.push(load("res://shell/screens/sowing_puzzle_screen.gd").create(id, p))
			await _frames(3)
			var screen: Node = _top()
			await _solve_on_screen(screen)
			assert_bool(screen._end_card.visible).override_failure_message("%s %s %d not solved" % [id, kind[0], kind[1]]).is_true()
			assert_bool(Store.puzzles_solved(id).has(int(p["id"]))).is_true()
			app.pop()
			await _frames(2)


func test_a_wrong_move_is_explained_and_counts_as_another_try() -> void:
	var p: Dictionary = (SowingPuzzleData.PUZZLES["kalah"] as Array).filter(func(q: Dictionary) -> bool: return q["goal"] == "most")[0]
	app.push(load("res://shell/screens/sowing_puzzle_screen.gd").create("kalah", p))
	await _frames(3)
	var screen: Node = _top()
	var s := SowingPuzzles.position("kalah", p)
	var wrong := -1
	for m in S.legal_moves(s):
		if m != int(p["answer"]):
			wrong = m
			break
	screen.board._tap(wrong)
	screen.board.skip()
	await _frames(2)
	assert_str(screen._feedback.text).contains("Not the best")
	await get_tree().create_timer(2.2).timeout
	assert_int(screen.tries).is_equal(2)
	assert_array(Array(screen.board.state.pits)).is_equal(p["pits"])


func test_the_next_puzzle_skips_ones_already_solved() -> void:
	var all: Array = SowingPuzzleData.PUZZLES["pallanguzhi"]
	var saved: Array = Store.puzzles_solved("pallanguzhi").duplicate()
	Store.data["games"]["pallanguzhi"]["puzzles_solved"] = [int(all[0]["id"]), int(all[1]["id"])]
	assert_int(int(Store.next_puzzle("pallanguzhi")["id"])).is_equal(int(all[2]["id"]))
	assert_int(int(Store.next_puzzle("pallanguzhi", int(all[2]["id"]))["id"])).is_equal(int(all[3]["id"]))
	Store.data["games"]["pallanguzhi"]["puzzles_solved"] = saved
	Store.save_data()
