extends Node
# How your staff work, from the computer: each product's Stock switch (off:
# stockers don't stock it, the manager doesn't order it), the Staff app's
# rules (stockers fill shelves with no label, stockers take labels off
# shelves of things you've stopped stocking, when the manager orders), the
# manager putting ordering before everything else, and ordering with the
# Handheld Scanner instead of walking to the computer.
#   godot --headless --path . --fixed-fps 60 res://tests/rules_test.tscn

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	seed(2026)
	Engine.max_fps = 0
	Engine.time_scale = 4.0
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	var store: Store = Game.store
	var hud: Node = main.get_node("HUD")
	var S0 := TestIds.starter(0)
	var S1 := TestIds.starter(1)
	var S2 := TestIds.starter(2)
	Game.money = 9000.0
	Game.tutorial_hidden = true
	for b: StockBox in store.boxes.values():
		store.remove_box(b)
	var dry: Array[Shelf] = []
	for s in store.shelves:
		if not s.holds_cold():
			dry.append(s)
	check(dry.size() >= 3, "a few shelves to work with (%d)" % dry.size())
	for s in dry:  # everything full of S1, so only the shelves set up below matter
		s.product_id = S1
		s.stock = Shelf.CAPACITY
		s.queue_redraw()
	var a := dry[0]
	var b := dry[1]

	# ---- defaults: like before
	check(Game.staff_stock(S0) and Game.fill_empty_shelves and Game.take_labels_off and Game.reorder_at == 0, "by default staff stock everything, fill empty shelves, take labels off, and the manager orders when a box fits")

	# ---- the Stock switch
	a.product_id = S0
	a.stock = 2
	Game.set_staff_stock(S0, false)
	check(not store.reorder_list().has(S0), "Stock off: the manager won't order it, even almost gone")
	check(store.best_shelf_for(S0, a.position, null) == null, "and stockers have no shelf for it")
	store.drop_box(store.delivery_cells[0], S0, 8)
	Game.hire("stocker")
	await _frames(2)
	var stocker: Staff = store.staff[0]
	await _physics(900)
	check(a.stock == 2 and store.boxes.values().any(func(x): return x.product_id == S0), "a stocker leaves its box alone (shelf still at %d)" % a.stock)
	Game.set_staff_stock(S0, true)
	var stocked := false
	for i in 2400:
		await get_tree().physics_frame
		if a.stock > 2:
			stocked = true
			break
	check(stocked, "Stock on again: they stock it (%d)" % a.stock)
	for x: StockBox in store.boxes.values():
		store.remove_box(x)
	await _idle(stocker)

	# ---- stockers fill empty shelves (or not)
	b.product_id = ""
	b.stock = 0
	b.queue_redraw()
	check(store.reorder_list().has(S2) or not Game.is_licensed(S2), "an empty shelf with no label: the manager orders something new for it (%s)" % store.reorder_list())
	Game.set_fill_empty_shelves(false)
	check(not store.reorder_list().has(S2), "with 'fill empty shelves' off, no ordering for it")
	store.drop_box(store.delivery_cells[0], S2, 8)
	await _physics(900)
	check(b.product_id == "" and b.stock == 0, "and a stocker doesn't put anything on it")
	Game.set_fill_empty_shelves(true)
	stocked = false
	for i in 2400:
		await get_tree().physics_frame
		if b.product_id == S2 and b.stock > 0:
			stocked = true
			break
	check(stocked, "on again: they fill it with %s" % Game.product_name(S2))
	for x: StockBox in store.boxes.values():
		store.remove_box(x)
	await _idle(stocker)

	# ---- stockers take labels off shelves of things you've stopped stocking
	b.product_id = S2
	b.stock = 0
	b.queue_redraw()
	Game.set_take_labels_off(false)
	Game.set_staff_stock(S2, false)
	await _physics(900)
	check(b.product_id == S2, "'take labels off' off: the empty %s shelf keeps its label" % Game.product_name(S2))
	Game.set_take_labels_off(true)
	var peeled := false
	var seen_job := false
	for i in 2400:
		await get_tree().physics_frame
		if stocker.job in [Staff.Job.TO_UNLABEL, Staff.Job.UNLABELING]:
			seen_job = true
		if b.product_id == "":
			peeled = true
			break
	check(peeled and seen_job, "on: a stocker walks over and takes the label off")
	check(a.product_id == S0, "but not off a shelf of something you still stock")
	b.product_id = S1
	b.stock = Shelf.CAPACITY
	Game.set_staff_stock(S2, true)

	# ---- when the manager orders
	a.product_id = S0
	a.stock = 7  # of 12, with boxes of 8: no room for a whole box yet
	var points: Array = Game.REORDER_POINTS
	var at := {}
	for i in points.size():
		Game.set_reorder_at(i)
		at[points[i].name] = store.reorder_list().has(S0)
	check(not at["When a box fits"] and at["3/4 full"] and not at["Half full"] and not at["Almost empty"], "7 of 12 left orders at '3/4 full' only: %s" % at)
	a.stock = 2
	Game.set_reorder_at(points.size() - 1)
	check(store.reorder_list().has(S0), "'Almost empty' still orders at 2 left")
	Game.set_reorder_at(0)

	# ---- the manager orders before anything else
	a.stock = Shelf.CAPACITY
	Game.hire("manager")
	await _frames(2)
	var boss: Staff = store.staff.filter(func(s): return s.role == "manager")[0]
	for i in 600:
		await get_tree().physics_frame
		if boss.job == Staff.Job.TO_CHECK and not boss.path.is_empty():
			break
	check(boss.job == Staff.Job.TO_CHECK, "the manager is out checking on things")
	a.stock = 1
	var dropped := -1
	for i in int(Staff.ORDER_CHECK_EVERY * 60.0 / Engine.time_scale) + 30:
		await get_tree().physics_frame
		if boss.job in [Staff.Job.TO_COMPUTER, Staff.Job.ORDERING]:
			dropped = i
			break
	check(dropped >= 0, "something runs low: they drop that and go order (after %d frames)" % dropped)
	var ordered := false
	for i in 3000:
		await get_tree().physics_frame
		if store.pending_deliveries.any(func(d): return d.id == S0) or store.boxes.values().any(func(x): return x.product_id == S0):
			ordered = true
			break
	check(ordered, "and order it")
	await _settle(store, boss)

	# ---- with the Handheld Scanner: scan a shelf instead of walking to the computer
	Game.buy_upgrade("scanner")
	a.stock = 1
	var went_to_computer := false
	var scanned := false
	ordered = false
	for i in 3000:
		await get_tree().physics_frame
		if boss.job in [Staff.Job.TO_COMPUTER, Staff.Job.ORDERING]:
			went_to_computer = true
		if boss.job == Staff.Job.SCAN_ORDERING and not scanned:
			scanned = true
			check(boss.scan_shelf == a, "the scanner: they scan the low shelf itself")
		if store.pending_deliveries.any(func(d): return d.id == S0) or store.boxes.values().any(func(x): return x.product_id == S0):
			ordered = true
			break
	check(scanned and ordered and not went_to_computer, "with the scanner they order by scanning a shelf, no trip to the computer")
	check(Staff.SCAN_ORDER_SECONDS < Staff.ORDER_SECONDS, "and it's quicker (%.1fs instead of %.1fs)" % [Staff.SCAN_ORDER_SECONDS, Staff.ORDER_SECONDS])

	# ---- on the computer
	hud.open_computer()
	hud.computer.show_tab(0)
	await _frames(3)
	var stock_button := _button_after(hud.computer.body, "Order box")
	check(stock_button != null and stock_button.text == "On", "Stock & Prices has a Stock switch per product: " + (stock_button.text if stock_button else "none"))
	stock_button.pressed.emit()
	await _frames(2)
	check(not Game.staff_stock(Game.unlocked_ids()[0]) and stock_button.text == "Off", "pressing it turns stocking off")
	stock_button.pressed.emit()
	hud.computer.show_tab(2)
	await _frames(3)
	var rule_buttons: Array = hud.computer.body.find_children("*", "Button", true, false).filter(func(x): return x.text in ["On", "Off"])
	check(rule_buttons.size() == 2, "the Staff app has the two stocker rules (%d)" % rule_buttons.size())
	rule_buttons[0].pressed.emit()
	await _frames(2)
	check(not Game.fill_empty_shelves and rule_buttons[0].text == "Off", "'Stockers fill empty shelves' switches off")
	rule_buttons[0].pressed.emit()
	var later: Array = hud.computer.body.find_children("*", "Button", true, false).filter(func(x): return x.text == ">")
	check(not later.is_empty(), "and the manager's reorder point has < and >")
	later[0].pressed.emit()
	await _frames(2)
	check(Game.reorder_at == 1, "> orders later: " + Game.REORDER_POINTS[Game.reorder_at].name)
	hud.computer.close()

	# ---- saved with the game (last: loading resets the game)
	main.queue_free()  # (the store goes, like going back to the menu to load)
	await _frames(2)
	Game.set_staff_stock(S1, false)
	Game.set_fill_empty_shelves(false)
	Game.set_take_labels_off(false)
	Game.set_reorder_at(3)
	var d := Game.to_dict()
	check(d.get("unstocked", []).has(S1) and d.get("staff_rules", {}).get("reorder_at") == 3, "the rules and Stock switches go in the save")
	Game.reset()
	Game.from_dict(d)
	check(not Game.staff_stock(S1) and not Game.fill_empty_shelves and not Game.take_labels_off and Game.reorder_at == 3, "and come back when it loads")
	d.erase("unstocked")
	d.erase("staff_rules")
	Game.reset()
	Game.from_dict(d)
	check(Game.staff_stock(S1) and Game.fill_empty_shelves and Game.take_labels_off and Game.reorder_at == 0, "older saves load with the defaults")

	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


## The first button after the one whose text is `after` (the Stock switch
## comes right after Order box).
func _button_after(from: Node, after: String) -> Button:
	var all := from.find_children("*", "Button", true, false)
	for i in all.size() - 1:
		if (all[i] as Button).text == after:
			return all[i + 1]
	return null


func _idle(s: Staff) -> void:
	for i in 1200:
		await get_tree().physics_frame
		if s.job == Staff.Job.IDLE and s.carry_count == 0:
			return


## Lets the deliveries arrive and get stocked, and the manager calm down.
func _settle(store: Store, boss: Staff) -> void:
	for i in 1200:
		await get_tree().physics_frame
		if store.pending_deliveries.is_empty() and boss.job in [Staff.Job.IDLE, Staff.Job.TO_CHECK, Staff.Job.CHECKING]:
			break
	for x: StockBox in store.boxes.values():
		store.remove_box(x)
	for s in store.shelves:
		if s.product_id != "":
			s.stock = Shelf.CAPACITY


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
