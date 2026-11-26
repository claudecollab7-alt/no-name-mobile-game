extends Control
## The app frame (DISCUSSION.md section 25): four tabs (Play, Daily, Friends, Profile)
## with screens pushed on top for the game page, play, result and settings.
## Android's back button closes a card, then a pushed screen, then returns to Play.

const TABS := [
	["Play", "device-gamepad-2", "res://shell/screens/home_screen.gd"],
	["Daily", "calendar-star", "res://shell/screens/daily_screen.gd"],
	["Friends", "users", "res://shell/screens/friends_screen.gd"],
	["Profile", "user-circle", "res://shell/screens/profile_screen.gd"],
]
const TAB_HEIGHT := 176

var _tab_screens: Array[AppScreen] = []
var _tab_buttons: Array[Control] = []
var _stack: Array[AppScreen] = []
var _root: Control
var _tab_bar: PanelContainer
var _current_tab := 0


func _ready() -> void:
	theme = Ui.make_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Ui.MEADOW
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.offset_bottom = -TAB_HEIGHT
	add_child(_root)
	for t: Array in TABS:
		var s: AppScreen = load(t[2]).new()
		s.app = self
		s.visible = false
		_root.add_child(s)
		_tab_screens.append(s)
	_build_tab_bar()
	show_tab(0)
	if not Store.data["seen_rules"]:
		Modal.how_to_play(self)


func _build_tab_bar() -> void:
	_tab_bar = PanelContainer.new()
	var b := Ui.box(Ui.PANEL, Color(0, 0, 0, 0), 0, 0, 0)
	b.border_color = Ui.LINE
	b.border_width_top = 3
	b.content_margin_top = 14
	b.content_margin_bottom = 30
	_tab_bar.add_theme_stylebox_override("panel", b)
	_tab_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_tab_bar.offset_top = -TAB_HEIGHT
	add_child(_tab_bar)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_bar.add_child(row)
	for i in TABS.size():
		var cell := Ui.vbox(4)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(cell)
		Ui.on_tap(cell, show_tab.bind(i))
		_tab_buttons.append(cell)


func _style_tabs() -> void:
	for i in _tab_buttons.size():
		var cell := _tab_buttons[i]
		for c in cell.get_children():
			c.queue_free()
		var col := Ui.ACCENT if i == _current_tab else Ui.FAINT
		var ic := Ui.icon(TABS[i][1], 60, col)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(ic)
		var l := Ui.label(TABS[i][0], 24, col, "bold")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(l)


func show_tab(i: int) -> void:
	while not _stack.is_empty():
		_stack.pop_back().queue_free()
	_current_tab = i
	for k in _tab_screens.size():
		_tab_screens[k].visible = k == i
	_tab_bar.visible = true
	_root.offset_bottom = -TAB_HEIGHT
	_style_tabs()
	_tab_screens[i].on_show()


## Opens a full-screen page over the tabs (game page, play, result, settings).
func push(screen: AppScreen) -> void:
	screen.app = self
	if not screen.is_overlay:
		for s in _stack:
			s.visible = false
	_tab_screens[_current_tab].visible = false
	_tab_bar.visible = false
	_root.offset_bottom = 0
	_root.add_child(screen)
	_stack.append(screen)
	screen.on_show()


## Swaps the top page for another (play screen to result screen).
func replace(screen: AppScreen) -> void:
	if not _stack.is_empty():
		_stack.pop_back().queue_free()
	push(screen)


func pop() -> void:
	if _stack.is_empty():
		return
	_stack.pop_back().queue_free()
	if _stack.is_empty():
		show_tab(_current_tab)
	else:
		_stack[-1].visible = true
		_stack[-1].on_show()


func home() -> void:
	show_tab(0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if Modal.close_top(self):
			return
		if not _stack.is_empty():
			pop()
		elif _current_tab != 0:
			show_tab(0)
		else:
			get_tree().quit()
