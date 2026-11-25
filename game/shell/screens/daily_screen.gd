extends AppScreen
## Daily tab. The puzzles themselves arrive in phase 4; until then this explains what's coming.

var _streak: Label


func _ready() -> void:
	var col := page()
	col.add_child(Ui.heading("Daily puzzle", 62))
	var card := Ui.card(Ui.WARM, Ui.ACCENT_LINE, 40)
	var v := Ui.vbox(18)
	var ic := Ui.icon("flame", 120, Ui.ACCENT)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var t := Ui.heading("A new puzzle every day", 44)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var body := Ui.muted("One position, one goal: capture in two, or trap in three. Solve it in as few tries as you can, share your result, and keep your streak alive.", 30)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(body)
	var soon := Ui.pill("Arriving in an upcoming update", Ui.SOFT, Ui.MUTED, 26)
	soon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(soon)
	card.add_child(v)
	col.add_child(card)

	var stats := Ui.hbox(16)
	_streak = _stat(stats, "Day streak")
	col.add_child(stats)
	col.add_child(Ui.button("Play Tiger & Goat meanwhile", func() -> void: app.show_tab(0)))


func _stat(row: HBoxContainer, caption: String) -> Label:
	var c := Ui.card(Ui.PANEL, Ui.LINE, 22, 30)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := Ui.vbox(0)
	var n := Ui.heading("0", 56)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var l := Ui.label(caption, 24, Ui.MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	c.add_child(v)
	row.add_child(c)
	return n


func on_show() -> void:
	_streak.text = str(int(Store.data["daily"]["streak"]))
