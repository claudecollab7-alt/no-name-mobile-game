extends GdUnitTestSuite
## Bagh-Chal online through the real screens and the real server (BUILD_PLAN.md G3.5):
## the game page's online card, a room where you pick tigers, a friend joins by code,
## moves both ways on the Bagh-Chal board, resign, result, record, and a rematch on
## the same board with sides swapped.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const GamePage := preload("res://shell/screens/game_page.gd")
const PORT := 9194

var server: NetServer
var app: Node
var friend: Node
var friend_inbox: Array = []
var _saved_server := ""
var _saved_side := ""


func before_test() -> void:
	server = auto_free(NetServer.new())
	server.auto_start = false
	add_child(server)
	server.start(PORT)
	_saved_server = str(Store.data["online"]["server"])
	_saved_side = str(Store.data["online"]["room_side"])
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
	Store.data["online"]["server"] = _saved_server
	Store.data["online"]["room_side"] = _saved_side
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


func test_a_bagh_chal_room_plays_through_the_screens() -> void:
	# The game page has an online card, and it opens Bagh-Chal's online screen.
	app.push(GamePage.create("baghchal"))
	await get_tree().process_frame
	assert_bool(_texts(_top()).has("Play online")).is_true()
	app.push(load("res://shell/screens/online_screen.gd").create("baghchal"))
	assert_bool(_texts(_top()).has("Bagh-Chal online")).is_true()
	assert_bool(_texts(_top()).has("I'm tigers")).is_true()  # You can pick a side.
	assert_bool(await _until(func() -> bool: return Online.status == "online" and friend.status == "online")).is_true()
	_top()._set_room_side("tigers")
	_top()._create()
	assert_bool(await _until(func() -> bool: return _script_of(_top()).ends_with("waiting_screen.gd") and _top()._code_box.visible)).is_true()
	var code: String = _top()._code_label.text

	friend.send({"t": "join", "code": code})
	assert_bool(await _until(func() -> bool: return _script_of(_top()).ends_with("/play_screen.gd"))).is_true()
	var play: Node = _top()
	assert_str(play.mode).is_equal("online")
	assert_str(play.board_id).is_equal("baghchal")
	assert_str(play.human_side).is_equal("tigers")
	assert_str(play.board.state.board).is_equal("baghchal")
	assert_int(play.board.state.in_hand).is_equal(20)
	assert_str(_last("start")["you"]).is_equal("goats")

	# Goats first: the friend places a goat and it shows on this board.
	friend.send({"t": "move", "m": R.encode(R.NONE, 12, R.NONE)})
	assert_bool(await _until(func() -> bool: return play.board.state.moves_played == 1 and not play.board.busy)).is_true()
	assert_int(play.board.state.in_hand).is_equal(19)

	# Then the tigers here: the friend sees the move.
	friend_inbox.clear()
	var m: int = R.legal_moves(play.board.state)[0]
	play.board._tap(R.move_from(m))  # Pick up a tiger...
	play.board._tap(R.move_to(m))  # ...and put it down.
	assert_bool(await _until(func() -> bool: return not _last("moved").is_empty())).is_true()
	assert_str(_last("moved")["by"]).is_equal("tigers")

	# Resign: the result screen, and the loss goes on Bagh-Chal's own record.
	var losses := Store.game_stat("baghchal", "losses")
	var tg_played := Store.stat("played")
	Online.send({"t": "resign"})
	assert_bool(await _until(func() -> bool: return _script_of(_top()).ends_with("result_screen.gd"))).is_true()
	assert_str(_top().reason).is_equal("resign")
	assert_int(Store.game_stat("baghchal", "losses")).is_equal(losses + 1)
	assert_int(Store.stat("played")).is_equal(tg_played + 1)

	# Rematch: both say yes; same board, and this time you are the goats.
	friend.send({"t": "rematch"})
	_top()._ask_rematch()
	assert_bool(await _until(func() -> bool: return _script_of(_top()).ends_with("/play_screen.gd") and _top() != play)).is_true()
	assert_str(_top().board_id).is_equal("baghchal")
	assert_str(_top().human_side).is_equal("goats")
	assert_str(_top().board.state.board).is_equal("baghchal")
