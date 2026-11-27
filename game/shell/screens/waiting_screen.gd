extends AppScreen
## Waiting for an opponent: quick-match search (with the honest computer offer after
## 20 seconds, D5), a room code to share, or joining a friend's room.

const PlayScreen := preload("res://shell/screens/play_screen.gd")
const SowingPlayScreen := preload("res://shell/screens/sowing_play_screen.gd")
const FourPlayScreen := preload("res://shell/screens/four_play_screen.gd")
const GamePage := preload("res://shell/screens/game_page.gd")
const OFFER_AFTER := 20.0

var kind := "search"  ## "search", "room" or "join"
var arg := ""  ## side for search/room, code for join
var game_id := "aadupuli"  ## The game asked for (a joined room's own game wins).
var _title: Label
var _sub: Label
var _code_box: Control
var _code_label: Label
var _offer: Control
var _dots: Label
var _elapsed := 0.0
var _sent := false


static func create(p_kind: String, p_arg: String, p_game := "aadupuli") -> AppScreen:
	var s: AppScreen = load("res://shell/screens/waiting_screen.gd").new()
	s.kind = p_kind
	s.arg = p_arg
	s.game_id = p_game
	return s


func _ready() -> void:
	var col := page(true, 64, 40)
	col.add_child(top_bar({"search": "Find a player", "room": "Invite a friend", "join": "Join a friend"}[kind]))
	col.add_child(Ui.spacer())

	var avatars := Ui.hbox(28)
	avatars.alignment = BoxContainer.ALIGNMENT_CENTER
	avatars.add_child(Ui.avatar(Store.avatar(), Store.avatar_colour(), 200))
	_dots = Ui.heading("•  •  •", 56)
	_dots.add_theme_color_override("font_color", Ui.ACCENT)
	avatars.add_child(_dots)
	var mystery := PanelContainer.new()
	mystery.custom_minimum_size = Vector2(200, 200)
	mystery.add_theme_stylebox_override("panel", Ui.box(Color("#E9EEE0"), Ui.LINE, 100, 4, 0))
	var q := Ui.heading("?", 90)
	q.add_theme_color_override("font_color", Ui.FAINT)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mystery.add_child(q)
	avatars.add_child(mystery)
	col.add_child(avatars)

	_title = Ui.heading("", 50)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	_sub = Ui.muted("", 28)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_sub)

	# Room code, for "room".
	_code_box = Ui.card(Ui.WARM, Ui.ACCENT_LINE, 30)
	var cv := Ui.vbox(14)
	var cap := Ui.label("ROOM CODE", 24, Ui.MUTED, "bold")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(cap)
	_code_label = Ui.heading("·····", 110)
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_label.add_theme_constant_override("outline_size", 0)
	cv.add_child(_code_label)
	cv.add_child(Ui.button("Copy invite", _copy_invite, true, 104))
	_code_box.add_child(cv)
	_code_box.visible = false
	col.add_child(_code_box)

	# The honest offer: play the computer meanwhile.
	_offer = Ui.card(Ui.PANEL, Ui.LINE, 28)
	var ov := Ui.vbox(14)
	var orow := Ui.hbox(20)
	orow.add_child(Ui.icon("robot", 60, Ui.ACCENT))
	var ow := Ui.vbox(0)
	ow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ow.add_child(Ui.heading("Quiet right now", 36))
	ow.add_child(Ui.muted("Few players are online. Play the computer while you wait? It's clearly the computer, never a pretend person.", 26))
	orow.add_child(ow)
	ov.add_child(orow)
	ov.add_child(Ui.button("Play the computer", _play_computer, false, 104))
	_offer.add_child(ov)
	_offer.visible = false
	col.add_child(_offer)

	col.add_child(Ui.spacer())
	col.add_child(Ui.button("Cancel", _cancel, false, 112))
	Online.message.connect(_on_message)
	Online.status_changed.connect(_on_status)
	_refresh_text()


func on_show() -> void:
	if Online.status == "online":
		_send_request()
	else:
		Online.go_online()


func _on_status(s: String) -> void:
	if s == "online" and not _sent:
		_send_request()


func _send_request() -> void:
	_sent = true
	match kind:
		"search": Online.send({"t": "search", "side": arg, "game": game_id})
		"room": Online.send({"t": "create", "side": arg, "game": game_id})
		"join": Online.send({"t": "join", "code": arg})


func _process(delta: float) -> void:
	_elapsed += delta
	var n := int(_elapsed * 2.0) % 4
	_dots.text = ["•", "•  •", "•  •  •", ""][n]
	if kind == "search":
		_sub.text = tr("Searching for %d s") % int(_elapsed)
		_offer.visible = _elapsed >= OFFER_AFTER


func _refresh_text() -> void:
	match kind:
		"search":
			_title.text = "Looking for a player"
		"room":
			_title.text = "Waiting for your friend"
			_sub.text = "Send them the code. The game starts when they join."
		"join":
			_title.text = tr("Joining room %s") % arg
			_sub.text = "Connecting you to your friend…"


func _on_message(msg: Dictionary) -> void:
	if not is_inside_tree():
		return
	match str(msg.get("t", "")):
		"room":
			_code_label.text = str(msg.get("code", ""))
			_code_box.visible = true
		"start":
			var game := str(msg.get("game", "aadupuli"))
			if Games.is_tiger(game):
				app.replace(PlayScreen.create_online(msg))
			elif game == "fourinrow":
				app.replace(FourPlayScreen.create_online(msg))
			else:
				app.replace(SowingPlayScreen.create_online(msg))
		"error":
			var texts := {"no_room": "There's no room with that code. Check it with your friend.", "room_full": "That room already has two players."}
			if texts.has(msg.get("code")):
				Modal.show(app, "Can't join", [Modal.text(texts[msg.get("code")])], [["OK", func() -> void: app.pop(), true]])


func _copy_invite() -> void:
	var title := tr(Games.title(game_id))
	DisplayServer.clipboard_set(tr("Play %s with me! Open the app, tap Play online, then Join a friend and enter code %s") % [title, _code_label.text])
	Modal.show(app, "Copied", [Modal.text("The invite is copied. Paste it into WhatsApp or any message to your friend.")], [["OK", func() -> void: pass, true]])


func _cancel() -> void:
	Online.send({"t": "cancel" if kind == "search" else "leave"})
	app.pop()


func _play_computer() -> void:
	Online.send({"t": "cancel"})
	if game_id == "fourinrow":
		app.replace(FourPlayScreen.create(game_id, "computer", Store.last("level"), arg != "second"))
		return
	if not Games.is_tiger(game_id):
		app.replace(SowingPlayScreen.create(game_id, "computer", Store.last("level")))
		return
	var side := arg if arg in ["tigers", "goats"] else "goats"
	app.replace(PlayScreen.create("computer", Store.last("level"), side, false, game_id))


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(Online):
		if kind == "search" and _sent:
			Online.send({"t": "cancel"})
