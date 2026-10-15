extends Node
# Stress test for customers getting stuck. Runs a busy store for a long time,
# keeps shelves stocked, serves the register, and (with SHUFFLE=1) keeps
# moving furniture around like a player in build mode. Reports any customer
# that stops moving while it should be walking, stands inside furniture, or
# never leaves.
#   SHUFFLE=1 MINUTES=20 godot --headless --path . --fixed-fps 60 res://tests/stuck_test.tscn

const STILL_LIMIT := 8.0  # seconds without moving while walking = stuck
const LIFE_LIMIT := 150.0  # seconds in the store = stuck

var store: Store
var shuffle := OS.get_environment("SHUFFLE") == "1"
var minutes := float(OS.get_environment("MINUTES")) if OS.get_environment("MINUTES") != "" else 10.0
var elapsed := 0.0
var watch := {}  # Customer -> {pos, still, age, reported}
var staff_watch := {}  # Staff -> {pos, still, reported}
var problems := 0
var spawned := 0
var shuffle_timer := 3.0
var serve_timer := 0.0
var longest_line := 0
var browsing := 0.0


func _ready() -> void:
	seed(int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 5)
	Engine.max_fps = 0
	Engine.time_scale = 4.0
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	store = Game.store
	Game.money = 100000.0
	Game.add_xp(2000.0)  # level 5: up to 9 customers at once
	for id in Game.PRODUCTS:
		if Game.can_license(id):
			Game.buy_license(id)
	for c in [Vector2i(9, 4), Vector2i(10, 4), Vector2i(11, 4), Vector2i(9, 7), Vector2i(10, 7), Vector2i(11, 7)]:
		store.add_furniture("shelf" if c.y == 4 else "fridge", c)
	store.layout_changed()
	if OS.get_environment("STAFF") == "1":
		for c in [Vector2i(3, 9), Vector2i(12, 3), Vector2i(2, 4)]:
			if store.placement_error(c, "register") == "":
				store.add_furniture("register", c)
				store.layout_changed()
		for role in ["stocker", "stocker", "cashier", "cashier", "cashier"]:
			Game.hire(role)
		print("registers: %d, staff: %d" % [store.registers.size(), Game.staff.size()])
	_restock()
	Game.open_store()


func _process(delta: float) -> void:
	if Game.store == null:
		return
	elapsed += delta
	if elapsed > minutes * 60.0:
		print("RESULT: %d problem(s), %d customers spawned, %d still in store, longest line %d, walkouts %d, customer-seconds spent browsing %.0f" % [problems, spawned, store.customers.size(), longest_line, Game.stats.walkouts, browsing])
		get_tree().quit(1 if problems > 0 else 0)
		return
	# endless day
	Game.minute = 12 * 60
	if OS.get_environment("STAFF") == "1":
		if store.boxes.size() < 3 and randf() < 0.02:
			store.place_box(Game.unlocked_ids().pick_random())
	else:
		_restock()
	serve_timer -= delta
	if serve_timer <= 0.0 and OS.get_environment("STAFF") != "1":
		serve_timer = float(OS.get_environment("SERVE")) if OS.get_environment("SERVE") != "" else 1.5
		var c := store.register.front_customer()
		if c:
			store.register.interact(Game.player)
	var max_c := int(OS.get_environment("MAXC")) if OS.get_environment("MAXC") != "" else store.max_customers()
	if store.customers.size() < max_c:
		store.spawn_customer()
	if shuffle:
		shuffle_timer -= delta
		if shuffle_timer <= 0.0:
			shuffle_timer = randf_range(1.0, 4.0)
			_shuffle_one()
	_watch(delta)


func _restock() -> void:
	var ids := Game.unlocked_ids()
	for i in store.shelves.size():
		var s: Shelf = store.shelves[i]
		if s.stock < 3:
			var pool := ids.filter(func(id): return Game.is_cold(id) == s.holds_cold())
			s.product_id = pool[i % pool.size()]
			s.stock = Shelf.CAPACITY
			s.queue_redraw()


## Moves a random piece of furniture somewhere legal, like build mode does.
func _shuffle_one() -> void:
	var furniture: Array = store.objects.values().filter(func(o): return o.is_movable())
	if furniture.is_empty():
		return
	var obj: Interactable = furniture.pick_random()
	var cells: Array = store.floor_cells.keys()
	cells.shuffle()
	for c: Vector2i in cells.slice(0, 40):
		if c != obj.cell and store.placement_error(c, obj.furniture_id, obj) == "":
			store.move_furniture(obj, c)
			return


func _watch(delta: float) -> void:
	longest_line = maxi(longest_line, store.register.line.size())
	var alive := {}
	for c: Customer in store.customers:
		alive[c] = true
		if not watch.has(c):
			watch[c] = {"pos": c.position, "still": 0.0, "age": 0.0, "reported": false}
			spawned += 1
		var w: Dictionary = watch[c]
		w.age += delta
		var st: String = Customer.State.keys()[c.state]
		if not w.has("states"):
			w.states = {}
		w.states[st] = snappedf(w.states.get(st, 0.0) + delta, 0.1)
		if c.position.distance_to(w.pos) > 0.5 or w.get("state", -1) != c.state:
			w.still = 0.0
			w.pos = c.position
			w.state = c.state
		else:
			w.still += delta
		var why := ""
		if store.astar.is_point_solid(c.current_cell()) and c.state != Customer.State.ENTERING:
			why = "standing inside something solid"
		elif w.state == Customer.State.WAIT_FOR_LINE:
			browsing += delta
		if why != "":
			pass
		elif c.state != Customer.State.IN_LINE and w.still > STILL_LIMIT:
			why = "standing still for %.0fs" % w.still
		elif c.state == Customer.State.IN_LINE and c.current_cell() != c.register.spot(c.line_index):
			why = "in line but not on their spot"
		elif w.age > LIFE_LIMIT * (c.max_patience / Customer.PATIENCE) / minf(1.0, c.speed / Customer.SPEED):
			# (slow or extra-patient kinds of shoppers get longer)
			why = "in the store for %.0fs" % w.age
		if why != "" and not w.reported:
			w.reported = true
			problems += 1
			print("STUCK [%.0fs]: %s | %s with %d items | state=%s cell=%s path=%s line=%d list=%s target=%s patience=%.0f | time per state %s" % [
				elapsed, why, c.kind.get("name", "?"), c.item_count(), Customer.State.keys()[c.state], c.current_cell(), c.path,
				c.line_index, c.shopping_list, c.target_shelf.cell if is_instance_valid(c.target_shelf) else "-", c.patience, w.get("states", {})])
		if w.reported and w.get("traced", 0) < 4 and OS.get_environment("TRACE") == "1":
			w.traced = w.get("traced", 0) + 1
			var tgt: Vector2 = Iso.cell_to_world(c.path[0]) if not c.path.is_empty() else c.position
			print("   trace state=%s pos=%s path=%s target=%s line=%d line_list=%s serving=%s busy=%s" % [
				Customer.State.keys()[c.state], c.position, c.path, tgt, c.line_index,
				store.register.line.map(func(x): return [x.line_index, Customer.State.keys()[x.state], x.current_cell()]),
				store.register.is_serving(c), Game.player.is_busy()])
	for s in store.staff:
		if not staff_watch.has(s):
			staff_watch[s] = {"pos": s.position, "still": 0.0, "reported": false}
		var w: Dictionary = staff_watch[s]
		if s.position.distance_to(w.pos) > 0.5 or s.path.is_empty():
			w.still = 0.0
			w.pos = s.position
		else:
			w.still += delta
		if w.still > STILL_LIMIT and not w.reported:
			w.reported = true
			problems += 1
			print("STAFF STUCK [%.0fs]: %s the %s, job=%s cell=%s path=%s" % [elapsed, s.staff_name, s.role, Staff.Job.keys()[s.job], s.current_cell(), s.path])
		if store.astar.is_point_solid(s.current_cell()) and not w.get("solid", false):
			w.solid = true
			problems += 1
			print("STAFF INSIDE SOMETHING: %s at %s" % [s.staff_name, s.current_cell()])
	for c in watch.keys():
		if not alive.has(c):
			watch.erase(c)
