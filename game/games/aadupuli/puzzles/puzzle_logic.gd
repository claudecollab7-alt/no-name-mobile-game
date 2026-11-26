class_name AadupuliPuzzles
extends RefCounted
## Puzzle goals for Tiger & Goat, with exact proofs (BUILD_PLAN.md phase 4).
## Every puzzle shipped has been proven by these functions: a forced win exists, and
## only one first move achieves it. The puzzle screen uses the same functions to judge
## the player's moves and to choose the computer's toughest defence.
##
## Goals:
##   "capture": tigers to play, capture a goat within n tiger moves, whatever goats do
##   "safe":    goats to play, find the only move after which no goat can be captured
##   "trap":    goats to play, trap every tiger within n goat moves, whatever tigers do

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")


## A fresh position for a puzzle record (no repeat history, no holding-out count).
static func position(p: Dictionary) -> R.State:
	var s := R.new_game()
	s.tigers = PackedInt32Array(p["tigers"])
	s.goats = 0
	for g: int in p["goats"]:
		s.goats |= 1 << g
	s.in_hand = int(p["in_hand"])
	s.captured = int(p["captured"])
	s.turn = int(p["turn"])
	s.quiet = 0
	s.counts = {R.position_key(s): 1}
	return s


static func goal_text(p: Dictionary) -> String:
	match str(p["goal"]):
		"capture":
			return "Tigers to play. Capture a goat in %d moves, whatever the goats do." % int(p["n"]) if int(p["n"]) > 1 else "Tigers to play. Capture a goat."
		"safe":
			return "Goats to play. Only one move keeps every goat safe. Find it."
		"trap":
			return "Goats to play. Trap every tiger in %d moves, whatever the tigers do." % int(p["n"]) if int(p["n"]) > 1 else "Goats to play. Trap every tiger in one move."
	return ""


# ---------- Capture ----------

static func capture_now(s: R.State) -> bool:
	if s.turn != R.TIGER:
		return false
	for m in R.legal_moves(s):
		if R.move_over(m) != R.NONE:
			return true
	return false


## Tigers to move: can they force a capture within n tiger moves?
static func capture_in(s: R.State, n: int) -> bool:
	return not capture_wins(s, n, true).is_empty()


## The tiger moves that force a capture within n moves. first_only stops at one.
static func capture_wins(s: R.State, n: int, first_only := false) -> PackedInt32Array:
	var out := PackedInt32Array()
	var moves := R.legal_moves(s)
	for m in moves:
		if R.move_over(m) != R.NONE:
			out.append(m)
			if first_only:
				return out
	if n <= 1:
		return out
	for m in moves:
		if R.move_over(m) != R.NONE:
			continue
		if _capture_after(R.apply(s, m), n - 1):
			out.append(m)
			if first_only:
				return out
	return out


## Goats to move: does every goat reply still allow a capture within n tiger moves?
static func _capture_after(s: R.State, n: int) -> bool:
	if R.result(s) != R.ONGOING:
		return R.result(s) == R.TIGERS_WIN
	for g in R.legal_moves(s):
		if not capture_in(R.apply(s, g), n):
			return false
	return true


# ---------- Safe ----------

static func safe_moves(s: R.State) -> PackedInt32Array:
	var out := PackedInt32Array()
	if s.turn != R.GOAT:
		return out
	for g in R.legal_moves(s):
		if not capture_now(R.apply(s, g)):
			out.append(g)
	return out


# ---------- Trap ----------

static func trap_in(s: R.State, n: int) -> bool:
	return not trap_wins(s, n, true).is_empty()


## The goat moves that force every tiger to be trapped within n goat moves.
static func trap_wins(s: R.State, n: int, first_only := false) -> PackedInt32Array:
	var out := PackedInt32Array()
	if s.turn != R.GOAT:
		return out
	for g in R.legal_moves(s):
		var a := R.apply(s, g)
		var res := R.result(a)
		var ok := false
		if res == R.GOATS_WIN and not R.held(a):
			ok = true
		elif res == R.ONGOING and n > 1:
			ok = true
			for t in R.legal_moves(a):
				var b := R.apply(a, t)
				if R.result(b) == R.TIGERS_WIN or not trap_in(b, n - 1):
					ok = false
					break
		if ok:
			out.append(g)
			if first_only:
				return out
	return out


# ---------- Judging play ----------

## Moves the player may make now and still solve the puzzle with `moves_left` moves.
static func winning_moves(p: Dictionary, s: R.State, moves_left: int) -> PackedInt32Array:
	match str(p["goal"]):
		"capture":
			return capture_wins(s, moves_left)
		"safe":
			return safe_moves(s)
		"trap":
			return trap_wins(s, moves_left)
	return PackedInt32Array()


## True when the position after the player's move completes the goal.
static func is_solved(p: Dictionary, before: R.State, after: R.State) -> bool:
	match str(p["goal"]):
		"capture":
			return after.captured > before.captured
		"safe":
			return not capture_now(after)
		"trap":
			return R.result(after) == R.GOATS_WIN
	return false


## The computer's reply: the defence that leaves the player the fewest winning moves.
static func toughest_reply(p: Dictionary, s: R.State, moves_left: int) -> int:
	var replies := R.legal_moves(s)
	var best := -1
	var best_count := 1 << 30
	for r in replies:
		var after := R.apply(s, r)
		var count := winning_moves(p, after, moves_left).size()
		if count < best_count:
			best_count = count
			best = r
	return best
