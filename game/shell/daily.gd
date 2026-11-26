class_name Daily
extends RefCounted
## The daily puzzle: which puzzle today is, streaks, and the result text to share
## (BUILD_PLAN.md tasks 4.4-4.5). Works offline: puzzles are bundled and the day comes
## from the phone's own date, so everyone gets the same puzzle on the same date.
## Easier early in the week, harder towards the weekend.

const FIRST_DAY := "2026-11-01"  ## Daily puzzle #1. Reset to the launch date before release.
## Difficulty by weekday (0 Sunday ... 6 Saturday).
const WEEKDAY_DIFFICULTY := [5, 1, 2, 2, 3, 3, 4]


static func today() -> String:
	return Time.get_date_string_from_system()


static func day_number(date := "") -> int:
	if date == "":
		date = today()
	var days := (Time.get_unix_time_from_datetime_string(date) - Time.get_unix_time_from_datetime_string(FIRST_DAY)) / 86400
	return maxi(1, int(days) + 1)


static func date_of(day: int) -> String:
	var unix := Time.get_unix_time_from_datetime_string(FIRST_DAY) + (day - 1) * 86400
	return Time.get_date_string_from_unix_time(unix)


## Today's puzzle (or any day's), chosen by the day's difficulty.
static func puzzle_for(day: int) -> Dictionary:
	var all: Array = AadupuliPuzzleData.PUZZLES
	if all.is_empty():
		return {}
	var unix := Time.get_unix_time_from_datetime_string(date_of(day))
	var weekday: int = Time.get_datetime_dict_from_unix_time(unix)["weekday"]
	var want: int = WEEKDAY_DIFFICULTY[weekday]
	var bucket: Array = []
	for gap in 5:  # Nearest difficulty that has puzzles.
		bucket = all.filter(func(p: Dictionary) -> bool: return absi(int(p["difficulty"]) - want) == gap)
		if not bucket.is_empty():
			break
	return bucket[(day * 7919 + 13) % bucket.size()]


static func random_practice(exclude_id := -1) -> Dictionary:
	var all: Array = AadupuliPuzzleData.PUZZLES.filter(func(p: Dictionary) -> bool: return int(p["id"]) != exclude_id)
	return all[randi() % all.size()] if not all.is_empty() else {}


# ---------- Progress ----------

static func _data() -> Dictionary:
	return Store.data["daily"]


## Tries used on a day's puzzle, or 0 if not solved.
static func tries_on(day: int) -> int:
	return int(_data().get("solved", {}).get(str(day), 0))


## The current streak: 0 if neither today nor yesterday was solved.
static func streak() -> int:
	var last := str(_data().get("last_date", ""))
	if last == today() or last == date_of(day_number() - 1):
		return int(_data().get("streak", 0))
	return 0


static func best() -> int:
	return int(_data().get("best", 0))


static func solved_count() -> int:
	return (_data().get("solved", {}) as Dictionary).size()


## Records a solved daily puzzle. Counts towards the streak only if solved on its own day.
static func record(day: int, tries: int) -> void:
	var d := _data()
	if not d.has("solved"):
		d["solved"] = {}
	if tries_on(day) == 0:
		d["solved"][str(day)] = tries
	if day == day_number():
		var last := str(d.get("last_date", ""))
		if last != today():
			d["streak"] = (int(d.get("streak", 0)) + 1) if last == date_of(day - 1) else 1
			d["last_date"] = today()
			d["best"] = maxi(int(d.get("best", 0)), int(d["streak"]))
	Store.save_data()


static func share_text(day: int, tries: int) -> String:
	var how: String = TranslationServer.translate("Solved on the first try") if tries == 1 else TranslationServer.translate("Solved in %d tries") % tries
	return TranslationServer.translate("Tiger & Goat · Daily puzzle #%d\n%s · %d-day streak") % [day, how, streak()]
