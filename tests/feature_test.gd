extends Node
# Checks the market, unlocks, scanner and build mode rules.
# Run: godot --headless --path . res://tests/feature_test.tscn

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	seed(1234)
	Engine.max_fps = 0
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var store: Store = Game.store
	var p: Player = Game.player
	var b: BuildMode = Game.build_mode
	var S0 := TestIds.starter(0)
	var S1 := TestIds.starter(1)
	var L1 := TestIds.at_level(1, false)  # licensed at level 1
	var COLD := TestIds.cold()  # needs a fridge, unlocks at level 2
	var L4 := TestIds.at_level(4)
	var cold_level: int = Game.PRODUCTS[COLD].level

	# ---- morning: closed until the sign is flipped
	check(not Game.opened and not Game.is_open, "a new game starts with the store closed")
	var m0 := Game.minute
	for i in 60:
		await get_tree().process_frame
	check(Game.minute == m0, "the clock doesn't run before opening")
	check(store.customers.is_empty(), "no customers before opening")
	check(store.sign.can_interact(p), "the sign can be flipped")
	check(store.sign.get_prompt(p).begins_with("Open the store"), "sign prompt: " + store.sign.get_prompt(p))
	store.sign.interact(p)
	check(Game.opened and Game.is_open, "flipping the sign opens the store")
	check(not store.sign.can_interact(p), "the sign can't be flipped twice")
	for i in 60:
		await get_tree().process_frame
	check(Game.minute > m0, "the clock runs after opening")

	# ---- market
	var start_cost := Game.box_cost(S0)
	var normal_cost: float = Game.PRODUCTS[S0].unit_cost * Game.PRODUCTS[S0].box_size
	check(is_equal_approx(start_cost, normal_cost), "a box of %s costs $%.2f at a normal market (got %s)" % [S0, normal_cost, start_cost])
	for i in 60:
		Game.update_market(i % 3 == 0)
	var in_range := true
	var moved := false
	for id in Game.PRODUCTS:
		var f: float = Game.market.factor[id]
		in_range = in_range and f >= Market.MIN_FACTOR and f <= Market.MAX_FACTOR
		moved = moved or not is_equal_approx(f, 1.0)
	check(in_range, "market factors stay within limits after 60 updates")
	check(moved, "market prices actually move")
	Game.match_market(S1)
	check(Game.buy_chance(S1) == 1.0, "customers always buy at market price")
	Game.prices[S1] = Game.market_price(S1) * 2.0
	check(Game.buy_chance(S1) < 0.1, "customers rarely buy at double the market price")
	Game.match_market(S1)
	var ok_box := true
	for id in Game.PRODUCTS:
		var expected: float = Game.PRODUCTS[id].unit_cost * Game.PRODUCTS[id].box_size * Game.market.factor[id]
		ok_box = ok_box and absf(Game.box_cost(id) - expected) < 0.03
	check(ok_box, "box costs follow the market")

	# ---- unlocks
	Game.money = 5000.0
	check(Game.unlocked_ids() == TestIds.starters(), "start with %s" % [TestIds.starters()])
	check(Game.buy_license(L1), "can license %s at level 1" % L1)
	check(not Game.buy_license(COLD), "can't license %s at level 1" % COLD)
	Game.add_xp(400.0)
	check(Game.level == 3, "400 XP -> store level 3 (got %d)" % Game.level)
	check(cold_level <= 3 and Game.buy_license(COLD), "can license %s at level 3" % COLD)
	check(not Game.buy_license(L4), "can't license %s (level 4) at level 3" % L4)
	check(Game.is_licensed(COLD) and COLD in Game.unlocked_ids(), "%s is now sold" % COLD)
	var milk_lists := 0
	var only_licensed := true
	var asks := 0
	for i in 300:
		var unsold := 0
		for want in store._make_shopping_list():
			if want.id == COLD:
				milk_lists += 1
			if not Game.is_licensed(want.id):
				unsold += 1
				only_licensed = only_licensed and want.id in Game.licensable_ids()
		only_licensed = only_licensed and unsold <= 1
		asks += unsold
	check(only_licensed and asks == 0, "shoppers only want products you've licensed (%d asks for anything else in 300 lists)" % asks)
	check(milk_lists > 0, "customers start wanting newly licensed products")

	# ---- scanner
	var shelf: Shelf = store.shelves[0]
	shelf.product_id = S0
	shelf.stock = 3
	check(not shelf.can_scan(p), "can't scan without the scanner")
	check(Game.buy_upgrade("scanner"), "bought the scanner")
	check(not Game.buy_upgrade("scanner"), "can't buy the scanner twice")
	check(shelf.can_scan(p), "can scan a stocked shelf")
	var pending := store.pending_deliveries.size()
	var money := Game.money
	shelf.scan(p)
	check(store.pending_deliveries.size() == pending + 1, "scanning orders a box")
	check(is_equal_approx(Game.money, money - Game.box_cost(S0)), "scanning charges the box cost")
	var empty: Shelf = store.shelves[1]
	check(not empty.can_scan(p), "can't scan a shelf that never had anything")

	# ---- build mode: rules
	b.enter()
	check(get_tree().paused, "build mode pauses the game")
	check(store.placement_error(store.door_cell, "shelf") != "", "can't build on the door")
	check(store.placement_error(store.line_cells[0], "shelf") != "", "can't build in the checkout line")
	check(store.placement_error(store.delivery_cells[0], "shelf") != "", "can't build on the delivery zone")
	check(store.placement_error(Vector2i(0, 5), "shelf") != "", "can't build on a wall")
	check(store.placement_error(shelf.cell, "shelf") != "", "can't build on another shelf")
	check(store.placement_error(p.current_cell(), "shelf") != "", "can't build where the player stands")

	# ---- build mode: place a shelf and a fridge through the tap handler
	var spot := Vector2i(10, 5)
	check(store.placement_error(spot, "shelf") == "", "open floor is buildable")
	b.select_place("shelf")
	money = Game.money
	b.tap(Iso.cell_to_world(spot), true)
	check(not store.objects.has(spot), "touch: first tap only previews")
	b.tap(Iso.cell_to_world(spot), true)
	check(store.objects.get(spot) is Shelf, "touch: second tap places the shelf")
	check(is_equal_approx(Game.money, money - 60.0), "a shelf costs $60")
	var fridge_spot := Vector2i(12, 5)
	b.select_place("fridge")
	b.tap(Iso.cell_to_world(fridge_spot))
	var fridge: Shelf = store.objects.get(fridge_spot)
	check(fridge is Fridge, "mouse: one click places a fridge")
	b.select_place("plant")
	b.tap(Iso.cell_to_world(Vector2i(13, 3)))
	check(store.plant_count() == 3, "placed a plant (3 total)")
	check(store.traffic_multiplier() > 1.2, "plants and levels bring more customers")

	# ---- cold vs dry
	p.pick_up(S0, 8)
	check(not fridge.can_interact(p), "fridge won't take %s" % S0)
	check(store.objects[spot].can_interact(p), "shelf takes %s" % S0)
	p.pick_up(COLD, 6)
	check(fridge.can_interact(p), "fridge takes %s" % COLD)
	check(not store.objects[spot].can_interact(p), "shelf won't take %s" % COLD)
	check(fridge.get_prompt(p).begins_with("Stock " + Game.product_name(COLD)), "fridge prompt: " + fridge.get_prompt(p))
	fridge.interact(p)
	check(fridge.stock == 6 and fridge.product_id == COLD, "stocked the fridge with %s" % COLD)
	check(not p.is_carrying(), "box used up")

	# ---- blocking paths: wall off the back of the store
	var blocked := 0
	for x in range(1, 15):
		var c := Vector2i(x, 3)
		if store.placement_error(c, "shelf") == "":
			store.add_furniture("shelf", c)
			store.layout_changed()
		else:
			blocked += 1
	var reach := store._flood()
	var deliveries_ok := true
	for c in store.delivery_cells:
		deliveries_ok = deliveries_ok and reach.has(c)
	check(blocked > 0, "some spots refused to keep paths open (%d)" % blocked)
	check(deliveries_ok, "delivery zone is still reachable")
	check(reach.has(store.stand_cell_for(store.computer.cell, store.door_cell)), "computer is still reachable")
	var accessible := true
	for s in store.shelves:
		accessible = accessible and store.stand_cell_for(s.cell, store.door_cell) != Store.NO_CELL
	check(accessible, "every shelf still has a reachable spot next to it")

	# ---- move keeps stock
	var target := Vector2i(11, 7)
	b.select_tool(BuildMode.Tool.MOVE)
	b.tap(fridge.position + Vector2(0, -20))
	check(b.moving == fridge, "picked up the fridge")
	b.tap(Iso.cell_to_world(target))
	check(store.objects.get(target) == fridge and not store.objects.has(fridge_spot), "moved the fridge")
	check(fridge.stock == 6, "fridge kept its milk")
	check(not store.astar.is_point_solid(fridge_spot) and store.astar.is_point_solid(target), "pathfinding grid updated")

	# ---- sell boxes up leftover stock
	b.select_tool(BuildMode.Tool.SELL)
	money = Game.money
	b.tap(fridge.position + Vector2(0, -20), true)
	check(b.selected == fridge and is_instance_valid(fridge), "touch: first tap selects for selling")
	b.tap(fridge.position + Vector2(0, -20), true)
	check(not store.objects.has(target), "second tap sells it")
	check(is_equal_approx(Game.money, money + 75.0), "selling refunds half ($75)")
	var box: StockBox = store.boxes.get(target)
	check(box != null and box.product_id == COLD and box.count == 6, "leftover %s was boxed up" % COLD)

	# ---- paint
	money = Game.money
	check(Game.buy_floor_style(2), "bought the wood floor")
	check(Game.buy_wall_color(2), "bought brick walls")
	check(not Game.buy_wall_color(2), "can't buy the color you already have")
	check(is_equal_approx(Game.money, money - 70.0), "paint cost $40 + $30")
	var sprite: Sprite2D = store.wall_cells[Vector2i(0, 0)][0]
	check(sprite.texture.resource_path.ends_with("wall_brick_tall.png"), "walls repainted")

	# ---- moving the computer, the sign and the register
	var free_spot := func(obj: Interactable, cells: Array) -> Vector2i:
		for c: Vector2i in cells:
			if c != obj.cell and store.placement_error(c, "", obj) == "":
				return c
		return Store.NO_CELL
	var spots: Array = []
	for y in range(store.height - 1, 0, -1):
		for x in range(1, store.width - 1):
			spots.append(Vector2i(x, y))
	b.select_tool(BuildMode.Tool.MOVE)
	var computer: Computer = store.computer
	var old_pc := computer.cell
	b.tap(computer.position + Vector2(0, -20))
	check(b.moving == computer, "Move tool picks up the computer")
	var pc_spot: Vector2i = free_spot.call(computer, spots)
	b.tap(Iso.cell_to_world(pc_spot))
	check(computer.cell == pc_spot and store.objects.get(pc_spot) == computer, "moved the computer to %s" % pc_spot)
	check(not store.objects.has(old_pc) and not store.astar.is_point_solid(old_pc), "the computer's old spot is free")
	check(store.stand_cell_for(computer.cell, store.door_cell) != Store.NO_CELL, "the computer can still be reached")

	var sign_spot: Vector2i = free_spot.call(store.sign, spots)
	b.tap(store.sign.position + Vector2(0, -20))
	b.tap(Iso.cell_to_world(sign_spot))
	check(store.sign.cell == sign_spot, "moved the OPEN sign")

	var reg: Register = store.register
	var old_line := store.line_cells.duplicate()
	var old_reg := reg.cell
	var reg_spot := Store.NO_CELL
	for c: Vector2i in spots:
		if c.distance_to(old_reg) > 3 and store.placement_error(c, "", reg) == "" and store.preview_line(c).size() == old_line.size():
			reg_spot = c
			break
	check(reg_spot != Store.NO_CELL, "found a new spot for the register: %s" % reg_spot)
	b.tap(reg.position + Vector2(0, -10))
	check(b.moving == reg, "Move tool picks up the register")
	check(b.preview_line.size() == old_line.size(), "build mode previews the checkout line")
	b._hover(Iso.cell_to_world(reg_spot + Vector2i(0, -1)))
	b._hover(Iso.cell_to_world(reg_spot))
	check(store.line_cells == old_line, "hovering around doesn't change the real line")
	b.tap(Iso.cell_to_world(reg_spot))
	check(reg.cell == reg_spot, "moved the register")
	check(store.line_cells.size() == old_line.size() and store.line_cells != old_line, "the checkout line moved too: %s" % [store.line_cells])
	var chained := Iso.chebyshev(store.line_cells[0], reg.cell) == 1 and absi(store.line_cells[0].x - reg.cell.x) + absi(store.line_cells[0].y - reg.cell.y) == 1
	for i in range(1, store.line_cells.size()):
		var d: Vector2i = store.line_cells[i] - store.line_cells[i - 1]
		chained = chained and absi(d.x) + absi(d.y) == 1
	check(chained, "the line starts next to the register and is one connected row")
	check(reg.line_cells == store.line_cells and reg.spots()[0] == store.line_cells[0], "customers will use the new line")
	check(store.placement_error(store.line_cells[1], "shelf") == "Keep the checkout line clear", "the new line is protected")
	var reopened := false
	for c in old_line:
		if not c in store.line_cells and store.placement_error(c, "shelf") != "Keep the checkout line clear":
			reopened = true
	check(reopened, "the old line spots can be built on again")

	b.select_tool(BuildMode.Tool.SELL)
	b.tap(reg.position + Vector2(0, -10))
	check(is_instance_valid(reg) and store.objects.get(reg.cell) == reg, "the register can't be sold")
	b.select_tool(BuildMode.Tool.MOVE)

	b.exit()
	check(not get_tree().paused, "leaving build mode unpauses")

	# ---- customers cope with layout changes
	for i in 5:
		store.spawn_customer()
	for i in 240:
		await get_tree().physics_frame
	b.enter()
	b.select_tool(BuildMode.Tool.SELL)
	for s in store.shelves.duplicate():
		if s.stock > 0:
			b.tap(s.position + Vector2(0, -20))
	b.exit()
	for i in 600:
		await get_tree().physics_frame
	check(true, "customers survived shelves vanishing mid-shop (no errors above)")

	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)
