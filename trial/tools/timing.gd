extends SceneTree
## Command-line timing test (BUILD_PLAN.md task T0.6) plus quick rule sanity checks.
## Run from the repository root:
##   godot --headless --path trial -s res://tools/timing.gd

const R := preload("res://rules.gd")
const Search := preload("res://search.gd")


func _init() -> void:
	R.build()
	_check_board()
	_check_random_games(300)
	print("")
	print("Look-ahead in 1 second (this computer):")
	_report("Opening, goats to place their first goat", R.new_game())
	_report("Placement half done, goats to play", _position([0, 9, 16], [1, 2, 5, 6, 7, 8, 11, 12], 7, 0, R.GOAT))
	_report("All goats placed, tigers to play", _position([3, 10, 15], [1, 2, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 17], 0, 2, R.TIGER))
	quit()


func _check_board() -> void:
	var links := 0
	for p in R.POINT_COUNT:
		links += (R.neighbours[p] as Array).size()
	var symmetric := true
	for p in R.POINT_COUNT:
		for n: int in R.neighbours[p]:
			if not (R.neighbours[n] as Array).has(p):
				symmetric = false
	print("Board: %d points, %d connections, two-way: %s" % [R.POINT_COUNT, links / 2, symmetric])


## Plays random games to the end and checks the 15-goat total never breaks.
func _check_random_games(count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var wins := [0, 0, 0]
	var total_moves := 0
	var broken := 0
	for g in count:
		var s := R.new_game()
		var moves := 0
		while R.result(s) == R.ONGOING and moves < 400:
			var legal := R.legal_moves(s)
			s = R.apply(s, legal[rng.randi_range(0, legal.size() - 1)])
			moves += 1
			var on_board := 0
			for p in R.POINT_COUNT:
				if R.goat_at(s, p):
					on_board += 1
			if on_board + s.in_hand + s.captured != R.GOAT_TOTAL:
				broken += 1
		wins[R.result(s)] += 1
		total_moves += moves
	print("Random games: %d played, goats won %d, tigers won %d, unfinished after 400 moves %d, average %d moves, goat-count errors %d" % [
		count, wins[R.GOATS_WIN], wins[R.TIGERS_WIN], wins[R.ONGOING], total_moves / count, broken])


func _position(tigers: Array[int], goats: Array, in_hand: int, captured: int, turn: int) -> R.State:
	var s := R.new_game()
	s.tigers = tigers
	s.goats = 0
	for p: int in goats:
		s.goats |= 1 << p
	s.in_hand = in_hand
	s.captured = captured
	s.turn = turn
	return s


func _report(label: String, s: R.State) -> void:
	var search := Search.new()
	search.think(s, 1000)
	print("  %-45s depth %2d  in %4d ms  %8d positions  (%d per second)" % [
		label, search.depth_reached, search.elapsed_ms, search.nodes, int(search.nodes * 1000.0 / maxf(1.0, search.elapsed_ms))])
