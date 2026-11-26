extends AppScreen
## Shared end-of-game popup: a dimmed backdrop over the finished board, a card that pops
## in once the last move has finished animating, confetti for a win, and the win or lose
## sound in step with the card. Each game's result screen fills the card.


func _init() -> void:
	super()
	is_overlay = true
	z_index = 90  # Above the board's pieces (z 1-2), below cards opened from it (z 100).


## Dimmed backdrop and a centred card that pops in; returns the card's column.
func _popup() -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.17, 0.1, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var card := Ui.card(Ui.CARD, Color(0, 0, 0, 0), 48, 48)
	card.custom_minimum_size.x = 960
	center.add_child(card)
	var col := Ui.vbox(22)
	card.add_child(col)
	card.pivot_offset = Vector2(480, 400)
	card.scale = Vector2(0.86, 0.86)
	card.modulate.a = 0.0
	dim.modulate.a = 0.0
	# Pause briefly so the winning move finishes animating, then pop in.
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dim, "modulate:a", 1.0, 0.25).set_delay(0.6)
	tw.tween_property(card, "scale", Vector2.ONE, 0.32).set_delay(0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(0.6)
	card.resized.connect(func() -> void: card.pivot_offset = card.size / 2.0)
	return col


func _confetti() -> void:
	var c := CPUParticles2D.new()
	c.z_index = 120
	c.amount = 90
	c.one_shot = true
	c.explosiveness = 0.92
	c.lifetime = 2.4
	c.direction = Vector2(0, -1)
	c.spread = 70.0
	c.initial_velocity_min = 700.0
	c.initial_velocity_max = 1300.0
	c.gravity = Vector2(0, 1500)
	c.angular_velocity_min = -360.0
	c.angular_velocity_max = 360.0
	c.scale_amount_min = 9.0
	c.scale_amount_max = 18.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	ramp.colors = PackedColorArray([Ui.ACCENT, Color("#F6C66B"), Color("#FFFFFF"), Color("#6E9A4C"), Ui.ACCENT])
	c.color_initial_ramp = ramp
	add_child(c)
	await get_tree().create_timer(0.65).timeout
	if is_inside_tree():
		c.position = Vector2(size.x / 2.0, size.y * 0.42)
		c.emitting = true


func _play_sound(kind: String) -> void:
	await get_tree().create_timer(0.55).timeout  # In step with the card popping in.
	if is_inside_tree():
		Sfx.play(kind)


## A row of number cards: [[label, value], ...].
func number_cards(pairs: Array) -> HBoxContainer:
	var nums := Ui.hbox(16)
	for pair: Array in pairs:
		var c := Ui.card(Ui.PANEL, Ui.LINE, 18, 30)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := Ui.vbox(0)
		var big := Ui.heading(str(pair[1]), 52)
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(big)
		var small := Ui.label(str(pair[0]), 24, Ui.MUTED)
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(small)
		c.add_child(v)
		nums.add_child(c)
	return nums
