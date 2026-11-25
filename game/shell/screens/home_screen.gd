extends AppScreen
## Play tab: greeting, daily puzzle card, and the game shelf (D46, D48).

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const GamePage := preload("res://shell/screens/game_page.gd")

var _hello: Label
var _greet: Label
var _avatar_slot: Control


func _ready() -> void:
	var col := page()

	var head := Ui.hbox(20)
	var words := Ui.vbox(0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_greet = Ui.label("", 28, Ui.MUTED)
	words.add_child(_greet)
	_hello = Ui.heading("", 62)
	words.add_child(_hello)
	head.add_child(words)
	_avatar_slot = Ui.hbox(0)
	Ui.on_tap(_avatar_slot, func() -> void: app.show_tab(3))
	head.add_child(_avatar_slot)
	col.add_child(head)

	# Daily puzzle card.
	var daily := Ui.card(Ui.WARM, Ui.ACCENT_LINE, 26)
	var drow := Ui.hbox(22)
	drow.add_child(Ui.icon("flame", 64, Ui.ACCENT))
	var dw := Ui.vbox(0)
	dw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dw.add_child(Ui.heading("Daily puzzle", 36))
	dw.add_child(Ui.muted("A new challenge every day. Build your streak.", 26))
	drow.add_child(dw)
	drow.add_child(Ui.soon_pill())
	daily.add_child(drow)
	Ui.on_tap(daily, func() -> void: app.show_tab(1))
	col.add_child(daily)

	col.add_child(Ui.heading("Games", 40))

	# Tiger & Goat: the featured game card.
	var game := Ui.card(Ui.PANEL, Ui.LINE, 0)
	var gcol := Ui.vbox(0)
	game.add_child(gcol)
	var art := PanelContainer.new()
	art.add_theme_stylebox_override("panel", _top_rounded(Ui.MEADOW_DEEP))
	art.mouse_filter = Control.MOUSE_FILTER_PASS
	var preview_state := R.new_game()
	for m: int in [R.encode(R.NONE, 8, R.NONE), R.encode(3, 9, R.NONE), R.encode(R.NONE, 15, R.NONE)]:
		preview_state = R.apply(preview_state, m)
	art.add_child(BoardPreview.create(preview_state, 400))
	gcol.add_child(art)
	var info := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		info.add_theme_constant_override("margin_" + side, 26)
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	gcol.add_child(info)
	var irow := Ui.hbox(20)
	info.add_child(irow)
	var iw := Ui.vbox(0)
	iw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	iw.add_child(Ui.heading("Tiger & Goat", 44))
	iw.add_child(Ui.muted("Hunt or trap  ·  2 players  ·  about 8 min", 26))
	irow.add_child(iw)
	var play := Ui.button("Play", _open_game, true, 96)
	play.custom_minimum_size.x = 200
	play.size_flags_horizontal = Control.SIZE_SHRINK_END
	irow.add_child(play)
	Ui.on_tap(game, _open_game)
	col.add_child(game)

	# More games, coming soon (D48).
	var more := Ui.hbox(18)
	for g: Array in [["Mancala", "circle-dot"], ["Ludo", "dice-5"], ["More", "plus"]]:
		var c := Ui.card(Ui.PANEL, Ui.LINE, 20, 30)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.modulate = Color(1, 1, 1, 0.8)
		var v := Ui.vbox(6)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic := Ui.icon(g[1], 56, Ui.MUTED)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ic)
		var name := Ui.heading(g[0], 30)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(name)
		var soon := Ui.soon_pill()
		soon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(soon)
		c.add_child(v)
		more.add_child(c)
	col.add_child(more)


func on_show() -> void:
	_greet.text = Ui.greeting()
	_hello.text = tr("Hi, %s") % Store.player_name()
	for c in _avatar_slot.get_children():
		c.queue_free()
	_avatar_slot.add_child(Ui.avatar(Store.avatar(), Store.avatar_colour(), 120))


func _open_game() -> void:
	app.push(GamePage.new())


func _top_rounded(fill: Color) -> StyleBoxFlat:
	var b := Ui.box(fill, Color(0, 0, 0, 0), 34, 0, 0)
	b.corner_radius_bottom_left = 0
	b.corner_radius_bottom_right = 0
	return b
