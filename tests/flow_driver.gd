extends Node
# Driver for tests/flow_test.gd. Lives under the root so it survives scene
# changes.

var fails := 0
var shot_dir := OS.get_environment("SHOT_DIR")
var settings_backup := ""


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	Engine.max_fps = 0
	_run()


func _run() -> void:
	if FileAccess.file_exists(Settings.PATH):
		settings_backup = FileAccess.get_file_as_string(Settings.PATH)
	var backups := {}
	for i in Saves.SLOTS:
		if FileAccess.file_exists(Saves.slot_path(i)):
			backups[i] = FileAccess.get_file_as_string(Saves.slot_path(i))
		Saves.delete_slot(i)

	# ---- empty menu
	get_tree().change_scene_to_file(Saves.MENU_SCENE)
	await _frames(5)
	var menu: Node = get_tree().current_scene
	check(menu.name == "Menu", "game starts on the main menu")
	check(menu.continue_button.disabled, "Continue is disabled with no saves")
	check(menu.load_button.disabled, "Load Game is disabled with no saves")
	await _shot("menu_empty")
	menu.show_screen(menu.Screen.NEW)
	await _frames(3)
	check(menu.slots_list.get_child_count() == 3, "three save slots")
	await _shot("menu_new_game")

	# ---- new game in slot 2
	menu._on_slot(1)
	await _frames(8)
	check(get_tree().current_scene.name == "Main", "New Game opens the store")
	check(Game.slot == 1 and Saves.has_save(1), "new game saved to slot 2 right away")
	check(Game.money == Game.STARTING_MONEY and Game.day == 1, "new game starts fresh")
	check(not Game.opened, "new game waits for the OPEN sign")
	Game.store.sign.interact(Game.player)
	check(Game.opened and Game.is_open, "the sign opens the store")

	# make some progress
	var store: Store = Game.store
	var S0 := TestIds.starter(0)
	var S1 := TestIds.starter(1)
	var S2 := TestIds.starter(2)
	var L1 := TestIds.at_level(1, false)
	var L3 := TestIds.at_level(3)
	Game.money = 777.0
	Game.add_xp(400.0)
	Game.buy_license(L1)
	Game.money = 777.0
	var shelf: Shelf = store.add_furniture("shelf", Vector2i(10, 5))
	shelf.product_id = S0
	shelf.stock = 5
	store.add_furniture("fridge", Vector2i(12, 5))
	store.layout_changed()
	Game.floor_style = 3
	Game.wall_color = 1
	Game.decor_changed.emit()
	Game.player.pick_up(S2, 4)
	Game.minute = 13 * 60 + 15
	Game.next_market_minute = 16 * 60
	Game.market.factor[S1] = 1.37
	Game.prices[S1] = 4.5
	Game.upgrades["scanner"] = true
	# move the register (and its line) and the computer
	var moved_reg := Store.NO_CELL
	var moved_pc := Store.NO_CELL
	for y in range(2, store.height - 1):
		for x in range(1, store.width - 1):
			var c := Vector2i(x, y)
			if moved_pc == Store.NO_CELL and Iso.chebyshev(c, store.computer.cell) > 3 and store.placement_error(c, "", store.computer) == "":
				moved_pc = c
	store.move_object(store.computer, moved_pc)
	for y in range(store.height - 2, 1, -1):
		for x in range(1, store.width - 1):
			var c := Vector2i(x, y)
			if moved_reg == Store.NO_CELL and Iso.chebyshev(c, store.register.cell) > 3 and store.placement_error(c, "", store.register) == "":
				moved_reg = c
	store.move_object(store.register, moved_reg)
	var moved_line := store.line_cells.duplicate()
	check(store.register.cell == moved_reg and store.computer.cell == moved_pc, "moved the register to %s and the computer to %s" % [moved_reg, moved_pc])
	Game.order_box(L3)  # level 3, not licensed: refused
	Game.order_box(S0)
	# a second register, and some staff
	var reg2_cell := Store.NO_CELL
	for y in range(2, store.height - 1):
		for x in range(1, store.width - 1):
			var c := Vector2i(x, y)
			if reg2_cell == Store.NO_CELL and store.placement_error(c, "register") == "":
				reg2_cell = c
	Game.money += 1000.0
	store.add_furniture("register", reg2_cell)
	store.layout_changed()
	var reg2_line: Array[Vector2i] = store.registers[1].line_cells.duplicate()
	Game.hire("stocker")
	Game.hire("cashier")
	var staff_names := Game.staff.map(func(e): return e.name)
	Game.money -= 1000.0
	var spill_cells: Array[Vector2i] = []
	if Brand.SPILLS:
		for c in [Vector2i(8, 3), Vector2i(9, 6), Vector2i(3, 8)]:
			store.add_spill(c)
		spill_cells.assign(store.spills.keys())
	# v0.8: a bought lot, a storage rack, a self-checkout, the delivery zone
	# moved, rival prices checked, a staff member with a level
	var town := store.town != null
	var rack_cell := Store.NO_CELL
	var self_cell := Store.NO_CELL
	var zone_anchor := Store.NO_CELL
	if town:
		Game.money += 3000.0
		Game.buy_expansion()
		check(Game.expansions == 1 and store.width == 20, "bought the first lot")
		for y in range(2, store.height - 1):
			for x in range(store.width - 5, store.width - 1):
				var c := Vector2i(x, y)
				if rack_cell == Store.NO_CELL and store.placement_error(c, "storage") == "":
					rack_cell = c
		var rack: StorageRack = store.add_furniture("storage", rack_cell)
		rack.store_box(S0, 6)
		rack.store_box(S1, 3)
		store.layout_changed()
		for y in range(store.height - 2, 1, -1):
			for x in range(store.width - 5, store.width - 1):
				var c := Vector2i(x, y)
				if self_cell == Store.NO_CELL and store.placement_error(c, "selfcheckout") == "":
					self_cell = c
		store.add_furniture("selfcheckout", self_cell)
		store.layout_changed()
		for y in range(2, store.height - 2):
			for x in range(1, store.width - 3):
				var c := Vector2i(x, y)
				if zone_anchor == Store.NO_CELL and c != store.delivery_anchor() and store.delivery_zone_error(c) == "":
					zone_anchor = c
		store.move_delivery_zone(zone_anchor)
		Game.rival_seen[S0] = [1.23, 2]
		Game.add_staff_xp(Game.staff[0].id, 40.0)
		Game.money -= 3000.0
	var spent_money := Game.money

	var hud: Node = get_tree().current_scene.get_node("HUD")
	hud.open_pause()
	await _frames(3)
	check(get_tree().paused, "pause menu pauses the game")
	await _shot("pause_menu")
	hud.pause_menu._save()
	await _frames(2)
	var saved := Saves.read_slot(1)
	check(is_equal_approx(float(saved.game.money), spent_money), "Save Game writes the current money")
	check(not get_tree().paused, "saving closes the pause menu")
	hud.open_pause()
	hud._open_options()
	await _frames(3)
	check(hud.options.visible and not hud.pause_menu.visible, "Options opens from the pause menu")
	await _shot("options_ingame")
	hud.options.close()
	await _frames(2)
	check(hud.pause_menu.visible, "closing Options goes back to the pause menu")

	# ---- quit to menu, continue points at slot 2
	Saves.quit_to_menu()
	await _frames(6)
	menu = get_tree().current_scene
	check(menu.name == "Menu", "Save & Main Menu returns to the menu")
	check(Saves.latest_slot() == 1, "slot 2 is the latest played")
	check(not menu.continue_button.disabled and "Slot 2" in menu.continue_button.text, "Continue shows slot 2: " + menu.continue_button.text.replace("\n", " / "))
	await _shot("menu_continue")

	# ---- play slot 1 for a bit, it becomes the latest
	await get_tree().create_timer(1.1).timeout  # saved_at has 1 second resolution on some systems
	Saves.new_game(0)
	await _frames(8)
	check(Game.slot == 0, "new game in slot 1")
	Game.day = 3
	Game.money = 55.0
	Saves.quit_to_menu()
	await _frames(6)
	menu = get_tree().current_scene
	check(Saves.latest_slot() == 0, "slot 1 is now the latest played")
	check("Slot 1" in menu.continue_button.text and "Day 3" in menu.continue_button.text, "Continue follows the last game played")
	menu.show_screen(menu.Screen.LOAD)
	await _frames(3)
	await _shot("menu_load_game")

	# ---- load slot 2 and check everything came back
	await get_tree().create_timer(1.1).timeout
	menu._on_slot(1)
	await _frames(8)
	store = Game.store
	check(Game.slot == 1, "loaded slot 2")
	check(is_equal_approx(Game.money, spent_money), "money restored ($%.2f)" % Game.money)
	check(Game.level == 3 and is_equal_approx(Game.xp, 400.0), "level and XP restored")
	check(Game.is_licensed(L1) and not Game.is_licensed(L3), "licenses restored")
	check(Game.has_upgrade("scanner"), "upgrades restored")
	var s2: Variant = store.objects.get(Vector2i(10, 5))
	check(s2 is Shelf and s2.product_id == S0 and s2.stock == 5, "placed shelf and its stock restored")
	check(store.objects.get(Vector2i(12, 5)) is Fridge, "placed fridge restored")
	check(store.register.cell == moved_reg and store.objects.get(moved_reg) == store.register, "register position restored")
	check(store.line_cells == moved_line, "checkout line restored with the register: %s" % [store.line_cells])
	check(store.computer.cell == moved_pc and store.objects.get(moved_pc) == store.computer, "computer position restored")
	check(store.registers.filter(func(r): return not r is SelfCheckout).size() == 2 and store.registers[1].cell == reg2_cell, "second register restored")
	check(store.registers[1].line_cells == reg2_line, "second register's line restored")
	check(Game.staff.map(func(e): return e.name) == staff_names, "staff restored: %s" % [staff_names])
	check(store.staff.size() == 2, "staff came back to work")
	if Brand.SPILLS:
		var back: Array[Vector2i] = []
		back.assign(store.spills.keys())
		back.sort()
		spill_cells.sort()
		check(not spill_cells.is_empty() and back == spill_cells, "blood spills restored: %s" % [back])
		check(store.mop_bucket != null, "mop bucket restored")
	var shelves := 0
	for o in store.objects.values():
		if o is Shelf:
			shelves += 1
	check(shelves == 8, "same number of shelves and fridges (%d)" % shelves)
	check(Game.floor_style == 3 and Game.wall_color == 1, "paint restored")
	var wall: Sprite2D = store.wall_cells[Vector2i(0, 0)][0]
	check(wall.texture.resource_path.ends_with("wall_%s_tall.png" % Game.WALL_COLORS[1].id), "walls drawn in the saved color")
	check(Game.player.carry_product == S2 and Game.player.carry_count == 4, "carried box restored")
	check(absf(Game.minute - (13 * 60 + 15)) < 2.0, "time of day restored")
	check(is_equal_approx(Game.market.factor[S1], 1.37) and is_equal_approx(Game.prices[S1], 4.5), "market and prices restored")
	check(store.pending_deliveries.size() == 1 and store.pending_deliveries[0].id == S0, "delivery on the way restored")
	check(store.boxes.size() == 4, "boxes on the floor restored (%d)" % store.boxes.size())
	if town:
		check(Game.expansions == 1 and store.width == 20 and store.is_walkable(Vector2i(17, 5)), "the bought lot is still part of the store")
		var rack: Variant = store.objects.get(rack_cell)
		check(rack is StorageRack and rack.boxes.size() == 2 and rack.boxes[1].product_id == S1 and rack.boxes[1].count == 3, "storage rack and its boxes restored")
		check(store.objects.get(self_cell) is SelfCheckout, "self-checkout restored")
		check(store.delivery_anchor() == zone_anchor, "delivery zone restored at %s" % zone_anchor)
		check(Game.rival_seen.get(S0, []) == [1.23, 2], "checked rival prices restored")
		check(int(Game.staff[0].level) == 2 and store.staff[0].level == 2, "staff level restored")
	await _frames(30)
	await _shot("loaded_game")

	# ---- continue now goes back to slot 2
	Saves.quit_to_menu()
	await _frames(6)
	menu = get_tree().current_scene
	check(Saves.latest_slot() == 1, "loading a game makes it the latest played")

	# ---- delete with confirmation
	menu.show_screen(menu.Screen.LOAD)
	await _frames(2)
	menu._on_delete(1)
	await _frames(2)
	check(menu.screen == menu.Screen.CONFIRM, "Delete asks first")
	await _shot("menu_confirm")
	menu.confirm_no.pressed.emit()
	await _frames(2)
	check(Saves.has_save(1), "Cancel keeps the save")
	menu._on_delete(1)
	await _frames(2)
	menu.confirm_yes.pressed.emit()
	await _frames(2)
	check(not Saves.has_save(1), "confirming deletes the save")
	check(Saves.latest_slot() == 0, "Continue falls back to the other save")

	# ---- overwriting asks first
	menu.show_screen(menu.Screen.NEW)
	await _frames(2)
	menu._on_slot(0)
	await _frames(2)
	check(menu.screen == menu.Screen.CONFIRM and get_tree().current_scene == menu, "starting over on a used slot asks first")
	menu.confirm_no.pressed.emit()
	await _frames(2)
	check(Saves.slot_info(0).day == 3, "Cancel keeps the old game")

	# ---- a save made between days resumes the next morning
	Saves.load_game(0)
	await _frames(8)
	check(not Game.opened, "a save made before opening loads still closed")
	Game.open_store()
	Game.minute = Game.CLOSE_MINUTE - 0.1
	await _frames(20)
	check(Game.day_over, "day ended")
	Saves.save_game()
	Saves.quit_to_menu()
	await _frames(6)
	Saves.load_game(0)
	await _frames(10)
	check(Game.day == 4 and not Game.opened and is_equal_approx(Game.minute, Game.OPEN_MINUTE), "loading a between-days save goes to the next morning, sign not flipped yet (day %d, opened %s, minute %.1f)" % [Game.day, Game.opened, Game.minute])
	Saves.quit_to_menu()
	await _frames(6)
	menu = get_tree().current_scene

	# ---- damaged file
	var f := FileAccess.open(Saves.slot_path(2), FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	menu.show_screen(menu.Screen.LOAD)
	await _frames(2)
	check(Saves.slot_info(2).has("damaged"), "damaged file detected")
	var b3: Button = menu.slots_list.get_child(2).get_child(0)
	check(b3.disabled and "can't be read" in b3.text, "damaged slot can't be loaded")
	check(not Saves.load_game(2), "load_game refuses a damaged file")
	Saves.delete_slot(2)

	# ---- options
	menu.show_screen(menu.Screen.OPTIONS)
	await _frames(3)
	await _shot("options_menu")
	Settings.set_graphics(Settings.Graphics.LOW)
	Settings.set_vsync(false)
	Settings.set_vibration(false)
	Settings.graphics = Settings.Graphics.HIGH
	Settings.vsync = true
	Settings.vibration = true
	Settings.load_settings()
	check(Settings.graphics == Settings.Graphics.LOW and not Settings.vsync and not Settings.vibration, "settings saved and loaded back")
	check(Engine.max_fps == 30, "Low graphics caps the game at 30 FPS")
	Settings.set_graphics(Settings.Graphics.HIGH)
	check(Engine.max_fps == 0, "High graphics has no FPS cap")
	check(menu.options.gfx_value.text == "High", "options screen shows the change")
	menu.options.close()
	await _frames(2)
	check(menu.screen == menu.Screen.MAIN, "Back returns to the main menu")

	# ---- clean up: put back the user's own saves and settings
	for i in Saves.SLOTS:
		Saves.delete_slot(i)
		if backups.has(i):
			var out := FileAccess.open(Saves.slot_path(i), FileAccess.WRITE)
			out.store_string(backups[i])
			out.close()
	if settings_backup != "":
		var out := FileAccess.open(Settings.PATH, FileAccess.WRITE)
		out.store_string(settings_backup)
		out.close()
	else:
		DirAccess.remove_absolute(Settings.PATH)
	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	if shot_dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	print("saved ", name)
