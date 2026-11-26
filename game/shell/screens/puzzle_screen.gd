extends AppScreen
## One puzzle (BUILD_PLAN.md task 4.3). The player makes the moves for the goal's side;
## the computer answers with its toughest defence. A wrong move is explained and the
## position resets; each reset counts as a try. "Show answer" rings the right first move
## (a revealed puzzle still counts as solved, but not for the streak).

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const BoardView := preload("res://games/aadupuli/board/board_view.gd")

var puzzle := {}
var day := 0  ## Daily puzzle number, or 0 for practice.
var board: BoardView
var tries := 1
var revealed := false
var _moves_left := 1
var _before: R.State
var _busy := false
var _tries_label: Label
var _feedback: Label
var _end_card: PanelContainer
var _end_title: Label
var _end_text: Label
var _end_row: HBoxContainer
var _answer_button: Button


static func create(p_puzzle: Dictionary, p_day := 0) -> AppScreen:
	var s: AppScreen = load("res://shell/screens/puzzle_screen.gd").new()
	s.puzzle = p_puzzle
	s.day = p_day
	return s


func _ready() -> void:
	var col := page(false, 64, 40)
	var title := tr("Daily puzzle #%d") % day if day > 0 else tr("Puzzle %d") % int(puzzle["id"])
	_tries_label = Ui.label("", 26, Ui.MUTED, "bold")
	col.add_child(top_bar(title, _tries_label))

	var card := Ui.card(Ui.CARD, Ui.LINE, 26)
	var row := Ui.hbox(20)
	row.add_child(Ui.token(int(puzzle["turn"]) == R.TIGER, 34))
	var words := Ui.vbox(8)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var goal := Ui.label(AadupuliPuzzles.goal_text(puzzle), 32, Ui.INK, "bold")
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(goal)
	words.add_child(_difficulty(int(puzzle["difficulty"])))
	row.add_child(words)
	card.add_child(row)
	col.add_child(card)

	var area := Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.custom_minimum_size.y = 560
	col.add_child(area)
	board = BoardView.new()
	board.reduce_motion = Store.setting("reduce_motion")
	board.show_hints = Store.setting("hints")
	area.add_child(board)
	area.resized.connect(func() -> void: board.layout(area.size))
	board.played.connect(func(kind: String) -> void: Sfx.play(kind))
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
	var l := Ui.label(["", "Gentle", "Easy", "Medium", "Tricky", "Hard"][clampi(level, 1, 5)], 24, Ui.MUTED)
	row.add_child(l)
	return row


func _reset() -> void:
	if _end_card.visible:
		return
	_moves_left = int(puzzle["n"])
	_busy = false
	board.interactive = true
	board.focus_points = PackedInt32Array()
	board.set_state(AadupuliPuzzles.position(puzzle))
	if revealed:
		_ring_answer()
	_tries_label.text = tr("Try %d") % tries
	_feedback.text = "Your move"


func _on_move(m: int) -> void:
	if _busy or _end_card.visible:
		return
	var before := _before
	var after := board.state
	board.focus_points = PackedInt32Array()
	var good := AadupuliPuzzles.winning_moves(puzzle, before, _moves_left)
	if not good.has(m):
		_wrong(after)
		return
	if AadupuliPuzzles.is_solved(puzzle, before, after):
		_solved()
		return
	_moves_left -= 1
	_busy = true
	board.interactive = false
	_feedback.text = "Good. Now the computer answers…"
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return
	var reply := AadupuliPuzzles.toughest_reply(puzzle, board.state, _moves_left)
	if reply >= 0:
		board.play_move(reply)
	_busy = false
	board.interactive = true
	board.refresh_targets()
	_feedback.text = tr("Your move · %d left") % _moves_left if _moves_left > 1 else "Your move · last one"


## Shows why the move fails, then resets for another try.
func _wrong(after: R.State) -> void:
	Sfx.play("nope")
	_busy = true
	board.interactive = false
	match str(puzzle["goal"]):
		"safe":
			_feedback.text = "Not quite: a tiger can now jump a goat."
			for m in R.legal_moves(after):
				if R.move_over(m) != R.NONE:
					await get_tree().create_timer(0.5).timeout
					if is_inside_tree():
						board.play_move(m)
					break
		"capture":
			_feedback.text = "Not quite: the goats can now defend everything."
		"trap":
			_feedback.text = "Not quite: a tiger can still slip away."
	await get_tree().create_timer(1.6).timeout
	if not is_inside_tree():
		return
	tries += 1
	_reset()


func _reveal() -> void:
	revealed = true
	_answer_button.disabled = true
	_reset()
	_feedback.text = "The right first move is ringed in orange."


func _ring_answer() -> void:
	var a := int(puzzle["answer"])
	var pts := PackedInt32Array([R.move_to(a)])
	if R.move_from(a) != R.NONE:
		pts.insert(0, R.move_from(a))
	board.focus_points = pts


func _solved() -> void:
	board.interactive = false
	_busy = true
	Sfx.vibrate(40)
	Sfx.play("solved")
	_feedback.text = ""
	var counts_for_streak := day > 0 and not revealed
	if counts_for_streak:
		Daily.record(day, tries)
	_end_title.text = "Solved!" if not revealed else "Solved with a hint"
	var how := tr("First try!") if tries == 1 else tr("Solved in %d tries.") % tries
	if day > 0:
		_end_text.text = how + "  " + (tr("%d-day streak.") % Daily.streak() if counts_for_streak else tr("Hints don't count towards your streak."))
	else:
		_end_text.text = how
	for c in _end_row.get_children():
		c.queue_free()
	if counts_for_streak:
		_end_row.add_child(Ui.button("Copy result", _share, false, 104))
	if day == 0:
		_end_row.add_child(Ui.button("Next puzzle", func() -> void: app.replace(create(Daily.random_practice(int(puzzle["id"])))), false, 104))
	_end_row.add_child(Ui.button("Done", func() -> void: app.pop(), true, 104))
	_end_card.visible = true
	_end_card.modulate.a = 0.0
	create_tween().tween_property(_end_card, "modulate:a", 1.0, 0.25).set_delay(0.3)


func _share() -> void:
	DisplayServer.clipboard_set(Daily.share_text(day, tries))
	Modal.show(app, "Copied", [Modal.text("Your result is copied. Paste it into WhatsApp or any message.")], [["OK", func() -> void: pass, true]])
