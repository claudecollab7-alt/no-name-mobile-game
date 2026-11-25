class_name AadupuliOpponent
extends RefCounted
## Computer opponent, interim version (BUILD_PLAN.md phase 2 replaces it with the full
## design: position table, tuned scoring, levels set by self-play).
##
## Look-ahead with alpha-beta pruning and captures tried first. Levels:
## easy looks 2 moves ahead and sometimes picks a weaker move; medium looks 4 ahead
## and occasionally picks the second best; hard deepens until its time runs out.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const WIN := 100000

const LEVELS := {
	"easy": {"depth": 2, "time_ms": 400, "slip": 0.33, "slip_rank": 3},
	"medium": {"depth": 4, "time_ms": 600, "slip": 0.1, "slip_rank": 2},
	"hard": {"depth": 64, "time_ms": 1000, "slip": 0.0, "slip_rank": 1},
}

var nodes := 0
var _deadline := 0
var _aborted := false
var _rng := RandomNumberGenerator.new()


func choose_move(s: R.State, level: String) -> int:
	var cfg: Dictionary = LEVELS.get(level, LEVELS["medium"])
	var moves := R.legal_moves(s)  # Root moves honour the no-repeat rule.
	if moves.size() == 1:
		return moves[0]
	nodes = 0
	_aborted = false
	_deadline = Time.get_ticks_msec() + int(cfg["time_ms"])
	var scored: Array = []
	for depth in range(1, int(cfg["depth"]) + 1):
		var this_round: Array = []
		for m in _ordered(moves):
			var v := -_negamax(R.apply(s, m, false), depth - 1, -WIN * 2, WIN * 2, 1)
			if _aborted:
				break
			this_round.append([v, m])
		if _aborted and not scored.is_empty():
			break
		if not _aborted or scored.is_empty():
			scored = this_round
		if _aborted:
			break
	if scored.is_empty():
		return moves[0]
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	# Never miss a win that is right there, even on easy.
	if scored[0][0] >= WIN - 10:
		return scored[0][1]
	if _rng.randf() < float(cfg["slip"]):
		var pick := mini(_rng.randi_range(1, int(cfg["slip_rank"])), scored.size() - 1)
		return scored[pick][1]
	return scored[0][1]


func _negamax(s: R.State, depth: int, alpha: int, beta: int, ply: int) -> int:
	nodes += 1
	if (nodes & 255) == 0 and Time.get_ticks_msec() >= _deadline:
		_aborted = true
		return 0
	if s.captured >= s.capture_target:
		return -(WIN - ply)
	var moves := R.pseudo_moves(s)
	if moves.is_empty():
		return -(WIN - ply)
	if depth <= 0:
		return _evaluate(s, moves)
	for m in _ordered(moves):
		var v := -_negamax(R.apply(s, m, false), depth - 1, -beta, -alpha, ply + 1)
		if _aborted:
			return 0
		if v > alpha:
			alpha = v
			if alpha >= beta:
				break
	return alpha


## From the side to move's point of view: captures and tiger freedom favour tigers.
func _evaluate(s: R.State, moves: PackedInt32Array) -> int:
	var mobility := moves.size() if s.turn == R.TIGER else R.tiger_mobility(s)
	var score := s.captured * 1000 + mobility * 12
	return score if s.turn == R.TIGER else -score


func _ordered(moves: PackedInt32Array) -> PackedInt32Array:
	var captures := PackedInt32Array()
	var quiet := PackedInt32Array()
	for m in moves:
		if R.move_over(m) != R.NONE:
			captures.append(m)
		else:
			quiet.append(m)
	captures.append_array(quiet)
	return captures
