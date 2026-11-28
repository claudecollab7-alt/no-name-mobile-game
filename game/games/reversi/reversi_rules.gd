class_name ReversiRules
extends RefCounted
## Rules for Reversi (DISCUSSION.md section 32, D72): an 8 × 8 board. Place a disc so it
## traps one or more straight lines of the opponent's discs (across, up and down, or
## diagonally) between it and another of yours; every trapped disc flips. A move that
## traps nothing is not allowed. With no legal move you pass; when neither player can
## move the game ends, and more discs wins (equal is a draw). Pure data, no screen code.
##
## Players are 0 and 1; player 0 (orange) always moves first (D73). A move is a square,
## numbered as the grid engine does: row * 8 + col, row 0 at the bottom. PASS is the
## move a player without a legal move makes.
##
## Each player's discs are kept as a 64-bit bitboard, bit (row * 8 + col). GDScript's
## integers are signed, so shifting right would copy the top bit down; _shift masks
## every shift, which also stops discs wrapping from one edge of the board to the other.

const SIZE := 8
const CELLS := 64
const PASS := 64

const ONGOING := 0
const WIN_0 := 1
const WIN_1 := 2
const DRAW := 3

## Directions as bit shifts: east, west, north, south, and the four diagonals.
const DIRS := [1, -1, 8, -8, 9, 7, -7, -9]

static var _not_col0 := 0  ## Every square except column 0 (for shifts going east).
static var _not_col7 := 0  ## Every square except column 7 (for shifts going west).
static var _low := []  ## _low[n]: the bits that survive a right shift by n.


class State:
	var bits := PackedInt64Array([0, 0])  ## Each player's discs.
	var turn := 0
	var moves_played := 0
	var last_move := -1  ## The last square played, PASS, or -1.

	func copy() -> State:
		var s := State.new()
		s.bits = bits.duplicate()
		s.turn = turn
		s.moves_played = moves_played
		s.last_move = last_move
		return s


static func _setup() -> void:
	if not _low.is_empty():
		return
	for row in SIZE:
		for col in SIZE:
			var b := bit(col, row)
			if col != 0:
				_not_col0 |= b
			if col != 7:
				_not_col7 |= b
	_low.resize(10)
	for n in range(1, 10):
		_low[n] = ~(-1 << (64 - n))


static func bit(col: int, row: int) -> int:
	return 1 << (row * SIZE + col)


static func cell(col: int, row: int) -> int:
	return row * SIZE + col


## The four centre squares: orange on one diagonal, cream on the other.
static func new_game() -> State:
	_setup()
	var s := State.new()
	s.bits[0] = bit(3, 4) | bit(4, 3)
	s.bits[1] = bit(3, 3) | bit(4, 4)
	return s


## Moves every disc in `b` one square in direction `d`, dropping any that leave the board.
static func _shift(b: int, d: int) -> int:
	var out: int
	if d > 0:
		out = b << d
	else:
		out = (b >> -d) & int(_low[-d])
	match d:
		1, 9, -7:
			return out & _not_col0  # Went east: nothing may wrap into column 0.
		-1, 7, -9:
			return out & _not_col7  # Went west: nothing may wrap into column 7.
	return out


## Squares where the player with discs `me` may play against `opp`.
static func moves_mask(me: int, opp: int) -> int:
	_setup()
	var empty := ~(me | opp)
	var out := 0
	for d: int in DIRS:
		var x := _shift(me, d) & opp
		for i in 5:  # A line can hold at most six of the opponent's discs.
			x |= _shift(x, d) & opp
		out |= _shift(x, d) & empty
	return out


## The opponent's discs that a disc on `move` (a single bit) would flip.
static func flips_mask(me: int, opp: int, move: int) -> int:
	_setup()
	var out := 0
	for d: int in DIRS:
		var line := 0
		var x := _shift(move, d)
		while x & opp:
			line |= x
			x = _shift(x, d)
		if x & me:
			out |= line
	return out


static func count(b: int) -> int:
	var n := 0
	while b:
		b &= b - 1
		n += 1
	return n


## The squares set in a bitboard, in order.
static func squares(b: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in CELLS:
		if b & (1 << c):
			out.append(c)
	return out


## 0 or 1 for the player whose disc is there, or -1 if it is empty.
static func owner_at(s: State, col: int, row: int) -> int:
	var b := bit(col, row)
	if s.bits[0] & b:
		return 0
	if s.bits[1] & b:
		return 1
	return -1


static func discs(s: State, player: int) -> int:
	return count(s.bits[player])


## The moves the player to move may make: their legal squares in order, or [PASS] if
## they have none but the game goes on, or nothing once it is over.
static func legal_moves(s: State) -> PackedInt32Array:
	var mine := moves_mask(s.bits[s.turn], s.bits[1 - s.turn])
	if mine:
		return squares(mine)
	if moves_mask(s.bits[1 - s.turn], s.bits[s.turn]):
		return PackedInt32Array([PASS])
	return PackedInt32Array()


## Plays `m` in place and passes the turn. Returns the squares that flipped (empty for a
## pass). The caller checks the move is legal (legal_moves).
static func play(s: State, m: int) -> PackedInt32Array:
	var me := s.turn
	s.turn = 1 - me
	s.moves_played += 1
	s.last_move = m
	if m == PASS:
		return PackedInt32Array()
	var move := 1 << m
	var flips := flips_mask(s.bits[me], s.bits[1 - me], move)
	s.bits[me] |= move | flips
	s.bits[1 - me] &= ~flips
	return squares(flips)


## The position after `m` (the original is left as it was).
static func after(s: State, m: int) -> State:
	var a := s.copy()
	play(a, m)
	return a


static func result(s: State) -> int:
	if moves_mask(s.bits[0], s.bits[1]) or moves_mask(s.bits[1], s.bits[0]):
		return ONGOING
	var a := count(s.bits[0])
	var b := count(s.bits[1])
	if a > b:
		return WIN_0
	if b > a:
		return WIN_1
	return DRAW


## Saved as eight rows of text from the bottom up ("." empty, "0" orange, "1" cream), so
## nothing depends on 64-bit numbers surviving JSON.
static func to_dict(s: State) -> Dictionary:
	var rows: Array = []
	for row in SIZE:
		var line := ""
		for col in SIZE:
			var who := owner_at(s, col, row)
			line += "." if who < 0 else str(who)
		rows.append(line)
	return {"game": "reversi", "rows": rows, "turn": s.turn, "moves_played": s.moves_played, "last_move": s.last_move}


static func from_dict(d: Dictionary) -> State:
	_setup()
	var s := State.new()
	var rows: Array = d.get("rows", [])
	for row in mini(rows.size(), SIZE):
		var line := str(rows[row])
		for col in mini(line.length(), SIZE):
			match line[col]:
				"0": s.bits[0] |= bit(col, row)
				"1": s.bits[1] |= bit(col, row)
	s.turn = clampi(int(d.get("turn", 0)), 0, 1)
	s.moves_played = int(d.get("moves_played", count(s.bits[0] | s.bits[1]) - 4))
	s.last_move = int(d.get("last_move", -1))
	return s
