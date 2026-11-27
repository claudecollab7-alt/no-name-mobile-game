class_name FourPreview
extends Control
## A non-interactive Four in a Row board showing any position: home card, game page.

const Board := preload("res://games/fourinrow/board/four_board_view.gd")
const F := preload("res://games/fourinrow/four_rules.gd")

var board: Board


static func create(s: F.State, height := 260.0, compact := false) -> FourPreview:
	var p := FourPreview.new()
	p.custom_minimum_size.y = height
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.board = Board.new()
	p.board.interactive = false
	p.board.show_hints = false
	p.board.reduce_motion = true
	p.board.compact = compact
	p.add_child(p.board)
	p.board.set_state(s)
	p.resized.connect(func() -> void: p.board.layout(p.size))
	return p
