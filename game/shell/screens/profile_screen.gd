extends AppScreen
## Profile tab: optional name and animal avatar (D47), totals, per-side record, badges.

const SettingsScreen := preload("res://shell/screens/settings_screen.gd")

var _col: VBoxContainer


func _ready() -> void:
	_col = page()


func on_show() -> void:
	for c in _col.get_children():
		c.queue_free()
	var top := Ui.vbox(8)
	var av := Ui.avatar(Store.avatar(), Store.avatar_colour(), 220)
	Ui.on_tap(av, _edit_profile)
	top.add_child(av)
	var n := Ui.heading(Store.player_name(), 58)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(n)
	var since := Ui.hbox(12)
	since.alignment = BoxContainer.ALIGNMENT_CENTER
	since.add_child(Ui.label(tr("Playing since %s") % Store.since_text(), 26, Ui.MUTED))
	var edit := Ui.label("Edit", 26, Ui.ACCENT, "bold")
	Ui.on_tap(edit, _edit_profile)
	since.add_child(edit)
	top.add_child(since)
	_col.add_child(top)

	var totals := Ui.hbox(16)
	for pair: Array in [[str(Store.stat("played")), "Games"], ["%d%%" % Store.win_rate(), "Wins vs computer"], [str(Store.stat("best_streak")), "Best streak"]]:
		totals.add_child(_number(pair[0], pair[1]))
	_col.add_child(totals)

	var record := Ui.card(Ui.PANEL, Ui.LINE, 28)
	var rv := Ui.vbox(14)
	rv.add_child(Ui.heading("Tiger & Goat", 36))
	rv.add_child(_line("As tigers", "%d – %d" % [Store.stat("tiger_wins"), Store.stat("tiger_losses")]))
	rv.add_child(_line("As goats", "%d – %d" % [Store.stat("goat_wins"), Store.stat("goat_losses")]))
	rv.add_child(_line("Pass and play games", str(Store.stat("pass_games"))))
	var hardest := str(Store.data["stats"]["hardest"])
	rv.add_child(_line("Hardest level beaten", tr(hardest.capitalize()) if hardest != "" else "—"))
	record.add_child(rv)
	_col.add_child(record)

	var seeds := Ui.card(Ui.PANEL, Ui.LINE, 28)
	var sv := Ui.vbox(14)
	sv.add_child(Ui.heading("Seed games", 36))
	for id: String in ["kalah", "pallanguzhi"]:
		var rec := "%d – %d" % [Store.game_stat(id, "wins"), Store.game_stat(id, "losses")]
		if Store.game_stat(id, "draws") > 0:
			rec += tr("  ·  %d drawn") % Store.game_stat(id, "draws")
		sv.add_child(_line(Games.title(id), rec))
	seeds.add_child(sv)
	_col.add_child(seeds)

	_col.add_child(Ui.heading("Badges", 38))
	var badges := Ui.hbox(12)
	for b: Dictionary in Store.badges():
		var v := Ui.vbox(6)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var circle := PanelContainer.new()
		circle.custom_minimum_size = Vector2(124, 124)
		circle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var earned: bool = b["earned"]
		circle.add_theme_stylebox_override("panel", Ui.box(Ui.ACCENT_TINT if earned else Color("#E9EEE0"), Ui.ACCENT_LINE if earned else Ui.LINE, 62, 3, 0))
		var ic := Ui.icon(b["icon"], 60, Ui.ACCENT if earned else Ui.FAINT)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		circle.add_child(ic)
		v.add_child(circle)
		var t := Ui.label(b["title"], 24, Ui.MUTED if earned else Ui.FAINT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		badges.add_child(v)
	_col.add_child(badges)

	var settings := Ui.card(Ui.PANEL, Ui.LINE, 28)
	var srow := Ui.hbox(22)
	srow.add_child(Ui.icon("settings", 56, Ui.INK))
	var st := Ui.heading("Settings", 36)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(st)
	srow.add_child(Ui.icon("chevron-right", 48, Ui.MUTED))
	settings.add_child(srow)
	Ui.on_tap(settings, func() -> void: app.push(SettingsScreen.new()))
	_col.add_child(settings)


func _number(value: String, caption: String) -> PanelContainer:
	var c := Ui.card(Ui.PANEL, Ui.LINE, 18, 30)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := Ui.vbox(0)
	var big := Ui.heading(value, 52)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var small := Ui.label(caption, 22, Ui.MUTED)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(small)
	c.add_child(v)
	return c


func _line(left: String, right: String) -> HBoxContainer:
	var row := Ui.hbox(12)
	var l := Ui.label(left, 30, Ui.INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(Ui.label(right, 30, Ui.INK, "bold"))
	return row


func _edit_profile() -> void:
	var name_field := LineEdit.new()
	name_field.text = str(Store.data["profile"]["name"])
	name_field.placeholder_text = tr("Player")
	name_field.max_length = 16
	name_field.custom_minimum_size.y = 110
	var choice := {"avatar": Store.avatar(), "colour": Store.avatar_colour()}
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	var cells: Array = []
	var options: Array = []
	for kind in ["goat", "tiger"]:
		for colour in [1, 0, 2, 3]:
			options.append([kind, colour])
	for opt: Array in options:
		var cell := PanelContainer.new()
		var a := Ui.avatar(opt[0], opt[1], 170)
		cell.add_child(a)
		cells.append([cell, opt])
		Ui.on_tap(cell, func() -> void:
			choice["avatar"] = opt[0]
			choice["colour"] = opt[1]
			_mark(cells, choice))
		grid.add_child(cell)
	_mark(cells, choice)
	var center := CenterContainer.new()
	center.add_child(grid)
	Modal.show(app, "Your profile", [Ui.label("Name", 26, Ui.MUTED, "bold"), name_field, Ui.label("Avatar", 26, Ui.MUTED, "bold"), center], [
		["Cancel", func() -> void: pass],
		["Save", func() -> void:
			Store.set_profile(name_field.text, choice["avatar"], choice["colour"])
			on_show(), true],
	])


func _mark(cells: Array, choice: Dictionary) -> void:
	for pair: Array in cells:
		var opt: Array = pair[1]
		var on: bool = opt[0] == choice["avatar"] and opt[1] == choice["colour"]
		(pair[0] as PanelContainer).add_theme_stylebox_override("panel", Ui.box(Color(0, 0, 0, 0), Ui.ACCENT if on else Color(0, 0, 0, 0), 96, 6, 6))
