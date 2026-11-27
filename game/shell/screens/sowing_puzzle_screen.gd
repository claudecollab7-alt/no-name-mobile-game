extends AppScreen
## One seed-game puzzle (BUILD_PLAN.md G2.5b). You play the bottom row; in "win"
## puzzles the computer answers with its toughest defence. Each move is judged once its
## seeds have landed. A wrong move is explained and the position resets; each reset
## counts as a try. "Show answer" rings the right first move.

const S := preload("res://games/sowing/sowing_rules.gd")
const Board := preload("res://games/sowing/board/sowing_board_view.gd")

var game_id := "kalah"
var puzzle := {}
var board: Board
var tries := 1
var revealed := false
var _left := 1  ## "win": your moves left. "most": seeds still to win this turn.
var _before: S.State
var _waiting := ""  ## "", "mine" (your move is landing) or "reply" (the computer's is)
var _last_pit := -1
var _tries_label: Label
var _feedback: Label
var _end_card: PanelContainer
var _end_title: Label
var _end_text: Label
var _end_row: HBoxContainer
var _answer_button: Button


static func create(id: String, p: Dictionary) -> AppScreen:
	var s: AppScreen = load("res://shell/screens/sowing_puzzle_screen.gd").new()
	s.game_id = id
	s.puzzle = p
	return s


func _ready() -> void:
	var col := page(false, 64, 40)
	_tries_label = Ui.label("", 26, Ui.MUTED, "bold")
	col.add_child(top_bar(tr("%s puzzle %d") % [tr(Games.title(game_id)), int(puzzle["id"])], _tries_label))

	var card := Ui.card(Ui.CARD, Ui.LINE, 26)
	var row := Ui.hbox(20)
	var ic := Ui.icon("star", 60, Ui.ACCENT)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(ic)
	var words := Ui.vbox(8)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var goal := Ui.label(SowingPuzzles.goal_text(puzzle), 32, Ui.INK, "bold")
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
	board = Board.new()
	board.reduce_motion = Store.setting("reduce_motion")
	board.show_hints = Store.setting("hints")
	area.add_child(board)
	area.resized.connect(func() -> void: board.layout(area.size))
	board.played.connect(func(kind: String) -> void: Sfx.play(kind))
	board.before_move.connect(func(s: S.State) -> void: _before = s)
	board.human_moved.connect(_on_move)
	board.changed.connect(_on_settled)

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


func _is_most() -> bool:
	return str(puzzle["goal"]) == "most"


func _reset() -> void:
	if _end_card.visible:
		return
	_left = int(puzzle["target"]) if _is_most() else int(puzzle["n"])
	_waiting = ""
	board.interactive = true
	board.focus_points = PackedInt32Array([int(puzzle["answer"])]) if revealed else PackedInt32Array()
	board.set_state(SowingPuzzles.position(game_id, puzzle))
	_tries_label.text = tr("Try %d") % tries
	_feedback.text = "Your move"


func _on_move(pit: int) -> void:
	if _end_card.visible:
		return
	_last_pit = pit
	_waiting = "mine"
	board.interactive = false
	board.focus_points = PackedInt32Array()


## Seeds have landed: judge your move, or hand the turn back after the computer's.
func _on_settled() -> void:
	var what := _waiting
	_waiting = ""
	if what == "mine":
		_judge()
	elif what == "reply":
		_after_reply()


func _judge() -> void:
	var before := _before
	var after := board.state
	if not SowingPuzzles.good_moves(puzzle, before, _left).has(_last_pit):
		_wrong(before)
		return
	if _is_most():
		_left -= after.stores[0] - before.stores[0]
		if _left <= 0:
			_solved()
		else:
			_feedback.text = "Good, and your last seed reached your store. Keep going!"
			board.interactive = true
		return
	_left -= 1
	if SowingPuzzles.decided(after, 0) == 1:
		_solved()
	elif after.turn == 0:
		_feedback.text = "Good, and you go again."
		board.interactive = true
	else:
		_reply()


func _reply() -> void:
	_feedback.text = "Good. Now the computer answers…"
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree() or _end_card.visible:
		return
	var r := SowingPuzzles.toughest_reply(board.state, _left)
	if r < 0:
		_after_reply()
		return
	_waiting = "reply"
	board.play_move(r)


func _after_reply() -> void:
	var s := board.state
	if not s.over and s.turn == 1:
		_reply()  # The computer goes again.
		return
	board.interactive = true
	_feedback.text = tr("Your move · %d left") % _left if _left > 1 else "Your move · last one"


## Says why the move falls short, then resets for another try.
func _wrong(before: S.State) -> void:
	Sfx.play("nope")
	board.interactive = false
	if _is_most():
		var reach := int(puzzle["target"]) - _left + SowingPuzzles._gain_with(before, _last_pit)
		_feedback.text = tr("Not the best: that turn can win %d seeds at most. You can win %d.") % [reach, int(puzzle["target"])]
	else:
		_feedback.text = "Not quite: now your opponent can hold out."
	await get_tree().create_timer(1.8).timeout
	if not is_inside_tree():
		return
	tries += 1
	_reset()


func _reveal() -> void:
	revealed = true
	_answer_button.disabled = true
	_reset()
	_feedback.text = "The right first move is ringed in orange."


func _solved() -> void:
	board.interactive = false
	Sfx.vibrate(40)
	Sfx.play("solved")
	_feedback.text = ""
	Store.solve_puzzle(game_id, int(puzzle["id"]))
	_end_title.text = "Solved!" if not revealed else "Solved with a hint"
	_end_text.text = tr("First try!") if tries == 1 else tr("Solved in %d tries.") % tries
	for c in _end_row.get_children():
		c.queue_free()
	var next := Store.next_puzzle(game_id, int(puzzle["id"]))
	if not next.is_empty():
		_end_row.add_child(Ui.button("Next puzzle", func() -> void: app.replace(create(game_id, next)), false, 104))
	_end_row.add_child(Ui.button("Done", func() -> void: app.pop(), true, 104))
	_end_card.visible = true
	_end_card.modulate.a = 0.0
	create_tween().tween_property(_end_card, "modulate:a", 1.0, 0.25).set_delay(0.3)
