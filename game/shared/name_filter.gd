class_name NameFilter
extends RefCounted
## Checks player names shown to other players online (D50: everyone sees chosen names,
## filtered). Allows letters, digits and single spaces, 2-16 characters, and rejects
## names containing blocked words, also when disguised with digits or symbols.
## Filters miss things: extend BLOCKED as problems appear.

const MAX_LEN := 16
const FALLBACK := "Player"

## Lower-case, letters only. Matched as substrings after normalising, so keep each
## entry long enough not to catch ordinary names.
## Deliberately leaves out short words that hide inside ordinary names
## (Peacock, Hancock, Grapes, Essex, Dickson, Spicy, Randi).
const BLOCKED := [
	"fuck", "shit", "bitch", "cunt", "pussy", "whore", "slut", "bastard",
	"asshole", "arsehole", "wanker", "twat", "porn", "nazi", "hitler", "rapist",
	"nigger", "nigga", "faggot", "retard", "kike", "chink",
	"chutiya", "madarchod", "bhenchod", "behenchod", "gandu", "bsdk",
]

const LEET := {"0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "8": "b", "@": "a", "$": "s", "!": "i", "|": "i"}


## Returns a name safe to show, or FALLBACK when the name is empty or not allowed.
static func clean(raw: String) -> String:
	var name := _tidy(raw)
	if name.length() < 2 or not is_allowed(name):
		return FALLBACK
	return name


static func is_allowed(name: String) -> bool:
	var squashed := ""
	for ch in name.to_lower():
		if LEET.has(ch):
			squashed += LEET[ch]
		elif ch >= "a" and ch <= "z":
			squashed += ch
	for word: String in BLOCKED:
		if squashed.contains(word):
			return false
	return true


## Keeps letters (any script), digits and single spaces; trims to MAX_LEN.
static func _tidy(raw: String) -> String:
	var out := ""
	var last_space := true
	for ch in raw.strip_edges():
		var code := ch.unicode_at(0)
		var is_space := ch == " "
		var ok := is_space or (ch >= "0" and ch <= "9") or ch.to_lower() != ch.to_upper() or code > 0x2E80
		if not ok or (is_space and last_space):
			continue
		out += ch
		last_space = is_space
	return out.strip_edges().left(MAX_LEN).strip_edges()
