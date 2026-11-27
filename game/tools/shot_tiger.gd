extends Node
## Saves pictures of the tiger boards (Tiger & Goat and Bagh-Chal) for design review.
## Needs a window, not --headless; run as a scene so the app's autoloads exist:
##   godot --path game res://tools/shot_tiger.tscn -- --out=C:/some/folder

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const Board := preload("res://games/aadupuli/board/board_view.gd")
const SIZE := Vector2i(1080, 1300)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	for board_id: String in ["baghchal", "aadupuli"]:
		var vp := SubViewport.new()
		vp.size = SIZE
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var bg := ColorRect.new()
		bg.color = Ui.MEADOW
		bg.size = SIZE
		vp.add_child(bg)
		var board: Board = Board.new()
		vp.add_child(board)
		board.layout(Vector2(SIZE))
		board.new_game({"board": board_id})
		await _frames(4)
		await _save(vp, "%s/%s_start.png" % [out, board_id])
		var rng := RandomNumberGenerator.new()
		rng.seed = 4
		var s := board.state
		for i in 16:
			var moves := R.legal_moves(s)
			s = R.apply(s, moves[rng.randi_range(0, moves.size() - 1)])
		board.set_state(s)
		await _frames(4)
		await _save(vp, "%s/%s_mid.png" % [out, board_id])
		vp.queue_free()
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(vp: SubViewport, path: String) -> void:
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)
	print("saved ", path)
