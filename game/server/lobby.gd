class_name OnlineLobby
extends RefCounted
## All online-play logic, with no networking: players, private rooms, quick match,
## moves checked against the rules, chat relay, turn timer, rematch, disconnects.
## Every handler returns the messages to send as [[peer_id, message], ...], which keeps
## this class testable without sockets (tests/test_online_lobby.gd).
##
## Decisions: server checks every move (D17); chat is preset phrases and emotes only,
## sent as ids (D29); 45-second turns, first time-out plays a random move and warns,
## second forfeits (D51); names filtered (D50); empty quick match is handled on the
## phone by offering the computer after 20 seconds (D5).
##
## Several games share the lobby: each room plays one game ("aadupuli", "kalah" or
## "pallanguzhi"; old clients send none and get Tiger & Goat). Sides are "tigers" and
## "goats" in Tiger & Goat, "first" and "second" in the seed games (who moves first;
## a rematch swaps them, so the start alternates). Quick match pairs the same game only.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const S := preload("res://games/sowing/sowing_rules.gd")
const GAMES := ["aadupuli", "kalah", "pallanguzhi"]

const PROTOCOL := 1
const TURN_MS := 45000
const RECONNECT_MS := 60000
const CODE_LETTERS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  # No 0/O or 1/I to misread.
const CHAT_IDS := 14  ## Phrases and emotes are numbered 0..13 on the phone (shell/online_chat.gd).

var players := {}  ## peer -> {name, avatar, colour, token, room, chat_at}
var rooms := {}  ## code -> room Dictionary
var queue: Array = []  ## [{peer, side, game}] waiting for quick match
var tokens := {}  ## token -> peer, for reconnecting
var _rng := RandomNumberGenerator.new()
var _out: Array = []


func _init(seed_value := 0) -> void:
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


# ---------- Entry points ----------

func handle(peer: int, msg: Dictionary, now: int) -> Array:
	_out = []
	var t := str(msg.get("t", ""))
	if t != "hello" and not players.has(peer):
		_send(peer, {"t": "error", "code": "no_hello"})
		return _out
	match t:
		"hello": _hello(peer, msg, now)
		"create": _create(peer, str(msg.get("side", "random")), _game_of(msg))
		"join": _join(peer, str(msg.get("code", "")).to_upper().strip_edges(), now)
		"search": _search(peer, str(msg.get("side", "any")), _game_of(msg), now)
		"cancel": _cancel_search(peer)
		"leave": _leave(peer, now)
		"move": _move(peer, int(msg.get("m", -1)), now)
		"chat": _chat(peer, int(msg.get("id", -1)), now)
		"resign": _resign(peer)
		"rematch": _rematch(peer, now)
		_: _send(peer, {"t": "error", "code": "unknown"})
	return _out


func disconnected(peer: int, now: int) -> Array:
	_out = []
	_cancel_search(peer)
	var room := _room_of(peer)
	if room.is_empty():
		_forget(peer)
		return _out
	if room["status"] == "playing":
		room["away"][peer] = now
		_send(_opponent(room, peer), {"t": "opponent_away", "seconds": RECONNECT_MS / 1000})
	else:
		_leave(peer, now)
		_forget(peer)
	return _out


## Called about once a second: turn time-outs and players who never came back.
func tick(now: int) -> Array:
	_out = []
	for code: String in rooms.keys():
		var room: Dictionary = rooms[code]
		if room["status"] != "playing":
			continue
		for peer: int in room["away"].keys():
			if now - int(room["away"][peer]) >= RECONNECT_MS:
				_end(room, _side_of(room, _opponent(room, peer)), "left")
				_leave(peer, now)
				_forget(peer)
				break
		if room["status"] == "playing" and now >= int(room["deadline"]):
			_timeout(room, now)
	return _out


# ---------- Players ----------

func _hello(peer: int, msg: Dictionary, now: int) -> void:
	if int(msg.get("v", 0)) != PROTOCOL:
		_send(peer, {"t": "error", "code": "update_needed"})
		return
	var token := str(msg.get("token", ""))
	if token != "" and tokens.has(token) and tokens[token] != peer:
		_reconnect(peer, int(tokens[token]), token, now)
		return
	if token == "":
		token = "%08x%08x" % [_rng.randi(), _rng.randi()]
	players[peer] = {
		"name": NameFilter.clean(str(msg.get("name", ""))),
		"avatar": "tiger" if str(msg.get("avatar", "")) == "tiger" else "goat",
		"colour": clampi(int(msg.get("colour", 0)), 0, 5),
		"token": token, "room": "", "chat_at": -100000,
	}
	tokens[token] = peer
	_send(peer, {"t": "welcome", "token": token, "name": players[peer]["name"]})


## Same player, new connection: move them into their old seat.
func _reconnect(peer: int, old: int, token: String, now: int) -> void:
	var p: Dictionary = players.get(old, {})
	players.erase(old)
	players[peer] = p
	tokens[token] = peer
	_send(peer, {"t": "welcome", "token": token, "name": p.get("name", NameFilter.FALLBACK)})
	var room := _room_of(peer)
	if room.is_empty():
		return
	var i: int = room["players"].find(old)
	room["players"][i] = peer
	room["sides"][peer] = room["sides"][old]
	room["sides"].erase(old)
	room["timeouts"][peer] = room["timeouts"].get(old, 0)
	room["timeouts"].erase(old)
	room["away"].erase(old)
	room["rematch"].erase(old)
	if room["status"] == "playing":
		_send(peer, _start_msg(room, peer, now))
		_send(_opponent(room, peer), {"t": "opponent_back"})


func _forget(peer: int) -> void:
	if players.has(peer):
		tokens.erase(players[peer]["token"])
		players.erase(peer)


func _public(peer: int) -> Dictionary:
	var p: Dictionary = players[peer]
	return {"name": p["name"], "avatar": p["avatar"], "colour": p["colour"]}


# ---------- Rooms ----------

func _create(peer: int, side: String, game: String) -> void:
	_leave(peer, 0)
	var code := _new_code()
	rooms[code] = {
		"code": code, "game": game, "players": [peer], "host_side": side if side in sides_of(game) else "random",
		"sides": {}, "status": "waiting", "state": null, "deadline": 0, "timeouts": {},
		"away": {}, "rematch": [], "private": true,
	}
	players[peer]["room"] = code
	_send(peer, {"t": "room", "code": code, "status": "waiting", "game": game})


func _join(peer: int, code: String, now: int) -> void:
	if not rooms.has(code):
		_send(peer, {"t": "error", "code": "no_room"})
		return
	var room: Dictionary = rooms[code]
	if room["players"].size() >= 2 or room["status"] != "waiting":
		_send(peer, {"t": "error", "code": "room_full"})
		return
	_leave(peer, now)
	room["players"].append(peer)
	players[peer]["room"] = code
	_begin(room, now)


func _search(peer: int, side: String, game: String, now: int) -> void:
	_leave(peer, now)
	_cancel_search(peer)
	var want := side if side in sides_of(game) else "any"
	for i in queue.size():
		var other: Dictionary = queue[i]
		if other["game"] != game:
			continue
		var their: String = other["side"]
		if their == "any" or want == "any" or their != want:
			queue.remove_at(i)
			var code := _new_code()
			var host_side := their if their != "any" else ("random" if want == "any" else _other_side(game, want))
			rooms[code] = {
				"code": code, "game": game, "players": [other["peer"], peer], "host_side": host_side,
				"sides": {}, "status": "waiting", "state": null, "deadline": 0, "timeouts": {},
				"away": {}, "rematch": [], "private": false,
			}
			players[other["peer"]]["room"] = code
			players[peer]["room"] = code
			_begin(rooms[code], now)
			return
	queue.append({"peer": peer, "side": want, "game": game})
	_send(peer, {"t": "searching"})


func _cancel_search(peer: int) -> void:
	for i in range(queue.size() - 1, -1, -1):
		if queue[i]["peer"] == peer:
			queue.remove_at(i)


func _leave(peer: int, _now: int) -> void:
	var room := _room_of(peer)
	if room.is_empty():
		return
	if room["status"] == "playing":
		_end(room, _side_of(room, _opponent(room, peer)), "left")
	var other := _opponent(room, peer)
	room["players"].erase(peer)
	players[peer]["room"] = ""
	if other != 0:
		_send(other, {"t": "opponent_left"})
		players[other]["room"] = ""
	rooms.erase(room["code"])


func _new_code() -> String:
	while true:
		var code := ""
		for i in 5:
			code += CODE_LETTERS[_rng.randi_range(0, CODE_LETTERS.length() - 1)]
		if not rooms.has(code):
			return code
	return ""


# ---------- Playing ----------

func _begin(room: Dictionary, now: int) -> void:
	var host: int = room["players"][0]
	var guest: int = room["players"][1]
	var game: String = room["game"]
	var host_side: String = room["host_side"]
	if host_side == "random":
		host_side = sides_of(game)[_rng.randi() % 2]
	room["sides"] = {host: host_side, guest: _other_side(game, host_side)}
	room["state"] = _new_state(game)
	room["status"] = "playing"
	room["timeouts"] = {host: 0, guest: 0}
	room["rematch"] = []
	room["deadline"] = now + TURN_MS
	for peer: int in room["players"]:
		_send(peer, _start_msg(room, peer, now))


func _start_msg(room: Dictionary, peer: int, now: int) -> Dictionary:
	var opp := _opponent(room, peer)
	return {
		"t": "start", "code": room["code"], "game": room["game"], "private": room["private"], "you": room["sides"][peer],
		"opponent": _public(opp) if opp != 0 else {}, "state": _dict(room),
		"turn_ms": maxi(0, int(room["deadline"]) - now),
	}


func _move(peer: int, m: int, now: int) -> void:
	var room := _room_of(peer)
	if room.is_empty() or room["status"] != "playing":
		_send(peer, {"t": "error", "code": "not_playing"})
		return
	if _turn_side(room) != room["sides"][peer] or not _legal(room).has(m):
		_send(peer, {"t": "sync", "state": _dict(room), "turn_ms": maxi(0, int(room["deadline"]) - now)})
		return
	_apply(room, m, peer, now)


func _apply(room: Dictionary, m: int, by: int, now: int) -> void:
	if room["game"] == "aadupuli":
		room["state"] = R.apply(room["state"], m)
	else:
		room["state"] = S.after(room["state"], m)
	room["deadline"] = now + TURN_MS
	for p: int in room["players"]:
		_send(p, {"t": "moved", "m": m, "by": room["sides"][by], "turn_ms": TURN_MS, "state": _dict(room)})
	var outcome := _outcome(room)
	if not outcome.is_empty():
		_end(room, outcome[0], outcome[1])


func _timeout(room: Dictionary, now: int) -> void:
	var side := _turn_side(room)
	var peer := _peer_with_side(room, side)
	room["timeouts"][peer] = int(room["timeouts"].get(peer, 0)) + 1
	if room["timeouts"][peer] >= 2:
		_end(room, _other_side(room["game"], side), "timeout")
		return
	var moves := _legal(room)
	for p: int in room["players"]:
		_send(p, {"t": "timeout", "side": side})
	_apply(room, moves[_rng.randi_range(0, moves.size() - 1)], peer, now)


func _resign(peer: int) -> void:
	var room := _room_of(peer)
	if not room.is_empty() and room["status"] == "playing":
		_end(room, _side_of(room, _opponent(room, peer)), "resign")


func _end(room: Dictionary, winner: String, reason: String) -> void:
	room["status"] = "finished"
	room["away"] = {}
	for p: int in room["players"]:
		if players.has(p):
			_send(p, {"t": "end", "winner": winner, "reason": reason, "state": _dict(room)})


func _rematch(peer: int, now: int) -> void:
	var room := _room_of(peer)
	if room.is_empty() or room["status"] != "finished" or room["players"].size() < 2:
		_send(peer, {"t": "error", "code": "no_rematch"})
		return
	if not room["rematch"].has(peer):
		room["rematch"].append(peer)
	if room["rematch"].size() < 2:
		_send(_opponent(room, peer), {"t": "rematch_offer"})
		return
	# Swap sides for the rematch.
	var host: int = room["players"][0]
	room["host_side"] = _other_side(room["game"], room["sides"][host])
	_begin(room, now)


func _chat(peer: int, id: int, now: int) -> void:
	var room := _room_of(peer)
	if room.is_empty() or id < 0 or id >= CHAT_IDS:
		return
	if now - int(players[peer]["chat_at"]) < 1500:  # At most one message every 1.5 s.
		return
	players[peer]["chat_at"] = now
	var other := _opponent(room, peer)
	if other != 0:
		_send(other, {"t": "chat", "id": id})


# ---------- Helpers ----------

func _send(peer: int, msg: Dictionary) -> void:
	_out.append([peer, msg])


func _room_of(peer: int) -> Dictionary:
	if not players.has(peer):
		return {}
	return rooms.get(players[peer]["room"], {})


func _opponent(room: Dictionary, peer: int) -> int:
	for p: int in room["players"]:
		if p != peer:
			return p
	return 0


func _side_of(room: Dictionary, peer: int) -> String:
	return str(room["sides"].get(peer, ""))


func _peer_with_side(room: Dictionary, side: String) -> int:
	for p: int in room["sides"]:
		if room["sides"][p] == side:
			return p
	return 0


# ---------- Per-game rules ----------

static func sides_of(game: String) -> Array:
	return ["tigers", "goats"] if game == "aadupuli" else ["first", "second"]


func _other_side(game: String, side: String) -> String:
	var both := sides_of(game)
	return both[1] if side == both[0] else both[0]


func _game_of(msg: Dictionary) -> String:
	var g := str(msg.get("game", "aadupuli"))
	return g if g in GAMES else "aadupuli"


func _new_state(game: String) -> Variant:
	if game == "aadupuli":
		return R.new_game()
	return S.new_game(S.KALAH if game == "kalah" else S.PALLANGUZHI, 0)


func _turn_side(room: Dictionary) -> String:
	if room["game"] == "aadupuli":
		return "tigers" if (room["state"] as R.State).turn == R.TIGER else "goats"
	return "first" if (room["state"] as S.State).turn == 0 else "second"


func _legal(room: Dictionary) -> PackedInt32Array:
	if room["game"] == "aadupuli":
		return R.legal_moves(room["state"])
	return S.legal_moves(room["state"])


func _dict(room: Dictionary) -> Dictionary:
	if room["game"] == "aadupuli":
		return R.to_dict(room["state"])
	return S.to_dict(room["state"])


## [winner side or "draw", reason] once the game is over, else [].
func _outcome(room: Dictionary) -> Array:
	if room["game"] == "aadupuli":
		var s: R.State = room["state"]
		var res := R.result(s)
		if res == R.ONGOING:
			return []
		var reason := "captured" if res == R.TIGERS_WIN and s.captured >= s.capture_target else (
			"held" if res == R.GOATS_WIN and R.held(s) else ("trapped" if res == R.GOATS_WIN else "stuck"))
		return ["tigers" if res == R.TIGERS_WIN else "goats", reason]
	match S.result(room["state"]):
		S.WIN_0:
			return ["first", "seeds"]
		S.WIN_1:
			return ["second", "seeds"]
		S.DRAW:
			return ["draw", "seeds"]
	return []
