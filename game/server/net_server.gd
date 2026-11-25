class_name NetServer
extends Node
## WebSocket front for OnlineLobby: accepts phones and browsers, turns JSON text
## messages into lobby calls, and sends the lobby's replies back.
## Run from the repository root:  bash tools/run_server.sh   (port 9080 by default)

const MAX_MESSAGE := 4096
const MAX_PEERS := 500

var port := 9080
var auto_start := true  ## Tests start the server themselves on another port.
var lobby := OnlineLobby.new()
var _tcp := TCPServer.new()
var _peers := {}  ## id -> WebSocketPeer
var _open := {}  ## id -> true once the handshake finished
var _next_id := 1
var _tick_at := 0


func _ready() -> void:
	if not auto_start:
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = int(arg.trim_prefix("--port="))
	start(port)


func start(p: int) -> Error:
	port = p
	var err := _tcp.listen(port, "*")
	if err != OK:
		push_error("Tiger & Goat server: could not listen on port %d (%s)" % [port, error_string(err)])
	else:
		print("Tiger & Goat server listening on port %d" % port)
	return err


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	while _tcp.is_connection_available() and _peers.size() < MAX_PEERS:
		var ws := WebSocketPeer.new()
		ws.inbound_buffer_size = 16384
		ws.accept_stream(_tcp.take_connection())
		_peers[_next_id] = ws
		_next_id += 1
	for id: int in _peers.keys():
		var ws: WebSocketPeer = _peers[id]
		ws.poll()
		var state := ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			_open[id] = true
			while ws.get_available_packet_count() > 0:
				var text := ws.get_packet().get_string_from_utf8()
				if text.length() > MAX_MESSAGE:
					continue
				var msg: Variant = JSON.parse_string(text)
				if msg is Dictionary:
					_deliver(lobby.handle(id, msg, now))
		elif state == WebSocketPeer.STATE_CLOSED:
			_peers.erase(id)
			if _open.has(id):
				_open.erase(id)
				_deliver(lobby.disconnected(id, now))
	if now >= _tick_at:
		_tick_at = now + 1000
		_deliver(lobby.tick(now))


func _deliver(out: Array) -> void:
	for pair: Array in out:
		var ws: WebSocketPeer = _peers.get(pair[0])
		if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			ws.send_text(JSON.stringify(pair[1]))


func _exit_tree() -> void:
	for id: int in _peers:
		(_peers[id] as WebSocketPeer).close()
	_tcp.stop()
