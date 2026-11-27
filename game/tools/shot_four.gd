extends Node
## Saves pictures of the Four in a Row board for design review (BUILD_PLAN.md G4.2).
## Needs a window, not --headless; run as a scene so the app's autoloads exist:
##   godot --path game res://tools/shot_four.tscn -- --out=C:/some/folder

const F := preload("res://games/fourinrow/four_rules.gd")
const Board := preload("res://games/fourinrow/board/four_board_view.gd")
const SIZE := Vector2i(1080, 1300)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	# Start, mid-game (orange to move, hints on), and a won game with the four lit up.
	var mid := F.new_game()
	for c: int in [3, 3, 2, 4, 4, 2, 3, 5, 5, 1, 4, 3]:
		F.drop(mid, c)
	var won := F.new_game()
	for c: int in [3, 4, 4, 5, 5, 6, 5, 6, 6, 0, 6]:
		F.drop(won, c)
	for shot: Array in [["four_start", F.new_game(), false], ["four_mid", mid, true], ["four_win", won, false]]:
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
		if shot[0] == "four_mid":  # A disc caught mid-fall.
			board.play_move(1)
			await _frames(7)
			await _save(vp, "%s/four_drop.png" % out)
		vp.queue_free()
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _save(vp: SubViewport, path: String) -> void:
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(path)
	print("saved ", path)
