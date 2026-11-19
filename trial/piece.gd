extends Node2D
## A tiger or goat token drawn in code (brass-and-wood palette, DISCUSSION.md section 22).
## Tigers: round copper tokens with stripes. Goats: ivory rounded squares with a brown rim.

const COPPER := Color("#D4682A")
const COPPER_DARK := Color("#4A1D08")
const IVORY := Color("#F1E6CF")
const IVORY_RIM := Color("#8B6A3E")
const GLOW := Color("#FFF3D6")
const SHADOW := Color(0, 0, 0, 0.35)

var is_tiger := false
var radius := 30.0:
	set(value):
		radius = value
		queue_redraw()
var selected := false:
	set(value):
		selected = value
		queue_redraw()


func _draw() -> void:
	var r := radius
	if selected:
		draw_circle(Vector2.ZERO, r * 1.45, Color(GLOW, 0.55), true, -1.0, true)
		draw_arc(Vector2.ZERO, r * 1.45, 0.0, TAU, 48, GLOW, r * 0.12, true)
	if is_tiger:
		_draw_tiger(r)
	else:
		_draw_goat(r * 0.8)


func _draw_tiger(r: float) -> void:
	draw_circle(Vector2(0, r * 0.14), r, SHADOW, true, -1.0, true)
	draw_circle(Vector2.ZERO, r, COPPER, true, -1.0, true)
	draw_arc(Vector2.ZERO, r - r * 0.06, 0.0, TAU, 48, COPPER_DARK, r * 0.12, true)
	var w := r * 0.13
	# Three stripes: a short one down the forehead and one curving in from each side.
	draw_line(Vector2(0, -r * 0.72), Vector2(0, -r * 0.18), COPPER_DARK, w, true)
	draw_arc(Vector2(-r * 1.05, 0), r * 0.62, -0.75, 0.75, 16, COPPER_DARK, w, true)
	draw_arc(Vector2(r * 1.05, 0), r * 0.62, PI - 0.75, PI + 0.75, 16, COPPER_DARK, w, true)
	# Eyes, so it reads as a face at a glance.
	draw_circle(Vector2(-r * 0.3, r * 0.08), r * 0.1, COPPER_DARK, true, -1.0, true)
	draw_circle(Vector2(r * 0.3, r * 0.08), r * 0.1, COPPER_DARK, true, -1.0, true)


func _draw_goat(h: float) -> void:
	var rect := Rect2(Vector2(-h, -h), Vector2(h * 2.0, h * 2.0))
	draw_style_box(_box(SHADOW, SHADOW, 0.0, h), Rect2(rect.position + Vector2(0, h * 0.18), rect.size))
	draw_style_box(_box(IVORY, IVORY_RIM, h * 0.14, h), rect)
	draw_arc(Vector2.ZERO, h * 0.42, 0.0, TAU, 32, Color(IVORY_RIM, 0.7), h * 0.08, true)


func _box(fill: Color, border: Color, border_width: float, h: float) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = border
	b.set_border_width_all(int(round(border_width)))
	b.set_corner_radius_all(int(round(h * 0.45)))
	b.anti_aliasing = true
	return b
