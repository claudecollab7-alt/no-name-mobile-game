extends AppScreen
## The game itself: a panel per side with its goal, the board, a one-line hint (D43).
## Modes: "computer" (human plays `human_side` against the interim opponent at `level`),
## "pass" (two people, one phone) or "online" (against a person, through the server,
## which checks every move; 45-second turns, set phrases and faces for chat).

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const BoardView := preload("res://games/aadupuli/board/board_view.gd")
const Opponent := preload("res://games/aadupuli/ai/opponent.gd")
const ResultScreen := preload("res://shell/screens/result_screen.gd")

const LEVEL_NAMES := {"easy": "Easy", "medium": "Medium", "hard": "Hard"}

var mode := "pass"
var level := "medium"
var human_side := "goats"
var tossed := false
var board_id := "aadupuli"  ## Which tiger game: "aadupuli" (Tiger & Goat) or "baghchal"

var board: BoardView
var _opponent := Opponent.new()
var _tiger_chip: PanelContainer
var _goat_chip: PanelContainer
var _tiger_pill: Label
var _tiger_goal: Label
var _goat_pill: Label
var _dots: CaptureDots
var _hand_count: Label
var _hand_caption: Label
var _hint: Label
var _history: Array = []  ## States before each human move, for undo.
var _thinking := false
var _finished := false
var _game_id := 0  ## Bumps on restart so a pending computer move is dropped.
var _thread: Thread
var opponent := {}  ## Online: {name, avatar, colour}
var start_state := {}  ## Online: position sent by the server
var _deadline := 0  ## Online: when the current turn runs out (ticks msec)
var _notice_until := 0


## Five slots filling with fleeces as the tigers capture goats.
class CaptureDots extends Control:
	var count := 0:
		set(value):
			count = value
			queue_redraw()

	func _draw() -> void:
		var s := size.y * 0.62
		var gap := s * 0.32
		var x := size.x - (5 * s + 4 * gap)
		for i in 5:
			var c := Vector2(x + i * (s + gap) + s / 2.0, size.y / 2.0)
			if i < count:
				draw_circle(c, s * 0.5, Color("#B9AE99"), true, -1.0, true)
				draw_circle(c, s * 0.42, Color("#FFFFFF"), true, -1.0, true)
				draw_circle(c + Vector2(0, s * 0.04), s * 0.17, Color("#5A4C40"), true, -1.0, true)
			else:
				draw_arc(c, s * 0.44, 0.0, TAU, 32, Color("#C8D6B4"), s * 0.1, true)


## An online game, from the server's "start" message.
static func create_online(msg: Dictionary) -> AppScreen:
	var s: AppScreen = load("res://shell/screens/play_screen.gd").new()
	s.mode = "online"
	s.human_side = str(msg.get("you", "goats"))
	s.opponent = msg.get("opponent", {})
	s.start_state = msg.get("state", {})
	s.board_id = str(s.start_state.get("board", "aadupuli"))
	s._deadline = Time.get_ticks_msec() + int(msg.get("turn_ms", 45000))
	return s


static func create(p_mode: String, p_level: String, p_side: String, p_tossed := false, p_board := "aadupuli") -> AppScreen:
	var s: AppScreen = load("res://shell/screens/play_screen.gd").new()
	s.board_id = p_board
	s.mode = p_mode
	s.level = p_level
	s.human_side = p_side
	s.tossed = p_tossed
	return s


func _ready() -> void:
	var col := page(false, 64, 40)
	var title := "Pass and play" if mode == "pass" else tr("vs Computer · %s") % tr(LEVEL_NAMES.get(level, "Medium"))
	if mode == "online":
		title = tr("vs %s") % str(opponent.get("name", "Player"))
		var bar := Ui.hbox(24)
		bar.add_child(Ui.icon_button("arrow-left", _confirm_leave))
		var t := Ui.heading(title, 48)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.clip_text = true
		bar.add_child(t)
		bar.add_child(Ui.icon_button("help-circle", func() -> void: Modal.how_to_play(app, board_id)))
		col.add_child(bar)
	else:
		col.add_child(top_bar(title, Ui.icon_button("help-circle", func() -> void: Modal.how_to_play(app, board_id))))

	var tparts := _player_chip(true)
	_tiger_chip = tparts[0]
	_tiger_pill = tparts[1]
	var tright := Ui.vbox(2)
	tright.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots = CaptureDots.new()
	_dots.custom_minimum_size = Vector2(300, 54)
	tright.add_child(_dots)
	var caught := Ui.label("Captured", 24, Ui.MUTED)
	caught.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tright.add_child(caught)
	tparts[2].add_child(tright)
	col.add_child(_tiger_chip)

	var area := Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.custom_minimum_size.y = 520
	col.add_child(area)
	board = BoardView.new()
	board.show_hints = Store.setting("hints")
	board.reduce_motion = Store.setting("reduce_motion")
	area.add_child(board)
	area.resized.connect(func() -> void: board.layout(area.size))
	board.changed.connect(_on_changed)
	board.played.connect(func(kind: String) -> void: Sfx.play(kind))
	board.no_moves.connect(func(_p: int) -> void:
		_hint.text = "That piece has nowhere to go right now. Try another.")
	board.before_move.connect(func(s: R.State) -> void:
		if mode == "computer":
			_history.append(s))
	board.human_moved.connect(func(m: int) -> void:
		if mode == "online":
			Online.send({"t": "move", "m": m}))

	var gparts := _player_chip(false)
	_goat_chip = gparts[0]
	_goat_pill = gparts[1]
	var gright := Ui.vbox(0)
	gright.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_count = Ui.heading(str(R.BOARDS[board_id]["goat_count"]), 52)
	_hand_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gright.add_child(_hand_count)
	_hand_caption = Ui.label("to place", 24, Ui.MUTED)
	_hand_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gright.add_child(_hand_caption)
	gparts[2].add_child(gright)
	col.add_child(_goat_chip)

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
		board.set_state(R.from_dict(start_state))
	else:
		board.new_game({"board": board_id})
	if tossed:
		_hint.text = tr("Coin toss: you play the %s") % tr(human_side)


func _player_chip(is_tiger: bool) -> Array:
	var panel := Ui.card(Ui.PANEL, Ui.LINE, 22)
	var row := Ui.hbox(22)
	panel.add_child(row)
	row.add_child(Ui.token(is_tiger, 36))
	var text := Ui.vbox(0)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var name_row := Ui.hbox(14)
	text.add_child(name_row)
	name_row.add_child(Ui.heading(_side_name(is_tiger), 40))
	var pill := Ui.pill("Your turn")
	name_row.add_child(pill)
	var tigers: int = R.BOARDS[board_id]["start_tigers"].size()
	var goal := Ui.label("Capture 5 goats to win" if is_tiger else tr("Trap all %d tigers to win") % tigers, 26, Ui.MUTED)
	text.add_child(goal)
	if is_tiger:
		_tiger_goal = goal
	return [panel, pill, row]


func _side_name(is_tiger: bool) -> String:
	var base := "Tigers" if is_tiger else "Goats"
	if mode != "computer":
		return base
	var mine := (human_side == "tigers") == is_tiger
	if mine:
		return tr("You · %s") % tr(base)
	if mode == "online":
		return "%s · %s" % [str(opponent.get("name", "Player")), tr(base)]
	return tr("Computer · %s") % tr(base)


func _human_turn() -> bool:
	if mode == "pass":
		return true
	return (board.state.turn == R.TIGER) == (human_side == "tigers")


func _on_changed() -> void:
	var s := board.state
	var res := R.result(s)
	var over := res != R.ONGOING
	var tiger_active := (not over and s.turn == R.TIGER) or res == R.TIGERS_WIN
	var goat_active := (not over and s.turn == R.GOAT) or res == R.GOATS_WIN
	_tiger_chip.add_theme_stylebox_override("panel", Ui.box(Ui.PANEL, Ui.ACCENT if tiger_active else Ui.LINE, 36, 4 if tiger_active else 3, 22))
	_goat_chip.add_theme_stylebox_override("panel", Ui.box(Ui.PANEL, Ui.ACCENT if goat_active else Ui.LINE, 36, 4 if goat_active else 3, 22))
	_tiger_pill.visible = tiger_active
	_goat_pill.visible = goat_active
	var pill_text := "Winner" if over else ("Your turn" if _human_turn() else ("Their turn" if mode == "online" else "Thinking…"))
	_tiger_pill.text = pill_text
	_goat_pill.text = pill_text
	_dots.count = s.captured
	var left := R.quiet_left(s)
	if left >= 0 and not over:
		_tiger_goal.text = tr("Capture 5 goats · %d moves left") % left
		_tiger_goal.add_theme_color_override("font_color", Ui.ACCENT if left <= 10 else Ui.MUTED)
	else:
		_tiger_goal.text = "Capture 5 goats to win"
		_tiger_goal.add_theme_color_override("font_color", Ui.MUTED)
	if s.in_hand > 0:
		_hand_count.text = str(s.in_hand)
		_hand_caption.text = "to place"
	else:
		_hand_count.text = str(R.goats_on_board(s))
		_hand_caption.text = "on the hill" if board_id == "aadupuli" else "on the board"
	if mode == "online":
		board.interactive = not over and _human_turn()
		if over:
			_hint.text = "Game over"
			return
		if Time.get_ticks_msec() >= _notice_until:
			_hint.text = "Your move" if _human_turn() else tr("Waiting for %s…") % str(opponent.get("name", "Player"))
		return
	if over:
		_hint.text = "The tigers caught 5 goats." if res == R.TIGERS_WIN and s.captured >= s.capture_target else (
			"The goats held the hill." if R.held(s) else ("The tigers are trapped." if res == R.GOATS_WIN else "The goats have no move left."))
		_finish(res)
		return
	if not _human_turn():
		_hint.text = "The computer is thinking…"
		_computer_move()
		return
	if tossed and s.moves_played == 0:
		return
	if s.turn == R.GOAT and s.in_hand > 0:
		_hint.text = "Tap a glowing point to place a goat"
	elif s.turn == R.GOAT:
		_hint.text = "Tap a goat, then where it should go"
	else:
		_hint.text = "Tap a tiger, then where it should go. Jump a goat to capture it."


func _computer_move() -> void:
	if _thinking:
		return
	_thinking = true
	board.interactive = false
	var id := _game_id
	await get_tree().create_timer(0.35).timeout  # Let the last move finish animating.
	if not is_inside_tree() or _finished or id != _game_id:
		return
	var snapshot := board.state
	var m: int
	if OS.has_feature("web"):
		m = _opponent.choose_move(snapshot, level, 700)  # Single-threaded: keep pauses short.
	else:
		# Think on a worker thread so the screen keeps animating.
		_thread = Thread.new()
		_thread.start(_opponent.choose_move.bind(snapshot, level))
		while _thread.is_alive():
			await get_tree().process_frame
		m = _thread.wait_to_finish()
		_thread = null
	if not is_inside_tree() or _finished or id != _game_id:
		return
	_thinking = false
	board.play_move(m)
	if not _finished:
		board.interactive = true
		board.refresh_targets()


func _restart() -> void:
	_game_id += 1
	_history.clear()
	_finished = false
	_thinking = false
	board.interactive = true
	board.new_game({"board": board_id})


## Takes back the human's last move and the computer's reply.
func _undo() -> void:
	if _thinking or _history.is_empty():
		return
	board.interactive = true
	board.set_state(_history.pop_back())


func _finish(res: int) -> void:
	if _finished:
		return
	_finished = true
	board.interactive = false
	var tigers_won := res == R.TIGERS_WIN
	var human_won := (human_side == "tigers") == tigers_won
	if board_id == "aadupuli":
		Store.record_game(mode, human_side, level, human_won)
	else:
		Store.record_tiger_game(board_id, mode, human_side, level, human_won)
	var final_state := board.state
	_hint.text = "Game over"
	# Show the popup straight away; it waits a moment before fading in, so the last
	# move can finish animating. No timer to depend on.
	app.push.call_deferred(ResultScreen.create(final_state, mode, level, human_side, tigers_won))



# ---------- Online ----------

func _process(_delta: float) -> void:
	if mode != "online" or _finished or board == null or board.state == null:
		return
	var left := maxi(0, ceili((_deadline - Time.get_ticks_msec()) / 1000.0))
	var text := (tr("Your turn · %d") if _human_turn() else tr("Their turn · %d")) % left
	_tiger_pill.text = text
	_goat_pill.text = text
	if _notice_until != 0 and Time.get_ticks_msec() >= _notice_until:
		_notice_until = 0
		_on_changed()


func _notice(text: String) -> void:
	_hint.text = text
	_notice_until = Time.get_ticks_msec() + 3500


func _on_online(msg: Dictionary) -> void:
	if not is_inside_tree() or _finished:
		return
	var them := str(opponent.get("name", "Player"))
	match str(msg.get("t", "")):
		"moved":
			var server := R.from_dict(msg.get("state", {}))
			if str(msg.get("by", "")) != human_side:
				board.play_move(int(msg.get("m", -1)))
			if R.position_key(board.state) != R.position_key(server) or board.state.moves_played != server.moves_played:
				board.set_state(server)
			else:
				board.state.counts = server.counts
			_deadline = Time.get_ticks_msec() + int(msg.get("turn_ms", 45000))
			_on_changed()
		"sync":
			board.set_state(R.from_dict(msg.get("state", {})))
			_deadline = Time.get_ticks_msec() + int(msg.get("turn_ms", 45000))
		"timeout":
			if str(msg.get("side", "")) == human_side:
				_notice("Time ran out, so a move was played for you. Next time the game is lost.")
			else:
				_notice(tr("%s ran out of time. A move was played for them.") % them)
		"chat":
			if not bool(Store.data["online"]["muted"]):
				_bubble(false, int(msg.get("id", -1)))
		"opponent_away":
			_notice(tr("%s lost connection. Waiting up to a minute for them…") % them)
			_notice_until = Time.get_ticks_msec() + 60000
		"opponent_back":
			_notice(tr("%s is back.") % them)
		"end":
			_finish_online(msg)


func _finish_online(msg: Dictionary) -> void:
	_finished = true
	board.interactive = false
	var final_state := R.from_dict(msg.get("state", {}))
	board.set_state(final_state)
	var tigers_won := str(msg.get("winner", "")) == "tigers"
	var human_won := (human_side == "tigers") == tigers_won
	if board_id == "aadupuli":
		Store.record_game("online", human_side, "", human_won)
	else:
		Store.record_tiger_game(board_id, "online", human_side, "", human_won)
	var r: AppScreen = ResultScreen.create(final_state, "online", "", human_side, tigers_won)
	r.set("opponent", opponent)
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
	Modal.show(app, "Resign?", [Modal.text(tr("%s wins this game.") % str(opponent.get("name", "Player")))], [
		["Keep playing", func() -> void: pass, true],
		["Resign", func() -> void: Online.send({"t": "resign"})],
	])


func _open_chat() -> void:
	OnlineChat.open_picker(app, str(opponent.get("name", "Player")), func(id: int) -> void:
		Online.send({"t": "chat", "id": id})
		_bubble(true, id))


## A speech bubble next to a player's panel for a few seconds.
func _bubble(mine: bool, id: int) -> void:
	var my_panel := _tiger_chip if human_side == "tigers" else _goat_chip
	var their_panel := _goat_chip if human_side == "tigers" else _tiger_chip
	OnlineChat.bubble(self, my_panel if mine else their_panel, mine, id)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	if mode == "online" and not _finished:
		Online.send({"t": "leave"})
