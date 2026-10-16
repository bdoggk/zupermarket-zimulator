extends Node
# Sets up a later-game store (two registers, staff, coolers, decorations,
# and in the zombie game some blood and the mop) and saves screenshots.
#   SHOT_DIR=/some/dir godot --path . res://tests/showcase.tscn
# TOUCH=1 shows the phone / handheld layout. WINDOW=960x540 sets the window size.
# PAD=1 acts as if a controller was plugged in.

var shot_dir := OS.get_environment("SHOT_DIR")


func _ready() -> void:
	seed(99)
	var size := OS.get_environment("WINDOW")  # e.g. 960x540: a window that size (not saved)
	if size != "":
		var wh := size.split("x")
		Settings.display = Settings.Display.WINDOWED
		Settings.resolution = Vector2i(int(wh[0]), int(wh[1]))
		Settings.apply()
		await get_tree().process_frame
		await get_tree().process_frame
	UI.pretend_pad = OS.get_environment("PAD") == "1"  # as if a controller was plugged in
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	var hud: Node = main.get_node("HUD")
	hud.force_touch_ui = OS.get_environment("TOUCH") == "1"
	add_child(main)
	await _frames(2)
	var store: Store = Game.store
	var p: Player = Game.player
	var b: BuildMode = Game.build_mode

	Game.open_store()
	Game.money = 3000.0
	Game.add_xp(1500.0)
	await _frames(3)
	await _shot("level_up")
	hud.levelup_panel.visible = false
	for id in Game.PRODUCTS:
		if Game.can_license(id):
			Game.buy_license(id)
	Game.buy_upgrade("scanner")

	b.enter()
	for c in [Vector2i(9, 4), Vector2i(10, 4), Vector2i(11, 4)]:
		b.select_place("shelf")
		b.tap(Iso.cell_to_world(c))
	for c in [Vector2i(9, 7), Vector2i(10, 7), Vector2i(11, 7)]:
		b.select_place("fridge")
		b.tap(Iso.cell_to_world(c))
	b.select_place("plant")
	b.tap(Iso.cell_to_world(Vector2i(13, 3)))
	var lanterns := 0
	for c in [Vector2i(1, 4), Vector2i(1, 8), Vector2i(13, 9), Vector2i(6, 9), Vector2i(14, 5), Vector2i(4, 1)]:
		if lanterns < 3 and store.placement_error(c, "lantern") == "":
			b.select_place("lantern")
			b.tap(Iso.cell_to_world(c))
			lanterns += 1
	b.select_place("register")
	b.tap(Iso.cell_to_world(Vector2i(2, 6)))
	if store.town:
		b.select_place("storage")
		for c in [Vector2i(13, 3), Vector2i(12, 3), Vector2i(8, 3)]:
			if store.placement_error(c, "storage") == "":
				b.tap(Iso.cell_to_world(c))
				break
		b.select_place("selfcheckout")
		b.tap(Iso.cell_to_world(Vector2i(13, 7)))
	Game.buy_floor_style(2)
	Game.buy_wall_color(2)
	b.exit()

	var dry: Array = Game.unlocked_ids().filter(func(id): return not Game.is_cold(id))
	var cold: Array = Game.unlocked_ids().filter(func(id): return Game.is_cold(id))
	var di := 0
	var ci := 0
	for s in store.shelves:
		var pool := cold if s.holds_cold() else dry
		var i := ci if s.holds_cold() else di
		s.product_id = pool[i % pool.size()]
		s.stock = 7 + (i * 5) % 6
		s.queue_redraw()
		if s.holds_cold():
			ci += 1
		else:
			di += 1
	Game.minute = 10 * 60 + 40
	Game.next_market_minute = 12 * 60
	Game.money = maxf(Game.money, 2000.0)
	Game.hire("cashier")
	Game.hire("cashier")
	Game.hire("stocker")
	if store.town:
		Game.hire("janitor")
		Game.add_staff_xp(Game.staff[0].id, 95.0)
		for r in store.racks:
			r.store_box(dry[0], 6)
			r.store_box(dry[1 % dry.size()], 8)
			r.store_box(cold[0] if not cold.is_empty() else dry[0], 4)
		Game.scout_rival([dry[0], dry[1 % dry.size()]])
	store.place_box(dry[0])
	if Brand.SPILLS:
		for c in [Vector2i(8, 6), Vector2i(12, 9), Vector2i(4, 9)]:
			store.add_spill(c)

	for i in 7:
		store.spawn_customer()
		await _seconds(1.0)
	await _seconds(9.0)

	p.position = Iso.cell_to_world(Vector2i(8, 7))
	if Brand.SPILLS:
		p.set_holding_mop(true)
	p.camera.reset_smoothing()
	p.zoom_by(0.72)
	await _seconds(1.2)
	await _shot("store")
	# Point at a shopper with something in their basket.
	var shopper: Customer = null
	for c in store.customers:
		if not c.basket.is_empty():
			shopper = c
	if shopper == null and not store.customers.is_empty():
		shopper = store.customers[0]
	if shopper:
		var at: Vector2 = get_viewport().get_canvas_transform() * (shopper.position + Vector2(0, -16))
		get_viewport().warp_mouse(at)
		await _frames(3)
		await _shot("shopper_card")
		get_viewport().warp_mouse(Vector2(5, 5))
	p.zoom_by(1.0 / 0.72)

	hud.open_computer()
	await _frames(4)
	await _shot("computer_desktop")
	hud.computer.show_tab(1)  # Products
	await _frames(4)
	await _shot("computer_products")
	hud.computer.show_tab(2)  # Staff
	await _frames(4)
	await _shot("computer_staff")
	hud.computer.show_tab(0)  # Stock
	await _frames(4)
	await _shot("computer_stock")
	hud.computer.show_tab(3)  # Upgrades
	await _frames(4)
	await _shot("computer_upgrades")
	hud.computer.close()
	if store.town:
		Game.rival_requested.emit()
		await _frames(4)
		await _shot("rival_prices")
		hud.rival_panel.close()
		# The market stalls across the street.
		var counter: ShopCounter = store.town.shop_counters.brewery
		p.position = Iso.cell_to_world(counter.cell + Vector2i(1, -1))
		p.camera.reset_smoothing()
		await _seconds(1.0)
		Game.shop_requested.emit("brewery")
		await _frames(4)
		await _shot("shop_brewery")
		Game.buy_brew("swift")
		Game.buy_brew("wine")
		Game.shop_requested.emit("curios")
		await _frames(4)
		await _shot("shop_curios")
		Game.buy_brew("garlic")
		hud.shop_panel.close()
		await _seconds(0.5)
		await _shot("stalls")
		var at_night := Game.minute
		Game.minute = 19 * 60 + 50
		await _seconds(0.6)
		await _shot("stalls_night")
		Game.minute = at_night
		p.position = Iso.cell_to_world(Vector2i(8, 7))
		p.camera.reset_smoothing()
		b.enter()
		b.select_tool(BuildMode.Tool.EXPAND)
		b._hover(Iso.cell_to_world(b.next_lot()[18]))
		await _frames(4)
		await _shot("build_expand")
		b.exit()

	b.enter()
	p.zoom_by(0.8)
	p.camera.offset = Vector2.ZERO
	b.select_place("register")
	b._hover(Iso.cell_to_world(Vector2i(12, 6)))
	await _frames(3)
	await _shot("build_register")
	b.turn(store.sign)
	for obj in store.registers:
		if obj is SelfCheckout:
			b.turn(obj)
	Game.money += 100.0
	b.select_place("shelf")
	b.place_rotation = 1
	b._hover(Iso.cell_to_world(Vector2i(12, 5)))
	await _frames(3)
	await _shot("build_rotate")
	b.exit()
	p.zoom_by(1.25)
	if Game.STAFF.has("manager"):
		Game.money += 500.0
		Game.hire("manager")
		hud.open_computer()
		hud.computer.show_tab(2)
		await _frames(4)
		await _shot("computer_staff_manager")
		hud.computer.close()
	var lit: Array = store.objects.values().filter(func(o): return o is Lantern)
	if not lit.is_empty():
		Game.minute = 19 * 60 + 50  # dark out: the lanterns matter
		p.position = lit[0].position + Vector2(40, 10)
		p.camera.reset_smoothing()
		await _seconds(1.0)
		await _shot("lanterns")
		Game.minute = 10 * 60 + 40
	for c in store.customers.duplicate():
		if is_instance_valid(c.register):
			c.register.leave_line(c)
		store.customer_left(c)
		c.queue_free()
	Game.end_day()
	await _frames(4)
	await _shot("day_over")
	hud.show_day_summary()
	await _frames(4)
	await _shot("day_summary")
	hud._on_next_day()
	await _frames(2)
	hud.open_pause()
	hud._open_options()
	await _frames(4)
	await _shot("options")
	hud.options.vol_slider.grab_focus()
	hud.options.settings_scroll.scroll_vertical = 10000
	await _frames(4)
	await _shot("options_sound")
	hud.options.show_controls()
	await _frames(4)
	await _shot("controls")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(name: String) -> void:
	if shot_dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	print("saved ", name)
