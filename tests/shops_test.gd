extends Node
# Checks the two little shops across the road (the witch's brewery and the
# vampire's curio shop: walls, a door, shelves, a counter with its keeper
# behind it), what their brews and charms do, the effects list, saving them,
# the witch and vampire shoppers, the witches and vampires in town, and
# the favorite products that bring skeletons, witches and vampires in.
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

	# ---- the shops
	check(town.shop_counters.has("brewery") and town.shop_counters.has("curios"), "two little shops in town")
	check(town.shop_keepers.has("brewery") and town.shop_keepers.has("curios"), "each with its keeper")
	for id: String in town.shop_counters:
		var counter: ShopCounter = town.shop_counters[id]
		var shop: Dictionary = Brand.SHOPS[id]
		var door: Vector2i = town.shop_doors.get(id, Store.NO_CELL)
		var inside: Array = town.shop_floor.keys().filter(func(c): return town.shop_floor[c] == id)
		check(door != Store.NO_CELL and inside.size() >= 7, "%s is a little building: a door and %d tiles of floor" % [shop.name, inside.size()])
		var walls := 0
		var shelves := 0
		for cell: Vector2i in town.objects:
			var o: Interactable = town.objects[cell]
			if o is Prop and not (o as Prop).textures.is_empty():
				var path: String = (o as Prop).textures[0].resource_path
				if path.contains("wall_" + str(shop.look)):
					walls += 1
				elif path.contains("shop_shelf_" + str(shop.look)):
					shelves += 1
		check(walls >= 14 and shelves >= 3, "with walls all around (%d) and shelves (%d)" % [walls, shelves])
		var around := 0
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not town.shop_floor.has(door + d) and store.is_walkable(door + d):
				around += 1
		check(around == 1, "the door is the only way in or out")
		var front := Interactable.FACINGS[counter.rotation_step]
		var keeper_cell := Iso.world_to_cell(town.shop_keepers[id].position)
		check(keeper_cell == counter.cell - front, "the keeper stands behind the counter, which faces into the shop")
		var stand := counter.cell + front
		var route := store.find_path(store.door_cell, stand)
		check(store.is_walkable(stand) and store.reachable.has(stand) and route.has(door),
			"you can walk from your store, in through its door, to %s's counter" % shop.name)
		p.position = Iso.cell_to_world(door)  # on the mat
		await _frames(2)
		check(town._in_shop == id, "walking in, %s says hello" % shop.keeper)
		p.position = Iso.cell_to_world(stand)
		await _frames(2)
		check(p.focused == counter and counter.get_prompt(p).contains(shop.name), "standing at the counter, E shops there: " + counter.get_prompt(p))
		p.try_interact()
		await _frames(2)
		check(hud.shop_panel.visible and hud.shop_panel.shop == id, "it opens the shop")
		var sold: int = Brand.BREWS.values().filter(func(b): return b.shop == id).size()
		check(hud.shop_panel.grid.get_child_count() == sold * 4, "listing its %d things" % sold)
		hud._back()
		await _frames(1)
		check(not hud.shop_panel.visible, "Esc closes it")
	var strays := 0
	for i in 300:
		if town.shop_floor.has(town._random_town_cell()):
			strays += 1
	check(strays == 0, "people strolling around town don't wander into the shops")
	check(Game.brew_problem("rumor") == "Not for sale" and not Game.buy_brew("rumor"), "(the spy's rumor isn't something you can buy)")
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
		store.add_spill(cell, -1, false, Store.spill_settle_seconds())  # old puddles
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

	# ---- witches and vampires in town
	var locals := func(looks: Array) -> Array:
		return store.world.get_children().filter(func(n): return n is Wanderer and is_instance_valid(n) \
			and n.has_meta("local") and not n.is_leaving() and n.sprite.texture in looks)
	check(locals.call(Brand.SHOPPERS.witch.looks).size() >= Town.WITCHES, "witches stroll around town (%d)" % locals.call(Brand.SHOPPERS.witch.looks).size())
	Game.minute = 11 * 60
	await _frames(3)
	check(town._vampires.is_empty(), "no vampires about by day")
	Game.minute = 18 * 60
	await _frames(3)
	var bats: Array = town._vampires.duplicate()
	check(bats.size() == Town.VAMPIRES and bats.all(func(b): return b.sprite.texture in Brand.SHOPPERS.vampire.looks), "at dusk, %d vampires come out" % bats.size())
	check(bats.all(func(b): return town.shop_floor.has(Iso.world_to_cell(b.position))), "(out of the curio shop)")
	Game.minute = 8 * 60
	await _frames(3)
	check(town._vampires.is_empty() and bats.all(func(b): return not is_instance_valid(b) or not b.loop), "and in the morning they go home")

	# ---- favorite products: stock what skeletons, witches and vampires love
	var fav_kinds := Brand.SHOPPERS.values().filter(func(k): return k.has("likes"))
	check(fav_kinds.size() == 3 and fav_kinds.all(func(k): return (k.likes as Array).size() >= 2 \
		and k.likes.all(func(id): return Game.PRODUCTS.has(id) and Game.PRODUCTS[id].license > 0.0)),
		"skeletons, witches and vampires each have favorite products: %s" % [fav_kinds.map(func(k): return "%s: %s" % [k.name, ", ".join(k.likes.map(func(id): return Game.product_name(id)))])])
	check(fav_kinds.all(func(k): return k.likes.all(func(id): return Game.fans_of(id).size() == 1 and Game.fans_of(id)[0].name == k.name)), "(nobody shares a favorite)")
	var newt: String = Brand.SHOPPERS.witch.likes[0]
	check(Game.fans_text(newt) == "Witches love it" and Game.fans_text(TestIds.starter(0)) == "", "the Products app says who loves what: " + Game.fans_text(newt))
	var lv := int(Game.PRODUCTS[newt].level)
	check(Game.unlocks_at(lv).any(func(l): return l.contains("Witches love " + Game.product_name(newt))), "and so does the level-up list: %s" % [Game.unlocks_at(lv)])
	var skel: Dictionary = Brand.SHOPPERS.skeleton
	var witch: Dictionary = Brand.SHOPPERS.witch
	var zombie: Dictionary = Brand.SHOPPERS.zombie
	Game.minute = 11 * 60
	Game.effects.erase("stake")
	var was_licensed: Dictionary = Game.licensed.duplicate()
	for id: String in Game.PRODUCTS:
		Game.licensed[id] = true  # (selling everything, so the favorites don't win by default)
		Game.prices[id] = Game.market_price(id)
	for s in store.shelves:
		if fav_kinds.any(func(k): return k.likes.has(s.product_id)):
			s.stock = 0
	var share := func(kind: Dictionary) -> float:
		var n := 0
		for i in 4000:
			if Game.pick_shopper_kind().name == kind.name:
				n += 1
		return n / 4000.0
	var list_rate := func(kind: Dictionary, ids: Array) -> float:
		var n := 0
		for i in 1500:
			if store._make_shopping_list(kind).any(func(want): return ids.has(want.id)):
				n += 1
		return n / 1500.0
	check(Game.favorites_on_shelves(witch) == 0, "with none of them on your shelves...")
	var base_w := Game.shopper_weight(witch)
	var before: float = share.call(witch)
	var base_pull := Game.rival_pull([], witch)
	var used: Array = []
	for id: String in witch.likes:
		var spots := store.shelves.filter(func(s): return s.holds_cold() == Game.is_cold(id) and not used.has(s) and s.stock == 0) \
			+ store.shelves.filter(func(s): return s.holds_cold() == Game.is_cold(id) and not used.has(s))
		if spots.is_empty():
			check(false, "(no %s for %s)" % ["cooler" if Game.is_cold(id) else "shelf", Game.product_name(id)])
			continue
		var fave_shelf: Shelf = spots[0]
		used.append(fave_shelf)
		fave_shelf.product_id = id
		fave_shelf.stock = 6
		fave_shelf.queue_redraw()
	check(Game.favorites_on_shelves(witch) == 2, "put %s on the shelves..." % " and ".join(witch.likes.map(func(id): return Game.product_name(id))))
	check(is_equal_approx(Game.shopper_weight(witch), base_w * (1.0 + 2.0 * Game.FAVORITE_PULL)),
		"and witches come %.1fx as often (weight %.1f -> %.1f)" % [Game.shopper_weight(witch) / base_w, base_w, Game.shopper_weight(witch)])
	var after: float = share.call(witch)
	check(after > before * 1.8, "(%d%% of shoppers were witches, now %d%%)" % [roundi(before * 100.0), roundi(after * 100.0)])
	check(is_equal_approx(Game.rival_pull([], witch), base_pull - 2.0 * Game.FAVORITE_RIVAL),
		"and fewer of them go to %s (%.2f -> %.2f)" % [Brand.RIVAL.name, base_pull, Game.rival_pull([], witch)])
	var witch_rate: float = list_rate.call(witch, witch.likes)
	var zombie_rate: float = list_rate.call(zombie, witch.likes)
	check(witch_rate > zombie_rate * 1.8 and witch_rate > 0.4, "witches mostly come for them (%d%% want one, vs %d%% of zombies)" % [roundi(witch_rate * 100.0), roundi(zombie_rate * 100.0)])
	var bones := store.spawn_customer(skel)
	await _frames(2)
	check(bones.describe().contains("Loves Bone Meal and Calcium Milk"), "the shopper card says what they love: " + bones.describe().split("\n")[1])
	store.customer_left(bones)
	bones.queue_free()
	for s in used:
		s.stock = 0
	check(Game.favorites_on_shelves(witch) == 0 and is_equal_approx(Game.shopper_weight(witch), base_w), "sold out, and it's back to normal")
	# Not selling a favorite yet: shoppers don't ask for it (0.9.6), but the
	# vampires in town tell you about it (Game.townsfolk_says).
	var vamp: Dictionary = Brand.SHOPPERS.vampire
	for id: String in vamp.likes:
		Game.licensed.erase(id)
	check(vamp.likes.all(func(id): return Game.can_license(id)), "(the vampire's favorites aren't licensed yet)")
	var asked := 0
	for i in 1500:
		for want in store._make_shopping_list(vamp):
			if not Game.is_licensed(want.id):
				asked += 1
	check(asked == 0, "vampire shoppers only want what you sell (%d asks for anything else)" % asked)
	var hint := Game.townsfolk_says(vamp)
	check((vamp.likes as Array).any(func(id): return hint.contains(Game.product_name(id))), "a vampire in town hints at one: \"%s\"" % hint)
	Game.licensed = was_licensed

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
