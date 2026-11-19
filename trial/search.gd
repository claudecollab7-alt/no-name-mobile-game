extends RefCounted
## Trial-only look-ahead: iterative deepening negamax with alpha-beta pruning.
## Its only job is answering "how many moves deep can GDScript look in one second
## on a cheap phone?" (BUILD_PLAN.md task T0.6). The real opponent comes in phase 2.

const R := preload("res://rules.gd")
const WIN := 100000

var nodes := 0
var depth_reached := 0
var best_move := -1
var elapsed_ms := 0
var _deadline := 0
var _aborted := false


func think(s: R.State, budget_ms: int) -> int:
	R.build()
	nodes = 0
	depth_reached = 0
	best_move = -1
	_aborted = false
	var start := Time.get_ticks_msec()
	_deadline = start + budget_ms
	for depth in range(1, 64):
		var m := _root(s, depth)
		if _aborted:
			break
		best_move = m
		depth_reached = depth
	elapsed_ms = Time.get_ticks_msec() - start
	return best_move


func _root(s: R.State, depth: int) -> int:
	var best := -1
	var alpha := -WIN * 2
	for m: int in _ordered(R.legal_moves(s)):
		var v := -_negamax(R.apply(s, m), depth - 1, -WIN * 2, -alpha, 1)
		if _aborted:
			return -1
		if v > alpha or best == -1:
			alpha = v
			best = m
	return best


func _negamax(s: R.State, depth: int, alpha: int, beta: int, ply: int) -> int:
	nodes += 1
	if (nodes & 511) == 0 and Time.get_ticks_msec() >= _deadline:
		_aborted = true
		return 0
	if s.captured >= R.CAPTURE_TARGET:
		return -(WIN - ply)  # Goats are to move and have lost.
	var moves := R.legal_moves(s)
	if moves.is_empty():
		return -(WIN - ply)  # Side to move is stuck.
	if depth <= 0:
		return _evaluate(s, moves)
	for m: int in _ordered(moves):
		var v := -_negamax(R.apply(s, m), depth - 1, -beta, -alpha, ply + 1)
		if _aborted:
			return 0
		if v > alpha:
			alpha = v
			if alpha >= beta:
				break
	return alpha


## Score from the side to move's point of view: captures and tiger freedom help tigers.
func _evaluate(s: R.State, moves: PackedInt32Array) -> int:
	var mobility := moves.size() if s.turn == R.TIGER else R.tiger_mobility(s)
	var score := s.captured * 1000 + mobility * 12
	return score if s.turn == R.TIGER else -score


## Captures first: they decide most lines, so trying them first prunes far more.
func _ordered(moves: PackedInt32Array) -> PackedInt32Array:
	var captures := PackedInt32Array()
	var quiet := PackedInt32Array()
	for m: int in moves:
		if R.move_over(m) != R.NONE:
			captures.append(m)
		else:
			quiet.append(m)
	captures.append_array(quiet)
	return captures
