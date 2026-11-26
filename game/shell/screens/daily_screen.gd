extends AppScreen
## Daily tab: today's puzzle, the streak, and practice puzzles (BUILD_PLAN.md phase 4).

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const PuzzleScreen := preload("res://shell/screens/puzzle_screen.gd")

var _col: VBoxContainer


func _ready() -> void:
	_col = page()


func on_show() -> void:
	for c in _col.get_children():
		c.queue_free()
	_col.add_child(Ui.heading("Daily puzzle", 62))
	var day := Daily.day_number()
	var p := Daily.puzzle_for(day)
	if p.is_empty():
		_col.add_child(Ui.muted("Puzzles are on their way.", 30))
		return

	var card := Ui.card(Ui.WARM, Ui.ACCENT_LINE, 34)
	var v := Ui.vbox(16)
	var head := Ui.hbox(18)
	head.add_child(Ui.icon("flame", 72, Ui.ACCENT))
	var hw := Ui.vbox(0)
	hw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hw.add_child(Ui.heading(tr("Puzzle #%d") % day, 46))
	hw.add_child(Ui.label(_weekday(), 26, Ui.MUTED))
	head.add_child(hw)
	head.add_child(Ui.token(int(p["turn"]) == R.TIGER, 34))
	v.add_child(head)
	var goal := Ui.label(AadupuliPuzzles.goal_text(p), 30, Ui.INK, "bold")
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(goal)
	var preview := Ui.card(Ui.MEADOW_DEEP, Color(0, 0, 0, 0), 0, 30)
	preview.add_child(BoardPreview.create(AadupuliPuzzles.position(p), 360))
	v.add_child(preview)
	var done := Daily.tries_on(day)
	if done > 0:
		var solved := Ui.label(tr("Solved today on the first try") if done == 1 else tr("Solved today in %d tries") % done, 30, Color("#3B6D11"), "bold")
		v.add_child(solved)
		var row := Ui.hbox(16)
		row.add_child(Ui.button("Copy result", func() -> void:
			DisplayServer.clipboard_set(Daily.share_text(day, done))
			Modal.show(app, "Copied", [Modal.text("Your result is copied. Paste it into WhatsApp or any message.")], [["OK", func() -> void: pass, true]]), false, 104))
		row.add_child(Ui.button("Play again", func() -> void: app.push(PuzzleScreen.create(p, 0)), false, 104))
		v.add_child(row)
		v.add_child(Ui.muted("A new puzzle arrives tomorrow.", 26))
	else:
		v.add_child(Ui.button("Solve today's puzzle", func() -> void: app.push(PuzzleScreen.create(p, day)), true, 116))
	card.add_child(v)
	_col.add_child(card)

	var stats := Ui.hbox(16)
	for pair: Array in [[str(Daily.streak()), "Day streak"], [str(Daily.best()), "Best streak"], [str(Daily.solved_count()), "Solved"]]:
		var c := Ui.card(Ui.PANEL, Ui.LINE, 20, 30)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := Ui.vbox(0)
		var n := Ui.heading(pair[0], 54)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(n)
		var l := Ui.label(pair[1], 24, Ui.MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(l)
		c.add_child(cv)
		stats.add_child(c)
	_col.add_child(stats)

	var practice := Ui.card(Ui.PANEL, Ui.LINE, 28)
	var prow := Ui.hbox(22)
	prow.add_child(Ui.icon("bulb", 60, Ui.ACCENT))
	var pw := Ui.vbox(0)
	pw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pw.add_child(Ui.heading("Practice puzzles", 34))
	pw.add_child(Ui.muted(tr("%d puzzles to sharpen your play. They don't affect your streak.") % AadupuliPuzzleData.PUZZLES.size(), 26))
	prow.add_child(pw)
	prow.add_child(Ui.icon("chevron-right", 48, Ui.MUTED))
	practice.add_child(prow)
	Ui.on_tap(practice, func() -> void: app.push(PuzzleScreen.create(Daily.random_practice(), 0)))
	_col.add_child(practice)


func _weekday() -> String:
	var d: int = Time.get_datetime_dict_from_system()["weekday"]
	var names := ["Sunday · hard", "Monday · gentle", "Tuesday · easy", "Wednesday · easy", "Thursday · medium", "Friday · medium", "Saturday · tricky"]
	return names[d]
