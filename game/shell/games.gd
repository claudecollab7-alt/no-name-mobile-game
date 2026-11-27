class_name Games
extends RefCounted
## What the app says about each game: name, one-liners and the rules card.
## Seed games are in SOWING; the tiger-and-goat games (one engine, two boards) in TIGER.

const S := preload("res://games/sowing/sowing_rules.gd")

const SOWING := {
	"kalah": {
		"title": "Mancala",
		"line": "Sow and capture  ·  2 players  ·  about 5 min",
		"short": "Sow and capture",
		"about": "Sow seeds round the board and collect the most in your store. Land in your store to go again; land in an empty pit to capture.",
		"rules": [
			["Sow", "Pick up all the seeds in one of your pits and drop them one by one into the next pits, going anticlockwise. Your store is on the way; your opponent's is skipped."],
			["Go again", "If your last seed lands in your store, you play again."],
			["Capture", "If your last seed lands in an empty pit on your side, you take it and every seed in the pit opposite."],
			["Game end", "When one side runs out of seeds, each player keeps the seeds on their own side. Most seeds wins."],
		],
	},
	"pallanguzhi": {
		"title": "Pallanguzhi",
		"line": "Keep sowing, then capture  ·  2 players  ·  about 6 min",
		"short": "Keep sowing",
		"about": "A South Indian seed game with fourteen pits. Your sowing keeps going from pit to pit until it stops at an empty one, then you capture the pit beyond it.",
		"rules": [
			["Sow", "Pick up all the seeds in one of your pits and drop them one by one into the next pits, going anticlockwise round both rows."],
			["Keep going", "When your last seed drops, pick up all the seeds in the next pit and keep sowing."],
			["Capture", "If the next pit is empty, take every seed in the pit after it. Then your turn ends."],
			["Pasu", "Whenever a pit reaches exactly 6 seeds, the player whose side it is on takes them at once."],
			["Game end", "When the player to move has no seeds, the game ends. Seeds left go to the side they are on. Most seeds wins."],
		],
	},
}


## Rules rows are [is_tiger, heading, text]: the token beside each row shows whose rule it is.
const TIGER := {
	"aadupuli": {
		"title": "Tiger & Goat",
		"line": "Hunt or trap  ·  2 players  ·  about 8 min",
		"about": "Three tigers hunt fifteen goats on a hill. Tigers win by capturing 5 goats; goats win by trapping every tiger.",
		"lessons": true,
		"rules": [
			[false, "Goats go first", "Place one goat per turn on any empty point. Goats can't move until all 15 are on the board."],
			[true, "Tigers hunt", "Move one step along a path, or jump over a goat to the empty point behind it to capture it."],
			[true, "Tigers win", "by capturing 5 goats."],
			[false, "Goats win", "by trapping all 3 tigers so none can move, or by holding out: once all goats are placed, if the tigers make 40 moves without a capture, the goats win."],
			[false, "No endless shuffling", "You can't make a move that repeats the same position a third time."],
		],
	},
	"baghchal": {
		"title": "Bagh-Chal",
		"line": "Hunt or trap  ·  2 players  ·  about 10 min",
		"short": "Four tigers, twenty goats",
		"about": "Nepal's tiger game. Four tigers start in the corners and hunt twenty goats. Tigers win by capturing 5 goats; goats win by trapping all four tigers.",
		"lessons": true,
		"rules": [
			[false, "Goats go first", "Place one goat per turn on any empty point. Goats can't move until all 20 are on the board."],
			[true, "Tigers hunt", "Move one step along a line, or jump over a goat to the empty point behind it to capture it. Tigers may hunt while goats are still being placed."],
			[true, "Tigers win", "by capturing 5 goats."],
			[false, "Goats win", "by trapping all 4 tigers so none can move."],
			[false, "No going back", "Once all goats are placed, no move may bring back a position that has already happened."],
		],
	},
}


static func tiger_info(board: String) -> Dictionary:
	return TIGER.get(board, TIGER["aadupuli"])


static func rules_for(id: String) -> Dictionary:
	return S.config_for(id)


static func info(id: String) -> Dictionary:
	return SOWING.get(id, SOWING["kalah"])


static func title(id: String) -> String:
	if TIGER.has(id):
		return str(TIGER[id]["title"])
	return str(info(id)["title"])


## The tiger games (Tiger & Goat, Bagh-Chal) share one set of screens.
static func is_tiger(id: String) -> bool:
	return TIGER.has(id)


## Shows the rules card for a sowing game.
static func how_to_play(host: Node, id: String) -> void:
	var rows: Array = []
	for step: Array in info(id)["rules"]:
		var row := Ui.hbox(28)
		var ic := Ui.icon("circle-dot", 56, Ui.ACCENT)
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(ic)
		var words := Ui.vbox(2)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(Ui.heading(step[0], 38))
		var body := Ui.muted(step[1], 30)
		body.custom_minimum_size.x = 700
		words.add_child(body)
		row.add_child(words)
		rows.append(row)
	Modal.show(host, TranslationServer.translate("How to play %s") % TranslationServer.translate(title(id)), rows, [
		["Try the tutorial", func() -> void: host.push(load("res://shell/screens/sowing_tutorial_screen.gd").create(id))],
		["Got it", func() -> void: pass, true],
	])
