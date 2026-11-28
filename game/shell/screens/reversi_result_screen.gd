extends "res://shell/screens/result_popup.gd"
## End of a Reversi game: who won (or a draw), the final disc count, and what next.
## Against the computer: play again moving first or second as before, or switch.

const R := preload("res://games/reversi/reversi_rules.gd")

var final_state: R.State
var game_id := "reversi"
var mode := "computer"
var level := "medium"
var me := 0  ## Your player number: 0 moved first (orange), 1 second (cream).
var tossed := false


static func create(s: R.State, id: String, p_mode: String, p_level: String, p_me := 0, p_tossed := false) -> AppScreen:
	var r: AppScreen = load("res://shell/screens/reversi_result_screen.gd").new()
	r.final_state = s
	r.game_id = id
	r.mode = p_mode
	r.level = p_level
	r.me = p_me
	r.tossed = p_tossed
	return r


func _ready() -> void:
	var col := _popup()
	var pass_play := mode == "pass"
	var my_side := "first" if me == 0 else "second"
	var res := R.result(final_state)
	var is_draw := res == R.DRAW
	var human_won := (res == R.WIN_0) == (me == 0) and not is_draw
	var orange := R.discs(final_state, 0)
	var cream := R.discs(final_state, 1)

	var title := tr(Games.title(game_id)).to_upper()
	var context: String
	if pass_play:
		context = tr("%s  ·  PASS AND PLAY") % title
	else:
		context = tr("%s  ·  %s  ·  YOU MOVED %s") % [title, tr(level.capitalize()).to_upper(), tr(my_side).to_upper()]
	var top := Ui.label(context, 24, Ui.MUTED, "bold")
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(top)

	var badge := Ui.icon("thumb-up" if is_draw else "trophy", 96, Ui.ACCENT)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(badge)

	var headline: String
	if is_draw:
		headline = "It's a draw"
	elif pass_play:
		headline = tr("Player %d wins!") % (1 if res == R.WIN_0 else 2)
	else:
		headline = "You win!" if human_won else "The computer wins"
	var h := Ui.heading(headline, 70)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(h)
	var why := tr("Orange %d, cream %d.") % [orange, cream]
	if orange + cream < R.CELLS:
		why += " " + tr("Neither player could move.")
	var w := Ui.muted(why, 30)
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(w)

	var happy := pass_play or human_won
	if not pass_play and human_won:
		Sfx.vibrate(40)
	_play_sound.call_deferred("win" if happy or is_draw else "lose")
	if happy and not is_draw:
		_confetti()

	var pairs: Array
	if pass_play:
		pairs = [["Orange", orange], ["Cream", cream], ["Games", Store.game_stat(game_id, "pass_games")]]
	else:
		pairs = [["Your discs", R.discs(final_state, me)], ["Wins", Store.game_stat(game_id, "wins")], ["Win streak", Store.stat("streak")]]
	col.add_child(number_cards(pairs))

	var row := Ui.hbox(18)
	row.add_child(Ui.button("Home", func() -> void: app.home()))
	row.add_child(Ui.button("Rules", func() -> void: Games.how_to_play(app, game_id)))
	if mode == "computer":
		row.add_child(Ui.button("Move second" if me == 0 else "Move first", func() -> void: _again(me != 0)))
	col.add_child(row)
	col.add_child(Ui.button("Play again", func() -> void: _again(me == 0), true, 124))


## A new game on the same level; `first` says whether you move first in it.
func _again(first: bool) -> void:
	var play: Script = load("res://shell/screens/reversi_play_screen.gd")
	if mode == "computer":
		Store.set_last("seat", "first" if first else "second")
	app.pop()  # This popup...
	app.replace(play.create(game_id, mode, level, first))  # ...then the finished game beneath it.
