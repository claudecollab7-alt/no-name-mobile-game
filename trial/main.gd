extends Control
## Trial screen, redesigned for a global audience (DISCUSSION.md sections 22–23).
## Plato-like layout: a player panel for each side with its goal, the board between them,
## a one-screen "How to play" card, and very little text to read.
## The bottom line keeps the trial measurements: platform, start-up, fps, look-ahead.

const R := preload("res://rules.gd")
const Search := preload("res://search.gd")
const BoardView := preload("res://board_view.gd")
const Piece := preload("res://piece.gd")

const DISPLAY_FONT := "res://assets/fonts/Fredoka-Variable.ttf"
const BODY_FONT := "res://assets/fonts/Figtree-Variable.ttf"

const CREAM := Color("#FAF6EE")
const WHITE := Color("#FFFFFF")
const INK := Color("#2B2118")
const MUTED := Color("#6E6254")
const LINE := Color("#EADFCF")
const COPPER := Color("#C25A22")
const IVORY := Color("#F1E6CF")
const IVORY_RIM := Color("#8B6A3E")

var display_font: FontVariation
var body_font: FontVariation
var board: BoardView
var board_area: Control
var tiger_chip: PanelContainer
var goat_chip: PanelContainer
var tiger_turn: Label
var goat_turn: Label
var capture_dots: CaptureDots
var in_hand_label: Label
var in_hand_caption: Label
var hint_label: Label
var dev_label: Label
var sounds := {}
var startup_ms := 0
var _stats_timer := 0.0
var _think_text := ""


## Five slots showing how many goats the tigers have taken.
class CaptureDots extends Control:
	var count := 0:
		set(value):
			count = value
			queue_redraw()

	func _draw() -> void:
		var n := 5
		var s := size.y * 0.62
		var gap := s * 0.32
		var x := size.x - (n * s + (n - 1) * gap)
		for i in n:
			var box := StyleBoxFlat.new()
			box.set_corner_radius_all(int(s * 0.3))
			box.anti_aliasing = true
			if i < count:
				box.bg_color = Color("#F1E6CF")
				box.border_color = Color("#8B6A3E")
				box.set_border_width_all(3)
			else:
				box.bg_color = Color(0, 0, 0, 0)
				box.border_color = Color("#D9CBB6")
				box.set_border_width_all(3)
			draw_style_box(box, Rect2(Vector2(x + i * (s + gap), (size.y - s) / 2.0), Vector2(s, s)))


func _ready() -> void:
	startup_ms = Time.get_ticks_msec()
	display_font = _font(DISPLAY_FONT, 600)
	body_font = _font(BODY_FONT, 500)
	_apply_theme()
	_build_ui()
	_load_sounds()
	board.new_game()
	_show_rules()


# ---------- Layout ----------

func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = CREAM
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	margin.add_theme_constant_override("margin_top", 64)
	margin.add_theme_constant_override("margin_bottom", 40)
	add_child(margin)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 22)
	margin.add_child(col)

	# Top bar: wordmark and a round help button.
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var wordmark := _label("Tiger & Goat", 66, INK, display_font)
	wordmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	wordmark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(wordmark)
	var help := _button("?", _show_rules)
	help.custom_minimum_size = Vector2(104, 104)
	help.size_flags_horizontal = Control.SIZE_SHRINK_END
	help.add_theme_font_override("font", display_font)
	help.add_theme_font_size_override("font_size", 48)
	top.add_child(help)

	# Tigers' panel above the board.
	var tiger_parts := _player_chip(true, "Tigers", "Capture 5 goats to win")
	tiger_chip = tiger_parts[0]
	tiger_turn = tiger_parts[1]
	var tiger_right := VBoxContainer.new()
	tiger_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tiger_right.alignment = BoxContainer.ALIGNMENT_CENTER
	capture_dots = CaptureDots.new()
	capture_dots.custom_minimum_size = Vector2(300, 56)
	tiger_right.add_child(capture_dots)
	var caught := _label("Captured", 26, MUTED, body_font)
	caught.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tiger_right.add_child(caught)
	tiger_parts[2].add_child(tiger_right)
	col.add_child(tiger_chip)

	board_area = Control.new()
	board_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_area.custom_minimum_size.y = 560
	col.add_child(board_area)
	board = BoardView.new()
	board_area.add_child(board)
	board_area.resized.connect(func() -> void: board.layout(board_area.size))
	board.changed.connect(_update_panels)
	board.played.connect(_on_played)

	# Goats' panel below the board.
	var goat_parts := _player_chip(false, "Goats", "Trap all 3 tigers to win")
	goat_chip = goat_parts[0]
	goat_turn = goat_parts[1]
	var goat_right := VBoxContainer.new()
	goat_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goat_right.alignment = BoxContainer.ALIGNMENT_CENTER
	in_hand_label = _label("15", 52, INK, display_font)
	in_hand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	goat_right.add_child(in_hand_label)
	in_hand_caption = _label("to place", 26, MUTED, body_font)
	in_hand_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	goat_right.add_child(in_hand_caption)
	goat_parts[2].add_child(goat_right)
	col.add_child(goat_chip)

	hint_label = _label("", 32, MUTED, body_font)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size.y = 84
	col.add_child(hint_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	col.add_child(row)
	row.add_child(_button("New game", func() -> void: board.new_game()))
	row.add_child(_button("How to play", _show_rules))

	# Trial measurements, kept small and out of the way.
	var dev := HBoxContainer.new()
	dev.add_theme_constant_override("separation", 12)
	col.add_child(dev)
	dev_label = _label("", 24, MUTED, body_font)
	dev_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	dev_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dev_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dev.add_child(dev_label)
	var think := _button("Think 1 s", _think_test)
	think.custom_minimum_size = Vector2(200, 72)
	think.size_flags_horizontal = Control.SIZE_SHRINK_END
	think.add_theme_font_size_override("font_size", 24)
	dev.add_child(think)


## Returns [panel, turn pill, content row] so callers can add the right-hand side.
func _player_chip(is_tiger: bool, title: String, goal: String) -> Array:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _chip_box(false))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 24)
	panel.add_child(row)
	row.add_child(_token_icon(is_tiger, 96.0))
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_theme_constant_override("separation", 16)
	text.add_child(name_row)
	var name_label := _label(title, 42, INK, display_font)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_row.add_child(name_label)
	var pill := _label("To play", 24, WHITE, display_font)
	var pill_box := StyleBoxFlat.new()
	pill_box.bg_color = COPPER
	pill_box.set_corner_radius_all(22)
	pill_box.content_margin_left = 18
	pill_box.content_margin_right = 18
	pill_box.content_margin_top = 4
	pill_box.content_margin_bottom = 6
	pill.add_theme_stylebox_override("normal", pill_box)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(pill)
	var goal_label := _label(goal, 28, MUTED, body_font)
	goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_child(goal_label)
	return [panel, pill, row]


func _token_icon(is_tiger: bool, side: float) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2(side, side)
	var piece := Piece.new()
	piece.is_tiger = is_tiger
	piece.radius = side * (0.4 if is_tiger else 0.46)
	holder.add_child(piece)
	holder.resized.connect(func() -> void: piece.position = holder.size / 2.0)
	return holder


func _chip_box(active: bool) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = WHITE
	b.border_color = COPPER if active else LINE
	b.set_border_width_all(4 if active else 3)
	b.set_corner_radius_all(36)
	b.content_margin_left = 26
	b.content_margin_right = 30
	b.content_margin_top = 20
	b.content_margin_bottom = 20
	b.anti_aliasing = true
	return b


func _label(text: String, size: int, color: Color, font: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = 108
	b.pressed.connect(action)
	return b


func _font(path: String, weight: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(path)
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return f


func _apply_theme() -> void:
	var t := Theme.new()
	t.default_font = body_font
	t.default_font_size = 32
	var normal := _button_box(WHITE, LINE)
	var hover := _button_box(Color("#FFF8EE"), Color(COPPER, 0.6))
	var pressed := _button_box(Color("#F6E7D6"), COPPER)
	for state_name in ["normal", "focus"]:
		t.set_stylebox(state_name, "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(color_name, "Button", INK)
	t.set_font("font", "Button", display_font)
	t.set_font_size("font_size", "Button", 34)
	theme = t


func _button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = border
	b.set_border_width_all(3)
	b.set_corner_radius_all(32)
	b.anti_aliasing = true
	return b


# ---------- How to play ----------

func _show_rules() -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 100  # Pieces use z_index 1–2, so the card must sit above them.
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.11, 0.07, 0.04, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var card := PanelContainer.new()
	var card_box := StyleBoxFlat.new()
	card_box.bg_color = WHITE
	card_box.set_corner_radius_all(44)
	for side in ["left", "right", "top", "bottom"]:
		card_box.set("content_margin_" + side, 52)
	card.add_theme_stylebox_override("panel", card_box)
	card.custom_minimum_size.x = 940
	center.add_child(card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 30)
	card.add_child(col)
	var title := _label("How to play", 58, INK, display_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(title)
	var steps := [
		[false, "Goats go first", "Place one goat per turn on any empty point. Goats can't move until all 15 are on the board."],
		[true, "Tigers hunt", "Move one step along a line, or jump over a goat to the empty point behind it to capture it."],
		[true, "Tigers win", "by capturing 5 goats."],
		[false, "Goats win", "by trapping all 3 tigers so none can move."],
	]
	for step: Array in steps:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 28)
		col.add_child(row)
		row.add_child(_token_icon(step[0], 84.0))
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_theme_constant_override("separation", 2)
		row.add_child(words)
		var heading := _label(step[1], 38, INK, display_font)
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		words.add_child(heading)
		var body := _label(step[2], 30, MUTED, body_font)
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size.x = 700
		words.add_child(body)
	var ok := _button("Got it", overlay.queue_free)
	var ok_box := _button_box(COPPER, COPPER)
	ok.add_theme_stylebox_override("normal", ok_box)
	ok.add_theme_stylebox_override("hover", _button_box(Color("#B04F1C"), Color("#B04F1C")))
	ok.add_theme_stylebox_override("pressed", _button_box(Color("#9C4618"), Color("#9C4618")))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		ok.add_theme_color_override(color_name, WHITE)
	col.add_child(ok)


# ---------- Game state on screen ----------

func _update_panels() -> void:
	var s := board.state
	var res := R.result(s)
	var over := res != R.ONGOING
	tiger_chip.add_theme_stylebox_override("panel", _chip_box(not over and s.turn == R.TIGER or res == R.TIGERS_WIN))
	goat_chip.add_theme_stylebox_override("panel", _chip_box(not over and s.turn == R.GOAT or res == R.GOATS_WIN))
	tiger_turn.visible = (not over and s.turn == R.TIGER) or res == R.TIGERS_WIN
	goat_turn.visible = (not over and s.turn == R.GOAT) or res == R.GOATS_WIN
	tiger_turn.text = "Winner" if res == R.TIGERS_WIN else "To play"
	goat_turn.text = "Winner" if res == R.GOATS_WIN else "To play"
	capture_dots.count = s.captured
	if s.in_hand > 0:
		in_hand_label.text = str(s.in_hand)
		in_hand_caption.text = "to place"
	else:
		in_hand_label.text = str(R.GOAT_TOTAL - s.captured)
		in_hand_caption.text = "on the board"
	if res == R.TIGERS_WIN:
		hint_label.text = "The tigers caught 5 goats."
	elif res == R.GOATS_WIN:
		hint_label.text = "The tigers are trapped."
	elif s.turn == R.GOAT and s.in_hand > 0:
		hint_label.text = "Tap a glowing point to place a goat"
	elif s.turn == R.GOAT:
		hint_label.text = "Tap a goat, then where it should go"
	else:
		hint_label.text = "Tap a tiger, then where it should go. Jump a goat to capture it."


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


# ---------- Trial measurements ----------

func _think_test() -> void:
	var search := Search.new()
	search.think(board.state, 1000)
	_think_text = "  ·  look-ahead %d deep (%s/s)" % [
		search.depth_reached, _thousands(int(search.nodes * 1000.0 / maxf(1.0, search.elapsed_ms)))]
	_stats_timer = 1.0


func _process(delta: float) -> void:
	_stats_timer += delta
	if _stats_timer < 0.5:
		return
	_stats_timer = 0.0
	dev_label.text = "Trial  ·  %s  ·  start %.1f s  ·  %d fps%s" % [
		OS.get_name(), startup_ms / 1000.0, Engine.get_frames_per_second(), _think_text]


func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
