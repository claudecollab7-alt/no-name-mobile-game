class_name UiSwitch
extends Control
## An on/off switch in the meadow style.

signal toggled(on: bool)

var on := false:
	set(value):
		on = value
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(108, 60)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _draw() -> void:
	var r := size.y / 2.0
	var track := Ui.box(Ui.ACCENT if on else Color("#C8D6B4"), Color(0, 0, 0, 0), int(r), 0, 0)
	draw_style_box(track, Rect2(Vector2.ZERO, size))
	var knob_x := size.x - r if on else r
	draw_circle(Vector2(knob_x, r), r - 6.0, Ui.WHITE, true, -1.0, true)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		on = not on
		Sfx.tap()
		toggled.emit(on)
		accept_event()
