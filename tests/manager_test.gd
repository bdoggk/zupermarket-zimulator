extends Node
# Checks the general manager (reorders anything down to 2 on the shelves,
# boosts the other staff, gets stuck staff moving), stockers taking spare
# boxes back to the delivery zone, and the end-of-day prompt (Space shows
# the summary, Space again starts the next day).
#   godot --headless --path . --fixed-fps 60 res://tests/manager_test.tscn

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	seed(5150)
	Engine.max_fps = 0
	Engine.time_scale = 4.0
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	var store: Store = Game.store
	var p: Player = Game.player
	var hud: Node = main.get_node("HUD")
	var S0 := TestIds.starter(0)
	var S1 := TestIds.starter(1)
	Game.money = 5000.0
	Game.tutorial_hidden = true
	for b: StockBox in store.boxes.values():
		store.remove_box(b)

	# ---- spare boxes go back to the delivery zone
	var dry: Array[Shelf] = []
	for s in store.shelves:
		if not s.holds_cold():
			dry.append(s)
	for s in dry:
		s.product_id = S1
		s.stock = Shelf.CAPACITY
		s.queue_redraw()
	var target := dry[0]
	target.product_id = S0
	target.stock = Shelf.CAPACITY - 3  # room for 3 of the box's 8+
	var zone_cell: Vector2i = store.delivery_cells[0]
	store.drop_box(zone_cell, S0, 8)
	Game.hire("stocker")
	await _frames(2)
	var stocker: Staff = store.staff[0]
	var filled := false
	for i in 2400:
		await get_tree().physics_frame
		if target.stock == Shelf.CAPACITY and stocker.carry_count == 0 and stocker.job == Staff.Job.IDLE:
			filled = true
			break
	check(filled, "the stocker filled the shelf")
	var back: Array = store.boxes.values().filter(func(b): return b.product_id == S0)
	check(back.size() == 1 and back[0].cell in store.delivery_cells, "and took the rest back to the delivery zone (%s)" % [back.map(func(b): return b.cell)])
	check(back.size() == 1 and back[0].count == 8 - 3, "with the %d that didn't fit" % (back[0].count if back.size() == 1 else -1))
	for b: StockBox in store.boxes.values():
		store.remove_box(b)

	# ---- the general manager
	var plain_speed := stocker.speed
	check(Game.hire_problem("manager") == "", "you can hire a general manager")
	Game.hire("manager")
	await _frames(2)
	var boss: Staff = store.staff.filter(func(s): return s.role == "manager")[0]
	check(Game.hire_problem("manager") != "", "just one: " + Game.hire_problem("manager"))
	check(stocker.speed > plain_speed * 1.1 and stocker.managed, "with a manager, the stocker works faster (%.2fx -> %.2fx)" % [plain_speed, stocker.speed])
	check(not boss.managed, "the manager doesn't boost themself")

	target.stock = 2  # down to 2 and nothing coming
	check(S0 in store.products_running_low(Staff.REORDER_AT), "%s is down to 2 with nothing on the way" % Game.product_name(S0))
	check(not S1 in store.products_running_low(Staff.REORDER_AT), "%s is fully stocked" % Game.product_name(S1))
	var money := Game.money
	var ordered := false
	var went_to_computer := false
	for i in 3000:
		await get_tree().physics_frame
		if boss.job in [Staff.Job.TO_COMPUTER, Staff.Job.ORDERING]:
			went_to_computer = true
		if store.pending_deliveries.any(func(d): return d.id == S0) or store.boxes.values().any(func(b): return b.product_id == S0):
			ordered = true
			break
	check(went_to_computer, "the manager walked to the computer")
	check(ordered, "and ordered more %s" % Game.product_name(S0))
	check(Game.money < money, "it was paid for")
	var orders := store.pending_deliveries.size() + store.boxes.size()
	for i in 600:
		await get_tree().physics_frame
	var orders_after := store.pending_deliveries.size() + store.boxes.values().filter(func(b): return b.product_id == S0).size() + (1 if stocker.carry_product == S0 else 0)
	check(orders_after <= 1 and orders <= 1, "only one box (no ordering twice while it's on the way)")
	check(Game.staff_entry(boss.id).xp > 0.0, "the manager earns XP")

	# Someone stuck on a job for a long time gets told to get back to work.
	stocker._give_up()
	stocker.job = Staff.Job.TO_BOX
	stocker.path.clear()
	stocker._job_time = 100.0
	stocker._last_job = Staff.Job.TO_BOX
	check(stocker.is_slacking(), "a stocker stuck on the same job counts as slacking")
	var nudged := false
	for i in int(Staff.SHOUT_EVERY * 60.0 / Engine.time_scale * 4.0) + 120:
		await get_tree().physics_frame
		if stocker.job != Staff.Job.TO_BOX or stocker._job_time < 50.0:
			nudged = true
			break
	check(nudged, "the manager gets them moving again")
	check(boss.status_text() != "", "the Staff tab says what the manager is up to: " + boss.status_text())

	# ---- end of the day: a prompt first, then the summary, then the next day
	Game.open_store()
	Game.end_day()
	await _frames(2)
	check(hud.day_over_bar.visible and not hud.summary_panel.visible, "when the day ends, a prompt shows at the bottom (no summary yet): " + hud.day_over_bar.text)
	check(hud.day_over_bar.position.y > hud.root.size.y / 2.0, "it's at the bottom of the screen")
	var day := Game.day
	var box := store.place_box(S1)
	p.position = Iso.cell_to_world(store.delivery_cells[0])
	await _frames(3)
	_press_space()
	await _frames(2)
	check(hud.summary_panel.visible and not hud.day_over_bar.visible, "Space shows the day's summary")
	check(not p.is_carrying(), "and doesn't pick anything up")
	check(hud.summary_hint.text.contains("Space"), "the summary says how to go on: " + hud.summary_hint.text)
	_press_space()
	await _frames(2)
	check(not hud.summary_panel.visible and Game.day == day + 1 and not Game.day_over, "Space again starts Day %d" % Game.day)
	check(box, "(a box was waiting next to you the whole time)")

	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


func _press_space() -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_SPACE
		e.physical_keycode = KEY_SPACE
		e.pressed = pressed
		get_viewport().push_input(e)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
