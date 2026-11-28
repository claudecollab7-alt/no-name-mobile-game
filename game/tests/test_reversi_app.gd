extends GdUnitTestSuite
## Reversi in the app (BUILD_PLAN.md G5.4): home card, game page with the first/second
## choice (D73), play against the computer or pass and play, passing, result, record.

const R := preload("res://games/reversi/reversi_rules.gd")
const GamePage := preload("res://shell/screens/reversi_game_page.gd")
const PlayScreen := preload("res://shell/screens/reversi_play_screen.gd")

var app: Node
var _saved := {}
var _saved_last := {}
var _saved_stats := {}


func before_test() -> void:
	_saved = (Store.data["games"]["reversi"] as Dictionary).duplicate(true)
	_saved_last = (Store.data["last"] as Dictionary).duplicate(true)
	_saved_stats = (Store.data["stats"] as Dictionary).duplicate(true)
	Store.data["games"]["reversi"]["tutorial_offered"] = true  # The lessons offer: test_reversi_tutorial.gd
	app = auto_free(load("res://main.tscn").instantiate())
	add_child(app)
	await _frames(3)
	Modal.close_top(app)


func after_test() -> void:
	Store.data["games"]["reversi"] = _saved
	Store.data["last"] = _saved_last
	Store.data["stats"] = _saved_stats
	Store.save_data()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _top() -> Node:
	return app._stack[-1] if not app._stack.is_empty() else null


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


## Rows from the TOP down, as they read on screen.
func _pos(top_down: Array, turn := 0) -> R.State:
	var rows := top_down.duplicate()
	rows.reverse()
	return R.from_dict({"rows": rows, "turn": turn})


## Plays random legal squares for the human side until the game ends (up to 90 s).
func _play_out(play: Node, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var stop := Time.get_ticks_msec() + 90000
	while R.result(play.board.state) == R.ONGOING and Time.get_ticks_msec() < stop:
		play.board.skip()
		if play._human_turn() and not play._thinking and play.board.interactive:
			var moves := R.legal_moves(play.board.state)
			play.board._tap(moves[rng.randi_range(0, moves.size() - 1)])
		await get_tree().process_frame


func _wait_for_result(play: Node) -> Node:
	var stop := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < stop:
		await get_tree().process_frame
		if _top() != play:
			return _top()
	return null


func test_the_home_card_opens_the_page_with_the_first_or_second_choice() -> void:
	var home: Node = app._tab_screens[0]
	assert_int(_texts(home).count("Reversi")).is_equal(1)
	home._open_reversi()
	await _frames(2)
	var page: Node = _top()
	assert_str(page.get_script().resource_path).ends_with("reversi_game_page.gd")
	var texts := _texts(page)
	assert_bool(texts.has("Against the computer")).is_true()
	assert_bool(texts.has("Pass and play")).is_true()
	for chip in ["First", "Second", "Coin toss"]:
		assert_bool(texts.has(chip)).override_failure_message(chip).is_true()
	page._set_mode("pass")
	assert_bool(page._seat_row.visible).is_false()  # Pass and play: Player 1 moves first.


func test_moving_first_you_are_orange_with_two_discs_and_it_is_your_turn() -> void:
	Store.set_last("mode", "computer")
	Store.set_last("seat", "first")
	app.push(GamePage.create("reversi"))
	await _frames(2)
	_top()._start()
	await _frames(3)
	var play: Node = _top()
	assert_str(play.get_script().resource_path).ends_with("reversi_play_screen.gd")
	assert_int(play.me).is_equal(0)
	assert_bool(play.board.interactive).is_true()
	assert_bool(_texts(play).has("Orange · moves first")).is_true()
	assert_str(play._panels[0][2].text).is_equal("2")
	# A move, then undo takes back yours and the computer's reply.
	play.board._tap(R.legal_moves(play.board.state)[0])
	var stop := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < stop and not (play.board.state.moves_played == 2 and not play.board.busy):
		await get_tree().process_frame
	assert_int(play.board.state.moves_played).is_equal(2)
	play._undo()
	assert_int(play.board.state.moves_played).is_equal(0)
	assert_str(play._panels[0][2].text).is_equal("2")


func test_moving_second_the_computer_starts() -> void:
	app.push(PlayScreen.create("reversi", "computer", "easy", false))
	await _frames(2)
	var play: Node = _top()
	assert_int(play.me).is_equal(1)
	var stop := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < stop and not (play.board.state.moves_played == 1 and not play.board.busy):
		await get_tree().process_frame
	assert_int(play.board.state.turn).is_equal(1)
	assert_bool(play.board.interactive).is_true()
	assert_str(play._panels[0][2].text).is_equal("4")  # Orange placed one and flipped one.


func test_a_coin_toss_says_who_moves_first() -> void:
	Store.set_last("mode", "computer")
	Store.set_last("seat", "toss")
	app.push(GamePage.create("reversi"))
	await _frames(2)
	_top()._start()
	await _frames(2)
	var play: Node = _top()
	assert_bool(play.tossed).is_true()
	var hint: String = play._hint.text
	assert_bool(hint.begins_with("Coin toss:")).override_failure_message(hint).is_true()


func test_a_player_with_no_move_passes_and_is_told_so() -> void:
	app.push(PlayScreen.create("reversi", "pass", ""))
	await _frames(1)
	var play: Node = _top()
	# Cream (Player 2) to move has nothing; orange can still play.
	play.board.set_state(_pos(["........", "........", "........", "........", "........", "........", ".1......", "0......."], 1))
	assert_bool(play.board.interactive).is_false()
	assert_str(play._hint.text).contains("no move")
	var stop := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < stop and play.board.state.turn == 1:
		await get_tree().process_frame
	assert_int(play.board.state.last_move).is_equal(R.PASS)
	assert_str(play._hint.text).contains("Player 2 had no move and passed.")
	assert_bool(play.board.interactive).is_true()


func test_a_game_against_the_computer_ends_with_a_result_recorded_by_seat() -> void:
	var played := Store.game_stat("reversi", "played")
	var second := Store.game_stat("reversi", "second_wins") + Store.game_stat("reversi", "second_losses")
	app.push(PlayScreen.create("reversi", "computer", "easy", false))
	await _frames(1)
	var play: Node = _top()
	await _play_out(play, 3)
	assert_int(R.result(play.board.state)).is_not_equal(R.ONGOING)
	var result := await _wait_for_result(play)
	assert_object(result).is_not_null()
	assert_str(result.get_script().resource_path).ends_with("reversi_result_screen.gd")
	assert_int(Store.game_stat("reversi", "played")).is_equal(played + 1)
	if R.result(play.board.state) != R.DRAW:
		assert_int(Store.game_stat("reversi", "second_wins") + Store.game_stat("reversi", "second_losses")).is_equal(second + 1)
	var s: R.State = play.board.state
	assert_bool(_texts(result).has("Orange %d, cream %d." % [R.discs(s, 0), R.discs(s, 1)]) \
		or _texts(result).has("Orange %d, cream %d. Neither player could move." % [R.discs(s, 0), R.discs(s, 1)])).is_true()
	# Switch to moving first for the next game.
	var buttons := _buttons(result)
	assert_bool(buttons.has("Move first")).is_true()
	(buttons["Move first"] as Button).pressed.emit()
	await _frames(2)
	assert_str(_top().get_script().resource_path).ends_with("reversi_play_screen.gd")
	assert_int(_top().me).is_equal(0)


func test_pass_and_play_names_the_winning_player() -> void:
	var passed := Store.game_stat("reversi", "pass_games")
	app.push(PlayScreen.create("reversi", "pass", ""))
	await _frames(1)
	var play: Node = _top()
	assert_bool(_texts(play).has("Player 1")).is_true()
	assert_bool(_texts(play).has("Player 2")).is_true()
	# Orange takes cream's last disc: nobody can move, and Player 1 wins.
	play.board.set_state(_pos(["........", "........", "........", "........", "........", "...1....", "..1.....", ".0......"]))
	play.board._tap(R.cell(4, 3))
	play.board.skip()
	var result := await _wait_for_result(play)
	assert_object(result).is_not_null()
	assert_bool(_texts(result).has("Player 1 wins!")).is_true()
	assert_int(Store.game_stat("reversi", "pass_games")).is_equal(passed + 1)
	(_buttons(result)["Play again"] as Button).pressed.emit()
	await _frames(2)
	assert_int(_top().board.state.moves_played).is_equal(0)


func test_the_rules_card_is_its_own_with_the_lessons() -> void:
	Games.how_to_play(app, "reversi")
	await _frames(1)
	var texts := _texts(app)
	assert_bool(texts.has("How to play Reversi")).is_true()
	assert_bool(texts.has("Trap to flip")).is_true()
	assert_bool(_buttons(app).has("Try the tutorial")).is_true()
	Modal.close_top(app)
