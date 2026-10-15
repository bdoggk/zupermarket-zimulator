extends Node
# Checks shelf labels (a shelf keeps the label of the first product put on
# it, stockers respect it, you can peel it off), taking items off a shelf
# into a box, and the first-day tips.
#   godot --headless --path . --fixed-fps 60 res://tests/label_test.tscn

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	seed(99)
	Engine.max_fps = 0
	Engine.time_scale = 4.0
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	var store: Store = Game.store
	var p: Player = Game.player
	var hud: Node = main.get_node("HUD")
	var tips: Node = hud.tutorial
	var S0 := TestIds.starter(0)
	var S1 := TestIds.starter(1)
	Game.money = 5000.0

	# ---- first-day tips
	await _frames(2)
	check(Game.day == 1 and tips.current == "box" and tips.visible, "day 1 starts with a tip about boxes")
	check(not hud.prep_panel.visible, "the tips replace the 'store closed' hint")
	var shelf: Shelf = null
	for s in store.shelves:
		if not s.holds_cold():
			shelf = s
			break
	check(store.shelves.all(func(s): return not s.is_labeled()), "shelves start without labels")
	var box: StockBox = null
	for b: StockBox in store.boxes.values():
		if b.product_id == S0:
			box = b
	p.position = Iso.cell_to_world(box.cell)
	await _frames(2)
	box.interact(p)
	await _frames(2)
	check(tips.current == "stock", "picking up a box moves the tips on (now: %s)" % tips.current)

	# ---- stocking labels a shelf
	p.position = Iso.cell_to_world(store.stand_cell_for(shelf.cell, shelf.cell))
	await _frames(2)
	check(shelf.can_interact(p) and shelf.get_prompt(p).begins_with("Stock"), "you can stock an unlabeled shelf: " + shelf.get_prompt(p))
	shelf.interact(p)
	check(shelf.is_labeled() and shelf.product_id == S0 and shelf.stock > 0, "the shelf is now labeled for %s" % Game.product_name(S0))
	await _frames(2)
	check(tips.current == "open", "then the tips say to open the store (now: %s)" % tips.current)
	var had := shelf.stock
	for i in had:
		shelf.take_one()
	check(shelf.stock == 0 and shelf.is_labeled(), "the label stays when the shelf sells out")
	check(not shelf.accepts(S1) and shelf.accepts(S0), "a labeled shelf only takes its own product")
	p.pick_up(S1, 6)
	check(not shelf.can_interact(p) and shelf.get_prompt(p).contains("labeled for"), "carrying something else: " + shelf.get_prompt(p))
	p.drop_carry()

	# ---- taking items off, peeling the label
	shelf.add_stock(S0, 5)
	check(shelf.can_interact(p) and shelf.get_prompt(p).begins_with("Take"), "empty hands: " + shelf.get_prompt(p))
	shelf.interact(p)
	check(p.carry_product == S0 and p.carry_count == 5 and shelf.stock == 0, "took the 5 items off into a box")
	check(shelf.is_labeled(), "the label is still there")
	shelf.interact(p)  # carrying a box of its product: puts them back
	check(shelf.stock == 5 and not p.is_carrying(), "and you can put them back")
	shelf.interact(p)  # take them off again...
	p.drop_carry()  # ...and get rid of the box
	check(shelf.can_interact(p) and shelf.get_prompt(p).begins_with("Remove"), "an empty labeled shelf: " + shelf.get_prompt(p))
	var secs := shelf.get_action_time(p)
	shelf.interact(p)
	check(not shelf.is_labeled() and shelf.accepts(S1), "peeled the label off: it takes anything now (took %.2fs)" % secs)
	check(not shelf.can_interact(p) and shelf.get_prompt(p).contains("no label"), "nothing left to do with it: " + shelf.get_prompt(p))
	p.pick_up(S0, 4)
	shelf.interact(p)

	# ---- a box on the floor wins over taking things off a shelf
	for b: StockBox in store.boxes.values():
		store.remove_box(b)
	var stand := store.stand_cell_for(shelf.cell, shelf.cell)
	store.drop_box(stand, S1, 6)
	p.position = Iso.cell_to_world(stand)
	await _frames(3)
	check(p.focused is StockBox, "standing on a box next to a stocked shelf, E picks up the box")
	for b: StockBox in store.boxes.values():
		store.remove_box(b)
	await _frames(3)
	check(p.focused == shelf or p.focused is Shelf, "with no box there, E uses the shelf")

	# ---- stockers follow the labels
	for s in store.shelves:
		if s != shelf and not s.holds_cold():
			s.product_id = S1
			s.stock = Shelf.CAPACITY
			s.queue_redraw()
	shelf.stock = 0  # empty, still labeled for S0
	check(shelf.product_id == S0, "test shelf labeled %s and empty" % Game.product_name(S0))
	Game.hire("stocker")
	store.place_box(S1)
	for i in 900:
		await get_tree().physics_frame
	check(shelf.stock == 0, "the stocker doesn't put %s on a shelf labeled %s" % [Game.product_name(S1), Game.product_name(S0)])
	store.place_box(S0)
	for i in 1500:
		await get_tree().physics_frame
		if shelf.stock > 0:
			break
	check(shelf.stock > 0 and shelf.product_id == S0, "but refills it with %s" % Game.product_name(S0))

	# ---- labels are saved
	shelf.stock = 0
	var saved := store.to_dict()
	var entry: Dictionary = {}
	for f in saved.furniture:
		if Store._to_cell(f.cell) == shelf.cell:
			entry = f
	check(entry.get("product") == S0 and int(entry.get("stock", -1)) == 0, "an empty labeled shelf saves its label")

	# ---- the rest of the tips
	Game.open_store()
	await _frames(2)
	check(tips.current == "register", "once open, the tips explain the register (now: %s)" % tips.current)
	tips._skip()
	await _frames(2)
	check(tips.current != "register" and Game.tutorial.has("register"), "Next tip moves on (now: %s)" % tips.current)
	var game_save := Game.to_dict()
	check((game_save.tutorial as Array).has("register"), "tip progress is saved")
	tips._hide_all()
	await _frames(2)
	check(not tips.visible and Game.tutorial_hidden, "Hide tips hides them")
	Game.tutorial_hidden = false
	Game.day = 2
	await _frames(2)
	check(not tips.visible, "no tips after the first day")

	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
