extends GdUnitTestSuite
## Rule tests for the pits-and-seeds games (DISCUSSION.md section 29).

const S := preload("res://games/sowing/sowing_rules.gd")


func _kalah(pits: Array, turn := 0, stores := [0, 0]) -> S.State:
	var s := S.new_game(S.KALAH)
	s.pits = PackedInt32Array(pits)
	s.stores = PackedInt32Array(stores)
	s.turn = turn
	return s


func _pall(pits: Array, turn := 0, stores := [0, 0]) -> S.State:
	var s := S.new_game(S.PALLANGUZHI)
	s.pits = PackedInt32Array(pits)
	s.stores = PackedInt32Array(stores)
	s.turn = turn
	return s


func _kinds(steps: Array) -> Array:
	return steps.map(func(st: Array) -> String: return st[0])


# ---------- Kalah ----------

func test_kalah_starts_with_four_seeds_in_twelve_pits() -> void:
	var s := S.new_game(S.KALAH)
	assert_int(s.pits.size()).is_equal(12)
	assert_int(S.total_seeds(s)).is_equal(48)
	assert_array(Array(S.legal_moves(s))).is_equal([0, 1, 2, 3, 4, 5])


func test_kalah_sows_anticlockwise_one_seed_per_pit() -> void:
	var r := S.apply(S.new_game(S.KALAH), 0)
	var s: S.State = r[0]
	assert_array(Array(s.pits)).is_equal([0, 5, 5, 5, 5, 4, 4, 4, 4, 4, 4, 4])
	assert_int(s.turn).is_equal(1)


func test_kalah_last_seed_in_own_store_gives_another_turn() -> void:
	var r := S.apply(S.new_game(S.KALAH), 2)  # 4 seeds: 3, 4, 5, store.
	var s: S.State = r[0]
	assert_int(s.stores[0]).is_equal(1)
	assert_int(s.turn).is_equal(0)
	assert_str(r[1][-1][0]).is_equal(S.AGAIN)


func test_kalah_skips_the_opponents_store() -> void:
	# 13 seeds from pit 0 go all the way round once without touching store 1.
	var s := S.after(_kalah([13, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1]), 0)
	assert_int(s.stores[1]).is_equal(0)
	assert_int(s.stores[0]).is_greater_equal(1)
	assert_int(S.total_seeds(s)).is_equal(19)


func test_kalah_last_seed_in_own_empty_pit_captures_the_opposite_pit() -> void:
	# Pit 0 has 1 seed; pit 1 is empty; opposite of pit 1 is pit 10 with 5 seeds.
	var s := S.after(_kalah([1, 0, 2, 2, 2, 2, 2, 2, 2, 2, 5, 2]), 0)
	assert_int(s.stores[0]).is_equal(6)
	assert_int(s.pits[1]).is_equal(0)
	assert_int(s.pits[10]).is_equal(0)


func test_kalah_no_capture_when_the_opposite_pit_is_empty() -> void:
	var s := S.after(_kalah([1, 0, 2, 2, 2, 2, 2, 2, 2, 2, 0, 2]), 0)
	assert_int(s.stores[0]).is_equal(0)
	assert_int(s.pits[1]).is_equal(1)


func test_kalah_ends_when_a_side_is_empty_and_leftovers_go_to_their_owner() -> void:
	var s := S.after(_kalah([0, 0, 0, 0, 0, 1, 3, 0, 0, 0, 0, 2], 0, [20, 22]), 5)
	assert_bool(s.over).is_true()
	assert_int(s.stores[0]).is_equal(21)
	assert_int(s.stores[1]).is_equal(27)
	assert_int(S.result(s)).is_equal(S.WIN_1)


# ---------- Pallanguzhi ----------

func test_pallanguzhi_starts_with_six_seeds_in_fourteen_pits() -> void:
	var s := S.new_game(S.PALLANGUZHI)
	assert_int(s.pits.size()).is_equal(14)
	assert_int(S.total_seeds(s)).is_equal(84)


func test_pallanguzhi_captures_the_pit_beyond_an_empty_pit_and_the_turn_ends() -> void:
	# Pit 0 has 2: drops in 1 and 2. Next pit 3 is empty, so pit 4 (5 seeds) is captured.
	var pits := [2, 1, 1, 0, 5, 1, 1, 1, 1, 1, 1, 1, 1, 1]
	var r := S.apply(_pall(pits), 0)
	var s: S.State = r[0]
	assert_int(s.stores[0]).is_equal(5)
	assert_int(s.pits[4]).is_equal(0)
	assert_int(s.turn).is_equal(1)
	assert_str(r[1][-1][0]).is_equal(S.CAPTURE)


func test_pallanguzhi_relays_from_the_next_pit() -> void:
	# Pit 0 has 1: drops in 1. Next pit 2 has 3: pick up, drop in 3, 4, 5.
	# Next pit 6 is empty, so pit 7 (2 seeds) is captured.
	var pits := [1, 0, 3, 0, 0, 0, 0, 2, 1, 1, 1, 1, 1, 1]
	var r := S.apply(_pall(pits), 0)
	var s: S.State = r[0]
	assert_bool(_kinds(r[1]).has(S.RELAY)).is_true()
	assert_array(Array(s.pits).slice(0, 8)).is_equal([0, 1, 0, 1, 1, 1, 0, 0])
	assert_int(s.stores[0]).is_equal(2)


func test_pallanguzhi_pasu_in_your_own_pit_is_yours() -> void:
	# Pit 0 has 2: the drop into pit 1 (your own) makes 6 (pasu); then drop in 2; next 3 empty, capture 4.
	var pits := [2, 5, 0, 0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1]
	var r := S.apply(_pall(pits), 0)
	var s: S.State = r[0]
	assert_bool(_kinds(r[1]).has(S.PASU)).is_true()
	assert_int(s.pits[1]).is_equal(0)
	assert_int(s.stores[0]).is_equal(6 + 3)


func test_pallanguzhi_pasu_goes_to_the_pits_owner_not_the_sower() -> void:
	# Player 0 sows pit 6's seed into player 1's pit 7, making 6: that pasu is player 1's
	# (D63). Next pit 8 is empty, so player 0 captures pit 9 (2 seeds).
	var pits := [1, 0, 0, 0, 0, 0, 1, 5, 0, 2, 1, 1, 1, 1]
	var r := S.apply(_pall(pits), 6)
	var s: S.State = r[0]
	assert_array(Array(s.stores)).is_equal([2, 6])
	var pasu: Array = (r[1] as Array).filter(func(st: Array) -> bool: return st[0] == S.PASU)
	assert_array(pasu).is_equal([[S.PASU, 7, 6, 1]])
	# The older rule (pasu to whoever dropped the seed) is still available as an option.
	var game: Dictionary = S.PALLANGUZHI.duplicate()
	game["pasu_to"] = "sower"
	var old := _pall(pits)
	old.game = game
	assert_array(Array(S.after(old, 6).stores)).is_equal([8, 0])


func test_pallanguzhi_ends_when_the_player_to_move_has_no_seeds() -> void:
	# Player 0 captures pit 4 with their last seeds; player 1's side is empty.
	var pits := [0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	var s := S.after(_pall(pits, 0, [40, 43]), 2)
	assert_bool(s.over).is_true()
	assert_int(S.total_seeds(s)).is_equal(84)


# ---------- Both ----------

func test_random_games_always_end_and_never_lose_a_seed() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for game: Dictionary in [S.KALAH, S.PALLANGUZHI]:
		var start := S.total_seeds(S.new_game(game))
		for g in 200:
			var s := S.new_game(game, g % 2)
			var guard := 0
			while not s.over and guard < 1000:
				var moves := S.legal_moves(s)
				s = S.after(s, moves[rng.randi_range(0, moves.size() - 1)])
				assert_int(S.total_seeds(s)).is_equal(start)
				guard += 1
			assert_bool(s.over).override_failure_message("%s game %d did not end" % [game["id"], g]).is_true()


func test_saving_and_loading_gives_back_the_same_position() -> void:
	for game: Dictionary in [S.KALAH, S.PALLANGUZHI]:
		var s := S.after(S.new_game(game), int(S.legal_moves(S.new_game(game))[1]))
		var back := S.from_dict(JSON.parse_string(JSON.stringify(S.to_dict(s))))
		assert_dict(S.to_dict(back)).is_equal(S.to_dict(s))
