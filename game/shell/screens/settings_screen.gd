extends AppScreen
## Settings: game options, progress, and about (DISCUSSION.md section 25).

const VERSION := "0.2.0"

var _server_value: Label


func _ready() -> void:
	var col := page(true, 64, 40)
	col.add_child(top_bar("Settings"))

	col.add_child(section("Game"))
	var game := _group()
	_toggle(game, "Sound", "sound")
	_toggle(game, "Vibration", "vibration")
	_toggle(game, "Move hints", "hints")
	_toggle(game, "Reduce motion", "reduce_motion")
	_row(game, "Board theme", Ui.label("Hill and meadow", 28, Ui.MUTED), func() -> void: _themes())
	col.add_child(game.get_parent().get_parent())

	col.add_child(section("Online"))
	var online := _group()
	_server_value = Ui.label(_server_text(), 26, Ui.MUTED)
	_row(online, "Game server", _server_value, _edit_server)
	col.add_child(online.get_parent().get_parent())

	col.add_child(section("Progress"))
	var progress := _group()
	_row(progress, "Back up progress", Ui.soon_pill(), Callable())
	_row(progress, "Reset progress", Ui.icon("chevron-right", 44, Ui.MUTED), _confirm_reset)
	col.add_child(progress.get_parent().get_parent())

	col.add_child(section("About"))
	var about := _group()
	_row(about, "How to play", Ui.icon("chevron-right", 44, Ui.MUTED), func() -> void: Modal.how_to_play(app))
	_row(about, "Privacy", Ui.icon("chevron-right", 44, Ui.MUTED), _privacy)
	_row(about, "Credits", Ui.label("v" + VERSION, 26, Ui.MUTED), _credits)
	col.add_child(about.get_parent().get_parent())


## A rounded card holding rows separated by thin lines; returns the rows' container.
func _group() -> VBoxContainer:
	var card := Ui.card(Ui.PANEL, Ui.LINE, 0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(margin)
	var v := Ui.vbox(0)
	margin.add_child(v)
	return v


func _row(group: VBoxContainer, title: String, right: Control, action: Callable) -> void:
	if group.get_child_count() > 0:
		var line := ColorRect.new()
		line.color = Ui.SOFT
		line.custom_minimum_size.y = 2
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(line)
	var row := Ui.hbox(16)
	row.custom_minimum_size.y = 116
	var t := Ui.label(title, 32, Ui.INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(t)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	if action.is_valid():
		Ui.on_tap(row, action)
	group.add_child(row)


func _toggle(group: VBoxContainer, title: String, key: String) -> void:
	var sw := UiSwitch.new()
	sw.on = bool(Store.setting(key))
	sw.toggled.connect(func(on: bool) -> void: Store.set_setting(key, on))
	_row(group, title, sw, Callable())


func _themes() -> void:
	var rows: Array = []
	for t: Array in [["Hill and meadow", "In use", true], ["Heirloom", "Brass and wood", false], ["Night lantern", "A calm evening board", false]]:
		var row := Ui.hbox(16)
		var w := Ui.vbox(0)
		w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		w.add_child(Ui.heading(t[0], 34))
		w.add_child(Ui.label(t[1], 26, Ui.MUTED))
		row.add_child(w)
		row.add_child(Ui.icon("check", 48, Ui.ACCENT) if t[2] else Ui.soon_pill())
		rows.append(row)
	Modal.show(app, "Board theme", rows, [["Done", func() -> void: pass, true]])


func _confirm_reset() -> void:
	Modal.show(app, "Reset progress?", [Modal.text("Your games, wins, streaks and badges will be cleared. Your name, avatar and settings stay. This can't be undone.")], [
		["Cancel", func() -> void: pass],
		["Reset", func() -> void: Store.reset_progress(), true],
	])


func _privacy() -> void:
	Modal.show(app, "Privacy", [Modal.text("Playing alone or pass and play, everything stays on this phone: your name, avatar, settings and stats.\n\nWhen you play online, the game server receives your name, avatar and moves so your opponent can see them, plus a random code that lets you rejoin a game if your connection drops. The server keeps these only while you're connected and for a minute after; nothing is stored, sold or used for ads. There's no account and no free-text chat.")], [["Close", func() -> void: pass, true]])


func _credits() -> void:
	Modal.show(app, "Credits", [Modal.text("Tiger & Goat " + VERSION + "\nA traditional hunt-and-trap game for two.\n\nFonts: Fredoka and Figtree (SIL Open Font License).\nIcons: Tabler Icons (MIT License).\nSounds: made for this game.\nBuilt with the Godot Engine (MIT License).")], [["Close", func() -> void: pass, true]])



func _server_text() -> String:
	var url := Online.server_url()
	return url.trim_prefix("ws://").trim_prefix("wss://") if url != "" else tr("Not set")


func _edit_server() -> void:
	var field := LineEdit.new()
	field.text = str(Store.data["online"]["server"])
	field.placeholder_text = "192.168.1.10:9080"
	field.custom_minimum_size.y = 110
	Modal.show(app, "Game server", [Modal.text("The address of the Tiger & Goat server. Leave empty to use the default."), field], [
		["Cancel", func() -> void: pass],
		["Save", func() -> void:
			Store.data["online"]["server"] = field.text.strip_edges()
			Store.save_data()
			Online.go_offline()
			_server_value.text = _server_text(), true],
	])
