extends Node
# Checks the market stalls in town (the witch's brewery and the vampire's
# curios), what their brews and charms do, the effects list, saving them,
# and the new witch and vampire shoppers.
#   godot --headless --path . --fixed-fps 60 res://tests/shops_test.tscn

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	seed(808)
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	var store: Store = Game.store
	var town: Town = store.town
	var p: Player = Game.player
	var hud: Node = main.get_node("HUD")
	Game.tutorial_hidden = true
	Game.money = 1000.0

	# ---- the stalls
	check(town.shop_counters.has("brewery") and town.shop_counters.has("curios"), "two market stalls in town")
	check(town.shop_keepers.has("brewery") and town.shop_keepers.has("curios"), "each with its keeper behind the counter")
	for id: String in town.shop_counters:
		var counter: ShopCounter = town.shop_counters[id]
		var stand := counter.cell + Vector2i(1, 0)
		check(store.is_walkable(stand) and store.reachable.has(stand) and not store.find_path(store.door_cell, stand).is_empty(),
			"you can walk from the store to %s" % Brand.SHOPS[id].name)
		p.position = Iso.cell_to_world(stand)
		await _frames(2)
		check(p.focused == counter and counter.get_prompt(p).contains(Brand.SHOPS[id].name), "standing at it, E shops there: " + counter.get_prompt(p))
		p.try_interact()
		await _frames(2)
		check(hud.shop_panel.visible and hud.shop_panel.shop == id, "it opens the shop")
		var sold: int = Brand.BREWS.values().filter(func(b): return b.shop == id).size()
		check(hud.shop_panel.grid.get_child_count() == sold * 4, "listing its %d things" % sold)
		hud._back()
		await _frames(1)
		check(not hud.shop_panel.visible, "Esc closes it")
	p.position = Iso.cell_to_world(Vector2i(6, 6))
	await _frames(2)

	# ---- buying
	var money := Game.money
	check(Game.buy_brew("swift"), "buy a Swift Potion")
	check(is_equal_approx(Game.money, money - Brand.BREWS.swift.cost), "it costs $%d" % int(Brand.BREWS.swift.cost))
	check(Game.has_effect("swift") and is_equal_approx(Game.effects.swift, Brand.BREWS.swift.seconds), "it works for a minute")
	Game.buy_brew("swift")
	check(is_equal_approx(Game.effects.swift, 2.0 * Brand.BREWS.swift.seconds), "another one adds a minute")
	await _frames(2)
	check(hud.effects_box.visible and hud.effects_box.get_child_count() == 1, "it shows under the corner buttons")
	var label: Label = hud._effect_rows["swift"]
	check(label.text.begins_with("Swift Potion") and label.text.ends_with("2:00") or label.text.ends_with("1:59"), "with the time left: " + label.text)
	Game.money = 5.0
	check(Game.brew_problem("crucifix") == "Not enough money" and not Game.buy_brew("crucifix"), "can't buy what you can't afford")
	Game.money = 1000.0
	while Game.effects.get("swift", 0.0) + Brand.BREWS.swift.seconds <= Game.MAX_EFFECT_SECONDS:
		Game.buy_brew("swift")
	check(Game.brew_problem("swift") != "", "and there's a limit: " + Game.brew_problem("swift"))

	# ---- what they do
	var walked := await _walk_for(p, false)
	Game.effects.erase("swift")
	var plain := await _walk_for(p, false)
	check(walked > plain * 1.35, "Swift Potion: you run faster (%.0f px vs %.0f)" % [walked, plain])

	var shelf: Shelf = store.shelves[0]
	shelf.product_id = TestIds.starter(0)
	shelf.stock = 0
	p.position = Iso.cell_to_world(store.stand_cell_for(shelf.cell, shelf.cell))
	p.carry_product = TestIds.starter(0)
	p.carry_count = 8
	var t_plain := await _time_action(p, shelf)
	shelf.stock = 0
	p.carry_product = TestIds.starter(0)
	p.carry_count = 8
	Game.buy_brew("quickhand")
	var t_quick := await _time_action(p, shelf)
	check(t_quick < t_plain * 0.65, "Quickhand Potion: stocking goes twice as fast (%.2fs vs %.2fs)" % [t_quick, t_plain])
	p.carry_count = 0
	p.carry_product = ""

	var traffic := store.traffic_multiplier()
	Game.buy_brew("charm")
	check(is_equal_approx(store.traffic_multiplier(), traffic * Game.CHARM_TRAFFIC), "Charm Potion: %d%% more shoppers" % roundi((Game.CHARM_TRAFFIC - 1.0) * 100.0))

	var c := store.spawn_customer()
	await _frames(2)
	c.state = Customer.State.WAIT_FOR_LINE
	c.patience = 10.0
	c._tick_patience(1.0)
	var lost := 10.0 - c.patience
	Game.buy_brew("wine")
	c._tick_patience(1.0)
	check(is_equal_approx(10.0 - lost - c.patience, lost * Game.WINE_PATIENCE), "Grave Wine: shoppers lose patience half as fast")

	c.leaky = true
	c.position = Iso.cell_to_world(Vector2i(8, 5))  # in the store
	c.drip_timer = 0.0
	Game.buy_brew("garlic")
	var spills := store.spills.size()
	c._drip(0.1)
	check(store.spills.size() == spills, "Garlic: nobody drips blood")
	Game.effects.erase("garlic")
	c.drip_timer = 0.0
	c._drip(0.1)
	check(store.spills.size() == spills + 1 or store.spills.has(c.current_cell()), "and once it's gone, they drip again")
	store.customer_left(c)
	c.queue_free()

	for cell in [Vector2i(5, 8), Vector2i(6, 8), Vector2i(7, 8)]:
		store.add_spill(cell)
	check(store.mess_multiplier() < 1.0, "blood scares shoppers off...")
	var pull := Game.rival_pull([], {})
	Game.buy_brew("crucifix")
	check(store.mess_multiplier() == 1.0, "...but not with a Crucifix up")
	check(Game.rival_pull([], {}) < pull, "and it doesn't send them to %s either" % Brand.RIVAL.name)
	Game.open_store()
	Game.xp = 20.0  # some XP to lose
	await _seconds(1.0)
	check(is_equal_approx(Game.xp, 20.0), "and the blood doesn't cost you XP (still %.2f)" % Game.xp)
	var cross: float = Game.effects.crucifix
	Game.effects.erase("crucifix")
	await _seconds(1.0)
	check(Game.xp < 20.0, "(without it, it does: %.2f)" % Game.xp)
	Game.effects.crucifix = cross

	check(Game.rival_pull([], {}) > 0.0, "%s gets some shoppers..." % Brand.RIVAL.name)
	Game.buy_brew("stake")
	check(Game.rival_pull([], {}) == 0.0, "...but none with a Wooden Stake in its door")

	# ---- effects wear off, and save
	var saved := Game.to_dict()
	check(saved.effects.has("stake") and saved.effects.has("crucifix"), "effects are saved")
	Game.effects["garlic"] = 0.05
	var said := []
	Game.message.connect(func(t): said.append(t))
	await _seconds(0.3)
	check(not Game.has_effect("garlic") and said.any(func(t): return t.contains("Garlic wore off")), "they wear off (and say so)")
	var loaded := Game.to_dict()
	Game.effects = {}
	Game.from_dict(loaded)
	check(Game.has_effect("stake") and Game.has_effect("crucifix"), "and load again")
	Game.rival_owned = true
	check(Game.brew_problem("stake").contains("yours"), "no staking %s once it's yours" % Brand.RIVAL.name)
	Game.rival_owned = false

	# ---- witches and vampires
	check(Game.unlocks_at(int(Brand.SHOPPERS.witch.level)).any(func(l): return l.contains("witches")), "witches show up at level %d" % Brand.SHOPPERS.witch.level)
	check(Game.unlocks_at(int(Brand.SHOPPERS.vampire.level)).any(func(l): return l.contains("vampires")), "vampires at level %d" % Brand.SHOPPERS.vampire.level)
	Game.minute = 10 * 60
	var day_w := Game.shopper_weight(Brand.SHOPPERS.vampire)
	Game.minute = 19 * 60
	var night_w := Game.shopper_weight(Brand.SHOPPERS.vampire)
	check(night_w > day_w * 5.0, "vampires mostly come out after dark (weight %.1f by day, %.1f at night)" % [day_w, night_w])
	Game.xp = 5000.0
	Game.level = Game.level_for(Game.xp)
	var seen := {}
	for i in 400:
		seen[Game.pick_shopper_kind().name] = true
	check(seen.has("Witch") and seen.has("Vampire"), "both show up in the store: %s" % [seen.keys()])
	var v := store.spawn_customer(Brand.SHOPPERS.vampire)
	var w := store.spawn_customer(Brand.SHOPPERS.witch)
	await _frames(3)
	check(v.sprite.texture in Brand.SHOPPERS.vampire.looks and w.sprite.texture.get_height() > 36, "they look the part (a witch's hat sticks up)")
	check(not v.leaky and not w.leaky, "and they don't drip blood")

	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


func _walk_for(p: Player, _sprint: bool) -> float:
	p.position = Iso.cell_to_world(Vector2i(4, 6))
	await _frames(2)
	var from := p.position
	Input.action_press("move_right")
	var t := 0.0
	while t < 0.5:
		await get_tree().process_frame
		t += get_process_delta_time()
	Input.action_release("move_right")
	await _frames(1)
	return p.position.distance_to(from)


## How long stocking `shelf` from the box in your hands takes.
func _time_action(p: Player, shelf: Shelf) -> float:
	await _frames(2)
	p.use(shelf)
	var t := 0.0
	while p.is_busy() and t < 10.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	return t


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(t: float) -> void:
	await get_tree().create_timer(t).timeout
