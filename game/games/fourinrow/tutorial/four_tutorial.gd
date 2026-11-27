class_name FourTutorial
extends RefCounted
## "Learn by playing" lessons for Four in a Row (BUILD_PLAN.md G4.6). Each lesson sets up
## a small position on the real frame, says what to do in one line, accepts only the
## moves that teach the point, and says what happened once the disc has landed.
## Data only: shell/screens/four_tutorial_screen.gd runs it. You always play orange
## (player 0, who moves first), and it is always your move.

const F := preload("res://games/fourinrow/four_rules.gd")
const ANY := -1  ## Accept any column.


## Each lesson:
##   title, text: what to show; done: what to say after the move
##   columns: each column's discs from the bottom up (0 orange, 1 cream)
##   moves: the columns accepted (ANY for any); focus: [col, row] spaces to ring
##   wins: whether every accepted move makes four (checked by the tests)
static func steps() -> Array:
	return [
		{
			"title": "Drop a disc",
			"text": "You're orange. Tap any column: your disc falls to the lowest empty space.",
			"columns": [[], [], [], [], [], [], []],
			"moves": [ANY], "focus": [], "wins": false,
			"done": "Discs always fall as far down as they can. Then it's your opponent's turn.",
		},
		{
			"title": "Four in a row wins",
			"text": "You have three in a row along the bottom. Drop a disc at either end to make four.",
			"columns": [[], [0, 1], [0, 1], [0], [], [], [1]],
			"moves": [0, 4], "focus": [[0, 0], [4, 0]], "wins": true,
			"done": "Four in a row! Across, up and down, or diagonally, four wins the game.",
		},
		{
			"title": "Block their three",
			"text": "Cream has three stacked in a column. Drop a disc on top before they make four.",
			"columns": [[], [], [0], [0, 0], [], [1, 1, 1], []],
			"moves": [5], "focus": [[5, 3]], "wins": false,
			"done": "Blocked! Always look for three of theirs in a line, and fill the open end.",
		},
		{
			"title": "Diagonals count",
			"text": "Lines on a slant count too. Finish the diagonal from the bottom corner.",
			"columns": [[0], [1, 0], [0, 1, 0], [1, 1, 0], [], [], [1]],
			"moves": [3], "focus": [[0, 0], [1, 1], [2, 2], [3, 3]], "wins": true,
			"done": "A diagonal four! The slants are the easiest lines to miss, for you and for them.",
		},
	]


## The position for a lesson: orange to move.
static func position(step: Dictionary) -> F.State:
	return F.from_dict({"columns": step["columns"], "turn": 0})


## The columns a lesson accepts in its position.
static func accepted(step: Dictionary) -> PackedInt32Array:
	var legal := F.legal_moves(position(step))
	if step["moves"].has(ANY):
		return legal
	var out := PackedInt32Array()
	for c: int in step["moves"]:
		if legal.has(c):
			out.append(c)
	return out


## The spaces to ring, in Grid numbering (row * 7 + col), as the board expects.
static func focus_cells(step: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	for p: Array in step["focus"]:
		out.append(Grid.cell(F.COLS, p[0], p[1]))
	return out
