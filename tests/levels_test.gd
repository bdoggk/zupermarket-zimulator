extends Node
# Store levels with no cap and the things that come with the higher ones:
# the XP table carries on past the last level that unlocks something (with a
# cash bonus each level), levels 7 to 14 each bring something new (products,
# shoppers, upgrades, decorations, more staff), decorations that pull in one
# kind of shopper (a cauldron for witches...), and what the new upgrades do.
# Build mode keeps decorations in their own row, locked until their level.
#   godot --headless --path . --fixed-fps 60 res://tests/levels_test.tscn

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	seed(7)
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	var store: Store = Game.store
	var hud: Node = main.get_node("HUD")
	Game.tutorial_hidden = true
	Game.money = 50000.0

	# ---- the XP table never ends
	var table: Array = Game.LEVEL_XP
	var same := true
	for i in table.size():
		same = same and is_equal_approx(Game.xp_for_level(i + 1), float(table[i]))
	check(same, "levels 1 to %d need the XP in the table" % table.size())
	var gap := Game.xp_for_level(table.size() + 1) - Game.xp_for_level(table.size())
	var gap2 := Game.xp_for_level(table.size() + 2) - Game.xp_for_level(table.size() + 1)
	check(gap > float(table[-1] - table[-2]) and is_equal_approx(gap2 - gap, Game.LEVEL_XP_STEP), "past it, each level takes %d XP more than the one before (%d, %d...)" % [int(Game.LEVEL_XP_STEP), int(gap), int(gap2)])
	check(Game.level_for(Game.xp_for_level(40)) == 40 and Game.level_for(Game.xp_for_level(40) - 1.0) == 39, "level 40 is there to reach")
	Game.xp = Game.xp_for_level(30) + 10.0
	Game.level = Game.level_for(Game.xp)
	check(Game.next_level_xp() > Game.xp and Game.level_progress() > 0.0 and Game.level_progress() < 1.0, "at level 30 there's still a next level (%d XP)" % int(Game.next_level_xp()))
	Game.xp = 0.0
	Game.level = 1

	# ---- every level up to the last unlock brings something new
	var empty: Array[int] = []
	for lv in range(2, Game.LAST_UNLOCK_LEVEL + 1):
		var news := Game.unlocks_at(lv).filter(func(l): return not l.ends_with("more shoppers come by") and not l.begins_with("A level bonus"))
		if news.is_empty():
			empty.append(lv)
	check(empty.is_empty(), "levels 2 to %d each unlock something (none missing: %s)" % [Game.LAST_UNLOCK_LEVEL, empty])
	for lv in range(7, Game.LAST_UNLOCK_LEVEL + 1):
		print("      Level %d: %s" % [lv, " | ".join(Game.unlocks_at(lv))])
	var after := Game.unlocks_at(Game.LAST_UNLOCK_LEVEL + 1)
	check(after.any(func(l): return l.begins_with("A level bonus")) and not after.any(func(l): return l.ends_with("more shoppers come by")), "after that, a level brings a cash bonus: %s" % after)
	check(Game.level_bonus(Game.LAST_UNLOCK_LEVEL) == 0.0 and Game.level_bonus(Game.LAST_UNLOCK_LEVEL + 2) > Game.level_bonus(Game.LAST_UNLOCK_LEVEL + 1), "no bonus before then, and it grows")

	# Levelling up past it pays the bonus.
	Game.xp = Game.xp_for_level(Game.LAST_UNLOCK_LEVEL) + 1.0
	Game.level = Game.LAST_UNLOCK_LEVEL
	var cash := Game.money
	Game.add_xp(Game.xp_for_level(Game.LAST_UNLOCK_LEVEL + 2) - Game.xp)
	var expected := Game.level_bonus(Game.LAST_UNLOCK_LEVEL + 1) + Game.level_bonus(Game.LAST_UNLOCK_LEVEL + 2)
	check(Game.level == Game.LAST_UNLOCK_LEVEL + 2 and is_equal_approx(Game.money - cash, expected), "two levels at once past it: both bonuses ($%d)" % int(Game.money - cash))
	# The store gets busier only up to the last unlock.
	Game.level = Game.TRAFFIC_LEVELS
	var busy := store.traffic_multiplier()
	Game.level = Game.TRAFFIC_LEVELS + 6
	check(is_equal_approx(store.traffic_multiplier(), busy), "levels past %d don't keep adding shoppers (the store's full)" % Game.TRAFFIC_LEVELS)
	Game.level = 6
	var room6 := store.max_customers()
	Game.level = 10
	check(store.max_customers() > room6, "levels 7 to 10 make room for more shoppers at once (%d, was %d)" % [store.max_customers(), room6])

	# ---- new products and shoppers come with their levels
	var late := Game.PRODUCTS.keys().filter(func(id): return int(Game.PRODUCTS[id].level) >= 7)
	check(late.size() >= 8, "products for levels 7 and up (%d)" % late.size())
	var first: String = late[0]
	Game.level = int(Game.PRODUCTS[first].level) - 1
	check(not Game.buy_license(first), "can't license %s before level %d" % [Game.product_name(first), Game.PRODUCTS[first].level])
	Game.level = int(Game.PRODUCTS[first].level)
	check(Game.buy_license(first) and Game.is_licensed(first), "at level %d you can" % Game.level)
	var missing_icons := late.filter(func(id): return Game.icon(id) == null)
	check(missing_icons.is_empty(), "they all have pictures (%s missing)" % [missing_icons])
	var late_kinds := Brand.SHOPPERS.keys().filter(func(k): return int(Brand.SHOPPERS[k].level) >= 7)
	check(late_kinds.size() >= 3, "new kinds of shoppers from level 7: %s" % [late_kinds])
	for k: String in late_kinds:
		var lv := int(Brand.SHOPPERS[k].level)
		Game.level = lv - 1
		var seen_before := _seen(Brand.SHOPPERS[k], 600)
		Game.level = lv
		Game.minute = Game.NIGHT_MINUTE + 30  # (night owls come out)
		var seen_after := _seen(Brand.SHOPPERS[k], 1500)
		check(not seen_before and seen_after, "%s only come from level %d" % [Game.shopper_plural(Brand.SHOPPERS[k]), lv])
		var likes: Array = Brand.SHOPPERS[k].get("likes", [])
		check(likes.all(func(id): return Game.PRODUCTS.has(id)), "and they like things you can sell: %s" % [likes])
	Game.minute = 9 * 60

	# ---- decorations that bring in one kind of shopper
	var pullers := Game.FURNITURE.keys().filter(func(id): return Brand.SHOPPERS.has(Game.FURNITURE[id].get("pulls", "")))
	check(pullers.size() >= 5, "decorations that bring in more of one kind: %s" % [pullers])
	Game.level = 20
	if Game.FURNITURE.has("cauldron") and Brand.SHOPPERS.has("witch"):
		var witch: Dictionary = Brand.SHOPPERS.witch
		var plain := Game.shopper_weight(witch)
		var pots: Array = []
		for i in Game.DECOR_PULL_MAX + 1:
			var c := _free_cell(store, "cauldron")
			pots.append(store.add_furniture("cauldron", c))
			if i == 0:
				check(is_equal_approx(Game.shopper_weight(witch), plain * (1.0 + Game.DECOR_PULL)), "a cauldron: %d%% more witches" % roundi(Game.DECOR_PULL * 100.0))
		check(is_equal_approx(Game.shopper_weight(witch), plain * (1.0 + Game.DECOR_PULL * Game.DECOR_PULL_MAX)), "up to %d count (%d built)" % [Game.DECOR_PULL_MAX, pots.size()])
		check(is_equal_approx(Game.shopper_weight(Brand.SHOPPERS.zombie), Game.shopper_weight(Brand.SHOPPERS.zombie)) and Game.decorations_for(Brand.SHOPPERS.zombie) == 0, "zombies don't care about cauldrons")
		check(pots[0] is Lantern and (pots[0] as Lantern).color != Lantern.COLOR, "a cauldron glows (green)")
		var witches_with := _count(witch, 3000)
		for p in pots:
			store.remove_furniture(p)
		var witches_without := _count(witch, 3000)
		check(witches_with > witches_without * 1.3, "and more witches really come (%d in 3000 with, %d without)" % [witches_with, witches_without])
	var no_pics := pullers.filter(func(id): return Game.FURNITURE[id].texture == null)
	check(no_pics.is_empty(), "every decoration has a picture")
	for id: String in pullers:
		var obj: Node = store.add_furniture(id, _free_cell(store, id))
		check(obj is Decoration and Game.decorations_for(Brand.SHOPPERS[Game.FURNITURE[id].pulls]) >= 1, "%s builds and counts for %s" % [Game.FURNITURE[id].name, Game.shopper_plural(Brand.SHOPPERS[Game.FURNITURE[id].pulls])])
		store.remove_furniture(obj)

	# ---- build mode: decorations in their own row, locked until their level
	Game.level = 1
	var b: BuildMode = Game.build_mode
	b.enter()
	await _frames(3)
	var bar: Node = hud.build_bar
	check(not bar.decor_box.visible and not bar.tool_buttons["plant"].is_visible_in_tree(), "decorations aren't on the main row")
	bar.decor_button.pressed.emit()
	await _frames(2)
	check(bar.decor_box.visible and bar.tool_buttons["plant"].is_visible_in_tree(), "Decor opens their row")
	var locked: String = pullers.filter(func(id): return Game.furniture_level(id) > 1)[-1]
	check(bar.tool_buttons[locked].disabled and bar.locks[locked].text == "Lv %d" % Game.furniture_level(locked), "a locked one is greyed out with its level: %s" % bar.locks[locked].text)
	b.select_place(locked)
	check(b.tool != BuildMode.Tool.PLACE, "and can't be picked")
	check(not b._pad_tools().has(locked), "not even with a controller")
	Game.level = Game.furniture_level(locked)
	Game.unlocks_changed.emit()
	await _frames(2)
	check(not bar.tool_buttons[locked].disabled and bar.locks[locked].text.begins_with("$"), "at level %d it's for sale: %s" % [Game.level, bar.locks[locked].text])
	check(b._pad_tools().has(locked), "(a controller's d-pad gets to it too)")
	bar.decor_button.pressed.emit()
	await _frames(2)
	b.select_place(locked)
	await _frames(2)
	check(b.tool == BuildMode.Tool.PLACE and bar.decor_box.visible, "picking a decoration opens its row")
	bar.paint_button.pressed.emit()
	await _frames(2)
	check(bar.paint_box.visible and not bar.decor_box.visible, "Paint and Decor take turns")
	b.exit()
	await _frames(2)

	# ---- the new upgrades
	for id in ["conveyor", "billboard", "neon", "training", "drains", "golden_sign", "zone_4"]:
		check(Game.UPGRADES.has(id) and int(Game.UPGRADES[id].get("level", 1)) >= 7, "upgrade %s from level %d" % [id, int(Game.UPGRADES.get(id, {}).get("level", 0))])
	Game.level = 20
	var reg: Register = store.registers[0]
	var shopper := Customer.new()
	for i in 4:
		shopper.basket.append({"id": TestIds.starter(0), "price": 1.0})
	var slow := reg.scan_time(shopper)
	Game.buy_upgrade("conveyor")
	check(reg.scan_time(shopper) < slow, "Conveyor Belts: quicker at the register (%.2fs, was %.2fs)" % [reg.scan_time(shopper), slow])
	shopper.free()
	var busy_now := store.traffic_multiplier()
	check(Game.upgrade_problem("neon") != "", "the Neon Billboard needs the Billboard first: " + Game.upgrade_problem("neon"))
	Game.buy_upgrade("billboard")
	check(is_equal_approx(store.traffic_multiplier(), busy_now * Game.BILLBOARD_TRAFFIC), "Billboard: %d%% more shoppers" % roundi((Game.BILLBOARD_TRAFFIC - 1.0) * 100.0))
	Game.buy_upgrade("neon")
	check(is_equal_approx(store.traffic_multiplier(), busy_now * Game.BILLBOARD_TRAFFIC * Game.BILLBOARD_TRAFFIC), "Neon Billboard: more again")
	var id0 := TestIds.starter(0)
	Game.prices[id0] = Game.market_price(id0) * 1.3
	var chance := Game.buy_chance(id0)
	Game.buy_upgrade("golden_sign")
	check(Game.buy_chance(id0) > chance, "Golden Sign: shoppers put up with higher prices (%.2f, was %.2f)" % [Game.buy_chance(id0), chance])
	Game.prices[id0] = Game.market_price(id0)
	# Staff Training: twice the XP, and two more levels.
	var stocker := Game.hire("stocker")
	Game.add_staff_xp(stocker.id, 10.0)
	var plain_xp: float = stocker.xp
	var top := Game.staff_levels().size()
	stocker.xp = 10000.0
	Game.add_staff_xp(stocker.id, 0.0)
	check(stocker.level == top, "without training, staff stop at level %d" % top)
	Game.buy_upgrade("training")
	check(stocker.level == top + 2, "Staff Training: two more levels (now %d)" % stocker.level)
	stocker.xp = 0.0
	Game.add_staff_xp(stocker.id, 10.0)
	check(is_equal_approx(stocker.xp, plain_xp * Game.TRAINING_XP), "and they learn %dx as fast" % int(Game.TRAINING_XP))
	# Floor Drains: old puddles go by themselves.
	Game.is_open = true
	var cell := _free_cell(store, "plant")
	store.add_spill(cell, -1, false, 0.0)
	var spill: Spill = store.spills.get(cell)
	spill.age = Game.DRAIN_MINUTES * Game.SECONDS_PER_GAME_MINUTE - 0.2
	check(spill != null, "(a puddle)")
	check(Game.buy_upgrade("drains"), "bought the drains: " + Game.upgrade_problem("drains"))
	await _physics(30)
	check(not is_instance_valid(spill), "Floor Drains: an old puddle drains away")
	# Mass Grave: the delivery zone grows again (with the shelves next to it
	# cleared out of the way).
	var before := store.delivery_size.x * store.delivery_size.y
	var zone_at := store.delivery_anchor()
	for obj in store.objects.values().duplicate():
		if is_instance_valid(obj) and obj.furniture_id in ["shelf", "fridge", "storage", "plant", "lantern"] and Iso.chebyshev(obj.cell, zone_at) <= 6:
			store.remove_furniture(obj)
	store.layout_changed()
	for z in ["zone_1", "zone_2", "zone_3"]:
		if not Game.buy_upgrade(z):
			print("      %s: %s" % [z, Game.upgrade_problem(z)])
	var mid := store.delivery_size.x * store.delivery_size.y
	var ok := Game.buy_upgrade("zone_4")
	if not ok:
		print("      zone_4: " + Game.upgrade_problem("zone_4"))
	check(ok and store.delivery_size.x * store.delivery_size.y > mid, "%s: a bigger delivery zone (%s, from %d tiles)" % [Game.UPGRADES.zone_4.name, store.delivery_size, before])

	# ---- more staff at higher levels
	for role: String in Game.STAFF_PERKS:
		var lvls: Array = Game.STAFF_PERKS[role]
		Game.level = int(lvls[0]) - 1
		var few := Game.staff_cap(role)
		Game.level = int(lvls[-1])
		var more := Game.staff_cap(role)
		check(more == few + lvls.size(), "%s: %d more from level %s (%d -> %d)" % [role, lvls.size(), lvls, few, more])

	# ---- the computer
	hud.open_computer()
	for tab in hud.computer.TAB_NAMES.size():
		hud.computer.show_tab(tab)
		await _frames(2)
	hud.computer.show_tab(1)
	await _frames(2)
	var texts: Array = hud.computer.body.find_children("*", "Label", true, false).map(func(l): return l.text)
	check(texts.any(func(t): return t.begins_with(Game.product_name(late[-1]))), "the Products app lists the new products")
	hud.computer.close()

	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


## Whether `kind` turns up in `n` picks.
func _seen(kind: Dictionary, n: int) -> bool:
	return _count(kind, n) > 0


func _count(kind: Dictionary, n: int) -> int:
	var c := 0
	for i in n:
		if Game.pick_shopper_kind() == kind:
			c += 1
	return c


func _free_cell(store: Store, id: String) -> Vector2i:
	for c: Vector2i in store.floor_cells:
		if store.placement_error(c, id) == "" and Iso.chebyshev(c, store.door_cell) > 2:
			return c
	return Store.NO_CELL


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
