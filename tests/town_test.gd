extends Node
# Checks the v0.8 features: the town, shoppers walking in from it, kinds of
# shoppers, the rival store (prices, checking them, losing shoppers, buying
# it out), buying the lots next door, the movable delivery zone, storage
# racks, self-checkouts, delivery upgrades, staff levels and the janitor.
#   godot --headless --path . --fixed-fps 60 res://tests/town_test.tscn

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	seed(808)
	Engine.max_fps = 0
	Engine.time_scale = 4.0
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	var store: Store = Game.store
	var p: Player = Game.player
	var b: BuildMode = Game.build_mode
	var town: Town = store.town
	Game.money = 20000.0

	# ---- the town
	check(town != null, "there's a town outside")
	check(store.astar.region.size.x > store.width and store.astar.region.size.y > store.height, "the town is bigger than the store")
	var all_spawns_reach := town.spawns.all(func(c): return store.reachable.has(c))
	check(all_spawns_reach, "you can walk from the door to every edge of town")
	check(store.reachable.has(town.rival_door), "you can walk to %s" % Brand.RIVAL.name)
	check(not store.floor_cells.has(Vector2i(store.door_cell.x, store.door_cell.y + 1)), "outside isn't store floor")
	var c0 := Vector2i(store.door_cell.x, store.door_cell.y + 2)
	check(store.placement_error(c0, "shelf") != "", "you can't build outside")

	# ---- shoppers walk in from town, shop, pay and walk off
	_stock_all(store)
	Game.open_store()
	store.spawn_timer = 9999.0  # only the shoppers we send
	var kind: Dictionary = Brand.SHOPPERS.zombie
	var list: Array[Dictionary] = [{"id": TestIds.starter(0), "qty": 1}]
	var c := store.spawn_customer(kind, list)
	check(c.current_cell() in town.spawns, "a shopper appears at the edge of town")
	var got_in := false
	for i in 3000:
		await get_tree().physics_frame
		if store.floor_cells.has(c.current_cell()) and c.current_cell() != store.door_cell:
			got_in = true
			break
	check(got_in, "and walks in through the door")
	var paid := false
	var served: int = Game.stats.customers
	for i in 4000:
		await get_tree().physics_frame
		var r := store.register
		if r.front_customer():
			r.checkout()
		if Game.stats.customers > served:
			paid = true
			break
	check(paid, "they shop and pay")
	for i in 600:
		await get_tree().physics_frame
		if not c in store.customers:
			break
	check(not c in store.customers, "once out the door they don't count as in the store")
	check(is_instance_valid(c) and c.state == Customer.State.WALKING_AWAY, "and they walk off into town")

	# ---- kinds of shoppers
	var speeds := {}
	for id in Brand.SHOPPERS:
		var k: Dictionary = Brand.SHOPPERS[id]
		var s := store.spawn_customer(k)
		speeds[id] = s.speed
		check(s.max_patience == Customer.PATIENCE * k.patience and s.tolerance == k.tolerance, "%s: patience x%.2f, price tolerance %.2f" % [k.name, k.patience, k.tolerance])
	check(speeds.crawler < speeds.zombie and speeds.runner > speeds.zombie, "crawlers are slow, runners are fast")
	var brute_list := store._make_shopping_list(Brand.SHOPPERS.brute)
	check(brute_list.size() >= mini(4, Game.unlocked_ids().size()), "brutes want a lot of things (%d)" % brute_list.size())
	Game.prices[TestIds.starter(0)] = Game.market_price(TestIds.starter(0)) * 1.3
	check(Game.buy_chance(TestIds.starter(0), Brand.SHOPPERS.rich.tolerance) == 1.0 and Game.buy_chance(TestIds.starter(0)) < 1.0, "rich zombies don't mind high prices")
	Game.match_all_prices()
	Game.level = 1
	var seen_kinds := {}
	for i in 300:
		seen_kinds[Game.pick_shopper_kind().name] = true
	check(not seen_kinds.has(Brand.SHOPPERS.rich.name) and seen_kinds.has(Brand.SHOPPERS.crawler.name), "new stores get crawlers but no rich zombies yet")
	Game.level = Game.level_for(Game.xp)
	for s in store.customers.duplicate():
		store.customer_left(s)
		s.queue_free()

	# ---- the rival
	var id0 := TestIds.starter(0)
	check(Game.rival_price(id0) > 0.0, "%s has prices (%s: $%.2f)" % [Brand.RIVAL.name, Game.product_name(id0), Game.rival_price(id0)])
	var any_list: Array[Dictionary] = [{"id": id0, "qty": 1}]
	Game.prices[id0] = Game.rival_price(id0) * 1.5
	var pull_high := Game.rival_pull(any_list, kind)
	Game.prices[id0] = Game.rival_price(id0) * 0.8
	var pull_low := Game.rival_pull(any_list, kind)
	check(pull_high > pull_low + 0.2, "beating the rival's prices wins shoppers back (%.2f -> %.2f)" % [pull_high, pull_low])
	check(Game.rival_pull(any_list, Brand.SHOPPERS.skeleton) > pull_low, "skeletons like %s more" % Brand.RIVAL.name)
	var was_prices: Dictionary = Game.prices.duplicate()
	for id: String in Game.prices:  # (everything, whatever a shopper's list is)
		Game.prices[id] = Game.rival_price(id) * 2.0
	var lost: int = Game.stats.lost
	for i in 40:
		store._new_shopper()
	check(Game.stats.lost > lost + 15, "overpriced: most shoppers go to the rival (%d of 40)" % (Game.stats.lost - lost))
	Game.prices = was_prices
	Game.prices[id0] = Game.rival_price(id0) * 2.0
	check(town.walkers.size() > 5, "you can see them walking there")
	Game.match_all_prices()
	for s in store.customers.duplicate():
		store.customer_left(s)
		s.queue_free()

	var shelf: RivalShelf = town.rival_shelves[0]
	Game.rival_seen.clear()
	check(shelf.can_interact(p) and shelf.get_prompt(p).contains("$"), "rival shelves show their price: " + shelf.get_prompt(p))
	shelf.interact(p)
	check(Game.rival_seen.has(shelf.product_id), "checking a rival shelf notes down the price")
	var opened := [false]
	Game.rival_requested.connect(func(): opened[0] = true, CONNECT_ONE_SHOT)
	town.rival_desk.interact(p)
	check(opened[0], "the counter opens the rival's price list")
	var hud: Node = main.get_node("HUD")
	await _frames(2)
	check(hud.rival_panel.visible, "the price list shows up")
	check(Game.rival_seen.size() >= Game.unlocked_ids().size(), "and notes down all its prices")
	hud.rival_panel.close()

	check(not Game.has_method("buy_out_rival") and not ("buy_button" in hud.rival_panel), "it's not for sale (from level %d it's war instead)" % GangWar.LEVEL)
	Game.level = 1
	Game.add_xp(5000.0)

	# ---- the lots next door
	var w0 := store.width
	check(Game.expansion_problem() == "", "can buy the first lot")
	var lot1: Array = town.lots[1].duplicate()
	var inside: Vector2i = lot1[0] + Vector2i(1, 5)
	check(not store.is_walkable(inside), "the lot is fenced off")
	b.enter()
	b.select_tool(BuildMode.Tool.EXPAND)
	check(b.next_lot().size() == lot1.size(), "build mode shows the lot for sale")
	var money := Game.money
	b.tap(Iso.cell_to_world(lot1[20]))
	await _frames(2)
	check(Game.expansions == 1 and store.width == w0 + Store.LOT_WIDTH, "bought it: the store is %d tiles wider" % (store.width - w0))
	check(is_equal_approx(Game.money, money - Brand.EXPANSIONS[0].cost), "it cost $%d" % int(Brand.EXPANSIONS[0].cost))
	check(store.floor_cells.has(Vector2i(w0 - 1, 5)) and store.is_walkable(Vector2i(w0 - 1, 5)), "the old wall came down")
	check(store.wall_cells.has(Vector2i(store.width - 1, 5)), "there's a new wall")
	check(store.placement_error(inside, "shelf") == "", "you can build on the new floor")
	check(not town.objects.has(Vector2i(lot1[0].x + 1, store.height - 1)), "the fence and sign are gone")
	b.exit()

	# ---- the delivery zone moves
	for box: StockBox in store.boxes.values():
		store.remove_box(box)
	store.place_box(id0)
	var box_before: StockBox = store.boxes.values()[0]
	var old_anchor := store.delivery_anchor()
	var new_anchor := Vector2i(store.width - 5, 3)
	check(store.delivery_zone_error(new_anchor) == "", "the delivery zone fits in the new space")
	check(store.delivery_zone_error(store.register.cell) != "", "but not on the register")
	b.enter()
	b.select_tool(BuildMode.Tool.MOVE)
	b.tap(Iso.cell_to_world(old_anchor))
	check(b.moving is DeliveryZone, "build mode picks up the delivery zone")
	b.tap(Iso.cell_to_world(new_anchor + b.zone_grab))
	b.exit()
	check(store.delivery_anchor() == new_anchor, "and moves it")
	check(store.boxes.get(box_before.cell) == box_before and box_before.cell in store.delivery_cells, "the box on it came along")
	check(store.placement_error(old_anchor, "shelf") == "", "the old spot is free to build on")
	store.pending_deliveries.clear()
	Game.order_box(id0)
	for i in 900:
		await get_tree().physics_frame
		if store.pending_deliveries.is_empty():
			break
	check(store.boxes.size() == 2 and store.boxes.keys().all(func(k): return k in store.delivery_cells), "deliveries arrive at the new spot")

	# ---- delivery upgrades
	check(Game.delivery_seconds() == Game.DELIVERY_SECONDS, "deliveries take %d seconds" % int(Game.DELIVERY_SECONDS))
	check(Game.upgrade_problem("delivery_van") != "", "the van needs the bike first: " + Game.upgrade_problem("delivery_van"))
	Game.buy_upgrade("delivery_bike")
	Game.buy_upgrade("delivery_van")
	check(Game.delivery_seconds() < 5.0, "with the van, deliveries take %.1f seconds" % Game.delivery_seconds())

	# ---- storage racks
	var rack_cell := _free_cell(store, Vector2i(3, 6))
	var rack: StorageRack = store.add_furniture("storage", rack_cell)
	store.layout_changed()
	p.position = Iso.cell_to_world(store.stand_cell_for(rack.cell, rack.cell))
	p.pick_up(id0, 6)
	check(rack.can_interact(p) and rack.get_prompt(p).begins_with("Store"), "you can put a box on a rack: " + rack.get_prompt(p))
	rack.interact(p)
	check(rack.boxes.size() == 1 and not p.is_carrying(), "the box is on the rack")
	check(rack.can_interact(p) and rack.get_prompt(p).begins_with("Take"), "and take it back: " + rack.get_prompt(p))
	rack.interact(p)
	check(rack.boxes.is_empty() and p.carry_product == id0, "got it back")
	p.drop_carry()

	# A stocker puts boxes nobody has room for on the rack, and stocks from it later.
	for s: Shelf in store.shelves:
		s.product_id = id0
		s.stock = Shelf.CAPACITY
		s.queue_redraw()
	for box: StockBox in store.boxes.values():
		store.remove_box(box)
	store.place_box(id0)
	store.place_box(id0)
	Game.hire("stocker")
	await _frames(2)
	var stocker: Staff = store.staff.filter(func(s): return s.role == "stocker")[0]
	for i in 3000:
		await get_tree().physics_frame
		if rack.boxes.size() == 2:
			break
	check(rack.boxes.size() == 2 and store.boxes.is_empty(), "the stocker tidies boxes onto the rack (%d on it)" % rack.boxes.size())
	var target: Shelf = store.shelves[0]
	target.stock = 2
	for i in 3000:
		await get_tree().physics_frame
		if target.stock == Shelf.CAPACITY:
			break
	check(target.stock == Shelf.CAPACITY and rack.boxes.size() < 2, "and stocks shelves from the rack")
	check(stocker.level >= 1 and Game.staff_entry(stocker.id).xp > 0.0, "the stocker earned XP (%d)" % int(Game.staff_entry(stocker.id).xp))
	var slow := stocker.speed
	Game.add_staff_xp(stocker.id, 500.0)
	check(stocker.level == Game.STAFF_LEVEL_XP.size() and stocker.speed > slow + 0.4, "staff level up and get faster (level %d, %.2fx)" % [stocker.level, stocker.speed])
	store.remove_furniture(rack)

	# ---- janitor
	Game.hire("janitor")
	await _frames(2)
	var janitor: Staff = store.staff.filter(func(s): return s.role == "janitor")[0]
	for sp: Spill in store.spills.values():
		store.remove_spill(sp)
	var spill_cell := _free_cell(store, Vector2i(6, 8))
	store.add_spill(spill_cell)
	var cleaned: int = Game.stats.cleaned
	for i in 2000:
		await get_tree().physics_frame
		if store.spills.is_empty():
			break
	check(store.spills.is_empty() and Game.stats.cleaned == cleaned + 1, "the janitor mops up the blood")
	check(Game.staff_entry(janitor.id).xp > 0.0, "and gets XP for it")

	# ---- self-checkout
	for r in store.registers.duplicate():
		if r != store.register:
			store.remove_furniture(r)
	var sc_cell := Store.NO_CELL
	for y in range(2, store.height - 2):
		for x in range(store.width - 6, store.width - 1):
			if store.placement_error(Vector2i(x, y), "selfcheckout") == "":
				sc_cell = Vector2i(x, y)
				break
		if sc_cell != Store.NO_CELL:
			break
	check(sc_cell != Store.NO_CELL, "found a spot for a self-checkout")
	var sc: SelfCheckout = store.add_furniture("selfcheckout", sc_cell)
	store.layout_changed()
	check(sc.line_cells.size() == store.line_length, "it has a line")
	check(Game.staff_limit("cashier") == 1, "cashiers don't count self-checkouts as registers")
	var shopper := store.spawn_customer(kind, [{"id": id0, "qty": 1}])  # the shelves are full of it
	shopper.position = Iso.cell_to_world(store.door_cell)
	shopper.state = Customer.State.ENTERING
	var used_self := false
	served = Game.stats.customers
	for i in 4000:
		await get_tree().physics_frame
		if is_instance_valid(shopper) and shopper.register == sc:
			used_self = true
		if sc.jammed:
			sc.interact(p)
		if Game.stats.customers > served:
			break
	check(used_self, "a shopper with a few items uses the self-checkout")
	check(Game.stats.customers > served, "and checks out without you")
	var big := store.spawn_customer(kind, [])
	for i in 6:
		big.basket.append({"id": id0, "price": 1.0})
	check(not sc.accepts(big), "but not with more than %d items" % SelfCheckout.ITEM_LIMIT)
	sc.jammed = true
	check(sc.can_interact(p) and sc.get_prompt(p).begins_with("Fix"), "a stuck self-checkout needs you")
	sc.interact(p)
	check(not sc.jammed, "and you can fix it")

	# ---- closed for the day (your gang smashed it up, in the gang war)
	var staff_before := town.rival_staff.size()
	check(staff_before >= 1, "%s has skeleton staff" % Brand.RIVAL.name)
	Game.war.rival_closed = true
	Game.war.rival_closed_changed.emit()
	await _frames(2)
	check(Game.rival_pull(any_list, kind) == 0.0, "closed for the day: nobody goes there")
	check(town.rival_staff.is_empty() and town.rival_shelves.all(func(s): return s.stock == 0), "its staff leave and the shelves are empty")
	check(town.rival_sign.textures[0] == Brand.RIVAL.textures.sign_closed, "the sign says CLOSED")
	Game.war.rival_closed = false
	Game.war.rival_closed_changed.emit()
	await _frames(2)
	check(not town.rival_staff.is_empty() and town.rival_shelves.any(func(s): return s.stock > 0), "open again: staff and stock are back")

	# ---- saving keeps all of it
	var saved := Game.to_dict()
	var sd := store.to_dict()
	check(int(saved.expansions) == 1 and saved.has("war"), "the save has the lot and the gang war")
	check(sd.fixtures.delivery.cell == [new_anchor.x, new_anchor.y], "the save has the delivery zone")
	var regs: Array = sd.fixtures.registers
	check(regs.any(func(r): return r.get("id") == "selfcheckout"), "the save has the self-checkout")
	check(Game.staff.all(func(s): return s.has("xp") and s.has("level")), "the save has staff levels")

	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


func _free_cell(store: Store, near: Vector2i) -> Vector2i:
	var cells: Array = store.floor_cells.keys()
	cells.sort_custom(func(a, b): return Vector2(a - near).length() < Vector2(b - near).length())
	for cell: Vector2i in cells:
		if store.placement_error(cell, "shelf") == "" and not store.spills.has(cell):
			return cell
	return Store.NO_CELL


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
