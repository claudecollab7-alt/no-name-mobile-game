extends AppScreen
## A tiger-and-goat game's page (Tiger & Goat, Bagh-Chal): what it is, how to play it,
## and the play options (D46, D48). Bagh-Chal offers its lessons the first time you play.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const PlayScreen := preload("res://shell/screens/play_screen.gd")

var board_id := "aadupuli"
var mode := ""
var level := ""
var side := ""
var _mode_cards := {}
var _level_chips := {}
var _side_chips := {}
var _side_row: Control
var _puzzle_line: Label


static func create(board: String) -> AppScreen:
	var s: AppScreen = load("res://shell/screens/game_page.gd").new()
	s.board_id = board
	return s


func _ready() -> void:
	mode = Store.last("mode")
	level = Store.last("level")
	side = Store.last("side")
	var info := Games.tiger_info(board_id)
	var col := page(true, 64, 40)
	col.add_child(top_bar(str(info["title"]), Ui.icon_button("help-circle", func() -> void: Modal.how_to_play(app, board_id))))

	var art := Ui.card(Ui.MEADOW_DEEP, Color(0, 0, 0, 0), 0, 34)
	art.add_child(BoardPreview.create(R.new_game({"board": board_id}), 380 if board_id == "aadupuli" else 520))
	col.add_child(art)
	col.add_child(Ui.muted(str(info["about"]), 28))
	if info["lessons"]:
		_learn_card(col)
	if not Games.puzzles(board_id).is_empty():
		_puzzle_card(col)
	_play_options(col)


func on_show() -> void:
	if _puzzle_line != null:
		_puzzle_line.text = tr("%d puzzles, easiest first  ·  %d solved") % [Games.puzzles(board_id).size(), Store.puzzles_solved(board_id).size()]


func _puzzle_card(col: VBoxContainer) -> void:
	var pz := Ui.card(Ui.PANEL, Ui.LINE, 24)
	var prow := Ui.hbox(20)
	prow.add_child(Ui.icon("star", 56, Ui.ACCENT))
	var pw := Ui.vbox(0)
	pw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pw.add_child(Ui.heading("Puzzles", 34))
	_puzzle_line = Ui.muted("", 26)
	pw.add_child(_puzzle_line)
	prow.add_child(pw)
	prow.add_child(Ui.icon("chevron-right", 48, Ui.MUTED))
	pz.add_child(prow)
	Ui.on_tap(pz, _open_puzzles)
	col.add_child(pz)


func _open_puzzles() -> void:
	app.push(load("res://shell/screens/puzzle_screen.gd").create(Store.next_puzzle(board_id)))


func _learn_card(col: VBoxContainer) -> void:
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
	Ui.on_tap(learn, _learn)
	col.add_child(learn)


func _play_options(col: VBoxContainer) -> void:
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
	Ui.on_tap(online, func() -> void: app.push(load("res://shell/screens/online_screen.gd").create(board_id)))
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


func _learn() -> void:
	app.push(load("res://shell/screens/tutorial_screen.gd").create(board_id))


func _start() -> void:
	Store.set_last("mode", mode)
	Store.set_last("level", level)
	Store.set_last("side", side)
	# Bagh-Chal: the first time someone plays it, offer the lessons once (Tiger & Goat
	# offers its own on first launch).
	if board_id != "aadupuli":
		var g: Dictionary = Store.data["games"][board_id]
		if not bool(g["tutorial_done"]) and not bool(g["tutorial_offered"]) and int(g["played"]) == 0:
			g["tutorial_offered"] = true
			Store.save_data()
			Modal.show(app, tr("New to %s?") % tr(Games.title(board_id)), [Modal.text("Five tiny lessons on the real board teach it in about a minute.")], [
				["Just play", _play],
				["Learn first", _learn, true],
			])
			return
	_play()


func _play() -> void:
	var human := side
	if mode == "computer" and side == "toss":
		human = "goats" if randi() % 2 == 0 else "tigers"
	app.push(PlayScreen.create(mode, level, human, mode == "computer" and side == "toss", board_id))
