class_name ReversiPuzzles
extends RefCounted
## Puzzle goals for Reversi, with exact proofs (BUILD_PLAN.md G5.7). Every puzzle shipped
## was proven by these functions: only one first move achieves the goal. The puzzle
## screen uses the same functions to judge moves. You play the side to move (orange or
## cream).
##
## Goals:
##   "pass": find the only move that leaves your opponent with nowhere to play (they
##           must pass, and the game goes on)
##   "win":  win the game from here (a few empty squares left), whatever your opponent
##           does; only one first move wins against perfect defence
##
## The proofs search the whole rest of the game on the two bitboards, with the quick
## move finder from ReversiOpponent.

const R := preload("res://games/reversi/reversi_rules.gd")
const O := preload("res://games/reversi/ai/reversi_opponent.gd")

static var nodes := 0  ## Positions searched (for the generator's report).


## A fresh position for a puzzle record.
static func position(p: Dictionary) -> R.State:
	return R.from_dict({"rows": p["rows"], "turn": int(p["turn"])})


static func goal_text(p: Dictionary) -> String:
	match str(p["goal"]):
		"pass":
			return "Your move. Find the only move that leaves them nowhere to play."
		"win":
			return TranslationServer.translate("Your move. %d squares left: win the game, whatever they do.") % int(p["empties"])
	return ""


static func empties(s: R.State) -> int:
	return 64 - R.count(s.bits[0] | s.bits[1])


# ---------- Exact search ----------

## The end of the game with best play from here, for the player to move (discs `me`):
## 1 a win, 0 a draw, -1 a loss.
static func outcome_for(me: int, opp: int, alpha := -1, beta := 1) -> int:
	nodes += 1
	var mm := O.moves(me, opp)
	if mm == 0:
		if O.moves(opp, me) == 0:
			return signi(O.pop(me) - O.pop(opp))
		return -outcome_for(opp, me, -beta, -alpha)  # We must pass.
	var best := -2
	for b in O._ordered(mm):
		var f := O.flips(me, opp, b)
		var v := -outcome_for(opp & ~f, me | b | f, -beta, -alpha)
		if v > best:
			best = v
			if v > alpha:
				alpha = v
				if alpha >= beta:
					break
	return best


## 1, 0 or -1 for the player to move in `s`.
static func outcome(s: R.State) -> int:
	O._setup()
	return outcome_for(s.bits[s.turn], s.bits[1 - s.turn])


# ---------- Goals ----------

## The squares that still win the game for the player to move, against best defence.
static func win_moves(s: R.State) -> PackedInt32Array:
	var out := PackedInt32Array()
	if R.result(s) != R.ONGOING:
		return out
	for m in R.legal_moves(s):
		if m != R.PASS and wins_after(R.after(s, m), s.turn):
			out.append(m)
	return out


## True if `player` wins from position `s` (whoever is to move) with best play.
static func wins_after(s: R.State, player: int) -> bool:
	var res := R.result(s)
	if res != R.ONGOING:
		return res == (R.WIN_0 if player == 0 else R.WIN_1)
	var o := outcome(s)
	return o == 1 if s.turn == player else o == -1


## The squares after which the opponent has no move but the game goes on.
static func pass_moves(s: R.State) -> PackedInt32Array:
	var out := PackedInt32Array()
	for m in R.legal_moves(s):
		if m != R.PASS:
			var after := R.after(s, m)
			if Array(R.legal_moves(after)) == [R.PASS]:
				out.append(m)
	return out


# ---------- Judging play ----------

## True if playing `m` in `s` keeps the puzzle on track.
static func is_good(p: Dictionary, s: R.State, m: int) -> bool:
	if str(p["goal"]) == "pass":
		return pass_moves(s).has(m)
	return R.legal_moves(s).has(m) and wins_after(R.after(s, m), s.turn)


## The squares that keep the puzzle on track now (for "Show answer").
static func good_moves(p: Dictionary, s: R.State) -> PackedInt32Array:
	if str(p["goal"]) == "pass":
		return pass_moves(s)
	return win_moves(s)


## True when the position after the player's move completes the goal.
static func is_solved(p: Dictionary, after: R.State, mover: int) -> bool:
	if str(p["goal"]) == "pass":
		return true  # One move; is_good already judged it.
	return R.result(after) == (R.WIN_0 if mover == 0 else R.WIN_1)


## The computer's defence in a "win" puzzle: every reply loses, so it plays the one that
## keeps the score closest, found by searching to the end (within `ms`).
static func defence(s: R.State, ms := 600) -> int:
	var legal := R.legal_moves(s)
	if legal.is_empty():
		return -1
	if legal[0] == R.PASS:
		return R.PASS
	return O.new(7).search(s, empties(s), ms, 0.0, 1)
