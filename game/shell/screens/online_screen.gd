extends AppScreen
## Play online: find a player (quick match), invite a friend (create a room), or join
## a friend's room with its code. `game_id` says which game: in the tiger games
## (Tiger & Goat, Bagh-Chal) players can pick a side; in the seed games who starts is
## decided for them and alternates.

const WaitingScreen := preload("res://shell/screens/waiting_screen.gd")

var _status_icon: TextureRect
var _status: Label
var _retry: Button
var _code: LineEdit
var _search_side := "any"
var _room_side := "random"
var _search_chips := {}
var _room_chips := {}
var _error: Label
var game_id := "aadupuli"


static func create(id: String) -> AppScreen:
	var s: AppScreen = load("res://shell/screens/online_screen.gd").new()
	s.game_id = id
	return s


func _ready() -> void:
	_search_side = str(Store.data["online"]["search_side"])
	_room_side = str(Store.data["online"]["room_side"])
	var col := page(true, 64, 40)
	col.add_child(top_bar("Play online" if game_id == "aadupuli" else tr("%s online") % tr(Games.title(game_id))))

	var status_row := Ui.hbox(14)
	_status_icon = Ui.icon("wifi-off", 44, Ui.MUTED)
	status_row.add_child(_status_icon)
	_status = Ui.label("", 28, Ui.MUTED)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_row.add_child(_status)
	_retry = Ui.button("Retry", func() -> void: Online.go_online(), false, 84)
	_retry.custom_minimum_size.x = 180
	_retry.size_flags_horizontal = Control.SIZE_SHRINK_END
	status_row.add_child(_retry)
	col.add_child(status_row)

	# Find a player.
	var quick := _card("search", "Find a player", "Play someone online right now.")
	if Games.is_tiger(game_id):
		quick.get_meta("body").add_child(_chips([["any", "Any side"], ["tigers", "Tigers"], ["goats", "Goats"]], _search_chips, _set_search_side))
	quick.get_meta("body").add_child(Ui.button("Find a player", _find, true, 108))
	col.add_child(quick)

	# Invite a friend.
	var invite := _card("users", "Invite a friend", "Get a code and send it to a friend.")
	if Games.is_tiger(game_id):
		invite.get_meta("body").add_child(_chips([["random", "Random"], ["tigers", "I'm tigers"], ["goats", "I'm goats"]], _room_chips, _set_room_side))
	invite.get_meta("body").add_child(Ui.button("Create a room", _create, false, 108))
	col.add_child(invite)

	# Join a friend.
	var join := _card("door-exit", "Join a friend", "Type the code your friend sent you.")
	var jrow := Ui.hbox(16)
	_code = LineEdit.new()
	_code.placeholder_text = "ABCDE"
	_code.max_length = 5
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code.custom_minimum_size.y = 108
	_code.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code.add_theme_font_override("font", Ui.font("display"))
	_code.add_theme_font_size_override("font_size", 46)
	_code.text_changed.connect(func(t: String) -> void:
		var caret := _code.caret_column
		_code.text = t.to_upper()
		_code.caret_column = caret)
	_code.text_submitted.connect(func(_t: String) -> void: _join())
	jrow.add_child(_code)
	var jb := Ui.button("Join", _join, false, 108)
	jb.custom_minimum_size.x = 200
	jb.size_flags_horizontal = Control.SIZE_SHRINK_END
	jrow.add_child(jb)
	join.get_meta("body").add_child(jrow)
	_error = Ui.label("", 26, Color("#B5501A"))
	_error.visible = false
	join.get_meta("body").add_child(_error)
	col.add_child(join)

	col.add_child(Ui.muted("Online games use your name and avatar. Chat is only the set phrases and faces, so there's nothing rude to read.", 24))

	Online.status_changed.connect(_on_status)
	Online.message.connect(_on_message)
	_refresh_chips()


func on_show() -> void:
	Online.go_online()
	_show_status()


func _card(icon_name: String, title: String, sub: String) -> PanelContainer:
	var c := Ui.card(Ui.PANEL, Ui.LINE, 28)
	var v := Ui.vbox(18)
	var head := Ui.hbox(22)
	head.add_child(Ui.icon(icon_name, 60, Ui.ACCENT))
	var w := Ui.vbox(0)
	w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w.add_child(Ui.heading(title, 38))
	w.add_child(Ui.muted(sub, 26))
	head.add_child(w)
	v.add_child(head)
	c.add_child(v)
	c.set_meta("body", v)
	return c


func _chips(options: Array, store: Dictionary, action: Callable) -> HBoxContainer:
	var row := Ui.hbox(12)
	for o: Array in options:
		var chip := PanelContainer.new()
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l := Ui.label(o[1], 26, Ui.INK, "bold")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.add_child(l)
		Ui.on_tap(chip, action.bind(o[0]))
		store[o[0]] = chip
		row.add_child(chip)
	return row


func _set_search_side(s: String) -> void:
	_search_side = s
	_refresh_chips()


func _set_room_side(s: String) -> void:
	_room_side = s
	_refresh_chips()


func _refresh_chips() -> void:
	for group: Array in [[_search_chips, _search_side], [_room_chips, _room_side]]:
		var chips: Dictionary = group[0]
		for id: String in chips:
			var on: bool = id == group[1]
			var chip: PanelContainer = chips[id]
			chip.add_theme_stylebox_override("panel", Ui.box(Ui.ACCENT_TINT if on else Ui.WHITE, Ui.ACCENT if on else Ui.LINE, 24, 3, 14))
			(chip.get_child(0) as Label).add_theme_color_override("font_color", Color("#B5501A") if on else Ui.INK)


func _on_status(_s: String) -> void:
	_show_status()


func _show_status() -> void:
	if not is_inside_tree():
		return
	var s := Online.status
	var texts := {
		"online": "Connected",
		"connecting": "Connecting…",
		"unreachable": "Can't reach the game server. Check your connection, or the server address in Settings.",
		"offline": "Offline",
	}
	_status.text = texts.get(s, s)
	_status_icon.texture = Ui.icon_texture("wifi-off" if s != "online" else "check", 44, Ui.ACCENT if s == "online" else Ui.MUTED)
	_retry.visible = s == "unreachable"


func _ready_to_send() -> bool:
	if Online.status == "online":
		return true
	Modal.show(app, "Not connected", [Modal.text("The game server can't be reached right now. Check your internet connection and try again.")], [["OK", func() -> void: pass, true]])
	return false


func _find() -> void:
	if not _ready_to_send():
		return
	Store.data["online"]["search_side"] = _search_side
	Store.save_data()
	app.push(WaitingScreen.create("search", _search_side if Games.is_tiger(game_id) else "any", game_id))


func _create() -> void:
	if not _ready_to_send():
		return
	Store.data["online"]["room_side"] = _room_side
	Store.save_data()
	app.push(WaitingScreen.create("room", _room_side if Games.is_tiger(game_id) else "random", game_id))


func _join() -> void:
	var code := _code.text.strip_edges().to_upper()
	if code.length() != 5:
		_show_error("A room code has 5 letters and numbers.")
		return
	if not _ready_to_send():
		return
	_error.visible = false
	app.push(WaitingScreen.create("join", code, game_id))


func _show_error(text: String) -> void:
	_error.text = text
	_error.visible = true


func _on_message(msg: Dictionary) -> void:
	if not visible or msg.get("t") != "error":
		return
	if msg.get("code") == "update_needed":
		Modal.show(app, "Update needed", [Modal.text("A newer version of Tiger & Goat is needed to play online.")], [["OK", func() -> void: pass, true]])
