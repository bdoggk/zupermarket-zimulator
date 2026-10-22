extends Node
# Taking a particular product off a storage rack: with more than one product
# on it, using the rack brings up a list to pick from (keyboard, mouse,
# controller), and you get the fullest box of what you picked. With one
# product it hands it over straight away, like before. The list keeps up
# with stockers and closes when you walk off.
#   godot --headless --path . --fixed-fps 60 res://tests/rack_test.tscn

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	var hud: Node = main.get_node("HUD")
	var store: Store = Game.store
	var p: Player = Game.player
	Game.tutorial_hidden = true
	Game.money = 5000.0
	var guts: String = Game.unlocked_ids()[0]
	var blood: String = Game.unlocked_ids()[1]

	var rack_cell := _free_cell(store, Vector2i(3, 6))
	var rack: StorageRack = store.add_furniture("storage", rack_cell)
	store.layout_changed()
	var stand := store.stand_cell_for(rack.cell, rack.cell)
	p.position = Iso.cell_to_world(stand)
	await _frames(2)
	rack.store_box(guts, 5)
	rack.store_box(blood, 6)
	rack.store_box(guts, 8)
	var panel: Control = hud.rack_panel

	# ---- one product: straight into your hands, like before
	var solo: StorageRack = store.add_furniture("storage", _free_cell(store, Vector2i(9, 6)))
	solo.store_box(blood, 2)
	solo.store_box(blood, 6)
	check(solo.get_prompt(p) == "Take %s x6 (2/6)" % Game.product_name(blood) and not solo.asks_which(p), "one product on a rack: it offers the fullest box: " + solo.get_prompt(p))
	solo.interact(p)
	check(p.carry_product == blood and p.carry_count == 6 and not panel.visible, "and hands it over without a list")
	p.drop_carry()
	store.remove_furniture(solo)

	# ---- more than one: a list to pick from
	check(rack.get_prompt(p) == "Take a box: pick from 2 products (3/6)", "two products: the prompt says you'll pick: " + rack.get_prompt(p))
	check(rack.get_action_time(p) == 0.0, "the list comes up straight away (no wait)")
	p.use(rack)
	await _frames(3)
	check(panel.visible, "using the rack brings up the list")
	var takes := _takes(panel)
	check(takes.size() == 2, "one row per product (%d)" % takes.size())
	check(_row_text(panel, 0).contains("2 boxes: x5 + x8") and takes[0].text == "Take x8", "a row says how many boxes and how full: '%s', %s" % [_row_text(panel, 0).replace("\n", " / "), takes[0].text])
	check(_focus() == takes[0], "the first Take is selected (keyboard and controller)")
	var stood := p.position
	await _key(KEY_DOWN)
	check(_focus() == takes[1], "Down: the next product")
	check(p.position.is_equal_approx(stood), "the arrow keys don't walk you off")
	await _key(KEY_ENTER)
	check(p.carry_product == blood and p.carry_count == 6, "Enter takes that one: %s x%d" % [p.carry_product, p.carry_count])
	check(not panel.visible and rack.boxes.size() == 2 and rack.count_of(blood) == 0, "the list closes, the rest stay on the rack")

	# With the mouse: click Take.
	rack.interact(p)  # (puts the box back)
	check(rack.boxes.size() == 3 and not p.is_carrying(), "put it back")
	p.use(rack)
	await _frames(3)
	var tb: Button = _takes(panel)[0]
	await _click(tb)
	check(p.carry_product == guts and p.carry_count == 8, "clicking Take on the first product gives its fullest box (x%d)" % p.carry_count)
	check(rack.boxes.size() == 2 and rack.fullest(guts).count == 5, "the half-empty one is still there")
	rack.interact(p)

	# With a controller: d-pad and A.
	UI.pretend_pad = true
	p.use(rack)
	await _frames(3)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_A)
	check(p.carry_product == blood, "a controller: d-pad down, A takes the second product")
	rack.interact(p)
	UI.pretend_pad = false

	# ---- the list keeps up, and closes when it should
	p.use(rack)
	await _frames(3)
	await _key(KEY_ESCAPE)
	check(not panel.visible and not get_tree().paused, "Esc closes it (no pause menu)")
	p.use(rack)
	await _frames(3)
	rack.store_box(blood, 3)  # a stocker puts one on
	await _frames(2)
	check(_row_text(panel, 1).contains("2 boxes"), "a box put on while it's open shows up: " + _row_text(panel, 1).replace("\n", " / "))
	for b in rack.boxes.duplicate():
		if b.product_id == blood:
			rack.take(b)  # stockers take them all
	await _frames(2)
	check(not panel.visible, "it closes when only one product is left")
	rack.store_box(blood, 4)
	p.use(rack)
	await _frames(3)
	p.position = Iso.cell_to_world(_free_cell(store, rack.cell + Vector2i(4, 4)))
	await _frames(3)
	check(not panel.visible, "and when you walk away")
	p.position = Iso.cell_to_world(stand)
	await _frames(2)
	p.pick_up(guts, 3)
	check(rack.get_prompt(p).begins_with("Store") and not rack.asks_which(p), "carrying a box, using it still puts the box away: " + rack.get_prompt(p))
	p.drop_carry()
	Game.rack_requested.emit(rack)
	await _frames(2)
	Game.build_mode.enter()
	await _frames(2)
	check(not panel.visible, "build mode closes it")
	Game.build_mode.exit()

	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


func _takes(panel: Node) -> Array[Button]:
	var out: Array[Button] = []
	for c in panel.grid.get_children():
		if c is Button and not c.is_queued_for_deletion():
			out.append(c)
	return out


func _row_text(panel: Node, row: int) -> String:
	var labels: Array = panel.grid.get_children().filter(func(c): return c is Label and not c.is_queued_for_deletion())
	return (labels[row] as Label).text if row < labels.size() else ""


func _free_cell(store: Store, near: Vector2i) -> Vector2i:
	for r in 8:
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var c := near + Vector2i(dx, dy)
				if store.placement_error(c, "storage") == "":
					return c
	return near


func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


func _key(k: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(2)


func _pad(b: JoyButton) -> void:
	for down in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(2)


func _click(c: Control) -> void:
	var at: Vector2 = c.get_global_transform_with_canvas() * (c.size / 2.0)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = at
		e.global_position = at
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		get_viewport().push_input(e, true)  # (in the game's own coordinates, whatever the window)
		await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
