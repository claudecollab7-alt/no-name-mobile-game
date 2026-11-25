extends Node2D
## A tiger or goat token drawn in code, "hill and meadow" style (DISCUSSION.md section 24).
## Tigers: round orange faces with ears, stripes and a white muzzle; they breathe gently.
## Goats: fluffy white fleece with a dark face. Shape and colour both differ (D37).

const TIGER := Color("#E8742A")
const TIGER_DARK := Color("#3A2416")
const MUZZLE := Color("#FFF4E4")
const FLEECE := Color("#FFFFFF")
const FLEECE_EDGE := Color("#D6CBB7")
const GOAT_FACE := Color("#5A4C40")
const GLOW := Color("#FFFFFF")
const SHADOW := Color(0.23, 0.16, 0.09, 0.18)

var is_tiger := false
var breathe := true  ## Tigers on the board breathe; set false for static icons if wanted.
var radius := 30.0:
	set(value):
		radius = value
		queue_redraw()
var selected := false:
	set(value):
		selected = value
		queue_redraw()
var _time := randf() * TAU


func _process(delta: float) -> void:
	if is_tiger and breathe:
		_time += delta
		var s := 1.0 + 0.035 * sin(_time * 1.9)
		scale = Vector2(s, s)


func _draw() -> void:
	var r := radius
	if selected:
		draw_circle(Vector2.ZERO, r * 1.5, Color(GLOW, 0.5), true, -1.0, true)
		draw_arc(Vector2.ZERO, r * 1.5, 0.0, TAU, 48, GLOW, r * 0.12, true)
	_ellipse(Vector2(0, r * 0.92), Vector2(r * 0.8, r * 0.22), SHADOW)
	if is_tiger:
		_draw_tiger(r)
	else:
		_draw_goat(r)


func _draw_tiger(r: float) -> void:
	for side in [-1.0, 1.0]:
		draw_circle(Vector2(side * r * 0.66, -r * 0.74), r * 0.32, TIGER, true, -1.0, true)
		draw_circle(Vector2(side * r * 0.66, -r * 0.74), r * 0.15, MUZZLE, true, -1.0, true)
	draw_circle(Vector2.ZERO, r, TIGER, true, -1.0, true)
	var w := r * 0.14
	draw_line(Vector2(0, -r * 0.78), Vector2(0, -r * 0.3), TIGER_DARK, w, true)
	draw_arc(Vector2(-r * 1.05, 0), r * 0.62, -0.75, 0.75, 16, TIGER_DARK, w, true)
	draw_arc(Vector2(r * 1.05, 0), r * 0.62, PI - 0.75, PI + 0.75, 16, TIGER_DARK, w, true)
	_ellipse(Vector2(0, r * 0.5), Vector2(r * 0.46, r * 0.33), MUZZLE)
	draw_circle(Vector2(-r * 0.3, -r * 0.02), r * 0.11, TIGER_DARK, true, -1.0, true)
	draw_circle(Vector2(r * 0.3, -r * 0.02), r * 0.11, TIGER_DARK, true, -1.0, true)
	draw_circle(Vector2(0, r * 0.36), r * 0.1, TIGER_DARK, true, -1.0, true)


func _draw_goat(r: float) -> void:
	# Fleece: a ring of puffs around a body, edge colour first so the outline looks soft.
	var puffs := 9
	for pass_index in 2:
		var grow := r * 0.09 if pass_index == 0 else 0.0
		var col := FLEECE_EDGE if pass_index == 0 else FLEECE
		draw_circle(Vector2.ZERO, r * 0.8 + grow, col, true, -1.0, true)
		for k in puffs:
			var a := TAU * k / puffs
			draw_circle(Vector2(cos(a), sin(a)) * r * 0.72, r * 0.34 + grow, col, true, -1.0, true)
	# Ears, face and eyes.
	_ellipse(Vector2(-r * 0.86, -r * 0.25), Vector2(r * 0.36, r * 0.17), GOAT_FACE)
	_ellipse(Vector2(r * 0.86, -r * 0.25), Vector2(r * 0.36, r * 0.17), GOAT_FACE)
	_ellipse(Vector2(0, r * 0.08), Vector2(r * 0.48, r * 0.6), GOAT_FACE)
	draw_circle(Vector2(-r * 0.19, -r * 0.05), r * 0.1, FLEECE, true, -1.0, true)
	draw_circle(Vector2(r * 0.19, -r * 0.05), r * 0.1, FLEECE, true, -1.0, true)


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)
