extends GdUnitTestSuite
## Daily puzzles: every bundled puzzle is proven, the screen judges moves, streaks count.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const PuzzleScreen := preload("res://shell/screens/puzzle_screen.gd")

var app: Node
var _saved_daily := {}


func before_test() -> void:
	_saved_daily = Store.data["daily"].duplicate(true)
	app = auto_free(load("res://main.tscn").instantiate())
	add_child(app)
	await get_tree().process_frame
	Modal.close_top(app)


func after_test() -> void:
	Store.data["daily"] = _saved_daily
	Store.save_data()


func _top() -> Node:
	return app._stack[-1] if not app._stack.is_empty() else null


func test_there_are_enough_puzzles_of_every_difficulty() -> void:
	var all: Array = AadupuliPuzzleData.PUZZLES
	assert_int(all.size()).is_greater_equal(120)
	for d in [1, 2, 3, 4]:
		assert_bool(all.any(func(p: Dictionary) -> bool: return int(p["difficulty"]) == d)).override_failure_message("no difficulty %d" % d).is_true()


func test_every_puzzle_has_one_answer_and_can_be_solved_against_the_best_defence() -> void:
	for p: Dictionary in AadupuliPuzzleData.PUZZLES:
		var s := AadupuliPuzzles.position(p)
		var name := "puzzle %d" % int(p["id"])
		assert_int(R.result(s)).override_failure_message(name).is_equal(R.ONGOING)
		var wins := AadupuliPuzzles.winning_moves(p, s, int(p["n"]))
		assert_array(Array(wins)).override_failure_message(name + " should have exactly its answer").is_equal([int(p["answer"])])
		# Play it out: answer, toughest reply, any winning move, until solved.
		var left := int(p["n"])
		var move := int(p["answer"])
		var solved := false
		for i in left:
			var before := s
			s = R.apply(s, move)
			if AadupuliPuzzles.is_solved(p, before, s):
				solved = true
				break
			left -= 1
			s = R.apply(s, AadupuliPuzzles.toughest_reply(p, s, left))
			var next := AadupuliPuzzles.winning_moves(p, s, left)
			assert_bool(next.is_empty()).override_failure_message(name + " lost its forced line").is_false()
			move = next[0]
		assert_bool(solved).override_failure_message(name + " was not solved in time").is_true()


func test_daily_numbering_and_choice_are_stable() -> void:
	assert_int(Daily.day_number(Daily.FIRST_DAY)).is_equal(1)
	assert_str(Daily.date_of(Daily.day_number("2026-12-25"))).is_equal("2026-12-25")
	assert_dict(Daily.puzzle_for(40)).is_equal(Daily.puzzle_for(40))


func test_streak_grows_on_consecutive_days_and_restarts_after_a_gap() -> void:
	var today := Daily.day_number()
	Store.data["daily"] = {"streak": 4, "best": 4, "last_date": Daily.date_of(today - 1), "solved": {}}
	Daily.record(today, 2)
	assert_int(Daily.streak()).is_equal(5)
	assert_int(Daily.best()).is_equal(5)
	assert_int(Daily.tries_on(today)).is_equal(2)
	Store.data["daily"] = {"streak": 9, "best": 9, "last_date": Daily.date_of(today - 3), "solved": {}}
	assert_int(Daily.streak()).is_equal(0)
	Daily.record(today, 1)
	assert_int(Daily.streak()).is_equal(1)
	assert_int(Daily.best()).is_equal(9)


func test_puzzle_screen_counts_a_wrong_try_then_accepts_the_answer() -> void:
	var p: Dictionary = AadupuliPuzzleData.PUZZLES.filter(func(x: Dictionary) -> bool: return x["goal"] == "safe")[0]
	app.push(PuzzleScreen.create(p, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	var screen: Node = _top()
	var board: Node = screen.board
	# A wrong move first.
	var wrong := -1
	for m in R.legal_moves(board.state):
		if m != int(p["answer"]):
			wrong = m
			break
	board.before_move.emit(board.state)
	board.play_move(wrong)
	screen._on_move(wrong)
	await get_tree().create_timer(2.6).timeout
	assert_int(screen.tries).is_equal(2)
	# Then the answer.
	var a := int(p["answer"])
	if R.move_from(a) != R.NONE:
		board._tap(R.move_from(a))
	board._tap(R.move_to(a))
	await get_tree().process_frame
	assert_bool(screen._end_card.visible).is_true()


func test_solving_the_daily_puzzle_records_the_day() -> void:
	var day := Daily.day_number()
	Store.data["daily"] = {"streak": 0, "best": 0, "last_date": "", "solved": {}}
	var p := Daily.puzzle_for(day)
	app.push(PuzzleScreen.create(p, day))
	await get_tree().process_frame
	await get_tree().process_frame
	var screen: Node = _top()
	var board: Node = screen.board
	var left := int(p["n"])
	var move := int(p["answer"])
	for i in left:
		if R.move_from(move) != R.NONE:
			board._tap(R.move_from(move))
		board._tap(R.move_to(move))
		await get_tree().process_frame
		if screen._end_card.visible:
			break
		await get_tree().create_timer(1.2).timeout
		move = AadupuliPuzzles.winning_moves(p, board.state, screen._moves_left)[0]
	assert_bool(screen._end_card.visible).is_true()
	assert_int(Daily.tries_on(day)).is_equal(1)
	assert_int(Daily.streak()).is_equal(1)
