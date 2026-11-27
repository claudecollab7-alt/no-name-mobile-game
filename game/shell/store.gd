extends Node
## Everything the app remembers, kept only on this phone (D21, D47): profile, settings,
## stats and badges. One versioned JSON file, written to a temporary file and then
## renamed, so a crash mid-save cannot corrupt it.

signal changed

const PATH := "user://save.json"
const VERSION := 1

var data := {}


func _ready() -> void:
	load_data()


func defaults() -> Dictionary:
	var now := Time.get_date_dict_from_system()
	return {
		"version": VERSION,
		"profile": {"name": "", "avatar": "goat", "colour": 1, "since": "%04d-%02d" % [now["year"], now["month"]]},
		"settings": {"sound": true, "vibration": true, "hints": true, "reduce_motion": false, "theme": "meadow"},
		"last": {"mode": "computer", "level": "medium", "side": "goats"},
		"seen_rules": false,
		"tutorial_done": false,
		"stats": {"played": 0, "wins": 0, "losses": 0, "streak": 0, "best_streak": 0,
			"tiger_wins": 0, "tiger_losses": 0, "goat_wins": 0, "goat_losses": 0,
			"pass_games": 0, "hardest": "", "online_wins": 0, "online_losses": 0},
		"daily": {"streak": 0, "best": 0, "last_date": "", "solved": {}},
		# Per-game records for the games after Tiger & Goat (its record lives in "stats").
		"games": {
			"kalah": {"played": 0, "wins": 0, "losses": 0, "draws": 0, "pass_games": 0, "next_first": 0,
				"tutorial_done": false, "tutorial_offered": false, "puzzles_solved": []},
			"pallanguzhi": {"played": 0, "wins": 0, "losses": 0, "draws": 0, "pass_games": 0, "next_first": 0,
				"tutorial_done": false, "tutorial_offered": false, "puzzles_solved": []},
			"baghchal": {"played": 0, "wins": 0, "losses": 0, "draws": 0, "pass_games": 0,
				"tiger_wins": 0, "tiger_losses": 0, "goat_wins": 0, "goat_losses": 0,
				"tutorial_done": false, "tutorial_offered": false, "puzzles_solved": []},
		},
		"online": {"token": "", "server": "", "muted": false, "search_side": "any", "room_side": "random"},
	}


func load_data() -> void:
	data = defaults()
	if FileAccess.file_exists(PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_merge(data, parsed)
	data["version"] = VERSION


func save_data() -> void:
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Could not save progress: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	DirAccess.rename_absolute(tmp, PATH)
	changed.emit()


## Copies saved values over the defaults, so new settings in a later version get defaults.
func _merge(into: Dictionary, from: Dictionary) -> void:
	for k in from:
		if into.has(k) and into[k] is Dictionary and from[k] is Dictionary:
			_merge(into[k], from[k])
		elif into.has(k):
			into[k] = from[k]


# ---------- Settings ----------

func setting(key: String) -> Variant:
	return data["settings"].get(key)


func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	save_data()


func last(key: String) -> String:
	return str(data["last"].get(key, ""))


func set_last(key: String, value: String) -> void:
	data["last"][key] = value
	save_data()


# ---------- Profile ----------

func player_name() -> String:
	var n: String = str(data["profile"]["name"]).strip_edges()
	return n if n != "" else tr("Player")


func set_profile(player: String, avatar: String, colour: int) -> void:
	data["profile"]["name"] = player.strip_edges().left(16)
	data["profile"]["avatar"] = avatar
	data["profile"]["colour"] = colour
	save_data()


func avatar() -> String:
	return str(data["profile"]["avatar"])


func avatar_colour() -> int:
	return int(data["profile"]["colour"])


func since_text() -> String:
	var parts := str(data["profile"]["since"]).split("-")
	if parts.size() < 2:
		return ""
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %s" % [months[clampi(int(parts[1]) - 1, 0, 11)], parts[0]]


# ---------- Stats ----------

## mode "computer" or "pass"; side "tigers" or "goats" (the human's side vs the computer).
func record_game(mode: String, side: String, level: String, human_won: bool) -> void:
	var s: Dictionary = data["stats"]
	s["played"] += 1
	if mode == "pass":
		s["pass_games"] += 1
		save_data()
		return
	if mode == "online":
		s["online_wins" if human_won else "online_losses"] += 1
		save_data()
		return
	var key := "tiger_" if side == "tigers" else "goat_"
	if human_won:
		s["wins"] += 1
		s[key + "wins"] += 1
		s["streak"] += 1
		s["best_streak"] = maxi(s["best_streak"], s["streak"])
		var order := ["", "easy", "medium", "hard"]
		if order.find(level) > order.find(str(s["hardest"])):
			s["hardest"] = level
	else:
		s["losses"] += 1
		s[key + "losses"] += 1
		s["streak"] = 0
	save_data()


## Any game but Tiger & Goat. outcome: "win", "loss" or "draw" (the human's result;
## in pass and play only the game count changes). Also feeds the overall totals.
func record_result(game: String, mode: String, level: String, outcome: String) -> void:
	var g: Dictionary = data["games"][game]
	var s: Dictionary = data["stats"]
	g["played"] += 1
	s["played"] += 1
	if mode == "pass":
		g["pass_games"] += 1
		s["pass_games"] += 1
	elif mode == "online":  # Like Tiger & Goat: online results don't touch the computer streak.
		if outcome == "draw":
			g["draws"] += 1
		else:
			g["wins" if outcome == "win" else "losses"] += 1
			s["online_wins" if outcome == "win" else "online_losses"] += 1
	elif outcome == "draw":
		g["draws"] += 1
	elif outcome == "win":
		g["wins"] += 1
		s["wins"] += 1
		s["streak"] += 1
		s["best_streak"] = maxi(s["best_streak"], s["streak"])
		var order := ["", "easy", "medium", "hard"]
		if order.find(level) > order.find(str(s["hardest"])):
			s["hardest"] = level
	else:
		g["losses"] += 1
		s["losses"] += 1
		s["streak"] = 0
	save_data()


## Bagh-Chal: the overall record plus wins and losses by side (vs the computer).
func record_tiger_game(game: String, mode: String, side: String, level: String, human_won: bool) -> void:
	if mode == "computer":
		var g: Dictionary = data["games"][game]
		var key := ("tiger_" if side == "tigers" else "goat_") + ("wins" if human_won else "losses")
		g[key] += 1
	record_result(game, mode, level, "win" if human_won else "loss")


func game_stat(game: String, key: String) -> int:
	return int(data["games"].get(game, {}).get(key, 0))


## Who moves first in the next game of `game` (0 = you / player 1): it takes turns,
## because moving first is a real edge in these games (DISCUSSION.md section 29).
func take_first(game: String) -> int:
	var g: Dictionary = data["games"][game]
	var first := int(g["next_first"])
	g["next_first"] = 1 - first
	save_data()
	return first


# ---------- Seed-game puzzles ----------

func puzzles_solved(game: String) -> Array:
	return data["games"][game]["puzzles_solved"]


func solve_puzzle(game: String, id: int) -> void:
	var solved := puzzles_solved(game)
	if not solved.has(id):
		solved.append(id)
		save_data()


## The next puzzle to offer: the first unsolved one after `after_id` (in order, easiest
## first), wrapping round; once all are solved, any other one. {} if there are none.
func next_puzzle(game: String, after_id := 0) -> Dictionary:
	var all: Array = SowingPuzzleData.PUZZLES.get(game, [])
	if all.is_empty():
		return {}
	var solved := puzzles_solved(game)
	var start := 0
	for i in all.size():
		if int(all[i]["id"]) == after_id:
			start = i + 1
	for k in all.size():
		var p: Dictionary = all[(start + k) % all.size()]
		if not solved.has(int(p["id"])) and int(p["id"]) != after_id:
			return p
	return all[start % all.size()]  # All solved: simply the next one round.


func stat(key: String) -> int:
	return int(data["stats"].get(key, 0))


func win_rate() -> int:
	var decided := stat("wins") + stat("losses")
	return 0 if decided == 0 else roundi(100.0 * stat("wins") / decided)


func badges() -> Array:
	return [
		{"title": "First win", "icon": "trophy", "earned": stat("wins") > 0},
		{"title": "Trapper", "icon": "lock", "earned": stat("goat_wins") > 0},
		{"title": "Hunter", "icon": "paw", "earned": stat("tiger_wins") > 0},
		{"title": "Hard win", "icon": "star", "earned": str(data["stats"]["hardest"]) == "hard"},
	]


func reset_progress() -> void:
	var profile: Dictionary = data["profile"]
	var settings: Dictionary = data["settings"]
	data = defaults()
	data["profile"] = profile
	data["settings"] = settings
	save_data()
