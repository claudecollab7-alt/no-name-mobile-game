class_name Modal
extends RefCounted
## Centered cards over a dimmed screen: How to play, confirmations, short info pages.


## Shows a card with a title, any content nodes and a row of actions.
## actions: Array of [label, Callable, primary: bool]. Each action closes the card first.
static func show(host: Node, title: String, content: Array, actions: Array) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 100
	overlay.add_to_group("modal")
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.17, 0.1, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var card := Ui.card(Ui.CARD, Color(0, 0, 0, 0), 52, 44)
	card.custom_minimum_size.x = 940
	center.add_child(card)
	var col := Ui.vbox(30)
	card.add_child(col)
	if title != "":
		col.add_child(Ui.heading(title, 54))
	for c: Control in content:
		col.add_child(c)
	if not actions.is_empty():
		var row := Ui.hbox(18)
		col.add_child(row)
		for a: Array in actions:
			var cb: Callable = a[1]
			row.add_child(Ui.button(a[0], func() -> void:
				overlay.queue_free()
				cb.call(), a.size() > 2 and a[2]))
	host.add_child(overlay)
	return overlay


static func close_top(host: Node) -> bool:
	var modals := host.get_tree().get_nodes_in_group("modal")
	if modals.is_empty():
		return false
	modals[-1].queue_free()
	return true


static func text(t: String) -> Label:
	var l := Ui.muted(t, 30)
	l.custom_minimum_size.x = 820
	return l


static func how_to_play(host: Node, board := "aadupuli") -> void:
	var rows: Array = []
	var info := Games.tiger_info(board)
	for step: Array in info["rules"]:
		var row := Ui.hbox(28)
		row.add_child(Ui.token(step[0], 30))
		var words := Ui.vbox(2)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(Ui.heading(step[1], 38))
		var body := Ui.muted(step[2], 30)
		body.custom_minimum_size.x = 680
		words.add_child(body)
		row.add_child(words)
		rows.append(row)
	var actions: Array = [["Got it", func() -> void: pass, true]]
	if info["lessons"]:
		actions.push_front(["Try the tutorial", func() -> void: host.push(load("res://shell/screens/tutorial_screen.gd").new())])
	var title := "How to play" if board == "aadupuli" else TranslationServer.translate("How to play %s") % TranslationServer.translate(str(info["title"]))
	show(host, title, rows, actions)
	if board == "aadupuli":
		Store.data["seen_rules"] = true
		Store.save_data()


## First launch: offer the hands-on tutorial, or the one-screen rules.
static func welcome(host: Node) -> void:
	var art := Ui.hbox(18)
	art.alignment = BoxContainer.ALIGNMENT_CENTER
	art.add_child(Ui.avatar("tiger", 0, 150))
	art.add_child(Ui.avatar("goat", 1, 150))
	var body := text("Three tigers hunt fifteen goats on a hill. Learn it in about a minute with five tiny lessons, played on the real board.")
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	show(host, "Welcome to Tiger & Goat", [art, body], [
		["Just the rules", func() -> void: how_to_play(host)],
		["Start the tutorial", func() -> void: host.push(load("res://shell/screens/tutorial_screen.gd").new()), true],
	])
	Store.data["seen_rules"] = true
	Store.save_data()
