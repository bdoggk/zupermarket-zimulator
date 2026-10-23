extends Node
# First person: V switches to it and back (remembered), the 3D store
# matches the 2D one (floor, walls, shelves with their stock, people),
# walking goes the way you look (arrows turn, the mouse and right stick
# look), E uses what you're looking at, a tap walks there, build mode
# switches back to the view from above for a while, and popups land on
# the right spot on the screen.
#   godot --headless --path . --fixed-fps 60 res://tests/fp_test.tscn

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	var was_setting := Settings.first_person
	Settings.first_person = false  # (starts in the view from above)
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(4)
	var hud: Node = main.get_node("HUD")
	var store: Store = Game.store
	var p: Player = Game.player
	var fp: FirstPerson = Game.fp
	Game.tutorial_hidden = true
	Game.money = 5000.0

	check(fp != null and not fp.active and store.visible, "the store starts in the normal view")
	await _key(KEY_V)
	check(fp.active and not store.visible and fp.layer.visible, "V: first person (the 2D store is hidden, the 3D one shows)")
	check(Settings.first_person, "and it's remembered for next time")
	check(hud.view_button.text == "3rd" and not hud.zoom_buttons[0].visible, "the View button says 3rd, and the zoom buttons go")
	await _frames(3)

	# ---- the 3D store matches the 2D one
	var kinds := {}
	for m: Array in fp._mirrors.values():
		kinds[m[1]] = int(kinds.get(m[1], 0)) + 1
	check(kinds.get("shelf", 0) == store.shelves.size(), "every shelf and cooler is there (%d)" % kinds.get("shelf", 0))
	check(kinds.get("wall", 0) >= store.wall_cells.size(), "every wall (%d, %d in the store)" % [kinds.get("wall", 0), store.wall_cells.size()])
	var tiles := 0
	for mmi in fp._floor.get_children():
		if mmi is MultiMeshInstance3D and (mmi as MultiMeshInstance3D).position.y == 0.0:
			tiles += mmi.multimesh.instance_count
	var floor_tiles := 0
	for mmi in fp._floor.get_children():
		if mmi is MultiMeshInstance3D and mmi.material_override is StandardMaterial3D and mmi.material_override.albedo_texture != null:
			floor_tiles += mmi.multimesh.instance_count
	check(floor_tiles == store.floor_layer.tiles().size(), "every floor tile, the town's too (%d)" % floor_tiles)
	var cam := fp.camera.position
	var g := FirstPerson.iso_to_grid(p.position)
	check(absf(cam.x - g.x) < 0.01 and absf(cam.z - g.y) < 0.01 and absf(cam.y - FirstPerson.EYE) < 0.05, "the camera is your eyes: %s" % cam)
	# A shelf's stock shows: change it and its front is redrawn.
	var sh: Shelf = store.shelves[0]
	var before: Node3D = fp._mirrors[sh.get_instance_id()][2]
	sh.product_id = Game.unlocked_ids()[0]
	sh.stock = 7
	await _frames(fp.RESYNC_EVERY + 2)
	var after: Node3D = fp._mirrors[sh.get_instance_id()][2]
	check(after != before and is_instance_valid(after), "stocking a shelf shows on it")

	# ---- walking the way you look
	var spot := _open_spot(store)
	p.position = Iso.cell_to_world(spot)
	p.path.clear()
	fp.yaw = 0.0  # looking toward -y on the map
	await _frames(2)
	var from := FirstPerson.iso_to_grid(p.position)
	await _hold("move_up", 20)
	var moved := FirstPerson.iso_to_grid(p.position) - from
	check(moved.y < -0.3 and absf(moved.x) < 0.1, "W walks the way you look: %s" % moved)
	p.position = Iso.cell_to_world(spot)
	fp.yaw = PI / 2.0  # toward -x
	await _frames(2)
	from = FirstPerson.iso_to_grid(p.position)
	await _hold("move_up", 20)
	moved = FirstPerson.iso_to_grid(p.position) - from
	check(moved.x < -0.3 and absf(moved.y) < 0.1, "turned a quarter: W goes that way: %s" % moved)
	p.position = Iso.cell_to_world(spot)
	fp.yaw = 0.0
	await _frames(2)
	from = FirstPerson.iso_to_grid(p.position)
	await _hold("move_right", 20)
	moved = FirstPerson.iso_to_grid(p.position) - from
	check(moved.x > 0.3 and absf(moved.y) < 0.1, "D steps to the right: %s" % moved)
	# Left / Right arrows turn instead of stepping.
	p.position = Iso.cell_to_world(spot)
	await _frames(2)
	from = FirstPerson.iso_to_grid(p.position)
	var yaw0 := fp.yaw
	_physical(KEY_LEFT, true)
	await _frames(20)
	_physical(KEY_LEFT, false)
	await _frames(2)
	check(fp.yaw > yaw0 + 0.3 and FirstPerson.iso_to_grid(p.position).distance_to(from) < 0.05, "Left arrow turns you left (not a step): %.2f -> %.2f" % [yaw0, fp.yaw])
	# The mouse and the right stick look around.
	yaw0 = fp.yaw
	fp.look_by(Vector2(100, 0) * FirstPerson.MOUSE_LOOK)
	check(fp.yaw < yaw0, "the mouse looks around")
	var pitch0 := fp.pitch
	fp.look_by(Vector2(0, 10000))
	check(fp.pitch >= -FirstPerson.MAX_PITCH - 0.001 and fp.pitch < pitch0, "but not further than straight down")
	fp.pitch = -0.05
	yaw0 = fp.yaw
	var stick := InputEventJoypadMotion.new()
	stick.device = 0
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 1.0
	Input.parse_input_event(stick)
	await _frames(10)
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	await _frames(1)
	check(fp.yaw < yaw0 - 0.1, "the right stick looks around (%.2f -> %.2f)" % [yaw0, fp.yaw])

	# ---- E uses what you're looking at
	var north := spot + Vector2i(0, -1)
	var south := spot + Vector2i(0, 1)
	var a: Shelf = store.add_furniture("shelf", north) if store.placement_error(north, "shelf") == "" else null
	var b: Shelf = store.add_furniture("shelf", south) if store.placement_error(south, "shelf") == "" else null
	check(a != null and b != null, "(two shelves, either side of you)")
	if a and b:
		store.layout_changed()
		for s in [a, b]:
			s.product_id = Game.unlocked_ids()[0]
			s.stock = 5
		p.position = Iso.cell_to_world(spot)
		fp.yaw = 0.0  # toward north (-y)
		await _frames(4)
		check(p.focused == a, "looking at one shelf: E would use it (%s)" % p.focused)
		fp.yaw = PI  # turn around
		await _frames(4)
		check(p.focused == b, "turn around: the other one")
		check(hud.prompt_label.text != "", "with the prompt: " + hud.prompt_label.text)
		# Popups float over what they're about, wherever it is on the screen.
		var mid: Vector2 = get_viewport().get_visible_rect().size / 2.0
		var over_b: Vector2 = hud._world_to_ui(b.position + Vector2(0, -60)) * hud.transform.get_scale()
		check(absf(over_b.x - mid.x) < 40.0 and over_b.y < mid.y and over_b.y > 0.0, "a popup over the shelf you're facing is above the middle, on the screen: %s" % over_b)
		var over_a: Vector2 = hud._world_to_ui(a.position + Vector2(0, -60))
		check(over_a.x < -1000.0, "and one behind you is off the screen")
		for s in [a, b]:
			s.stock = 0
			s.product_id = ""
			store.remove_furniture(s)
		store.layout_changed()

	# ---- a tap on the floor walks there
	p.position = Iso.cell_to_world(spot)
	p.path.clear()
	fp.yaw = 0.0
	fp.pitch = -0.6  # looking down at the floor ahead
	await _frames(3)
	fp.tap(get_viewport().get_visible_rect().size / 2.0)
	check(not p.path.is_empty() and p.path[-1].y < spot.y, "a tap on the floor ahead walks you there: %s" % [p.path])
	p.path.clear()
	fp.pitch = -0.05

	# ---- build mode is seen from above
	Game.build_mode.enter()
	await _frames(3)
	check(not fp.active and store.visible, "build mode: the view from above")
	Game.build_mode.exit()
	await _frames(3)
	check(fp.active and not store.visible, "done building: first person again")

	# ---- holding things
	p.pick_up(Game.unlocked_ids()[0], 4)
	await _frames(2)
	check(fp.crosshair.visible, "(the crosshair and what you hold show)")
	p.drop_carry()

	# ---- back to the normal view
	await _key(KEY_V)
	check(not fp.active and store.visible and not fp.layer.visible and not Settings.first_person, "V again: back to the view from above")
	check(hud.view_button.text == "1st" and hud.zoom_buttons[0].visible, "(View says 1st, zoom's back)")
	hud.view_button.pressed.emit()
	await _frames(2)
	check(fp.active, "the View button works too")
	hud.view_button.pressed.emit()
	await _frames(2)

	Settings.set_first_person(was_setting)
	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


## A walkable cell with room all around it.
func _open_spot(store: Store) -> Vector2i:
	var best := Vector2i(6, 6)
	for c: Vector2i in store.floor_cells:
		var ok := store.is_walkable(c) and not store.boxes.has(c)
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				ok = ok and store.is_walkable(c + Vector2i(dx, dy)) and not store.delivery_cells.has(c + Vector2i(dx, dy))
		if ok:
			return c
	return best


func _hold(action: String, frames: int) -> void:
	Input.action_press(action)
	await _physics(frames)
	Input.action_release(action)
	await _frames(2)


func _physical(k: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = down
	Input.parse_input_event(e)


func _key(k: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(2)


func _physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
