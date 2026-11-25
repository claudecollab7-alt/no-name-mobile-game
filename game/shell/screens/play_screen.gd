extends AppScreen
## The game itself: a panel per side with its goal, the board, a one-line hint (D43).
## Modes: "computer" (human plays `human_side` against the interim opponent at `level`)
## or "pass" (two people, one phone).

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const BoardView := preload("res://games/aadupuli/board/board_view.gd")
const Opponent := preload("res://games/aadupuli/ai/opponent.gd")
const ResultScreen := preload("res://shell/screens/result_screen.gd")

const LEVEL_NAMES := {"easy": "Easy", "medium": "Medium", "hard": "Hard"}

var mode := "pass"
var level := "medium"
var human_side := "goats"
var tossed := false

var board: BoardView
var _opponent := Opponent.new()
var _tiger_chip: PanelContainer
var _goat_chip: PanelContainer
var _tiger_pill: Label
var _goat_pill: Label
var _dots: CaptureDots
var _hand_count: Label
var _hand_caption: Label
var _hint: Label
var _history: Array = []  ## States before each human move, for undo.
var _thinking := false
var _finished := false
var _game_id := 0  ## Bumps on restart so a pending computer move is dropped.


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


static func create(p_mode: String, p_level: String, p_side: String, p_tossed := false) -> AppScreen:
	var s: AppScreen = load("res://shell/screens/play_screen.gd").new()
	s.mode = p_mode
	s.level = p_level
	s.human_side = p_side
	s.tossed = p_tossed
	return s


func _ready() -> void:
	var col := page(false, 64, 40)
	var title := "Pass and play" if mode == "pass" else tr("vs Computer · %s") % tr(LEVEL_NAMES.get(level, "Medium"))
	col.add_child(top_bar(title, Ui.icon_button("help-circle", func() -> void: Modal.how_to_play(app))))

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
	board.before_move.connect(func(s: R.State) -> void:
		if mode == "computer":
			_history.append(s))

	var gparts := _player_chip(false)
	_goat_chip = gparts[0]
	_goat_pill = gparts[1]
	var gright := Ui.vbox(0)
	gright.alignment = BoxContainer.ALIGNMENT_CENTER
	_hand_count = Ui.heading("15", 52)
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
	row.add_child(Ui.button("Restart", _restart))
	if mode == "computer":
		row.add_child(Ui.button("Undo", _undo))
	col.add_child(row)
	board.new_game()
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
	text.add_child(Ui.label("Capture 5 goats to win" if is_tiger else "Trap all 3 tigers to win", 26, Ui.MUTED))
	return [panel, pill, row]


func _side_name(is_tiger: bool) -> String:
	var base := "Tigers" if is_tiger else "Goats"
	if mode != "computer":
		return base
	var mine := (human_side == "tigers") == is_tiger
	return tr("You · %s") % tr(base) if mine else tr("Computer · %s") % tr(base)


func _human_turn() -> bool:
	if mode != "computer":
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
	var pill_text := "Winner" if over else ("Your turn" if _human_turn() else "Thinking…")
	_tiger_pill.text = pill_text
	_goat_pill.text = pill_text
	_dots.count = s.captured
	if s.in_hand > 0:
		_hand_count.text = str(s.in_hand)
		_hand_caption.text = "to place"
	else:
		_hand_count.text = str(R.goats_on_board(s))
		_hand_caption.text = "on the hill"
	if over:
		_hint.text = "The tigers caught 5 goats." if res == R.TIGERS_WIN and s.captured >= s.capture_target else (
			"The tigers are trapped." if res == R.GOATS_WIN else "The goats have no move left.")
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
	var m := _opponent.choose_move(board.state, level)
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
	board.new_game()


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
	Store.record_game(mode, human_side, level, human_won)
	var final_state := board.state
	await get_tree().create_timer(1.1).timeout
	if is_inside_tree():
		app.replace(ResultScreen.create(final_state, mode, level, human_side, tigers_won))
