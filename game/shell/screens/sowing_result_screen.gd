extends "res://shell/screens/result_popup.gd"
## End of a pits-and-seeds game: who won, the seed count, and what next.

const S := preload("res://games/sowing/sowing_rules.gd")

var final_state: S.State
var game_id := "kalah"
var mode := "computer"
var level := "medium"


static func create(s: S.State, id: String, p_mode: String, p_level: String) -> AppScreen:
	var r: AppScreen = load("res://shell/screens/sowing_result_screen.gd").new()
	r.final_state = s
	r.game_id = id
	r.mode = p_mode
	r.level = p_level
	return r


func _ready() -> void:
	var col := _popup()
	var res := S.result(final_state)
	var mine := final_state.stores[0]
	var theirs := final_state.stores[1]
	var pass_play := mode == "pass"
	var human_won := res == S.WIN_0

	var context := tr("%s  ·  PASS AND PLAY") % tr(Games.title(game_id)).to_upper() if pass_play \
		else tr("%s  ·  %s") % [tr(Games.title(game_id)).to_upper(), tr(level.capitalize()).to_upper()]
	var top := Ui.label(context, 24, Ui.MUTED, "bold")
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(top)

	var badge := Ui.icon("trophy" if res != S.DRAW else "thumb-up", 96, Ui.ACCENT)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(badge)

	var headline: String
	if res == S.DRAW:
		headline = "It's a draw"
	elif pass_play:
		headline = tr("Player %d wins!") % (1 if human_won else 2)
	else:
		headline = "You win!" if human_won else "The computer wins"
	var h := Ui.heading(headline, 70)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(h)
	var why: String
	if res == S.DRAW:
		why = tr("%d seeds each.") % mine
	else:
		why = tr("%d seeds to %d.") % [maxi(mine, theirs), mini(mine, theirs)]
	var w := Ui.muted(why, 30)
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(w)

	var happy := pass_play or human_won
	if not pass_play and human_won:
		Sfx.vibrate(40)
	_play_sound.call_deferred("win" if happy or res == S.DRAW else "lose")
	if happy and res != S.DRAW:
		_confetti()

	var pairs: Array
	if pass_play:
		pairs = [["Player 1", mine], ["Player 2", theirs], ["Moves", final_state.moves_played]]
	else:
		pairs = [["Your seeds", mine], ["Computer", theirs], ["Win streak", Store.stat("streak")]]
	col.add_child(number_cards(pairs))

	var row := Ui.hbox(18)
	row.add_child(Ui.button("Home", func() -> void: app.home()))
	row.add_child(Ui.button("Rules", func() -> void: Games.how_to_play(app, game_id)))
	col.add_child(row)
	col.add_child(Ui.button("Play again", _again, true, 124))
	var next_text: String
	if pass_play:
		next_text = tr("Player %d starts the next game.") % (1 if _you_start_next() else 2)
	else:
		next_text = "You start the next game." if _you_start_next() else "The computer starts the next game."
	var next := Ui.muted(next_text, 26)
	next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(next)


func _you_start_next() -> bool:
	return int(Store.data["games"][game_id]["next_first"]) == 0


func _again() -> void:
	var play: Script = load("res://shell/screens/sowing_play_screen.gd")
	app.pop()  # This popup...
	app.replace(play.create(game_id, mode, level))  # ...then the finished game beneath it.
