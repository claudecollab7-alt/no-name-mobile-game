class_name ReversiOpponent
extends RefCounted
## Computer opponent for Reversi (DISCUSSION.md section 32), built like the other games'
## ones: iterative deepening negamax with alpha-beta pruning, a position table, and levels
## that differ in look-ahead, time and how often they slip. Hard stays strong but
## beatable (D71): it looks ahead as far as its time allows and plays the last few moves
## perfectly, but its judgement of the middle game is a rule of thumb.
##
## The search works directly on two bitboards, `me` (the player to move) and `opp`, in the
## rules' layout (bit row * 8 + col). Moves and flips are found with the shifts written
## out by hand and pre-combined masks, several times faster than the rules' general
## version. Moves are handled as single bits. GDScript integers are signed: bit 63 is the
## sign bit, so it is split off before counting and taken first when listing moves,
## which keeps every step clear of overflow.
## Thread-safe: it only reads the State it is given.

const R := preload("res://games/reversi/reversi_rules.gd")
const WIN := 100000
const DECIDED := 50000  ## Scores beyond this are a won or lost ending.
const EXACT := 0
const LOWER := 1
const UPPER := 2

## Scoring, for the side to move. Tune with tools/reversi_ladder.gd.
const WEIGHTS := {
	"corner": 30,  ## each corner held
	"x_square": 15,  ## penalty: a disc diagonally next to an empty corner
	"c_square": 6,  ## penalty: a disc on the edge next to an empty corner
	"edge": 2,  ## each edge square that is not next to a corner
	"mobility": 6,  ## each move you have, less each move they have
	"frontier": 2,  ## penalty: each disc next to an empty square (it gives the other side moves)
	"discs": 1,  ## each disc, in the last 16 moves only
}

## "depth" is the look-ahead in the middle game; once only "end" squares are empty, the
## search goes on to the end of the game (as far as time allows). Easy is "naive": it
## counts discs, as a beginner does, and knows nothing of corners or mobility.
const LEVELS := {
	"easy": {"depth": 1, "end": 0, "time_ms": 300, "slip": 0.3, "slip_rank": 3, "naive": true},
	"medium": {"depth": 4, "end": 8, "time_ms": 700, "slip": 0.08, "slip_rank": 2},
	"hard": {"depth": 5, "end": 10, "time_ms": 1200, "slip": 0.0, "slip_rank": 1},
}

static var SIGN := 0  ## Bit 63, the top-right corner.
static var E1 := 0  ## Masks for each shift direction: no wrapping, no sign spreading.
static var W1 := 0
static var NE9 := 0
static var NW7 := 0
static var SE7 := 0
static var SW9 := 0
static var S8 := 0
static var CORNER_INFO := []  ## Per corner: [corner, X square, C squares].
static var EDGES := 0  ## Edge squares not next to a corner.
static var GROUPS := PackedInt64Array()  ## Move order: corners first, X squares last.

var nodes := 0
var depth_reached := 0
var tuning := {}  ## Overrides for WEIGHTS (ladder experiments).
var _w := WEIGHTS
var _naive := false
var _deadline := 0
var _aborted := false
var _table := {}
var _rng := RandomNumberGenerator.new()


func _init(seed_value := 0) -> void:
	_setup()
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


static func _setup() -> void:
	if not GROUPS.is_empty():
		return
	SIGN = 1 << 63
	var not_col0 := 0
	var not_col7 := 0
	for sq in 64:
		if sq % 8 != 0:
			not_col0 |= 1 << sq
		if sq % 8 != 7:
			not_col7 |= 1 << sq
	E1 = not_col0
	W1 = not_col7 & _low(1)
	NE9 = not_col0
	NW7 = not_col7
	SE7 = not_col0 & _low(7)
	SW9 = not_col7 & _low(9)
	S8 = _low(8)
	var corners := 0
	var xs := 0
	var cs := 0
	for corner: Array in [[0, 0, 1, 1], [7, 0, -1, 1], [0, 7, 1, -1], [7, 7, -1, -1]]:
		var col: int = corner[0]
		var row: int = corner[1]
		var dc: int = corner[2]
		var dr: int = corner[3]
		var c := R.bit(col, row)
		var x := R.bit(col + dc, row + dr)
		var cc := R.bit(col + dc, row) | R.bit(col, row + dr)
		CORNER_INFO.append([c, x, cc])
		corners |= c
		xs |= x
		cs |= cc
	var ring := 0
	var inner := 0
	for sq in 64:
		var col := sq % 8
		var row := floori(sq / 8.0)
		if col == 0 or col == 7 or row == 0 or row == 7:
			ring |= 1 << sq
		elif col >= 2 and col <= 5 and row >= 2 and row <= 5:
			inner |= 1 << sq
	EDGES = ring & ~corners & ~cs
	var second := ~ring & ~inner & ~xs
	GROUPS = PackedInt64Array([corners, EDGES, inner, second, cs, xs])


# ---------- Bitboard helpers ----------

## The bits that survive a right shift by n (GDScript's >> copies the sign bit down).
static func _low(n: int) -> int:
	return ~(-1 << (64 - n))


## Bits set in x.
static func pop(x: int) -> int:
	var n := 0
	if x < 0:
		n = 1
		x &= 0x7FFFFFFFFFFFFFFF
	x = x - ((x >> 1) & 0x5555555555555555)
	x = (x & 0x3333333333333333) + ((x >> 2) & 0x3333333333333333)
	x = (x + (x >> 4)) & 0x0F0F0F0F0F0F0F0F
	x += x >> 8
	x += x >> 16
	x += x >> 32
	return n + (x & 0x7F)


## The squares where the player with discs `me` may play against `opp`.
static func moves(me: int, opp: int) -> int:
	var empty := ~(me | opp)
	var out := 0
	var m := opp & E1  # East.
	var x := (me << 1) & m
	x |= (x << 1) & m; x |= (x << 1) & m; x |= (x << 1) & m; x |= (x << 1) & m; x |= (x << 1) & m
	out |= (x << 1) & empty & E1
	m = opp & W1  # West.
	x = (me >> 1) & m
	x |= (x >> 1) & m; x |= (x >> 1) & m; x |= (x >> 1) & m; x |= (x >> 1) & m; x |= (x >> 1) & m
	out |= (x >> 1) & empty & W1
	m = opp  # North.
	x = (me << 8) & m
	x |= (x << 8) & m; x |= (x << 8) & m; x |= (x << 8) & m; x |= (x << 8) & m; x |= (x << 8) & m
	out |= (x << 8) & empty
	m = opp & S8  # South.
	x = (me >> 8) & m
	x |= (x >> 8) & m; x |= (x >> 8) & m; x |= (x >> 8) & m; x |= (x >> 8) & m; x |= (x >> 8) & m
	out |= (x >> 8) & empty & S8
	m = opp & NE9  # North-east.
	x = (me << 9) & m
	x |= (x << 9) & m; x |= (x << 9) & m; x |= (x << 9) & m; x |= (x << 9) & m; x |= (x << 9) & m
	out |= (x << 9) & empty & NE9
	m = opp & NW7  # North-west.
	x = (me << 7) & m
	x |= (x << 7) & m; x |= (x << 7) & m; x |= (x << 7) & m; x |= (x << 7) & m; x |= (x << 7) & m
	out |= (x << 7) & empty & NW7
	m = opp & SE7  # South-east.
	x = (me >> 7) & m
	x |= (x >> 7) & m; x |= (x >> 7) & m; x |= (x >> 7) & m; x |= (x >> 7) & m; x |= (x >> 7) & m
	out |= (x >> 7) & empty & SE7
	m = opp & SW9  # South-west.
	x = (me >> 9) & m
	x |= (x >> 9) & m; x |= (x >> 9) & m; x |= (x >> 9) & m; x |= (x >> 9) & m; x |= (x >> 9) & m
	out |= (x >> 9) & empty & SW9
	return out


## The opponent's discs that a disc on `move` (one bit) flips. In each direction, `x`
## gathers the run of their discs from the move; shifting the run once more lands on the
## square beyond it, which must be ours.
static func flips(me: int, opp: int, move: int) -> int:
	var f := 0
	var m := opp & E1
	var x := (move << 1) & m
	x |= (x << 1) & m; x |= (x << 1) & m; x |= (x << 1) & m; x |= (x << 1) & m; x |= (x << 1) & m
	if (x << 1) & me & E1:
		f |= x
	m = opp & W1
	x = (move >> 1) & m
	x |= (x >> 1) & m; x |= (x >> 1) & m; x |= (x >> 1) & m; x |= (x >> 1) & m; x |= (x >> 1) & m
	if (x >> 1) & me & W1:
		f |= x
	m = opp
	x = (move << 8) & m
	x |= (x << 8) & m; x |= (x << 8) & m; x |= (x << 8) & m; x |= (x << 8) & m; x |= (x << 8) & m
	if (x << 8) & me:
		f |= x
	m = opp & S8
	x = (move >> 8) & m
	x |= (x >> 8) & m; x |= (x >> 8) & m; x |= (x >> 8) & m; x |= (x >> 8) & m; x |= (x >> 8) & m
	if (x >> 8) & me & S8:
		f |= x
	m = opp & NE9
	x = (move << 9) & m
	x |= (x << 9) & m; x |= (x << 9) & m; x |= (x << 9) & m; x |= (x << 9) & m; x |= (x << 9) & m
	if (x << 9) & me & NE9:
		f |= x
	m = opp & NW7
	x = (move << 7) & m
	x |= (x << 7) & m; x |= (x << 7) & m; x |= (x << 7) & m; x |= (x << 7) & m; x |= (x << 7) & m
	if (x << 7) & me & NW7:
		f |= x
	m = opp & SE7
	x = (move >> 7) & m
	x |= (x >> 7) & m; x |= (x >> 7) & m; x |= (x >> 7) & m; x |= (x >> 7) & m; x |= (x >> 7) & m
	if (x >> 7) & me & SE7:
		f |= x
	m = opp & SW9
	x = (move >> 9) & m
	x |= (x >> 9) & m; x |= (x >> 9) & m; x |= (x >> 9) & m; x |= (x >> 9) & m; x |= (x >> 9) & m
	if (x >> 9) & me & SW9:
		f |= x
	return f


## Every square next to one in `b`, in all eight directions.
static func _around(b: int) -> int:
	return ((b << 1) & E1) | ((b >> 1) & W1) | (b << 8) | ((b >> 8) & S8) \
		| ((b << 9) & NE9) | ((b << 7) & NW7) | ((b >> 7) & SE7) | ((b >> 9) & SW9)


## The moves in `mm` as single bits, in a good order to search: corners first, the
## squares next to corners last. `first` (if one of them) goes before everything.
static func _ordered(mm: int, first := 0) -> PackedInt64Array:
	var out := PackedInt64Array()
	if first and (mm & first):
		out.append(first)
		mm &= ~first
	for g in GROUPS:
		var sub := mm & g
		while sub:
			var b := SIGN if sub < 0 else sub & -sub
			sub ^= b
			out.append(b)
	return out


static func _index(b: int) -> int:
	if b < 0:
		return 63
	var i := 0
	while (1 << i) != b:
		i += 1
	return i


# ---------- Choosing a move ----------

## time_cap_ms > 0 shortens thinking, e.g. in the browser, where search blocks the screen.
func choose_move(s: R.State, level: String, time_cap_ms := 0) -> int:
	var cfg: Dictionary = LEVELS.get(level, LEVELS["medium"])
	var time_ms := int(cfg["time_ms"])
	if time_cap_ms > 0:
		time_ms = mini(time_ms, time_cap_ms)
	var depth := int(cfg["depth"])
	var empties := 64 - pop(s.bits[0] | s.bits[1])
	if empties <= int(cfg.get("end", 0)):
		depth = empties
	return search(s, depth, time_ms, float(cfg["slip"]), int(cfg["slip_rank"]), bool(cfg.get("naive", false)))


## Full control, used by levels and by the ladder. Returns a square, or R.PASS.
func search(s: R.State, max_depth: int, time_ms: int, slip := 0.0, slip_rank := 1, naive := false) -> int:
	_w = WEIGHTS.merged(tuning, true)
	_naive = naive
	var me: int = s.bits[s.turn]
	var opp: int = s.bits[1 - s.turn]
	var mm := moves(me, opp)
	if mm == 0:
		return R.PASS if moves(opp, me) else -1
	var root := _ordered(mm)
	if root.size() == 1:
		return _index(root[0])
	nodes = 0
	depth_reached = 0
	_aborted = false
	_deadline = Time.get_ticks_msec() + time_ms
	if _table.size() > 400000:
		_table.clear()
	var empties := 64 - pop(me | opp)
	var scored: Array = []  ## [value, move bit], best first.
	for depth in range(1, mini(max_depth, empties) + 1):
		var round_scores: Array = []
		var best := -WIN * 4
		for b in (root if scored.is_empty() else PackedInt64Array(scored.map(func(e: Array) -> int: return e[1]))):
			var f := flips(me, opp, b)
			# Levels that slip need every move's exact score, to rank them; Hard only
			# needs the best, and the moves that tie with it (for variety).
			var alpha := -WIN * 4 if slip > 0.0 or best == -WIN * 4 else best - 1
			var v := -_negamax(opp & ~f, me | b | f, depth - 1, -WIN * 4, -alpha, 1)
			if _aborted:
				break
			best = maxi(best, v)
			round_scores.append([v, b])
		if _aborted:
			if scored.is_empty():
				scored = round_scores
			break
		round_scores.sort_custom(func(a: Array, c: Array) -> bool: return a[0] > c[0])
		scored = round_scores
		depth_reached = depth
		if absi(scored[0][0]) > DECIDED:
			break  # Won or lost whatever happens; looking deeper changes nothing.
	if scored.is_empty():
		return _index(root[_rng.randi_range(0, root.size() - 1)])
	scored.sort_custom(func(a: Array, c: Array) -> bool: return a[0] > c[0])
	var best_value: int = scored[0][0]
	if best_value > DECIDED:
		return _index(scored[0][1])  # A won ending: never slip away from it.
	if slip > 0.0 and _rng.randf() < slip and scored.size() > 1:
		var pick := mini(_rng.randi_range(1, slip_rank), scored.size() - 1)
		return _index(scored[pick][1])
	var ties: Array = scored.filter(func(e: Array) -> bool: return e[0] == best_value)
	return _index(ties[_rng.randi_range(0, ties.size() - 1)][1])


## Score of the position for the player to move (whose discs are `me`).
func _negamax(me: int, opp: int, depth: int, alpha: int, beta: int, ply: int) -> int:
	nodes += 1
	if (nodes & 255) == 0 and Time.get_ticks_msec() >= _deadline:
		_aborted = true
		return 0
	var mm := moves(me, opp)
	if mm == 0:
		if moves(opp, me) == 0:
			return final_score(me, opp)
		return -_negamax(opp, me, depth, -beta, -alpha, ply + 1)  # We must pass.
	if depth <= 0:
		return evaluate(me, opp, mm)
	var key := me ^ ((opp << 13) | ((opp >> 51) & 0x1FFF))
	var alpha0 := alpha
	var tt_move := 0
	var entry: Array = _table.get(key, [])
	if not entry.is_empty() and entry[0] == me and entry[1] == opp:
		tt_move = entry[5]
		if entry[2] >= depth:
			var v: int = entry[3]
			match int(entry[4]):
				EXACT:
					return v
				LOWER:
					alpha = maxi(alpha, v)
				UPPER:
					beta = mini(beta, v)
			if alpha >= beta:
				return v
	var best := -WIN * 4
	var best_move := 0
	for b in _ordered(mm, tt_move):
		var f := flips(me, opp, b)
		var v := -_negamax(opp & ~f, me | b | f, depth - 1, -beta, -alpha, ply + 1)
		if _aborted:
			return 0
		if v > best:
			best = v
			best_move = b
		alpha = maxi(alpha, v)
		if alpha >= beta:
			break
	var flag := EXACT
	if best <= alpha0:
		flag = UPPER
	elif best >= beta:
		flag = LOWER
	_table[key] = [me, opp, depth, best, flag, best_move]
	return best


## The end of the game: a win or loss outweighs any score, then by how many discs.
static func final_score(me: int, opp: int) -> int:
	var diff := pop(me) - pop(opp)
	if diff > 0:
		return WIN + diff
	if diff < 0:
		return -WIN + diff
	return 0


## A rule-of-thumb score for the player to move: corners, the squares that give corners
## away, edges, how many moves each side has, discs that face empty squares, and, late
## in the game, the disc count. `mm` is the mover's moves, already found.
func evaluate(me: int, opp: int, mm: int) -> int:
	if _naive:
		return pop(me) - pop(opp)
	var score := int(_w["mobility"]) * (pop(mm) - pop(moves(opp, me)))
	var x_w: int = _w["x_square"]
	var c_w: int = _w["c_square"]
	var corner_w: int = _w["corner"]
	for info: Array in CORNER_INFO:
		var c: int = info[0]
		if me & c:
			score += corner_w
		elif opp & c:
			score -= corner_w
		else:
			var x: int = info[1]
			var cc: int = info[2]
			if me & x:
				score -= x_w
			elif opp & x:
				score += x_w
			score -= c_w * (pop(me & cc) - pop(opp & cc))
	score += int(_w["edge"]) * (pop(me & EDGES) - pop(opp & EDGES))
	var empty := ~(me | opp)
	var near_empty := _around(empty)
	score -= int(_w["frontier"]) * (pop(me & near_empty) - pop(opp & near_empty))
	if pop(empty) <= 16:
		score += int(_w["discs"]) * (pop(me) - pop(opp))
	return score
