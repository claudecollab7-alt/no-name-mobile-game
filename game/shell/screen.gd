class_name AppScreen
extends Control
## Base for every screen. The app sets `app`; screens build their layout in build().

var app: Node  ## shell/app.gd


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Called each time the screen becomes visible, to refresh names and numbers.
func on_show() -> void:
	pass


## Standard page: safe margins and a vertical scroll for content taller than the phone.
func page(scroll := true, top := 72, bottom := 40) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", bottom)
	add_child(margin)
	var col := Ui.vbox(24)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if scroll:
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.mouse_filter = Control.MOUSE_FILTER_PASS
		margin.add_child(sc)
		sc.add_child(col)
	else:
		margin.add_child(col)
	return col


## Top bar for pushed screens: back button, title, optional right-hand button.
func top_bar(title: String, right: Control = null) -> HBoxContainer:
	var bar := Ui.hbox(24)
	bar.add_child(Ui.icon_button("arrow-left", func() -> void: app.pop()))
	var t := Ui.heading(title, 48)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(t)
	if right != null:
		bar.add_child(right)
	return bar


func section(title: String) -> Label:
	var l := Ui.label(title.to_upper(), 24, Ui.MUTED, "bold")
	return l
