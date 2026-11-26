extends GdUnitTestSuite
## The pits-and-seeds board: layout, tapping, animation from move steps, skipping.

const S := preload("res://games/sowing/sowing_rules.gd")
const Board := preload("res://games/sowing/board/sowing_board_view.gd")


func _board(game: Dictionary = S.KALAH) -> Board:
	var b: Board = Board.new()
	add_child(auto_free(b))
	b.layout(Vector2(1000, 1200))
	b.new_game(game)
	return b


## Runs the move animation to the end in small time steps.
func _settle(b: Board) -> void:
	var guard := 0
	while b.busy and guard < 2000:
		b._advance(1.0 / 60.0)
		guard += 1


func test_your_row_runs_left_to_right_along_the_bottom_and_opposites_share_a_column() -> void:
	for game: Dictionary in [S.KALAH, S.PALLANGUZHI]:
		var b := _board(game)
		var n := S.pits_per_side(b.state)
		for i in n - 1:
			assert_float(b.pit_pos(i + 1).x).is_greater(b.pit_pos(i).x)
		for i in n:
			var opp := S.opposite(b.state, i)
			assert_float(b.pit_pos(opp).x).is_equal_approx(b.pit_pos(i).x, 0.01)
			assert_float(b.pit_pos(opp).y).is_less(b.pit_pos(i).y)
		assert_bool(b.tray.end.x <= 1000.0 and b.tray.position.x >= 0.0).is_true()


func test_turning_the_board_puts_the_other_player_at_the_bottom() -> void:
	var b := _board()
	var low := b.pit_pos(0)
	b.bottom = 1
	assert_vector(b.pit_pos(6)).is_equal(low)
	assert_float(b.store_pos(1).x).is_greater(b.store_pos(0).x)


func test_a_tap_finds_the_pit_under_the_finger() -> void:
	var b := _board()
	for pit in 12:
		assert_int(b.pit_at(b.pit_pos(pit) + Vector2(b.cell * 0.3, b.cell * 0.5))).is_equal(pit)
	assert_int(b.pit_at(Vector2(2, 2))).is_equal(-1)


func test_tapping_your_pit_plays_it_and_seeds_land_one_at_a_time() -> void:
	var b := _board()
	var moved := [-1]
	var sounds: Array = []
	b.human_moved.connect(func(p: int) -> void: moved[0] = p)
	b.played.connect(func(k: String) -> void: sounds.append(k))
	b._tap(2)
	assert_int(moved[0]).is_equal(2)
	assert_bool(b.busy).is_true()
	assert_int(b.state.stores[0]).is_equal(1)  # The rules are already applied...
	assert_int(b.shown_stores[0]).is_equal(0)  # ...but the store fills as the seed lands.
	_settle(b)
	assert_bool(b.busy).is_false()
	assert_array(Array(b.shown)).is_equal(Array(b.state.pits))
	assert_array(Array(b.shown_stores)).is_equal(Array(b.state.stores))
	assert_int(sounds.count("seed")).is_equal(4)
	assert_bool(sounds.has("again")).is_true()
	assert_int(b.last_pit).is_equal(2)


func test_the_screen_hears_about_the_move_only_when_the_seeds_have_settled() -> void:
	var b := _board()
	var changes := [0]
	b.changed.connect(func() -> void: changes[0] += 1)
	b._tap(0)
	assert_int(changes[0]).is_equal(0)
	_settle(b)
	assert_int(changes[0]).is_equal(1)


func test_empty_pits_and_the_other_players_pits_say_no() -> void:
	var b := _board()
	var sounds: Array = []
	b.played.connect(func(k: String) -> void: sounds.append(k))
	b._tap(8)  # Player 1's pit on player 0's turn.
	assert_bool(b.busy).is_false()
	b._tap(0)
	_settle(b)
	b._tap(0)  # Still player 1's turn... and pit 0 is empty anyway.
	assert_int(sounds.count("nope")).is_equal(2)


func test_tapping_during_a_long_move_skips_to_the_end() -> void:
	var b := _board(S.PALLANGUZHI)
	b._tap(3)
	assert_bool(b.busy).is_true()
	var changes := [0]
	b.changed.connect(func() -> void: changes[0] += 1)
	b._tap(-1)
	assert_bool(b.busy).is_false()
	assert_int(changes[0]).is_equal(1)
	assert_array(Array(b.shown)).is_equal(Array(b.state.pits))


func test_captures_fly_to_the_players_pile() -> void:
	var b := _board(S.PALLANGUZHI)
	var s := S.new_game(S.PALLANGUZHI)
	s.pits = PackedInt32Array([2, 1, 1, 0, 5, 1, 1, 1, 1, 1, 1, 1, 1, 64])
	b.set_state(s)
	var sounds: Array = []
	b.played.connect(func(k: String) -> void: sounds.append(k))
	b._tap(0)
	_settle(b)
	assert_int(b.shown_stores[0]).is_equal(5)
	assert_bool(sounds.has("capture")).is_true()


func test_only_moves_limits_the_tutorial_to_the_pits_it_names() -> void:
	var b := _board()
	b.only_moves = PackedInt32Array([2])
	b._tap(0)
	assert_bool(b.busy).is_false()
	b._tap(2)
	assert_bool(b.busy).is_true()


func test_the_computer_can_play_while_seeds_are_still_moving() -> void:
	var b := _board()
	b._tap(0)
	b.play_move(7)  # Finishes the first move at once, then plays the second.
	_settle(b)
	assert_array(Array(b.shown)).is_equal(Array(b.state.pits))
	assert_int(b.state.moves_played).is_equal(2)
	assert_int(S.total_seeds(b.state)).is_equal(48)


func test_a_new_position_shows_at_once() -> void:
	var b := _board()
	b._tap(1)
	var s := S.new_game(S.KALAH, 1)
	b.set_state(s)
	assert_bool(b.busy).is_false()
	assert_int(b.last_pit).is_equal(-1)
	assert_array(Array(b.shown)).is_equal(Array(s.pits))
