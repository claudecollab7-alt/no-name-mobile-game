extends GdUnitTestSuite
## Pallanguzhi online through the real screens and the real server: create a room for
## the game, a friend joins by code, moves both ways, chat, resign, result, rematch
## (in which the other player starts).

const S := preload("res://games/sowing/sowing_rules.gd")
const PORT := 9193

var server: NetServer
var app: Node
var friend: Node
var friend_inbox: Array = []
var _saved_server := ""


func before_test() -> void:
	server = auto_free(NetServer.new())
	server.auto_start = false
	add_child(server)
	server.start(PORT)
	_saved_server = str(Store.data["online"]["server"])
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


func _friend_got(t: String) -> bool:
	return friend_inbox.any(func(m: Dictionary) -> bool: return m["t"] == t)


func test_a_pallanguzhi_room_plays_through_the_screens() -> void:
	app.push(load("res://shell/screens/online_screen.gd").create("pallanguzhi"))
	assert_bool(await _until(func() -> bool: return Online.status == "online" and friend.status == "online")).is_true()
	_top()._create()
	assert_bool(await _until(func() -> bool: return _script_of(_top()).ends_with("waiting_screen.gd") and _top()._code_box.visible)).is_true()
	var code: String = _top()._code_label.text

	friend.send({"t": "join", "code": code})
	assert_bool(await _until(func() -> bool: return _script_of(_top()).ends_with("sowing_play_screen.gd"))).is_true()
	var play: Node = _top()
	assert_str(play.mode).is_equal("online")
	assert_str(play.game_id).is_equal("pallanguzhi")
	assert_int(play.board.bottom).is_equal(play.me)  # Your own row is at the bottom.
	await get_tree().process_frame

	# The first move: whoever starts plays a pit; the other side sees it.
	var s: S.State = play.board.state
	if s.turn == play.me:
		play.board._tap(S.legal_moves(s)[0])
		assert_bool(await _until(func() -> bool: return _friend_got("moved"))).is_true()
	else:
		friend.send({"t": "move", "m": S.legal_moves(s)[0]})
		assert_bool(await _until(func() -> bool: return play.board.state.moves_played == 1)).is_true()
	play.board.skip()

	# Chat both ways; the card opens and closes cleanly.
	friend.send({"t": "chat", "id": 7})
	await _until(func() -> bool: return false, 20)
	play._open_chat()
	await get_tree().process_frame
	assert_bool(Modal.close_top(app)).is_true()

	# Resign and land on the seed result screen.
	var losses := Store.game_stat("pallanguzhi", "losses")
	Online.send({"t": "resign"})
	assert_bool(await _until(func() -> bool: return _script_of(_top()).ends_with("sowing_result_screen.gd"))).is_true()
	assert_str(_top().reason).is_equal("resign")
	assert_int(Store.game_stat("pallanguzhi", "losses")).is_equal(losses + 1)

	# Rematch: both say yes, and the other player starts this time.
	var was_me: int = play.me
	friend.send({"t": "rematch"})
	_top()._ask_rematch()
	assert_bool(await _until(func() -> bool: return _script_of(_top()).ends_with("sowing_play_screen.gd"))).is_true()
	assert_int(_top().me).is_equal(1 - was_me)
