class_name Ui
extends RefCounted
## The app's style kit: "Hill and meadow" colours (DISCUSSION.md section 24), Fredoka and
## Figtree fonts (D42), and small builders for labels, cards, buttons, icons and avatars,
## so every screen looks like one product. All visible text is English source text that
## Godot passes through translation automatically, ready for more languages later.

const MEADOW := Color("#E6EFDA")
const MEADOW_DEEP := Color("#DCE8CC")
const PANEL := Color("#F7F3E7")
const CARD := Color("#FFFCF4")
const WHITE := Color("#FFFFFF")
const INK := Color("#2F4128")
const MUTED := Color("#647A58")
const FAINT := Color("#8A9A80")
const LINE := Color("#D3DFC1")
const SOFT := Color("#DCE6CC")
const ACCENT := Color("#E26F2A")
const ACCENT_DOWN := Color("#C95E1F")
const ACCENT_TINT := Color("#FFF1E6")
const ACCENT_LINE := Color("#F1C9A6")
const WARM := Color("#FFF4E4")
const AVATAR_COLOURS: Array[Color] = [Color("#FBE3CF"), Color("#EEF2E6"), Color("#E3ECF7"), Color("#F6E3EC"), Color("#F3EBD2"), Color("#E5F0EC")]

const DISPLAY_FONT := "res://assets/fonts/Fredoka-Variable.ttf"
const BODY_FONT := "res://assets/fonts/Figtree-Variable.ttf"
const Piece := preload("res://games/aadupuli/board/piece.gd")

static var _fonts := {}
static var _icons := {}


# ---------- Fonts ----------

static func font(kind := "body") -> Font:
	if not _fonts.has(kind):
		var f := FontVariation.new()
		f.base_font = load(DISPLAY_FONT if kind == "display" else BODY_FONT)
		var weight: int = {"display": 600, "body": 500, "bold": 700}.get(kind, 500)
		f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_fonts[kind] = f
	return _fonts[kind]


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font("body")
	t.default_font_size = 34
	t.set_stylebox("normal", "Button", box(PANEL, LINE, 34))
	t.set_stylebox("focus", "Button", box(PANEL, LINE, 34))
	t.set_stylebox("hover", "Button", box(WHITE, Color(ACCENT, 0.6), 34))
	t.set_stylebox("pressed", "Button", box(Color("#EEE7D4"), ACCENT, 34))
	t.set_stylebox("disabled", "Button", box(SOFT, SOFT, 34))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", FAINT)
	t.set_font("font", "Button", font("display"))
	t.set_font_size("font_size", "Button", 36)
	var field := box(WHITE, LINE, 24, 3, 22)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", box(WHITE, ACCENT, 24, 3, 22))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_font_size("font_size", "LineEdit", 38)
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_constant("separation", "VBoxContainer", 22)
	t.set_constant("separation", "HBoxContainer", 20)
	return t


# ---------- Building blocks ----------

static func label(text: String, size := 32, color := INK, kind := "body") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func heading(text: String, size := 44) -> Label:
	return label(text, size, INK, "display")


static func muted(text: String, size := 28) -> Label:
	var l := label(text, size, MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func box(fill: Color, border := Color(0, 0, 0, 0), radius := 36, border_w := 3, pad := 26) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = border
	b.set_border_width_all(border_w if border.a > 0.0 else 0)
	b.set_corner_radius_all(radius)
	b.set_content_margin_all(pad)
	b.anti_aliasing = true
	return b


static func card(fill := PANEL, border := LINE, pad := 26, radius := 36) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(fill, border, radius, 3, pad))
	return p


static func hbox(sep := 20) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	return h


static func vbox(sep := 16) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	return v


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func button(text: String, action: Callable, primary := false, height := 112) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = height
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func() -> void:
		Sfx.tap()
		action.call())
	if primary:
		make_primary(b)
	return b


static func make_primary(b: Button) -> void:
	for s in ["normal", "focus"]:
		b.add_theme_stylebox_override(s, box(ACCENT, ACCENT, 34))
	for s in ["hover", "pressed"]:
		b.add_theme_stylebox_override(s, box(ACCENT_DOWN, ACCENT_DOWN, 34))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, WHITE)


## A small rounded tag such as "Soon" or "Your turn".
static func pill(text: String, fill := ACCENT, color := WHITE, size := 24) -> Label:
	var l := label(text, size, color, "display")
	var b := box(fill, Color(0, 0, 0, 0), 22, 0, 0)
	b.content_margin_left = 18
	b.content_margin_right = 18
	b.content_margin_top = 4
	b.content_margin_bottom = 6
	l.add_theme_stylebox_override("normal", b)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return l


static func soon_pill() -> Label:
	return pill("Soon", SOFT, MUTED, 22)


## Makes any control act like a button: calls action when tapped.
static func on_tap(c: Control, action: Callable) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			Sfx.tap()
			action.call())


# ---------- Icons (Tabler, MIT; assets/icons) ----------

static func icon_texture(name: String, size := 48, color := INK) -> Texture2D:
	var key := "%s/%d/%s" % [name, size, color.to_html(false)]
	if not _icons.has(key):
		var svg := FileAccess.get_file_as_string("res://assets/icons/%s.svg" % name)
		svg = svg.replace("currentColor", "#" + color.to_html(false))
		var img := Image.new()
		img.load_svg_from_string(svg, size / 24.0)
		_icons[key] = ImageTexture.create_from_image(img)
	return _icons[key]


static func icon(name: String, size := 48, color := INK) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon_texture(name, size, color)
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.custom_minimum_size = Vector2(size, size)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


## A round icon button, e.g. back or help in a top bar.
static func icon_button(name: String, action: Callable, size := 100) -> Button:
	var b := Button.new()
	b.icon = icon_texture(name, int(size * 0.5), INK)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(size, size)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for s in ["normal", "focus"]:
		b.add_theme_stylebox_override(s, box(PANEL, LINE, size / 2, 3, 0))
	b.add_theme_stylebox_override("hover", box(WHITE, LINE, size / 2, 3, 0))
	b.add_theme_stylebox_override("pressed", box(Color("#EEE7D4"), ACCENT, size / 2, 3, 0))
	b.pressed.connect(func() -> void:
		Sfx.tap()
		action.call())
	return b


# ---------- Avatars and tokens ----------

## A tiger or goat face on a round coloured background.
static func avatar(kind: String, colour := 0, size := 110.0) -> Control:
	var holder := PanelContainer.new()
	holder.custom_minimum_size = Vector2(size, size)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	holder.add_theme_stylebox_override("panel", box(AVATAR_COLOURS[colour % AVATAR_COLOURS.size()], Color(0, 0, 0, 0), int(size / 2.0), 0, 0))
	var piece := token(kind == "tiger", size * (0.34 if kind == "tiger" else 0.36))
	holder.add_child(piece)
	return holder


## A tiger or goat piece wrapped in a Control so it can sit in layouts.
static func token(is_tiger: bool, radius: float) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(radius, radius) * 2.6
	var p := Piece.new()
	p.is_tiger = is_tiger
	p.radius = radius
	p.breathe = false
	c.add_child(p)
	c.resized.connect(func() -> void: p.position = c.size / 2.0)
	return c


## Time-of-day greeting for the home screen.
static func greeting() -> String:
	var h: int = Time.get_datetime_dict_from_system()["hour"]
	if h < 5:
		return "Up late"
	if h < 12:
		return "Good morning"
	if h < 17:
		return "Good afternoon"
	return "Good evening"
