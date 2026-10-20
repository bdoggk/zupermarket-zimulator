extends Node
# Checks taking a register over from a cashier (and getting it back),
# shoppers recovering when they're stuck somewhere, jammed self-checkouts
# (they reboot, and the manager fixes them) and the skeletons in town.
#   godot --headless --path . --fixed-fps 60 res://tests/takeover_test.tscn

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	seed(4242)
	Engine.max_fps = 0
	Engine.time_scale = 4.0
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	var store: Store = Game.store
	var p: Player = Game.player
	var reg := store.register
	Game.money = 5000.0
	Game.tutorial_hidden = true

	# ---- skeletons around town
	var skeleton_locals := 0
	for n in store.world.get_children():
		if n is Wanderer and n.has_meta("local") and n.sprite.texture in Brand.SHOPPERS.skeleton.looks:
			skeleton_locals += 1
	check(skeleton_locals == store.town.LOCALS, "%d skeletons hang around town" % skeleton_locals)
	check(Brand.SHOPPERS.skeleton.level == 1, "skeleton shoppers come from day one")
	var skeletons := 0
	for i in 200:
		if Game.pick_shopper_kind().name == Brand.SHOPPERS.skeleton.name:
			skeletons += 1
	check(skeletons > 20, "plenty of shoppers are skeletons (%d of 200)" % skeletons)

	# ---- taking over a register
	Game.hire("cashier")
	await _frames(2)
	var cashier: Staff = store.staff[0]
	for i in 1500:
		await get_tree().physics_frame
		if cashier.is_at_post():
			break
	check(cashier.is_at_post() and reg.is_staffed(), "the cashier is running the register")
	var stand := Store.NO_CELL
	for d: Vector2i in Store.SIDES + Store.CORNERS:
		var c := reg.cell + d
		if store.is_walkable(c) and c != cashier.post and not store.is_line_spot(c):
			stand = c
			break
	var S0 := TestIds.starter(0)
	for s in store.shelves:
		if not s.holds_cold():
			s.product_id = S0
			s.stock = Shelf.CAPACITY
	Game.open_store()
	store.spawn_timer = 9999.0
	var c0 := store.spawn_customer(Brand.SHOPPERS.zombie, [{"id": S0, "qty": 1}])
	for i in 4000:
		await get_tree().physics_frame
		if reg.line.has(c0):
			break
	p.position = Iso.cell_to_world(stand)
	await _frames(2)
	check(reg.can_interact(p) and reg.get_prompt(p).begins_with("Take over"), "you can take over: " + reg.get_prompt(p))
	reg.interact(p)
	await _frames(2)
	check(reg.taken_over and not reg.is_staffed(), "you took over the register")
	check(cashier.on_break() or cashier.register != reg, "the cashier steps aside: " + cashier.status_text())
	var ready := false
	for i in 4000:
		await get_tree().physics_frame
		if reg.front_customer():
			ready = true
			break
	check(ready, "a shopper lines up")
	check(reg.can_interact(p) and reg.get_prompt(p).begins_with("Scan"), "and you scan them yourself: " + reg.get_prompt(p))
	var served: int = Game.stats.customers
	reg.interact(p)
	check(Game.stats.customers == served + 1, "rang them up")
	check(not is_instance_valid(reg.cashier) or not reg.cashier.is_scanning(), "the cashier didn't jump back in")
	p.position = Iso.cell_to_world(store.stand_cell_for(store.delivery_cells[0], store.delivery_cells[0]))  # across the store
	var back := false
	for i in 2000:
		await get_tree().physics_frame
		if not reg.taken_over and cashier.is_at_post() and cashier.register == reg:
			back = true
			break
	check(back, "when you walk away, the cashier comes back to it")

	# Standing right by it but not ringing anyone up: they come back too.
	p.position = Iso.cell_to_world(stand)
	await _frames(2)
	reg.interact(p)  # take over again
	await _frames(2)
	check(reg.taken_over and cashier.on_break(), "took it over again, standing right next to it")
	for i in int(1.5 * 60.0 / Engine.time_scale):
		await get_tree().physics_frame
	check(reg.taken_over, "a moment later it's still yours")
	back = false
	for i in 1200:
		await get_tree().physics_frame
		if not reg.taken_over and cashier.register == reg and cashier.is_at_post():
			back = true
			break
	check(back and p.current_cell() == stand, "stop ringing people up for a few seconds, and the cashier comes back even with you standing there")

	# E hands it straight back when there's nobody to scan.
	reg.interact(p)
	await _frames(2)
	check(reg.taken_over and reg.can_interact(p) and reg.get_prompt(p) == "Hand the register back to %s" % cashier.staff_name, "with nobody to scan, E offers to hand it back: " + reg.get_prompt(p))
	check(cashier.status_text().contains("press E"), "and the Staff app says how: " + cashier.status_text())
	reg.interact(p)
	check(not reg.taken_over, "E: it's theirs again")
	back = false
	for i in 300:
		await get_tree().physics_frame
		if cashier.register == reg and cashier.is_at_post():
			back = true
			break
	check(back, "and they're straight back at it")

	# ---- a stuck shopper finds a new plan
	var c1 := store.spawn_customer(Brand.SHOPPERS.zombie, [{"id": S0, "qty": 1}])
	c1.position = Iso.cell_to_world(store.door_cell + Vector2i(0, -2))
	c1.state = Customer.State.IN_LINE  # "in line", but nowhere near the line
	c1.register = reg
	c1.line_index = reg.join_line(c1)
	c1.path.clear()
	var moved := false
	for i in 900:
		await get_tree().physics_frame
		if c1.state != Customer.State.IN_LINE or c1.current_cell() == reg.spot(c1.line_index):
			moved = true
			break
	check(moved, "a shopper standing 'in line' away from the line gets moving again (%s)" % Customer.State.keys()[c1.state])

	# ---- jammed self-checkouts
	var sc_cell := Store.NO_CELL
	for y in range(2, store.height - 2):
		for x in range(2, store.width - 2):
			if sc_cell == Store.NO_CELL and store.placement_error(Vector2i(x, y), "selfcheckout") == "":
				sc_cell = Vector2i(x, y)
	var sc: SelfCheckout = store.add_furniture("selfcheckout", sc_cell)
	store.layout_changed()
	sc.jammed = true
	var rebooted := false
	for i in int(SelfCheckout.JAM_RESETS_AFTER * 60.0 / Engine.time_scale) + 200:
		await get_tree().physics_frame
		if not sc.jammed:
			rebooted = true
			break
	check(rebooted, "a jammed self-checkout nobody fixes reboots itself")
	Game.hire("manager")
	await _frames(2)
	var boss: Staff = store.staff.filter(func(s): return s.role == "manager")[0]
	sc.jammed = true
	sc._jam_time = 0.0
	var fixed_by_boss := false
	for i in int(SelfCheckout.JAM_RESETS_AFTER * 60.0 / Engine.time_scale) - 60:
		await get_tree().physics_frame
		if not sc.jammed:
			fixed_by_boss = boss.job in [Staff.Job.CHECKING, Staff.Job.IDLE] and sc._jam_time < SelfCheckout.JAM_RESETS_AFTER
			break
	check(fixed_by_boss, "the general manager fixes jammed self-checkouts")

	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
