class_name FourPuzzles
extends RefCounted
## Puzzle goals for Four in a Row, with exact proofs (BUILD_PLAN.md G4.7). Every puzzle
## shipped was proven by these functions: only one first move achieves the goal. The
## puzzle screen uses the same functions to judge moves and to pick the computer's
## toughest defence. You play the side to move (orange or cream).
##
## Goals:
##   "win":  make four within `n` of your moves, whatever your opponent does
##   "save": only one move stops your opponent from forcing four within their next
##           SAVE_DEPTH moves; find it
##
## The proofs work on the opponent's bitboard pair (cur = discs of the player to move,
## mask = all discs), as FourOpponent does, so they are quick enough to run while
## playing.

const F := preload("res://games/fourinrow/four_rules.gd")
const SAVE_DEPTH := 2  ## A "save" stops every forced four within this many of their moves.


## A fresh position for a puzzle record.
static func position(p: Dictionary) -> F.State:
	return F.from_dict({"columns": p["columns"], "turn": int(p["turn"])})


static func goal_text(p: Dictionary) -> String:
	match str(p["goal"]):
		"win":
			var n := int(p["n"])
			if n == 1:
				return "Your move. Make four in a row."
			return TranslationServer.translate("Your move. Make four within %d moves, whatever they do.") % n
		"save":
			return "Your move. Only one move stops them forcing four. Find it."
	return ""


# ---------- Bitboard helpers ----------

static func _pair(s: F.State) -> Array:
	FourOpponent._setup()
	return [s.bits[s.turn], s.bits[0] | s.bits[1]]


## The space a disc dropped in `col` would land on, or 0 if the column is full.
static func _drop_bit(mask: int, col: int) -> int:
	return FourOpponent._playable(mask) & FourOpponent._column(col)


static func _wins_now(cur: int, mask: int) -> bool:
	return FourOpponent.winning_spaces(cur, mask) & FourOpponent._playable(mask) != 0


static func _full(mask: int) -> bool:
	return FourOpponent._playable(mask) == 0


## Can the player to move (discs `cur`) make four within n of their own moves, whatever
## the opponent does?
static func _win_in(cur: int, mask: int, n: int) -> bool:
	if _wins_now(cur, mask):
		return true
	if n <= 1:
		return false
	for col in F.COLS:
		var move := _drop_bit(mask, col)
		if move and _forces(cur, mask, move, n):
			return true
	return false


## After the mover plays `move` (not itself a win), does every reply still leave them a
## win within n - 1 more moves?
static func _forces(cur: int, mask: int, move: int, n: int) -> bool:
	var opp := cur ^ mask  # The opponent's discs.
	var mask2 := mask | move
	if _wins_now(opp, mask2) or _full(mask2):
		return false  # They make four first, or the board fills: a draw.
	var mine := opp ^ mask2  # Our discs again, after their reply is added below.
	for col in F.COLS:
		var reply := _drop_bit(mask2, col)
		if reply == 0:
			continue
		if not _win_in(mine, mask2 | reply, n - 1):
			return false
	return true


# ---------- Goals ----------

## The columns that make four within n of your moves, whatever the opponent does.
static func win_moves(s: F.State, n: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if F.result(s) != F.ONGOING:
		return out
	var p := _pair(s)
	var cur: int = p[0]
	var mask: int = p[1]
	for col in F.COLS:
		var move := _drop_bit(mask, col)
		if move == 0:
			continue
		if FourOpponent.winning_spaces(cur, mask) & move:
			out.append(col)  # Four at once.
		elif n > 1 and _forces(cur, mask, move, n):
			out.append(col)
	return out


## The columns after which the opponent cannot force four within SAVE_DEPTH moves.
static func save_moves(s: F.State) -> PackedInt32Array:
	var out := PackedInt32Array()
	if F.result(s) != F.ONGOING:
		return out
	var p := _pair(s)
	var cur: int = p[0]
	var mask: int = p[1]
	for col in F.COLS:
		var move := _drop_bit(mask, col)
		if move == 0:
			continue
		var mask2 := mask | move
		if not _win_in(cur ^ mask, mask2, SAVE_DEPTH):
			out.append(col)
	return out


# ---------- Judging play ----------

## Columns the player may play now and still solve the puzzle with `moves_left` moves.
static func good_moves(p: Dictionary, s: F.State, moves_left: int) -> PackedInt32Array:
	if str(p["goal"]) == "save":
		return save_moves(s)
	return win_moves(s, moves_left)


## True when the position after the player's move completes the goal.
static func is_solved(p: Dictionary, after: F.State, mover: int) -> bool:
	if str(p["goal"]) == "save":
		return true  # A save is one move; good_moves already judged it.
	return F.result(after) == (F.WIN_0 if mover == 0 else F.WIN_1)


## The computer's reply: the defence that leaves the player the fewest winning moves
## (and never a draw or a loss it could avoid by blocking).
static func toughest_reply(s: F.State, moves_left: int) -> int:
	var best := -1
	var best_count := 1 << 30
	for r in F.legal_moves(s):
		var after := F.after(s, r)
		if F.result(after) != F.ONGOING:
			return r  # Only possible if the defender can win; take it.
		var count := win_moves(after, moves_left).size()
		if count < best_count:
			best_count = count
			best = r
	return best
