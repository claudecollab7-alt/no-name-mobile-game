extends Control
## Trial screen: light, calm app around the brass-and-wood board (DISCUSSION.md section 22).
## Shows the three trial measurements on screen so they can be read off a cheap phone:
## start-up time, frames per second, and look-ahead depth in one second.

const R := preload("res://rules.gd")
const Search := preload("res://search.gd")
const BoardView := preload("res://board_view.gd")

const FONTS: Array = [
	["Hind Madurai", "res://assets/fonts/HindMadurai-Regular.ttf"],
	["Catamaran", "res://assets/fonts/Catamaran-Variable.ttf"],
	["Mukta Malar", "res://assets/fonts/MuktaMalar-Regular.ttf"],
]
const CREAM := Color("#FAF6EE")
const WHITE := Color("#FFFFFF")
const INK := Color("#2B2118")
const MUTED := Color("#6E6254")
const COPPER := Color("#C25A22")

var board: BoardView
var board_area: Control
var status_label: Label
var info_label: Label
var stats_label: Label
var font_button: Button
var font_index := 0
var sounds := {}
var startup_ms := 0
var _stats_timer := 0.0


func _ready() -> void:
	startup_ms = Time.get_ticks_msec()
	_apply_theme()
	_build_ui()
	_load_sounds()
	board.new_game()
	info_label.text = "Tap an empty point to place a goat. Then tap a piece and a glowing point to move it."


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = CREAM
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Layout nodes must let taps fall through to the board, which reads them in _unhandled_input.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 44)
	margin.add_theme_constant_override("margin_top", 72)
	margin.add_theme_constant_override("margin_bottom", 56)
	add_child(margin)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)

	col.add_child(_label("Tigers & Goats", 68, INK))
	col.add_child(_label("ஆடு புலி ஆட்டம்", 52, COPPER))
	col.add_child(_label("ஸ்ரீ  ·  3 புலிகள்  ·  15 ஆடுகள்", 34, MUTED))

	status_label = _label("", 38, INK)
	status_label.custom_minimum_size.y = 64
	col.add_child(status_label)

	board_area = Control.new()
	board_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_area.custom_minimum_size.y = 520
	col.add_child(board_area)
	board = BoardView.new()
	board_area.add_child(board)
	board_area.resized.connect(func() -> void: board.layout(board_area.size))
	board.changed.connect(_update_status)
	board.played.connect(_on_played)

	info_label = _label("", 30, MUTED)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(info_label)

	stats_label = _label("", 26, MUTED)
	col.add_child(stats_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	row.add_child(_button("New game", func() -> void: board.new_game()))
	font_button = _button("Font: " + FONTS[0][0], _next_font)
	row.add_child(font_button)
	row.add_child(_button("Think 1 s", _think_test))


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 104
	b.pressed.connect(action)
	return b


func _apply_theme() -> void:
	var t := Theme.new()
	t.default_font = load(FONTS[font_index][1])
	t.default_font_size = 34
	var normal := _button_box(WHITE, Color(COPPER, 0.55))
	var hover := _button_box(Color("#FFF8EE"), COPPER)
	var pressed := _button_box(Color("#F6E7D6"), COPPER)
	for state_name in ["normal", "focus"]:
		t.set_stylebox(state_name, "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(color_name, "Button", INK)
	t.set_font_size("font_size", "Button", 32)
	theme = t


func _button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = border
	b.set_border_width_all(3)
	b.set_corner_radius_all(28)
	b.anti_aliasing = true
	return b


func _load_sounds() -> void:
	for kind in ["place", "move", "capture"]:
		var player := AudioStreamPlayer.new()
		player.stream = load("res://assets/sounds/%s.wav" % kind)
		add_child(player)
		sounds[kind] = player


func _on_played(kind: String) -> void:
	(sounds[kind] as AudioStreamPlayer).play()
	if kind == "capture" and OS.has_feature("mobile"):
		Input.vibrate_handheld(70)


func _update_status() -> void:
	var s := board.state
	var res := R.result(s)
	if res == R.TIGERS_WIN:
		status_label.text = "Tigers win: %d goats captured" % s.captured
	elif res == R.GOATS_WIN:
		status_label.text = "Goats win: the tigers are trapped"
	elif s.turn == R.GOAT:
		var what := "place a goat (%d in hand)" % s.in_hand if s.in_hand > 0 else "move a goat"
		status_label.text = "Goats to play: %s  ·  captured %d/%d" % [what, s.captured, R.CAPTURE_TARGET]
	else:
		status_label.text = "Tigers to play  ·  captured %d/%d" % [s.captured, R.CAPTURE_TARGET]


func _next_font() -> void:
	font_index = (font_index + 1) % FONTS.size()
	_apply_theme()
	font_button.text = "Font: " + FONTS[font_index][0]


func _think_test() -> void:
	var search := Search.new()
	search.think(board.state, 1000)
	var rate := search.nodes * 1000.0 / maxf(1.0, search.elapsed_ms)
	info_label.text = "Look-ahead: %d moves deep in %.1f s  ·  %s positions (%s per second)" % [
		search.depth_reached, search.elapsed_ms / 1000.0, _thousands(search.nodes), _thousands(int(rate))]


func _process(delta: float) -> void:
	_stats_timer += delta
	if _stats_timer < 0.5:
		return
	_stats_timer = 0.0
	stats_label.text = "%s  ·  started in %.1f s  ·  %d fps" % [
		OS.get_name(), startup_ms / 1000.0, Engine.get_frames_per_second()]


func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
