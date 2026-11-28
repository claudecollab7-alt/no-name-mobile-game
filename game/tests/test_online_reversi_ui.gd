extends GdUnitTestSuite
## Reversi online through the real screens and the real server (BUILD_PLAN.md G5.5):
## the page's online card, a room where you choose to move second, a friend joins by
## code, moves both ways, resign, result, record, and a rematch where you move first.

const V := preload("res://games/reversi/reversi_rules.gd")
const GamePage := preload("res://shell/screens/reversi_game_page.gd")
const PORT := 9196

var server: NetServer
var app: Node
var friend: Node
var friend_inbox: Array = []
var _saved_server := ""
var _saved_online := {}
var _saved_game := {}


func before_test() -> void:
	server = auto_free(NetServer.new())
	server.auto_start = false
	add_child(server)
	server.start(PORT)
	_saved_online = (Store.data["online"] as Dictionary).duplicate(true)
	_saved_game = (Store.data["games"]["reversi"] as Dictionary).duplicate(true)
	Store.data["online"]["server"] = "127.0.0.1:%d" % PORT
	Online.go_offline()
	app = auto_free(load("res://main.tscn").instantiate())
	add_child(app)
	await get_tree().process_frame
	Modal.close_top(app)
	friend = auto_free(load("res://shell/online.gd").new())
	friend.use_saved_token = false
	friend.url_override = "ws://127.0.0.1:%d" % PORT
	friend.message.connect(func(m: Dictionary) -> void: friend_inbox.append(m))
	add_child(friend)
	friend.go_online()


func after_test() -> void:
	Store.data["online"] = _saved_online
	Store.data["games"]["reversi"] = _saved_game
	Store.save_data()
	Online.go_offline()
	friend.go_offline()


func _until(cond: Callable, frames := 600) -> bool:
	for i in frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _top() -> Node:
	return app._stack[-1] if not app._stack.is_empty() else null


func _script_of(n: Node) -> String:
	return n.get_script().resource_path if n != null else ""


func _last(t: String) -> Dictionary:
	for i in range(friend_inbox.size() - 1, -1, -1):
		if friend_inbox[i]["t"] == t:
			return friend_inbox[i]
	return {}


func _texts(root: Node) -> Array:
	var out: Array = []
	for l in root.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out


func test_a_reversi_room_plays_through_the_screens() -> void:
	app.push(GamePage.create("reversi"))
	await get_tree().process_frame
	assert_bool(_texts(_top()).has("Play online")).is_true()
	app.push(load("res://shell/screens/online_screen.gd").create("reversi"))
	assert_bool(_texts(_top()).has("Reversi online")).is_true()
	assert_bool(_texts(_top()).has("I go second")).is_true()
	assert_bool(await _until(func() -> bool: return Online.status == "online" and friend.status == "online")).is_true()
	_top()._set_room_side("second")
	_top()._create()
	assert_bool(await _until(func() -> bool: return _script_of(_top()).ends_with("waiting_screen.gd") and _top()._code_box.visible)).is_true()
	var code: String = _top()._code_label.text

	friend.send({"t": "join", "code": code})
	assert_bool(await _until(func() -> bool: return _script_of(_top()).ends_with("reversi_play_screen.gd"))).is_true()
	var play: Node = _top()
	assert_str(play.mode).is_equal("online")
	assert_int(play.me).is_equal(1)  # You chose to move second: cream.
	assert_str(_last("start")["you"]).is_equal("first")
	assert_bool(_texts(play).has("Cream · moves second")).is_true()
	assert_bool(play.board.interactive).is_false()  # Orange's turn.

	# The friend plays first; the disc lands and flips here.
	friend.send({"t": "move", "m": V.cell(3, 2)})
	assert_bool(await _until(func() -> bool: return play.board.state.moves_played == 1 and not play.board.busy)).is_true()
	assert_int(V.owner_at(play.board.state, 3, 2)).is_equal(0)
	assert_int(V.discs(play.board.state, 0)).is_equal(4)
	assert_bool(play.board.interactive).is_true()

	# Then a tap here reaches the friend.
	friend_inbox.clear()
	var mine: int = V.legal_moves(play.board.state)[0]
	play.board._tap(mine)
	assert_bool(await _until(func() -> bool: return not _last("moved").is_empty())).is_true()
	assert_str(_last("moved")["by"]).is_equal("second")
	assert_int(int(_last("moved")["m"])).is_equal(mine)

	# Resign: the result screen, and the loss goes on the record.
	var losses := Store.game_stat("reversi", "losses")
	Online.send({"t": "resign"})
	assert_bool(await _until(func() -> bool: return _script_of(_top()).ends_with("reversi_result_screen.gd"))).is_true()
	assert_str(_top().reason).is_equal("resign")
	assert_int(Store.game_stat("reversi", "losses")).is_equal(losses + 1)

	# Rematch: both say yes, and this time you move first.
	friend.send({"t": "rematch"})
	_top()._ask_rematch()
	assert_bool(await _until(func() -> bool: return _script_of(_top()).ends_with("reversi_play_screen.gd") and _top() != play)).is_true()
	assert_int(_top().me).is_equal(0)
	assert_int(_top().board.state.moves_played).is_equal(0)
	assert_bool(_top().board.interactive).is_true()


func test_a_pass_the_server_plays_for_you_shows_on_the_board() -> void:
	# You are cream. Orange takes your only nearby disc; you have no move, so the server
	# passes for you straight after.
	var start := V.from_dict({"rows": ["0.......", ".1......", "........", "........", "........", "........", "......1.", ".......0"], "turn": 0})
	var play: Node = load("res://shell/screens/reversi_play_screen.gd").create_online({
		"game": "reversi", "you": "second", "opponent": {"name": "Ben"}, "state": V.to_dict(start), "turn_ms": 45000})
	app.push(play)
	await get_tree().process_frame
	var moved := V.after(start, V.cell(2, 2))
	var passed := V.after(moved, V.PASS)
	play._on_online({"t": "moved", "m": V.cell(2, 2), "by": "first", "state": V.to_dict(moved), "turn_ms": 45000})
	play._on_online({"t": "moved", "m": V.PASS, "by": "second", "state": V.to_dict(passed), "turn_ms": 45000})
	assert_bool(await _until(func() -> bool: return not play.board.busy)).is_true()
	assert_int(play.board.state.last_move).is_equal(V.PASS)
	assert_int(play.board.state.turn).is_equal(0)
	assert_str(play._hint.text).starts_with("You had no move and passed.")
	assert_bool(play.board.interactive).is_false()
	play._finished = true  # Nothing to leave on the server.
