extends AppScreen
## The page for Four in a Row (DISCUSSION.md section 31): what it is, the rules card, and
## the play options. Against the computer you choose who moves first (D69): Play first,
## Play second or Coin toss; online, you pick first, second or either. Four lessons are
## offered once, the first time you press Play. Puzzles come later (G4.7).

const F := preload("res://games/fourinrow/four_rules.gd")
const PlayScreen := preload("res://shell/screens/four_play_screen.gd")

var game_id := "fourinrow"
var mode := ""
var level := ""
var seat := "first"  ## "first", "second" or "toss"
var _mode_cards := {}
var _level_chips := {}
var _seat_chips := {}
var _seat_row: Control


static func create(id: String) -> AppScreen:
	var p: AppScreen = load("res://shell/screens/four_game_page.gd").new()
	p.game_id = id
	return p


func _ready() -> void:
	mode = Store.last("mode")
	if mode not in ["computer", "pass"]:
		mode = "computer"
	level = Store.last("level")
	seat = Store.last("seat")
	if seat not in ["first", "second", "toss"]:
		seat = "first"
	var col := page(true, 64, 40)
	col.add_child(top_bar(Games.title(game_id), Ui.icon_button("help-circle", func() -> void: Games.how_to_play(app, game_id))))

	var art := Ui.card(Ui.MEADOW_DEEP, Color(0, 0, 0, 0), 0, 34)
	art.add_child(FourPreview.create(F.new_game(), 460))
	col.add_child(art)
	col.add_child(Ui.muted(str(Games.info(game_id)["about"]), 28))
	var learn := Ui.card(Ui.WARM, Ui.ACCENT_LINE, 24)
	var lrow := Ui.hbox(20)
	lrow.add_child(Ui.icon("bulb", 56, Ui.ACCENT))
	var lw := Ui.vbox(0)
	lw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lw.add_child(Ui.heading("Learn to play", 34))
	lw.add_child(Ui.muted("Four tiny lessons on the real frame, about a minute.", 26))
	lrow.add_child(lw)
	lrow.add_child(Ui.icon("chevron-right", 48, Ui.MUTED))
	learn.add_child(lrow)
	Ui.on_tap(learn, _learn)
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
	col.add_child(_mode_card("pass", "users", "Pass and play", "Two people, one phone. Player 1 moves first."))
	var online := _mode_card("online", "world", "Play online", "Find a player, or invite a friend with a code")
	(online.get_meta("row") as HBoxContainer).add_child(Ui.icon("chevron-right", 48, Ui.MUTED))
	col.add_child(online)

	_seat_row = Ui.hbox(14)
	var as_label := Ui.label("Play", 28, Ui.MUTED)
	as_label.custom_minimum_size.x = 80
	_seat_row.add_child(as_label)
	for s: Array in [["first", "First"], ["second", "Second"], ["toss", "Coin toss"]]:
		var chip := _chip(s[1])
		Ui.on_tap(chip, _set_seat.bind(s[0]))
		_seat_chips[s[0]] = chip
		_seat_row.add_child(chip)
	col.add_child(_seat_row)
	col.add_child(Ui.muted("Orange moves first. Moving first is an advantage, so it's your choice.", 26))

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
	if id == "online":
		Ui.on_tap(c, func() -> void: app.push(load("res://shell/screens/online_screen.gd").create(game_id)))
	else:
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


func _set_seat(s: String) -> void:
	seat = s
	_refresh()


func _refresh() -> void:
	for id: String in _mode_cards:
		var on := id == mode
		_mode_cards[id].add_theme_stylebox_override("panel", Ui.box(Ui.PANEL, Ui.ACCENT if on else Ui.LINE, 36, 5 if on else 3, 26))
	for id: String in _level_chips:
		_style_chip(_level_chips[id], id == level and mode == "computer")
	for id: String in _seat_chips:
		_style_chip(_seat_chips[id], id == seat)
	_seat_row.visible = mode == "computer"


func _style_chip(chip: PanelContainer, on: bool) -> void:
	chip.add_theme_stylebox_override("panel", Ui.box(Ui.ACCENT_TINT if on else Ui.WHITE, Ui.ACCENT if on else Ui.LINE, 26, 3, 16))
	(chip.get_child(0) as Label).add_theme_color_override("font_color", Color("#B5501A") if on else Ui.INK)


func _learn() -> void:
	app.push(load("res://shell/screens/four_tutorial_screen.gd").create(game_id))


func _start() -> void:
	Store.set_last("mode", mode)
	Store.set_last("level", level)
	Store.set_last("seat", seat)
	var g: Dictionary = Store.data["games"][game_id]
	# The first time someone plays, offer the lessons once.
	if not bool(g["tutorial_done"]) and not bool(g["tutorial_offered"]) and int(g["played"]) == 0:
		g["tutorial_offered"] = true
		Store.save_data()
		Modal.show(app, tr("New to %s?") % tr(Games.title(game_id)), [Modal.text("Four tiny lessons on the real frame teach it in about a minute.")], [
			["Just play", _play],
			["Learn first", _learn, true],
		])
		return
	_play()


func _play() -> void:
	var first := seat != "second"
	if mode == "computer" and seat == "toss":
		first = randi() % 2 == 0
	app.push(PlayScreen.create(game_id, mode, level, first, mode == "computer" and seat == "toss"))
