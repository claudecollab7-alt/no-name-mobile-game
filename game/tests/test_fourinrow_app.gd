extends GdUnitTestSuite
## Four in a Row in the app (BUILD_PLAN.md G4.4): home card, game page with the
## first/second choice (D69), play against the computer or pass and play, result, record.

const F := preload("res://games/fourinrow/four_rules.gd")
const GamePage := preload("res://shell/screens/four_game_page.gd")
const PlayScreen := preload("res://shell/screens/four_play_screen.gd")

var app: Node
var _saved := {}
var _saved_last := {}


func before_test() -> void:
	_saved = (Store.data["games"]["fourinrow"] as Dictionary).duplicate(true)
	_saved_last = (Store.data["last"] as Dictionary).duplicate(true)
	app = auto_free(load("res://main.tscn").instantiate())
	add_child(app)
	await _frames(3)
	Modal.close_top(app)


func after_test() -> void:
	Store.data["games"]["fourinrow"] = _saved
	Store.data["last"] = _saved_last
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


## Plays random legal columns for the human side until the game ends.
func _play_out(play: Node, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var waited := 0
	while F.result(play.board.state) == F.ONGOING and waited < 6000:
		if play._human_turn() and not play._thinking and play.board.interactive and not play.board.busy:
			var moves := F.legal_moves(play.board.state)
			play.board._tap(moves[rng.randi_range(0, moves.size() - 1)])
		await get_tree().process_frame
		waited += 1


func _wait_for_result(play: Node) -> Node:
	for i in 300:
		await get_tree().process_frame
		if _top() != play:
			return _top()
	return null


func test_the_home_card_opens_the_page_with_the_first_or_second_choice() -> void:
	var home: Node = app._tab_screens[0]
	assert_int(_texts(home).count("Four in a Row")).is_equal(1)  # A real card, no "Soon" tile.
	home._open_four()
	await _frames(2)
	var page: Node = _top()
	assert_str(page.get_script().resource_path).ends_with("four_game_page.gd")
	var texts := _texts(page)
	assert_bool(texts.has("Against the computer")).is_true()
	assert_bool(texts.has("Pass and play")).is_true()
	for chip in ["First", "Second", "Coin toss"]:
		assert_bool(texts.has(chip)).override_failure_message(chip).is_true()
	assert_bool(texts.has("Play online")).is_true()
	page._set_mode("pass")
	assert_bool(page._seat_row.visible).is_false()  # Pass and play: Player 1 moves first.


func test_moving_first_you_are_orange_and_it_is_your_turn() -> void:
	Store.set_last("mode", "computer")
	Store.set_last("seat", "first")
	app.push(GamePage.create("fourinrow"))
	await _frames(2)
	_top()._start()
	await _frames(3)
	var play: Node = _top()
	assert_str(play.get_script().resource_path).ends_with("four_play_screen.gd")
	assert_int(play.me).is_equal(0)
	assert_int(play.board.state.moves_played).is_equal(0)
	assert_bool(play.board.interactive).is_true()
	assert_bool(_texts(play).has("Orange · moves first")).is_true()
	assert_bool(_texts(play).has("Tap a column to drop your disc.")).is_true()
	# A move, then undo takes back yours and the computer's reply.
	play.board._tap(3)
	for i in 400:
		await get_tree().process_frame
		if play.board.state.moves_played == 2 and not play.board.busy:
			break
	assert_int(play.board.state.moves_played).is_equal(2)
	play._undo()
	assert_int(play.board.state.moves_played).is_equal(0)


func test_moving_second_the_computer_starts() -> void:
	Store.set_last("mode", "computer")
	Store.set_last("seat", "second")
	app.push(GamePage.create("fourinrow"))
	await _frames(2)
	_top()._start()
	await _frames(2)
	var play: Node = _top()
	assert_int(play.me).is_equal(1)
	for i in 400:
		await get_tree().process_frame
		if play.board.state.moves_played == 1 and not play.board.busy:
			break
	assert_int(play.board.state.moves_played).is_equal(1)
	assert_int(play.board.state.turn).is_equal(1)
	assert_bool(play.board.interactive).is_true()


func test_a_coin_toss_says_who_moves_first() -> void:
	Store.set_last("mode", "computer")
	Store.set_last("seat", "toss")
	app.push(GamePage.create("fourinrow"))
	await _frames(2)
	_top()._start()
	await _frames(2)
	var play: Node = _top()
	assert_bool(play.tossed).is_true()
	var hint: String = play._hint.text
	assert_bool(hint.begins_with("Coin toss:")).override_failure_message(hint).is_true()


func test_a_game_against_the_computer_ends_with_a_result_recorded_by_seat() -> void:
	var played := Store.game_stat("fourinrow", "played")
	var second := Store.game_stat("fourinrow", "second_wins") + Store.game_stat("fourinrow", "second_losses")
	app.push(PlayScreen.create("fourinrow", "computer", "easy", false))
	await _frames(1)
	var play: Node = _top()
	await _play_out(play, 3)
	assert_int(F.result(play.board.state)).is_not_equal(F.ONGOING)
	var result := await _wait_for_result(play)
	assert_object(result).is_not_null()
	assert_str(result.get_script().resource_path).ends_with("four_result_screen.gd")
	assert_int(Store.game_stat("fourinrow", "played")).is_equal(played + 1)
	if F.result(play.board.state) != F.DRAW:
		assert_int(Store.game_stat("fourinrow", "second_wins") + Store.game_stat("fourinrow", "second_losses")).is_equal(second + 1)
	# Switch to moving first for the next game.
	var buttons := _buttons(result)
	assert_bool(buttons.has("Move first")).is_true()
	(buttons["Move first"] as Button).pressed.emit()
	await _frames(2)
	assert_str(_top().get_script().resource_path).ends_with("four_play_screen.gd")
	assert_int(_top().me).is_equal(0)


func test_pass_and_play_names_the_winning_player() -> void:
	var passed := Store.game_stat("fourinrow", "pass_games")
	app.push(PlayScreen.create("fourinrow", "pass", ""))
	await _frames(1)
	var play: Node = _top()
	assert_bool(_texts(play).has("Player 1")).is_true()
	assert_bool(_texts(play).has("Player 2")).is_true()
	for c: int in [0, 1, 0, 1, 0, 1, 0]:  # Player 1 stacks four up column 0.
		play.board._tap(c)
		play.board.skip()
		await _frames(1)
	var result := await _wait_for_result(play)
	assert_object(result).is_not_null()
	assert_bool(_texts(result).has("Player 1 wins!")).is_true()
	assert_int(Store.game_stat("fourinrow", "pass_games")).is_equal(passed + 1)
	(_buttons(result)["Play again"] as Button).pressed.emit()
	await _frames(2)
	assert_int(_top().board.state.moves_played).is_equal(0)


func test_the_rules_card_is_its_own_without_a_tutorial_yet() -> void:
	Games.how_to_play(app, "fourinrow")
	await _frames(1)
	var texts := _texts(app)
	assert_bool(texts.has("How to play Four in a Row")).is_true()
	assert_bool(texts.has("Four in a row")).is_true()
	assert_bool(_buttons(app).has("Try the tutorial")).is_false()
	Modal.close_top(app)
