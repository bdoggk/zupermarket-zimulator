extends Node
# Can you always walk where the game says you can? Builds random store
# layouts, then walks you (the same way a click does) between random spots
# and checks you get there: never snagged on a corner, never stuck in a
# gap the path finder thinks is open. Also walks out into town and back.
#   SEED=1 LAYOUTS=6 godot --headless --path . --fixed-fps 60 res://tests/walk_test.tscn

var fails := 0
var walks := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		print("FAIL  " + what)
		fails += 1


func _ready() -> void:
	var s := int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 1
	seed(s)
	var layouts := int(OS.get_environment("LAYOUTS")) if OS.get_environment("LAYOUTS") != "" else 6
	Engine.max_fps = 0
	Engine.time_scale = 4.0
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	var store: Store = Game.store
	var p: Player = Game.player
	Game.tutorial_hidden = true
	Game.money = 100000.0
	Game.add_xp(5000.0)
	Game.buy_expansion()
	Game.buy_expansion()
	await _frames(2)
	for layout in layouts:
		# A random jumble of furniture (whatever build mode would allow).
		var ids: Array = Game.FURNITURE.keys()
		var cells: Array = store.floor_cells.keys()
		for i in 18:
			var id: String = ids.pick_random()
			var c: Vector2i = cells.pick_random()
			if store.placement_error(c, id, null, randi() % 4) == "":
				store.add_furniture(id, c, randi() % 4)
				store.layout_changed()
		# Move a few things around too.
		for i in 6:
			var movable := store.objects.values().filter(func(o): return o.is_movable())
			var obj: Interactable = movable.pick_random()
			var c: Vector2i = cells.pick_random()
			if store.placement_error(c, obj.furniture_id, obj) == "":
				store.move_object(obj, c)
		var inside: Array = store.reachable.keys().filter(func(c): return store.floor_cells.has(c))
		var outside: Array = store.reachable.keys().filter(func(c): return not store.floor_cells.has(c))
		for i in 25:
			var from: Vector2i = inside.pick_random()
			var to: Vector2i = inside.pick_random() if randf() < 0.8 else outside.pick_random()
			await _walk(p, store, from, to, randf() < 0.3)
		print("layout %d: %d objects, %d walks so far, %d failures" % [layout, store.objects.size(), walks, fails])
	print("RESULT: %d failure%s in %d walks" % [fails, "" if fails == 1 else "s", walks])
	get_tree().quit(1 if fails > 0 else 0)


## Puts you on `from` and walks you to `to` the way clicking the floor does.
func _walk(p: Player, store: Store, from: Vector2i, to: Vector2i, sprint: bool) -> void:
	p.cancel_action()
	p.path.clear()
	p.velocity = Vector2.ZERO
	p.position = Iso.cell_to_world(from)
	await _frames(2)
	if not store.is_walkable(to) or not store.reachable.has(to):
		return
	walks += 1
	p.run_toggle = sprint
	p.walk_to(to)  # what clicking that floor tile does (if nothing is drawn over it)
	var expected := store.find_path(from, to)
	var t := 0.0
	while not p.path.is_empty() and t < 60.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	await _frames(2)
	p.run_toggle = false
	if p.current_cell() != to:
		check(false, "walking %s -> %s ended on %s after %.1fs (path was %s)" % [from, to, p.current_cell(), t, expected])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
