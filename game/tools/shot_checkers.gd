extends Node
## Saves pictures of the Checkers board for design review (BUILD_PLAN.md G6.2).
## Needs a window, not --headless; run as a scene so the app's autoloads exist:
##   godot --path game res://tools/shot_checkers.tscn -- --out=C:/some/folder

const C := preload("res://games/checkers/checkers_rules.gd")
const Board := preload("res://games/checkers/board/checkers_board_view.gd")
const SIZE := Vector2i(1080, 1300)


func _ready() -> void:
	_run.call_deferred()


## A seeded random English game, played until Black has a capture chain to make.
func _with_capture() -> C.State:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for attempt in 200:
		var s := C.new_game(C.ENGLISH)
		for i in 40:
			if C.result(s) != C.ONGOING:
				break
			var moves := C.legal_moves(s)
			if s.turn == 0 and i > 10 and moves.any(func(m: C.Move) -> bool: return m.captured.size() >= 2):
				return s
			# Avoid captures, so the board stays full for the picture.
			var quiet := moves.filter(func(m: C.Move) -> bool: return not m.is_capture())
			var pool := quiet if not quiet.is_empty() else moves
			C.play(s, pool[rng.randi_range(0, pool.size() - 1)])
	return C.new_game(C.ENGLISH)


func _kings() -> C.State:
	var cells: Array = []
	cells.resize(C.SQUARES)
	cells.fill(".")
	for p: Array in [[1, 1, "b"], [3, 1, "b"], [2, 2, "b"], [6, 2, "B"], [4, 4, "B"], [7, 5, "r"], [5, 5, "r"], [2, 6, "r"], [1, 5, "R"], [6, 0, "R"]]:
		cells[C.square(p[0], p[1])] = p[2]
	return C.from_dict({"variant": C.INTERNATIONAL, "board": "".join(cells), "turn": 1, "last_move": [C.square(2, 4), C.square(1, 5)]})


func _run() -> void:
	var out := "user://"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	var cap := _with_capture()
	for shot: Array in [["checkers_start", C.new_game(), false], ["checkers_pick", cap, false], ["checkers_kings", _kings(), true]]:
		var vp := SubViewport.new()
		vp.size = SIZE
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var bg := ColorRect.new()
		bg.color = Ui.MEADOW
		bg.size = SIZE
		vp.add_child(bg)
		var board: Board = Board.new()
		board.flipped = shot[2]
		vp.add_child(board)
		board.layout(Vector2(SIZE))
		board.set_state(shot[1])
		if shot[0] == "checkers_pick":  # Pick up the piece with the longest capture.
			var best: C.Move = null
			for m: C.Move in C.legal_moves(cap):
				if best == null or m.captured.size() > best.captured.size():
					best = m
			board._tap(best.from_sq())
			await _frames(30)
			await _save(vp, "%s/checkers_pick.png" % out)
			board._tap(best.from_sq())  # Put it back, then play it: caught mid-hop.
			board.play_move(best.path)
			await _frames(9)
			await _save(vp, "%s/checkers_hop.png" % out)
		else:
			await _frames(30)
			await _save(vp, "%s/%s.png" % [out, shot[0]])
		vp.queue_free()
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(vp: SubViewport, path: String) -> void:
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)
	print("saved ", path)
