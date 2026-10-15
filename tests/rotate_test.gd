extends Node
# Checks turning things in build mode (shelves, registers and their lines,
# the sign, the delivery zone), the bigger delivery zone upgrades, saving
# and loading all of it, and shoppers turning back when the store closes
# before they get there.
#   godot --headless --path . --fixed-fps 60 res://tests/rotate_test.tscn

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	seed(777)
	Engine.max_fps = 0
	Engine.time_scale = 4.0
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	var store: Store = Game.store
	var b: BuildMode = Game.build_mode
	Game.money = 20000.0
	Game.tutorial_hidden = true

	# ---- how things are drawn each way
	var shelf_tex: Texture2D = Game.FURNITURE.shelf.texture
	var v := []
	for i in 4:
		v.append(Interactable.view_of(shelf_tex, i))
	check(v[0][0] == shelf_tex and not v[0][1], "a shelf facing you is drawn from the front")
	check(v[1][0] == shelf_tex and v[1][1], "turned once: the front, mirrored")
	check(v[2][0].resource_path.ends_with("shelf_back.png") and not v[2][1], "turned around: you see its back")
	check(v[3][0] == v[2][0] and v[3][1], "and once more: the back, mirrored")
	var sign_views := []
	for i in 4:
		sign_views.append(Interactable.view_of(OpenSign.OPEN_TEX, i))
	check(sign_views.all(func(sv): return not sv[1]), "the sign is never mirrored (its letters would read backwards)")
	check(sign_views[1][0].resource_path.ends_with("sign_open_r1.png") and sign_views[3][0] == sign_views[1][0], "it has its own art for facing the other way")
	var rack := Interactable.view_of(Game.FURNITURE.storage.texture, 2)
	check(rack[0] == Game.FURNITURE.storage.texture and not rack[1], "a rack looks the same from behind (it's open)")
	for id: String in Game.FURNITURE:
		var tex: Texture2D = Game.FURNITURE[id].texture
		var different := {}
		for i in 4:
			var view := Interactable.view_of(tex, i)
			different["%s/%s" % [view[0].resource_path, view[1]]] = true
		check(different.size() >= 2, "%s looks different when it's turned (%d ways)" % [Game.FURNITURE[id].name, different.size()])

	# ---- the Rotate tool
	b.enter()
	await _frames(2)
	var shelf: Shelf = store.shelves[0]
	b.select_tool(BuildMode.Tool.ROTATE)
	var steps := []
	for i in 4:
		b.tap(shelf.position)
		steps.append(shelf.rotation_step)
	check(steps == [1, 2, 3, 0], "clicking a shelf with Rotate turns it a quarter turn each time %s" % [steps])
	b.tap(shelf.position)
	check(shelf.rotation_step == 1 and shelf.mirrored() and shelf.shows_front(), "facing the other way, its items still show")
	b.tap(shelf.position)
	check(not shelf.shows_front(), "turned away, you see its back")

	# ---- R while placing something
	b.select_place("shelf")
	var spot := _free_cell(store, Vector2i(9, 4), "shelf")
	b._set_cursor(spot)
	_press_r()
	await _frames(1)
	check(b.place_rotation == 1 and b.held_step() == 1, "R turns the shelf you're placing")
	_press_r()
	await _frames(1)
	check(b.held_step() == 2, "and again")
	b.tap(Iso.cell_to_world(spot))
	var placed: Interactable = store.objects.get(spot)
	check(placed is Shelf and placed.rotation_step == 2, "it's bought facing that way")

	# ---- R with nothing in hand turns what's under the mouse
	b.select_tool(BuildMode.Tool.NONE)
	b._hover_pos = placed.position
	_press_r()
	await _frames(1)
	check(placed.rotation_step == 3, "R over something turns it")

	# ---- moving and turning at once
	b.select_tool(BuildMode.Tool.MOVE)
	b.tap(placed.position)
	check(b.moving == placed, "picked it up")
	_press_r()
	await _frames(1)
	var spot2 := _free_cell(store, Vector2i(10, 6), "shelf", placed)
	b._set_cursor(spot2)
	b.tap(Iso.cell_to_world(spot2))
	check(placed.cell == spot2 and placed.rotation_step == 0, "moved it and turned it (now %d)" % placed.rotation_step)
	b.tap(placed.position)
	_press_r()
	await _frames(1)
	b.tap(placed.position)
	check(placed.cell == spot2 and placed.rotation_step == 1, "putting it back down where it was, turned, just turns it")

	# ---- a register's line turns with it
	var reg := store.register
	var facing0 := reg.facing
	check(reg.rotation_step == Interactable.FACINGS.find(reg.facing), "the register faces its line")
	b.select_tool(BuildMode.Tool.ROTATE)
	b.tap(reg.position)
	check(reg.facing != facing0, "turning the register turns its line (%s -> %s)" % [facing0, reg.facing])
	check(reg.line_cells.size() == store.line_length and reg.line_cells[0] == reg.cell + reg.facing, "the line starts on the side it faces now")
	check(reg.rotation_step == Interactable.FACINGS.find(reg.facing), "and the register is drawn facing it")
	check(reg.line_cells.all(func(c): return store.is_walkable(c) and not c in store.delivery_cells and c != store.door_cell), "the new line is on open floor")
	# Block one side: turning skips the way the line can't go.
	var blocker_cell := reg.cell + Interactable.FACINGS[(reg.rotation_step + 1) % 4]
	if store.placement_error(blocker_cell, "plant") == "":
		var blocker := store.add_furniture("plant", blocker_cell)
		store.layout_changed()
		var blocked_step := (reg.rotation_step + 1) % 4
		check(store.rotate_error(reg, blocked_step) != "", "a register can't face something in the way: " + store.rotate_error(reg, blocked_step))
		b.tap(reg.position)
		check(reg.rotation_step != blocked_step and reg.line_cells[0] == reg.cell + reg.facing, "turning it skips that way (faces %s now)" % reg.facing)
		store.remove_furniture(blocker)
	# Shoppers still find the line.
	b.exit()
	await _frames(2)
	var S0 := TestIds.starter(0)
	for s in store.shelves:
		if not s.holds_cold():
			s.product_id = S0
			s.stock = Shelf.CAPACITY
	Game.open_store()
	store.spawn_timer = 9999.0
	var shopper := store.spawn_customer(Brand.SHOPPERS.zombie, [{"id": S0, "qty": 1}])
	var lined_up := false
	for i in 5000:
		await get_tree().physics_frame
		if reg.front_customer() == shopper:
			lined_up = true
			break
	check(lined_up and shopper.current_cell() == reg.line_cells[0], "a shopper lines up on the turned line")
	var served: int = Game.stats.customers
	reg.checkout()
	check(Game.stats.customers == served + 1, "and pays")

	# ---- shoppers on their way when the store closes turn back
	var late := store.spawn_customer(Brand.SHOPPERS.zombie, [{"id": S0, "qty": 1}])
	check(late.state == Customer.State.ARRIVING, "a shopper sets off from the edge of town")
	await _frames(2)
	Game.minute = Game.CLOSE_MINUTE
	var got_in := false
	var turned_back := false
	for i in 1500:
		await get_tree().physics_frame
		if not is_instance_valid(late):
			break
		if late.state in [Customer.State.WALKING_AWAY, Customer.State.EXITING]:
			turned_back = true
		if store.floor_cells.has(late.current_cell()):
			got_in = true
	check(turned_back, "when the store closes, they turn around")
	check(not got_in, "and never come in after closing")
	check(not is_instance_valid(late) or not store.customers.has(late), "they don't hold up the end of the day")
	for i in 600:
		await get_tree().physics_frame
		if Game.day_over:
			break
	check(Game.day_over, "the day ends once the last shopper inside has left")
	Game.start_next_day()
	await _frames(2)

	# ---- turning the sign and the delivery zone
	b.enter()
	await _frames(2)
	b.turn(store.sign)
	check(store.sign.rotation_step == 1, "the sign turns")
	var zone_boxes := store.boxes.values().filter(func(x): return x.cell in store.delivery_cells).size()
	check(store.delivery_size == Vector2i(3, 2) and store.delivery_cells.size() == 6, "the delivery zone starts 3 by 2")
	var problem := store.rotate_error(store.delivery_zone, 1)
	check(problem == "", "the delivery zone can turn where it is " + problem)
	b.turn(store.delivery_zone)
	check(store.delivery_size == Vector2i(2, 3) and store.delivery_turned, "turned: now 2 by 3")
	check(store.delivery_cells.size() == 6 and store.boxes.values().filter(func(x): return x.cell in store.delivery_cells).size() == zone_boxes, "the boxes on it stay on it (%d)" % zone_boxes)
	b.turn(store.delivery_zone)
	check(store.delivery_size == Vector2i(3, 2) and not store.delivery_turned, "and back")
	# Moving it turned (R while carrying it).
	b.select_tool(BuildMode.Tool.MOVE)
	b.tap(Iso.cell_to_world(store.delivery_cells[0]))
	check(b.moving == store.delivery_zone, "picked up the delivery zone")
	_press_r()
	await _frames(1)
	check(b.zone_size == Vector2i(2, 3), "R turns it while you carry it")
	b._set_cursor(b.cursor)
	b.tap(Iso.cell_to_world(b.cursor))
	check(store.delivery_size == Vector2i(2, 3), "and it's put down turned")
	b.turn(store.delivery_zone)
	b.exit()

	# ---- bigger delivery zones
	Game.level = 1
	check(Game.upgrade_problem("zone_1") == "Store level 2", "the first bigger zone needs store level 2: " + Game.upgrade_problem("zone_1"))
	Game.level = 2
	check(Game.upgrade_problem("zone_2") != "", "the next one needs the first: " + Game.upgrade_problem("zone_2"))
	var money := Game.money
	check(Game.upgrade_problem("zone_1") == "" and Game.buy_upgrade("zone_1"), "bought the Bigger Delivery Zone")
	check(is_equal_approx(money - Game.money, Game.UPGRADES.zone_1.cost), "it cost $%d" % int(money - Game.money))
	check(store.delivery_cells.size() == 9 and store.delivery_size == Vector2i(3, 3), "room for 9 boxes")
	Game.level = 3
	check(Game.buy_upgrade("zone_2") and store.delivery_cells.size() == 12, "the Loading Bay: room for 12")
	Game.level = 4
	problem = Game.upgrade_problem("zone_3")
	check(problem.contains("in the way"), "the biggest zone needs space cleared: " + problem)
	var in_way: Interactable = null
	for c in Store._rect_cells(store.delivery_anchor(), Vector2i(4, 4)):
		if store.objects.has(c):
			in_way = store.objects[c]
	if in_way:
		store.move_object(in_way, _free_cell(store, Vector2i(10, 7), in_way.furniture_id, in_way))
	check(Game.upgrade_problem("zone_3") == "", "after moving the %s, it fits" % (in_way.display_name() if in_way else "?"))
	check(Game.buy_upgrade("zone_3") and store.delivery_cells.size() == 16, "the biggest zone: room for 16")
	var placed_boxes := 0
	for i in 20:
		if store.place_box(S0):
			placed_boxes += 1
	check(store.delivery_cells.all(func(c): return store.boxes.has(c)), "boxes fill the whole zone (%d placed)" % placed_boxes)
	check(not Game.UPGRADES.keys().filter(func(id): return id.begins_with("zone")).any(func(id): return Game.upgrade_problem(id) == ""), "all bought")

	# ---- saving and loading keeps which way everything faces
	b.enter()
	await _frames(1)
	b.turn(store.computer)
	b.turn(store.mop_bucket)
	b.turn(store.mop_bucket)
	b.exit()
	var game_save := Game.to_dict()
	var store_save := store.to_dict()
	var placed_cell := placed.cell
	var placed_step := placed.rotation_step
	var reg_facing := reg.facing
	var anchor := store.delivery_anchor()
	check(store_save.fixtures.delivery.get("size") == [4, 4], "the save has the zone's size")
	check(store_save.fixtures.sign.get("rot") == 1, "and the sign's facing")
	main.queue_free()
	await _frames(3)
	Game.from_dict(game_save)
	Saves.pending_store = store_save
	main = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	store = Game.store
	check(store.delivery_size == Vector2i(4, 4) and store.delivery_anchor() == anchor and store.delivery_cells.size() == 16, "after loading: the big delivery zone is still there")
	var again: Interactable = store.objects.get(placed_cell)
	check(again is Shelf and again.rotation_step == placed_step, "the shelf still faces the same way (%d)" % (again.rotation_step if again else -1))
	check(store.sign.rotation_step == 1 and store.computer.rotation_step == 1 and store.mop_bucket.rotation_step == 2, "so do the sign, computer and mop bucket")
	check(store.register.facing == reg_facing and store.register.rotation_step == Interactable.FACINGS.find(reg_facing), "and the register (and its line)")
	check(Game.has_upgrade("zone_3"), "the upgrades are saved")

	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


func _free_cell(store: Store, near: Vector2i, id: String, moving: Interactable = null) -> Vector2i:
	var cells: Array = store.floor_cells.keys()
	cells.sort_custom(func(a, c): return Vector2(a - near).length() < Vector2(c - near).length())
	for cell: Vector2i in cells:
		if store.placement_error(cell, id, moving) == "" and not store.spills.has(cell) and not store.boxes.has(cell):
			return cell
	return Store.NO_CELL


func _press_r() -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_R
		e.physical_keycode = KEY_R
		e.pressed = pressed
		get_viewport().push_input(e)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
