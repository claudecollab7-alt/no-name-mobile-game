class_name OnlineChat
extends RefCounted
## The only things players can say to each other online (D29): six emotes and eight
## phrases, sent as numbers. No free typing, so nothing needs moderating.
## Keep the order: ids are shared with the server (OnlineLobby.CHAT_IDS).

const ITEMS := [
	["emote", "thumb-up"], ["emote", "mood-happy"], ["emote", "mood-wink"],
	["emote", "mood-surprised"], ["emote", "mood-sad"], ["emote", "heart"],
	["text", "Hello!"], ["text", "Good move!"], ["text", "Nice try"], ["text", "Oops!"],
	["text", "Thinking…"], ["text", "Well played"], ["text", "Good game"], ["text", "Rematch?"],
]


static func is_emote(id: int) -> bool:
	return id >= 0 and id < ITEMS.size() and ITEMS[id][0] == "emote"


static func value(id: int) -> String:
	return ITEMS[id][1] if id >= 0 and id < ITEMS.size() else ""


## The chat card: faces, phrases and a switch to hide the opponent's messages.
## `on_pick` is called with the chosen id after the card closes.
static func open_picker(app: Node, opponent_name: String, on_pick: Callable) -> void:
	var faces := Ui.hbox(14)
	var phrases := GridContainer.new()
	phrases.columns = 2
	phrases.add_theme_constant_override("h_separation", 14)
	phrases.add_theme_constant_override("v_separation", 14)
	for id in ITEMS.size():
		var item := PanelContainer.new()
		item.add_theme_stylebox_override("panel", Ui.box(Ui.PANEL, Ui.LINE, 30, 3, 16))
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_emote(id):
			var ic := Ui.icon(value(id), 64, Ui.ACCENT)
			ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			item.add_child(ic)
			faces.add_child(item)
		else:
			var l := Ui.label(value(id), 30, Ui.INK, "bold")
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			item.add_child(l)
			phrases.add_child(item)
		Ui.on_tap(item, func() -> void:
			Modal.close_top(app)
			on_pick.call(id))
	var mute_row := Ui.hbox(16)
	var ml := Ui.label(TranslationServer.translate("Hide messages from %s") % opponent_name, 28, Ui.MUTED)
	ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mute_row.add_child(ml)
	var sw := UiSwitch.new()
	sw.on = bool(Store.data["online"]["muted"])
	sw.toggled.connect(func(on: bool) -> void:
		Store.data["online"]["muted"] = on
		Store.save_data())
	mute_row.add_child(sw)
	Modal.show(app, "Say something", [faces, phrases, mute_row], [["Close", func() -> void: pass]])


## A speech bubble over the right end of a player's panel for a few seconds.
static func bubble(host: Control, panel: Control, mine: bool, id: int) -> void:
	if id < 0 or id >= ITEMS.size():
		return
	var b := PanelContainer.new()
	b.add_theme_stylebox_override("panel", Ui.box(Ui.WHITE, Ui.ACCENT if not mine else Ui.LINE, 32, 4, 18))
	if is_emote(id):
		b.add_child(Ui.icon(value(id), 72, Ui.ACCENT))
	else:
		b.add_child(Ui.label(value(id), 32, Ui.INK, "bold"))
	b.z_index = 60
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(b)
	await host.get_tree().process_frame
	if not is_instance_valid(b) or not is_instance_valid(panel):
		return
	b.global_position = panel.global_position + Vector2(panel.size.x - b.size.x - 30, -b.size.y * 0.55)
	if not mine:
		Sfx.tap()
	var tw := b.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(b, "modulate:a", 0.0, 0.4)
	tw.tween_callback(b.queue_free)
