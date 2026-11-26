extends AppScreen
## A pits-and-seeds game in progress: the opponent's panel on top, the board, your panel
## below, a one-line hint. Modes: "computer" (you are player 0), "pass" (two people, one
## phone; player 1 has the bottom row) and "online" (against a person through the server,
## which checks every move; 45-second turns, set phrases and faces for chat). Your own
## row is always at the bottom. Who moves first takes turns from game to game.

const S := preload("res://games/sowing/sowing_rules.gd")
const Board := preload("res://games/sowing/board/sowing_board_view.gd")
const AI := preload("res://games/sowing/ai/sowing_opponent.gd")
const ResultScreen := preload("res://shell/screens/sowing_result_screen.gd")

const LEVEL_NAMES := {"easy": "Easy", "medium": "Medium", "hard": "Hard"}

var game_id := "kalah"
var mode := "computer"
var level := "medium"
var first := 0  ## Who moves first this game: 0 = you (or player 1), 1 = the other side.
var me := 0  ## Your player number: 0, except online when you are the second to move.
var opponent := {}  ## Online: {name, avatar, colour}
var start_state := {}  ## Online: position sent by the server

var board: Board
var _ai := AI.new()
var _panels: Array = []  ## Per player number: [panel, pill, score label]
var _hint: Label
var _history: Array = []  ## States before each of your moves, for undo.
var _thinking := false
var _finished := false
var _went_again := false  ## The move just shown ended in the mover's store (Kalah).
var _game_id := 0  ## Bumps on restart so a pending computer move is dropped.
var _threads: Array[Thread] = []  ## Computer searches still running (one per pending move).
var _deadline := 0  ## Online: when the current turn runs out (ticks msec)
var _notice_until := 0


static func create(id: String, p_mode: String, p_level: String) -> AppScreen:
	var s: AppScreen = load("res://shell/screens/sowing_play_screen.gd").new()
	s.game_id = id
	s.mode = p_mode
	s.level = p_level
	s.first = Store.take_first(id)
	return s


## An online game, from the server's "start" message.
static func create_online(msg: Dictionary) -> AppScreen:
	var s: AppScreen = load("res://shell/screens/sowing_play_screen.gd").new()
	s.game_id = str(msg.get("game", "kalah"))
	s.mode = "online"
	s.me = 0 if str(msg.get("you", "first")) == "first" else 1
	s.opponent = msg.get("opponent", {})
	s.start_state = msg.get("state", {})
	s._deadline = Time.get_ticks_msec() + int(msg.get("turn_ms", 45000))
	return s


func _ready() -> void:
	var col := page(false, 64, 40)
	var help := Ui.icon_button("help-circle", func() -> void: Games.how_to_play(app, game_id))
	if mode == "online":
		var bar := Ui.hbox(24)
		bar.add_child(Ui.icon_button("arrow-left", _confirm_leave))
		var t := Ui.heading(tr("vs %s") % _them(), 48)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.clip_text = true
		bar.add_child(t)
		bar.add_child(help)
		col.add_child(bar)
	else:
		var title := "Pass and play" if mode == "pass" else tr("vs Computer · %s") % tr(LEVEL_NAMES.get(level, "Medium"))
		col.add_child(top_bar(title, help))
	_panels.resize(2)
	_panels[1 - me] = _player_panel(1 - me)
	col.add_child(_panels[1 - me][0])

	var area := Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.custom_minimum_size.y = 520
	col.add_child(area)
	board = Board.new()
	board.bottom = me
	board.show_hints = Store.setting("hints")
	board.reduce_motion = Store.setting("reduce_motion")
	area.add_child(board)
	area.resized.connect(func() -> void: board.layout(area.size))
	board.changed.connect(_on_changed)
	board.played.connect(_on_played)
	board.before_move.connect(func(s: S.State) -> void:
		if mode == "computer":
			_history.append(s))
	board.human_moved.connect(func(pit: int) -> void:
		if mode == "online":
			Online.send({"t": "move", "m": pit}))

	_panels[me] = _player_panel(me)
	col.add_child(_panels[me][0])

	_hint = Ui.label("", 30, Ui.MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.y = 80
	col.add_child(_hint)

	var row := Ui.hbox(18)
	if mode == "online":
		row.add_child(Ui.button("Chat", _open_chat))
		row.add_child(Ui.button("Resign", _confirm_resign))
		Online.message.connect(_on_online)
	else:
		row.add_child(Ui.button("Restart", _restart))
	if mode == "computer":
		row.add_child(Ui.button("Undo", _undo))
	col.add_child(row)
	if mode == "online":
		board.set_state(S.from_dict(start_state))
	else:
		board.new_game(Games.rules_for(game_id), first)


func _them() -> String:
	return str(opponent.get("name", "Player"))


func _player_name(p: int) -> String:
	if mode == "pass":
		return tr("Player %d") % (p + 1)
	if p == me:
		return tr("You")
	return _them() if mode == "online" else tr("Computer")


func _player_panel(p: int) -> Array:
	var panel := Ui.card(Ui.PANEL, Ui.LINE, 22)
	var row := Ui.hbox(22)
	panel.add_child(row)
	if mode == "computer" and p != me:
		var bot := PanelContainer.new()
		bot.custom_minimum_size = Vector2(84, 84)
		bot.add_theme_stylebox_override("panel", Ui.box(Ui.WARM, Ui.ACCENT_LINE, 42, 3, 0))
		var ic := Ui.icon("robot", 52, Ui.ACCENT)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bot.add_child(ic)
		row.add_child(bot)
	elif mode == "online" and p != me:
		row.add_child(Ui.avatar(str(opponent.get("avatar", "goat")), int(opponent.get("colour", 0)), 84))
	elif mode == "pass":
		row.add_child(Ui.avatar("goat" if p == 0 else "tiger", p, 84))
	else:
		row.add_child(Ui.avatar(Store.avatar(), Store.avatar_colour(), 84))
	var text := Ui.vbox(0)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var name_row := Ui.hbox(14)
	text.add_child(name_row)
	var name := Ui.heading(_player_name(p), 40)
	name_row.add_child(name)
	var pill := Ui.pill("Your turn")
	name_row.add_child(pill)
	text.add_child(Ui.label("Bottom row" if p == me else "Top row", 26, Ui.MUTED))
	var right := Ui.vbox(0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	var score := Ui.heading("0", 52)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(score)
	var cap := Ui.label("seeds won", 24, Ui.MUTED)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(cap)
	row.add_child(right)
	return [panel, pill, score]


func _human_turn() -> bool:
	return mode == "pass" or board.state.turn == me


func _on_played(kind: String) -> void:
	if kind == "again":
		_went_again = true
	Sfx.play(kind)


func _pill_text(p: int) -> String:
	if board.state.over:
		return "Winner"
	match mode:
		"pass":
			return "To move"
		"computer":
			return "Your turn" if p == me else "Thinking…"
	var left := maxi(0, ceili((_deadline - Time.get_ticks_msec()) / 1000.0))
	return (tr("Your turn · %d") if p == me else tr("Their turn · %d")) % left


func _on_changed() -> void:
	var s := board.state
	var res := S.result(s)
	var over := s.over
	for p in 2:
		var parts: Array = _panels[p]
		var active := (not over and s.turn == p) or (res == S.WIN_0 and p == 0) or (res == S.WIN_1 and p == 1)
		(parts[0] as PanelContainer).add_theme_stylebox_override("panel", Ui.box(Ui.PANEL, Ui.ACCENT if active else Ui.LINE, 36, 4 if active else 3, 22))
		(parts[1] as Label).visible = active
		(parts[1] as Label).text = _pill_text(p)
		(parts[2] as Label).text = str(s.stores[p])
	var again := _went_again
	_went_again = false
	board.interactive = not over and _human_turn() and not _finished
	if mode == "online":
		if over:
			_hint.text = "Game over"
		elif Time.get_ticks_msec() >= _notice_until:
			if again:
				_hint.text = "Your last seed landed in your store. Go again!" if s.turn == me else tr("%s goes again.") % _them()
			else:
				_hint.text = "Your move: tap one of your pits" if s.turn == me else tr("Waiting for %s…") % _them()
		return
	if over:
		_hint.text = "Game over"
		_finish(res)
		return
	if not _human_turn():
		if again:
			_hint.text = "The computer's last seed landed in its store, so it goes again."
		elif s.moves_played == 0:
			_hint.text = "The computer starts this game."
		else:
			_hint.text = "The computer is thinking…"
		_computer_move()
		return
	if again:
		_hint.text = "Your last seed landed in your store. Go again!" if mode == "computer" else tr("%s goes again.") % _player_name(s.turn)
	elif mode == "pass":
		_hint.text = tr("%s: tap a pit on the %s row") % [_player_name(s.turn), tr("bottom" if s.turn == 0 else "top")]
	elif s.moves_played == 0:
		_hint.text = "You start this game. Tap one of your pits to sow its seeds."
	else:
		_hint.text = "Tap one of your pits to sow its seeds"


func _computer_move() -> void:
	if _thinking:
		return
	_thinking = true
	board.interactive = false
	var id := _game_id
	await get_tree().create_timer(0.45).timeout  # A short beat so the turn change reads.
	if not is_inside_tree() or _finished or id != _game_id:
		return
	var snapshot := board.state
	var m: int
	if OS.has_feature("web"):
		m = _ai.choose_move(snapshot, level, 700)  # Single-threaded: keep pauses short.
	else:
		# Think on a worker thread so the seeds keep moving smoothly.
		var t := Thread.new()
		_threads.append(t)
		t.start(_ai.choose_move.bind(snapshot, level))
		while t.is_alive():
			await get_tree().process_frame
		m = t.wait_to_finish()
		_threads.erase(t)
	if not is_inside_tree() or _finished or id != _game_id:
		return
	_thinking = false
	board.play_move(m)


func _restart() -> void:
	_game_id += 1
	_history.clear()
	_finished = false
	_thinking = false
	_ai = AI.new()  # A search still running from the last game keeps its own copy.
	first = Store.take_first(game_id)
	board.new_game(Games.rules_for(game_id), first)


## Takes back your last move and everything the computer did after it.
func _undo() -> void:
	if _thinking or _history.is_empty() or _finished:
		return
	board.set_state(_history.pop_back())


func _finish(res: int) -> void:
	if _finished:
		return
	_finished = true
	board.interactive = false
	var outcome := "draw"
	if res == S.WIN_0:
		outcome = "win"
	elif res == S.WIN_1:
		outcome = "loss"
	Store.record_result(game_id, mode, level, outcome)
	app.push.call_deferred(ResultScreen.create(board.state, game_id, mode, level))


# ---------- Online ----------

func _process(_delta: float) -> void:
	if mode != "online" or _finished or board == null or board.state == null:
		return
	var s := board.state
	if not s.over:
		(_panels[s.turn][1] as Label).text = _pill_text(s.turn)
	if _notice_until != 0 and Time.get_ticks_msec() >= _notice_until:
		_notice_until = 0
		_on_changed()


func _notice(text: String) -> void:
	_hint.text = text
	_notice_until = Time.get_ticks_msec() + 3500


func _my_side() -> String:
	return "first" if me == 0 else "second"


func _on_online(msg: Dictionary) -> void:
	if not is_inside_tree() or _finished:
		return
	match str(msg.get("t", "")):
		"moved":
			var server := S.from_dict(msg.get("state", {}))
			if str(msg.get("by", "")) != _my_side():
				board.play_move(int(msg.get("m", -1)))
			if S.to_dict(board.state) != S.to_dict(server):
				board.set_state(server)
			_deadline = Time.get_ticks_msec() + int(msg.get("turn_ms", 45000))
		"sync":
			board.set_state(S.from_dict(msg.get("state", {})))
			_deadline = Time.get_ticks_msec() + int(msg.get("turn_ms", 45000))
		"timeout":
			if str(msg.get("side", "")) == _my_side():
				_notice("Time ran out, so a move was played for you. Next time the game is lost.")
			else:
				_notice(tr("%s ran out of time. A move was played for them.") % _them())
		"chat":
			if not bool(Store.data["online"]["muted"]):
				_bubble(false, int(msg.get("id", -1)))
		"opponent_away":
			_notice(tr("%s lost connection. Waiting up to a minute for them…") % _them())
			_notice_until = Time.get_ticks_msec() + 60000
		"opponent_back":
			_notice(tr("%s is back.") % _them())
		"end":
			_finish_online(msg)


func _finish_online(msg: Dictionary) -> void:
	_finished = true
	board.interactive = false
	var final_state := S.from_dict(msg.get("state", {}))
	if S.to_dict(board.state) != S.to_dict(final_state):
		board.set_state(final_state)
	var winner := str(msg.get("winner", ""))
	var outcome := "draw" if winner == "draw" else ("win" if winner == _my_side() else "loss")
	Store.record_result(game_id, "online", "", outcome)
	if board.busy:
		await board.changed  # Let the last seeds land before the result pops up.
	if not is_inside_tree():
		return
	var r: AppScreen = ResultScreen.create(final_state, game_id, "online", "")
	r.set("me", me)
	r.set("opponent", opponent)
	r.set("winner", winner)
	r.set("reason", str(msg.get("reason", "")))
	app.push.call_deferred(r)


func _confirm_leave() -> void:
	if _finished:
		app.pop()
		return
	Modal.show(app, "Leave this game?", [Modal.text("Leaving counts as a loss, and your opponent wins.")], [
		["Stay", func() -> void: pass, true],
		["Leave", func() -> void:
			Online.send({"t": "leave"})
			_finished = true
			app.pop()],
	])


func _confirm_resign() -> void:
	Modal.show(app, "Resign?", [Modal.text(tr("%s wins this game.") % _them())], [
		["Keep playing", func() -> void: pass, true],
		["Resign", func() -> void: Online.send({"t": "resign"})],
	])


func _open_chat() -> void:
	OnlineChat.open_picker(app, _them(), func(id: int) -> void:
		Online.send({"t": "chat", "id": id})
		_bubble(true, id))


func _bubble(mine: bool, id: int) -> void:
	OnlineChat.bubble(self, _panels[me if mine else 1 - me][0], mine, id)


func _exit_tree() -> void:
	for t in _threads:
		if t.is_started():
			t.wait_to_finish()
	if mode == "online" and not _finished:
		Online.send({"t": "leave"})
