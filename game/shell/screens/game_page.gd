extends AppScreen
## Tiger & Goat's page: what it is, how to play it, and the play options (D46, D48).

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const PlayScreen := preload("res://shell/screens/play_screen.gd")

var mode := ""
var level := ""
var side := ""
var _mode_cards := {}
var _level_chips := {}
var _side_chips := {}
var _side_row: Control


func _ready() -> void:
	mode = Store.last("mode")
	level = Store.last("level")
	side = Store.last("side")
	var col := page(true, 64, 40)
	col.add_child(top_bar("Tiger & Goat", Ui.icon_button("help-circle", func() -> void: Modal.how_to_play(app))))

	var art := Ui.card(Ui.MEADOW_DEEP, Color(0, 0, 0, 0), 0, 34)
	art.add_child(BoardPreview.create(R.new_game(), 380))
	col.add_child(art)
	col.add_child(Ui.muted("Three tigers hunt fifteen goats on a hill. Tigers win by capturing 5 goats; goats win by trapping every tiger.", 28))
	var learn := Ui.card(Ui.WARM, Ui.ACCENT_LINE, 24)
	var lrow := Ui.hbox(20)
	lrow.add_child(Ui.icon("bulb", 56, Ui.ACCENT))
	var lw := Ui.vbox(0)
	lw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lw.add_child(Ui.heading("Learn to play", 34))
	lw.add_child(Ui.muted("Five tiny lessons on the real board, about a minute.", 26))
	lrow.add_child(lw)
	lrow.add_child(Ui.icon("chevron-right", 48, Ui.MUTED))
	learn.add_child(lrow)
	Ui.on_tap(learn, func() -> void: app.push(load("res://shell/screens/tutorial_screen.gd").new()))
	col.add_child(learn)

	col.add_child(section("Play"))
	var cpu := _mode_card("computer", "robot", "Against the computer", "")
	var chips := Ui.hbox(14)
	for l: Array in [["easy", "Easy"], ["medium", "Medium"], ["hard", "Hard"]]:
		var chip := _chip(l[1])
		Ui.on_tap(chip, _set_level.bind(l[0]))
		_level_chips[l[0]] = chip
		chips.add_child(chip)
	(cpu.get_meta("words") as VBoxContainer).add_child(chips)
	col.add_child(cpu)
	col.add_child(_mode_card("pass", "users", "Pass and play", "Two people, one phone"))
	var online := _mode_card("online", "world", "Play online", "Find a player, or invite a friend with a code")
	(online.get_meta("row") as HBoxContainer).add_child(Ui.icon("chevron-right", 48, Ui.MUTED))
	Ui.on_tap(online, func() -> void: app.push(load("res://shell/screens/online_screen.gd").new()))
	col.add_child(online)

	_side_row = Ui.hbox(14)
	var as_label := Ui.label("Play as", 28, Ui.MUTED)
	as_label.custom_minimum_size.x = 140
	_side_row.add_child(as_label)
	for s: Array in [["goats", "Goats"], ["tigers", "Tigers"], ["toss", "Coin toss"]]:
		var chip := _chip(s[1])
		Ui.on_tap(chip, _set_side.bind(s[0]))
		_side_chips[s[0]] = chip
		_side_row.add_child(chip)
	col.add_child(_side_row)

	col.add_child(Ui.button("Play", _start, true, 124))
	_refresh()


func _mode_card(id: String, icon_name: String, title: String, sub: String) -> PanelContainer:
	var c := Ui.card(Ui.PANEL, Ui.LINE, 26)
	var row := Ui.hbox(24)
	row.add_child(Ui.icon(icon_name, 60, Ui.ACCENT if id == "computer" else Ui.MUTED))
	var words := Ui.vbox(12)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(Ui.heading(title, 36))
	if sub != "":
		words.add_child(Ui.muted(sub, 26))
	row.add_child(words)
	c.add_child(row)
	c.set_meta("words", words)
	c.set_meta("row", row)
	if id != "online":
		Ui.on_tap(c, _set_mode.bind(id))
		_mode_cards[id] = c
	return c


func _chip(text: String) -> PanelContainer:
	var c := PanelContainer.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := Ui.label(text, 28, Ui.INK, "bold")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(l)
	return c


func _set_mode(m: String) -> void:
	mode = m
	_refresh()


func _set_level(l: String) -> void:
	mode = "computer"
	level = l
	_refresh()


func _set_side(s: String) -> void:
	side = s
	_refresh()


func _refresh() -> void:
	for id: String in _mode_cards:
		var on := id == mode
		_mode_cards[id].add_theme_stylebox_override("panel", Ui.box(Ui.PANEL, Ui.ACCENT if on else Ui.LINE, 36, 5 if on else 3, 26))
	for id: String in _level_chips:
		_style_chip(_level_chips[id], id == level and mode == "computer")
	for id: String in _side_chips:
		_style_chip(_side_chips[id], id == side)
	_side_row.visible = mode == "computer"


func _style_chip(chip: PanelContainer, on: bool) -> void:
	chip.add_theme_stylebox_override("panel", Ui.box(Ui.ACCENT_TINT if on else Ui.WHITE, Ui.ACCENT if on else Ui.LINE, 26, 3, 16))
	(chip.get_child(0) as Label).add_theme_color_override("font_color", Color("#B5501A") if on else Ui.INK)


func _start() -> void:
	Store.set_last("mode", mode)
	Store.set_last("level", level)
	Store.set_last("side", side)
	var human := side
	if mode == "computer" and side == "toss":
		human = "goats" if randi() % 2 == 0 else "tigers"
	app.push(PlayScreen.create(mode, level, human, mode == "computer" and side == "toss"))
