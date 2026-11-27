class_name FourRules
extends RefCounted
## Rules for Four in a Row (DISCUSSION.md section 31, D68): an upright frame of 7
## columns × 6 rows; players take turns dropping a disc into a column that isn't full,
## and it falls to the lowest empty space. Four of your discs in a line (across, up and
## down, or diagonally) wins; a full board without four is a draw. Pure data, no screen
## code.
##
## Players are 0 and 1, and player 0 always moves first (online sides "first" and
## "second"; who is first is chosen before the game, D69). A move is a column, 0..6
## from the left.
##
## Each player's discs are kept as a bitboard: bit (col * 7 + row) is set for a disc at
## that column and row (row 0 at the bottom). The 7th bit of each column stays empty, so
## lines can be found with a few shifts and never wrap from one column to the next.

const COLS := 7
const ROWS := 6
const H := ROWS + 1  ## Bits per column: six rows and an empty guard bit.
const CELLS := COLS * ROWS

const ONGOING := 0
const WIN_0 := 1
const WIN_1 := 2
const DRAW := 3

static var _lines: Array[PackedInt32Array] = []


class State:
	var bits := PackedInt64Array([0, 0])  ## Each player's discs.
	var heights := PackedInt32Array([0, 0, 0, 0, 0, 0, 0])  ## Discs in each column.
	var turn := 0
	var moves_played := 0
	var last_move := -1  ## Column of the last disc dropped, or -1.

	func copy() -> State:
		var s := State.new()
		s.bits = bits.duplicate()
		s.heights = heights.duplicate()
		s.turn = turn
		s.moves_played = moves_played
		s.last_move = last_move
		return s


static func new_game() -> State:
	return State.new()


static func bit(col: int, row: int) -> int:
	return 1 << (col * H + row)


## 0 or 1 for the player whose disc is there, or -1 if it is empty.
static func owner_at(s: State, col: int, row: int) -> int:
	var b := bit(col, row)
	if s.bits[0] & b:
		return 0
	if s.bits[1] & b:
		return 1
	return -1


static func can_drop(s: State, col: int) -> bool:
	return col >= 0 and col < COLS and s.heights[col] < ROWS and result(s) == ONGOING


## The columns the player to move may drop into, left to right (none once it's over).
static func legal_moves(s: State) -> PackedInt32Array:
	var out := PackedInt32Array()
	if result(s) != ONGOING:
		return out
	for col in COLS:
		if s.heights[col] < ROWS:
			out.append(col)
	return out


## Drops the mover's disc into `col` in place and passes the turn. Returns the row it
## landed on. The caller checks the move is legal (legal_moves, can_drop).
static func drop(s: State, col: int) -> int:
	var row := s.heights[col]
	s.bits[s.turn] |= bit(col, row)
	s.heights[col] = row + 1
	s.turn = 1 - s.turn
	s.moves_played += 1
	s.last_move = col
	return row


## The position after dropping into `col` (the original is left as it was).
static func after(s: State, col: int) -> State:
	var a := s.copy()
	drop(a, col)
	return a


## True when the discs in `b` include four in a line.
static func has_four(b: int) -> bool:
	for shift: int in [1, H, H - 1, H + 1]:  # up, across, the two diagonals
		var m := b & (b >> shift)
		if m & (m >> (2 * shift)):
			return true
	return false


static func result(s: State) -> int:
	if has_four(s.bits[0]):
		return WIN_0
	if has_four(s.bits[1]):
		return WIN_1
	if s.moves_played >= CELLS:
		return DRAW
	return ONGOING


## The cells (Grid numbering: row * COLS + col) in every line of four belonging to the
## winner, for highlighting; empty if nobody has won.
static func winning_cells(s: State) -> PackedInt32Array:
	var res := result(s)
	if res != WIN_0 and res != WIN_1:
		return PackedInt32Array()
	var who := 0 if res == WIN_0 else 1
	if _lines.is_empty():
		_lines = Grid.lines(COLS, ROWS, 4)
	var seen := {}
	for run in _lines:
		var all := true
		for c in run:
			if owner_at(s, Grid.col_of(COLS, c), Grid.row_of(COLS, c)) != who:
				all = false
				break
		if all:
			for c in run:
				seen[c] = true
	var out := PackedInt32Array(seen.keys())
	out.sort()
	return out


## Saved as each column's discs from the bottom up, plus whose turn it is.
static func to_dict(s: State) -> Dictionary:
	var columns: Array = []
	for col in COLS:
		var discs: Array = []
		for row in s.heights[col]:
			discs.append(owner_at(s, col, row))
		columns.append(discs)
	return {"game": "fourinrow", "columns": columns, "turn": s.turn, "last_move": s.last_move}


static func from_dict(d: Dictionary) -> State:
	var s := State.new()
	var columns: Array = d.get("columns", [])
	for col in mini(columns.size(), COLS):
		var discs: Array = columns[col]
		for row in mini(discs.size(), ROWS):
			var who := clampi(int(discs[row]), 0, 1)
			s.bits[who] |= bit(col, row)
			s.heights[col] = row + 1
			s.moves_played += 1
	s.turn = clampi(int(d.get("turn", 0)), 0, 1)
	s.last_move = int(d.get("last_move", -1))
	return s
