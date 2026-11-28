extends GdUnitTestSuite
## Online-play logic without networking: rooms, quick match, moves, timer, chat, rematch.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")

var lobby: OnlineLobby
var now := 1000


func before_test() -> void:
	lobby = OnlineLobby.new(42)
	now = 1000


func _hello(peer: int, name := "Ana") -> Array:
	return lobby.handle(peer, {"t": "hello", "v": OnlineLobby.PROTOCOL, "name": name, "avatar": "goat", "colour": 1}, now)


func _to(out: Array, peer: int, t: String) -> Dictionary:
	for pair: Array in out:
		if pair[0] == peer and pair[1]["t"] == t:
			return pair[1]
	return {}


func _start_room(side := "goats") -> Array:
	_hello(1, "Ana")
	_hello(2, "Ben")
	var code: String = _to(lobby.handle(1, {"t": "create", "side": side}, now), 1, "room")["code"]
	return lobby.handle(2, {"t": "join", "code": code}, now)


func test_hello_gives_a_token_and_checks_the_protocol_version() -> void:
	assert_str(_to(_hello(1), 1, "welcome")["token"]).is_not_empty()
	var old := lobby.handle(9, {"t": "hello", "v": 0}, now)
	assert_str(_to(old, 9, "error")["code"]).is_equal("update_needed")


func test_names_are_filtered() -> void:
	assert_str(_to(_hello(1, "  Swift   Goat!! "), 1, "welcome")["name"]).is_equal("Swift Goat")
	assert_str(_to(_hello(2, "sh1t head"), 2, "welcome")["name"]).is_equal("Player")
	assert_str(NameFilter.clean("Peacock")).is_equal("Peacock")


func test_create_and_join_a_private_room_starts_the_game_with_chosen_sides() -> void:
	var out := _start_room("tigers")
	assert_str(_to(out, 1, "start")["you"]).is_equal("tigers")
	assert_str(_to(out, 2, "start")["you"]).is_equal("goats")
	assert_str(_to(out, 2, "start")["opponent"]["name"]).is_equal("Ana")
	assert_bool(_to(out, 1, "start")["private"]).is_true()


func test_joining_a_wrong_code_or_full_room_is_refused() -> void:
	_hello(3)
	assert_str(_to(lobby.handle(3, {"t": "join", "code": "ZZZZZ"}, now), 3, "error")["code"]).is_equal("no_room")
	var out := _start_room()
	var code: String = _to(out, 1, "start")["code"]
	assert_str(_to(lobby.handle(3, {"t": "join", "code": code}, now), 3, "error")["code"]).is_equal("room_full")


func test_quick_match_pairs_two_searchers_and_respects_side_wishes() -> void:
	_hello(1)
	_hello(2)
	assert_dict(_to(lobby.handle(1, {"t": "search", "side": "tigers"}, now), 1, "searching")).is_not_empty()
	var out := lobby.handle(2, {"t": "search", "side": "any"}, now)
	assert_str(_to(out, 1, "start")["you"]).is_equal("tigers")
	assert_str(_to(out, 2, "start")["you"]).is_equal("goats")
	assert_bool(_to(out, 1, "start")["private"]).is_false()


func test_two_players_wanting_the_same_side_are_not_paired() -> void:
	_hello(1)
	_hello(2)
	lobby.handle(1, {"t": "search", "side": "goats"}, now)
	assert_dict(_to(lobby.handle(2, {"t": "search", "side": "goats"}, now), 2, "searching")).is_not_empty()


func test_server_applies_legal_moves_and_refuses_moves_out_of_turn() -> void:
	_start_room("goats")
	var place := R.encode(R.NONE, 19, R.NONE)
	var wrong := lobby.handle(2, {"t": "move", "m": place}, now)  # Ben is tigers.
	assert_dict(_to(wrong, 2, "sync")).is_not_empty()
	var ok := lobby.handle(1, {"t": "move", "m": place}, now)
	assert_int(_to(ok, 2, "moved")["m"]).is_equal(place)
	var illegal := lobby.handle(2, {"t": "move", "m": R.encode(0, 22, R.NONE)}, now)
	assert_dict(_to(illegal, 2, "sync")).is_not_empty()


func test_chat_is_relayed_by_id_and_rate_limited() -> void:
	_start_room()
	assert_int(_to(lobby.handle(1, {"t": "chat", "id": 3}, now), 2, "chat")["id"]).is_equal(3)
	assert_dict(_to(lobby.handle(1, {"t": "chat", "id": 4}, now + 500), 2, "chat")).is_empty()
	assert_dict(_to(lobby.handle(1, {"t": "chat", "id": 99}, now + 5000), 2, "chat")).is_empty()


func test_first_time_out_plays_a_random_move_and_the_second_forfeits() -> void:
	_start_room("goats")
	now += OnlineLobby.TURN_MS
	var first := lobby.tick(now)
	assert_str(_to(first, 1, "timeout")["side"]).is_equal("goats")
	assert_dict(_to(first, 2, "moved")).is_not_empty()
	# Tigers (Ben) reply, then goats (Ana) time out again.
	var s: R.State = lobby.rooms.values()[0]["state"]
	lobby.handle(2, {"t": "move", "m": R.legal_moves(s)[0]}, now)
	now += OnlineLobby.TURN_MS
	var second := lobby.tick(now)
	assert_str(_to(second, 1, "end")["reason"]).is_equal("timeout")
	assert_str(_to(second, 1, "end")["winner"]).is_equal("tigers")


func test_resign_ends_the_game_and_rematch_swaps_sides() -> void:
	_start_room("goats")
	var end := lobby.handle(1, {"t": "resign"}, now)
	assert_str(_to(end, 2, "end")["winner"]).is_equal("tigers")
	assert_dict(_to(lobby.handle(1, {"t": "rematch"}, now), 2, "rematch_offer")).is_not_empty()
	var again := lobby.handle(2, {"t": "rematch"}, now)
	assert_str(_to(again, 1, "start")["you"]).is_equal("tigers")


func test_disconnected_player_can_reconnect_with_their_token() -> void:
	_start_room()
	var token: String = lobby.players[1]["token"]
	assert_dict(_to(lobby.disconnected(1, now), 2, "opponent_away")).is_not_empty()
	var back := lobby.handle(7, {"t": "hello", "v": OnlineLobby.PROTOCOL, "token": token}, now + 5000)
	assert_dict(_to(back, 7, "start")).is_not_empty()
	assert_dict(_to(back, 2, "opponent_back")).is_not_empty()


func test_player_who_never_returns_loses_after_a_minute() -> void:
	_start_room("goats")
	lobby.disconnected(1, now)
	var out := lobby.tick(now + OnlineLobby.RECONNECT_MS)
	assert_str(_to(out, 2, "end")["reason"]).is_equal("left")
	assert_str(_to(out, 2, "end")["winner"]).is_equal("tigers")
	assert_bool(lobby.rooms.is_empty()).is_true()


func test_full_game_over_the_lobby_ends_with_a_result() -> void:
	_start_room("goats")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var ended := {}
	for i in 400:
		var room: Dictionary = lobby.rooms.values()[0]
		var s: R.State = room["state"]
		var mover := 1 if s.turn == R.GOAT else 2
		var moves := R.legal_moves(s)
		var out := lobby.handle(mover, {"t": "move", "m": moves[rng.randi_range(0, moves.size() - 1)]}, now)
		ended = _to(out, 1, "end")
		if not ended.is_empty():
			break
	assert_dict(ended).is_not_empty()


# ---------- Seed games ----------

const S := preload("res://games/sowing/sowing_rules.gd")


func _start_seed_room(game: String, side := "first") -> Array:
	_hello(1, "Ana")
	_hello(2, "Ben")
	var code: String = _to(lobby.handle(1, {"t": "create", "side": side, "game": game}, now), 1, "room")["code"]
	return lobby.handle(2, {"t": "join", "code": code}, now)


func test_a_room_plays_the_game_it_was_created_for() -> void:
	var out := _start_seed_room("pallanguzhi")
	var start := _to(out, 2, "start")
	assert_str(start["game"]).is_equal("pallanguzhi")
	assert_str(start["you"]).is_equal("second")
	assert_str(_to(out, 1, "start")["you"]).is_equal("first")
	assert_int((start["state"]["pits"] as Array).size()).is_equal(14)


func test_old_clients_without_a_game_get_tiger_and_goat() -> void:
	var out := _start_room()
	assert_str(_to(out, 1, "start")["game"]).is_equal("aadupuli")


func test_quick_match_only_pairs_players_of_the_same_game() -> void:
	_hello(1)
	_hello(2)
	_hello(3)
	lobby.handle(1, {"t": "search", "side": "any", "game": "kalah"}, now)
	assert_dict(_to(lobby.handle(2, {"t": "search", "side": "any", "game": "pallanguzhi"}, now), 2, "searching")).is_not_empty()
	var out := lobby.handle(3, {"t": "search", "side": "any", "game": "kalah"}, now)
	assert_str(_to(out, 1, "start")["game"]).is_equal("kalah")
	assert_str(_to(out, 3, "start")["game"]).is_equal("kalah")


func test_seed_moves_are_checked_and_an_extra_turn_keeps_the_same_mover() -> void:
	_start_seed_room("kalah")
	assert_dict(_to(lobby.handle(2, {"t": "move", "m": 7}, now), 2, "sync")).is_not_empty()  # Not Ben's turn.
	var out := lobby.handle(1, {"t": "move", "m": 2}, now)  # Lands in Ana's store: she goes again.
	assert_str(_to(out, 2, "moved")["by"]).is_equal("first")
	assert_int(int(_to(out, 2, "moved")["state"]["turn"])).is_equal(0)
	assert_dict(_to(lobby.handle(2, {"t": "move", "m": 7}, now), 2, "sync")).is_not_empty()
	assert_dict(_to(lobby.handle(1, {"t": "move", "m": 5}, now), 2, "moved")).is_not_empty()


func test_a_seed_game_over_the_lobby_ends_with_a_winner_or_draw_and_rematch_swaps_who_starts() -> void:
	for game: String in ["kalah", "pallanguzhi"]:
		before_test()
		_start_seed_room(game, "first")
		var rng := RandomNumberGenerator.new()
		rng.seed = 8
		var ended := {}
		for i in 500:
			var room: Dictionary = lobby.rooms.values()[0]
			var s: S.State = room["state"]
			var mover := 1 if s.turn == 0 else 2
			var moves := S.legal_moves(s)
			var out := lobby.handle(mover, {"t": "move", "m": moves[rng.randi_range(0, moves.size() - 1)]}, now)
			ended = _to(out, 2, "end")
			if not ended.is_empty():
				break
		assert_bool(str(ended.get("winner", "")) in ["first", "second", "draw"]).is_true()
		lobby.handle(1, {"t": "rematch"}, now)
		var again := lobby.handle(2, {"t": "rematch"}, now)
		assert_str(_to(again, 1, "start")["you"]).is_equal("second")


func test_a_seed_time_out_plays_a_random_pit_for_the_slow_player() -> void:
	_start_seed_room("pallanguzhi")
	now += OnlineLobby.TURN_MS
	var out := lobby.tick(now)
	assert_str(_to(out, 2, "timeout")["side"]).is_equal("first")
	assert_dict(_to(out, 2, "moved")).is_not_empty()


# ---------- Bagh-Chal ----------

func _start_bagh_room(side := "goats") -> Array:
	_hello(1, "Ana")
	_hello(2, "Ben")
	var code: String = _to(lobby.handle(1, {"t": "create", "side": side, "game": "baghchal"}, now), 1, "room")["code"]
	return lobby.handle(2, {"t": "join", "code": code}, now)


func test_a_bagh_chal_room_starts_on_its_own_board_with_tigers_and_goats() -> void:
	var out := _start_bagh_room("tigers")
	var start := _to(out, 2, "start")
	assert_str(start["game"]).is_equal("baghchal")
	assert_str(_to(out, 1, "start")["you"]).is_equal("tigers")
	assert_str(start["you"]).is_equal("goats")
	var s := R.from_dict(start["state"])
	assert_str(s.board).is_equal("baghchal")
	assert_array(Array(s.tigers)).is_equal([0, 4, 20, 24])
	assert_int(s.in_hand).is_equal(20)


func test_quick_match_keeps_bagh_chal_and_tiger_and_goat_apart() -> void:
	_hello(1)
	_hello(2)
	_hello(3)
	lobby.handle(1, {"t": "search", "side": "tigers", "game": "baghchal"}, now)
	assert_dict(_to(lobby.handle(2, {"t": "search", "side": "goats", "game": "aadupuli"}, now), 2, "searching")).is_not_empty()
	var out := lobby.handle(3, {"t": "search", "side": "goats", "game": "baghchal"}, now)
	assert_str(_to(out, 1, "start")["you"]).is_equal("tigers")
	assert_str(_to(out, 3, "start")["you"]).is_equal("goats")
	assert_str(_to(out, 3, "start")["state"]["board"]).is_equal("baghchal")


func test_the_server_refuses_a_bagh_chal_move_that_goes_back_to_an_old_position() -> void:
	_start_bagh_room("goats")  # Ana (1) goats, Ben (2) tigers.
	var room: Dictionary = lobby.rooms.values()[0]
	room["state"] = R.from_dict({
		"tigers": [0, 4, 20, 24], "goats": 1 << 2, "in_hand": 0, "captured": 0, "turn": R.GOAT,
		"board": "baghchal", "repeat_limit": 2, "goat_count": 20, "quiet_limit": 0,
	})
	for pair: Array in [[1, R.encode(2, 7, R.NONE)], [2, R.encode(20, 15, R.NONE)], [1, R.encode(7, 2, R.NONE)], [2, R.encode(15, 20, R.NONE)]]:
		assert_dict(_to(lobby.handle(pair[0], {"t": "move", "m": pair[1]}, now), 1, "moved")).is_not_empty()
	# Back where it started; stepping down again would repeat the position after move one.
	var again := R.encode(2, 7, R.NONE)
	assert_bool(R.legal_moves(room["state"]).has(again)).is_false()
	assert_dict(_to(lobby.handle(1, {"t": "move", "m": again}, now), 1, "sync")).is_not_empty()


func test_a_bagh_chal_game_over_the_lobby_ends_and_rematch_swaps_sides() -> void:
	_start_bagh_room("goats")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var ended := {}
	for i in 600:
		var room: Dictionary = lobby.rooms.values()[0]
		var s: R.State = room["state"]
		var mover := 1 if s.turn == R.GOAT else 2
		var moves := R.legal_moves(s)
		var out := lobby.handle(mover, {"t": "move", "m": moves[rng.randi_range(0, moves.size() - 1)]}, now)
		ended = _to(out, 1, "end")
		if not ended.is_empty():
			break
	assert_bool(str(ended.get("winner", "")) in ["tigers", "goats"]).is_true()
	assert_str(ended["state"]["board"]).is_equal("baghchal")
	lobby.handle(1, {"t": "rematch"}, now)
	var again := lobby.handle(2, {"t": "rematch"}, now)
	assert_str(_to(again, 1, "start")["you"]).is_equal("tigers")
	assert_str(_to(again, 1, "start")["state"]["board"]).is_equal("baghchal")


# ---------- Four in a Row ----------

const F := preload("res://games/fourinrow/four_rules.gd")


func _start_four_room(side := "first") -> Array:
	_hello(1, "Ana")
	_hello(2, "Ben")
	var code: String = _to(lobby.handle(1, {"t": "create", "side": side, "game": "fourinrow"}, now), 1, "room")["code"]
	return lobby.handle(2, {"t": "join", "code": code}, now)


func test_a_four_in_a_row_room_starts_empty_with_the_chosen_seats() -> void:
	var out := _start_four_room("second")
	var start := _to(out, 1, "start")
	assert_str(start["game"]).is_equal("fourinrow")
	assert_str(start["you"]).is_equal("second")
	assert_str(_to(out, 2, "start")["you"]).is_equal("first")
	var s := F.from_dict(start["state"])
	assert_int(s.moves_played).is_equal(0)
	assert_int(s.turn).is_equal(0)


func test_four_in_a_row_quick_match_respects_seats_and_stays_apart() -> void:
	_hello(1)
	_hello(2)
	_hello(3)
	lobby.handle(1, {"t": "search", "side": "first", "game": "fourinrow"}, now)
	assert_dict(_to(lobby.handle(2, {"t": "search", "side": "second", "game": "kalah"}, now), 2, "searching")).is_not_empty()
	var out := lobby.handle(3, {"t": "search", "side": "second", "game": "fourinrow"}, now)
	assert_str(_to(out, 1, "start")["you"]).is_equal("first")
	assert_str(_to(out, 3, "start")["you"]).is_equal("second")


func test_the_server_refuses_full_columns_and_moves_out_of_turn() -> void:
	_start_four_room("first")  # Ana (1) first, Ben (2) second.
	assert_dict(_to(lobby.handle(2, {"t": "move", "m": 3}, now), 2, "sync")).is_not_empty()  # Not Ben's turn.
	for i in 6:
		var mover := 1 if i % 2 == 0 else 2
		assert_dict(_to(lobby.handle(mover, {"t": "move", "m": 0}, now), 1, "moved")).is_not_empty()
	assert_dict(_to(lobby.handle(1, {"t": "move", "m": 0}, now), 1, "sync")).is_not_empty()  # Column 0 is full.
	assert_dict(_to(lobby.handle(1, {"t": "move", "m": 9}, now), 1, "sync")).is_not_empty()  # No such column.


func test_four_in_a_row_ends_with_four_and_rematch_swaps_who_moves_first() -> void:
	_start_four_room("first")
	var ended := {}
	for c: int in [0, 1, 0, 1, 0, 1, 0]:  # Ana stacks four up column 0.
		var mover := 1 if (lobby.rooms.values()[0]["state"] as F.State).turn == 0 else 2
		ended = _to(lobby.handle(mover, {"t": "move", "m": c}, now), 2, "end")
	assert_str(ended["winner"]).is_equal("first")
	assert_str(ended["reason"]).is_equal("four")
	lobby.handle(1, {"t": "rematch"}, now)
	var again := lobby.handle(2, {"t": "rematch"}, now)
	assert_str(_to(again, 1, "start")["you"]).is_equal("second")
	assert_int(F.from_dict(_to(again, 1, "start")["state"]).moves_played).is_equal(0)


func test_a_full_four_in_a_row_board_is_a_draw() -> void:
	_start_four_room("first")
	# Columns filled so no four forms: the drawn pattern from the rules tests.
	var room: Dictionary = lobby.rooms.values()[0]
	var columns: Array = []
	for col in F.COLS:
		var discs: Array = []
		for row in F.ROWS:
			discs.append((col + floori(row / 3.0)) % 2)
		columns.append(discs)
	columns[6].pop_back()  # Leave the last space for the final move.
	room["state"] = F.from_dict({"columns": columns, "turn": 1})
	var out := lobby.handle(2, {"t": "move", "m": 6}, now)
	var ended := _to(out, 1, "end")
	assert_str(ended["winner"]).is_equal("draw")
	assert_str(ended["reason"]).is_equal("full")


# ---------- Reversi ----------

const V := preload("res://games/reversi/reversi_rules.gd")


func _start_reversi_room(side := "first") -> Array:
	_hello(1, "Ana")
	_hello(2, "Ben")
	var code: String = _to(lobby.handle(1, {"t": "create", "side": side, "game": "reversi"}, now), 1, "room")["code"]
	return lobby.handle(2, {"t": "join", "code": code}, now)


func _all_to(out: Array, peer: int, t: String) -> Array:
	var found: Array = []
	for pair: Array in out:
		if pair[0] == peer and pair[1]["t"] == t:
			found.append(pair[1])
	return found


func test_a_reversi_room_starts_with_four_discs_and_the_chosen_seats() -> void:
	var out := _start_reversi_room("second")
	var start := _to(out, 1, "start")
	assert_str(start["game"]).is_equal("reversi")
	assert_str(start["you"]).is_equal("second")
	assert_str(_to(out, 2, "start")["you"]).is_equal("first")
	var s := V.from_dict(start["state"])
	assert_int(V.discs(s, 0) + V.discs(s, 1)).is_equal(4)
	assert_int(s.turn).is_equal(0)


func test_the_server_refuses_squares_that_flip_nothing_and_moves_out_of_turn() -> void:
	_start_reversi_room("first")  # Ana (1) orange, Ben (2) cream.
	assert_dict(_to(lobby.handle(2, {"t": "move", "m": V.cell(3, 2)}, now), 2, "sync")).is_not_empty()  # Not Ben's turn.
	assert_dict(_to(lobby.handle(1, {"t": "move", "m": 0}, now), 1, "sync")).is_not_empty()  # Flips nothing.
	assert_dict(_to(lobby.handle(1, {"t": "move", "m": V.PASS}, now), 1, "sync")).is_not_empty()  # Can't pass with moves.
	assert_dict(_to(lobby.handle(1, {"t": "move", "m": V.cell(3, 2)}, now), 2, "moved")).is_not_empty()


func test_a_player_with_no_move_passes_at_once() -> void:
	_start_reversi_room("first")
	var room: Dictionary = lobby.rooms.values()[0]
	# Orange takes cream's disc at (1,1); then cream has no move but orange still does.
	room["state"] = V.from_dict({"rows": ["0.......", ".1......", "........", "........", "........", "........", "......1.", ".......0"], "turn": 0})
	var out := lobby.handle(1, {"t": "move", "m": V.cell(2, 2)}, now)
	var moved := _all_to(out, 2, "moved")
	assert_int(moved.size()).is_equal(2)
	assert_int(int(moved[1]["m"])).is_equal(V.PASS)
	assert_str(moved[1]["by"]).is_equal("second")
	var s: V.State = room["state"]
	assert_int(s.turn).is_equal(0)
	assert_str(room["status"]).is_equal("playing")


func test_reversi_ends_on_the_disc_count_and_rematch_swaps_who_moves_first() -> void:
	_start_reversi_room("first")
	var room: Dictionary = lobby.rooms.values()[0]
	room["state"] = V.from_dict({"rows": ["0.......", ".1......", "........", "........", "........", "........", "........", "........"], "turn": 0})
	var ended := _to(lobby.handle(1, {"t": "move", "m": V.cell(2, 2)}, now), 2, "end")
	assert_str(ended["winner"]).is_equal("first")
	assert_str(ended["reason"]).is_equal("discs")
	lobby.handle(1, {"t": "rematch"}, now)
	var again := lobby.handle(2, {"t": "rematch"}, now)
	assert_str(_to(again, 1, "start")["you"]).is_equal("second")
	assert_int(V.from_dict(_to(again, 1, "start")["state"]).moves_played).is_equal(0)
