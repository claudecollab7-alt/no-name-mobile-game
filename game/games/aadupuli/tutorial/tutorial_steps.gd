class_name AadupuliTutorial
extends RefCounted
## The "learn by playing" steps for Tiger & Goat (BUILD_PLAN.md task 3.2).
## Each step sets up a small position, says what to do in one line, and accepts only
## the moves that teach the point. The player plays both sides, one lesson at a time.
## Data only: the tutorial screen (shell/screens/tutorial_screen.gd) runs it.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")
const ANY := -1  ## Accept any legal move for the side to play.


## Returns the steps. Each step:
##   title, text: what to show
##   tigers, goats, in_hand, turn, captured: the position
##   moves: the moves accepted (ANY for any legal move)
##   focus: points to spotlight
##   done: what to say after the right move
static func steps() -> Array:
	return [
		{
			"title": "Goats go first",
			"text": "The goats start off the board. Tap any glowing point to place your first goat.",
			"tigers": [0, 3, 4], "goats": [], "in_hand": 15, "turn": R.GOAT, "captured": 0,
			"moves": [ANY], "focus": [],
			"done": "Nice. Goats keep coming, one per turn, until all 15 are on the hill.",
		},
		{
			"title": "Tigers walk the paths",
			"text": "Now you're a tiger. Tap the tiger in the cave, then a glowing point to step down a path.",
			"tigers": [0, 3, 4], "goats": [19], "in_hand": 14, "turn": R.TIGER, "captured": 0,
			"moves": [R.encode(0, 2, R.NONE), R.encode(0, 5, R.NONE)], "focus": [0],
			"done": "Tigers move one step at a time, along the lines.",
		},
		{
			"title": "Jump to capture",
			"text": "A goat with an empty point right behind it can be caught. Tap the glowing tiger and jump over the goat.",
			"tigers": [0, 3, 4], "goats": [9, 19, 22], "in_hand": 12, "turn": R.TIGER, "captured": 0,
			"moves": [R.encode(3, 15, 9)], "focus": [3, 9],
			"done": "Caught! Five captures and the tigers win.",
		},
		{
			"title": "Goats move too",
			"text": "Once all 15 goats are placed, goats can step along the paths. Move any goat.",
			"tigers": [0, 10, 16], "goats": [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 17, 18], "in_hand": 0,
			"turn": R.GOAT, "captured": 0,
			"moves": [ANY], "focus": [],
			"done": "Goats never jump. They win by working together.",
		},
		{
			"title": "Trap every tiger",
			"text": "Two tigers are already stuck. Close the last gap so no tiger can move: move the glowing goat.",
			"tigers": [13, 19, 22], "goats": [2, 3, 4, 7, 8, 9, 10, 11, 14, 15, 17, 20, 21], "in_hand": 0,
			"turn": R.GOAT, "captured": 2,
			"moves": [R.encode(2, 1, R.NONE)], "focus": [2, 1],
			"done": "Every tiger is trapped. The goats win!",
		},
	]


## Builds the position for a step.
static func position(step: Dictionary) -> R.State:
	var s := R.new_game()
	s.tigers = PackedInt32Array(step["tigers"])
	s.goats = 0
	for p: int in step["goats"]:
		s.goats |= 1 << p
	s.in_hand = int(step["in_hand"])
	s.turn = int(step["turn"])
	s.captured = int(step["captured"])
	s.counts = {R.position_key(s): 1}
	return s


## The moves the step accepts in its position.
static func accepted(step: Dictionary) -> PackedInt32Array:
	var legal := R.legal_moves(position(step))
	if step["moves"].has(ANY):
		return legal
	var out := PackedInt32Array()
	for m: int in step["moves"]:
		if legal.has(m):
			out.append(m)
	return out
