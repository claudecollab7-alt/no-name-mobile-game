extends AppScreen
## The page for a pits-and-seeds game (Mancala, Pallanguzhi): what it is, the rules card,
## and the play options. Same layout as Tiger & Goat's page; online comes later.

const S := preload("res://games/sowing/sowing_rules.gd")
const PlayScreen := preload("res://shell/screens/sowing_play_screen.gd")

var game_id := "kalah"
var mode := ""
var level := ""
var _mode_cards := {}
var _level_chips := {}
var _puzzle_line: Label


static func create(id: String) -> AppScreen:
	var p: AppScreen = load("res://shell/screens/sowing_game_page.gd").new()
	p.game_id = id
	return p


func _ready() -> void:
	mode = Store.last("mode")
	if mode not in ["computer", "pass"]:
		mode = "computer"
	level = Store.last("level")
	var col := page(true, 64, 40)
	col.add_child(top_bar(Games.title(game_id), Ui.icon_button("help-circle", func() -> void: Games.how_to_play(app, game_id))))

	var art := Ui.card(Ui.MEADOW_DEEP, Color(0, 0, 0, 0), 0, 34)
	art.add_child(SowingPreview.create(S.new_game(Games.rules_for(game_id)), 420, true))
	col.add_child(art)
	col.add_child(Ui.muted(str(Games.info(game_id)["about"]), 28))
	var learn := Ui.card(Ui.WARM, Ui.ACCENT_LINE, 24)
	var lrow := Ui.hbox(20)
	lrow.add_child(Ui.icon("bulb", 56, Ui.ACCENT))
	var lw := Ui.vbox(0)
	lw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lw.add_child(Ui.heading("Learn to play", 34))
	lw.add_child(Ui.muted("Four tiny lessons on the real board, about a minute.", 26))
	lrow.add_child(lw)
	lrow.add_child(Ui.icon("chevron-right", 48, Ui.MUTED))
	learn.add_child(lrow)
	Ui.on_tap(learn, _learn)
	col.add_child(learn)

	var puzzles: Array = SowingPuzzleData.PUZZLES.get(game_id, [])
	if not puzzles.is_empty():
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
		Ui.on_tap(pz, func() -> void:
			app.push(load("res://shell/screens/sowing_puzzle_screen.gd").create(game_id, Store.next_puzzle(game_id))))
		col.add_child(pz)

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
	Ui.on_tap(online, func() -> void: app.push(load("res://shell/screens/online_screen.gd").create(game_id)))
	col.add_child(online)
	var turns := Ui.muted("Moving first is an advantage, so who starts takes turns from game to game.", 26)
	col.add_child(turns)

	col.add_child(Ui.button("Play", _start, true, 124))
	_refresh()


func on_show() -> void:
	if _puzzle_line != null:
		var total: int = (SowingPuzzleData.PUZZLES.get(game_id, []) as Array).size()
		_puzzle_line.text = tr("%d puzzles, easiest first  ·  %d solved") % [total, Store.puzzles_solved(game_id).size()]


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


func _refresh() -> void:
	for id: String in _mode_cards:
		var on := id == mode
		_mode_cards[id].add_theme_stylebox_override("panel", Ui.box(Ui.PANEL, Ui.ACCENT if on else Ui.LINE, 36, 5 if on else 3, 26))
	for id: String in _level_chips:
		var on: bool = id == level and mode == "computer"
		var chip: PanelContainer = _level_chips[id]
		chip.add_theme_stylebox_override("panel", Ui.box(Ui.ACCENT_TINT if on else Ui.WHITE, Ui.ACCENT if on else Ui.LINE, 26, 3, 16))
		(chip.get_child(0) as Label).add_theme_color_override("font_color", Color("#B5501A") if on else Ui.INK)


func _learn() -> void:
	app.push(load("res://shell/screens/sowing_tutorial_screen.gd").create(game_id))


func _start() -> void:
	Store.set_last("mode", mode)
	Store.set_last("level", level)
	var g: Dictionary = Store.data["games"][game_id]
	# The first time someone plays a seed game, offer the lessons once.
	if not bool(g["tutorial_done"]) and not bool(g["tutorial_offered"]) and int(g["played"]) == 0:
		g["tutorial_offered"] = true
		Store.save_data()
		Modal.show(app, tr("New to %s?") % tr(Games.title(game_id)), [Modal.text("Four tiny lessons on the real board teach it in about a minute.")], [
			["Just play", func() -> void: app.push(PlayScreen.create(game_id, mode, level))],
			["Learn first", _learn, true],
		])
		return
	app.push(PlayScreen.create(game_id, mode, level))
