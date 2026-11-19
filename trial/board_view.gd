extends Node2D
## Draws the brass-and-wood board, owns the piece nodes and turns taps into moves.

signal played(kind: String)  ## "place", "move" or "capture"
signal changed

const R := preload("res://rules.gd")
const Piece := preload("res://piece.gd")

const WOOD := Color("#3A2415")
const WOOD_EDGE := Color("#2A190E")
const GRAIN := Color("#4B3120")
const INLAY_SHADOW := Color("#1E1209")
const BRASS := Color("#C99A45")
const BRASS_LIGHT := Color("#E3BF73")
const HINT := Color("#FFF3D6")

const SRC_MIN := Vector2(16, 22)
const SRC_SIZE := Vector2(508, 327)
const MARGIN := 40.0  ## Plank border around the lines, in board-picture units.
const TIGER_R := 17.0  ## Piece sizes in board-picture units (closest points are 32 apart).
const GOAT_R := 16.0
const TAP_R := 30.0

var state: R.State
var plank := Rect2()
var unit := 1.0  ## Screen pixels per board-picture unit.
var origin := Vector2.ZERO
var pieces := {}  ## point -> Piece node
var selected := -1
var targets := {}  ## destination point -> move, for the selected piece or for placement
var busy := false


func new_game() -> void:
	for p: int in pieces:
		pieces[p].queue_free()
	pieces.clear()
	state = R.new_game()
	for t: int in state.tigers:
		_spawn(t, true)
	_clear_selection()
	_refresh_targets()
	changed.emit()


func layout(area: Vector2) -> void:
	var usable := area - Vector2(0, 0)
	unit = minf(usable.x / (SRC_SIZE.x + MARGIN * 2.0), usable.y / (SRC_SIZE.y + MARGIN * 2.0))
	var size := (SRC_SIZE + Vector2(MARGIN, MARGIN) * 2.0) * unit
	plank = Rect2((area - size) / 2.0, size)
	origin = plank.position + Vector2(MARGIN, MARGIN) * unit
	for p: int in pieces:
		var piece: Piece = pieces[p]
		piece.position = point_pos(p)
		piece.radius = (TIGER_R if piece.is_tiger else GOAT_R) * unit
	queue_redraw()


func point_pos(i: int) -> Vector2:
	return origin + (R.POINTS[i] - SRC_MIN) * unit


func _draw() -> void:
	if plank.size == Vector2.ZERO:
		return
	_draw_plank()
	var line_w := 5.0 * unit
	for line: Array in R.LINES:
		var pts := PackedVector2Array()
		var shadow := PackedVector2Array()
		for i: int in line:
			pts.append(point_pos(i))
			shadow.append(point_pos(i) + Vector2(0, 1.6 * unit))
		draw_polyline(shadow, INLAY_SHADOW, line_w + 2.5 * unit, true)
		draw_polyline(pts, BRASS, line_w, true)
	for i in R.POINT_COUNT:
		var c := point_pos(i)
		draw_circle(c + Vector2(0, 1.2 * unit), 6.5 * unit, INLAY_SHADOW, true, -1.0, true)
		draw_circle(c, 6.0 * unit, BRASS_LIGHT, true, -1.0, true)
	for p: int in targets:
		var c := point_pos(p)
		draw_circle(c, 13.0 * unit, Color(HINT, 0.28), true, -1.0, true)
		draw_arc(c, 13.0 * unit, 0.0, TAU, 40, Color(HINT, 0.9), 2.2 * unit, true)


func _draw_plank() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = WOOD
	box.border_color = WOOD_EDGE
	box.set_border_width_all(int(round(4.0 * unit)))
	box.set_corner_radius_all(int(round(18.0 * unit)))
	box.shadow_color = Color(0, 0, 0, 0.28)
	box.shadow_size = int(round(10.0 * unit))
	box.shadow_offset = Vector2(0, 5.0 * unit)
	box.anti_aliasing = true
	draw_style_box(box, plank)
	# A few hand-tuned grain lines instead of a photo texture.
	var inset := 22.0 * unit
	for k in 11:
		var y := plank.position.y + inset + (plank.size.y - inset * 2.0) * (k + 0.5) / 11.0
		var pts := PackedVector2Array()
		for j in 33:
			var x := plank.position.x + inset + (plank.size.x - inset * 2.0) * j / 32.0
			pts.append(Vector2(x, y + sin(j * 0.55 + k * 1.7) * 2.6 * unit + sin(j * 0.17 + k) * 4.0 * unit))
		draw_polyline(pts, GRAIN, 1.4 * unit, true)


func _unhandled_input(event: InputEvent) -> void:
	if busy or state == null:
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var local := make_input_local(event) as InputEventMouseButton
	_tap(_nearest_point(local.position))
	get_viewport().set_input_as_handled()


func _nearest_point(pos: Vector2) -> int:
	var best := -1
	var best_d := TAP_R * unit
	for i in R.POINT_COUNT:
		var d := pos.distance_to(point_pos(i))
		if d < best_d:
			best_d = d
			best = i
	return best


func _tap(p: int) -> void:
	if p < 0 or R.result(state) != R.ONGOING:
		_clear_selection()
		_refresh_targets()
		return
	if targets.has(p):
		_play(targets[p])
		return
	var own := R.tiger_at(state, p) if state.turn == R.TIGER else (R.goat_at(state, p) and state.in_hand == 0)
	if own and p != selected:
		_select(p)
	else:
		_clear_selection()
		_refresh_targets()


func _select(p: int) -> void:
	_clear_selection()
	selected = p
	pieces[p].selected = true
	_refresh_targets()


func _clear_selection() -> void:
	if selected >= 0 and pieces.has(selected):
		pieces[selected].selected = false
	selected = -1


func _refresh_targets() -> void:
	targets.clear()
	if state != null and R.result(state) == R.ONGOING:
		var placing := state.turn == R.GOAT and state.in_hand > 0
		for m: int in R.legal_moves(state):
			if placing or R.move_from(m) == selected:
				targets[R.move_to(m)] = m
	queue_redraw()


func _play(m: int) -> void:
	var from := R.move_from(m)
	var to := R.move_to(m)
	var over := R.move_over(m)
	state = R.apply(state, m)
	_clear_selection()
	if from == R.NONE:
		var goat := _spawn(to, false)
		goat.scale = Vector2(0.3, 0.3)
		create_tween().tween_property(goat, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		played.emit("place")
	else:
		var piece: Piece = pieces[from]
		pieces.erase(from)
		pieces[to] = piece
		busy = true
		var t := create_tween()
		t.tween_property(piece, "position", point_pos(to), 0.32 if over != R.NONE else 0.2) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.finished.connect(func() -> void: busy = false)
		if over != R.NONE:
			var victim: Piece = pieces[over]
			pieces.erase(over)
			var v := create_tween().set_parallel(true)
			v.tween_property(victim, "scale", Vector2(1.5, 1.5), 0.22).set_delay(0.16)
			v.tween_property(victim, "modulate:a", 0.0, 0.22).set_delay(0.16)
			v.chain().tween_callback(victim.queue_free)
			played.emit("capture")
		else:
			played.emit("move")
	_refresh_targets()
	changed.emit()


func _spawn(p: int, tiger: bool) -> Piece:
	var piece := Piece.new()
	piece.is_tiger = tiger
	piece.radius = (TIGER_R if tiger else GOAT_R) * unit
	piece.position = point_pos(p)
	piece.z_index = 2 if tiger else 1
	add_child(piece)
	pieces[p] = piece
	return piece
