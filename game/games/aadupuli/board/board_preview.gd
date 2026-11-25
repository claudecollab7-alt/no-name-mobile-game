class_name BoardPreview
extends Control
## A non-interactive board showing any position: home card, game page, result screen.

const BoardView := preload("res://games/aadupuli/board/board_view.gd")
const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")

var board: BoardView


static func create(s: R.State, height := 420.0) -> BoardPreview:
	var p := BoardPreview.new()
	p.custom_minimum_size.y = height
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.board = BoardView.new()
	p.board.interactive = false
	p.board.reduce_motion = true
	p.add_child(p.board)
	p.board.set_state(s)
	p.resized.connect(func() -> void: p.board.layout(p.size))
	return p
