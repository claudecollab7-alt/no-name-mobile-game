extends AppScreen
## One Reversi puzzle (BUILD_PLAN.md G5.7). You play the side to move. In "make them
## pass" one move does it. In "win the ending" you play on to the end of the game while
## the computer defends as well as it can; passes happen by themselves. A move that
## gives the win away (or doesn't make them pass) is explained, and the position resets;
## each reset counts as a try. "Show answer" rings the right square (a revealed puzzle
## still counts as solved). Solved puzzles are remembered, and Next puzzle goes to the
## next unsolved one, easiest first.

const R := preload("res://games/reversi/reversi_rules.gd")
const Board := preload("res://games/reversi/board/reversi_board_view.gd")

var puzzle := {}
var game_id := "reversi"
var board: Board
var tries := 1
var revealed := false
var _mover := 0  ## The side you play: 0 orange, 1 cream.
var _before: R.State  ## The position just before your latest move.
var _at_start := true  ## Your latest move was the puzzle's first.
var _busy := false
var _tries_label: Label
var _feedback: Label
var _end_card: PanelContainer
var _end_title: Label
var _end_text: Label
var _end_row: HBoxContainer
var _answer_button: Button
var _round := 0  ## Bumps on reset so a pending reply is dropped.


static func create(p_puzzle: Dictionary) -> AppScreen:
	var s: AppScreen = load("res://shell/screens/reversi_puzzle_screen.gd").new()
	s.puzzle = p_puzzle
	return s


func _ready() -> void:
	_mover = int(puzzle["turn"])
	var col := page(false, 64, 40)
	_tries_label = Ui.label("", 26, Ui.MUTED, "bold")
	col.add_child(top_bar(tr("%s puzzle %d") % [tr(Games.title(game_id)), int(puzzle["id"])], _tries_label))

	var card := Ui.card(Ui.CARD, Ui.LINE, 26)
	var row := Ui.hbox(20)
	var disc := PanelContainer.new()  # The colour you play.
	disc.custom_minimum_size = Vector2(64, 64)
	disc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var tones: Array = Board.DISCS[_mover]
	disc.add_theme_stylebox_override("panel", Ui.box(tones[0], tones[1], 32, 5, 0))
	row.add_child(disc)
	var words := Ui.vbox(8)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var goal := Ui.label(ReversiPuzzles.goal_text(puzzle), 32, Ui.INK, "bold")
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(goal)
	words.add_child(Ui.label("You play orange" if _mover == 0 else "You play cream", 24, Ui.MUTED))
	words.add_child(_difficulty(int(puzzle["difficulty"])))
	row.add_child(words)
	card.add_child(row)
	col.add_child(card)

	var area := Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.custom_minimum_size.y = 560
	col.add_child(area)
	board = Board.new()
	board.reduce_motion = Store.setting("reduce_motion")
	board.show_hints = Store.setting("hints")
	area.add_child(board)
	area.resized.connect(func() -> void: board.layout(area.size))
	board.played.connect(func(kind: String) -> void:
		if kind == "place":
			Sfx.play("place")
		elif kind == "flip":
			Sfx.play("move")
		elif kind == "nope":
			Sfx.play("nope"))
	board.before_move.connect(func(s: R.State) -> void: _before = s)
	board.human_moved.connect(_on_move)

	_feedback = Ui.label("", 30, Ui.MUTED)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.custom_minimum_size.y = 84
	col.add_child(_feedback)

	var buttons := Ui.hbox(18)
	buttons.add_child(Ui.button("Start over", _reset))
	_answer_button = Ui.button("Show answer", _reveal)
	buttons.add_child(_answer_button)
	col.add_child(buttons)

	_end_card = Ui.card(Ui.WARM, Ui.ACCENT_LINE, 30)
	var ev := Ui.vbox(14)
	_end_title = Ui.heading("", 48)
	ev.add_child(_end_title)
	_end_text = Ui.muted("", 28)
	ev.add_child(_end_text)
	_end_row = Ui.hbox(16)
	ev.add_child(_end_row)
	_end_card.add_child(ev)
	_end_card.visible = false
	col.add_child(_end_card)
	_reset()


func _difficulty(level: int) -> HBoxContainer:
	var row := Ui.hbox(8)
	for i in 5:
		var d := PanelContainer.new()
		d.custom_minimum_size = Vector2(26, 26)
		d.add_theme_stylebox_override("panel", Ui.box(Ui.ACCENT if i < level else Ui.SOFT, Color(0, 0, 0, 0), 13, 0, 0))
		row.add_child(d)
	row.add_child(Ui.label(["", "Gentle", "Easy", "Medium", "Tricky", "Hard"][clampi(level, 1, 5)], 24, Ui.MUTED))
	return row


func _reset() -> void:
	if _end_card.visible:
		return
	_round += 1
	_busy = false
	_at_start = true
	board.interactive = true
	board.focus_points = PackedInt32Array()
	board.set_state(ReversiPuzzles.position(puzzle))
	if revealed:
		board.focus_points = PackedInt32Array([int(puzzle["answer"])])
	_tries_label.text = tr("Try %d") % tries
	_feedback.text = "Your move"


func _on_move(sq: int) -> void:
	if _busy or _end_card.visible:
		return
	var after := board.state
	board.focus_points = PackedInt32Array()
	# The first move is the proven answer; later ones are checked by searching to the end.
	var good := sq == int(puzzle["answer"]) if _at_start else ReversiPuzzles.is_good(puzzle, _before, sq)
	_at_start = false
	if not good:
		_wrong()
		return
	if ReversiPuzzles.is_solved(puzzle, after, _mover):
		_solved()  # The card fades in while the discs finish turning.
		return
	_busy = true
	board.interactive = false
	_feedback.text = "Good. Now the computer answers…"
	var round_id := _round
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree() or round_id != _round:
		return
	# The computer defends, and anyone without a move passes, until it's your move again
	# or the game is over.
	while R.result(board.state) == R.ONGOING:
		await _settle()
		if not is_inside_tree() or round_id != _round:
			return
		var s := board.state
		if s.turn == _mover:
			if R.legal_moves(s)[0] != R.PASS:
				break
			_feedback.text = "You have no move, so you pass."
			await get_tree().create_timer(1.0).timeout
			if not is_inside_tree() or round_id != _round:
				return
			board.play_move(R.PASS)
		else:
			var reply := ReversiPuzzles.defence(s)
			if reply == R.PASS:
				_feedback.text = "They have no move, so they pass."
				await get_tree().create_timer(1.0).timeout
				if not is_inside_tree() or round_id != _round:
					return
			board.play_move(reply)
	await _settle()
	if not is_inside_tree() or round_id != _round:
		return
	if R.result(board.state) != R.ONGOING:
		_solved()  # Every move you made kept the win, so the ending is yours.
		return
	_busy = false
	board.interactive = true
	if revealed:
		var hint := ReversiPuzzles.good_moves(puzzle, board.state)
		if not hint.is_empty():
			board.focus_points = PackedInt32Array([hint[0]])
	_feedback.text = tr("Your move · %d squares left") % ReversiPuzzles.empties(board.state)


func _settle() -> void:
	while board.busy and is_inside_tree():
		await get_tree().process_frame


## Says why the move fails, then resets for another try.
func _wrong() -> void:
	Sfx.play("nope")
	_busy = true
	board.interactive = false
	var round_id := _round
	if str(puzzle["goal"]) == "pass":
		_feedback.text = "Not quite: they can still play."
	else:
		_feedback.text = "Not quite: with their best replies, that no longer wins."
	await get_tree().create_timer(2.0).timeout
	if not is_inside_tree() or round_id != _round:
		return
	tries += 1
	_reset()


func _reveal() -> void:
	revealed = true
	_answer_button.disabled = true
	_reset()
	_feedback.text = "The right move is the ringed square."


func _solved() -> void:
	board.interactive = false
	_busy = true
	Sfx.vibrate(40)
	Sfx.play("solved")
	var s := board.state
	_feedback.text = "" if str(puzzle["goal"]) == "pass" else tr("Orange %d, cream %d.") % [R.discs(s, 0), R.discs(s, 1)]
	Store.solve_puzzle(game_id, int(puzzle["id"]))
	_end_title.text = "Solved!" if not revealed else "Solved with a hint"
	_end_text.text = tr("First try!") if tries == 1 else tr("Solved in %d tries.") % tries
	for c in _end_row.get_children():
		c.queue_free()
	var next := Store.next_puzzle(game_id, int(puzzle["id"]))
	_end_row.add_child(Ui.button("Next puzzle", func() -> void: app.replace(create(next)), false, 104))
	_end_row.add_child(Ui.button("Done", func() -> void: app.pop(), true, 104))
	_end_card.visible = true
	_end_card.modulate.a = 0.0
	create_tween().tween_property(_end_card, "modulate:a", 1.0, 0.25).set_delay(0.3)
