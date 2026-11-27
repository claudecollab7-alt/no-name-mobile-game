class_name SowingPuzzles
extends RefCounted
## Puzzle goals for the seed games, with exact proofs (BUILD_PLAN.md G2.5b). Every
## puzzle shipped was proven by these functions; the puzzle screen uses the same
## functions to judge moves and to pick the computer's toughest defence.
## You always play the bottom row (player 0).
##
## Goals:
##   "most": win `target` seeds this turn (the most possible). In Mancala a turn can be
##           several moves when your last seed lands in your store.
##   "win":  win the game within `n` of your moves, whatever your opponent does
##           ("win" = more than half of all seeds, or the game ends with you ahead).

const S := preload("res://games/sowing/sowing_rules.gd")


static func position(game_id: String, p: Dictionary) -> S.State:
	var s := S.new_game(S.config_for(game_id), 0)
	s.pits = PackedInt32Array(p["pits"])
	s.stores = PackedInt32Array(p["stores"])
	s.turn = 0
	return s


static func goal_text(p: Dictionary) -> String:
	match str(p["goal"]):
		"most":
			return TranslationServer.translate("Win %d seeds this turn. That's the most you can get.") % int(p["target"])
		"win":
			var n := int(p["n"])
			if n == 1:
				return "Win the game with one move."
			return TranslationServer.translate("Win the game in %d moves, whatever your opponent does.") % n
	return ""


# ---------- Most seeds this turn ----------

## The most seeds the player to move can win before the turn passes.
static func best_gain(s: S.State) -> int:
	var best := 0
	for m in S.legal_moves(s):
		best = maxi(best, _gain_with(s, m))
	return best


## Seeds won by playing `m` and then playing the rest of the turn as well as possible.
static func _gain_with(s: S.State, m: int) -> int:
	var me := s.turn
	var a := S.after(s, m)
	var g := a.stores[me] - s.stores[me]
	if a.turn == me and not a.over:
		g += best_gain(a)
	return g


## Moves that still allow winning `need` more seeds this turn.
static func gain_moves(s: S.State, need: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for m in S.legal_moves(s):
		if _gain_with(s, m) >= need:
			out.append(m)
	return out


# ---------- Win the game ----------

## +1 when `me` has won (more than half the seeds, or the game is over with `me`
## ahead), -1 when `me` can no longer win, 0 otherwise.
static func decided(s: S.State, me: int) -> int:
	var half := S.total_seeds(s) / 2
	if s.stores[me] > half or (s.over and s.stores[me] > s.stores[1 - me]):
		return 1
	if s.over or s.stores[1 - me] >= half + (S.total_seeds(s) % 2):
		return -1
	return 0


## The player to move: the moves that win within n of their own moves.
static func win_moves(s: S.State, n: int, first_only := false) -> PackedInt32Array:
	var out := PackedInt32Array()
	if n <= 0:
		return out
	var me := s.turn
	for m in S.legal_moves(s):
		if _wins_after(S.after(s, m), me, n - 1):
			out.append(m)
			if first_only:
				return out
	return out


## After a move by `me`, with `n` of their moves left: is the win forced?
static func _wins_after(a: S.State, me: int, n: int) -> bool:
	var d := decided(a, me)
	if d != 0:
		return d == 1
	if a.turn == me:
		return not win_moves(a, n, true).is_empty()
	if n <= 0:
		return false
	for r in S.legal_moves(a):
		if not _wins_after(S.after(a, r), me, n):
			return false
	return true


# ---------- Judging play ----------

## Moves the player may make now and still solve the puzzle.
## `left`: for "win", moves left; for "most", seeds still needed this turn.
static func good_moves(p: Dictionary, s: S.State, left: int) -> PackedInt32Array:
	if str(p["goal"]) == "most":
		return gain_moves(s, left)
	return win_moves(s, left)


## The computer's reply in a "win" puzzle (the computer is to move in `s`; you have
## `n` moves left): the reply that leaves you the fewest winning moves.
static func toughest_reply(s: S.State, n: int) -> int:
	var me := 1 - s.turn
	var best := -1
	var best_score := 1 << 30
	for r in S.legal_moves(s):
		var score := _pressure(S.after(s, r), me, n)
		if score < best_score:
			best_score = score
			best = r
	return best


## How many winning moves `me` keeps (assuming the opponent keeps defending as well
## as it can if it moves again first).
static func _pressure(a: S.State, me: int, n: int) -> int:
	var d := decided(a, me)
	if d != 0:
		return 1000 if d == 1 else 0
	if a.turn == me:
		return win_moves(a, n).size()
	var low := 1 << 30
	for r in S.legal_moves(a):
		low = mini(low, _pressure(S.after(a, r), me, n))
	return low
