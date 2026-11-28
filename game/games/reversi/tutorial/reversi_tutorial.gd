class_name ReversiTutorial
extends RefCounted
## "Learn by playing" lessons for Reversi (BUILD_PLAN.md G5.6). Each lesson sets up a
## small position on the real tray, says what to do in one line, accepts only the moves
## that teach the point, and says what happened once the discs have turned.
## Data only: shell/screens/reversi_tutorial_screen.gd runs it. You always play orange
## (player 0), and it is always your move.

const R := preload("res://games/reversi/reversi_rules.gd")
const ANY := [-1, -1]  ## Accept any legal square.


## Each lesson:
##   title, text: what to show; done: what to say after the move
##   rows: the board from the TOP down, as it reads on screen ("." empty, "0" orange, "1" cream)
##   moves: the squares accepted, as [col, row] (ANY for any); focus: [col, row] squares to ring
##   check: what every accepted move must do, checked by the tests:
##     "flip" (flips at least one), "line" (flips three or more in one line),
##     "many" (flips in five or more directions), "corner", "pass" (cream must pass after)
static func steps() -> Array:
	return [
		{
			"title": "Trap to flip",
			"text": "You're orange. Tap a glowing dot: each one traps a cream disc between your new disc and one of yours.",
			"rows": ["........", "........", "........", "...01...", "...10...", "........", "........", "........"],
			"moves": [ANY], "focus": [], "check": "flip",
			"done": "The trapped disc flipped to orange. Every move must trap at least one disc.",
		},
		{
			"title": "A whole line flips",
			"text": "Three cream discs sit in a row next to yours. Play at the other end to trap them all.",
			"rows": ["........", "........", "........", "........", ".1110...", "........", "........", "........"],
			"moves": [[0, 3]], "focus": [[0, 3]], "check": "line",
			"done": "All three flipped at once. Every disc trapped in a straight line turns over.",
		},
		{
			"title": "Every direction at once",
			"text": "One move can trap lines across, up and down, and on the slants. Play in the middle of the ring.",
			"rows": ["........", ".0.0.0..", "..111...", ".01.10..", "..111...", ".0.0.0..", "........", "........"],
			"moves": [[3, 4]], "focus": [[3, 4]], "check": "many",
			"done": "Eight lines flipped with one disc! Look for squares that trap in several directions.",
		},
		{
			"title": "Corners are safe",
			"text": "You can take the corner. Nothing can ever trap a disc in a corner, so it's yours for good.",
			"rows": ["........", "........", "........", "...0....", "...01...", "..10....", ".1......", "........"],
			"moves": [[0, 0]], "focus": [[0, 0]], "check": "corner",
			"done": "The corner is yours for the rest of the game. Corners, then edges, are the strongest squares.",
		},
		{
			"title": "No move? Pass",
			"text": "Play either glowing dot. Then cream has nowhere to play, so they must pass and you go again.",
			"rows": [".......0", "......1.", "........", "........", "........", "........", ".1......", "0......."],
			"moves": [ANY], "focus": [], "check": "pass",
			"done": "Cream had no move, so they passed and it's your turn again. The game ends when neither player can move; most discs wins.",
		},
	]


## The position for a lesson: orange to move.
static func position(step: Dictionary) -> R.State:
	var rows: Array = (step["rows"] as Array).duplicate()
	rows.reverse()
	return R.from_dict({"rows": rows, "turn": 0, "moves_played": 0})


## The squares a lesson accepts in its position.
static func accepted(step: Dictionary) -> PackedInt32Array:
	var legal := R.legal_moves(position(step))
	if step["moves"].has(ANY):
		return legal
	var out := PackedInt32Array()
	for p: Array in step["moves"]:
		var sq := R.cell(p[0], p[1])
		if legal.has(sq):
			out.append(sq)
	return out


## The squares to ring.
static func focus_cells(step: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	for p: Array in step["focus"]:
		out.append(R.cell(p[0], p[1]))
	return out
