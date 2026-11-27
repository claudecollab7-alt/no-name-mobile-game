class_name SowingRules
extends RefCounted
## Rules for the pits-and-seeds family (DISCUSSION.md section 29): Kalah ("Mancala")
## and Pallanguzhi today, Oware later. Pure data, no screen code.
##
## Layout: 2N pits in anticlockwise order. Player 0 owns pits 0..N-1 (bottom row,
## left to right); player 1 owns pits N..2N-1 (top row, right to left). Opposite of
## pit i is 2N-1-i. Captured seeds sit in stores[player]; in Kalah the stores are part
## of the sowing path, in Pallanguzhi they are each player's pile beside the board.
##
## apply() also returns the steps of the move (pick up, drop, relay, capture, pasu,
## extra turn, sweep) so the board can animate seeds one at a time.

const KALAH := {
	"id": "kalah", "pits": 6, "seeds": 4, "store_in_path": true, "extra_turn": true,
	"capture": "opposite", "relay": false, "pasu": 0,
}
const PALLANGUZHI := {
	"id": "pallanguzhi", "pits": 7, "seeds": 6, "store_in_path": false, "extra_turn": false,
	"capture": "beyond_empty", "relay": true, "pasu": 6, "pasu_to": "owner",
}
## The rules for a game id ("kalah" or "pallanguzhi").
static func config_for(id: String) -> Dictionary:
	return PALLANGUZHI if id == "pallanguzhi" else KALAH


const MAX_DROPS := 400  ## Safety stop for relay sowing, which can very rarely loop.

const ONGOING := 0
const WIN_0 := 1
const WIN_1 := 2
const DRAW := 3

## Step kinds recorded by apply().
const PICK := "pick"  ## [PICK, pit, count]
const DROP := "drop"  ## [DROP, pit or STORE_0/STORE_1]
const RELAY := "relay"  ## [RELAY, pit, count]: Pallanguzhi picks up the next pit
const CAPTURE := "capture"  ## [CAPTURE, pit, count, player]
const PASU := "pasu"  ## [PASU, pit, count, player]: a pit reaching 6 goes to its owner (D63)
const AGAIN := "again"  ## [AGAIN, player]: extra turn
const SWEEP := "sweep"  ## [SWEEP, pit, count, player]: leftovers at the end
const STORE_0 := 100
const STORE_1 := 101


class State:
	var game := {}  ## KALAH or PALLANGUZHI
	var pits := PackedInt32Array()
	var stores := PackedInt32Array([0, 0])
	var turn := 0
	var over := false
	var moves_played := 0

	func copy() -> State:
		var s := State.new()
		s.game = game
		s.pits = pits.duplicate()
		s.stores = stores.duplicate()
		s.turn = turn
		s.over = over
		s.moves_played = moves_played
		return s


static func new_game(game: Dictionary, first := 0) -> State:
	var s := State.new()
	s.game = game
	var n: int = game["pits"]
	s.pits.resize(n * 2)
	s.pits.fill(int(game["seeds"]))
	s.turn = first
	return s


static func pits_per_side(s: State) -> int:
	return int(s.game["pits"])


static func owner(s: State, pit: int) -> int:
	return 0 if pit < pits_per_side(s) else 1


static func opposite(s: State, pit: int) -> int:
	return s.pits.size() - 1 - pit


static func side_total(s: State, player: int) -> int:
	var n := pits_per_side(s)
	var total := 0
	for i in range(player * n, player * n + n):
		total += s.pits[i]
	return total


static func total_seeds(s: State) -> int:
	var t := s.stores[0] + s.stores[1]
	for v in s.pits:
		t += v
	return t


static func legal_moves(s: State) -> PackedInt32Array:
	var out := PackedInt32Array()
	if s.over:
		return out
	var n := pits_per_side(s)
	for i in range(s.turn * n, s.turn * n + n):
		if s.pits[i] > 0:
			out.append(i)
	return out


static func result(s: State) -> int:
	if not s.over:
		return ONGOING
	if s.stores[0] > s.stores[1]:
		return WIN_0
	if s.stores[1] > s.stores[0]:
		return WIN_1
	return DRAW


## Plays pit `pit` for the player to move. Returns [new_state, steps]. With record
## false the steps are not collected (the computer's search plays thousands of moves).
static func apply(s: State, pit: int, record := true) -> Array:
	var n := s.copy()
	var steps: Array = []
	if bool(s.game["store_in_path"]):
		_sow_kalah(n, pit, steps, record)
	else:
		_sow_relay(n, pit, steps, record)
	n.moves_played = s.moves_played + 1
	_check_end(n, steps)
	return [n, steps]


## Convenience for search and tests: the position after a move, without the steps.
static func after(s: State, pit: int) -> State:
	return apply(s, pit, false)[0]


# ---------- Kalah ----------

static func _sow_kalah(s: State, pit: int, steps: Array, record: bool) -> void:
	var me := s.turn
	var size := s.pits.size()
	var half := size / 2
	var seeds := s.pits[pit]
	s.pits[pit] = 0
	steps.append([PICK, pit, seeds])
	# Ring positions: pits 0..half-1, store 0, pits half..size-1, store 1.
	var pos := _ring_of(pit, half)
	var last := -1
	while seeds > 0:
		pos = (pos + 1) % (size + 2)
		var where := _place_of(pos, half)
		if where == (STORE_1 if me == 0 else STORE_0):
			continue  # Never sow into the opponent's store.
		if where >= STORE_0:
			s.stores[where - STORE_0] += 1
		else:
			s.pits[where] += 1
		if record:
			steps.append([DROP, where])
		seeds -= 1
		last = where
	if last == (STORE_0 if me == 0 else STORE_1) and bool(s.game["extra_turn"]):
		steps.append([AGAIN, me])
		return  # Same player moves again.
	if last < STORE_0 and owner(s, last) == me and s.pits[last] == 1:
		var opp := opposite(s, last)
		if s.pits[opp] > 0:
			var taken := s.pits[opp] + 1
			s.stores[me] += taken
			steps.append([CAPTURE, opp, s.pits[opp], me])
			steps.append([CAPTURE, last, 1, me])
			s.pits[opp] = 0
			s.pits[last] = 0
	s.turn = 1 - me


static func _ring_of(pit: int, half: int) -> int:
	return pit if pit < half else pit + 1


static func _place_of(pos: int, half: int) -> int:
	if pos < half:
		return pos
	if pos == half:
		return STORE_0
	if pos == half * 2 + 1:
		return STORE_1
	return pos - 1


# ---------- Pallanguzhi ----------

static func _sow_relay(s: State, pit: int, steps: Array, record: bool) -> void:
	var me := s.turn
	var size := s.pits.size()
	var pasu := int(s.game["pasu"])
	var seeds := s.pits[pit]
	s.pits[pit] = 0
	steps.append([PICK, pit, seeds])
	var pos := pit
	var drops := 0
	while true:
		while seeds > 0:
			pos = (pos + 1) % size
			s.pits[pos] += 1
			seeds -= 1
			drops += 1
			if record:
				steps.append([DROP, pos])
			if pasu > 0 and s.pits[pos] == pasu:
				var taker := me if str(s.game.get("pasu_to", "owner")) == "sower" else owner(s, pos)
				s.stores[taker] += pasu
				steps.append([PASU, pos, pasu, taker])
				s.pits[pos] = 0
		if drops >= MAX_DROPS:
			break
		var next := (pos + 1) % size
		if s.pits[next] > 0:
			seeds = s.pits[next]
			s.pits[next] = 0
			pos = next
			steps.append([RELAY, next, seeds])
			continue
		var beyond := (next + 1) % size
		var taken := s.pits[beyond]
		s.stores[me] += taken
		s.pits[beyond] = 0
		steps.append([CAPTURE, beyond, taken, me])
		break
	s.turn = 1 - me


# ---------- End of game ----------

## Kalah ends when either side is empty; Pallanguzhi when the player to move has no
## seeds. Seeds still on the board go to the owner of the side they are on.
static func _check_end(s: State, steps: Array) -> void:
	var ends := false
	if bool(s.game["store_in_path"]):
		ends = side_total(s, 0) == 0 or side_total(s, 1) == 0
	else:
		ends = side_total(s, s.turn) == 0
	if not ends:
		return
	for i in s.pits.size():
		if s.pits[i] > 0:
			var who := owner(s, i)
			steps.append([SWEEP, i, s.pits[i], who])
			s.stores[who] += s.pits[i]
			s.pits[i] = 0
	s.over = true


static func to_dict(s: State) -> Dictionary:
	return {"game": s.game["id"], "pits": Array(s.pits), "stores": Array(s.stores), "turn": s.turn,
		"over": s.over, "moves_played": s.moves_played}


static func from_dict(d: Dictionary) -> State:
	var s := State.new()
	s.game = KALAH if str(d["game"]) == "kalah" else PALLANGUZHI
	s.pits = PackedInt32Array(d["pits"])
	s.stores = PackedInt32Array(d["stores"])
	s.turn = int(d["turn"])
	s.over = bool(d["over"])
	s.moves_played = int(d.get("moves_played", 0))
	return s
