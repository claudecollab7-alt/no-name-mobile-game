extends GdUnitTestSuite
## Smoke test for the app shell: opens every screen and card, plays games to the end.
## Catches script errors in code that only runs when a screen is shown.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const GamePage := preload("res://shell/screens/game_page.gd")
const SettingsScreen := preload("res://shell/screens/settings_screen.gd")

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


func test_every_tab_opens() -> void:
	for i in 4:
		app.show_tab(i)
		await _frames(2)
		assert_bool(app._tab_screens[i].visible).is_true()


func test_pass_and_play_game_reaches_the_result_screen() -> void:
	Store.set_last("mode", "pass")
	app.push(GamePage.new())
	await _frames(2)
	_top()._start()
	await _frames(3)
	var play: Node = _top()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var guard := 0
	while R.result(play.board.state) == R.ONGOING and guard < 400:
		var moves := R.legal_moves(play.board.state)
		play.board.play_move(moves[rng.randi_range(0, moves.size() - 1)])
		await _frames(1)
		guard += 1
	assert_int(R.result(play.board.state)).is_not_equal(R.ONGOING)
	await get_tree().create_timer(1.5).timeout
	assert_str(_top().get_script().resource_path).is_equal("res://shell/screens/result_screen.gd")
	assert_int(Store.stat("pass_games")).is_greater(0)


func test_computer_replies_after_a_human_move() -> void:
	Store.set_last("mode", "computer")
	Store.set_last("level", "easy")
	Store.set_last("side", "goats")
	app.push(GamePage.new())
	await _frames(2)
	_top()._start()
	await _frames(3)
	var play: Node = _top()
	play.board._tap(19)  # Human places a goat.
	await get_tree().create_timer(1.5).timeout
	assert_int(play.board.state.moves_played).is_equal(2)  # The computer has replied.
	assert_int(play.board.state.turn).is_equal(R.GOAT)
	play._undo()
	await _frames(2)
	assert_int(play.board.state.moves_played).is_equal(0)


func test_settings_profile_and_cards_open() -> void:
	app.push(SettingsScreen.new())
	await _frames(2)
	var settings: Node = _top()
	for f in ["_themes", "_confirm_reset", "_privacy", "_credits"]:
		settings.call(f)
		await _frames(2)
		assert_bool(Modal.close_top(app)).is_true()
		await _frames(1)
	Modal.how_to_play(app)
	await _frames(2)
	assert_bool(Modal.close_top(app)).is_true()
	app.show_tab(3)
	await _frames(2)
	app._tab_screens[3]._edit_profile()
	await _frames(2)
	assert_bool(Modal.close_top(app)).is_true()
