class_name CheckersRules
extends RefCounted
## Rules for Checkers (DISCUSSION.md section 33, D76–D81), in two rule sets on one 8 × 8
## board. Pure data, no screen code.
##
##   "english":       men move and capture one square diagonally forward; kings move and
##                    capture one square in any diagonal direction. A man reaching the far
##                    row is crowned and the move ends there.
##   "international": men move forward but capture forward and backward; kings "fly":
##                    they move any distance along a diagonal and capture a piece at any
##                    distance, landing on any empty square beyond it. A man is crowned
##                    only if its move ends on the far row; passing through it in the
##                    middle of a capture chain, it carries on as a man.
##
## In both: captures are optional (D77), but once a piece captures it must keep capturing
## while it can, so every legal capture is a whole chain. Captured pieces are removed when
## the chain ends; until then they block the way and can't be jumped twice. You win by
## taking all the opponent's pieces or leaving them no move. The game is drawn when a
## position comes up for the third time with the same player to move, or after 50 moves in
## a row (25 each) with no capture and no man moved (D81).
##
## Players: 0 is Black, who always moves first (D79), starting on rows 0–2 and moving up;
## 1 is Red, starting on rows 5–7. Only the 32 dark squares are used, numbered
## row * 4 + col / 2 with row 0 at the bottom; a square (col, row) is dark when col + row
## is even. A move is the list of squares the piece stands on: where it starts, then
## each square it lands on.

const ENGLISH := "english"
const INTERNATIONAL := "international"
const VARIANTS := [ENGLISH, INTERNATIONAL]

const SQUARES := 32
const EMPTY := 0
const BLACK_MAN := 1
const BLACK_KING := 2
const RED_MAN := 3
const RED_KING := 4

const ONGOING := 0
const WIN_0 := 1
const WIN_1 := 2
const DRAW := 3

const QUIET_LIMIT := 50  ## Moves in a row with no capture and no man moved before a draw.
const REPEATS := 3  ## The same position this many times is a draw.

## Diagonal directions as [dcol, drow]: up-right, up-left, down-right, down-left.
const DIRS := [[1, 1], [-1, 1], [1, -1], [-1, -1]]
const FORWARD := [[0, 1], [2, 3]]  ## The directions each player's men move in.

static var RAYS := []  ## RAYS[sq][d]: the squares along direction d from sq, nearest first.


class Move:
	var path := PackedInt32Array()  ## Start square, then each landing square.
	var captured := PackedInt32Array()  ## Squares of the pieces taken, in order.

	func from_sq() -> int:
		return path[0]

	func to_sq() -> int:
		return path[path.size() - 1]

	func is_capture() -> bool:
		return not captured.is_empty()


class State:
	var variant := ENGLISH
	var board := PackedInt32Array()  ## One entry per dark square.
	var turn := 0
	var moves_played := 0
	var quiet := 0  ## Moves in a row with no capture and no man moved.
	var history := PackedStringArray()  ## Position keys since the last capture or man move.
	var last_move := PackedInt32Array()

	func copy() -> State:
		var s := State.new()
		s.variant = variant
		s.board = board.duplicate()
		s.turn = turn
		s.moves_played = moves_played
		s.quiet = quiet
		s.history = history.duplicate()
		s.last_move = last_move.duplicate()
		return s


static func _setup() -> void:
	if not RAYS.is_empty():
		return
	for sq in SQUARES:
		var rays := []
		for d: Array in DIRS:
			var ray := PackedInt32Array()
			var c := col_of(sq) + int(d[0])
			var r := row_of(sq) + int(d[1])
			while c >= 0 and c < 8 and r >= 0 and r < 8:
				ray.append(square(c, r))
				c += int(d[0])
				r += int(d[1])
			rays.append(ray)
		RAYS.append(rays)


# ---------- Squares and pieces ----------

## The square at (col, row), or -1 if that is a light square or off the board.
static func square(col: int, row: int) -> int:
	if col < 0 or col > 7 or row < 0 or row > 7 or (col + row) % 2 != 0:
		return -1
	return row * 4 + floori(col / 2.0)


static func row_of(sq: int) -> int:
	return floori(sq / 4.0)


static func col_of(sq: int) -> int:
	var row := row_of(sq)
	return (sq % 4) * 2 + row % 2


## 0 or 1 for the player a piece belongs to, or -1 for an empty square.
static func owner(piece: int) -> int:
	if piece == BLACK_MAN or piece == BLACK_KING:
		return 0
	if piece == RED_MAN or piece == RED_KING:
		return 1
	return -1


static func is_king(piece: int) -> bool:
	return piece == BLACK_KING or piece == RED_KING


static func far_row(player: int) -> int:
	return 7 if player == 0 else 0


static func new_game(variant := ENGLISH) -> State:
	_setup()
	var s := State.new()
	s.variant = variant if variant in VARIANTS else ENGLISH
	s.board.resize(SQUARES)
	for sq in SQUARES:
		var row := row_of(sq)
		s.board[sq] = BLACK_MAN if row <= 2 else (RED_MAN if row >= 5 else EMPTY)
	s.history.append(key(s))
	return s


static func count(s: State, player: int) -> int:
	var n := 0
	for p in s.board:
		if owner(p) == player:
			n += 1
	return n


## A text key for the position: the board and who is to move (for repetitions).
static func key(s: State) -> String:
	return _board_text(s.board) + str(s.turn)


static func _board_text(board: PackedInt32Array) -> String:
	var out := ""
	for p in board:
		out += ".bBrR"[p]
	return out


# ---------- Moves ----------

## Every legal move for the player to move: all simple moves and all complete capture
## chains (captures are optional). Empty when they have none, or the game is drawn.
static func legal_moves(s: State) -> Array:
	_setup()
	if _drawn(s):
		return []
	var out: Array = []
	for sq in SQUARES:
		var piece := s.board[sq]
		if owner(piece) != s.turn:
			continue
		_steps(s, sq, piece, out)
		_captures(s, sq, piece, out)
	return out


## The legal move with exactly this path, or null.
static func find_move(s: State, path: PackedInt32Array) -> Move:
	for m: Move in legal_moves(s):
		if m.path == path:
			return m
	return null


static func _flying(s: State, piece: int) -> bool:
	return is_king(piece) and s.variant == INTERNATIONAL


static func _steps(s: State, sq: int, piece: int, out: Array) -> void:
	var dirs: Array = [0, 1, 2, 3] if is_king(piece) else FORWARD[owner(piece)]
	for d: int in dirs:
		for to in RAYS[sq][d]:
			if s.board[to] != EMPTY:
				break
			var m := Move.new()
			m.path = PackedInt32Array([sq, to])
			out.append(m)
			if not _flying(s, piece):
				break


## The directions a piece may capture in.
static func _capture_dirs(s: State, piece: int) -> Array:
	if is_king(piece) or s.variant == INTERNATIONAL:
		return [0, 1, 2, 3]
	return FORWARD[owner(piece)]


static func _captures(s: State, sq: int, piece: int, out: Array) -> void:
	var path := PackedInt32Array([sq])
	_chain(s, sq, sq, piece, path, PackedInt32Array(), out)


## Extends a capture chain from `at`. The moving piece has left `start`, so that square
## counts as empty; pieces already taken stay on the board until the chain ends.
static func _chain(s: State, start: int, at: int, piece: int, path: PackedInt32Array, taken: PackedInt32Array, out: Array) -> void:
	var me := owner(piece)
	var extended := false
	for d: int in _capture_dirs(s, piece):
		var ray: PackedInt32Array = RAYS[at][d]
		var i := 0
		if _flying(s, piece):
			while i < ray.size() and _empty(s, ray[i], start):
				i += 1  # A flying king may run up to the piece it takes.
		if i >= ray.size():
			continue
		var victim := ray[i]
		if owner(s.board[victim]) != 1 - me or taken.has(victim):
			continue
		var j := i + 1
		while j < ray.size() and _empty(s, ray[j], start):
			var land := ray[j]
			extended = true
			var next_path := path.duplicate()
			next_path.append(land)
			var next_taken := taken.duplicate()
			next_taken.append(victim)
			# English: a man reaching the far row is crowned and stops there.
			if s.variant == ENGLISH and not is_king(piece) and row_of(land) == far_row(me):
				_add_chain(next_path, next_taken, out)
			else:
				_chain(s, start, land, piece, next_path, next_taken, out)
			if not _flying(s, piece):
				break
			j += 1
	if not extended and path.size() > 1:
		_add_chain(path, taken, out)


static func _empty(s: State, sq: int, start: int) -> bool:
	return s.board[sq] == EMPTY or sq == start


static func _add_chain(path: PackedInt32Array, taken: PackedInt32Array, out: Array) -> void:
	var m := Move.new()
	m.path = path
	m.captured = taken
	out.append(m)


# ---------- Playing ----------

## Plays `m` (from legal_moves) in place and passes the turn.
static func play(s: State, m: Move) -> void:
	var from := m.from_sq()
	var to := m.to_sq()
	var piece := s.board[from]
	var me := owner(piece)
	# A capture or any man moving (crowned or not) can't be undone, so it resets the
	# draw count and the repetition history.
	var reset := m.is_capture() or not is_king(piece)
	s.board[from] = EMPTY
	for c in m.captured:
		s.board[c] = EMPTY
	if not is_king(piece) and row_of(to) == far_row(me):
		piece = BLACK_KING if me == 0 else RED_KING
	s.board[to] = piece
	s.turn = 1 - s.turn
	s.moves_played += 1
	s.last_move = m.path.duplicate()
	if reset:
		s.quiet = 0
		s.history = PackedStringArray()
	else:
		s.quiet += 1
	s.history.append(key(s))


## The position after `m` (the original is left as it was).
static func after(s: State, m: Move) -> State:
	var a := s.copy()
	play(a, m)
	return a


static func _drawn(s: State) -> bool:
	if s.quiet >= QUIET_LIMIT:
		return true
	var k := key(s)
	var n := 0
	for h in s.history:
		if h == k:
			n += 1
	return n >= REPEATS


static func result(s: State) -> int:
	if _drawn(s):
		return DRAW
	if legal_moves(s).is_empty():
		return WIN_1 if s.turn == 0 else WIN_0
	return ONGOING


## Why the game ended: "taken" (no pieces left), "blocked" (pieces but no move),
## "repeated", "quiet" (50 moves without progress), or "" while it goes on.
static func reason(s: State) -> String:
	if s.quiet >= QUIET_LIMIT:
		return "quiet"
	if _drawn(s):
		return "repeated"
	if legal_moves(s).is_empty():
		return "taken" if count(s, s.turn) == 0 else "blocked"
	return ""


# ---------- Saving ----------

## Saved as text: the 32 dark squares from square 0 up ("." empty, "b" black man, "B" black
## king, "r" red man, "R" red king), with the counts needed for the draw rules.
static func to_dict(s: State) -> Dictionary:
	return {
		"game": "checkers", "variant": s.variant, "board": _board_text(s.board), "turn": s.turn,
		"moves_played": s.moves_played, "quiet": s.quiet, "history": Array(s.history),
		"last_move": Array(s.last_move),
	}


static func from_dict(d: Dictionary) -> State:
	_setup()
	var s := State.new()
	s.variant = str(d.get("variant", ENGLISH))
	if s.variant not in VARIANTS:
		s.variant = ENGLISH
	s.board.resize(SQUARES)
	var text := str(d.get("board", ""))
	for sq in mini(text.length(), SQUARES):
		s.board[sq] = maxi(0, ".bBrR".find(text[sq]))
	s.turn = clampi(int(d.get("turn", 0)), 0, 1)
	s.moves_played = int(d.get("moves_played", 0))
	s.quiet = int(d.get("quiet", 0))
	for h: Variant in d.get("history", []):
		s.history.append(str(h))
	if s.history.is_empty():
		s.history.append(key(s))
	for sq: Variant in d.get("last_move", []):
		s.last_move.append(int(sq))
	return s
