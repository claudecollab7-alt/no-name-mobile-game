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


static func how_to_play(host: Node) -> void:
	var rows: Array = []
	var steps := [
		[false, "Goats go first", "Place one goat per turn on any empty point. Goats can't move until all 15 are on the board."],
		[true, "Tigers hunt", "Move one step along a path, or jump over a goat to the empty point behind it to capture it."],
		[true, "Tigers win", "by capturing 5 goats."],
		[false, "Goats win", "by trapping all 3 tigers so none can move, or by holding out: once all goats are placed, if the tigers make 40 moves without a capture, the goats win."],
		[false, "No endless shuffling", "You can't make a move that repeats the same position a third time."],
	]
	for step: Array in steps:
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
	show(host, "How to play", rows, [["Got it", func() -> void: pass, true]])
	Store.data["seen_rules"] = true
	Store.save_data()
