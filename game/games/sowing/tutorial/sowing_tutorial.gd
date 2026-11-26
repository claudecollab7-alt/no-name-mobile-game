class_name SowingTutorial
extends RefCounted
## "Learn by playing" lessons for the seed games (BUILD_PLAN.md G2.5). Each lesson sets
## up a small position on the real board, says what to do in one line, accepts only the
## move that teaches the point, and says what happened once the seeds have landed.
## Data only: shell/screens/sowing_tutorial_screen.gd runs it. You always play the
## bottom row (player 0).

const S := preload("res://games/sowing/sowing_rules.gd")
const ANY := -1  ## Accept any of your pits.


## Each lesson:
##   title, text: what to show; done: what to say after the move
##   pits, stores: the position (empty pits = the starting position)
##   moves: the pits accepted (ANY for any); focus: pits to spotlight
##   after: what the position looks like after the move (checked by the tests)
static func steps(game_id: String) -> Array:
	if game_id == "pallanguzhi":
		return [
			{
				"title": "Sow and capture",
				"text": "Tap the glowing pit. Its seeds drop one by one into the next pits. If the pit after your last seed is empty, you win the pit beyond it.",
				"pits": [2, 1, 1, 0, 4, 1, 1, 2, 2, 2, 2, 2, 2, 2], "stores": [30, 30],
				"moves": [0], "focus": [0, 4],
				"done": "You won 4 seeds. After a capture, your turn ends.",
				"after": {"stores": [34, 30], "turn": 1},
			},
			{
				"title": "Keep sowing",
				"text": "When your last seed drops, pick up the next pit and keep going. Tap the glowing pit and watch the seeds travel.",
				"pits": [1, 0, 3, 0, 0, 0, 0, 2, 1, 1, 1, 1, 1, 1], "stores": [36, 36],
				"moves": [0], "focus": [0, 2],
				"done": "Your sowing carried on from pit to pit until it reached an empty one, then captured. Long chains are the heart of Pallanguzhi.",
				"after": {"stores": [38, 36], "turn": 1},
			},
			{
				"title": "Pasu: six seeds",
				"text": "A pit that reaches exactly 6 seeds is a pasu: its owner takes them at once. Tap the glowing pit to make the next one six.",
				"pits": [2, 5, 0, 0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1], "stores": [32, 33],
				"moves": [0], "focus": [0, 1],
				"done": "Pasu! Six seeds for you, and a capture too. Careful: a six in your opponent's pit goes to them.",
				"after": {"stores": [41, 33], "turn": 1},
			},
			{
				"title": "The end",
				"text": "The game ends when the player to move has no seeds. Seeds left go to the side they are on. Play your last seed.",
				"pits": [0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], "stores": [43, 40],
				"moves": [2], "focus": [2],
				"done": "Your opponent has no seeds left, so the game is over: 44 seeds to 40. You win!",
				"after": {"stores": [44, 40], "over": true},
			},
		]
	return [
		{
			"title": "Sow your seeds",
			"text": "Your pits are the bottom row. Tap any of them: its seeds go one by one into the next pits, to the right.",
			"pits": [], "stores": [0, 0],
			"moves": [ANY], "focus": [],
			"done": "Seeds always travel the same way round: along your row, into your store on the right, then along the top row.",
			"after": {},
		},
		{
			"title": "Land in your store",
			"text": "This pit has 4 seeds, exactly enough to reach your store on the right. Tap it.",
			"pits": [], "stores": [0, 0],
			"moves": [2], "focus": [2],
			"done": "Your last seed landed in your store, so you play again.",
			"after": {"stores": [1, 0], "turn": 0},
		},
		{
			"title": "Capture",
			"text": "If your last seed lands in an empty pit on your side, you take it and every seed in the pit opposite. Tap the glowing pit.",
			"pits": [1, 0, 3, 2, 0, 1, 2, 3, 1, 4, 5, 2], "stores": [10, 14],
			"moves": [0], "focus": [0, 10],
			"done": "Captured! Six seeds go to your store.",
			"after": {"stores": [16, 14], "turn": 1},
		},
		{
			"title": "The end",
			"text": "When a row runs out of seeds, the game ends and each player keeps the seeds on their own side. Play your last seed.",
			"pits": [0, 0, 0, 0, 0, 1, 2, 1, 0, 3, 0, 1], "stores": [25, 15],
			"moves": [5], "focus": [5],
			"done": "Your row is empty, so the game is over: 26 seeds to 22. You win!",
			"after": {"stores": [26, 22], "over": true},
		},
	]


## Builds the position for a lesson; you (player 0) are to move.
static func position(game_id: String, step: Dictionary) -> S.State:
	var s := S.new_game(Games.rules_for(game_id), 0)
	if not (step["pits"] as Array).is_empty():
		s.pits = PackedInt32Array(step["pits"])
	s.stores = PackedInt32Array(step["stores"])
	return s


## The pits the lesson accepts in its position.
static func accepted(game_id: String, step: Dictionary) -> PackedInt32Array:
	var legal := S.legal_moves(position(game_id, step))
	if (step["moves"] as Array).has(ANY):
		return legal
	var out := PackedInt32Array()
	for m: int in step["moves"]:
		if legal.has(m):
			out.append(m)
	return out
