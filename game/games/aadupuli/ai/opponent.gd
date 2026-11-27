class_name AadupuliOpponent
extends RefCounted
## Computer opponent for Tiger & Goat (BUILD_PLAN.md phase 2).
##
## Search: iterative deepening negamax with alpha-beta pruning, a position table
## (remembers positions already examined, including the best move found there),
## and move ordering: table move first, then captures, then the rest.
## Scoring weights live in WEIGHTS so they can be tuned without touching the search.
## Levels: easy looks 2 moves ahead and sometimes picks a weaker move; medium looks
## 4 ahead and occasionally picks the second best; hard searches as deep as its time
## allows. Thread-safe: it only reads the State it is given.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const WIN := 100000
const EXACT := 0
const LOWER := 1
const UPPER := 2

## Scoring, from the tigers' point of view. Tune with tools/self_play.gd.
const WEIGHTS := {
	"captured": 1000,  ## each goat taken
	"mobility": 10,  ## each tiger move available
	"threat": 220,  ## each goat that could be jumped right now
	"trapped": 260,  ## each tiger that cannot move (counts against tigers)
	"safe_wall": 6,  ## each goat-goat link (goats standing together protect each other)
	"quiet": 12,  ## each tiger move spent without a capture (counts against tigers)
}

const LEVELS := {
	"easy": {"depth": 2, "time_ms": 300, "slip": 0.33, "slip_rank": 3},
	"medium": {"depth": 4, "time_ms": 600, "slip": 0.1, "slip_rank": 2},
	"hard": {"depth": 64, "time_ms": 1200, "slip": 0.0, "slip_rank": 1},
}

var nodes := 0
var depth_reached := 0
var _deadline := 0
var _aborted := false
var _table := {}
var _rng := RandomNumberGenerator.new()


func _init(seed_value := 0) -> void:
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


## time_cap_ms > 0 shortens thinking, e.g. in the browser, where search blocks the screen.
func choose_move(s: R.State, level: String, time_cap_ms := 0) -> int:
	var cfg: Dictionary = LEVELS.get(level, LEVELS["medium"])
	var time_ms := int(cfg["time_ms"])
	if time_cap_ms > 0:
		time_ms = mini(time_ms, time_cap_ms)
	return search(s, int(cfg["depth"]), time_ms, float(cfg["slip"]), int(cfg["slip_rank"]))


## Full control, used by levels and by self-play.
func search(s: R.State, max_depth: int, time_ms: int, slip := 0.0, slip_rank := 1) -> int:
	var moves := R.legal_moves(s)  # The root honours the no-repeat rule.
	if moves.size() == 1:
		return moves[0]
	nodes = 0
	depth_reached = 0
	_aborted = false
	_deadline = Time.get_ticks_msec() + time_ms
	if _table.size() > 400000:
		_table.clear()
	var scored: Array = []
	for depth in range(1, max_depth + 1):
		var round_scores: Array = []
		for m in _root_order(s, moves, scored):
			# Full window at the root, so every move gets an exact score: needed to rank
			# moves for the easier levels and to pick fairly among equal best moves.
			var v := -_negamax(R.apply(s, m, false), depth - 1, -WIN * 2, WIN * 2, 1)
			if _aborted:
				break
			round_scores.append([v, m])
		if _aborted:
			if scored.is_empty():
				scored = round_scores
			break
		scored = round_scores
		depth_reached = depth
		scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		if scored[0][0] >= WIN - 100:
			break  # A forced win is found; no need to look deeper.
	if scored.is_empty():
		return moves[0]
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	if scored[0][0] >= WIN - 100:
		return scored[0][1]  # Never miss a win that is there, even on easy.
	# Among equally good moves, vary the choice so games aren't identical.
	var best_value: int = scored[0][0]
	var ties: Array = scored.filter(func(e: Array) -> bool: return e[0] == best_value)
	if slip > 0.0 and _rng.randf() < slip and scored.size() > 1:
		var pick := mini(_rng.randi_range(1, slip_rank), scored.size() - 1)
		return scored[pick][1]
	return ties[_rng.randi_range(0, ties.size() - 1)][1]


func _root_order(s: R.State, moves: PackedInt32Array, previous: Array) -> PackedInt32Array:
	if previous.is_empty():
		return _ordered(moves, -1)
	var out := PackedInt32Array()
	for e: Array in previous:
		out.append(e[1])
	return out


func _negamax(s: R.State, depth: int, alpha: int, beta: int, ply: int) -> int:
	nodes += 1
	if (nodes & 255) == 0 and Time.get_ticks_msec() >= _deadline:
		_aborted = true
		return 0
	if s.captured >= s.capture_target:
		return -(WIN - ply)  # Goats to move, and they have lost.
	if R.held(s):
		return WIN - ply  # Goats to move, and they have held the hill.
	var moves := R.pseudo_moves(s)
	if moves.is_empty():
		return -(WIN - ply)
	if depth <= 0:
		return _evaluate(s, moves)
	var key := R.position_key(s) ^ (s.quiet << 51) ^ (s.captured << 58)
	var alpha0 := alpha
	var tt_move := -1
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
	var best := -WIN * 2
	var best_move := -1
	for m in _ordered(moves, tt_move):
		var v := -_negamax(R.apply(s, m, false), depth - 1, -beta, -alpha, ply + 1)
		if _aborted:
			return 0
		if v > best:
			best = v
			best_move = m
		if v > alpha:
			alpha = v
			if alpha >= beta:
				break
	var flag := EXACT
	if best <= alpha0:
		flag = UPPER
	elif best >= beta:
		flag = LOWER
	_table[key] = [depth, best, flag, best_move]
	return best


## Score for the side to move.
func _evaluate(s: R.State, moves: PackedInt32Array) -> int:
	var score := _tiger_score(s, moves if s.turn == R.TIGER else PackedInt32Array())
	return score if s.turn == R.TIGER else -score


func evaluate_for_tigers(s: R.State) -> int:
	return _tiger_score(s, PackedInt32Array())


func _tiger_score(s: R.State, tiger_moves: PackedInt32Array) -> int:
	if tiger_moves.is_empty():
		var as_tigers := s.copy()
		as_tigers.turn = R.TIGER
		tiger_moves = R.pseudo_moves(as_tigers)
	var threatened := 0
	var per_tiger := {}
	for m in tiger_moves:
		var over := R.move_over(m)
		if over != R.NONE:
			threatened |= 1 << over
		per_tiger[R.move_from(m)] = true
	var threats := 0
	while threatened != 0:
		threatened &= threatened - 1
		threats += 1
	var trapped := 0
	for t in s.tigers:
		if not per_tiger.has(t):
			trapped += 1
	var links := 0
	var g := s.goats
	for p in R.point_count(s):
		if (g & (1 << p)) == 0:
			continue
		for n in R.neighbours(p, s.board):
			if n > p and (g & (1 << n)) != 0:
				links += 1
	return (s.captured * WEIGHTS["captured"] + tiger_moves.size() * WEIGHTS["mobility"]
		+ threats * WEIGHTS["threat"] - trapped * WEIGHTS["trapped"] - links * WEIGHTS["safe_wall"]
		- s.quiet * WEIGHTS["quiet"])


func _ordered(moves: PackedInt32Array, first: int) -> PackedInt32Array:
	var head := PackedInt32Array()
	var captures := PackedInt32Array()
	var quiet := PackedInt32Array()
	for m in moves:
		if m == first:
			head.append(m)
		elif R.move_over(m) != R.NONE:
			captures.append(m)
		else:
			quiet.append(m)
	head.append_array(captures)
	head.append_array(quiet)
	return head
