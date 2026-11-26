class_name SowingPreview
extends Control
## A non-interactive sowing board showing any position: home card, game page.

const Board := preload("res://games/sowing/board/sowing_board_view.gd")
const S := preload("res://games/sowing/sowing_rules.gd")

var board: Board


static func create(s: S.State, height := 260.0, compact := false) -> SowingPreview:
	var p := SowingPreview.new()
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
