extends GdUnitTestSuite
## End to end over real WebSockets: the actual server and two separate player connections
## in one process. Create a room, join by code, play moves both ways, chat, resign, rematch.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const PORT := 9191

var server: NetServer
var ana: Node
var ben: Node
var inbox := {}


func before_test() -> void:
	server = auto_free(NetServer.new())
	server.auto_start = false
	add_child(server)
	server.start(PORT)
	ana = _client("ana")
	ben = _client("ben")
	await _until(func() -> bool: return ana.status == "online" and ben.status == "online" and ana.token != "" and ben.token != "")


func after_test() -> void:
	for c: Node in [ana, ben]:
		if is_instance_valid(c):
			c.go_offline()


func _client(who: String) -> Node:
	var c: Node = auto_free(load("res://shell/online.gd").new())
	c.use_saved_token = false
	c.url_override = "ws://127.0.0.1:%d" % PORT
	inbox[who] = []
	c.message.connect(func(m: Dictionary) -> void: inbox[who].append(m))
	add_child(c)
	c.go_online()
	return c


func _until(cond: Callable, frames := 600) -> bool:
	for i in frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _last(who: String, t: String) -> Dictionary:
	for i in range(inbox[who].size() - 1, -1, -1):
		if inbox[who][i]["t"] == t:
			return inbox[who][i]
	return {}


func test_two_players_create_join_play_chat_resign_and_rematch() -> void:
	ana.send({"t": "create", "side": "goats"})
	assert_bool(await _until(func() -> bool: return not _last("ana", "room").is_empty())).is_true()
	var code: String = _last("ana", "room")["code"]
	assert_int(code.length()).is_equal(5)

	ben.send({"t": "join", "code": code})
	assert_bool(await _until(func() -> bool: return not _last("ana", "start").is_empty() and not _last("ben", "start").is_empty())).is_true()
	assert_str(_last("ana", "start")["you"]).is_equal("goats")
	assert_str(_last("ben", "start")["you"]).is_equal("tigers")

	# Ana (goats) places; Ben sees the move.
	var place := R.encode(R.NONE, 19, R.NONE)
	ana.send({"t": "move", "m": place})
	assert_bool(await _until(func() -> bool: return not _last("ben", "moved").is_empty())).is_true()
	assert_int(int(_last("ben", "moved")["m"])).is_equal(place)

	# Ben tries an illegal tiger move and gets the true position back instead.
	ben.send({"t": "move", "m": R.encode(0, 22, R.NONE)})
	assert_bool(await _until(func() -> bool: return not _last("ben", "sync").is_empty())).is_true()

	# A legal tiger move reaches Ana.
	ben.send({"t": "move", "m": R.encode(0, 2, R.NONE)})
	assert_bool(await _until(func() -> bool: return inbox["ana"].filter(func(m: Dictionary) -> bool: return m["t"] == "moved").size() >= 2)).is_true()

	# Chat by id.
	ben.send({"t": "chat", "id": 7})
	assert_bool(await _until(func() -> bool: return not _last("ana", "chat").is_empty())).is_true()
	assert_int(int(_last("ana", "chat")["id"])).is_equal(7)

	# Ana resigns; both get the result; both ask for a rematch and sides swap.
	ana.send({"t": "resign"})
	assert_bool(await _until(func() -> bool: return not _last("ben", "end").is_empty())).is_true()
	assert_str(_last("ben", "end")["winner"]).is_equal("tigers")
	inbox["ana"].clear()
	ana.send({"t": "rematch"})
	assert_bool(await _until(func() -> bool: return not _last("ben", "rematch_offer").is_empty())).is_true()
	ben.send({"t": "rematch"})
	assert_bool(await _until(func() -> bool: return not _last("ana", "start").is_empty())).is_true()
	assert_str(_last("ana", "start")["you"]).is_equal("tigers")


func test_quick_match_pairs_two_searching_players() -> void:
	ana.send({"t": "search", "side": "any"})
	assert_bool(await _until(func() -> bool: return not _last("ana", "searching").is_empty())).is_true()
	ben.send({"t": "search", "side": "any"})
	assert_bool(await _until(func() -> bool: return not _last("ana", "start").is_empty() and not _last("ben", "start").is_empty())).is_true()
	assert_str(_last("ana", "start")["you"]).is_not_equal(_last("ben", "start")["you"])
