extends Node
# Checks extra registers, hiring staff (stocker + cashier), wages, and blood
# spills + the mop (zombie game only).
#   godot --headless --path . --fixed-fps 60 res://tests/staff_test.tscn

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	seed(4321)
	Engine.max_fps = 0
	Engine.time_scale = 4.0
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	var store: Store = Game.store
	var p: Player = Game.player
	var b: BuildMode = Game.build_mode
	var S0 := TestIds.starter(0)
	var S1 := TestIds.starter(1)
	Game.money = 5000.0

	# ---- extra registers
	check(store.registers.size() == 1 and store.registers[0] == store.register, "the store starts with one register")
	check(not store.register.is_sellable(), "the first register can't be sold")
	var spots := _floor_cells(store)
	var reg_spot := Store.NO_CELL
	for c: Vector2i in spots:
		if Iso.chebyshev(c, store.register.cell) > 3 and store.placement_error(c, "register") == "":
			reg_spot = c
			break
	check(reg_spot != Store.NO_CELL, "found a spot for a second register: %s" % reg_spot)
	b.enter()
	b.select_place("register")
	b._hover(Iso.cell_to_world(reg_spot))
	check(b.preview_line.size() == store.line_length, "build mode previews the new register's line")
	var money := Game.money
	b.tap(Iso.cell_to_world(reg_spot))
	check(store.registers.size() == 2, "bought a second register")
	check(is_equal_approx(Game.money, money - Game.FURNITURE.register.cost), "a register costs $%d" % int(Game.FURNITURE.register.cost))
	var r2: Register = store.registers[1]
	check(r2.line_cells.size() == store.line_length, "the new register has its own line")
	var overlap := false
	for c in r2.line_cells:
		overlap = overlap or c in store.register.line_cells
	check(not overlap, "the two lines don't overlap")
	check(store.placement_error(r2.line_cells[1], "shelf") == "Keep the checkout line clear", "the new line is protected")
	check(r2.is_sellable(), "extra registers can be sold")
	var added := 0
	for c: Vector2i in spots:
		if store.registers.size() >= Store.MAX_REGISTERS:
			break
		if store.placement_error(c, "register") == "":
			store.add_furniture("register", c)
			store.layout_changed()
			added += 1
	check(store.registers.size() == Store.MAX_REGISTERS, "can have %d registers" % Store.MAX_REGISTERS)
	var any_spot := Store.NO_CELL
	for c: Vector2i in spots:
		if store.placement_error(c, "shelf") == "":
			any_spot = c
			break
	check(store.placement_error(any_spot, "register").begins_with("You can have up to"), "but not more")
	b.select_tool(BuildMode.Tool.SELL)
	while store.registers.size() > 2:
		var extra: Register = store.registers[-1]
		b.tap(extra.position + Vector2(0, -10))
	check(store.registers.size() == 2, "sold the extra registers again")
	b.exit()

	# ---- customers use both lines
	_stock_all(store)
	Game.open_store()
	for i in 8:
		store.spawn_customer()
	var both := false
	for i in 1500:
		await get_tree().physics_frame
		if store.registers[0].line.size() > 0 and store.registers[1].line.size() > 0:
			both = true
			break
	check(both, "customers line up at both registers")

	# ---- cashiers
	check(Game.hire_problem("cashier") == "", "can hire a cashier")
	Game.hire("cashier")
	Game.hire("cashier")
	check(Game.staff_count("cashier") == 2, "hired two cashiers")
	check(Game.hire_problem("cashier") != "", "can't hire more cashiers than registers: " + Game.hire_problem("cashier"))
	await _frames(2)
	var cashiers := store.staff.filter(func(s): return s.role == "cashier")
	check(cashiers.size() == 2, "two cashiers came to work")
	var at_post := false
	for i in 1200:
		await get_tree().physics_frame
		if cashiers.all(func(s): return s.is_at_post()):
			at_post = true
			break
	check(at_post, "both cashiers got to their registers")
	check(cashiers[0].register != cashiers[1].register, "each cashier has their own register")
	check(store.registers.all(func(r): return r.is_staffed()), "both registers are staffed")
	var post_ok := true
	for s in cashiers:
		post_ok = post_ok and not store.is_line_spot(s.post) and Iso.chebyshev(s.post, s.register.cell) == 1
	check(post_ok, "cashiers stand next to their register, out of the line")
	var served_before: int = Game.stats.customers
	for i in 30:
		if store.customers.size() < 8:
			store.spawn_customer()
		for j in 60:
			await get_tree().physics_frame
	check(Game.stats.customers > served_before + 3, "cashiers check customers out on their own (%d served)" % (Game.stats.customers - served_before))
	check(store.register.get_prompt(p).begins_with("Take over the register from "), "the register says who's running it (you can take over): " + store.register.get_prompt(p))

	# ---- stocker
	Game.hire("stocker")
	await _frames(2)
	var stocker: Staff = store.staff.filter(func(s): return s.role == "stocker")[0]
	for s in store.shelves:
		s.stock = 0
		s.product_id = ""
		s.queue_redraw()
	for box: StockBox in store.boxes.values():
		store.remove_box(box)
	store.place_box(S0)
	store.place_box(S1)
	var boxed := 0
	for box: StockBox in store.boxes.values():
		boxed += box.count
	for i in 2400:
		await get_tree().physics_frame
		if store.boxes.is_empty() and stocker.carry_count == 0:
			break
	var stocked := 0
	for s in store.shelves:
		stocked += s.stock
	check(store.boxes.is_empty(), "the stocker took the boxes")
	# customers may have bought some already
	check(stocked + Game.stats.items_sold > 0 and store.shelves_with(S0).size() > 0 or store.shelves.any(func(s): return s.product_id == S0), "the stocker put %s on a shelf" % S0)
	check(store.shelves.any(func(s): return s.product_id == S1), "the stocker put %s on a shelf" % S1)
	var cold := TestIds.cold()
	Game.licensed[cold] = true
	var has_fridge := store.shelves.any(func(s): return s.holds_cold())
	store.place_box(cold)
	for i in 600:
		await get_tree().physics_frame
	if not has_fridge:
		check(store.boxes.values().any(func(bx): return bx.product_id == cold), "with no %s, the stocker leaves cold boxes alone" % Game.FURNITURE.fridge.name.to_lower())

	# ---- wages
	var wages := Game.daily_wages()
	var expected: float = Game.STAFF.cashier.wage * 2 + Game.STAFF.stocker.wage
	check(is_equal_approx(wages, expected), "daily wages add up ($%d)" % int(wages))
	var summary := {}
	Game.day_ended.connect(func(s): summary.merge(s), CONNECT_ONE_SHOT)  # lambdas can't reassign locals
	money = Game.money
	Game.end_day()
	check(is_equal_approx(Game.money, money - wages), "wages are paid at the end of the day")
	check(is_equal_approx(summary.get("wages", -1.0), wages), "the day summary shows the wages")

	# ---- firing
	var leaving: Staff = cashiers[0]
	var leaving_reg: Register = leaving.register
	Game.fire(leaving.id)
	await _frames(2)
	check(not is_instance_valid(leaving) or leaving.is_queued_for_deletion(), "a fired cashier leaves")
	check(not is_instance_valid(leaving_reg.cashier), "their register is free again")
	check(Game.staff_count("cashier") == 1, "one cashier left")

	# ---- spills and the mop (zombie game)
	if Brand.SPILLS:
		var bucket: MopBucket = store.mop_bucket
		check(bucket != null, "there's a mop bucket")
		var spill_cell := Store.NO_CELL
		for c: Vector2i in spots:
			if store.is_walkable(c) and not store.boxes.has(c) and not store.is_line_spot(c) and c != store.door_cell:
				spill_cell = c
				break
		for old: Spill in store.spills.values():
			store.remove_spill(old)  # start clean (shoppers drip during the test)
		var traffic := store.traffic_multiplier()
		var pull := Game.rival_pull([], {})
		store.add_spill(spill_cell)
		check(store.spills.has(spill_cell), "a spill appears on the floor")
		check(is_equal_approx(store.traffic_multiplier(), traffic) and is_equal_approx(Game.rival_pull([], {}), pull),
			"a puddle or two doesn't scare anyone off")
		var extra: Array[Vector2i] = []
		for c: Vector2i in spots:
			if c != spill_cell and store.is_walkable(c) and not store.spills.has(c) and not store.boxes.has(c) \
					and not store.is_line_spot(c) and c != store.door_cell and extra.size() < 4:
				store.add_spill(c)
				extra.append(c)
		check(is_equal_approx(store.mess_multiplier(), 1.0), "fresh blood doesn't put anyone off yet (%d wet puddles)" % store.spills.size())
		var sp1: Spill = store.spills[spill_cell]
		Game.open_store()
		var wet_age := sp1.age
		await _seconds(0.5)
		check(sp1.age > wet_age and not sp1.is_settled(), "puddles dry out while you're open (%.1fs of %.0fs)" % [sp1.age, Store.spill_settle_seconds()])
		for s2: Spill in store.spills.values():
			s2.age = Store.spill_settle_seconds()  # an hour later...
		check(sp1.is_settled() and store.settled_spills() == store.spills.size(), "after an hour on the floor they've dried")
		var few := store.mess_multiplier()
		check(few < 1.0 and few >= 1.0 - Store.SPILL_PENALTY * 3.0 - 0.001, "more puddles keep a few shoppers away (%d puddles: -%d%%)" % [store.spills.size(), roundi((1.0 - few) * 100.0)])
		for c: Vector2i in spots:
			if store.spills.size() >= Store.MAX_SPILLS:
				break
			if store.is_walkable(c) and not store.spills.has(c) and not store.boxes.has(c) and not store.is_line_spot(c) and c != store.door_cell:
				store.add_spill(c, -1, false, Store.spill_settle_seconds())
				extra.append(c)
		check(store.mess_multiplier() >= Store.MIN_SPILL_TRAFFIC - 0.001 and Game.rival_pull([], {}) <= pull + 0.081,
			"even a floor full of blood (%d puddles) keeps at most %d%% away: -%d%%" % [store.spills.size(), roundi((1.0 - Store.MIN_SPILL_TRAFFIC) * 100.0), roundi((1.0 - store.mess_multiplier()) * 100.0)])
		for c in extra:
			if store.spills.has(c):
				store.remove_spill(store.spills[c])
		var sp: Spill = store.spills[spill_cell]
		check(not sp.can_interact(p), "you need the mop to clean it")
		p.carry_product = ""
		p.carry_count = 0
		check(bucket.can_interact(p), "you can grab the mop")
		bucket.interact(p)
		check(p.holding_mop, "holding the mop")
		var a_box: StockBox = null
		store.place_box(S0)
		for bx: StockBox in store.boxes.values():
			a_box = bx
		check(a_box != null and not a_box.can_interact(p), "can't pick up boxes while holding the mop")
		check(sp.can_interact(p), "the mop can clean the spill")
		var cleaned: int = Game.stats.cleaned
		sp.interact(p)
		await _frames(2)
		check(not store.spills.has(spill_cell) and Game.stats.cleaned == cleaned + 1, "mopped it up")
		bucket.interact(p)
		check(not p.holding_mop, "put the mop back")
		var leaky := 0
		for i in 40:
			var c := store.spawn_customer()
			if c.leaky:
				leaky += 1
		check(leaky > 4 and leaky < 30, "some shoppers drip blood (%d of 40)" % leaky)
	else:
		check(store.mop_bucket == null, "no mop bucket in this game")
		var before := store.spills.size()
		store.add_spill(store.player.current_cell())
		check(store.spills.size() == before, "no spills in this game")
		var leaky := false
		for i in 20:
			leaky = leaky or store.spawn_customer().leaky
		check(not leaky, "shoppers don't drip in this game")

	# ---- shoppers stand in front of shelves, and shelves fade when someone's behind them
	for c in store.customers.duplicate():
		store.customer_left(c)
		c.queue_free()
	await _frames(2)
	var shelf: Shelf = null
	for sh in store.shelves:
		var f := sh.cell + sh.facing_dir()
		if store.is_walkable(f) and store.reachable.has(f) and store.is_walkable(sh.cell - sh.facing_dir()):
			shelf = sh
			break
	check(shelf != null, "(a shelf with room in front and behind)")
	if shelf:
		var front := shelf.cell + shelf.facing_dir()
		var stand := store.shelf_stand_cell(shelf, shelf.cell - shelf.facing_dir() * 3)
		var out := stand - shelf.cell
		check(Iso.chebyshev(stand, front) <= 1 and out.x * shelf.facing_dir().x + out.y * shelf.facing_dir().y == 1,
			"shoppers take things from the front of a shelf, even coming from behind it (%s, front %s)" % [stand, front])
		var who := store.spawn_customer()
		await _frames(2)
		who.state = Customer.State.IN_LINE  # (stand still)
		who.path.clear()
		who.position = Iso.cell_to_world(Vector2i(shelf.cell.x - 1, shelf.cell.y - 1))
		who.modulate.a = 1.0
		p.position = Iso.cell_to_world(store.door_cell)
		await _frames(3)
		check(shelf.see_through and shelf.modulate.a < 0.9, "a shopper behind a shelf: the shelf fades so you can see them (%.2f)" % shelf.modulate.a)
		who.position = Iso.cell_to_world(front)
		await _frames(3)
		var others := store.staff.filter(func(st): return Store._hides(shelf.position, st.position)).size() \
			+ store.customers.filter(func(c): return c != who and Store._hides(shelf.position, c.position)).size()
		check(shelf.see_through == (others > 0) and (others > 0 or is_equal_approx(shelf.modulate.a, 1.0)),
			"and comes back once they've moved on (%d others behind it)" % others)
		store.customer_left(who)
		who.queue_free()

	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


func _floor_cells(store: Store) -> Array:
	var cells: Array = []
	for y in range(store.height - 2, 1, -1):
		for x in range(1, store.width - 1):
			cells.append(Vector2i(x, y))
	return cells


func _stock_all(store: Store) -> void:
	var dry := TestIds.starters()
	var i := 0
	for s in store.shelves:
		if not s.holds_cold():
			s.product_id = dry[i % dry.size()]
			s.stock = Shelf.CAPACITY
			s.queue_redraw()
			i += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(t: float) -> void:
	await get_tree().create_timer(t).timeout
