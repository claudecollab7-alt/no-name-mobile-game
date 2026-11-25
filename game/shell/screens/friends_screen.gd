extends AppScreen
## Friends tab: play a friend online with a room code, or find a player (D46).

const OnlineScreen := preload("res://shell/screens/online_screen.gd")
const GamePage := preload("res://shell/screens/game_page.gd")


func _ready() -> void:
	var col := page()
	col.add_child(Ui.heading("Friends", 62))
	var card := Ui.card(Ui.PANEL, Ui.LINE, 40)
	var v := Ui.vbox(18)
	var avatars := Ui.hbox(24)
	avatars.alignment = BoxContainer.ALIGNMENT_CENTER
	avatars.add_child(Ui.avatar("tiger", 0, 150))
	avatars.add_child(Ui.avatar("goat", 2, 150))
	v.add_child(avatars)
	var t := Ui.heading("Play with friends, anywhere", 44)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var body := Ui.muted("Create a room and send your friend the code. They join from their own phone and the game starts.", 30)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(body)
	v.add_child(Ui.button("Play online", func() -> void: app.push(OnlineScreen.new()), true, 112))
	card.add_child(v)
	col.add_child(card)

	var together := Ui.card(Ui.WARM, Ui.ACCENT_LINE, 28)
	var row := Ui.hbox(22)
	row.add_child(Ui.icon("users", 64, Ui.ACCENT))
	var w := Ui.vbox(0)
	w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w.add_child(Ui.heading("Together on one phone", 34))
	w.add_child(Ui.muted("Pass and play, no internet needed.", 26))
	row.add_child(w)
	row.add_child(Ui.icon("chevron-right", 48, Ui.MUTED))
	together.add_child(row)
	Ui.on_tap(together, _pass_and_play)
	col.add_child(together)

	var soon := Ui.card(Ui.PANEL, Ui.LINE, 28)
	soon.modulate = Color(1, 1, 1, 0.75)
	var srow := Ui.hbox(22)
	srow.add_child(Ui.icon("user-circle", 60, Ui.MUTED))
	var sw := Ui.vbox(0)
	sw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sw.add_child(Ui.heading("Friends list", 34))
	sw.add_child(Ui.muted("Add players you enjoyed and invite them again.", 26))
	srow.add_child(sw)
	srow.add_child(Ui.soon_pill())
	soon.add_child(srow)
	col.add_child(soon)


func _pass_and_play() -> void:
	Store.set_last("mode", "pass")
	app.push(GamePage.new())
