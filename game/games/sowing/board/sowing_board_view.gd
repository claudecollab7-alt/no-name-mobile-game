extends Node2D
## The pits-and-seeds board (DISCUSSION.md section 29): a carved wooden tray resting on a
## patch of meadow, seeds drawn as small mixed pebbles. The player `bottom` has their row
## along the bottom of the screen. Moves are animated from the steps SowingRules.apply()
## records: a handful of seeds travels from pit to pit, leaving one in each, and captured
## seeds fly to the store (Kalah) or to the player's pile beside the tray (Pallanguzhi).
## Tapping the board while seeds are moving skips to the end of the move.

signal played(kind: String)  ## "select" (pick up), "seed" (one drop), "capture", "again", "nope"
signal changed  ## The position on screen has settled (after a move, or a new position).
signal before_move(state_before)  ## A human move is about to be played; used for undo.
signal human_moved(pit: int)  ## A move the player made by tapping (sent to the server online).

const S := preload("res://games/sowing/sowing_rules.gd")

const GROUND := Color("#C9DCAE")
const GROUND_DARK := Color("#B9CF9B")
const GRASS := Color("#6E9A4C")
const FLOWER := Color("#FFF8E8")
const FLOWER_EYE := Color("#F6C66B")
const WOOD := Color("#B98450")
const WOOD_EDGE := Color("#8A5A2E")
const WOOD_SHINE := Color("#D2A06A")
const GRAIN := Color("#A57140")
const HOLLOW := Color("#7A4C2A")
const HOLLOW_DEEP := Color("#4F2F19")
const CHIP := Color("#4F2F19")
const CHIP_TEXT := Color("#FFF4E4")
const INK := Color("#2F4128")
const HINT := Color("#FFFFFF")
const FOCUS := Color("#E26F2A")
const LAST := Color("#F6C66B")
const SHADOW := Color(0.2, 0.12, 0.05, 0.28)
const SEED_TONES := [Color("#EADBB9"), Color("#C9A26B"), Color("#8C5B36"), Color("#B5B39C"), Color("#D58C5E")]

const STORE_W := 1.25  ## Kalah stores, in pit columns.
const CHIP_GAP := 0.88  ## Count chips sit this far (in cells) beyond the pit's centre.
const GOLDEN := 2.39996  ## Golden angle: seeds spiral out evenly and never reshuffle.

var state: S.State
var bottom := 0:  ## The player whose row runs along the bottom of the screen.
	set(value):
		bottom = value
		queue_redraw()
var interactive := true  ## False for the result screen and while the computer thinks.
var show_hints := true
var reduce_motion := false
var only_moves := PackedInt32Array()  ## When set, only these pits may be played (tutorial).
var focus_points := PackedInt32Array()  ## Pits ringed in orange to show where to look (tutorial).
var last_pit := -1  ## The pit the last move started from.
var busy := false  ## Seeds are moving.
var compact := false  ## Small previews: just the tray, no Pallanguzhi piles around it.

var shown := PackedInt32Array()  ## Seeds drawn in each pit; catches up with `state` as seeds land.
var shown_stores := PackedInt32Array([0, 0])
var cell := 100.0  ## Width of one pit column in pixels; everything else is sized from it.
var tray := Rect2()

var _area := Vector2.ZERO
var _time := 0.0
var _queue: Array = []
var _step: Array = []
var _step_t := 0.0
var _step_len := 0.0
var _drop_len := 0.16
var _hand := 0  ## Seeds in the travelling hand.
var _hand_pos := Vector2.ZERO
var _hand_from := Vector2.ZERO
var _hand_to := Vector2.ZERO
var _fly_count := 0  ## A captured handful on its way to a store or pile.
var _fly_from := Vector2.ZERO
var _fly_to := Vector2.ZERO


func new_game(game: Dictionary = S.KALAH, first := 0) -> void:
	set_state(S.new_game(game, first))


## Shows any position without animation (new game, restored game, result screen).
func set_state(s: S.State) -> void:
	state = s
	last_pit = -1
	_queue.clear()
	_step = []
	_hand = 0
	_fly_count = 0
	busy = false
	_sync()
	_relayout()
	changed.emit()


## Plays a move chosen elsewhere (the computer, the other player online), animated.
func play_move(pit: int) -> void:
	if busy:
		skip()
	_play(pit)


## Jumps to the end of the move being animated.
func skip() -> void:
	if busy:
		_finish()


func layout(area: Vector2) -> void:
	_area = area
	_relayout()


func pits_per_side() -> int:
	return S.pits_per_side(state) if state != null else 6


func _has_stores() -> bool:
	return state != null and bool(state.game["store_in_path"])


func _relayout() -> void:
	if _area == Vector2.ZERO or state == null:
		return
	var n := pits_per_side()
	var cols := n + (STORE_W * 2.0 if _has_stores() else 0.0)
	# Tray: 4.1 cells tall (count chips, two rows, gap). Pallanguzhi also needs room
	# above and below the tray for each player's pile of captured seeds.
	var tall := 4.8 if _has_stores() or compact else 7.8
	cell = minf(_area.x / (cols + 0.8), _area.y / tall)
	var size := Vector2((cols + 0.6) * cell, 4.1 * cell)
	tray = Rect2((_area - size) / 2.0, size)
	queue_redraw()


# ---------- Geometry ----------

## Screen position of a pit. Each player's pits run anticlockwise: the bottom row left
## to right, the top row right to left, so a pit and its opposite share a column.
func pit_pos(pit: int) -> Vector2:
	var n := pits_per_side()
	var v := (pit + n * bottom) % (n * 2)
	var col := v if v < n else n * 2 - 1 - v
	var x := tray.position.x + (0.3 + (STORE_W if _has_stores() else 0.0) + col + 0.5) * cell
	var y := tray.position.y + (2.8 if v < n else 1.3) * cell
	return Vector2(x, y)


func pit_radii() -> Vector2:
	return Vector2(0.4, 0.6) * cell


## Where a player's captured seeds go: the store at their right-hand end of the tray
## (Kalah), or a pile on the meadow beside their side of the tray (Pallanguzhi).
func store_pos(player: int) -> Vector2:
	var mine := player == bottom
	if _has_stores():
		var x := tray.end.x - (0.3 + STORE_W / 2.0) * cell if mine else tray.position.x + (0.3 + STORE_W / 2.0) * cell
		return Vector2(x, tray.get_center().y)
	return Vector2(tray.get_center().x, tray.end.y + 1.15 * cell if mine else tray.position.y - 1.15 * cell)


func store_radii() -> Vector2:
	return Vector2(0.44, 1.32) * cell if _has_stores() else Vector2(1.5, 0.55) * cell


func _place_pos(where: int) -> Vector2:
	return store_pos(where - S.STORE_0) if where >= S.STORE_0 else pit_pos(where)


## The pit under a tap: anywhere in the pit's column on its half of the tray counts.
func pit_at(pos: Vector2) -> int:
	if state == null:
		return -1
	for pit in state.pits.size():
		var c := pit_pos(pit)
		if absf(pos.x - c.x) <= cell * 0.5 and absf(pos.y - c.y) <= cell * 0.85:
			return pit
	return -1


# ---------- Input ----------

func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or state == null:
		return
	var local := (make_input_local(event) as InputEventMouseButton).position
	if not tray.grow(cell * 1.6).has_point(local):
		return
	if busy:
		skip()
		get_viewport().set_input_as_handled()
		return
	if not interactive:
		return
	_tap(pit_at(local))
	get_viewport().set_input_as_handled()


func _tap(pit: int) -> void:
	if busy:
		skip()
		return
	if pit < 0 or state.over:
		return
	if not _allowed(pit):
		played.emit("nope")
		return
	before_move.emit(state)
	_play(pit)
	human_moved.emit(pit)


func _allowed(pit: int) -> bool:
	return S.legal_moves(state).has(pit) and (only_moves.is_empty() or only_moves.has(pit))


# ---------- Animation ----------

func _play(pit: int) -> void:
	var r := S.apply(state, pit)
	state = r[0]
	last_pit = pit
	_queue = (r[1] as Array).duplicate()
	var drops := _queue.filter(func(st: Array) -> bool: return st[0] == S.DROP).size()
	# Short moves sow at a relaxed pace; long relays speed up so a turn stays under ~4 s.
	_drop_len = clampf(3.2 / maxf(drops, 1.0), 0.05, 0.16) * (0.5 if reduce_motion else 1.0)
	_step = []
	busy = true
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if busy:
		_advance(delta)
	if busy or _pulsing():
		queue_redraw()


func _pulsing() -> bool:
	return not focus_points.is_empty() or (show_hints and interactive and state != null and not state.over)


func _advance(delta: float) -> void:
	var left := delta
	while busy:
		if _step.is_empty():
			if _queue.is_empty():
				_finish()
				return
			_begin(_queue.pop_front())
		var remaining := _step_len - _step_t
		if left < remaining:
			_step_t += left
			_update_hand()
			return
		left -= remaining
		_step_t = _step_len
		_end(_step)
		_step = []


func _begin(step: Array) -> void:
	_step = step
	_step_t = 0.0
	var speed := 0.5 if reduce_motion else 1.0
	match str(step[0]):
		S.PICK, S.RELAY:
			var pit: int = step[1]
			shown[pit] = 0
			_hand = step[2]
			_hand_from = pit_pos(pit)
			_hand_to = _hand_from
			_step_len = 0.18 * speed
			played.emit("select")
		S.DROP:
			_hand_from = _hand_pos
			_hand_to = _place_pos(step[1])
			_step_len = _drop_len
		S.CAPTURE, S.PASU, S.SWEEP:
			var pit: int = step[1]
			_fly_count = step[2]
			shown[pit] -= _fly_count
			_fly_from = pit_pos(pit)
			_fly_to = store_pos(step[3])
			_step_len = (0.4 if _fly_count > 0 else 0.15) * speed
			if _fly_count > 0 and str(step[0]) != S.SWEEP:
				played.emit("capture")
		S.AGAIN:
			_step_len = 0.3 * speed
			played.emit("again")
		_:
			_step_len = 0.0
	_update_hand()


func _end(step: Array) -> void:
	match str(step[0]):
		S.DROP:
			var where: int = step[1]
			if where >= S.STORE_0:
				shown_stores[where - S.STORE_0] += 1
			else:
				shown[where] += 1
			_hand -= 1
			_hand_pos = _hand_to
			played.emit("seed")
		S.CAPTURE, S.PASU, S.SWEEP:
			shown_stores[int(step[3])] += _fly_count
			_fly_count = 0


func _update_hand() -> void:
	if _step.is_empty():
		return
	var t := _step_t / _step_len if _step_len > 0.0 else 1.0
	if str(_step[0]) in [S.PICK, S.RELAY, S.DROP]:
		_hand_pos = _hand_from.lerp(_hand_to, ease(t, -1.6))


func _finish() -> void:
	busy = false
	_queue.clear()
	_step = []
	_hand = 0
	_fly_count = 0
	_sync()
	queue_redraw()
	changed.emit()


func _sync() -> void:
	shown = state.pits.duplicate()
	shown_stores = state.stores.duplicate()


# ---------- Drawing ----------

func _draw() -> void:
	if state == null or tray.size == Vector2.ZERO:
		return
	_draw_ground()
	_draw_tray()
	var pulse := 0.5 + 0.5 * sin(_time * 3.4)
	var hints := show_hints and interactive and not busy and not state.over
	for pit in state.pits.size():
		var c := pit_pos(pit)
		_draw_hollow(c, pit_radii())
		if pit == last_pit:
			_ring(c, pit_radii() * 1.22, Color(LAST, 0.9), 0.05 * cell)
		if hints and _allowed(pit):
			_ring(c, pit_radii() * (1.14 + 0.04 * pulse), Color(HINT, 0.45 + 0.45 * pulse), 0.045 * cell)
		_draw_seeds(c, pit_radii(), shown[pit], pit + 1)
		_draw_chip(c + Vector2(0, (CHIP_GAP if _is_bottom_row(pit) else -CHIP_GAP) * cell), shown[pit])
	for p in focus_points:
		_ring(pit_pos(p), pit_radii() * (1.3 + 0.06 * pulse), Color(FOCUS, 0.55 + 0.45 * pulse), 0.06 * cell)
	for player in 2:
		if _has_stores() or not compact:
			_draw_store(player)
	if _fly_count > 0 and not _step.is_empty():
		var t := ease(_step_t / maxf(_step_len, 0.001), -1.8)
		var p := _fly_from.lerp(_fly_to, t) + Vector2(0, -sin(t * PI) * cell * 0.6)
		_draw_handful(p, _fly_count)
	if _hand > 0:
		var lift := cell * 0.32
		if not _step.is_empty() and str(_step[0]) == S.DROP:
			lift += sin(_step_t / maxf(_step_len, 0.001) * PI) * cell * 0.12
		_draw_handful(_hand_pos + Vector2(0, -lift), _hand, true)


func _is_bottom_row(pit: int) -> bool:
	return S.owner(state, pit) == bottom


func _draw_ground() -> void:
	# A band of meadow behind the tray, edge to edge, with grass tufts and a few daisies.
	# Kept inside the board's own area, so it never spills over the panels around it.
	var margin := 0.6 if _has_stores() or compact else 2.3
	var top := maxf(0.0, tray.position.y - margin * cell)
	var bot := minf(_area.y, tray.end.y + margin * cell)
	draw_rect(Rect2(0, top, _area.x, bot - top), GROUND)
	draw_rect(Rect2(0, top, _area.x, cell * 0.08), GROUND_DARK)
	draw_rect(Rect2(0, bot - cell * 0.08, _area.x, cell * 0.08), GROUND_DARK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var spots := int(_area.x / cell * 6.0)
	for i in spots:
		var p := Vector2(rng.randf() * _area.x, rng.randf_range(top + cell * 0.25, bot - cell * 0.1))
		if tray.grow(cell * 0.25).has_point(p) or (not _has_stores() and not compact and _near_pile(p)):
			continue
		if rng.randf() < 0.8:
			_tuft(p, cell * rng.randf_range(0.14, 0.2))
		else:
			_daisy(p, cell * 0.07)


func _near_pile(p: Vector2) -> bool:
	for player in 2:
		var c := store_pos(player)
		var r := store_radii() * 1.25 + Vector2(cell * 0.9, 0)
		if absf(p.x - c.x) < r.x and absf(p.y - c.y) < r.y:
			return true
	return false


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


func _draw_tray() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = WOOD
	sb.set_corner_radius_all(int(cell * 0.6))
	sb.set_border_width_all(int(maxf(2.0, cell * 0.05)))
	sb.border_color = WOOD_EDGE
	sb.shadow_color = SHADOW
	sb.shadow_size = int(cell * 0.14)
	sb.shadow_offset = Vector2(0, cell * 0.1)
	sb.anti_aliasing = true
	draw_style_box(sb, tray)
	# A lighter bevel along the top edge, then soft wood grain.
	var inset := cell * 0.09
	var shine := StyleBoxFlat.new()
	shine.bg_color = Color(0, 0, 0, 0)
	shine.set_corner_radius_all(int(cell * 0.52))
	shine.border_width_top = int(maxf(2.0, cell * 0.04))
	shine.border_color = Color(WOOD_SHINE, 0.8)
	shine.anti_aliasing = true
	draw_style_box(shine, tray.grow(-inset))
	var x0 := tray.position.x + cell * 0.6
	var x1 := tray.end.x - cell * 0.6
	for i in 7:
		var y := tray.position.y + tray.size.y * (0.12 + 0.125 * i)
		var pts := PackedVector2Array()
		var steps := 24
		for k in steps + 1:
			var x := lerpf(x0, x1, float(k) / steps)
			pts.append(Vector2(x, y + sin(x / cell * 0.9 + i * 1.7) * cell * 0.05))
		draw_polyline(pts, Color(GRAIN, 0.35), maxf(1.0, cell * 0.018), true)


## A carved bowl lit from above: the top inner wall is in shadow.
func _draw_hollow(c: Vector2, r: Vector2) -> void:
	_ellipse(c + Vector2(0, r.y * 0.07), r * 1.1, Color(WOOD_SHINE, 0.9))
	_ellipse(c, r * 1.07, WOOD_EDGE)
	_ellipse(c, r, HOLLOW_DEEP)
	_ellipse(c + Vector2(0, r.y * 0.13), r * Vector2(0.92, 0.86), HOLLOW)


func _draw_store(player: int) -> void:
	var c := store_pos(player)
	var r := store_radii()
	var count := shown_stores[player]
	if _has_stores():
		_draw_hollow(c, r)
		_draw_seeds(c, r, count, 50 + player)
		# In line with the pit counts of the store owner's row.
		var row_y := pit_pos(player * pits_per_side()).y
		var below := player == bottom
		_draw_chip(Vector2(c.x, row_y + (CHIP_GAP if below else -CHIP_GAP) * cell), count)
	else:
		var spread := clampf(sqrt(count / 50.0), 0.3, 1.0)
		if count > 0:
			_ellipse(c + Vector2(0, r.y * 0.3), r * Vector2(spread, spread * 0.75), Color(GROUND_DARK, 0.9))
		_draw_seeds(c, r, count, 50 + player, true)
		var font := Ui.font("display")
		var size := int(cell * 0.42)
		var text := str(count)
		var at := c + Vector2(r.x + cell * 0.35, size * 0.35)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, INK)


## A dark chip with the seed count, so nobody has to count pebbles.
func _draw_chip(c: Vector2, count: int) -> void:
	var font := Ui.font("display")
	var size := int(cell * 0.27)
	var text := str(count)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var h := cell * 0.34
	var box := Rect2(c - Vector2(maxf(w + cell * 0.18, h) / 2.0, h / 2.0), Vector2(maxf(w + cell * 0.18, h), h))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(CHIP, 0.55)
	sb.set_corner_radius_all(int(h / 2.0))
	sb.anti_aliasing = true
	draw_style_box(sb, box)
	draw_string(font, Vector2(c.x - w / 2.0, c.y + size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, CHIP_TEXT)


## Seeds spiral out from the middle of their bowl; once a bowl is full the next layer
## sits a little higher, so a big pile looks heaped rather than overflowing.
func _draw_seeds(c: Vector2, r: Vector2, count: int, salt: int, heap := false) -> void:
	var sr := cell * 0.12
	var inner := Vector2(maxf(r.x - sr * 1.1, sr * 0.5), maxf(r.y - sr * 1.0, sr * 0.5))
	var cap := maxi(1, int((1.0 if heap else 0.55) * inner.x * inner.y / (sr * sr * 0.78)))
	if heap:  # A pile spreads out as it grows, instead of starting wide and sparse.
		cap = maxi(1, mini(cap, int(count * 0.55) + 1))
	for k in count:
		var layer := k / cap
		var i := k % cap
		var a := i * GOLDEN + layer * 0.9
		var d := sqrt((i + 0.5) / cap)
		var lift := layer * sr * (0.5 if heap else 0.35)
		var p := c + Vector2(cos(a) * inner.x, sin(a) * inner.y) * d - Vector2(0, lift)
		_seed(p, sr, (salt * 131 + k * 37) % 997)


func _draw_handful(c: Vector2, count: int, show_count := false) -> void:
	_ellipse(c + Vector2(0, cell * 0.34), Vector2(cell * 0.22, cell * 0.06), Color(SHADOW, 0.16))
	var sr := cell * 0.12
	for k in mini(count, 14):
		var d := sqrt(k + 0.5) * sr * 0.9
		var a := k * GOLDEN
		_seed(c + Vector2(cos(a) * d, sin(a) * d * 0.8), sr, (k * 53) % 997)
	if show_count and count > 1:
		_draw_chip(c + Vector2(cell * 0.5, -cell * 0.3), count)


func _seed(p: Vector2, sr: float, h: int) -> void:
	var tone: Color = SEED_TONES[h % SEED_TONES.size()]
	var rot := (h % 31) / 31.0 * PI
	_ellipse(p + Vector2(0, sr * 0.28), Vector2(sr, sr * 0.78), Color(0, 0, 0, 0.22), rot)
	_ellipse(p, Vector2(sr, sr * 0.78), tone, rot)
	_ellipse(p + Vector2(-sr * 0.3, -sr * 0.28), Vector2(sr * 0.34, sr * 0.2), Color(1, 1, 1, 0.45), rot)


func _ring(c: Vector2, r: Vector2, color: Color, width: float) -> void:
	var pts := _ellipse_points(c, r, 40)
	pts.append(pts[0])
	draw_polyline(pts, color, width, true)


func _ellipse(c: Vector2, r: Vector2, color: Color, rot := 0.0) -> void:
	draw_colored_polygon(_ellipse_points(c, r, 28, rot), color)


func _ellipse_points(c: Vector2, r: Vector2, n: int, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	return pts


## Recomputes the glowing pits, e.g. after the computer's move hands the turn back.
func refresh_targets() -> void:
	queue_redraw()
