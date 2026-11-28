extends Node
## Saves pictures of the Reversi board for design review (BUILD_PLAN.md G5.2).
## Needs a window, not --headless; run as a scene so the app's autoloads exist:
##   godot --path game res://tools/shot_reversi.tscn -- --out=C:/some/folder

const R := preload("res://games/reversi/reversi_rules.gd")
const Board := preload("res://games/reversi/board/reversi_board_view.gd")
const SIZE := Vector2i(1080, 1300)


func _ready() -> void:
	_run.call_deferred()


## A game played by always taking the move that flips the most (first on ties).
func _greedy(moves: int) -> R.State:
	var s := R.new_game()
	for i in moves:
		var best := -1
		var most := -1
		for m in R.legal_moves(s):
			var n := 0 if m == R.PASS else R.discs(R.after(s, m), s.turn)
			if n > most:
				most = n
				best = m
		if best < 0:
			break
		R.play(s, best)
	return s


func _run() -> void:
	var out := "user://"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	var mid := _greedy(14)
	var done := _greedy(200)
	for shot: Array in [["reversi_start", R.new_game(), true], ["reversi_mid", mid, true], ["reversi_end", done, false]]:
		var vp := SubViewport.new()
		vp.size = SIZE
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var bg := ColorRect.new()
		bg.color = Ui.MEADOW
		bg.size = SIZE
		vp.add_child(bg)
		var board: Board = Board.new()
		board.interactive = shot[2]
		vp.add_child(board)
		board.layout(Vector2(SIZE))
		board.set_state(shot[1])
		await _frames(30)
		await _save(vp, "%s/%s.png" % [out, shot[0]])
		if shot[0] == "reversi_mid":  # Discs caught turning over, part way along the line.
			var best := -1
			var most := -1
			for m in R.legal_moves(mid):
				var n := R.play(mid.copy(), m).size()
				if n > most:
					most = n
					best = m
			board.play_move(best)
			await _frames(16)
			await _save(vp, "%s/reversi_flip.png" % out)
		vp.queue_free()
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(vp: SubViewport, path: String) -> void:
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)
	print("saved ", path)
