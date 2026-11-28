class_name CheckersOpponent
extends RefCounted
## Computer opponent for Checkers (DISCUSSION.md section 33), for both rule sets, built
## like the other games' ones: iterative deepening negamax with alpha-beta pruning, a
## position table, and levels that differ in look-ahead, time and how often they slip.
## Hard stays strong but beatable (D71).
##
## The search plays moves on one board in place and takes them back, with its own move
## finder that follows the same rules as CheckersRules (checked by the tests). A move
## inside the search is [from, to, captured squares...]. Captures are optional, so at
## the end of the look-ahead the side to move may either stop or carry on capturing
## (a "quiet" search over captures only), whichever scores better.
## The draw rules (repetition, 50 quiet moves) are left to the game itself.
## Thread-safe: it only reads the State it is given.

const C := preload("res://games/checkers/checkers_rules.gd")
const WIN := 100000
const DECIDED := 50000
const EXACT := 0
const LOWER := 1
const UPPER := 2
const QUIET_DEPTH := 8  ## How many captures in a row the quiet search follows.

## Scoring, for the side to move. Tune with tools/checkers_ladder.gd.
const WEIGHTS := {
	"man": 100,
	"king": 160,  ## English kings
	"flying_king": 300,  ## International kings, which fly
	"advance": 3,  ## per row a man has come forward
	"back_row": 10,  ## each man still on your own back row (it stops their crowning)
	"centre": 5,  ## each piece on the four middle squares of rows 3 and 4
	"hunt": 3,  ## when ahead: per square a king is from the nearest enemy piece (a penalty)
}

const LEVELS := {
	"easy": {"depth": 1, "time_ms": 300, "slip": 0.4, "slip_rank": 3},
	"medium": {"depth": 4, "time_ms": 700, "slip": 0.1, "slip_rank": 2},
	"hard": {"depth": 30, "time_ms": 1200, "slip": 0.0, "slip_rank": 1},
}

static var ZOBRIST := []  ## ZOBRIST[sq][piece]: a random 62-bit number.
static var SIDE := 0
static var CENTRE := PackedInt32Array()

var nodes := 0
var depth_reached := 0
var tuning := {}  ## Overrides for WEIGHTS (ladder experiments).
var _w := WEIGHTS
var _variant := C.ENGLISH
var _board := PackedInt32Array()
var _key := 0
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
	C._setup()
	if not ZOBRIST.is_empty():
		return
	var r := RandomNumberGenerator.new()
	r.seed = 6151
	for sq in C.SQUARES:
		var row: Array = [0]
		for piece in range(1, 5):
			row.append((r.randi() << 30) ^ r.randi())
		ZOBRIST.append(row)
	SIDE = (r.randi() << 30) ^ r.randi()
	for p: Array in [[2, 3], [4, 3], [3, 4], [5, 4]]:
		CENTRE.append(C.square(p[0], p[1]))


# ---------- Moves on the search board ----------

## Every move for `me` on the search board: [from, to, captured...].
func _moves(me: int, captures_only := false) -> Array:
	var out: Array = []
	for sq in C.SQUARES:
		var piece := _board[sq]
		if C.owner(piece) != me:
			continue
		_chain(sq, sq, piece, PackedInt32Array(), out)
		if not captures_only:
			_steps(sq, piece, out)
	return out


func _flying(piece: int) -> bool:
	return C.is_king(piece) and _variant == C.INTERNATIONAL


func _steps(sq: int, piece: int, out: Array) -> void:
	var dirs: Array = [0, 1, 2, 3] if C.is_king(piece) else C.FORWARD[C.owner(piece)]
	for d: int in dirs:
		for to in C.RAYS[sq][d]:
			if _board[to] != C.EMPTY:
				break
			out.append(PackedInt32Array([sq, to]))
			if not _flying(piece):
				break


func _chain(start: int, at: int, piece: int, taken: PackedInt32Array, out: Array) -> void:
	var me := C.owner(piece)
	var extended := false
	var dirs: Array = [0, 1, 2, 3] if C.is_king(piece) or _variant == C.INTERNATIONAL else C.FORWARD[me]
	var fly := _flying(piece)
	for d: int in dirs:
		var ray: PackedInt32Array = C.RAYS[at][d]
		var i := 0
		if fly:
			while i < ray.size() and (_board[ray[i]] == C.EMPTY or ray[i] == start):
				i += 1
		if i >= ray.size():
			continue
		var victim := ray[i]
		if C.owner(_board[victim]) != 1 - me or taken.has(victim):
			continue
		var j := i + 1
		while j < ray.size() and (_board[ray[j]] == C.EMPTY or ray[j] == start):
			var land := ray[j]
			extended = true
			var next := taken.duplicate()
			next.append(victim)
			if _variant == C.ENGLISH and not C.is_king(piece) and C.row_of(land) == C.far_row(me):
				_add(start, land, next, out)
			else:
				_chain(start, land, piece, next, out)
			if not fly:
				break
			j += 1
	if not extended and not taken.is_empty():
		_add(start, at, taken, out)


func _add(from: int, to: int, taken: PackedInt32Array, out: Array) -> void:
	var m := PackedInt32Array([from, to])
	m.append_array(taken)
	out.append(m)


## Plays a search move; returns what is needed to take it back: [piece, captured pieces...].
func _make(m: PackedInt32Array) -> PackedInt32Array:
	var from := m[0]
	var to := m[1]
	var piece := _board[from]
	var undo := PackedInt32Array([piece])
	_board[from] = C.EMPTY
	_key ^= ZOBRIST[from][piece]
	for i in range(2, m.size()):
		var c := m[i]
		undo.append(_board[c])
		_key ^= ZOBRIST[c][_board[c]]
		_board[c] = C.EMPTY
	var placed := piece
	if not C.is_king(piece) and C.row_of(to) == C.far_row(C.owner(piece)):
		placed = C.BLACK_KING if C.owner(piece) == 0 else C.RED_KING
	_board[to] = placed
	_key ^= ZOBRIST[to][placed]
	return undo


func _unmake(m: PackedInt32Array, undo: PackedInt32Array) -> void:
	var from := m[0]
	var to := m[1]
	_key ^= ZOBRIST[to][_board[to]]
	_board[to] = C.EMPTY
	_board[from] = undo[0]
	_key ^= ZOBRIST[from][undo[0]]
	for i in range(2, m.size()):
		_board[m[i]] = undo[i - 1]
		_key ^= ZOBRIST[m[i]][undo[i - 1]]


func _hash() -> int:
	var k := 0
	for sq in C.SQUARES:
		if _board[sq] != C.EMPTY:
			k ^= ZOBRIST[sq][_board[sq]]
	return k


# ---------- Choosing a move ----------

## The move to play, as a path for CheckersRules (or an empty path with no move).
## time_cap_ms > 0 shortens thinking, e.g. in the browser, where search blocks the screen.
func choose_move(s: C.State, level: String, time_cap_ms := 0) -> PackedInt32Array:
	var cfg: Dictionary = LEVELS.get(level, LEVELS["medium"])
	var time_ms := int(cfg["time_ms"])
	if time_cap_ms > 0:
		time_ms = mini(time_ms, time_cap_ms)
	return search(s, int(cfg["depth"]), time_ms, float(cfg["slip"]), int(cfg["slip_rank"]))


## Full control, used by levels and by the ladder.
func search(s: C.State, max_depth: int, time_ms: int, slip := 0.0, slip_rank := 1) -> PackedInt32Array:
	_w = WEIGHTS.merged(tuning, true)
	_variant = s.variant
	_board = s.board.duplicate()
	_key = _hash()
	var me := s.turn
	var root := _ordered(_moves(me), PackedInt32Array())
	if root.is_empty():
		return PackedInt32Array()
	if root.size() == 1:
		return _to_path(s, root[0])
	nodes = 0
	depth_reached = 0
	_aborted = false
	_deadline = Time.get_ticks_msec() + time_ms
	if _table.size() > 300000:
		_table.clear()
	var scored: Array = []  ## [value, move], best first.
	for depth in range(1, max_depth + 1):
		var round_scores: Array = []
		var best := -WIN * 4
		var order: Array = root if scored.is_empty() else scored.map(func(e: Array) -> PackedInt32Array: return e[1])
		for m: PackedInt32Array in order:
			var alpha := -WIN * 4 if slip > 0.0 or best == -WIN * 4 else best - 1
			var undo := _make(m)
			var v := -_negamax(1 - me, depth - 1, -WIN * 4, -alpha, 1)
			_unmake(m, undo)
			if _aborted:
				break
			best = maxi(best, v)
			round_scores.append([v, m])
		if _aborted:
			if scored.is_empty():
				scored = round_scores
			break
		round_scores.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		scored = round_scores
		depth_reached = depth
		if absi(scored[0][0]) > DECIDED:
			break  # Won or lost whatever happens; looking deeper changes nothing.
	if scored.is_empty():
		return _to_path(s, root[_rng.randi_range(0, root.size() - 1)])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var best_value: int = scored[0][0]
	if best_value > DECIDED:
		return _to_path(s, scored[0][1])  # A won game: never slip away from it.
	if slip > 0.0 and _rng.randf() < slip and scored.size() > 1:
		var pick := mini(_rng.randi_range(1, slip_rank), scored.size() - 1)
		return _to_path(s, scored[pick][1])
	var ties: Array = scored.filter(func(e: Array) -> bool: return e[0] == best_value)
	return _to_path(s, ties[_rng.randi_range(0, ties.size() - 1)][1])


## The rules' path for a search move (the same piece, landing square and pieces taken).
static func _to_path(s: C.State, m: PackedInt32Array) -> PackedInt32Array:
	var caps := Array(m.slice(2))
	caps.sort()
	for lm: C.Move in C.legal_moves(s):
		if lm.from_sq() == m[0] and lm.to_sq() == m[1]:
			var theirs := Array(lm.captured)
			theirs.sort()
			if theirs == caps:
				return lm.path
	return PackedInt32Array()


## Captures first (the most pieces first), then moves that crown, then the rest; `first`
## (the table's best move) before everything.
func _ordered(moves: Array, first: PackedInt32Array) -> Array:
	var scored: Array = []
	for m: PackedInt32Array in moves:
		var score := (m.size() - 2) * 100
		var piece := _board[m[0]]
		if not C.is_king(piece) and C.row_of(m[1]) == C.far_row(C.owner(piece)):
			score += 50
		if not first.is_empty() and m == first:
			score += 100000
		scored.append([score, m])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	return scored.map(func(e: Array) -> PackedInt32Array: return e[1])


func _negamax(me: int, depth: int, alpha: int, beta: int, ply: int) -> int:
	nodes += 1
	if (nodes & 255) == 0 and Time.get_ticks_msec() >= _deadline:
		_aborted = true
		return 0
	if depth <= 0:
		return _quiet(me, alpha, beta, ply, QUIET_DEPTH)
	var key := _key ^ (SIDE if me == 1 else 0)
	var alpha0 := alpha
	var tt_move := PackedInt32Array()
	var entry: Array = _table.get(key, [])
	if not entry.is_empty():
		tt_move = entry[3]
		if entry[0] >= depth:
			var v: int = entry[1]
			match int(entry[2]):
				EXACT:
					return v
				LOWER:
					alpha = maxi(alpha, v)
				UPPER:
					beta = mini(beta, v)
			if alpha >= beta:
				return v
	var moves := _moves(me)
	if moves.is_empty():
		return -(WIN - ply)  # No move: a loss.
	var best := -WIN * 4
	var best_move := PackedInt32Array()
	for m: PackedInt32Array in _ordered(moves, tt_move):
		var undo := _make(m)
		var v := -_negamax(1 - me, depth - 1, -beta, -alpha, ply + 1)
		_unmake(m, undo)
		if _aborted:
			return 0
		if v > best:
			best = v
			best_move = m
		alpha = maxi(alpha, v)
		if alpha >= beta:
			break
	var flag := EXACT
	if best <= alpha0:
		flag = UPPER
	elif best >= beta:
		flag = LOWER
	_table[key] = [depth, best, flag, best_move]
	return best


## At the end of the look-ahead: stop here, or carry on capturing if that is better.
func _quiet(me: int, alpha: int, beta: int, ply: int, left: int) -> int:
	nodes += 1
	var stand := evaluate(me)
	if stand >= beta or left <= 0:
		return stand
	alpha = maxi(alpha, stand)
	var best := stand
	for m: PackedInt32Array in _ordered(_moves(me, true), PackedInt32Array()):
		var undo := _make(m)
		var v := -_quiet(1 - me, -beta, -alpha, ply + 1, left - 1)
		_unmake(m, undo)
		if v > best:
			best = v
		alpha = maxi(alpha, v)
		if alpha >= beta:
			break
	return best


## A rule-of-thumb score for `me`: material, men coming forward, the back row, the centre,
## and, when ahead, kings closing in on what is left.
func evaluate(me: int) -> int:
	var king_w: int = _w["flying_king"] if _variant == C.INTERNATIONAL else _w["king"]
	var man_w: int = _w["man"]
	var adv_w: int = _w["advance"]
	var back_w: int = _w["back_row"]
	var centre_w: int = _w["centre"]
	var material := [0, 0]
	var score := [0, 0]
	var kings := [[], []]
	var pieces := [[], []]
	for sq in C.SQUARES:
		var piece := _board[sq]
		if piece == C.EMPTY:
			continue
		var who := C.owner(piece)
		var row := C.row_of(sq)
		pieces[who].append(sq)
		if C.is_king(piece):
			material[who] += king_w
			kings[who].append(sq)
		else:
			material[who] += man_w
			var forward := row if who == 0 else 7 - row
			score[who] += forward * adv_w
			if forward == 0:
				score[who] += back_w
		if CENTRE.has(sq):
			score[who] += centre_w
	var total: int = material[me] - material[1 - me] + score[me] - score[1 - me]
	# When ahead, send the kings after the enemy, and trade down.
	var lead: int = material[me] - material[1 - me]
	if absi(lead) * 2 >= man_w:
		var up := me if lead > 0 else 1 - me
		var hunt := 0
		for k: int in kings[up]:
			var nearest := 99
			for e: int in pieces[1 - up]:
				nearest = mini(nearest, maxi(absi(C.col_of(k) - C.col_of(e)), absi(C.row_of(k) - C.row_of(e))))
			hunt += nearest if nearest < 99 else 0
		var trade: int = (24 - pieces[0].size() - pieces[1].size()) * 2
		var bonus: int = trade - hunt * int(_w["hunt"])
		total += bonus if up == me else -bonus
	return total
