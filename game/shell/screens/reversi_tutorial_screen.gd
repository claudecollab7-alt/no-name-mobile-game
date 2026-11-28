extends AppScreen
## "Learn by playing" for Reversi: five short lessons on the real tray, run from
## games/reversi/tutorial/reversi_tutorial.gd. Each lesson accepts only the moves that
## teach the point; once the discs have turned it says what happened (in the passing
## lesson, cream's pass is played on the board too). The last lesson leads into a first
## game against Easy, moving first.

const R := preload("res://games/reversi/reversi_rules.gd")
const Board := preload("res://games/reversi/board/reversi_board_view.gd")
const PlayScreen := preload("res://shell/screens/reversi_play_screen.gd")

var game_id := "reversi"
var board: Board
var step_index := 0
var _steps: Array = []
var _counter: Label
var _dots: HBoxContainer
var _title: Label
var _text: Label
var _done_card: PanelContainer
var _done_text: Label
var _next_row: HBoxContainer
var _waiting := false  ## A lesson move was played; its discs are still turning.


static func create(id := "reversi") -> AppScreen:
	var s: AppScreen = load("res://shell/screens/reversi_tutorial_screen.gd").new()
	s.game_id = id
	return s


func _ready() -> void:
	_steps = ReversiTutorial.steps()
	var col := page(false, 64, 40)
	_counter = Ui.label("", 28, Ui.MUTED, "bold")
	col.add_child(top_bar(tr("Learn %s") % tr(Games.title(game_id)), _counter))

	_dots = Ui.hbox(10)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_dots)

	var card := Ui.card(Ui.CARD, Ui.LINE, 28)
	var row := Ui.hbox(22)
	var disc := PanelContainer.new()  # You play orange in every lesson.
	disc.custom_minimum_size = Vector2(64, 64)
	disc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var tones: Array = Board.DISCS[0]
	disc.add_theme_stylebox_override("panel", Ui.box(tones[0], tones[1], 32, 5, 0))
	row.add_child(disc)
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
	board = Board.new()
	board.reduce_motion = Store.setting("reduce_motion")
	area.add_child(board)
	area.resized.connect(func() -> void: board.layout(area.size))
	board.played.connect(func(kind: String) -> void:
		if kind == "place":
			Sfx.play("place")
		elif kind == "flip":
			Sfx.play("move")
		elif kind == "nope":
			Sfx.play("nope"))
	board.human_moved.connect(_on_moved)
	board.changed.connect(_on_settled)

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
	_title.text = step["title"]
	_text.text = step["text"]
	_done_card.visible = false
	_waiting = false
	board.interactive = true
	board.show_hints = true
	board.only_moves = ReversiTutorial.accepted(step)
	board.focus_points = ReversiTutorial.focus_cells(step)
	board.set_state(ReversiTutorial.position(step))


func _on_moved(_sq: int) -> void:
	board.interactive = false
	board.focus_points = PackedInt32Array()
	board.only_moves = PackedInt32Array()
	_waiting = true


## The discs have turned: say what the lesson showed.
func _on_settled() -> void:
	if not _waiting:
		return
	_waiting = false
	board.interactive = false
	var step: Dictionary = _steps[step_index]
	if step["check"] == "pass" and R.legal_moves(board.state)[0] == R.PASS:
		board.play_move(R.PASS)  # Cream has nowhere to play: show the pass.
	_done_text.text = step["done"]
	for c in _next_row.get_children():
		c.queue_free()
	if step_index < _steps.size() - 1:
		_next_row.add_child(Ui.button("Next", _next, true, 108))
	else:
		Store.data["games"][game_id]["tutorial_done"] = true
		Store.save_data()
		Sfx.play("solved")
		_done_text.text = tr("%s You're ready to play.") % step["done"]
		_next_row.add_child(Ui.button("Home", func() -> void: app.home(), false, 108))
		_next_row.add_child(Ui.button("Play the computer", _first_game, true, 108))
	_done_card.visible = true
	_done_card.modulate.a = 0.0
	create_tween().tween_property(_done_card, "modulate:a", 1.0, 0.25).set_delay(0.2)


func _next() -> void:
	step_index += 1
	_show_step()


## First real game: against Easy, and you move first.
func _first_game() -> void:
	Store.set_last("mode", "computer")
	Store.set_last("level", "easy")
	Store.set_last("seat", "first")
	app.replace(PlayScreen.create(game_id, "computer", "easy", true))
