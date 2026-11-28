extends Node2D
## The Checkers board (DISCUSSION.md section 33, D78): a wooden frame lying in the meadow,
## cream light squares and deep green dark squares, classic red and black pieces, and a
## small gold crown on each king. Your own side sits at the bottom (`flipped` turns the
## board round when you play Red).
##
## Playing a move: tap one of your pieces (pieces that can move glow when hints are on),
## then tap where it lands; its landing squares glow. In a capture chain, tap each landing
## square in turn: the piece follows you and the pieces it has taken dim. Tap the piece
## again to put it back. A move slides (or hops over each captured piece, which then
## lifts away) and a crown pops on when a man becomes a king. Tapping while a move plays
## out skips to its end.

signal played(kind: String)  ## "move", "hop", "capture", "crown", "nope", "end"
signal changed  ## The position on screen has settled (after a move, or a new position).
signal before_move(state_before)  ## A human move is about to be played; used for undo.
signal human_moved(path: PackedInt32Array)  ## A move the player made by tapping.

const C := preload("res://games/checkers/checkers_rules.gd")

const GRASS := Color("#6E9A4C")
const FLOWER := Color("#FFF8E8")
const FLOWER_EYE := Color("#F6C66B")
const WOOD := Color("#A8743F")
const WOOD_EDGE := Color("#7A4E24")
const WOOD_SHINE := Color("#C99560")
const GRAIN := Color("#93622F")
const LIGHT := Color("#EFE2C2")  ## The light squares.
const DARK := Color("#3F6E45")  ## The dark squares, where the pieces stand.
const DARK_EDGE := Color("#335C39")
const SHADOW := Color(0.2, 0.12, 0.05, 0.28)
const HINT := Color("#FFFFFF")
const FOCUS := Color("#E26F2A")
const LAST := Color("#F6C66B")
const CROWN := Color("#F2C14E")
const CROWN_EDGE := Color("#A97A1E")
## Piece colours: [face, rim, ridge] for Black (player 0) and Red (player 1).
const PIECES := [
	[Color("#34343A"), Color("#16161A"), Color("#4C4C54")],
	[Color("#C8352D"), Color("#8A1F19"), Color("#DD5A50")],
]

const MARGIN := 0.42  ## Wooden border around the squares, in cells.
const PIECE_R := 0.38  ## Piece radius, in cells.
const SLIDE_LEN := 0.18  ## Seconds for a one-square slide (longer slides take a little more).
const HOP_LEN := 0.24  ## Seconds for each hop over a captured piece.
const FADE_LEN := 0.18  ## Seconds for a taken piece to lift away.

var state: C.State
var interactive := true  ## False for the result screen and while the computer thinks.
var show_hints := true
var reduce_motion := false
var flipped := false  ## Red's side at the bottom.
var only_moves: Array = []  ## When set, only these paths may be played (tutorial).
var focus_points := PackedInt32Array()  ## Squares ringed in orange (tutorial, puzzles).
var busy := false  ## A move is playing out.
var compact := false  ## Small previews: just the board, no grass around it.
var cell := 100.0  ## Width of one square in pixels; everything is sized from it.
var frame := Rect2()  ## The whole board, border included.

var _area := Vector2.ZERO
var _time := 0.0
var _prefix := PackedInt32Array()  ## The squares tapped so far for the move being chosen.
var _moves: Array = []  ## Legal moves in this position (cached).
# The move playing out:
var _anim_move: C.Move
var _anim_piece := 0  ## The piece as it was before the move (before any crowning).
var _anim_points: Array = []  ## Square centres along the path, from where the animation starts.
var _anim_hops: Array = []  ## Per segment: true if it hops over a captured piece.
var _anim_ends: Array = []  ## Per segment: the time it ends.
var _anim_taken: Array = []  ## [square, piece, time it is passed] for each piece shown being taken.
var _anim_t := 0.0
var _anim_len := 0.0
var _crown_t := -1.0  ## Time since the crown appeared, or -1.


func new_game(variant := C.ENGLISH) -> void:
	set_state(C.new_game(variant))


## Shows any position without animation (new game, restored game, result screen).
func set_state(s: C.State) -> void:
	state = s
	busy = false
	_prefix = PackedInt32Array()
	_moves = C.legal_moves(s)
	_crown_t = -1.0
	queue_redraw()
	changed.emit()


## Plays a move chosen elsewhere (the computer, the other player online), animated.
func play_move(path: PackedInt32Array) -> void:
	if busy:
		skip()
	var m := C.find_move(state, path)
	if m != null:
		_play(m, 0)


## Jumps to the end of the move playing out.
func skip() -> void:
	if busy:
		_finish()


func layout(area: Vector2) -> void:
	_area = area
	var wide := 8.0 + MARGIN * 2.0 + (0.1 if compact else 0.6)
	cell = minf(area.x / wide, area.y / wide)
	var side := (8.0 + MARGIN * 2.0) * cell
	frame = Rect2((area - Vector2(side, side)) / 2.0, Vector2(side, side))
	queue_redraw()


# ---------- Geometry ----------

## Centre of the square at (col, row), row 0 at the bottom (the top when flipped).
func cell_pos(col: int, row: int) -> Vector2:
	if flipped:
		col = 7 - col
		row = 7 - row
	return frame.position + Vector2(MARGIN + col + 0.5, MARGIN + (7 - row) + 0.5) * cell


func square_pos(sq: int) -> Vector2:
	return cell_pos(C.col_of(sq), C.row_of(sq))


## The dark square under a tap, or -1.
func square_at(pos: Vector2) -> int:
	var p := (pos - frame.position) / cell - Vector2(MARGIN, MARGIN)
	if p.x < 0.0 or p.y < 0.0 or p.x >= 8.0 or p.y >= 8.0:
		return -1
	var col := int(p.x)
	var row := 7 - int(p.y)
	if flipped:
		col = 7 - col
		row = 7 - row
	return C.square(col, row)


# ---------- Choosing a move ----------

func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or state == null:
		return
	var local := (make_input_local(event) as InputEventMouseButton).position
	if not frame.has_point(local):
		return
	get_viewport().set_input_as_handled()
	if busy:
		skip()
		return
	if interactive:
		_tap(square_at(local))


## The legal moves the player may make now (all of them, or a lesson's).
func _allowed_moves() -> Array:
	if only_moves.is_empty():
		return _moves
	return _moves.filter(func(m: C.Move) -> bool: return only_moves.has(m.path))


## Moves that start with the squares tapped so far.
func _candidates() -> Array:
	var n := _prefix.size()
	return _allowed_moves().filter(func(m: C.Move) -> bool: return m.path.size() > n and m.path.slice(0, n) == _prefix or m.path == _prefix)


func _tap(sq: int) -> void:
	if busy:
		skip()
		return
	if sq < 0 or C.result(state) != C.ONGOING:
		return
	if _prefix.is_empty():
		_pick(sq)
		return
	if sq == _prefix[0]:
		_prefix = PackedInt32Array()  # Put the piece back.
		queue_redraw()
		return
	if targets().has(sq):
		_prefix.append(sq)
		for m: C.Move in _candidates():
			if m.path == _prefix:
				_complete(m)
				return
		played.emit("hop")
		queue_redraw()
		return
	if _prefix.size() == 1 and movable().has(sq):
		_pick(sq)  # Another of your pieces.
		return
	played.emit("nope")


func _pick(sq: int) -> void:
	if not movable().has(sq):
		played.emit("nope")
		return
	_prefix = PackedInt32Array([sq])
	played.emit("pick")
	queue_redraw()


func _complete(m: C.Move) -> void:
	var start := maxi(0, _prefix.size() - 2)
	_prefix = PackedInt32Array()
	before_move.emit(state)
	_play(m, start)
	human_moved.emit(m.path)


## Your pieces that have a move now.
func movable() -> PackedInt32Array:
	var out := PackedInt32Array()
	for m: C.Move in _allowed_moves():
		if not out.has(m.from_sq()):
			out.append(m.from_sq())
	return out


## The squares the picked piece may land on next.
func targets() -> PackedInt32Array:
	var out := PackedInt32Array()
	var n := _prefix.size()
	if n == 0:
		return out
	for m: C.Move in _candidates():
		if m.path.size() > n and not out.has(m.path[n]):
			out.append(m.path[n])
	return out


## The pieces already jumped in the chain being chosen.
func _taken_so_far() -> PackedInt32Array:
	var cands := _candidates()
	if cands.is_empty() or _prefix.size() < 2:
		return PackedInt32Array()
	var m: C.Move = cands[0]
	return m.captured.slice(0, _prefix.size() - 1)


# ---------- Animation ----------

## Plays `m` in place, animating it from path square `start` (earlier landings were
## already shown while the player chose them).
func _play(m: C.Move, start: int) -> void:
	_anim_move = m
	_anim_piece = state.board[m.from_sq()]
	var before := state.board.duplicate()
	state = C.after(state, m)
	_moves = C.legal_moves(state)
	_anim_points = []
	_anim_hops = []
	_anim_ends = []
	_anim_taken = []
	var t := 0.0
	var speed := 0.5 if reduce_motion else 1.0
	for i in range(start, m.path.size()):
		_anim_points.append(square_pos(m.path[i]))
	for i in range(start, m.path.size() - 1):
		var hop := m.is_capture()
		var a: Vector2 = square_pos(m.path[i])
		var b: Vector2 = square_pos(m.path[i + 1])
		var steps := maxf(1.0, a.distance_to(b) / (cell * sqrt(2.0)))
		t += (HOP_LEN if hop else SLIDE_LEN * sqrt(steps)) * speed
		_anim_hops.append(hop)
		_anim_ends.append(t)
		if hop:
			_anim_taken.append([m.captured[i], before[m.captured[i]], t])
	_anim_t = 0.0
	_anim_len = t + (0.0 if reduce_motion else FADE_LEN)
	_crown_t = -1.0
	busy = true
	played.emit("hop" if m.is_capture() else "move")
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _crown_t >= 0.0:
		_crown_t += delta
	if busy:
		var before := _anim_t
		_anim_t += delta
		for e: Array in _anim_taken:
			if before < float(e[2]) and _anim_t >= float(e[2]):
				played.emit("capture")
		if _anim_t >= _anim_len:
			_finish()
	if busy or _pulsing() or (_crown_t >= 0.0 and _crown_t < 0.4):
		queue_redraw()


func _finish() -> void:
	busy = false
	if _anim_move != null and C.is_king(state.board[_anim_move.to_sq()]) and not C.is_king(_anim_piece):
		_crown_t = 0.0
		played.emit("crown")
	_anim_move = null
	queue_redraw()
	changed.emit()
	if C.result(state) != C.ONGOING:
		played.emit("end")


func _pulsing() -> bool:
	return not focus_points.is_empty() or not _prefix.is_empty() or (show_hints and interactive and state != null and C.result(state) == C.ONGOING)


## Where the moving piece is drawn now.
func _anim_pos() -> Vector2:
	if _anim_points.size() < 2:
		return _anim_points[0] if not _anim_points.is_empty() else Vector2.ZERO
	var t0 := 0.0
	for i in _anim_ends.size():
		var t1: float = _anim_ends[i]
		if _anim_t <= t1 or i == _anim_ends.size() - 1:
			var k := clampf((_anim_t - t0) / maxf(t1 - t0, 0.001), 0.0, 1.0)
			var a: Vector2 = _anim_points[i]
			var b: Vector2 = _anim_points[i + 1]
			if _anim_hops[i]:
				return a.lerp(b, k) - Vector2(0, sin(k * PI) * cell * 0.35)
			var e := k * k * (3.0 - 2.0 * k)  # Ease in and out.
			return a.lerp(b, e)
		t0 = t1
	return _anim_points[_anim_points.size() - 1]


# ---------- Drawing ----------

func _draw() -> void:
	if state == null or frame.size == Vector2.ZERO:
		return
	if not compact:
		_draw_meadow()
	_draw_board()
	var pulse := 0.5 + 0.5 * sin(_time * 3.4)
	# The last move: its squares tinted, the landing square ringed.
	if not state.last_move.is_empty() and not busy and _prefix.is_empty():
		for sq in state.last_move:
			_tint(sq, Color(LAST, 0.22))
	var hidden := -1  ## A square whose piece is drawn elsewhere (moving or picked up).
	if busy and _anim_move != null:
		hidden = _anim_move.to_sq()
	elif not _prefix.is_empty():
		hidden = _prefix[0]
	var dimmed := _taken_so_far()
	for sq in C.SQUARES:
		var piece := state.board[sq]
		if piece == C.EMPTY or sq == hidden:
			continue
		_draw_piece(square_pos(sq), piece, 0.35 if dimmed.has(sq) else 1.0)
	# Pieces being taken: shown until the mover passes, then lifting away.
	if busy:
		for e: Array in _anim_taken:
			var since := _anim_t - float(e[2])
			if since < FADE_LEN:
				var k := clampf(since / FADE_LEN, 0.0, 1.0) if since > 0.0 else 0.0
				_draw_piece(square_pos(e[0]) - Vector2(0, k * cell * 0.25), int(e[1]), 1.0 - k)
	# Hints: your movable pieces glow; once one is picked, its landing squares do.
	var hinting := show_hints and interactive and not busy and C.result(state) == C.ONGOING
	if _prefix.is_empty():
		if hinting:
			for sq in movable():
				_ring(square_pos(sq), cell * (PIECE_R + 0.05 + 0.02 * pulse), Color(HINT, 0.35 + 0.4 * pulse), cell * 0.045)
		if not state.last_move.is_empty() and not busy:
			var to := state.last_move[state.last_move.size() - 1]
			if state.board[to] != C.EMPTY:
				_ring(square_pos(to), cell * (PIECE_R + 0.06), Color(LAST, 0.95), cell * 0.05)
	else:
		var at := square_pos(_prefix[_prefix.size() - 1])
		for sq in targets():
			var c := square_pos(sq)
			draw_circle(c, cell * (0.17 + 0.03 * pulse), Color(HINT, 0.14 + 0.12 * pulse), true, -1.0, true)
			draw_circle(c, cell * 0.09, Color(HINT, 0.6 + 0.35 * pulse), true, -1.0, true)
		var piece := state.board[_prefix[0]]
		_draw_piece(at - Vector2(0, cell * 0.08), piece, 1.0, 0.08)  # Picked up.
		_ring(at - Vector2(0, cell * 0.08), cell * (PIECE_R + 0.06), Color(HINT, 0.9), cell * 0.05)
	for p in focus_points:
		_ring(square_pos(p), cell * (0.45 + 0.02 * pulse), Color(FOCUS, 0.55 + 0.45 * pulse), cell * 0.06)
	if busy and _anim_move != null:
		var lift := 0.06 if _anim_move.is_capture() else 0.03
		_draw_piece(_anim_pos(), _anim_piece, 1.0, lift)


func _tint(sq: int, color: Color) -> void:
	var c := square_pos(sq)
	draw_rect(Rect2(c - Vector2(cell, cell) * 0.5, Vector2(cell, cell)), color)


## A checker: shadow, dark rim, face, two ridges and a little shine; a crown on a king.
## `lift` raises it off the board (picked up, or moving).
func _draw_piece(c: Vector2, piece: int, alpha := 1.0, lift := 0.0) -> void:
	var tones: Array = PIECES[C.owner(piece)]
	var r := cell * PIECE_R
	draw_circle(c + Vector2(0, r * 0.12 + lift * cell * 0.6), r * (1.0 - lift), Color(0, 0, 0, 0.25 * alpha), true, -1.0, true)
	var top := c - Vector2(0, lift * cell)
	draw_circle(top + Vector2(0, r * 0.08), r, Color(tones[1], alpha), true, -1.0, true)  # The side.
	draw_circle(top, r, Color(tones[1], alpha), true, -1.0, true)
	draw_circle(top, r * 0.9, Color(tones[0], alpha), true, -1.0, true)
	draw_arc(top, r * 0.72, 0.0, TAU, 36, Color(tones[2], alpha), r * 0.07, true)
	draw_arc(top, r * 0.5, 0.0, TAU, 30, Color(tones[2], alpha * 0.8), r * 0.05, true)
	draw_arc(top, r * 0.8, PI * 1.15, PI * 1.55, 10, Color(1, 1, 1, 0.3 * alpha), r * 0.08, true)
	if C.is_king(piece):
		var grow := 1.0
		if _crown_t >= 0.0 and _crown_t < 0.3 and _anim_move == null and state.last_move.size() > 0 \
				and top.distance_to(square_pos(state.last_move[state.last_move.size() - 1])) < 1.0:
			var k := _crown_t / 0.3
			grow = 0.4 + 0.6 * k + sin(k * PI) * 0.25  # A little pop.
		_draw_crown(top, r * 0.66 * grow, alpha)


func _draw_crown(c: Vector2, w: float, alpha: float) -> void:
	var h := w * 0.75
	var base := c + Vector2(0, h * 0.45)
	var pts := PackedVector2Array([
		base + Vector2(-w, 0), base + Vector2(-w, -h * 0.55), base + Vector2(-w * 0.55, -h * 0.2),
		base + Vector2(0, -h), base + Vector2(w * 0.55, -h * 0.2), base + Vector2(w, -h * 0.55),
		base + Vector2(w, 0),
	])
	draw_colored_polygon(pts, Color(CROWN, alpha))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(CROWN_EDGE, alpha), maxf(1.0, w * 0.12), true)
	for x: float in [-w, 0.0, w]:
		var tip := base + Vector2(x, -h if x == 0.0 else -h * 0.55)
		draw_circle(tip, w * 0.13, Color(CROWN, alpha), true, -1.0, true)


func _draw_board() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = WOOD
	sb.set_corner_radius_all(int(cell * 0.3))
	sb.set_border_width_all(int(maxf(2.0, cell * 0.05)))
	sb.border_color = WOOD_EDGE
	sb.shadow_color = SHADOW
	sb.shadow_size = int(cell * 0.16)
	sb.shadow_offset = Vector2(0, cell * 0.12)
	sb.anti_aliasing = true
	draw_style_box(sb, frame)
	var shine := StyleBoxFlat.new()
	shine.bg_color = Color(0, 0, 0, 0)
	shine.set_corner_radius_all(int(cell * 0.24))
	shine.border_width_top = int(maxf(2.0, cell * 0.04))
	shine.border_color = Color(WOOD_SHINE, 0.8)
	shine.anti_aliasing = true
	draw_style_box(shine, frame.grow(-cell * 0.07))
	var inner := frame.grow(-MARGIN * cell)
	for k in 2:
		var off := cell * (0.13 + 0.14 * k)
		_grain(Vector2(frame.position.x + cell * 0.3, frame.position.y + off), Vector2(frame.end.x - cell * 0.3, frame.position.y + off), k)
		_grain(Vector2(frame.position.x + cell * 0.3, frame.end.y - off), Vector2(frame.end.x - cell * 0.3, frame.end.y - off), k + 2)
		_grain(Vector2(frame.position.x + off, inner.position.y), Vector2(frame.position.x + off, inner.end.y), k + 4)
		_grain(Vector2(frame.end.x - off, inner.position.y), Vector2(frame.end.x - off, inner.end.y), k + 6)
	draw_rect(inner.grow(cell * 0.04), WOOD_EDGE)
	draw_rect(inner, LIGHT)
	for row in 8:
		for col in 8:
			if (col + row) % 2 == 0:
				var c := cell_pos(col, row)
				var r := Rect2(c - Vector2(cell, cell) * 0.5, Vector2(cell, cell))
				draw_rect(r, DARK)
				draw_rect(r.grow(-cell * 0.03), DARK_EDGE, false, maxf(1.0, cell * 0.02))
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, cell * 0.06)), Color(0, 0, 0, 0.1))


func _grain(a: Vector2, b: Vector2, seed_k: int) -> void:
	var pts := PackedVector2Array()
	var steps := 24
	var across := (b - a).orthogonal().normalized()
	for i in steps + 1:
		var t := float(i) / steps
		pts.append(a.lerp(b, t) + across * sin(t * 9.0 + seed_k * 1.7) * cell * 0.025)
	draw_polyline(pts, Color(GRAIN, 0.3), maxf(1.0, cell * 0.016), true)


## Grass tufts and daisies scattered on the meadow around the board.
func _draw_meadow() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 29
	var spots := int(_area.x * _area.y / (cell * cell) * 0.5)
	var keep_out := frame.grow(cell * 0.3)
	for i in spots:
		var p := Vector2(rng.randf() * _area.x, rng.randf() * _area.y)
		var daisy := rng.randf() < 0.22
		var h := cell * rng.randf_range(0.14, 0.2)
		if keep_out.has_point(p):
			continue
		if daisy:
			_daisy(p, cell * 0.07)
		else:
			_tuft(p, h)


func _tuft(base: Vector2, h: float) -> void:
	var pts := PackedVector2Array()
	for k in 7:
		var up := (h if k % 2 == 1 else 0.0) + (h * 0.3 if k == 3 else 0.0)
		pts.append(base + Vector2((k - 3) * h * 0.25, -up))
	draw_polyline(pts, GRASS, maxf(1.5, cell * 0.022), true)


func _daisy(c: Vector2, r: float) -> void:
	for k in 5:
		var a := TAU * k / 5.0
		draw_circle(c + Vector2(cos(a), sin(a)) * r, r * 0.75, FLOWER, true, -1.0, true)
	draw_circle(c, r * 0.6, FLOWER_EYE, true, -1.0, true)


func _ring(c: Vector2, r: float, color: Color, width: float) -> void:
	draw_arc(c, r, 0.0, TAU, 40, color, width, true)


## Redraws the glows, e.g. after the computer's move hands the turn back.
func refresh_targets() -> void:
	_moves = C.legal_moves(state) if state != null else []
	queue_redraw()
