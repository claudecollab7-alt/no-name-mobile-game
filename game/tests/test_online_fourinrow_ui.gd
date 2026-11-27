extends GdUnitTestSuite
## Four in a Row online through the real screens and the real server (BUILD_PLAN.md
## G4.5): the page's online card, a room where you choose to move second, a friend joins
## by code, discs both ways, resign, result, record, and a rematch where you move first.

const F := preload("res://games/fourinrow/four_rules.gd")
const GamePage := preload("res://shell/screens/four_game_page.gd")
const PORT := 9195

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
	_saved_game = (Store.data["games"]["fourinrow"] as Dictionary).duplicate(true)
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
	Store.data["games"]["fourinrow"] = _saved_game
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


func test_a_four_in_a_row_room_plays_through_the_screens() -> void:
	app.push(GamePage.create("fourinrow"))
	await get_tree().process_frame
	assert_bool(_texts(_top()).has("Play online")).is_true()
	app.push(load("res://shell/screens/online_screen.gd").create("fourinrow"))
	assert_bool(_texts(_top()).has("Four in a Row online")).is_true()
	assert_bool(_texts(_top()).has("I go second")).is_true()
	assert_bool(_texts(_top()).has("Move first")).is_true()
	assert_bool(await _until(func() -> bool: return Online.status == "online" and friend.status == "online")).is_true()
	_top()._set_room_side("second")
	_top()._create()
	assert_bool(await _until(func() -> bool: return _script_of(_top()).ends_with("waiting_screen.gd") and _top()._code_box.visible)).is_true()
	var code: String = _top()._code_label.text

	friend.send({"t": "join", "code": code})
	assert_bool(await _until(func() -> bool: return _script_of(_top()).ends_with("four_play_screen.gd"))).is_true()
	var play: Node = _top()
	assert_str(play.mode).is_equal("online")
	assert_int(play.me).is_equal(1)  # You chose to move second: cream.
	assert_str(_last("start")["you"]).is_equal("first")
	assert_bool(_texts(play).has("Cream · moves second")).is_true()

	# The friend drops first; it lands on this board.
	friend.send({"t": "move", "m": 3})
	assert_bool(await _until(func() -> bool: return play.board.state.moves_played == 1 and not play.board.busy)).is_true()
	assert_int(F.owner_at(play.board.state, 3, 0)).is_equal(0)

	# Then a tap here reaches the friend.
	friend_inbox.clear()
	play.board._tap(4)
	assert_bool(await _until(func() -> bool: return not _last("moved").is_empty())).is_true()
	assert_str(_last("moved")["by"]).is_equal("second")
	assert_int(int(_last("moved")["m"])).is_equal(4)

	# Resign: the result screen, and the loss goes on the record as moving second.
	var losses := Store.game_stat("fourinrow", "losses")
	Online.send({"t": "resign"})
	assert_bool(await _until(func() -> bool: return _script_of(_top()).ends_with("four_result_screen.gd"))).is_true()
	assert_str(_top().reason).is_equal("resign")
	assert_int(Store.game_stat("fourinrow", "losses")).is_equal(losses + 1)

	# Rematch: both say yes, and this time you move first.
	friend.send({"t": "rematch"})
	_top()._ask_rematch()
	assert_bool(await _until(func() -> bool: return _script_of(_top()).ends_with("four_play_screen.gd") and _top() != play)).is_true()
	assert_int(_top().me).is_equal(0)
	assert_int(_top().board.state.moves_played).is_equal(0)
