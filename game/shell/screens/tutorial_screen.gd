extends AppScreen
## "Learn by playing": five short lessons on a real board (BUILD_PLAN.md task 3.2).
## Each lesson sets a position, gives one instruction, accepts only the moves that teach
## the point, then says what was learned. The last lesson leads into a first easy game.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const BoardView := preload("res://games/aadupuli/board/board_view.gd")
const PlayScreen := preload("res://shell/screens/play_screen.gd")

var board: BoardView
var step_index := 0
var _steps: Array = AadupuliTutorial.steps()
var _counter: Label
var _dots: HBoxContainer
var _side_slot: Control
var _title: Label
var _text: Label
var _done_card: PanelContainer
var _done_text: Label
var _next_row: HBoxContainer


func _ready() -> void:
	var col := page(false, 64, 40)
	_counter = Ui.label("", 28, Ui.MUTED, "bold")
	col.add_child(top_bar("Learn to play", _counter))

	_dots = Ui.hbox(10)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_dots)

	var card := Ui.card(Ui.CARD, Ui.LINE, 28)
	var row := Ui.hbox(22)
	_side_slot = Ui.hbox(0)
	row.add_child(_side_slot)
	var words := Ui.vbox(4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = Ui.heading("", 42)
	words.add_child(_title)
	_text = Ui.muted("", 30)
	words.add_child(_text)
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
	area.add_child(board)
	area.resized.connect(func() -> void: board.layout(area.size))
	board.played.connect(func(kind: String) -> void: Sfx.play(kind))
	board.human_moved.connect(_on_moved)

	_done_card = Ui.card(Ui.WARM, Ui.ACCENT_LINE, 28)
	var dv := Ui.vbox(18)
	_done_text = Ui.label("", 32, Ui.INK, "bold")
	_done_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(_done_text)
	_next_row = Ui.hbox(16)
	dv.add_child(_next_row)
	_done_card.add_child(dv)
	_done_card.visible = false
	col.add_child(_done_card)
	_show_step()


func _show_step() -> void:
	var step: Dictionary = _steps[step_index]
	_counter.text = "%d / %d" % [step_index + 1, _steps.size()]
	for c in _dots.get_children():
		c.queue_free()
	for i in _steps.size():
		var d := PanelContainer.new()
		d.custom_minimum_size = Vector2(56 if i == step_index else 22, 22)
		d.add_theme_stylebox_override("panel", Ui.box(Ui.ACCENT if i <= step_index else Ui.SOFT, Color(0, 0, 0, 0), 11, 0, 0))
		_dots.add_child(d)
	for c in _side_slot.get_children():
		c.queue_free()
	_side_slot.add_child(Ui.token(int(step["turn"]) == R.TIGER, 34))
	_title.text = step["title"]
	_text.text = step["text"]
	_done_card.visible = false
	board.interactive = true
	board.show_hints = true
	board.only_moves = AadupuliTutorial.accepted(step)
	board.focus_points = PackedInt32Array(step["focus"])
	board.set_state(AadupuliTutorial.position(step))


func _on_moved(_m: int) -> void:
	var step: Dictionary = _steps[step_index]
	board.interactive = false
	board.focus_points = PackedInt32Array()
	board.only_moves = PackedInt32Array()
	board.refresh_targets()
	_done_text.text = step["done"]
	for c in _next_row.get_children():
		c.queue_free()
	if step_index < _steps.size() - 1:
		_next_row.add_child(Ui.button("Next", _next, true, 108))
	else:
		Store.data["tutorial_done"] = true
		Store.save_data()
		Sfx.play("solved")
		_done_text.text = tr("%s You're ready to play.") % step["done"]
		_next_row.add_child(Ui.button("Home", func() -> void: app.home(), false, 108))
		_next_row.add_child(Ui.button("Play the computer", _first_game, true, 108))
	_done_card.visible = true
	_done_card.modulate.a = 0.0
	create_tween().tween_property(_done_card, "modulate:a", 1.0, 0.25).set_delay(0.35)


func _next() -> void:
	step_index += 1
	_show_step()


## First real game: against Easy, playing the tigers (the more forgiving side for beginners).
func _first_game() -> void:
	Store.set_last("mode", "computer")
	Store.set_last("level", "easy")
	Store.set_last("side", "tigers")
	app.replace(PlayScreen.create("computer", "easy", "tigers"))
