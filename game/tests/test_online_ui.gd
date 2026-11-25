extends GdUnitTestSuite
## Drives the real app screens against the real server: Play online, create a room,
## a second player joins by code, a move on the board, chat, resign, result screen.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const PORT := 9192

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


func test_create_room_play_chat_resign_through_the_screens() -> void:
	app.push(load("res://shell/screens/online_screen.gd").new())
	assert_bool(await _until(func() -> bool: return Online.status == "online" and friend.status == "online")).is_true()
	var hub: Node = _top()
	hub._room_side = "goats"
	hub._create()
	assert_bool(await _until(func() -> bool: return _script_of(_top()).ends_with("waiting_screen.gd") and _top()._code_box.visible)).is_true()
	var code: String = _top()._code_label.text

	friend.send({"t": "join", "code": code})
	assert_bool(await _until(func() -> bool: return _script_of(_top()).ends_with("play_screen.gd"))).is_true()
	var play: Node = _top()
	assert_str(play.mode).is_equal("online")
	assert_str(play.human_side).is_equal("goats")
	await get_tree().process_frame

	# Place a goat by tapping the board; the friend (tigers) receives it.
	play.board._tap(19)
	assert_bool(await _until(func() -> bool: return friend_inbox.any(func(m: Dictionary) -> bool: return m["t"] == "moved"))).is_true()

	# The friend sends a chat face; the chat card opens and closes cleanly.
	friend.send({"t": "chat", "id": 0})
	await _until(func() -> bool: return false, 30)
	play._open_chat()
	await get_tree().process_frame
	assert_bool(Modal.close_top(app)).is_true()

	# Resign through the server and land on the result screen.
	Online.send({"t": "resign"})
	assert_bool(await _until(func() -> bool: return _script_of(_top()).ends_with("result_screen.gd"))).is_true()
	assert_str(_top().reason).is_equal("resign")
	assert_int(Store.stat("online_losses")).is_greater(0)
