extends Node
# Sets up a later-game store (two registers, staff, coolers, decorations,
# and in the zombie game some blood and the mop) and saves screenshots.
#   SHOT_DIR=/some/dir godot --path . res://tests/showcase.tscn

var shot_dir := OS.get_environment("SHOT_DIR")


func _ready() -> void:
	seed(99)
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	var hud: Node = main.get_node("HUD")
	add_child(main)
	await _frames(2)
	var store: Store = Game.store
	var p: Player = Game.player
	var b: BuildMode = Game.build_mode

	Game.open_store()
	Game.money = 3000.0
	Game.add_xp(1500.0)
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
	b.select_place("register")
	b.tap(Iso.cell_to_world(Vector2i(2, 6)))
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
	Game.hire("cashier")
	Game.hire("cashier")
	Game.hire("stocker")
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
	p.zoom_by(1.0 / 0.72)

	hud.open_computer()
	hud.computer.show_tab(2)  # Staff
	await _frames(4)
	await _shot("computer_staff")
	hud.computer.close()

	b.enter()
	p.zoom_by(0.8)
	b.select_place("register")
	b._hover(Iso.cell_to_world(Vector2i(12, 6)))
	await _frames(3)
	await _shot("build_register")
	b.exit()
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
