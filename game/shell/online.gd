extends Node
## Connection to the online server (autoload "Online"). Keeps one WebSocket open while
## online play is in use, reconnects by itself, and remembers the player's token so a
## dropped game can be rejoined within a minute.

signal status_changed(status: String)  ## "offline", "connecting", "online", "unreachable"
signal message(msg: Dictionary)

const PROTOCOL := 1
const DEFAULT_PORT := 9080
const RETRY_MS := 3000

var status := "offline"
var my_name := ""
var use_saved_token := true  ## Tests turn this off to act as separate players.
var token := ""
var url_override := ""  ## Tests set this; the app uses Settings or the page address.

var _ws: WebSocketPeer
var _wanted := false
var _retry_at := 0
var _fails := 0


func server_url() -> String:
	if url_override != "":
		return url_override
	var saved := str(Store.data["online"].get("server", "")).strip_edges()
	if saved != "":
		return saved if saved.begins_with("ws") else "ws://%s" % (saved if saved.contains(":") else "%s:%d" % [saved, DEFAULT_PORT])
	if OS.has_feature("web"):
		var host: Variant = JavaScriptBridge.eval("window.location.hostname", true)
		if host is String and host != "":
			return "ws://%s:%d" % [host, DEFAULT_PORT]
	return ""


## Starts (or keeps) a connection. Safe to call repeatedly.
func go_online() -> void:
	_wanted = true
	if status in ["online", "connecting"]:
		return
	_open()


func go_offline() -> void:
	_wanted = false
	if _ws != null:
		_ws.close()
	_ws = null
	_set_status("offline")


func send(msg: Dictionary) -> void:
	if _ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify(msg))


func _open() -> void:
	var url := server_url()
	if url == "":
		_set_status("unreachable")
		return
	_ws = WebSocketPeer.new()
	if _ws.connect_to_url(url) != OK:
		_fail()
		return
	_set_status("connecting")


func _process(_delta: float) -> void:
	if _ws == null:
		if _wanted and Time.get_ticks_msec() >= _retry_at and status != "connecting":
			_open()
		return
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if status != "online":
				_fails = 0
				if use_saved_token:
					token = str(Store.data["online"].get("token", ""))
				send({"t": "hello", "v": PROTOCOL, "name": Store.player_name(), "avatar": Store.avatar(),
					"colour": Store.avatar_colour(), "token": token})
				_set_status("online")
			while _ws != null and _ws.get_available_packet_count() > 0:
				var msg: Variant = JSON.parse_string(_ws.get_packet().get_string_from_utf8())
				if msg is Dictionary:
					_receive(msg)
		WebSocketPeer.STATE_CLOSED:
			_fail()


func _receive(msg: Dictionary) -> void:
	if msg.get("t") == "welcome":
		token = str(msg.get("token", ""))
		my_name = str(msg.get("name", ""))
		if use_saved_token:
			Store.data["online"]["token"] = token
			Store.save_data()
	message.emit(msg)


func _fail() -> void:
	_ws = null
	_fails += 1
	_retry_at = Time.get_ticks_msec() + RETRY_MS
	_set_status("unreachable" if _fails >= 2 else "connecting")


func _set_status(s: String) -> void:
	if s != status:
		status = s
		status_changed.emit(s)
