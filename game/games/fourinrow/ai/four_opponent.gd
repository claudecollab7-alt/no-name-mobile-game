class_name FourOpponent
extends RefCounted
## Computer opponent for Four in a Row (DISCUSSION.md section 31, D71), built like the
## other games' ones: iterative deepening negamax with alpha-beta pruning, a position
## table, and levels that differ in look-ahead, time and how often they slip. Hard is
## strong but beatable: it looks ahead as far as its time allows, but its judgement of
## positions beyond that is a rule of thumb, not a solution of the game.
##
## The search works directly on two numbers per position, in the rules' bitboard layout:
## `cur` (the discs of the player to move) and `mask` (every disc). Playing a move is
## then: cur ^= mask; mask |= move. Spaces that would complete four for a player are
## found with shifts, which lets the search win at once when it can, block when it must,
## and never drop a disc right under a space the opponent needs.
## Thread-safe: it only reads the State it is given.

const F := preload("res://games/fourinrow/four_rules.gd")
const WIN := 100000
const EXACT := 0
const LOWER := 1
const UPPER := 2
const H := F.H
const ORDER := [3, 2, 4, 1, 5, 0, 6]  ## Centre columns first: they take part in the most lines.

## Scoring, for the side to move. Tune with tools/four_ladder.gd.
const WEIGHTS := {
	"threat": 40,  ## each empty space that would complete four for you
	"parity": 15,  ## extra for a threat on a row that suits you (first player: rows 1, 3, 5)
	"three": 9,  ## each line of four holding three of yours and nothing of theirs
	"two": 3,  ## each line of four holding two of yours and nothing of theirs
	"centre": 4,  ## each of your discs in the centre column
}

const LEVELS := {
	"easy": {"depth": 2, "time_ms": 300, "slip": 0.35, "slip_rank": 3, "careless": true},
	"medium": {"depth": 4, "time_ms": 700, "slip": 0.12, "slip_rank": 2},
	"hard": {"depth": 42, "time_ms": 1200, "slip": 0.0, "slip_rank": 1},
}

static var BOTTOM := 0  ## The bottom space of every column.
static var BOARD := 0  ## Every space on the board.
static var CENTRE := 0
static var ODD_ROWS := 0  ## Rows 1, 3, 5 counted from the bottom (0, 2, 4 in the bitboard).
static var WINDOWS := PackedInt64Array()  ## The 69 lines of four, as masks.

var nodes := 0
var depth_reached := 0
var tuning := {}  ## Overrides for WEIGHTS (ladder experiments).
var _w := WEIGHTS
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
	if not WINDOWS.is_empty():
		return
	for col in F.COLS:
		BOTTOM |= 1 << (col * H)
		for row in F.ROWS:
			BOARD |= F.bit(col, row)
			if row % 2 == 0:
				ODD_ROWS |= F.bit(col, row)
	for row in F.ROWS:
		CENTRE |= F.bit(3, row)
	for run in Grid.lines(F.COLS, F.ROWS, 4):
		var w := 0
		for c in run:
			w |= F.bit(Grid.col_of(F.COLS, c), Grid.row_of(F.COLS, c))
		WINDOWS.append(w)


## time_cap_ms > 0 shortens thinking, e.g. in the browser, where search blocks the screen.
func choose_move(s: F.State, level: String, time_cap_ms := 0) -> int:
	var cfg: Dictionary = LEVELS.get(level, LEVELS["medium"])
	var time_ms := int(cfg["time_ms"])
	if time_cap_ms > 0:
		time_ms = mini(time_ms, time_cap_ms)
	return search(s, int(cfg["depth"]), time_ms, float(cfg["slip"]), int(cfg["slip_rank"]), bool(cfg.get("careless", false)))


## Full control, used by levels and by the ladder. A careless slip (Easy) may even miss
## a block, as a beginner would; other levels only slip between moves that don't lose.
func search(s: F.State, max_depth: int, time_ms: int, slip := 0.0, slip_rank := 1, careless := false) -> int:
	_w = WEIGHTS.merged(tuning, true)
	var moves := F.legal_moves(s)
	if moves.size() == 1:
		return moves[0]
	var cur: int = s.bits[s.turn]
	var mask: int = s.bits[0] | s.bits[1]
	var n := s.moves_played
	# A win on the board is always taken, at every level.
	var wins := winning_spaces(cur, mask) & _playable(mask)
	for col: int in ORDER:
		if wins & _column(col):
			return col
	nodes = 0
	depth_reached = 0
	_aborted = false
	_deadline = Time.get_ticks_msec() + time_ms
	if _table.size() > 500000:
		_table.clear()
	var scored: Array = []
	for depth in range(1, mini(max_depth, F.CELLS - n) + 1):
		var round_scores: Array = []
		for col in _root_order(moves, scored):
			var move := (mask + BOTTOM) & _column(col)
			# Full window at the root, so every move gets an exact score: needed to rank
			# moves for the easier levels and to pick fairly among equal best moves.
			var v := -_negamax(cur ^ mask, mask | move, n + 1, depth - 1, -WIN * 2, WIN * 2, 1)
			if _aborted:
				break
			round_scores.append([v, col])
		if _aborted:
			if scored.is_empty():
				scored = round_scores
			break
		scored = round_scores
		depth_reached = depth
		scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		if absi(scored[0][0]) >= WIN - 100:
			break  # Decided either way; looking deeper changes nothing.
	if scored.is_empty():
		return moves[_rng.randi_range(0, moves.size() - 1)]
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var best_value: int = scored[0][0]
	if best_value >= WIN - 100:
		return scored[0][1]  # A forced win: never slip away from it.
	var ties: Array = scored.filter(func(e: Array) -> bool: return e[0] == best_value)
	# A slip picks one of the next-best moves; unless careless, never one that simply loses.
	var fine: Array = scored if careless else scored.filter(func(e: Array) -> bool: return e[0] > -(WIN - 100))
	if slip > 0.0 and _rng.randf() < slip and fine.size() > 1:
		var pick := mini(_rng.randi_range(1, slip_rank), fine.size() - 1)
		return fine[pick][1]
	return ties[_rng.randi_range(0, ties.size() - 1)][1]


func _root_order(moves: PackedInt32Array, previous: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	if not previous.is_empty():
		for e: Array in previous:
			out.append(e[1])
		return out
	for col: int in ORDER:
		if moves.has(col):
			out.append(col)
	return out


## Score of the position for the player to move (whose discs are `cur`), `n` discs in.
func _negamax(cur: int, mask: int, n: int, depth: int, alpha: int, beta: int, ply: int) -> int:
	nodes += 1
	if (nodes & 255) == 0 and Time.get_ticks_msec() >= _deadline:
		_aborted = true
		return 0
	if n >= F.CELLS:
		return 0  # A full board without four is a draw.
	var possible := _playable(mask)
	if winning_spaces(cur, mask) & possible:
		return WIN - ply  # We complete four now.
	var opp := cur ^ mask
	var opp_wins := winning_spaces(opp, mask)
	var forced := possible & opp_wins
	if forced:
		if forced & (forced - 1):
			return -(WIN - ply - 1)  # Two threats at once: only one can be blocked.
		possible = forced  # The one threat must be blocked.
	var safe := possible & ~(opp_wins >> 1)  # Never fill the space under their winning space.
	if safe == 0:
		return -(WIN - ply - 1)
	if n + 1 >= F.CELLS:
		return 0  # One space left and it doesn't win: a draw.
	if depth <= 0:
		return evaluate(cur, mask)
	var key := cur + mask
	var alpha0 := alpha
	var tt_col := -1
	var entry: Array = _table.get(key, [])
	if not entry.is_empty():
		tt_col = entry[3]
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
	var best := -WIN * 2
	var best_col := -1
	for col in _order(cur, mask, safe, tt_col):
		var move := safe & _column(col)
		var v := -_negamax(cur ^ mask, mask | move, n + 1, depth - 1, -beta, -alpha, ply + 1)
		if _aborted:
			return 0
		if v > best:
			best = v
			best_col = col
		alpha = maxi(alpha, v)
		if alpha >= beta:
			break
	var flag := EXACT
	if best <= alpha0:
		flag = UPPER
	elif best >= beta:
		flag = LOWER
	_table[key] = [depth, best, flag, best_col]
	return best


## The table's best column first, then moves that make the most new threats, centre first.
func _order(cur: int, mask: int, safe: int, tt_col: int) -> PackedInt32Array:
	var scored: Array = []
	for i in ORDER.size():
		var col: int = ORDER[i]
		var move := safe & _column(col)
		if move == 0:
			continue
		var score := 1000 if col == tt_col else _count(winning_spaces(cur | move, mask | move)) * 10 - i
		scored.append([score, col])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var out := PackedInt32Array()
	for e: Array in scored:
		out.append(e[1])
	return out


## A rule-of-thumb score for the player to move: threats, open lines and the centre.
func evaluate(cur: int, mask: int) -> int:
	var opp := cur ^ mask
	var first := (_count(mask) % 2) == 0  # The player to move moved first in this game.
	var mine := winning_spaces(cur, mask)
	var theirs := winning_spaces(opp, mask)
	var my_rows := ODD_ROWS if first else BOARD & ~ODD_ROWS
	var their_rows := BOARD & ~ODD_ROWS if first else ODD_ROWS
	var score := int(_w["threat"]) * (_count(mine) - _count(theirs))
	score += int(_w["parity"]) * (_count(mine & my_rows) - _count(theirs & their_rows))
	score += int(_w["centre"]) * (_count(cur & CENTRE) - _count(opp & CENTRE))
	var three: int = _w["three"]
	var two: int = _w["two"]
	for w in WINDOWS:
		var a := cur & w
		var b := opp & w
		if b == 0 and a != 0:
			var k := _count(a)
			score += three if k == 3 else (two if k == 2 else 0)
		elif a == 0 and b != 0:
			var k := _count(b)
			score -= three if k == 3 else (two if k == 2 else 0)
	return score


## Empty spaces where the player with discs `pos` would complete four (anywhere on the
## board, playable now or not).
static func winning_spaces(pos: int, mask: int) -> int:
	# Up and down: three in a column below the space.
	var r := (pos << 1) & (pos << 2) & (pos << 3)
	for shift: int in [H, H - 1, H + 1]:  # across, and the two diagonals
		var p := (pos << shift) & (pos << (2 * shift))
		r |= p & (pos << (3 * shift))
		r |= p & (pos >> shift)
		p = (pos >> shift) & (pos >> (2 * shift))
		r |= p & (pos << shift)
		r |= p & (pos >> (3 * shift))
	return r & (BOARD ^ mask)


## The space each column's next disc would land in.
static func _playable(mask: int) -> int:
	return (mask + BOTTOM) & BOARD


static func _column(col: int) -> int:
	return ((1 << F.ROWS) - 1) << (col * H)


static func _count(x: int) -> int:
	var n := 0
	while x:
		x &= x - 1
		n += 1
	return n
