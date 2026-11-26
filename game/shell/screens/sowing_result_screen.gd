extends "res://shell/screens/result_popup.gd"
## End of a pits-and-seeds game: who won, the seed count, and what next.
## Online games also offer a rematch, in which the other player starts.

const S := preload("res://games/sowing/sowing_rules.gd")

var final_state: S.State
var game_id := "kalah"
var mode := "computer"
var level := "medium"
var me := 0  ## Your player number (online you may be the second to move).
var opponent := {}  ## Online only
var winner := ""  ## Online only: "first", "second" or "draw" from the server
var reason := ""  ## Online only: seeds, resign, timeout, left
var _rematch_button: Button
var _note: Label
var _moving_on := false


static func create(s: S.State, id: String, p_mode: String, p_level: String) -> AppScreen:
	var r: AppScreen = load("res://shell/screens/sowing_result_screen.gd").new()
	r.final_state = s
	r.game_id = id
	r.mode = p_mode
	r.level = p_level
	return r


func _ready() -> void:
	var col := _popup()
	var mine := final_state.stores[me]
	var theirs := final_state.stores[1 - me]
	var pass_play := mode == "pass"
	var them := str(opponent.get("name", "Player"))
	# Who won: online the server says (it also knows about resigning and time-outs).
	var my_side := "first" if me == 0 else "second"
	var draw: bool
	var human_won: bool
	if mode == "online":
		draw = winner == "draw"
		human_won = winner == my_side
	else:
		var res := S.result(final_state)
		draw = res == S.DRAW
		human_won = res == S.WIN_0

	var context: String
	if pass_play:
		context = tr("%s  ·  PASS AND PLAY") % tr(Games.title(game_id)).to_upper()
	elif mode == "online":
		context = tr("%s  ·  ONLINE") % tr(Games.title(game_id)).to_upper()
	else:
		context = tr("%s  ·  %s") % [tr(Games.title(game_id)).to_upper(), tr(level.capitalize()).to_upper()]
	var top := Ui.label(context, 24, Ui.MUTED, "bold")
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(top)

	var badge := Ui.icon("thumb-up" if draw else "trophy", 96, Ui.ACCENT)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(badge)

	var headline: String
	if draw:
		headline = "It's a draw"
	elif pass_play:
		headline = tr("Player %d wins!") % (1 if human_won else 2)
	elif mode == "online":
		headline = "You win!" if human_won else tr("%s wins") % them
	else:
		headline = "You win!" if human_won else "The computer wins"
	var h := Ui.heading(headline, 70)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(h)
	var why: String
	if draw:
		why = tr("%d seeds each.") % mine
	else:
		why = tr("%d seeds to %d.") % [maxi(mine, theirs), mini(mine, theirs)]
	if mode == "online":
		var whose := "You" if not human_won else them
		match reason:
			"resign": why = tr("%s resigned.") % whose
			"timeout": why = tr("%s ran out of time twice.") % whose
			"left": why = tr("%s left the game.") % whose
	var w := Ui.muted(why, 30)
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(w)

	var happy := pass_play or human_won
	if not pass_play and human_won:
		Sfx.vibrate(40)
	_play_sound.call_deferred("win" if happy or draw else "lose")
	if happy and not draw:
		_confetti()

	var pairs: Array
	if pass_play:
		pairs = [["Player 1", mine], ["Player 2", theirs], ["Moves", final_state.moves_played]]
	elif mode == "online":
		pairs = [["Your seeds", mine], [them, theirs], ["Online wins", Store.stat("online_wins")]]
	else:
		pairs = [["Your seeds", mine], ["Computer", theirs], ["Win streak", Store.stat("streak")]]
	col.add_child(number_cards(pairs))

	if mode == "online":
		_note = Ui.muted("", 28)
		_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(_note)
		var orow := Ui.hbox(18)
		orow.add_child(Ui.button("Home", func() -> void: app.home()))
		_rematch_button = Ui.button("Rematch", _ask_rematch, true)
		orow.add_child(_rematch_button)
		col.add_child(orow)
		if reason == "left":
			_rematch_button.disabled = true
		Online.message.connect(_on_online)
		return

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


func _ask_rematch() -> void:
	Online.send({"t": "rematch"})
	_rematch_button.disabled = true
	_rematch_button.text = "Waiting…"
	_note.text = tr("Waiting for %s to say yes. The other player starts next.") % str(opponent.get("name", "Player"))


func _on_online(msg: Dictionary) -> void:
	if not is_inside_tree():
		return
	var them := str(opponent.get("name", "Player"))
	match str(msg.get("t", "")):
		"rematch_offer":
			_note.text = tr("%s wants a rematch!") % them
		"opponent_left":
			_note.text = tr("%s has left.") % them
			_rematch_button.disabled = true
			_rematch_button.text = "Rematch"
		"start":
			_moving_on = true
			var play: Script = load("res://shell/screens/sowing_play_screen.gd")
			app.pop()
			app.replace(play.create_online(msg))


func _exit_tree() -> void:
	if mode == "online" and not _moving_on:
		Online.send({"t": "leave"})
