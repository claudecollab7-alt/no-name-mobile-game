extends Node2D
## Draws the "hill and meadow" board (DISCUSSION.md section 24), owns the piece nodes
## and turns taps into moves. The board is a place: the tigers' cave sits on the summit,
## the paths are worn into a sandy hill, and the goats come up from the meadow.
## Bagh-Chal (section 30, D67) is the same world with a Himalayan touch: snowy peaks and
## prayer flags behind a square sandy plateau with the 5 x 5 board worn into it.

signal played(kind: String)  ## "place", "move" or "capture"
signal changed
signal before_move(state_before)
signal human_moved(move: int)
signal no_moves(point: int)  ## The player picked a piece that has nowhere to go.  ## A move the player made by tapping (sent to the server online).  ## A human move is about to be played; used for undo.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const Piece := preload("res://games/aadupuli/board/piece.gd")

const RIDGE := Color("#C9DCAE")
const SUN := Color("#F6C66B")
const BIRD := Color("#647A58")
const SAND := Color("#EBD5A8")
const SAND_EDGE := Color("#D9BE88")
const CAVE := Color("#3A2A1E")
const GRASS := Color("#6E9A4C")
const PATH_EDGE := Color("#D5B47D")
const PATH := Color("#FBF1DA")
const STONE := Color("#B48D55")
const HINT := Color("#FFFFFF")
const FOCUS := Color("#E26F2A")
const LAST := Color("#8A6A3A")  ## Last-move trail: a darker sand, quiet but visible.

const MOUNTAIN := Color("#B5C6CF")
const MOUNTAIN_FAR := Color("#CBD8DC")
const SNOW := Color("#FBFCFA")
const FLAG_COLOURS := [Color("#4C7FB8"), Color("#F4F1E6"), Color("#D2553F"), Color("#6E9A4C"), Color("#E8B93F")]
const POLE := Color("#8A6A3A")

const TIGER_R := 17.0  ## Piece sizes in board-picture units (Tiger & Goat's closest points are 32 apart).
const GOAT_R := 15.0
const TAP_R := 30.0

## How each board sits in its picture: bounds of the points, space around them for the
## scene (left, top, right, bottom), how far it may stretch on tall screens, and how big
## the pieces are compared with Tiger & Goat.
const VIEWS := {
	"aadupuli": {"min": Vector2(16, 22), "size": Vector2(508, 327), "pad": [40.0, 40.0, 40.0, 40.0], "stretch": 1.6, "piece": 1.0},
	"baghchal": {"min": Vector2(0, 0), "size": Vector2(400, 400), "pad": [70.0, 175.0, 70.0, 70.0], "stretch": 1.0, "piece": 1.85},
}

var state: R.State
var plank := Rect2()
var unit := 1.0  ## Screen pixels per board-picture unit, horizontally (also sizes pieces and lines).
var unit_y := 1.0  ## Vertical scale; can exceed unit on tall screens.
var origin := Vector2.ZERO
var pieces := {}  ## point -> Piece node
var selected := -1
var targets := {}  ## destination point -> move, for the selected piece or for placement
var busy := false
var interactive := true  ## False for the result screen and while the computer thinks.
var show_hints := true
var reduce_motion := false
var only_moves := PackedInt32Array()  ## When set, only these moves are allowed (tutorial).
var focus_points := PackedInt32Array()  ## Points ringed in orange to show where to look (tutorial).
var last_move := -1  ## Marked on the board so players see what just happened.
var _area := Vector2.ZERO
var _time := 0.0
var _board := "aadupuli"
var _view: Dictionary = VIEWS["aadupuli"]
var _pk := 1.0  ## Piece and marker size factor for this board.


func new_game(options: Dictionary = {}) -> void:
	set_state(R.new_game(options))


## Shows any position without animation (new game, restored game, result screen).
func set_state(s: R.State) -> void:
	for p: int in pieces:
		pieces[p].queue_free()
	pieces.clear()
	state = s
	if s.board != _board:
		_board = s.board
		_view = VIEWS.get(_board, VIEWS["aadupuli"])
		_pk = float(_view["piece"])
		if _area != Vector2.ZERO:
			layout(_area)
	last_move = -1
	for t in state.tigers:
		_spawn(t, true)
	for p in R.point_count(state):
		if R.goat_at(state, p):
			_spawn(p, false)
	_clear_selection()
	_refresh_targets()
	changed.emit()


## Plays a move chosen elsewhere (the computer), with the usual animation and sound.
func play_move(m: int) -> void:
	_play(m)


func layout(area: Vector2) -> void:
	_area = area
	var pad: Array = _view["pad"]
	var full: Vector2 = _view["size"] + Vector2(pad[0] + pad[2], pad[1] + pad[3])
	unit = minf(area.x / full.x, area.y / full.y)
	# On tall phones, stretch the board vertically (up to its stretch limit) instead of
	# leaving empty bands; it also spreads the rows apart for easier tapping.
	unit_y = minf(area.y / full.y, unit * float(_view["stretch"]))
	var size := Vector2(full.x * unit, full.y * unit_y)
	plank = Rect2((area - size) / 2.0, size)
	origin = plank.position + Vector2(pad[0] * unit, pad[1] * unit_y)
	for p: int in pieces:
		var piece: Piece = pieces[p]
		piece.position = point_pos(p)
		piece.radius = (TIGER_R if piece.is_tiger else GOAT_R) * unit * _pk
	queue_redraw()


func point_pos(i: int) -> Vector2:
	return _sp(R.points_of(_board)[i])


## Board-picture coordinates to screen coordinates.
func _sp(v: Vector2) -> Vector2:
	var lo: Vector2 = _view["min"]
	return origin + Vector2((v.x - lo.x) * unit, (v.y - lo.y) * unit_y)


func _process(delta: float) -> void:
	_time += delta
	if not targets.is_empty() or not focus_points.is_empty():
		queue_redraw()  # Only the pulses animate; skip redraws when there are none.


func _draw() -> void:
	if plank.size == Vector2.ZERO:
		return
	if _board == "baghchal":
		_draw_himalaya()
	else:
		_draw_scene()
	for line: Array in R.lines_of(_board):
		var pts := PackedVector2Array()
		for i: int in line:
			pts.append(point_pos(i))
		draw_polyline(pts, PATH_EDGE, 11.0 * unit, true)
		draw_polyline(pts, PATH, 5.5 * unit, true)
	for i in R.point_count(state):
		draw_circle(point_pos(i), 5.5 * unit, STONE, true, -1.0, true)
	_draw_last_move()
	var pulse := 0.5 + 0.5 * sin(_time * 3.4)
	# Placement targets are a hint and follow the setting; a selected piece always shows its moves.
	if show_hints or selected >= 0:
		for p: int in targets:
			var c := point_pos(p)
			draw_circle(c, (8.5 + 2.5 * pulse) * unit, Color(HINT, 0.45 + 0.4 * pulse), true, -1.0, true)
	for p in focus_points:
		draw_arc(point_pos(p), (23.0 + 3.0 * pulse) * unit * _pk, 0.0, TAU, 48, Color(FOCUS, 0.55 + 0.45 * pulse), 3.2 * unit, true)


func _draw_scene() -> void:
	# Setting sun behind a far green ridge, and two birds.
	draw_circle(_sp(Vector2(486, 10)), 24.0 * unit, SUN, true, -1.0, true)
	var ridge := _path([Vector2(-60, 400)], [
		[Vector2(40, 0), Vector2(170, 32)], [Vector2(270, 62), Vector2(380, 26)],
		[Vector2(490, -10), Vector2(600, 52)]])
	ridge.append(_sp(Vector2(600, 400)))
	# Distant meadow runs edge to edge behind the ridge, so wide screens and cards have no bare sides.
	if _area.x > 0.0:
		var top := _sp(Vector2(0, 62)).y
		var bottom := maxf(_area.y, _sp(Vector2(0, 400)).y)
		draw_rect(Rect2(0, top, _area.x, bottom - top), RIDGE)
	draw_colored_polygon(ridge, RIDGE)
	for b: Vector2 in [Vector2(70, 26), Vector2(108, 12)]:
		var s := 8.0  # A gull: two wings arching up from the body.
		var wing := PackedVector2Array()
		for v: Vector2 in [Vector2(-s, -s * 0.1), Vector2(-s * 0.55, -s * 0.5), Vector2(-s * 0.15, -s * 0.3), Vector2(0, 0),
				Vector2(s * 0.15, -s * 0.3), Vector2(s * 0.55, -s * 0.5), Vector2(s, -s * 0.1)]:
			wing.append(_sp(b + v))
		draw_polyline(wing, BIRD, 2.0 * unit, true)
	# The sandy hill: a broad plateau carrying the rows, rising to a summit at the apex.
	var hill := _path([Vector2(-26, 380)], [
		[Vector2(-34, 180), Vector2(-16, 80)], [Vector2(-8, 60), Vector2(40, 60)],
		[Vector2(200, 58), Vector2(248, 18)], [Vector2(278, -8), Vector2(308, 18)],
		[Vector2(356, 58), Vector2(516, 60)], [Vector2(564, 60), Vector2(572, 80)],
		[Vector2(590, 180), Vector2(582, 380)]])
	draw_colored_polygon(hill, SAND)
	hill.append(hill[0])
	draw_polyline(hill, SAND_EDGE, 2.5 * unit, true)
	# The tigers' cave on the summit, just behind the top point.
	var cave := _path([Vector2(250, 12)], [[Vector2(278, -26), Vector2(306, 12)]])
	draw_colored_polygon(cave, CAVE)
	# Meadow grass along the foot of the hill.
	for x: float in [-14.0, 30.0, 96.0, 150.0, 214.0, 262.0, 300.0, 376.0, 430.0, 490.0, 548.0]:
		var base := Vector2(x, 381)
		var tuft := PackedVector2Array()
		for k in 7:
			var dx := k * 3.0
			tuft.append(_sp(base + Vector2(dx, -12.0 if k % 2 == 1 else 0.0) + Vector2(0, -4.0 if k == 3 else 0.0)))
		draw_polyline(tuft, GRASS, 2.4 * unit, true)


## Bagh-Chal's scene (D67): far snowy peaks, a string of prayer flags, the meadow, and a
## square sandy plateau carrying the 5 x 5 board. Picture units: points run 0..400.
func _draw_himalaya() -> void:
	# Two ranges of peaks, the far one paler, with snow on the tops.
	var far := _path([Vector2(-140, 10)], [
		[Vector2(-90, -60), Vector2(-40, -118)], [Vector2(10, -60), Vector2(70, -96)],
		[Vector2(150, -150), Vector2(230, -132)], [Vector2(300, -90), Vector2(360, -122)],
		[Vector2(430, -160), Vector2(560, -40)]])
	far.append(_sp(Vector2(560, 10)))
	draw_colored_polygon(far, MOUNTAIN_FAR)
	var near := PackedVector2Array()
	var tops: Array = [Vector2(-30, -126), Vector2(120, -158), Vector2(330, -142), Vector2(470, -112)]
	var feet: Array = [Vector2(-150, -10), Vector2(50, -36), Vector2(230, -24), Vector2(410, -40), Vector2(570, -10)]
	near.append(_sp(Vector2(-150, 20)))
	for i in tops.size():
		near.append(_sp(feet[i]))
		near.append(_sp(tops[i]))
	near.append(_sp(feet[-1]))
	near.append(_sp(Vector2(570, 20)))
	draw_colored_polygon(near, MOUNTAIN)
	for top: Vector2 in tops:
		var cap := PackedVector2Array()
		for v: Vector2 in [Vector2(0, 0), Vector2(26, 30), Vector2(12, 24), Vector2(2, 34), Vector2(-10, 22), Vector2(-24, 30)]:
			cap.append(_sp(top + v))
		draw_colored_polygon(cap, SNOW)
	# The meadow, edge to edge, so wide screens and cards have no bare sides.
	if _area.x > 0.0:
		var top_y := _sp(Vector2(0, -20)).y
		var bottom := maxf(_area.y, _sp(Vector2(0, 480)).y)
		draw_rect(Rect2(0, top_y, _area.x, bottom - top_y), RIDGE)
	# Prayer flags strung between two poles, sagging gently over the plateau.
	var left := Vector2(-48, -100)
	var right := Vector2(448, -100)
	for pole: Vector2 in [left, right]:
		draw_line(_sp(pole + Vector2(0, -12)), _sp(pole + Vector2(0, 62)), POLE, 3.0 * unit, true)
	var string := PackedVector2Array()
	var flags := 15
	for i in flags + 2:
		var f := float(i) / float(flags + 1)
		string.append(_sp(left.lerp(right, f) + Vector2(0, sin(f * PI) * 28.0)))
	draw_polyline(string, Color(POLE, 0.7), 1.6 * unit, true)
	for i in range(1, flags + 1):
		var a := string[i]
		var w := 11.0 * unit
		var h := 14.0 * unit_y
		var flag := PackedVector2Array([a + Vector2(-w / 2.0, 0), a + Vector2(w / 2.0, 0), a + Vector2(w / 2.0, h), a + Vector2(-w / 2.0, h)])
		draw_colored_polygon(flag, FLAG_COLOURS[(i - 1) % FLAG_COLOURS.size()])
	# The plateau: a rounded sandy square with the board worn into it.
	var r := 46.0
	var lo := Vector2(-50, -50)
	var hi := Vector2(450, 450)
	var plateau := _path([Vector2(lo.x + r, lo.y)], [
		[Vector2(hi.x - r, lo.y), Vector2(hi.x - r, lo.y)], [Vector2(hi.x, lo.y), Vector2(hi.x, lo.y + r)],
		[Vector2(hi.x, hi.y - r), Vector2(hi.x, hi.y - r)], [Vector2(hi.x, hi.y), Vector2(hi.x - r, hi.y)],
		[Vector2(lo.x + r, hi.y), Vector2(lo.x + r, hi.y)], [Vector2(lo.x, hi.y), Vector2(lo.x, hi.y - r)],
		[Vector2(lo.x, lo.y + r), Vector2(lo.x, lo.y + r)], [Vector2(lo.x, lo.y), Vector2(lo.x + r, lo.y)]])
	draw_colored_polygon(plateau, SAND)
	plateau.append(plateau[0])
	draw_polyline(plateau, SAND_EDGE, 2.5 * unit, true)
	# Meadow grass along the foot of the plateau.
	for x: float in [-60.0, -10.0, 60.0, 140.0, 210.0, 280.0, 350.0, 420.0, 470.0]:
		var base := Vector2(x, 468)
		var tuft := PackedVector2Array()
		for k in 7:
			tuft.append(_sp(base + Vector2(k * 3.0, -12.0 if k % 2 == 1 else 0.0) + Vector2(0, -4.0 if k == 3 else 0.0)))
		draw_polyline(tuft, GRASS, 2.4 * unit, true)


## Builds a closed outline from a start point and quadratic segments [control, end],
## in board-picture coordinates.
func _path(start: Array, segments: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var p0: Vector2 = start[0]
	out.append(_sp(p0))
	for seg: Array in segments:
		var c: Vector2 = seg[0]
		var p1: Vector2 = seg[1]
		for i in range(1, 13):
			var t := i / 12.0
			out.append(_sp(p0.lerp(c, t).lerp(c.lerp(p1, t), t)))
		p0 = p1
	return out


func _unhandled_input(event: InputEvent) -> void:
	if busy or state == null or not interactive:
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var local := make_input_local(event) as InputEventMouseButton
	_tap(_nearest_point(local.position))
	get_viewport().set_input_as_handled()


func _nearest_point(pos: Vector2) -> int:
	var best := -1
	var best_d := TAP_R * unit * _pk
	for i in R.point_count(state):
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
		before_move.emit(state)
		var m: int = targets[p]
		_play(m)
		human_moved.emit(m)
		return
	var own := R.tiger_at(state, p) if state.turn == R.TIGER else (R.goat_at(state, p) and state.in_hand == 0)
	if own and not only_moves.is_empty():
		own = Array(only_moves).any(func(m: int) -> bool: return R.move_from(m) == p)
	if own and p != selected and not _has_moves(p):
		_clear_selection()
		_refresh_targets()
		no_moves.emit(p)
		played.emit("nope")
		return
	if own and p != selected:
		_select(p)
		played.emit("select")
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
	if state != null and interactive and R.result(state) == R.ONGOING:
		var placing := state.turn == R.GOAT and state.in_hand > 0
		for m: int in R.legal_moves(state):
			if not only_moves.is_empty() and not only_moves.has(m):
				continue
			if placing or R.move_from(m) == selected:
				targets[R.move_to(m)] = m
	queue_redraw()


func _play(m: int) -> void:
	var from := R.move_from(m)
	var to := R.move_to(m)
	var over := R.move_over(m)
	state = R.apply(state, m)
	last_move = m
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
		var speed := 0.5 if reduce_motion else 1.0
		t.tween_property(piece, "position", point_pos(to), (0.32 if over != R.NONE else 0.2) * speed) \
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
	piece.radius = (TIGER_R if tiger else GOAT_R) * unit * _pk
	piece.position = point_pos(p)
	piece.z_index = 2 if tiger else 1
	piece.breathe = not reduce_motion
	add_child(piece)
	pieces[p] = piece
	return piece


## Recomputes the glowing points, e.g. after the computer's move hands the turn back.
func refresh_targets() -> void:
	_clear_selection()
	_refresh_targets()



func _has_moves(p: int) -> bool:
	for m in R.legal_moves(state):
		if R.move_from(m) == p and (only_moves.is_empty() or only_moves.has(m)):
			return true
	return false


## A soft trail from where the last piece came from to where it landed.
func _draw_last_move() -> void:
	if last_move < 0:
		return
	var to := point_pos(R.move_to(last_move))
	var from_index := R.move_from(last_move)
	var mark := Color(LAST, 0.85)
	if from_index != R.NONE:
		var from := point_pos(from_index)
		draw_line(from, to, Color(LAST, 0.35), 7.0 * unit, true)
		draw_arc(from, 11.0 * unit * _pk, 0.0, TAU, 32, mark, 2.4 * unit, true)
	draw_circle(to, 22.0 * unit * _pk, Color(LAST, 0.22), true, -1.0, true)
