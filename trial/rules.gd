extends RefCounted
## Trial-only Aadupuli rules on the classic 23-point board.
##
## Throwaway code for the go/no-go week. The real rules (BUILD_PLAN.md phase 1)
## add the no-repeat rule, options and a full test suite. Moves are packed into
## one int so the timing test can search quickly: from | to << 5 | over << 10,
## where NONE (31) means "no point".

const NONE := 31
const GOAT := 0
const TIGER := 1
const POINT_COUNT := 23
const GOAT_TOTAL := 15
const CAPTURE_TARGET := 5

const ONGOING := 0
const GOATS_WIN := 1
const TIGERS_WIN := 2

## Point positions taken from the verified board picture (docs/board-reference.png).
const POINTS: Array[Vector2] = [
	Vector2(278, 22),
	Vector2(16, 97), Vector2(224, 97), Vector2(256, 97), Vector2(293, 97), Vector2(333, 97), Vector2(524, 97),
	Vector2(16, 150), Vector2(185, 150), Vector2(239, 150), Vector2(305, 150), Vector2(372, 150), Vector2(524, 150),
	Vector2(16, 209), Vector2(143, 209), Vector2(221, 209), Vector2(317, 209), Vector2(410, 209), Vector2(524, 209),
	Vector2(50, 349), Vector2(179, 349), Vector2(344, 349), Vector2(506, 349),
]

## Every straight line on the board, as points in order. Moves follow these lines;
## a jump needs three points in a row on one line.
const LINES: Array = [
	[0, 2, 8, 14, 19], [0, 3, 9, 15, 20], [0, 4, 10, 16, 21], [0, 5, 11, 17, 22],
	[1, 2, 3, 4, 5, 6], [7, 8, 9, 10, 11, 12], [13, 14, 15, 16, 17, 18], [19, 20, 21, 22],
	[1, 7, 13], [6, 12, 18],
]

const START_TIGERS: Array[int] = [0, 3, 4]

static var neighbours: Array = []  # neighbours[p] -> Array[int]
static var jumps: Array = []  # jumps[p] -> Array[int] of [over, land, over, land, ...]


class State:
	var tigers: Array[int] = [0, 3, 4]
	var goats := 0  ## Bit p set when a goat stands on point p.
	var in_hand := 15
	var captured := 0
	var turn := 0  ## 0 goats, 1 tigers.

	func copy() -> State:
		var s := State.new()
		s.tigers = tigers.duplicate()
		s.goats = goats
		s.in_hand = in_hand
		s.captured = captured
		s.turn = turn
		return s


static func build() -> void:
	if not neighbours.is_empty():
		return
	for i in POINT_COUNT:
		neighbours.append([])
		jumps.append([])
	for line: Array in LINES:
		for k in range(line.size() - 1):
			var a: int = line[k]
			var b: int = line[k + 1]
			neighbours[a].append(b)
			neighbours[b].append(a)
		for k in range(line.size() - 2):
			var a: int = line[k]
			var b: int = line[k + 1]
			var c: int = line[k + 2]
			jumps[a].append_array([b, c])
			jumps[c].append_array([b, a])


static func new_game() -> State:
	build()
	var s := State.new()
	s.tigers = START_TIGERS.duplicate()
	return s


static func encode(from: int, to: int, over: int) -> int:
	return from | (to << 5) | (over << 10)


static func move_from(m: int) -> int:
	return m & 31


static func move_to(m: int) -> int:
	return (m >> 5) & 31


static func move_over(m: int) -> int:
	return (m >> 10) & 31


static func tiger_mask(s: State) -> int:
	return (1 << s.tigers[0]) | (1 << s.tigers[1]) | (1 << s.tigers[2])


static func goat_at(s: State, p: int) -> bool:
	return (s.goats & (1 << p)) != 0


static func tiger_at(s: State, p: int) -> bool:
	return s.tigers.has(p)


static func legal_moves(s: State) -> PackedInt32Array:
	build()
	var out := PackedInt32Array()
	var occupied := s.goats | tiger_mask(s)
	if s.turn == GOAT:
		if s.in_hand > 0:
			for p in POINT_COUNT:
				if (occupied & (1 << p)) == 0:
					out.append(encode(NONE, p, NONE))
		else:
			for p in POINT_COUNT:
				if (s.goats & (1 << p)) == 0:
					continue
				for n: int in neighbours[p]:
					if (occupied & (1 << n)) == 0:
						out.append(encode(p, n, NONE))
	else:
		_append_tiger_moves(s, occupied, out)
	return out


static func tiger_mobility(s: State) -> int:
	var out := PackedInt32Array()
	_append_tiger_moves(s, s.goats | tiger_mask(s), out)
	return out.size()


static func _append_tiger_moves(s: State, occupied: int, out: PackedInt32Array) -> void:
	for t: int in s.tigers:
		for n: int in neighbours[t]:
			if (occupied & (1 << n)) == 0:
				out.append(encode(t, n, NONE))
		var j: Array = jumps[t]
		for k in range(0, j.size(), 2):
			var over: int = j[k]
			var land: int = j[k + 1]
			if (s.goats & (1 << over)) != 0 and (occupied & (1 << land)) == 0:
				out.append(encode(t, land, over))


static func apply(s: State, m: int) -> State:
	var n := s.copy()
	var from := move_from(m)
	var to := move_to(m)
	var over := move_over(m)
	if s.turn == GOAT:
		if from == NONE:
			n.goats |= 1 << to
			n.in_hand -= 1
		else:
			n.goats = (n.goats & ~(1 << from)) | (1 << to)
	else:
		for i in 3:
			if n.tigers[i] == from:
				n.tigers[i] = to
				break
		if over != NONE:
			n.goats &= ~(1 << over)
			n.captured += 1
	n.turn = 1 - s.turn
	return n


static func result(s: State) -> int:
	if s.captured >= CAPTURE_TARGET:
		return TIGERS_WIN
	if legal_moves(s).is_empty():
		return GOATS_WIN if s.turn == TIGER else TIGERS_WIN
	return ONGOING
