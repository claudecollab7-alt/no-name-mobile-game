class_name AadupuliRules
extends RefCounted
## Rules of Tiger & Goat (Aadupuli) on the classic 23-point board.
##
## The only place that knows what is legal (BUILD_PLAN.md section 3). Pure data:
## no nodes, no screen code, so it runs from tests and from the command line.
## Rules as decided in DISCUSSION.md section 17: goats place first, one per turn,
## and cannot move until all are placed; tigers move one step or jump one goat;
## captures are optional; tigers win at CAPTURE_TARGET captures; goats win when
## no tiger can move; a move that would recreate a position for the third time
## is not allowed, and a side left with no legal move loses.
##
## Moves are packed ints: from | to << 5 | over << 10, with NONE (31) for "no point".

const NONE := 31
const GOAT := 0
const TIGER := 1
const POINT_COUNT := 23

const ONGOING := 0
const GOATS_WIN := 1
const TIGERS_WIN := 2

const DEFAULT_OPTIONS := {
	"capture_target": 5,  # D10, to be settled by self-play in phase 2.
	"repeat_limit": 3,  # D12: the third occurrence of a position is illegal.
	"goat_count": 15,  # D34: other counts may come later.
	"start_tigers": [0, 3, 4],  # D35: fixed start.
}

## Point positions from the verified board picture (docs/board-reference.png).
const POINTS: Array[Vector2] = [
	Vector2(278, 22),
	Vector2(16, 97), Vector2(224, 97), Vector2(256, 97), Vector2(293, 97), Vector2(333, 97), Vector2(524, 97),
	Vector2(16, 150), Vector2(185, 150), Vector2(239, 150), Vector2(305, 150), Vector2(372, 150), Vector2(524, 150),
	Vector2(16, 209), Vector2(143, 209), Vector2(221, 209), Vector2(317, 209), Vector2(410, 209), Vector2(524, 209),
	Vector2(50, 349), Vector2(179, 349), Vector2(344, 349), Vector2(506, 349),
]

## Every straight line on the board, points in order. Moves follow these lines;
## a jump needs three points in a row on one line.
const LINES: Array = [
	[0, 2, 8, 14, 19], [0, 3, 9, 15, 20], [0, 4, 10, 16, 21], [0, 5, 11, 17, 22],
	[1, 2, 3, 4, 5, 6], [7, 8, 9, 10, 11, 12], [13, 14, 15, 16, 17, 18], [19, 20, 21, 22],
	[1, 7, 13], [6, 12, 18],
]

static var _neighbours: Array[PackedInt32Array] = []
static var _jumps: Array[PackedInt32Array] = []  ## [over, land, over, land, ...] per point


## A complete game position. Treat as immutable: apply() returns a new State.
class State:
	var tigers := PackedInt32Array()
	var goats := 0  ## Bit p is set when a goat stands on point p.
	var in_hand := 0
	var captured := 0
	var turn := 0  ## GOAT or TIGER
	var moves_played := 0
	var capture_target := 5
	var repeat_limit := 3
	var goat_count := 15
	var counts := {}  ## position key -> times seen, for the no-repeat rule

	func copy() -> State:
		var s := State.new()
		s.tigers = tigers.duplicate()
		s.goats = goats
		s.in_hand = in_hand
		s.captured = captured
		s.turn = turn
		s.moves_played = moves_played
		s.capture_target = capture_target
		s.repeat_limit = repeat_limit
		s.goat_count = goat_count
		s.counts = counts  # Shared until apply() records a new position (copy-on-write).
		return s


static func neighbours(p: int) -> PackedInt32Array:
	_build()
	return _neighbours[p]


static func jumps(p: int) -> PackedInt32Array:
	_build()
	return _jumps[p]


static func _build() -> void:
	if not _neighbours.is_empty():
		return
	var n: Array = []
	var j: Array = []
	for i in POINT_COUNT:
		n.append([])
		j.append([])
	for line: Array in LINES:
		for k in range(line.size() - 1):
			n[line[k]].append(line[k + 1])
			n[line[k + 1]].append(line[k])
		for k in range(line.size() - 2):
			j[line[k]].append_array([line[k + 1], line[k + 2]])
			j[line[k + 2]].append_array([line[k + 1], line[k]])
	for i in POINT_COUNT:
		_neighbours.append(PackedInt32Array(n[i]))
		_jumps.append(PackedInt32Array(j[i]))


static func new_game(options: Dictionary = {}) -> State:
	_build()
	var o := DEFAULT_OPTIONS.merged(options, true)
	var s := State.new()
	s.tigers = PackedInt32Array(o["start_tigers"])
	s.goat_count = o["goat_count"]
	s.in_hand = s.goat_count
	s.capture_target = o["capture_target"]
	s.repeat_limit = o["repeat_limit"]
	s.counts = {position_key(s): 1}
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
	var mask := 0
	for t in s.tigers:
		mask |= 1 << t
	return mask


static func goat_at(s: State, p: int) -> bool:
	return (s.goats & (1 << p)) != 0


static func tiger_at(s: State, p: int) -> bool:
	return s.tigers.has(p)


static func goats_on_board(s: State) -> int:
	var n := 0
	var g := s.goats
	while g != 0:
		g &= g - 1
		n += 1
	return n


## Same position = same goats, same tigers (order ignored), same side to move.
## Goats in hand always fall during placement, so placement positions never repeat.
static func position_key(s: State) -> int:
	return s.goats | (tiger_mask(s) << POINT_COUNT) | (s.turn << (POINT_COUNT * 2)) | (s.in_hand << (POINT_COUNT * 2 + 1))


## Every move the side to move may make, honouring the no-repeat rule.
static func legal_moves(s: State) -> PackedInt32Array:
	var moves := pseudo_moves(s)
	if s.in_hand > 0 or s.counts.is_empty():
		return moves
	var out := PackedInt32Array()
	for m in moves:
		var key := position_key(apply(s, m, false))
		if s.counts.get(key, 0) < s.repeat_limit - 1:
			out.append(m)
	return out


## Moves allowed by movement alone, ignoring the no-repeat rule. Used by search.
static func pseudo_moves(s: State) -> PackedInt32Array:
	_build()
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
				for n in _neighbours[p]:
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
	for t in s.tigers:
		for n in _neighbours[t]:
			if (occupied & (1 << n)) == 0:
				out.append(encode(t, n, NONE))
		var j := _jumps[t]
		for k in range(0, j.size(), 2):
			if (s.goats & (1 << j[k])) != 0 and (occupied & (1 << j[k + 1])) == 0:
				out.append(encode(t, j[k + 1], j[k]))


## Returns the position after move m. With record=false the repeat counts are left
## untouched, which is much faster for search.
static func apply(s: State, m: int, record := true) -> State:
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
		for i in n.tigers.size():
			if n.tigers[i] == from:
				n.tigers[i] = to
				break
		if over != NONE:
			n.goats &= ~(1 << over)
			n.captured += 1
	n.turn = 1 - s.turn
	n.moves_played = s.moves_played + 1
	if record:
		n.counts = s.counts.duplicate()
		var key := position_key(n)
		n.counts[key] = n.counts.get(key, 0) + 1
	return n


static func result(s: State) -> int:
	if s.captured >= s.capture_target:
		return TIGERS_WIN
	if legal_moves(s).is_empty():
		return GOATS_WIN if s.turn == TIGER else TIGERS_WIN
	return ONGOING


static func to_dict(s: State) -> Dictionary:
	var counts := {}
	for k: int in s.counts:
		counts[str(k)] = s.counts[k]
	return {
		"tigers": Array(s.tigers), "goats": s.goats, "in_hand": s.in_hand, "captured": s.captured,
		"turn": s.turn, "moves_played": s.moves_played, "capture_target": s.capture_target,
		"repeat_limit": s.repeat_limit, "goat_count": s.goat_count, "counts": counts,
	}


static func from_dict(d: Dictionary) -> State:
	_build()
	var s := State.new()
	s.tigers = PackedInt32Array(d["tigers"])
	s.goats = int(d["goats"])
	s.in_hand = int(d["in_hand"])
	s.captured = int(d["captured"])
	s.turn = int(d["turn"])
	s.moves_played = int(d.get("moves_played", 0))
	s.capture_target = int(d.get("capture_target", 5))
	s.repeat_limit = int(d.get("repeat_limit", 3))
	s.goat_count = int(d.get("goat_count", 15))
	s.counts = {}
	var counts: Dictionary = d.get("counts", {})
	for k in counts:
		s.counts[int(k)] = int(counts[k])
	return s
