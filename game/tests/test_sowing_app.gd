extends GdUnitTestSuite
## Mancala and Pallanguzhi in the app: home cards, game page, play, result, records.

const S := preload("res://games/sowing/sowing_rules.gd")
const SowingGamePage := preload("res://shell/screens/sowing_game_page.gd")
const ProfileScreen := preload("res://shell/screens/profile_screen.gd")

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


func _open_play(id: String, mode: String, level := "easy") -> Node:
	Store.set_last("mode", mode)
	Store.set_last("level", level)
	app.push(SowingGamePage.create(id))
	await _frames(2)
	_top()._start()
	await _frames(3)
	return _top()


func test_the_home_screen_has_a_card_for_each_seed_game() -> void:
	var home: Node = app._tab_screens[0]
	var titles: Array = []
	for l in home.find_children("*", "Label", true, false):
		titles.append((l as Label).text)
	assert_bool(titles.has("Mancala")).is_true()
	assert_bool(titles.has("Pallanguzhi")).is_true()


func test_pass_and_play_reaches_the_result_and_counts_the_game() -> void:
	for id: String in ["kalah", "pallanguzhi"]:
		var before := Store.game_stat(id, "pass_games")
		var play: Node = await _open_play(id, "pass")
		assert_str(play.get_script().resource_path).is_equal("res://shell/screens/sowing_play_screen.gd")
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		var guard := 0
		while not play.board.state.over and guard < 400:
			var moves := S.legal_moves(play.board.state)
			play.board.play_move(moves[rng.randi_range(0, moves.size() - 1)])
			play.board.skip()
			await _frames(1)
			guard += 1
		assert_bool(play.board.state.over).is_true()
		await get_tree().create_timer(0.5).timeout
		assert_str(_top().get_script().resource_path).is_equal("res://shell/screens/sowing_result_screen.gd")
		assert_int(Store.game_stat(id, "pass_games")).is_equal(before + 1)
		app.home()
		await _frames(2)


func test_the_computer_replies_and_undo_takes_both_moves_back() -> void:
	Store.data["games"]["kalah"]["next_first"] = 0  # You move first.
	var play: Node = await _open_play("kalah", "computer")
	assert_int(play.first).is_equal(0)
	play.board._tap(0)  # Four seeds into pits 1-4: no extra turn.
	play.board.skip()
	var guard := 0
	while play.board.state.moves_played < 2 and guard < 300:
		await _frames(1)
		guard += 1
	play.board.skip()
	await _frames(2)
	assert_int(play.board.state.moves_played).is_greater_equal(2)
	while play.board.state.turn != 0 and guard < 600:  # The computer may go again.
		play.board.skip()
		await _frames(1)
		guard += 1
	play._undo()
	await _frames(2)
	assert_int(play.board.state.moves_played).is_equal(0)


func test_who_starts_takes_turns_between_games() -> void:
	Store.data["games"]["pallanguzhi"]["next_first"] = 1
	var play: Node = await _open_play("pallanguzhi", "computer")
	assert_int(play.first).is_equal(1)
	assert_int(play.board.state.turn).is_equal(1)  # The computer starts...
	assert_bool(play.board.interactive).is_false()  # ...and you can't play meanwhile.
	play._restart()
	await _frames(2)
	assert_int(play.first).is_equal(0)
	assert_int(play.board.state.turn).is_equal(0)


func test_rules_cards_and_the_profile_record_open() -> void:
	for id: String in ["kalah", "pallanguzhi"]:
		Games.how_to_play(app, id)
		await _frames(2)
		assert_bool(Modal.close_top(app)).is_true()
	Store.record_result("kalah", "computer", "medium", "win")
	app.push(ProfileScreen.new())
	await _frames(3)
	var texts: Array = []
	for l in _top().find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	assert_bool(texts.has("Seed games")).is_true()


func test_a_computer_game_result_counts_a_win_loss_or_draw() -> void:
	var played := Store.game_stat("kalah", "played")
	var play: Node = await _open_play("kalah", "computer")
	var s := S.new_game(S.KALAH)
	s.pits = PackedInt32Array([0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1])
	s.stores = PackedInt32Array([30, 16])
	s.turn = 0
	play._history.clear()
	play.board.set_state(s)
	await _frames(1)
	play.board._tap(5)  # Last seed into your store ends the game: 31 + nothing vs 16 + 1.
	play.board.skip()
	await get_tree().create_timer(0.5).timeout
	assert_int(Store.game_stat("kalah", "played")).is_equal(played + 1)
	assert_str(_top().get_script().resource_path).is_equal("res://shell/screens/sowing_result_screen.gd")
