extends AppScreen
## End of a game: who won and why, the final board, three numbers, and what next.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")

var final_state: R.State
var mode := "pass"
var level := "medium"
var human_side := "goats"
var tigers_won := false


static func create(s: R.State, p_mode: String, p_level: String, p_side: String, p_tigers_won: bool) -> AppScreen:
	var r: AppScreen = load("res://shell/screens/result_screen.gd").new()
	r.final_state = s
	r.mode = p_mode
	r.level = p_level
	r.human_side = p_side
	r.tigers_won = p_tigers_won
	return r


func _ready() -> void:
	var col := page(true, 96, 40)
	var human_won := (human_side == "tigers") == tigers_won

	var context := "PASS AND PLAY" if mode == "pass" else tr("%s  ·  YOU PLAYED %s") % [tr(level.capitalize()).to_upper(), tr(human_side).to_upper()]
	var top := Ui.label(context, 24, Ui.MUTED, "bold")
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(top)

	var headline: String
	if mode == "computer":
		headline = "You win!" if human_won else "The computer wins"
	else:
		headline = "The tigers win!" if tigers_won else "The goats win!"
	var h := Ui.heading(headline, 76)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(h)
	var why := "The tigers captured 5 goats." if tigers_won and final_state.captured >= final_state.capture_target else (
		"All three tigers are trapped." if not tigers_won else "The goats had no move left.")
	var w := Ui.muted(why, 30)
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(w)
	if mode == "computer" and human_won:
		Sfx.vibrate(40)

	var art := Ui.card(Ui.MEADOW_DEEP, Color(0, 0, 0, 0), 0, 34)
	art.add_child(BoardPreview.create(final_state, 600))
	col.add_child(art)

	var nums := Ui.hbox(16)
	var third: Array = ["Win streak", str(Store.stat("streak"))] if mode == "computer" else ["Goats left", str(R.goats_on_board(final_state))]
	for pair: Array in [["Moves", str(final_state.moves_played)], ["Goats caught", str(final_state.captured)], third]:
		var c := Ui.card(Ui.PANEL, Ui.LINE, 18, 30)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := Ui.vbox(0)
		var big := Ui.heading(pair[1], 52)
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(big)
		var small := Ui.label(pair[0], 24, Ui.MUTED)
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(small)
		c.add_child(v)
		nums.add_child(c)
	col.add_child(nums)

	var row := Ui.hbox(18)
	row.add_child(Ui.button("Home", func() -> void: app.home()))
	if mode == "computer":
		var other := "goats" if human_side == "tigers" else "tigers"
		row.add_child(Ui.button("Switch sides", func() -> void: _again(other)))
	col.add_child(row)
	col.add_child(Ui.button("Rematch", func() -> void: _again(human_side), true, 124))


func _again(side: String) -> void:
	var play: Script = load("res://shell/screens/play_screen.gd")
	app.replace(play.create(mode, level, side))
