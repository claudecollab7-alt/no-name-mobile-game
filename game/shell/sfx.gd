extends Node
## Sounds and vibration, respecting the player's settings.

const STREAMS := {
	"place": preload("res://assets/sounds/place.wav"),
	"move": preload("res://assets/sounds/move.wav"),
	"capture": preload("res://assets/sounds/capture.wav"),
	"win": preload("res://assets/sounds/win.wav"),
	"lose": preload("res://assets/sounds/lose.wav"),
	"select": preload("res://assets/sounds/select.wav"),
	"solved": preload("res://assets/sounds/solved.wav"),
	"nope": preload("res://assets/sounds/nope.wav"),
}

var _players := {}


func _ready() -> void:
	for kind: String in STREAMS:
		var p := AudioStreamPlayer.new()
		p.stream = STREAMS[kind]
		add_child(p)
		_players[kind] = p
	var tap_player := AudioStreamPlayer.new()
	tap_player.stream = STREAMS["place"]
	tap_player.volume_db = -14.0
	add_child(tap_player)
	_players["tap"] = tap_player


func play(kind: String) -> void:
	if Store.setting("sound") and _players.has(kind):
		(_players[kind] as AudioStreamPlayer).play()
	if kind == "capture":
		vibrate(70)


## A very soft click for buttons, reusing the placement sound quietly.
func tap() -> void:
	if Store.setting("sound"):
		(_players["tap"] as AudioStreamPlayer).play()


func vibrate(ms: int) -> void:
	if Store.setting("vibration") and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
