class_name SowingOpponent
extends RefCounted
## Computer opponent for the pits-and-seeds games (Kalah, Pallanguzhi), built like the
## Tiger & Goat one: iterative deepening negamax with alpha-beta pruning, a position
## table, and levels that differ in depth, time and how often they slip.
##
## Kalah's extra turn means the same player can move twice in a row, so the search keeps
## track of whose point of view a score is from instead of always flipping it.
## Thread-safe: it only reads the State it is given.

const S := preload("res://games/sowing/sowing_rules.gd")
const WIN := 100000
const EXACT := 0
const LOWER := 1
const UPPER := 2

## Scoring, for the side to move. Tune with tools/sowing_self_play.gd.
const WEIGHTS := {
	"store": 100,  ## each seed already won (in your store or pile)
	"side": 25,  ## each seed on your side of the board (yours if the game ends now)
}

const LEVELS := {
	"easy": {"depth": 2, "time_ms": 300, "slip": 0.35, "slip_rank": 3},
	"medium": {"depth": 5, "time_ms": 600, "slip": 0.1, "slip_rank": 2},
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
func choose_move(s: S.State, level: String, time_cap_ms := 0) -> int:
	var cfg: Dictionary = LEVELS.get(level, LEVELS["medium"])
	var time_ms := int(cfg["time_ms"])
	if time_cap_ms > 0:
		time_ms = mini(time_ms, time_cap_ms)
	return search(s, int(cfg["depth"]), time_ms, float(cfg["slip"]), int(cfg["slip_rank"]))


## Full control, used by levels and by self-play.
func search(s: S.State, max_depth: int, time_ms: int, slip := 0.0, slip_rank := 1) -> int:
	var moves := S.legal_moves(s)
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
		for m in _root_order(moves, scored):
			# Full window at the root, so every move gets an exact score: needed to rank
			# moves for the easier levels and to pick fairly among equal best moves.
			var v := _child_value(s, S.after(s, m), depth - 1, -WIN * 2, WIN * 2, 1)
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
		if absi(scored[0][0]) >= WIN - 200:
			break  # The result is already decided; looking deeper changes nothing.
	if scored.is_empty():
		return moves[0]
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	if scored[0][0] >= WIN - 200:
		return scored[0][1]  # Never miss a win that is there, even on easy.
	var best_value: int = scored[0][0]
	var ties: Array = scored.filter(func(e: Array) -> bool: return e[0] == best_value)
	if slip > 0.0 and _rng.randf() < slip and scored.size() > 1:
		var pick := mini(_rng.randi_range(1, slip_rank), scored.size() - 1)
		return scored[pick][1]
	return ties[_rng.randi_range(0, ties.size() - 1)][1]


## The value of `child` for the player to move in `parent`: the same if they move again
## (Kalah's extra turn), otherwise flipped.
func _child_value(parent: S.State, child: S.State, depth: int, alpha: int, beta: int, ply: int) -> int:
	if child.turn == parent.turn:
		return _negamax(child, depth, alpha, beta, ply)
	return -_negamax(child, depth, -beta, -alpha, ply)


func _root_order(moves: PackedInt32Array, previous: Array) -> PackedInt32Array:
	if previous.is_empty():
		return moves
	var out := PackedInt32Array()
	for e: Array in previous:
		out.append(e[1])
	return out


## Score of `s` for the player whose turn it is in `s`.
func _negamax(s: S.State, depth: int, alpha: int, beta: int, ply: int) -> int:
	nodes += 1
	if (nodes & 127) == 0 and Time.get_ticks_msec() >= _deadline:
		_aborted = true
		return 0
	var me := s.turn
	var half := S.total_seeds(s) / 2
	if s.over:
		var diff := s.stores[me] - s.stores[1 - me]
		return 0 if diff == 0 else (WIN - ply if diff > 0 else -(WIN - ply))
	if s.stores[me] > half:
		return WIN - ply  # More than half the seeds: nothing can take the win away.
	if s.stores[1 - me] > half:
		return -(WIN - ply)
	if depth <= 0:
		return evaluate(s)
	var key := _key(s)
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
	for m in _ordered(s, tt_move):
		var v := _child_value(s, S.after(s, m), depth - 1, alpha, beta, ply + 1)
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


## Static score for the player to move.
func evaluate(s: S.State) -> int:
	var me := s.turn
	return ((s.stores[me] - s.stores[1 - me]) * WEIGHTS["store"]
		+ (S.side_total(s, me) - S.side_total(s, 1 - me)) * WEIGHTS["side"])


func _key(s: S.State) -> int:
	return hash(s.pits) ^ (s.stores[0] << 32) ^ (s.stores[1] << 40) ^ (s.turn << 48)


## Table move first; then, in Kalah, moves whose last seed lands in the store (another
## turn), then the rest from the pit nearest the store backwards.
func _ordered(s: S.State, first: int) -> PackedInt32Array:
	var moves := S.legal_moves(s)
	var head := PackedInt32Array()
	var again := PackedInt32Array()
	var rest := PackedInt32Array()
	var n := S.pits_per_side(s)
	var kalah := bool(s.game["store_in_path"])
	for i in range(moves.size() - 1, -1, -1):
		var m := moves[i]
		if m == first:
			head.append(m)
		elif kalah and s.pits[m] == (s.turn + 1) * n - m:
			again.append(m)
		else:
			rest.append(m)
	head.append_array(again)
	head.append_array(rest)
	return head
