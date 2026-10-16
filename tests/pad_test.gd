extends Node
# Playing with a controller (no mouse, no touch): the store computer, its
# apps, the market stalls and Bone Mart's price list all work with the
# d-pad, A and B.
#   godot --headless --path . --fixed-fps 60 res://tests/pad_test.tscn

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	UI.pretend_pad = true
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	var hud: Node = main.get_node("HUD")
	var pc: Node = hud.computer
	Game.tutorial_hidden = true
	Game.money = 2000.0
	Game.add_xp(5000.0)  # a long list of products
	for id in Game.PRODUCTS:
		if id != "brains":
			Game.buy_license(id)
	Game.money = 5000.0
	await _frames(1)
	hud.levelup_panel.visible = false

	# ---- the computer
	hud.open_computer()
	await _frames(3)
	check(_focus() == pc.desktop_icons[0], "the computer opens with its first app selected: " + _focus_name())
	await _button(JOY_BUTTON_A)
	check(pc.is_app_open() and pc.tab == 0, "A opens Stock & Prices")
	var first := _focus()
	check(first is Button and pc.body.is_ancestor_of(first), "and selects the first button in it: " + _focus_name())
	var orders: int = Game.store.pending_deliveries.size()
	var seen := {}
	for i in 12:
		seen[_focus()] = true
		if _focus() is Button and (_focus() as Button).text == "Order box":
			break
		await _button(JOY_BUTTON_DPAD_RIGHT)
	check(_focus() is Button and (_focus() as Button).text == "Order box", "the d-pad gets to Order box: " + _focus_name())
	await _button(JOY_BUTTON_A)
	await _frames(2)
	check(Game.store.pending_deliveries.size() == orders + 1, "and A orders a box")
	for i in 9:
		await _button(JOY_BUTTON_DPAD_DOWN)
	check(_focus() != null and pc.body.is_ancestor_of(_focus()), "down the list (it scrolls along): " + _focus_name())
	check(pc.scroll.scroll_vertical > 0, "the list scrolled to show it (%d)" % pc.scroll.scroll_vertical)
	await _button(JOY_BUTTON_B)
	check(pc.visible and not pc.is_app_open(), "B goes back to the desktop")
	check(_focus() == pc.desktop_icons[0], "with the app it came from selected")
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_A)
	check(pc.is_app_open() and pc.tab == 1, "d-pad + A opens Products")
	var licenses := Game.licensed.size()
	var found := false
	for i in 30:
		var f := _focus()
		if f is Button and (f as Button).text.begins_with("License") and not (f as Button).disabled:
			found = true
			break
		await _button(JOY_BUTTON_DPAD_DOWN)
	check(found, "you can get to a License button")
	if found:
		var at := _focus()
		await _button(JOY_BUTTON_A)
		await _frames(2)
		check(Game.licensed.size() == licenses + 1, "and buy it")
		check(_focus() != null and (pc.body.is_ancestor_of(_focus()) or _focus() == pc.window_close),
			"something stays selected after the list is rebuilt (the X when there's nothing left to buy): " + _focus_name())
	await _button(JOY_BUTTON_B)
	await _button(JOY_BUTTON_DPAD_DOWN)
	await _button(JOY_BUTTON_A)
	check(pc.tab == 2 and _focus() is Button, "Staff: " + _focus_name())
	var staff := Game.staff.size()
	await _button(JOY_BUTTON_A)
	await _frames(2)
	check(Game.staff.size() == staff + 1, "A hires someone")
	await _button(JOY_BUTTON_B)
	await _button(JOY_BUTTON_B)
	check(not pc.visible, "B again turns the computer off")

	# ---- a market stall
	Game.shop_requested.emit("brewery")
	await _frames(2)
	check(hud.shop_panel.visible and _focus() is Button and (_focus() as Button).text.begins_with("Buy"), "a market stall opens with Buy selected: " + _focus_name())
	await _button(JOY_BUTTON_A)
	check(Game.has_effect("swift"), "A buys the potion")
	await _button(JOY_BUTTON_B)
	check(not hud.shop_panel.visible, "B closes the stall")

	# ---- Bone Mart's price list
	Game.rival_requested.emit()
	await _frames(2)
	check(hud.rival_panel.visible and _focus() == hud.rival_panel.buy_button, "Bone Mart's list opens with Buy out selected: " + _focus_name())
	await _button(JOY_BUTTON_DPAD_RIGHT)
	check(_focus() == hud.rival_panel.close_button, "right: Close")
	await _button(JOY_BUTTON_A)
	check(not hud.rival_panel.visible, "A closes it")
	Game.money = 10.0
	Game.rival_requested.emit()
	await _frames(2)
	check(_focus() == hud.rival_panel.close_button, "when you can't buy it out, Close is selected")
	await _button(JOY_BUTTON_B)
	check(not hud.rival_panel.visible, "B closes it")
	check(not hud.pause_menu.visible, "B never opens the pause menu by itself")
	await _button(JOY_BUTTON_B)
	check(not hud.pause_menu.visible and not get_tree().paused, "(even with nothing open)")
	await _button(JOY_BUTTON_START)
	check(hud.pause_menu.visible, "Start pauses")
	await _button(JOY_BUTTON_B)
	check(not hud.pause_menu.visible and not get_tree().paused, "B unpauses")

	# ---- build mode with a controller: the middle of the screen is the cursor
	var b: BuildMode = Game.build_mode
	var store: Store = Game.store
	Game.money = 5000.0
	await _button(JOY_BUTTON_Y)
	check(b.active, "Y goes into build mode")
	await _button(JOY_BUTTON_DPAD_RIGHT)
	check(b.tool == BuildMode.Tool.PLACE and b.place_id == Game.FURNITURE.keys()[0], "d-pad right picks the first thing to buy: " + b.place_id)
	var spot := Store.NO_CELL
	for c: Vector2i in store.floor_cells:
		if store.placement_error(c, b.place_id) == "":
			spot = c
			break
	_look_at(b, spot)
	await _frames(3)
	check(b.cursor == spot and b.cursor_error == "", "the tile in the middle of the screen is previewed: %s (%s)" % [b.cursor, b.cursor_error])
	var shelves := store.shelves.size()
	await _button(JOY_BUTTON_A)
	check(store.shelves.size() == shelves + 1 and store.objects.has(spot), "A buys it there")
	await _button(JOY_BUTTON_DPAD_LEFT)
	var tools := b._pad_tools()
	check(b._pad_current() == tools[-1], "d-pad left from the first one wraps around to the last tool: %s" % b._pad_current())
	while b.tool != BuildMode.Tool.SELL:
		await _button(JOY_BUTTON_DPAD_RIGHT)
	_look_at(b, Vector2i(-50, -50))
	await _frames(2)
	_look_at(b, spot)
	await _frames(3)
	check(b.selected == store.objects.get(spot), "Sell: looking at the new shelf picks it")
	await _button(JOY_BUTTON_A)
	check(not store.objects.has(spot), "A sells it")
	await _button(JOY_BUTTON_B)
	await _button(JOY_BUTTON_B)
	check(not b.active and not get_tree().paused, "B (twice) leaves build mode")

	UI.pretend_pad = false
	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


## Moves the build mode view so `cell` is in the middle of the screen.
func _look_at(b: BuildMode, cell: Vector2i) -> void:
	var cam: Camera2D = Game.player.camera
	cam.offset = Iso.cell_to_world(cell) - cam.get_screen_center_position() + cam.offset
	cam.force_update_scroll()


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func _focus_name() -> String:
	var f := _focus()
	if f == null:
		return "(nothing)"
	return "%s '%s'" % [f.get_class(), (f as Button).text if f is Button else ""]


func _button(b: JoyButton) -> void:
	for pressed in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = pressed
		e.device = 0
		Input.parse_input_event(e)
		await get_tree().process_frame
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
