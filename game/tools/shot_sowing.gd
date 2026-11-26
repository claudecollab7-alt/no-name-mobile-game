extends Node
## Saves pictures of the sowing board for design review (needs a window, not --headless).
## Run as a scene so the app's autoloads exist:
##   godot --path game res://tools/shot_sowing.tscn -- --out=C:/some/folder

const S := preload("res://games/sowing/sowing_rules.gd")
const Board := preload("res://games/sowing/board/sowing_board_view.gd")
const SIZE := Vector2i(1080, 1300)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	for game: Dictionary in [S.KALAH, S.PALLANGUZHI]:
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
		board.new_game(game)
		await _frames(4)
		await _save(vp, "%s/%s_start.png" % [out, game["id"]])
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var s := board.state
		for i in 9:
			var moves := S.legal_moves(s)
			s = S.after(s, moves[rng.randi_range(0, moves.size() - 1)])
		board.set_state(s)
		await _frames(4)
		await _save(vp, "%s/%s_board.png" % [out, game["id"]])
		# Mid-move: start the biggest move and catch the hand travelling.
		var best := -1
		for m in S.legal_moves(s):
			if best < 0 or s.pits[m] > s.pits[best]:
				best = m
		board.play_move(best)
		board._advance(0.5)
		await _frames(3)
		await _save(vp, "%s/%s_moving.png" % [out, game["id"]])
		vp.queue_free()
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(vp: SubViewport, path: String) -> void:
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)
	print("saved ", path)
