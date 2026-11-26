extends GdUnitTestSuite
## A game against the computer must end with a visible result for the player.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const PlayScreen := preload("res://shell/screens/play_screen.gd")

var app: Node


func before_test() -> void:
	app = auto_free(load("res://main.tscn").instantiate())
	add_child(app)
	await get_tree().process_frame
	Modal.close_top(app)


func _top() -> Node:
	return app._stack[-1] if not app._stack.is_empty() else null


func test_game_against_the_computer_shows_a_result_when_it_ends() -> void:
	app.push(PlayScreen.create("computer", "easy", "goats"))
	await get_tree().process_frame
	var play: Node = _top()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var waited := 0
	while R.result(play.board.state) == R.ONGOING and waited < 6000:
		if play._human_turn() and not play._thinking and play.board.interactive:
			var moves := R.legal_moves(play.board.state)
			play.board.play_move(moves[rng.randi_range(0, moves.size() - 1)])
		await get_tree().process_frame
		waited += 1
	assert_int(R.result(play.board.state)).is_not_equal(R.ONGOING)
	var shown := false
	for i in 300:
		await get_tree().process_frame
		if _top() != play or play.get_node_or_null("EndCard") != null:
			shown = true
			break
	assert_bool(shown).override_failure_message("No result appeared after the game ended").is_true()


func test_pass_and_play_win_by_taps_shows_the_popup() -> void:
	app.push(PlayScreen.create("pass", "", "goats"))
	await get_tree().process_frame
	var play: Node = _top()
	var board: Node = play.board
	# Goats walk into five captures; the same taps as the manual browser check.
	for p: int in [9, 3, 15, 10, 4, 16, 2, 0, 8, 14, 8, 19, 20, 19, 21]:
		while board.busy:
			await get_tree().process_frame
		board._tap(p)
		await get_tree().process_frame
	assert_int(board.state.captured).is_equal(5)
	var shown := false
	for i in 300:
		await get_tree().process_frame
		if _top() != play:
			shown = true
			break
	assert_bool(shown).override_failure_message("No popup after a pass-and-play win").is_true()
