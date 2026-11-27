extends GdUnitTestSuite
## Bagh-Chal in the app (BUILD_PLAN.md G3.4): home card, game page, play, result, record.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const GamePage := preload("res://shell/screens/game_page.gd")
const PlayScreen := preload("res://shell/screens/play_screen.gd")

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


func _texts(root: Node) -> Array:
	var out: Array = []
	for l in root.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out


func test_the_home_screen_has_a_bagh_chal_card_that_opens_its_page() -> void:
	var home: Node = app._tab_screens[0]
	assert_bool(_texts(home).has("Bagh-Chal")).is_true()
	home._open_bagh()
	await _frames(2)
	var page: Node = _top()
	assert_str(page.get_script().resource_path).is_equal("res://shell/screens/game_page.gd")
	assert_str(page.board_id).is_equal("baghchal")
	var texts := _texts(page)
	assert_bool(texts.has("Bagh-Chal")).is_true()
	assert_bool(texts.has("Against the computer")).is_true()
	assert_bool(texts.has("Play online")).is_true()
	assert_bool(texts.has("Learn to play")).is_true()


func test_the_page_starts_a_bagh_chal_game_with_the_right_pieces() -> void:
	Store.set_last("mode", "pass")
	Store.data["games"]["baghchal"]["tutorial_offered"] = true  # Lessons offer: test_baghchal_tutorial.gd
	app.push(GamePage.create("baghchal"))
	await _frames(2)
	_top()._start()
	await _frames(3)
	var play: Node = _top()
	assert_str(play.get_script().resource_path).is_equal("res://shell/screens/play_screen.gd")
	assert_str(play.board.state.board).is_equal("baghchal")
	assert_array(Array(play.board.state.tigers)).is_equal([0, 4, 20, 24])
	assert_int(play.board.state.in_hand).is_equal(20)
	var texts := _texts(play)
	assert_bool(texts.has("Trap all 4 tigers to win")).is_true()
	assert_bool(texts.has("20")).is_true()
	play._restart()
	await _frames(1)
	assert_str(play.board.state.board).is_equal("baghchal")


func test_the_rules_card_is_bagh_chals_own() -> void:
	Modal.how_to_play(app, "baghchal")
	await _frames(2)
	var texts := _texts(app)
	assert_bool(texts.has("How to play Bagh-Chal")).is_true()
	assert_bool(texts.has("No going back")).is_true()
	var buttons: Array = []
	for b in app.find_children("*", "Button", true, false):
		buttons.append((b as Button).text)
	assert_bool(buttons.has("Try the tutorial")).is_true()
	Modal.close_top(app)


func test_a_game_against_the_computer_ends_with_a_result_and_is_recorded() -> void:
	var as_goats := Store.game_stat("baghchal", "goat_wins") + Store.game_stat("baghchal", "goat_losses")
	var played := Store.game_stat("baghchal", "played")
	app.push(PlayScreen.create("computer", "easy", "goats", false, "baghchal"))
	await _frames(1)
	var play: Node = _top()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var waited := 0
	while R.result(play.board.state) == R.ONGOING and waited < 8000:
		if play._human_turn() and not play._thinking and play.board.interactive and not play.board.busy:
			var moves := R.legal_moves(play.board.state)
			play.board.play_move(moves[rng.randi_range(0, moves.size() - 1)])
		await get_tree().process_frame
		waited += 1
	assert_int(R.result(play.board.state)).is_not_equal(R.ONGOING)
	var result: Node = null
	for i in 300:
		await get_tree().process_frame
		if _top() != play:
			result = _top()
			break
	assert_object(result).is_not_null()
	assert_str(result.get_script().resource_path).is_equal("res://shell/screens/result_screen.gd")
	assert_int(Store.game_stat("baghchal", "played")).is_equal(played + 1)
	assert_int(Store.game_stat("baghchal", "goat_wins") + Store.game_stat("baghchal", "goat_losses")).is_equal(as_goats + 1)
	# Rematch keeps the board.
	result._again("tigers")
	await _frames(2)
	assert_str(_top().board_id).is_equal("baghchal")
	assert_str(_top().board.state.board).is_equal("baghchal")
