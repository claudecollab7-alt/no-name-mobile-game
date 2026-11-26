extends AppScreen
## End-of-game popup over the board: who won and why, three numbers, and what next.
## The finished board stays visible behind the card; a win gets a burst of confetti.

const R := preload("res://games/aadupuli/rules/aadupuli_rules.gd")

var final_state: R.State
var mode := "pass"
var level := "medium"
var human_side := "goats"
var tigers_won := false
var opponent := {}  ## Online only
var reason := ""  ## Online only: captured, trapped, stuck, resign, timeout, left
var _rematch_button: Button
var _note: Label
var _moving_on := false


static func create(s: R.State, p_mode: String, p_level: String, p_side: String, p_tigers_won: bool) -> AppScreen:
	var r: AppScreen = load("res://shell/screens/result_screen.gd").new()
	r.final_state = s
	r.mode = p_mode
	r.level = p_level
	r.human_side = p_side
	r.tigers_won = p_tigers_won
	return r


func _ready() -> void:
	var col := _popup()
	var human_won := (human_side == "tigers") == tigers_won

	var them := str(opponent.get("name", "Player"))
	var context := "PASS AND PLAY" if mode == "pass" else tr("%s  ·  YOU PLAYED %s") % [tr(level.capitalize()).to_upper(), tr(human_side).to_upper()]
	if mode == "online":
		context = tr("ONLINE  ·  YOU PLAYED %s") % tr(human_side).to_upper()
	var top := Ui.label(context, 24, Ui.MUTED, "bold")
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(top)

	var headline: String
	if mode == "online":
		headline = "You win!" if human_won else tr("%s wins") % them
	elif mode == "computer":
		headline = "You win!" if human_won else "The computer wins"
	else:
		headline = "The tigers win!" if tigers_won else "The goats win!"
	var h := Ui.heading(headline, 70)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(h)
	var why := "The tigers captured 5 goats." if tigers_won and final_state.captured >= final_state.capture_target else (
		"The goats held the hill: 40 tiger moves without a capture." if not tigers_won and R.held(final_state) else (
		"All three tigers are trapped." if not tigers_won else "The goats had no move left."))
	if mode == "online":
		var whose := "You" if not human_won else them
		match reason:
			"resign": why = tr("%s resigned.") % whose
			"timeout": why = tr("%s ran out of time twice.") % whose
			"left": why = tr("%s left the game.") % whose
	var w := Ui.muted(why, 30)
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(w)
	if mode != "pass" and human_won:
		Sfx.vibrate(40)
	_play_sound.call_deferred("win" if mode == "pass" or human_won else "lose")

	var badge := Ui.token(tigers_won, 70)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.move_child(top, 0)
	col.add_child(badge)
	col.move_child(badge, 0)
	if mode == "pass" or human_won:
		_confetti()

	var nums := Ui.hbox(16)
	var third: Array = ["Win streak", str(Store.stat("streak"))] if mode == "computer" else ["Goats left", str(R.goats_on_board(final_state))]
	if mode == "online":
		third = ["Online wins", str(Store.stat("online_wins"))]
	for pair: Array in [["Moves", str(final_state.moves_played)], ["Goats caught", str(final_state.captured)], third]:
		var c := Ui.card(Ui.PANEL, Ui.LINE, 18, 30)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := Ui.vbox(0)
		var big := Ui.heading(pair[1], 52)
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(big)
		var small := Ui.label(pair[0], 24, Ui.MUTED)
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(small)
		c.add_child(v)
		nums.add_child(c)
	col.add_child(nums)

	if mode == "online":
		_note = Ui.muted("", 28)
		_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(_note)
		var orow := Ui.hbox(18)
		orow.add_child(Ui.button("Home", func() -> void: app.home()))
		_rematch_button = Ui.button("Rematch", _ask_rematch, true)
		orow.add_child(_rematch_button)
		col.add_child(orow)
		if reason == "left":
			_rematch_button.disabled = true
		Online.message.connect(_on_online)
		return
	var row := Ui.hbox(18)
	row.add_child(Ui.button("Home", func() -> void: app.home()))
	if mode == "computer":
		var other := "goats" if human_side == "tigers" else "tigers"
		row.add_child(Ui.button("Switch sides", func() -> void: _again(other)))
	col.add_child(row)
	col.add_child(Ui.button("Rematch", func() -> void: _again(human_side), true, 124))


func _again(side: String) -> void:
	var play: Script = load("res://shell/screens/play_screen.gd")
	app.pop()  # This popup...
	app.replace(play.create(mode, level, side))  # ...then the finished game beneath it.


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



func _ask_rematch() -> void:
	Online.send({"t": "rematch"})
	_rematch_button.disabled = true
	_rematch_button.text = "Waiting…"
	_note.text = tr("Waiting for %s to say yes. You'll swap sides.") % str(opponent.get("name", "Player"))


func _on_online(msg: Dictionary) -> void:
	if not is_inside_tree():
		return
	var them := str(opponent.get("name", "Player"))
	match str(msg.get("t", "")):
		"rematch_offer":
			_note.text = tr("%s wants a rematch!") % them
		"opponent_left":
			_note.text = tr("%s has left.") % them
			_rematch_button.disabled = true
			_rematch_button.text = "Rematch"
		"start":
			_moving_on = true
			var play: Script = load("res://shell/screens/play_screen.gd")
			app.pop()
			app.replace(play.create_online(msg))


func _exit_tree() -> void:
	if mode == "online" and not _moving_on:
		Online.send({"t": "leave"})



func _play_sound(kind: String) -> void:
	await get_tree().create_timer(0.55).timeout  # In step with the card popping in.
	if is_inside_tree():
		Sfx.play(kind)
