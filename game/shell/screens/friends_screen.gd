extends AppScreen
## Friends tab: "coming soon" until online play arrives in release 2 (D46).

const GamePage := preload("res://shell/screens/game_page.gd")


func _ready() -> void:
	var col := page()
	col.add_child(Ui.heading("Friends", 62))
	var card := Ui.card(Ui.PANEL, Ui.LINE, 40)
	var v := Ui.vbox(18)
	var avatars := Ui.hbox(-24)
	avatars.alignment = BoxContainer.ALIGNMENT_CENTER
	avatars.add_child(Ui.avatar("tiger", 0, 150))
	avatars.add_child(Ui.avatar("goat", 2, 150))
	v.add_child(avatars)
	var t := Ui.heading("Play with friends, anywhere", 44)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var body := Ui.muted("Send a link, and your friend joins your game from their own phone. Take turns whenever suits you both.", 30)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(body)
	var soon := Ui.pill("Coming in the next update", Ui.SOFT, Ui.MUTED, 26)
	soon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(soon)
	card.add_child(v)
	col.add_child(card)

	var meanwhile := Ui.card(Ui.WARM, Ui.ACCENT_LINE, 28)
	var row := Ui.hbox(22)
	row.add_child(Ui.icon("users", 64, Ui.ACCENT))
	var w := Ui.vbox(0)
	w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	w.add_child(Ui.heading("Together on one phone", 34))
	w.add_child(Ui.muted("Pass and play works right now.", 26))
	row.add_child(w)
	row.add_child(Ui.icon("chevron-right", 48, Ui.MUTED))
	meanwhile.add_child(row)
	Ui.on_tap(meanwhile, _pass_and_play)
	col.add_child(meanwhile)


func _pass_and_play() -> void:
	Store.set_last("mode", "pass")
	app.push(GamePage.new())
