extends Node
# 0.9.5's fixes, from players' notes:
#  1. the computer says which kind of shopper asked for a product; skeletons,
#     witches and vampires in town tell you their favorites (in 0.9.6,
#     shoppers stopped asking for products you haven't licensed)
#  2. the general manager keeps every shelf of a product stocked, and stocks
#     new empty shelves with products that aren't on any
#  3. stockers bring what's emptiest first, to the emptiest shelf for it
#  4. the day's summary fits in the window
#  5. clicking in a price box puts the cursor there (no select-all)
#  6. E picks a box (or a waiting shopper) over taking over a cashier, and
#     what you're facing over what's behind you
#  7. you can brush past gravestones and lanterns; they can be moved
#  8. messages stay up long enough to read, and the log keeps them (M)
#  9. one markup sets every price (and Auto keeps it)
# 10. stockers share storage racks (no box back on the delivery zone while a
#     rack has room)
#     (and firing one mid-pickup doesn't lose the box)
#   godot --headless --path . --fixed-fps 60 res://tests/fixes_test.tscn

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	seed(9595)
	Engine.max_fps = 0
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	var store: Store = Game.store
	var p: Player = Game.player
	var hud: Node = main.get_node("HUD")
	Game.tutorial_hidden = true
	Game.money = 20000.0
	Game.add_xp(3000.0)  # store level 5: every kind of shopper, lots to license
	await _frames(2)
	hud.levelup_panel.visible = false

	_who_asked(hud)
	await _manager(store)
	await _stockers(store)
	await _summary(hud)
	await _price_box(hud)
	await _priorities(store, p)
	await _decor(store, p)
	await _messages(hud)
	await _markup(hud)
	await _racks(store)
	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- 1

func _who_asked(hud: Node) -> void:
	var newt := _liked_by("witch")
	Game.stats.wanted = {}
	Game.stats.wanted_by = {}
	var said: Array[String] = []
	var listen := func(t: String): said.append(t)
	Game.message.connect(listen)
	Game.record_wanted(newt, Brand.SHOPPERS.witch)
	Game.record_wanted(newt, Brand.SHOPPERS.witch)
	Game.record_wanted(newt, Brand.SHOPPERS.zombie)
	Game.message.disconnect(listen)
	check(Game.askers_text(newt) == "2 witches and 1 zombie", "who asked: " + Game.askers_text(newt))
	check(said.any(func(t): return t.begins_with("Witches keep asking for %s" % Game.product_name(newt))), "the reminder names witches, not zombies: %s" % [said])
	Game.record_wanted(newt, Brand.SHOPPERS.rich)
	check(Game.askers_text(newt) == "2 witches, 1 zombie and 1 rich zombie", "three kinds: " + Game.askers_text(newt))
	Game.licensed.erase(newt)
	hud.open_computer()
	hud.computer.show_tab(1)  # Products
	var texts: Array[String] = []
	for l in hud.computer.body.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	check(texts.any(func(t): return t.contains("Asked for today by 2 witches")), "the Products tab says witches asked for it")
	hud.computer.close()

	# Shoppers only want what you've licensed (0.9.6); townsfolk do the hinting.
	var asks := 0
	for i in 400:
		var list: Array = Game.store._make_shopping_list(Brand.SHOPPERS.witch)
		if list.any(func(e): return not Game.is_licensed(e.id)):
			asks += 1
	check(asks == 0, "shoppers never ask for something you haven't licensed (%d of 400 witches' lists)" % asks)
	Game.licensed[newt] = true
	if not Game.prices.has(newt):
		Game.prices[newt] = Game.market_price(newt)
	var with_newt := 0
	for i in 400:
		if Game.store._make_shopping_list(Brand.SHOPPERS.witch).any(func(e): return e.id == newt):
			with_newt += 1
	Game.licensed.erase(newt)
	check(with_newt > 120, "license a witch's favorite and witches want it a lot (%d of 400 lists)" % with_newt)

	# Townsfolk tell you what they'd come in for.
	Game.stats.wanted = {}
	Game.stats.wanted_by = {}
	var line := Game.townsfolk_says(Brand.SHOPPERS.witch)
	check(line.contains(Game.product_name(newt)) or (Brand.SHOPPERS.witch.likes as Array).any(func(id): return line.contains(Game.product_name(id))),
		"a witch in town asks for her favorite: \"%s\"" % line)
	check(Game.askers_text(newt) == "1 witch" or Game.stats.wanted_by.values().any(func(w): return w.has("witch")), "and it counts as a witch asking (%s)" % [Game.stats.wanted_by])
	check(Game.townsfolk_says(Brand.SHOPPERS.zombie) == "", "zombies don't have favorites to talk about")
	for id: String in Brand.SHOPPERS.witch.likes:
		Game.licensed[id] = true
		if not Game.prices.has(id):
			Game.prices[id] = Game.market_price(id)
	line = Game.townsfolk_says(Brand.SHOPPERS.witch)
	check(line.begins_with("Your ") or line.begins_with("Out of"), "licensed but on no shelf: \"%s\"" % line)
	var town: Town = Game.store.town
	var witches: Array = town.folk.filter(func(w): return w.get_meta("kind") == "witch")
	check(witches.size() >= 2, "the witches in town can talk (%d)" % witches.size())
	var heard: Array[String] = []
	var listen2 := func(_at: Vector2, t: String, _c: Color): heard.append(t)
	Game.popup.connect(listen2)
	var w: Wanderer = witches[0]
	Game.player.position = w.position + Vector2(20, 10)
	town._talk_timer = 0.0
	for i in 3:
		await get_tree().process_frame
	Game.popup.disconnect(listen2)
	check(heard.any(func(t): return t.begins_with("Your ") or t.begins_with("Out of")), "walk up to a witch and she says it: %s" % [heard])
	var said_at: float = w.get_meta("said_at", -1.0)
	town._talk_timer = 0.0
	for i in 3:
		await get_tree().process_frame
	check(said_at >= 0.0 and float(w.get_meta("said_at", -1.0)) == said_at, "(and she doesn't repeat herself right away)")
	for id: String in Brand.SHOPPERS.witch.likes:
		Game.licensed.erase(id)


# ---------------------------------------------------------------- 2

func _manager(store: Store) -> void:
	var S0 := TestIds.starter(0)
	var dry: Array = store.shelves.filter(func(s): return not s.holds_cold())
	for b: StockBox in store.boxes.values():
		store.remove_box(b)
	store.pending_deliveries.clear()
	for s in dry:
		s.product_id = TestIds.starter(1)
		s.stock = Shelf.CAPACITY
	var three: Array = dry.slice(0, 3)
	for s in three:
		s.product_id = S0
	three[0].stock = Shelf.CAPACITY
	three[1].stock = Shelf.CAPACITY
	three[2].stock = 0
	check(store.reorder_list().get(S0, 0) == 1, "two shelves full, one empty: the manager orders a box (%s)" % store.reorder_list())
	three[2].stock = Shelf.CAPACITY
	check(not store.reorder_list().has(S0), "all three full: nothing")
	# A brand-new shelf, and a product you license but don't have on a shelf.
	var newbie := TestIds.at_level(2, false)
	Game.licensed[newbie] = true
	if not Game.prices.has(newbie):
		Game.prices[newbie] = Game.market_price(newbie)
	three[2].product_id = ""
	three[2].stock = 0
	var on_shelves := {}
	for s in store.shelves:
		on_shelves[s.product_id] = true
	var wants := store.reorder_list()
	var picked: Array = wants.keys().filter(func(id): return not on_shelves.has(id))
	check(picked.size() == 1 and wants[picked[0]] == 1 and not Game.is_cold(picked[0]),
		"an empty, unlabeled shelf gets one box of a licensed product that's on no shelf (%s)" % wants)
	check(not store.products_running_low().has(picked[0]) if not picked.is_empty() else false, "(but the computer doesn't call it running low)")
	if not picked.is_empty():
		store.drop_box(store.delivery_cells[0], picked[0], 6)
	var after := store.reorder_list().keys().filter(func(id): return not on_shelves.has(id))
	check(after.is_empty(), "nothing more once a box for that shelf is waiting (%s)" % [after])
	for b: StockBox in store.boxes.values():
		store.remove_box(b)
	three[2].product_id = S0
	three[2].stock = Shelf.CAPACITY
	await _frames(1)


# ---------------------------------------------------------------- 3

func _stockers(store: Store) -> void:
	var S0 := TestIds.starter(0)
	var S1 := TestIds.starter(1)
	var dry: Array = store.shelves.filter(func(s): return not s.holds_cold())
	for b: StockBox in store.boxes.values():
		store.remove_box(b)
	for s in dry:
		s.product_id = S1
		s.stock = Shelf.CAPACITY
	dry[0].product_id = S0
	dry[0].stock = 10
	dry[1].product_id = S0
	dry[1].stock = 2
	check(store.best_shelf_for(S0, dry[0].position, null) == dry[1], "a box goes on the emptiest shelf for it, even if another is closer")
	# Two boxes: a nearly-full product right by the stocker, an empty one far off.
	dry[2].stock = 11  # S1: nearly full
	for s in dry:
		if s.product_id == S1:
			s.stock = 11
	dry[0].stock = 0
	dry[1].stock = 0  # S0: empty
	Game.hire("stocker")
	await _frames(2)
	var st: Staff = store.staff.filter(func(s): return s.role == "stocker")[-1]
	st.set_process(false)
	var near := store.delivery_cells[0]
	var far := store.delivery_cells[-1]
	st.position = Iso.cell_to_world(near)
	store.drop_box(near, S1, 1)
	store.drop_box(far, S0, 6)
	st._give_up()
	st._find_box()
	check(is_instance_valid(st.target_box) and st.target_box.product_id == S0, "the stocker goes for the empty product's box first, not the closest one (%s)" % [st.target_box.product_id if st.target_box else "none"])
	st._give_up()
	for b: StockBox in store.boxes.values():
		store.remove_box(b)
	for s in dry:
		s.stock = Shelf.CAPACITY
	st.set_process(true)


# ---------------------------------------------------------------- 4

func _summary(hud: Node) -> void:
	var lots := {}
	for id in Game.PRODUCTS:
		lots[id] = 7
	var s := {"day": 12, "revenue": 1234.5, "spent": 300.0, "invested": 900.0, "wages": 250.0, "profit": -215.5,
		"customers": 140, "items_sold": 410, "missed": 33, "walkouts": 4, "lost": 12, "wanted": lots,
		"spies_caught": 3, "spies_escaped": 1, "spy_reports": 2, "cleaned": 25, "xp_lost": 14.0}
	for size in [Vector2i(1280, 720), Vector2i(960, 540)]:
		get_window().size = size
		await _frames(2)
		hud._show_summary(s)
		await _frames(4)
		var r: Rect2 = hud.summary_panel.get_global_rect()
		var screen := Rect2(Vector2.ZERO, hud.root.size)
		check(screen.encloses(r), "at %dx%d the day's summary fits on the screen (%s in %s)" % [size.x, size.y, r, screen])
	check(hud.summary_notes.text.contains("Townsfolk asked you to sell"), "with the long list of asked-for products wrapped underneath")
	check(hud.summary_notes.text.contains("and %d more" % (Game.PRODUCTS.size() - hud.WANTED_SHOWN)), "naming the top %d and how many more" % hud.WANTED_SHOWN)
	# Messages stay clear of the hints on the left and the buttons on the right.
	hud.summary_panel.visible = false
	Game.message.emit("A message long enough to need some room: " + "words ".repeat(20))
	await _frames(3)
	var m: Rect2 = hud.message_box.get_global_rect()
	var c: Rect2 = hud.corner_box.get_global_rect()
	var hints: Array = [hud.prep_panel, hud.tutorial].filter(func(h): return h.visible)
	check(not hints.is_empty(), "(a hint is showing on the left)")
	var clear: bool = hints.all(func(h): return not m.intersects(h.get_global_rect()))
	check(clear and not m.intersects(c), "messages don't cover the hints or the corner buttons (%s, %s, %s)" % [m, hints.map(func(h): return h.get_global_rect()), c])
	hud.summary_panel.visible = false
	get_window().size = Vector2i(1280, 720)
	await _frames(2)


# ---------------------------------------------------------------- 5

func _price_box(hud: Node) -> void:
	hud.open_computer()
	hud.computer.show_tab(0)  # Stock & Prices
	await _frames(2)
	var f: LineEdit = hud.computer.price_fields[0]
	check(not f.select_all_on_focus, "clicking in a price box puts the cursor there instead of selecting the whole price")
	hud.computer.close()


# ---------------------------------------------------------------- 6

func _priorities(store: Store, p: Player) -> void:
	var reg: Register = store.register
	Game.hire("cashier")
	await _frames(3)
	var cashier: Staff = store.staff.filter(func(s): return s.role == "cashier")[-1]
	reg.cashier = cashier
	cashier.register = reg
	# Stand next to the register with a box one step further away.
	var stand := store.stand_cell_for(reg.cell, reg.cell)
	var box_cell := Store.NO_CELL
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var c: Vector2i = stand + d
		if c != reg.cell and store.can_drop_at(c) and Iso.chebyshev(c, stand) == 1:
			box_cell = c
			break
	check(box_cell != Store.NO_CELL, "found a spot for a box by the register")
	store.drop_box(box_cell, TestIds.starter(0), 3)
	p.position = Iso.cell_to_world(stand) + (Iso.cell_to_world(reg.cell) - Iso.cell_to_world(stand)) * 0.3  # leaning toward the register
	p.facing = (Iso.cell_to_world(reg.cell) - p.position).normalized()
	await _frames(2)
	check(p.focused is StockBox, "next to a box and a cashier's register, E picks up the box (not 'take over'): %s" % [p.focused])
	store.remove_box(store.boxes[box_cell])
	await _frames(2)
	check(p.focused == reg and reg.get_prompt(p).begins_with("Take over"), "with nothing else there, E can still take over")
	reg.cashier = null
	cashier.register = null
	# Facing: two boxes the same distance away, one ahead and one behind.
	var mid := Store.NO_CELL
	for c: Vector2i in _floor_cells(store):
		if store.can_drop_at(c) and store.can_drop_at(c + Vector2i(1, 0)) and store.can_drop_at(c - Vector2i(1, 0)) and store.is_walkable(c):
			mid = c
			break
	store.drop_box(mid + Vector2i(1, 0), TestIds.starter(0), 2)
	store.drop_box(mid - Vector2i(1, 0), TestIds.starter(1), 2)
	p.position = Iso.cell_to_world(mid)
	p.facing = (Iso.cell_to_world(mid - Vector2i(1, 0)) - p.position).normalized()
	await _frames(2)
	check(p.focused == store.boxes.get(mid - Vector2i(1, 0)), "two boxes equally close: E picks the one you're facing")
	p.facing = -p.facing
	await _frames(2)
	check(p.focused == store.boxes.get(mid + Vector2i(1, 0)), "turn around, and it's the other one")
	for b: StockBox in store.boxes.values():
		store.remove_box(b)


# ---------------------------------------------------------------- 7

func _decor(store: Store, p: Player) -> void:
	var b: BuildMode = Game.build_mode
	var spot := Store.NO_CELL
	for c: Vector2i in _floor_cells(store):
		var ok := true
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var n: Vector2i = c + Vector2i(dx, dy)
				if not store.is_walkable(n) or store.objects.has(n) or n in store.delivery_cells or store.boxes.has(n):
					ok = false
		if ok and store.placement_error(c, "plant") == "" and store.placement_error(c + Vector2i(1, 0), "lantern") == "":
			spot = c
			break
	check(spot != Store.NO_CELL, "found an open spot for a gravestone")
	b.enter()
	for kind in ["plant", "lantern"]:
		b.select_place(kind)
		b.tap(Iso.cell_to_world(spot))
		var obj: Interactable = store.objects.get(spot)
		check(obj is Decoration and obj.furniture_id == kind, "placed a %s" % Game.FURNITURE[kind].name.to_lower())
		b.select_tool(BuildMode.Tool.MOVE)
		b.tap(obj.position + Vector2(0, -20))  # click on it
		b.tap(Iso.cell_to_world(spot + Vector2i(0, 1)))
		check(store.objects.get(spot + Vector2i(0, 1)) == obj and not store.objects.has(spot), "the %s can be moved in build mode" % Game.FURNITURE[kind].name.to_lower())
		b.select_tool(BuildMode.Tool.MOVE)
		b.tap(obj.position + Vector2(0, -20))
		b.tap(Iso.cell_to_world(spot))
		b.select_tool(BuildMode.Tool.NONE)
		if kind == "plant":
			b.exit()
			await _frames(2)
			# Walk up the screen just past its middle: you slide around it.
			var start := Iso.cell_to_world(spot) + Vector2(10, 60)
			p.position = start
			p.path.clear()
			await _frames(2)
			Input.action_press("move_up")
			for i in 120:
				await get_tree().physics_frame
			Input.action_release("move_up")
			check(p.position.y < Iso.cell_to_world(spot).y - 16.0, "walking at a gravestone a little off-center, you slide past it (%s)" % [p.position - Iso.cell_to_world(spot)])
			b.enter()
		b.select_tool(BuildMode.Tool.SELL)
		b.tap(obj.position + Vector2(0, -20))
		check(not store.objects.has(spot), "(sold it again)")
		b.select_tool(BuildMode.Tool.NONE)
	b.exit()
	await _frames(2)


# ---------------------------------------------------------------- 8

func _messages(hud: Node) -> void:
	for m: Array in hud._messages:
		m[0].queue_free()
	hud._messages.clear()
	hud._message_queue.clear()
	Game.message_log.clear()
	for i in 6:
		Game.message.emit("Test message %d" % i)
	await _frames(1)
	check(hud._messages.size() == hud.MAX_MESSAGES, "%d messages at once on screen" % hud.MAX_MESSAGES)
	check(hud._message_queue.size() == 2, "the rest wait their turn instead of pushing the first ones off")
	Game.message.emit("Test message 0")
	check(hud._messages.size() == hud.MAX_MESSAGES and hud._message_queue.size() == 2, "the same message again doesn't show twice")
	check(hud._message_seconds("x".repeat(80)) >= hud.MESSAGE_SECONDS + 4.0, "a long message stays up longer")
	var t0 := Time.get_ticks_msec()
	while hud._message_queue.size() > 0 and Time.get_ticks_msec() - t0 < 20000:
		await get_tree().process_frame
	check(hud._message_queue.is_empty(), "after a few seconds, the waiting ones come up")
	check(Game.message_log.size() == 7 and Game.message_log[-1].text == "Test message 0", "every message goes in the log (%d)" % Game.message_log.size())
	var press := InputEventAction.new()
	press.action = "messages"
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(2)
	check(hud.message_log.visible, "M opens the message log")
	var first: Label = hud.message_log.list.get_child(0).get_child(1)
	check(first.text == "Test message 0", "newest first: " + first.text)
	hud._back(false)
	check(not hud.message_log.visible, "Esc / B closes it")
	hud.open_pause()
	await _frames(1)
	hud.pause_menu.messages_requested.emit()
	await _frames(1)
	check(hud.message_log.visible and not hud.pause_menu.visible, "the pause menu has Messages too (for controllers)")
	hud.message_log.close()
	get_tree().paused = false


# ---------------------------------------------------------------- 9

func _markup(hud: Node) -> void:
	Game.auto_price = false
	Game.set_markup(0.1)
	Game.match_all_prices()
	var id := TestIds.starter(0)
	check(is_equal_approx(Game.prices[id], snappedf(Game.market_price(id) * 1.1, 0.05)), "Set all prices: market +10%% ($%.2f vs market $%.2f)" % [Game.prices[id], Game.market_price(id)])
	Game.auto_price = true
	Game.set_markup(0.2)
	check(is_equal_approx(Game.prices[id], snappedf(Game.market_price(id) * 1.2, 0.05)), "with Auto on, changing the markup moves every price")
	Game.update_market(false)
	check(is_equal_approx(Game.prices[id], snappedf(Game.market_price(id) * 1.2, 0.05)), "and they keep it when the market moves")
	Game.set_markup(9.0)
	check(is_equal_approx(Game.price_markup, Game.MARKUP_MAX), "the markup stops at +%d%%" % roundi(Game.MARKUP_MAX * 100))
	Game.set_markup(0.1)
	var text := Game.markup_effect(0.1)
	check(text.contains("vampires") and text.contains("always pay it") and text.contains("% of the time") and text.contains("84%"), "it says what +10% means for each kind of shopper: " + text)
	check(Game.markup_effect(0.0).contains("every shopper buys"), "at market: " + Game.markup_effect(0.0))
	var saved := Game.to_dict()
	Game.price_markup = 0.0
	Game.from_dict(JSON.parse_string(JSON.stringify(saved)))
	check(is_equal_approx(Game.price_markup, 0.1), "the markup is saved")
	hud.open_computer()
	hud.computer.show_tab(0)
	await _frames(2)
	check(hud.computer.markup_row.visible and hud.computer.markup_label.text.ends_with("+10%"), "Stock & Prices shows the markup: " + hud.computer.markup_label.text)
	hud.computer._change_markup(Game.MARKUP_STEP)
	check(hud.computer.markup_label.text.ends_with("+15%"), "and > raises it")
	hud.computer.close()
	Game.auto_price = false
	Game.set_markup(0.0)
	Game.match_all_prices()


# ---------------------------------------------------------------- 10

func _racks(store: Store) -> void:
	var S0 := TestIds.starter(0)
	var spot := Store.NO_CELL
	for c: Vector2i in _floor_cells(store):
		if store.placement_error(c, "storage") == "":
			spot = c
			break
	store.add_furniture("storage", spot)
	store.layout_changed()
	var rack: StorageRack = store.racks[-1]
	while rack.boxes.size() < StorageRack.CAPACITY - 2:
		rack.store_box(TestIds.starter(1), 4)
	for s in store.shelves:
		if not s.holds_cold():
			s.product_id = S0
			s.stock = Shelf.CAPACITY  # nowhere to put more
	Game.hire("stocker")
	await _frames(3)
	var stockers: Array = store.staff.filter(func(s): return s.role == "stocker")
	check(stockers.size() >= 2, "two stockers")
	for st: Staff in stockers.slice(0, 2):
		st._give_up()
		st.carry_product = S0
		st.carry_count = 5  # left over: every shelf is full
		st._deliver()
	var jobs := stockers.slice(0, 2).map(func(st): return Staff.Job.keys()[st.job])
	check(stockers[0].put_rack == rack and stockers[1].put_rack == rack, "both stockers take their leftovers to the rack with 2 free spots, not the delivery zone (%s)" % [jobs])
	var third: Staff = stockers[0]
	check(store.rack_room_for(rack, null) == 0, "(the rack's two spots are spoken for)")
	for st: Staff in stockers.slice(0, 2):
		st._give_up()
		st.carry_count = 0
		st.carry_product = ""

	# Fired while picking up a box: the box stays (they used to finish picking
	# it up on their way out and take it with them).
	for b: StockBox in store.boxes.values():
		store.remove_box(b)
	var cell := store.delivery_cells[0]
	store.drop_box(cell, S0, 7)
	var picker: Staff = stockers[0]
	picker._give_up()
	picker.target_box = store.boxes[cell]
	store.claim(picker.target_box, picker)
	var before := _count(store, S0)
	picker._start(Staff.Job.PICKING_UP, 0.0)
	# Being let go, then still getting their turn this frame before they're
	# gone (in the game that depends on who fired them and when).
	store.staff.erase(picker)
	picker.leave()
	picker._process(1.0 / 60.0)
	Game.fire(picker.id)
	await _frames(3)
	check(_count(store, S0) == before and before >= 7, "fire a stocker as they pick up a box, and no stock goes with them (%d before, %d after)" % [before, _count(store, S0)])


# ---------------------------------------------------------------- helpers

## Every `id` in the store that isn't on a shelf: boxes on the floor, on
## the racks, in staff hands.
func _count(store: Store, id: String) -> int:
	var n := 0
	for b: StockBox in store.boxes.values():
		if b.product_id == id:
			n += b.count
	for r in store.racks:
		for b in r.boxes:
			if b.product_id == id:
				n += b.count
	for st in store.staff:
		if is_instance_valid(st) and not st.is_queued_for_deletion() and st.carry_product == id:
			n += st.carry_count
	return n


func _liked_by(kind: String) -> String:
	var likes: Array = Brand.SHOPPERS[kind].get("likes", [])
	return likes[0] if not likes.is_empty() else TestIds.at_level(2)


func _floor_cells(store: Store) -> Array:
	var cells: Array = []
	for y in range(store.height - 2, 1, -1):
		for x in range(1, store.width - 1):
			cells.append(Vector2i(x, y))
	return cells


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
