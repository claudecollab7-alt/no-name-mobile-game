extends GdUnitTestSuite
## Lessons for Mancala and Pallanguzhi: every position is sound and teaches what it says,
## and the lesson screen can be played from start to finish by tapping.

const S := preload("res://games/sowing/sowing_rules.gd")
const SowingGamePage := preload("res://shell/screens/sowing_game_page.gd")

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


func test_every_lesson_is_a_real_position_that_does_what_it_says() -> void:
	for id: String in ["kalah", "pallanguzhi"]:
		var total := S.total_seeds(S.new_game(Games.rules_for(id)))
		for step: Dictionary in SowingTutorial.steps(id):
			var s := SowingTutorial.position(id, step)
			var label := "%s: %s" % [id, step["title"]]
			assert_int(S.total_seeds(s)).override_failure_message(label).is_equal(total)
			var ok := SowingTutorial.accepted(id, step)
			assert_bool(ok.is_empty()).override_failure_message(label).is_false()
			var after := S.after(s, ok[0])
			var want: Dictionary = step["after"]
			if want.has("stores"):
				assert_array(Array(after.stores)).override_failure_message(label).is_equal(want["stores"])
			if want.has("turn"):
				assert_int(after.turn).override_failure_message(label).is_equal(want["turn"])
			if want.has("over"):
				assert_bool(after.over).override_failure_message(label).is_equal(want["over"])


func test_the_lessons_can_be_played_from_start_to_finish_by_tapping() -> void:
	for id: String in ["kalah", "pallanguzhi"]:
		Store.data["games"][id]["tutorial_done"] = false
		app.push(load("res://shell/screens/sowing_tutorial_screen.gd").create(id))
		await _frames(3)
		var screen: Node = _top()
		var steps := SowingTutorial.steps(id)
		for i in steps.size():
			assert_int(screen.step_index).is_equal(i)
			var pit: int = SowingTutorial.accepted(id, steps[i])[0]
			screen.board._tap(pit)
			assert_bool(screen.board.busy).override_failure_message("%s lesson %d did not move" % [id, i]).is_true()
			screen.board.skip()
			await _frames(2)
			assert_bool(screen._done_card.visible).is_true()
			if i < steps.size() - 1:
				screen._next()
				await _frames(2)
		assert_bool(bool(Store.data["games"][id]["tutorial_done"])).is_true()
		screen._first_game()
		await _frames(3)
		assert_str(_top().get_script().resource_path).is_equal("res://shell/screens/sowing_play_screen.gd")
		assert_int(_top().board.state.turn).is_equal(0)  # You start your first game.
		app.home()
		await _frames(2)


func test_a_lesson_refuses_moves_that_do_not_teach_it() -> void:
	app.push(load("res://shell/screens/sowing_tutorial_screen.gd").create("kalah"))
	await _frames(3)
	var screen: Node = _top()
	screen._next()  # "Land in your store": only pit 2.
	await _frames(2)
	screen.board._tap(0)
	assert_bool(screen.board.busy).is_false()
	assert_bool(screen._done_card.visible).is_false()


func test_the_first_play_offers_the_lessons_once() -> void:
	var g: Dictionary = Store.data["games"]["pallanguzhi"]
	var saved := g.duplicate()
	g["tutorial_done"] = false
	g["tutorial_offered"] = false
	g["played"] = 0
	Store.set_last("mode", "pass")
	app.push(SowingGamePage.create("pallanguzhi"))
	await _frames(2)
	_top()._start()
	await _frames(2)
	assert_bool(Modal.close_top(app)).is_true()  # The offer card was showing.
	_top()._start()  # Second time: straight into the game.
	await _frames(3)
	assert_str(_top().get_script().resource_path).is_equal("res://shell/screens/sowing_play_screen.gd")
	g.merge(saved, true)
