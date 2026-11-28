extends Node2D
## The Reversi board (DISCUSSION.md section 32, D74–D75): a wooden tray lying in the
## meadow, 8 × 8 grass-green squares, with orange discs for the player who moves first and
## cream discs for the other (the same discs as Four in a Row). A new disc settles into
## its square, then the discs it traps turn over with a little spin, one after another
## outwards along each line. Glowing dots show where the player to move may play, when
## hints are on (D75). Tap a square to play there; tapping while discs are turning skips
## to the end.

signal played(kind: String)  ## "place", "flip" (the first trapped disc starts turning), "pass", "end", "nope"
signal changed  ## The position on screen has settled (after a move, or a new position).
signal before_move(state_before)  ## A human move is about to be played; used for undo.
signal human_moved(square: int)  ## A move the player made by tapping (sent to the server online).

const R := preload("res://games/reversi/reversi_rules.gd")

const GRASS := Color("#6E9A4C")
const FLOWER := Color("#FFF8E8")
const FLOWER_EYE := Color("#F6C66B")
const WOOD := Color("#B98450")
const WOOD_EDGE := Color("#8A5A2E")
const WOOD_SHINE := Color("#D2A06A")
const GRAIN := Color("#A57140")
const FIELD := Color("#79A852")  ## The grass squares.
const FIELD_ALT := Color("#72A04C")  ## Every other square, a shade darker, like mown grass.
const GROOVE := Color("#527D36")  ## The lines between squares.
const STAR := Color("#4B7130")  ## The four small marks inside the board.
const SHADOW := Color(0.2, 0.12, 0.05, 0.28)
const HINT := Color("#FFFFFF")
const FOCUS := Color("#E26F2A")
const LAST := Color("#F6C66B")
const DISC_EDGE := Color("#C98F52")  ## The side of a disc, seen while it turns over.
## Disc colours: [face, rim, inner ring] for player 0 (moves first) and player 1.
const DISCS := [
	[Color("#E8782F"), Color("#B9561C"), Color("#F39A5A")],
	[Color("#FBF1DC"), Color("#CDB58C"), Color("#E8D9B8")],
]

const MARGIN := 0.42  ## Wooden border around the squares, in cells.
const DISC_R := 0.4  ## Disc radius, in cells.
const PLACE_LEN := 0.16  ## Seconds for a new disc to settle.
const FLIP_LEN := 0.3  ## Seconds for one disc to turn over.
const FLIP_GAP := 0.07  ## Delay between neighbouring discs along a line.

var state: R.State
var interactive := true  ## False for the result screen and while the computer thinks.
var show_hints := true
var reduce_motion := false
var only_moves := PackedInt32Array()  ## When set, only these squares may be played (tutorial).
var focus_points := PackedInt32Array()  ## Squares ringed in orange (tutorial, puzzles).
var busy := false  ## Discs are settling or turning over.
var compact := false  ## Small previews: just the tray, no grass around it.
var cell := 100.0  ## Width of one square in pixels; everything is sized from it.
var frame := Rect2()  ## The whole tray, border included.

var _area := Vector2.ZERO
var _time := 0.0
var _anim_t := 0.0
var _anim_len := 0.0
var _flip_len := FLIP_LEN
var _placed := -1  ## The square just played, while it settles.
var _mover := 0  ## Who played it.
var _flips := {}  ## Square -> seconds after the move when it starts turning over.
var _flip_sent := false


func new_game() -> void:
	set_state(R.new_game())


## Shows any position without animation (new game, restored game, result screen).
func set_state(s: R.State) -> void:
	state = s
	busy = false
	_placed = -1
	_flips = {}
	queue_redraw()
	changed.emit()


## Plays a move chosen elsewhere (the computer, the other player online), animated.
## A pass (R.PASS) changes no discs; it is announced with played("pass").
func play_move(m: int) -> void:
	if busy:
		skip()
	_play(m)


## Jumps to the end of the discs turning over.
func skip() -> void:
	if busy:
		_finish()


func layout(area: Vector2) -> void:
	_area = area
	var wide := R.SIZE + MARGIN * 2.0 + (0.1 if compact else 0.6)
	cell = minf(area.x / wide, area.y / wide)
	var side := (R.SIZE + MARGIN * 2.0) * cell
	frame = Rect2((area - Vector2(side, side)) / 2.0, Vector2(side, side))
	queue_redraw()


# ---------- Geometry ----------

## Centre of a square (row 0 at the bottom, as the rules number them).
func cell_pos(col: int, row: int) -> Vector2:
	return frame.position + Vector2(MARGIN + col + 0.5, MARGIN + (R.SIZE - 1 - row) + 0.5) * cell


func square_pos(sq: int) -> Vector2:
	return cell_pos(sq % R.SIZE, floori(sq / float(R.SIZE)))


## The square under a tap, or -1 off the squares.
func square_at(pos: Vector2) -> int:
	var p := (pos - frame.position) / cell - Vector2(MARGIN, MARGIN)
	if p.x < 0.0 or p.y < 0.0 or p.x >= R.SIZE or p.y >= R.SIZE:
		return -1
	return R.cell(int(p.x), R.SIZE - 1 - int(p.y))


# ---------- Input ----------

func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or state == null:
		return
	var local := (make_input_local(event) as InputEventMouseButton).position
	var sq := square_at(local)
	if sq < 0:
		return
	get_viewport().set_input_as_handled()
	if busy:
		skip()
		return
	if interactive:
		_tap(sq)


func _tap(sq: int) -> void:
	if busy:
		skip()
		return
	if sq < 0 or R.result(state) != R.ONGOING:
		return
	if not _allowed(sq):
		played.emit("nope")
		return
	before_move.emit(state)
	_play(sq)
	human_moved.emit(sq)


func _allowed(sq: int) -> bool:
	return R.legal_moves(state).has(sq) and (only_moves.is_empty() or only_moves.has(sq))


## The squares to show glowing dots on now.
func hint_squares() -> PackedInt32Array:
	var out := PackedInt32Array()
	if not (show_hints and interactive and not busy and state != null):
		return out
	for m in R.legal_moves(state):
		if m != R.PASS and (only_moves.is_empty() or only_moves.has(m)):
			out.append(m)
	return out


# ---------- Animation ----------

func _play(m: int) -> void:
	_mover = state.turn
	state = state.copy()  # The position before stays as it was, for undo.
	var flipped := R.play(state, m)
	if m == R.PASS:
		played.emit("pass")
		queue_redraw()
		changed.emit()
		_check_end()
		return
	_placed = m
	_flips = {}
	_flip_len = 0.0 if reduce_motion else FLIP_LEN
	var mc := m % R.SIZE
	var mr := floori(m / float(R.SIZE))
	_anim_len = PLACE_LEN
	for f in flipped:
		# Neighbours turn first, then outwards along each line.
		var steps := maxi(absi(f % R.SIZE - mc), absi(floori(f / float(R.SIZE)) - mr))
		var start := PLACE_LEN * 0.6 + (0.0 if reduce_motion else FLIP_GAP * (steps - 1))
		_flips[f] = start
		_anim_len = maxf(_anim_len, start + _flip_len + 0.02)
	_anim_t = 0.0
	_flip_sent = false
	busy = true
	played.emit("place")
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if busy:
		_anim_t += delta
		if not _flip_sent and not _flips.is_empty() and _anim_t >= PLACE_LEN * 0.6:
			_flip_sent = true
			played.emit("flip")
		if _anim_t >= _anim_len:
			_finish()
	if busy or _pulsing():
		queue_redraw()


func _finish() -> void:
	busy = false
	_placed = -1
	_flips = {}
	queue_redraw()
	changed.emit()
	_check_end()


func _check_end() -> void:
	if R.result(state) != R.ONGOING:
		played.emit("end")


func _pulsing() -> bool:
	return not focus_points.is_empty() or not hint_squares().is_empty()


# ---------- Drawing ----------

func _draw() -> void:
	if state == null or frame.size == Vector2.ZERO:
		return
	if not compact:
		_draw_meadow()
	_draw_tray()
	var pulse := 0.5 + 0.5 * sin(_time * 3.4)
	for row in R.SIZE:
		for col in R.SIZE:
			var sq := R.cell(col, row)
			var who := R.owner_at(state, col, row)
			if who >= 0:
				_draw_square_disc(sq, who)
	for sq in hint_squares():
		var c := square_pos(sq)
		draw_circle(c, cell * (0.17 + 0.03 * pulse), Color(HINT, 0.12 + 0.12 * pulse), true, -1.0, true)
		draw_circle(c, cell * 0.09, Color(HINT, 0.55 + 0.4 * pulse), true, -1.0, true)
	if state.last_move >= 0 and state.last_move != R.PASS and not busy:
		_ring(square_pos(state.last_move), cell * (DISC_R + 0.05), Color(LAST, 0.95), cell * 0.05)
	for p in focus_points:
		_ring(square_pos(p), cell * (0.44 + 0.02 * pulse), Color(FOCUS, 0.55 + 0.45 * pulse), cell * 0.06)


## A disc in its square, settling or turning over while a move plays out.
func _draw_square_disc(sq: int, who: int) -> void:
	var c := square_pos(sq)
	if busy and sq == _placed:
		var k := clampf(_anim_t / PLACE_LEN, 0.0, 1.0)
		var ease_k := 1.0 - (1.0 - k) * (1.0 - k)
		_draw_disc(c, who, 1.0, 1.0 + 0.25 * (1.0 - ease_k), (1.0 - ease_k) * 0.6, ease_k)
		return
	if busy and _flips.has(sq):
		var t := 1.0 if _flip_len <= 0.0 else (_anim_t - float(_flips[sq])) / _flip_len
		if _flip_len <= 0.0 and _anim_t < float(_flips[sq]):
			t = 0.0
		if t <= 0.0:
			_draw_disc(c, 1 - _mover)
		elif t >= 1.0:
			_draw_disc(c, _mover)
		else:
			# Turning over: the disc narrows to its edge, lifts a little, and shows its
			# other face as it comes back.
			var lift := sin(t * PI)
			_draw_disc(c, 1 - _mover if t < 0.5 else _mover, absf(cos(t * PI)), 1.0 + 0.08 * lift, lift)
		return
	_draw_disc(c, who)


## A disc seen from above: face, darker rim, a raised inner ring and a little shine.
## `squash` narrows it sideways (turning over), `lift` raises it off the board.
func _draw_disc(c: Vector2, who: int, squash := 1.0, grow := 1.0, lift := 0.0, alpha := 1.0) -> void:
	var tones: Array = DISCS[who]
	var r := cell * DISC_R * grow
	var up := Vector2(0, -lift * cell * 0.1)
	var sx := maxf(squash, 0.1)
	draw_set_transform(c + Vector2(0, r * 0.1 + lift * cell * 0.04), 0.0, Vector2(maxf(squash, 0.35), 1.0))
	draw_circle(Vector2.ZERO, r * (1.0 - 0.1 * lift), Color(0, 0, 0, 0.22 * alpha * (1.0 - 0.4 * lift)), true, -1.0, true)
	draw_set_transform(c + up, 0.0, Vector2(sx, 1.0))
	if squash < 0.999:  # The edge of the disc shows as it turns.
		draw_set_transform(c + up + Vector2(cell * 0.03 * (1.0 - squash), 0), 0.0, Vector2(sx, 1.0))
		draw_circle(Vector2.ZERO, r, Color(DISC_EDGE, alpha), true, -1.0, true)
		draw_set_transform(c + up, 0.0, Vector2(sx, 1.0))
	draw_circle(Vector2.ZERO, r, Color(tones[1], alpha), true, -1.0, true)
	draw_circle(Vector2.ZERO, r * 0.9, Color(tones[0], alpha), true, -1.0, true)
	draw_arc(Vector2.ZERO, r * 0.6, 0.0, TAU, 32, Color(tones[2], alpha), r * 0.1, true)
	draw_arc(Vector2.ZERO, r * 0.72, PI * 1.15, PI * 1.55, 10, Color(1, 1, 1, 0.55 * alpha), r * 0.1, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Grass tufts and daisies scattered on the meadow around the tray.
func _draw_meadow() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
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


func _draw_tray() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = WOOD
	sb.set_corner_radius_all(int(cell * 0.34))
	sb.set_border_width_all(int(maxf(2.0, cell * 0.05)))
	sb.border_color = WOOD_EDGE
	sb.shadow_color = SHADOW
	sb.shadow_size = int(cell * 0.16)
	sb.shadow_offset = Vector2(0, cell * 0.12)
	sb.anti_aliasing = true
	draw_style_box(sb, frame)
	var shine := StyleBoxFlat.new()
	shine.bg_color = Color(0, 0, 0, 0)
	shine.set_corner_radius_all(int(cell * 0.28))
	shine.border_width_top = int(maxf(2.0, cell * 0.04))
	shine.border_color = Color(WOOD_SHINE, 0.8)
	shine.anti_aliasing = true
	draw_style_box(shine, frame.grow(-cell * 0.07))
	# Grain running along the four sides of the border.
	var inner := frame.grow(-MARGIN * cell)
	for k in 2:
		var off := cell * (0.13 + 0.14 * k)
		_grain(Vector2(frame.position.x + cell * 0.3, frame.position.y + off), Vector2(frame.end.x - cell * 0.3, frame.position.y + off), k)
		_grain(Vector2(frame.position.x + cell * 0.3, frame.end.y - off), Vector2(frame.end.x - cell * 0.3, frame.end.y - off), k + 2)
		_grain(Vector2(frame.position.x + off, inner.position.y), Vector2(frame.position.x + off, inner.end.y), k + 4)
		_grain(Vector2(frame.end.x - off, inner.position.y), Vector2(frame.end.x - off, inner.end.y), k + 6)
	# The playing field: a step down into the tray, then the grass squares.
	draw_rect(inner.grow(cell * 0.04), WOOD_EDGE)
	for row in R.SIZE:
		for col in R.SIZE:
			var r := Rect2(inner.position + Vector2(col, R.SIZE - 1 - row) * cell, Vector2(cell, cell))
			draw_rect(r, FIELD if (row + col) % 2 == 0 else FIELD_ALT)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, cell * 0.06)), Color(0, 0, 0, 0.12))
	var w := maxf(1.5, cell * 0.035)
	for k in range(1, R.SIZE):
		var x := inner.position.x + k * cell
		var y := inner.position.y + k * cell
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), GROOVE, w, true)
		draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), GROOVE, w, true)
	for p: Vector2 in [Vector2(2, 2), Vector2(6, 2), Vector2(2, 6), Vector2(6, 6)]:
		draw_circle(inner.position + p * cell, cell * 0.07, STAR, true, -1.0, true)


func _grain(a: Vector2, b: Vector2, seed_k: int) -> void:
	var pts := PackedVector2Array()
	var steps := 24
	var across := (b - a).orthogonal().normalized()
	for i in steps + 1:
		var t := float(i) / steps
		pts.append(a.lerp(b, t) + across * sin(t * 9.0 + seed_k * 1.7) * cell * 0.025)
	draw_polyline(pts, Color(GRAIN, 0.3), maxf(1.0, cell * 0.016), true)


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


## Redraws the dots, e.g. after the computer's move hands the turn back.
func refresh_targets() -> void:
	queue_redraw()
