extends Node2D
## The Four in a Row board (DISCUSSION.md section 31, D70): an upright wooden frame
## standing on feet in a strip of meadow, 7 columns × 6 rows of round holes, with orange
## discs for the player who moves first and cream discs for the other. A dropped disc
## falls down its column and settles with a small bounce; the winning four (or more)
## glow and are joined by a line. Tap anywhere in a column, on the frame or just above
## it, to drop a disc there. Tapping while a disc is falling skips to where it lands.

signal played(kind: String)  ## "drop" (a disc starts falling), "land", "win", "nope"
signal changed  ## The position on screen has settled (after a move, or a new position).
signal before_move(state_before)  ## A human move is about to be played; used for undo.
signal human_moved(col: int)  ## A move the player made by tapping (sent to the server online).

const F := preload("res://games/fourinrow/four_rules.gd")

const GROUND := Color("#C9DCAE")
const GROUND_DARK := Color("#B9CF9B")
const GRASS := Color("#6E9A4C")
const FLOWER := Color("#FFF8E8")
const FLOWER_EYE := Color("#F6C66B")
const WOOD := Color("#B98450")
const WOOD_EDGE := Color("#8A5A2E")
const WOOD_SHINE := Color("#D2A06A")
const GRAIN := Color("#A57140")
const HOLE := Color("#A9C48A")  ## The meadow seen through an empty hole.
const HOLE_SHADE := Color("#7E9A62")
const SHADOW := Color(0.2, 0.12, 0.05, 0.28)
const HINT := Color("#FFFFFF")
const FOCUS := Color("#E26F2A")
const LAST := Color("#F6C66B")
const WIN_GLOW := Color("#FFF4C2")
## Disc colours: [face, rim, inner ring] for player 0 (moves first) and player 1.
const DISCS := [
	[Color("#E8782F"), Color("#B9561C"), Color("#F39A5A")],
	[Color("#FBF1DC"), Color("#CDB58C"), Color("#E8D9B8")],
]

const MARGIN := 0.36  ## Frame border around the holes, in cells.
const HOLE_R := 0.4  ## Hole radius, in cells.
const DISC_R := 0.37  ## Disc radius, in cells.
const TOP_ROOM := 1.0  ## Space above the frame for a disc to start falling from, in cells.
const FEET := 0.75  ## Feet and ground below the frame, in cells.

var state: F.State
var interactive := true  ## False for the result screen and while the computer thinks.
var show_hints := true
var reduce_motion := false
var only_moves := PackedInt32Array()  ## When set, only these columns may be played (tutorial).
var focus_points := PackedInt32Array()  ## Cells (Grid numbering) ringed in orange (tutorial, puzzles).
var busy := false  ## A disc is falling.
var compact := false  ## Small previews: just the frame, a thin strip of ground.
var cell := 100.0  ## Distance between hole centres in pixels; everything is sized from it.
var frame := Rect2()

var _area := Vector2.ZERO
var _time := 0.0
var _win_cells := PackedInt32Array()
var _win_time := 0.0
var _fall_col := -1  ## The falling disc: column, row it lands on, owner, progress.
var _fall_row := -1
var _fall_who := 0
var _fall_t := 0.0
var _fall_len := 0.0
var _fall_drop := 0.0  ## Share of the animation spent falling; the rest is the bounce.


func new_game() -> void:
	set_state(F.new_game())


## Shows any position without animation (new game, restored game, result screen).
func set_state(s: F.State) -> void:
	state = s
	busy = false
	_fall_col = -1
	_win_cells = F.winning_cells(s)
	_win_time = 0.0
	queue_redraw()
	changed.emit()


## Plays a move chosen elsewhere (the computer, the other player online), animated.
func play_move(col: int) -> void:
	if busy:
		skip()
	_play(col)


## Jumps to the end of the disc's fall.
func skip() -> void:
	if busy:
		_land()


func layout(area: Vector2) -> void:
	_area = area
	var wide := F.COLS + MARGIN * 2.0 + 0.9
	var tall := F.ROWS + MARGIN * 2.0 + (0.25 if compact else TOP_ROOM + FEET)
	cell = minf(area.x / wide, area.y / tall)
	var size := Vector2(F.COLS + MARGIN * 2.0, F.ROWS + MARGIN * 2.0) * cell
	var top := (area.y - tall * cell) / 2.0 + (0.0 if compact else TOP_ROOM * cell)
	frame = Rect2(Vector2((area.x - size.x) / 2.0, top), size)
	queue_redraw()


# ---------- Geometry ----------

## Centre of the hole at a column and row (row 0 at the bottom).
func cell_pos(col: int, row: int) -> Vector2:
	return frame.position + Vector2(MARGIN + col + 0.5, MARGIN + (F.ROWS - 1 - row) + 0.5) * cell


## The column under a tap: anywhere across the column, on the frame or above it.
func column_at(pos: Vector2) -> int:
	if pos.x < frame.position.x + MARGIN * cell * 0.5 or pos.x > frame.end.x - MARGIN * cell * 0.5:
		return -1
	if pos.y < frame.position.y - TOP_ROOM * cell or pos.y > frame.end.y + cell * 0.2:
		return -1
	return clampi(int((pos.x - frame.position.x - MARGIN * cell) / cell), 0, F.COLS - 1)


# ---------- Input ----------

func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or state == null:
		return
	var local := (make_input_local(event) as InputEventMouseButton).position
	var col := column_at(local)
	if col < 0:
		return
	get_viewport().set_input_as_handled()
	if busy:
		skip()
		return
	if interactive:
		_tap(col)


func _tap(col: int) -> void:
	if busy:
		skip()
		return
	if col < 0 or F.result(state) != F.ONGOING:
		return
	if not _allowed(col):
		played.emit("nope")
		return
	before_move.emit(state)
	_play(col)
	human_moved.emit(col)


func _allowed(col: int) -> bool:
	return F.can_drop(state, col) and (only_moves.is_empty() or only_moves.has(col))


# ---------- Animation ----------

func _play(col: int) -> void:
	_fall_who = state.turn
	state = F.after(state, col)
	_fall_col = col
	_fall_row = state.heights[col] - 1
	# Falls from just above the frame: farther falls take a little longer, like gravity.
	var rows_down := float(F.ROWS - _fall_row) + MARGIN + 0.6
	var fall := 0.11 * sqrt(rows_down) * (0.6 if reduce_motion else 1.0)
	var bounce := 0.0 if reduce_motion else 0.14
	_fall_len = fall + bounce
	_fall_drop = fall / _fall_len
	_fall_t = 0.0
	busy = true
	played.emit("drop")
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if busy:
		_fall_t += delta
		if _fall_t >= _fall_len:
			_land()
	if not _win_cells.is_empty():
		_win_time += delta
	if busy or _pulsing():
		queue_redraw()


func _land() -> void:
	busy = false
	_fall_col = -1
	played.emit("land")
	_win_cells = F.winning_cells(state)
	_win_time = 0.0
	if not _win_cells.is_empty():
		played.emit("win")
	queue_redraw()
	changed.emit()


func _pulsing() -> bool:
	return not focus_points.is_empty() or not _win_cells.is_empty() or (show_hints and interactive and state != null and F.result(state) == F.ONGOING)


## Where the falling disc is drawn now: down the column, then a small hop on landing.
func _fall_pos() -> Vector2:
	var start := Vector2(cell_pos(_fall_col, 0).x, frame.position.y - cell * 0.55)
	var end := cell_pos(_fall_col, _fall_row)
	var t := _fall_t / maxf(_fall_len, 0.001)
	if t < _fall_drop:
		var k := t / _fall_drop
		return start.lerp(end, k * k)
	var b := (t - _fall_drop) / maxf(1.0 - _fall_drop, 0.001)
	return end - Vector2(0, sin(b * PI) * cell * 0.16)


# ---------- Drawing ----------

func _draw() -> void:
	if state == null or frame.size == Vector2.ZERO:
		return
	_draw_ground()
	if not compact:
		_draw_feet()
	_draw_frame()
	var pulse := 0.5 + 0.5 * sin(_time * 3.4)
	var hints := show_hints and interactive and not busy and F.result(state) == F.ONGOING
	for col in F.COLS:
		for row in F.ROWS:
			var c := cell_pos(col, row)
			_draw_hole(c)
			var who := F.owner_at(state, col, row)
			if who >= 0 and not (col == _fall_col and row == _fall_row):
				_draw_disc(c, who)
		if hints and _allowed(col):
			var land := cell_pos(col, state.heights[col])
			_ring(land, cell * (HOLE_R + 0.03 + 0.02 * pulse), Color(HINT, 0.4 + 0.45 * pulse), cell * 0.045)
	if state.last_move >= 0 and not busy and _win_cells.is_empty():
		var col := state.last_move
		_ring(cell_pos(col, state.heights[col] - 1), cell * (DISC_R + 0.06), Color(LAST, 0.95), cell * 0.05)
	for p in focus_points:
		var c := cell_pos(Grid.col_of(F.COLS, p), Grid.row_of(F.COLS, p))
		_ring(c, cell * (HOLE_R + 0.08 + 0.03 * pulse), Color(FOCUS, 0.55 + 0.45 * pulse), cell * 0.06)
	if not _win_cells.is_empty() and not busy:
		_draw_win(pulse)
	if busy and _fall_col >= 0:
		_draw_disc(_fall_pos(), _fall_who)


func _draw_ground() -> void:
	# A strip of meadow the frame stands in, edge to edge, with grass and a few daisies.
	var top := maxf(0.0, frame.position.y + frame.size.y * (0.45 if not compact else 0.2))
	var bot := minf(_area.y, frame.end.y + (FEET + 0.1 if not compact else 0.25) * cell)
	draw_rect(Rect2(0, top, _area.x, bot - top), GROUND)
	draw_rect(Rect2(0, bot - cell * 0.08, _area.x, cell * 0.08), GROUND_DARK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var spots := int(_area.x / cell * 5.0)
	for i in spots:
		var p := Vector2(rng.randf() * _area.x, rng.randf_range(top + cell * 0.2, bot - cell * 0.1))
		if frame.grow(cell * 0.2).has_point(p) or _under_feet(p):
			continue
		if rng.randf() < 0.8:
			_tuft(p, cell * rng.randf_range(0.14, 0.2))
		else:
			_daisy(p, cell * 0.07)


func _under_feet(p: Vector2) -> bool:
	for side: int in [-1, 1]:
		var x := frame.get_center().x + side * (frame.size.x * 0.5 - cell * 1.3)
		if absf(p.x - x) < cell * 0.9 and p.y > frame.end.y - cell * 0.2 and p.y < frame.end.y + FEET * cell:
			return true
	return false


## Two wooden feet that keep the frame upright, resting on the grass with a soft shadow.
func _draw_feet() -> void:
	var y := frame.end.y
	var foot_h := cell * 0.42
	for side: int in [-1, 1]:
		var x := frame.get_center().x + side * (frame.size.x * 0.5 - cell * 1.3)
		_ellipse(Vector2(x, y + foot_h + cell * 0.04), Vector2(cell * 0.85, cell * 0.12), Color(SHADOW, 0.35))
		var foot := PackedVector2Array([
			Vector2(x - cell * 0.28, y - cell * 0.05), Vector2(x + cell * 0.28, y - cell * 0.05),
			Vector2(x + cell * 0.7, y + foot_h), Vector2(x - cell * 0.7, y + foot_h),
		])
		draw_colored_polygon(foot, WOOD_EDGE)
		var inner := PackedVector2Array([
			Vector2(x - cell * 0.22, y), Vector2(x + cell * 0.22, y),
			Vector2(x + cell * 0.6, y + foot_h - cell * 0.07), Vector2(x - cell * 0.6, y + foot_h - cell * 0.07),
		])
		draw_colored_polygon(inner, WOOD)


func _draw_frame() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = WOOD
	sb.set_corner_radius_all(int(cell * 0.45))
	sb.set_border_width_all(int(maxf(2.0, cell * 0.05)))
	sb.border_color = WOOD_EDGE
	sb.shadow_color = SHADOW
	sb.shadow_size = int(cell * 0.14)
	sb.shadow_offset = Vector2(0, cell * 0.1)
	sb.anti_aliasing = true
	draw_style_box(sb, frame)
	var shine := StyleBoxFlat.new()
	shine.bg_color = Color(0, 0, 0, 0)
	shine.set_corner_radius_all(int(cell * 0.38))
	shine.border_width_top = int(maxf(2.0, cell * 0.04))
	shine.border_color = Color(WOOD_SHINE, 0.8)
	shine.anti_aliasing = true
	draw_style_box(shine, frame.grow(-cell * 0.08))
	# Soft vertical grain between the columns, as on a plank frame.
	for k in F.COLS + 1:
		var x := frame.position.x + (MARGIN + k) * cell
		var pts := PackedVector2Array()
		var steps := 20
		for i in steps + 1:
			var y := lerpf(frame.position.y + cell * 0.25, frame.end.y - cell * 0.25, float(i) / steps)
			pts.append(Vector2(x + sin(y / cell * 1.1 + k * 1.9) * cell * 0.04, y))
		draw_polyline(pts, Color(GRAIN, 0.3), maxf(1.0, cell * 0.016), true)


## A hole through the frame: the meadow behind, shaded along its top edge.
func _draw_hole(c: Vector2) -> void:
	var r := cell * HOLE_R
	draw_circle(c + Vector2(0, r * 0.06), r * 1.08, Color(WOOD_SHINE, 0.85), true, -1.0, true)
	draw_circle(c, r * 1.04, WOOD_EDGE, true, -1.0, true)
	draw_circle(c, r, HOLE, true, -1.0, true)
	draw_arc(c, r * 0.9, PI * 1.08, PI * 1.92, 20, Color(HOLE_SHADE, 0.7), r * 0.2, true)


## A disc: face, darker rim, a raised inner ring and a little shine.
func _draw_disc(c: Vector2, who: int) -> void:
	var tones: Array = DISCS[who]
	var r := cell * DISC_R
	draw_circle(c + Vector2(0, r * 0.1), r, Color(0, 0, 0, 0.2), true, -1.0, true)
	draw_circle(c, r, tones[1], true, -1.0, true)
	draw_circle(c, r * 0.9, tones[0], true, -1.0, true)
	draw_arc(c, r * 0.6, 0.0, TAU, 32, tones[2], r * 0.1, true)
	draw_arc(c, r * 0.72, PI * 1.15, PI * 1.55, 10, Color(1, 1, 1, 0.55), r * 0.1, true)


func _draw_win(pulse: float) -> void:
	var pts := PackedVector2Array()
	for p in _win_cells:
		pts.append(cell_pos(Grid.col_of(F.COLS, p), Grid.row_of(F.COLS, p)))
	# Light up each winning disc, then join them with a glowing stroke.
	var grow := minf(1.0, _win_time / 0.35)
	for c in pts:
		_ring(c, cell * (DISC_R + 0.08 + 0.03 * pulse), Color(WIN_GLOW, (0.6 + 0.4 * pulse) * grow), cell * 0.08)
	if pts.size() >= 2:
		var a := pts[0]
		var b := pts[pts.size() - 1]
		for c in pts:  # The two discs farthest apart are the ends of the line.
			for d in pts:
				if c.distance_to(d) > a.distance_to(b):
					a = c
					b = d
		draw_line(a, a.lerp(b, grow), Color(WIN_GLOW, 0.75), cell * 0.12, true)


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


func _ellipse(c: Vector2, r: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, color)


## Recomputes the glowing columns, e.g. after the computer's move hands the turn back.
func refresh_targets() -> void:
	queue_redraw()
