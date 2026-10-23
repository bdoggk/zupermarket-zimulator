extends Node
# Driver for tests/chaos_test.gd. Lives under the root so it survives the
# scene changes when it saves and loads.
#
# Every few frames it does something random a player could do, and every
# few frames it checks the game for things that should never happen:
#   - script errors (caught with a Logger, printed with the last actions)
#   - things in the wrong place: furniture, boxes or puddles out of sync
#     with the store's maps, a box under furniture, stock over a shelf's
#     capacity, a register without a full line...
#   - stock appearing or vanishing (everything on shelves, in boxes, on
#     racks, carried and on the way only changes by what's ordered and what
#     shoppers put in their baskets)
#   - anyone stuck: shoppers standing still while they should walk, staff
#     stuck on a job, you stuck inside furniture, a day that never ends,
#     deliveries that never arrive although there's room, the rival's spies
#     hanging around or your spy never getting back
#   - leaks: the number of nodes keeps growing

const SLOT := 2
const CHECK_EVERY := 10  # frames
const HEAVY_CHECK_EVERY := 60

var rng := RandomNumberGenerator.new()
var speed := 4.0
var minutes := 60.0
var saveload := true
var mode := "chaos"  # or "staff": set up a big store with every kind of staff, then just watch
var touch := false  # TOUCH=1: a touch screen, with finger taps, slides and pinches too
var frame := 0
var game_time := 0.0
var failures := {}  # kind -> count
var errors := {}  # where -> count
var recent: Array[String] = []  # the last few actions
var counts := {}  # action -> how many times
var backups := {}
var settings_backup := ""
var busy := false  # an action is running (awaiting)
var changing_scene := false
var done := false

# Conservation of stock
var baseline := -1
var ordered := 0
var _taken_seen := 0  # Customer.items_taken last time
var _last_nonbasket := -1

# Stuck watching
var shopper_watch := {}  # instance id -> [position, still seconds, age seconds]
var player_in_wall := 0.0
var _stock_parts := {}  # where the stock was at the last check
var _trace: Customer = null  # print what this shopper does for a few frames
var _trace_frames := 0
var _had_room := 0  # checks in a row (unpaused) the delivery zone had room
var closing_time := 0.0
var max_world_nodes := 0
var max_hud_nodes := 0
var start_orphans := 0
var days_played := 0
var visits := 0  # Count Vlad came for your head (an unpaid loan)
var loads := 0

var store: Store
var p: Player
var hud: Node
var build: BuildMode
var logger: ErrorLog


class ErrorLog extends Logger:
	var driver: Node
	var mutex := Mutex.new()
	var queue: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtrace: Array[ScriptBacktrace]) -> void:
		var bt := ""
		for b in script_backtrace:
			if b and b.has_method("format"):
				bt += b.format()
		mutex.lock()
		queue.append([error_type, function, file, line, code, rationale, bt])
		mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> Array:
		mutex.lock()
		var q := queue
		queue = []
		mutex.unlock()
		return q


func _ready() -> void:
	Engine.max_fps = 0
	var env := OS.get_environment("SEED")
	rng.seed = int(env) if env != "" else 1
	seed(rng.seed)
	if OS.get_environment("MINUTES") != "":
		minutes = float(OS.get_environment("MINUTES"))
	if OS.get_environment("SPEED") != "":
		speed = float(OS.get_environment("SPEED"))
	saveload = OS.get_environment("SAVELOAD") != "0"
	if OS.get_environment("MODE") != "":
		mode = OS.get_environment("MODE")
	touch = OS.get_environment("TOUCH") == "1"
	if touch:
		Input.emulate_touch_from_mouse = true  # (a touch screen, like a phone: see touch_test.gd)
	logger = ErrorLog.new()
	logger.driver = self
	OS.add_logger(logger)
	_run()


func _run() -> void:
	if FileAccess.file_exists(Settings.PATH):
		settings_backup = FileAccess.get_file_as_string(Settings.PATH)
	for i in Saves.SLOTS:
		if FileAccess.file_exists(Saves.slot_path(i)):
			backups[i] = FileAccess.get_file_as_string(Saves.slot_path(i))
	Saves.new_game(SLOT)
	await _wait_for_store()
	Game.tutorial_hidden = true
	if mode == "staff":
		_set_up_big_store()
	Engine.time_scale = speed
	start_orphans = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var frames := int(minutes * 60.0 * 60.0 / speed)
	print("CHAOS seed %d: %.0f game minutes at %.0fx (%d frames)" % [rng.seed, minutes, speed, frames])
	while frame < frames:
		await get_tree().process_frame
		frame += 1
		_drain_errors()
		if changing_scene or not _bound():
			continue
		if not get_tree().paused:
			game_time += get_process_delta_time()
		if _trace_frames > 0 and is_instance_valid(_trace):
			_trace_frames -= 1
			if _trace_frames % 10 == 0:
				print("   trace f%d: %s pos %s cell %s path %s still %.2f timer %.2f" % [frame, Customer.State.keys()[_trace.state],
				_trace.position, _trace.current_cell(), _trace.path.slice(0, 3), _trace._still, _trace.timer])
		if frame % CHECK_EVERY == 0:
			_check(frame % HEAVY_CHECK_EVERY == 0)
		if not busy and frame % 6 == 0:
			busy = true
			await _act()
			busy = false
	_finish()


func _finish() -> void:
	done = true
	Engine.time_scale = 1.0
	_drain_errors()
	print("")
	print("CHAOS done: %d frames, %.0f game seconds, %d days, %d loads, %d visits from Count Vlad" % [frame, game_time, days_played, loads, visits])
	var acts := counts.keys()
	acts.sort()
	print("actions: " + ", ".join(acts.map(func(a): return "%s %d" % [a, counts[a]])))
	print("max nodes: world %d, hud %d; orphans %d -> %d" % [max_world_nodes, max_hud_nodes, start_orphans, Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
	if is_instance_valid(store):
		print("end state: day %d, level %d, $%.0f, %d staff, %d shelves, %d registers, %d racks, %d boxes, %d spills, %d expansions" % [
			Game.day, Game.level, Game.money, Game.staff.size(), store.shelves.size(), store.registers.size(),
			store.racks.size(), store.boxes.size(), store.spills.size(), Game.expansions])
	for k in errors:
		print("ERRORS x%d  %s" % [errors[k], k])
	for k in failures:
		print("FAILS x%d  %s" % [failures[k], k])
	print("RESULT: %d error kinds, %d failure kinds" % [errors.size(), failures.size()])
	# Put back the saves and settings this test used.
	for i in Saves.SLOTS:
		Saves.delete_slot(i)
		if backups.has(i):
			var f := FileAccess.open(Saves.slot_path(i), FileAccess.WRITE)
			f.store_string(backups[i])
			f.close()
	if settings_backup != "":
		var f := FileAccess.open(Settings.PATH, FileAccess.WRITE)
		f.store_string(settings_backup)
		f.close()
	get_tree().quit(1 if not errors.is_empty() or not failures.is_empty() else 0)


# ---------------------------------------------------------------- reporting

func _note(what: String) -> void:
	recent.append("[f%d d%d %s] %s" % [frame, Game.day, Game.clock_text(), what])
	if recent.size() > 14:
		recent.pop_front()
	var kind := what.split(" ")[0] if not what.begins_with("press") else what.substr(0, 7)
	counts[kind] = int(counts.get(kind, 0)) + 1


func _fail(kind: String, detail := "") -> void:
	var n := int(failures.get(kind, 0)) + 1
	failures[kind] = n
	if n <= 2:
		print("\nFAIL  %s  %s" % [kind, detail])
		print("   recent: \n     " + "\n     ".join(recent))


func _drain_errors() -> void:
	if logger == null:
		return
	for e in logger.take():
		var where := "%s:%d %s" % [e[2], e[3], e[4]]
		if done:
			continue
		var n := int(errors.get(where, 0)) + 1
		errors[where] = n
		if n <= 2:
			print("\nERROR (type %d) %s in %s\n   %s\n%s" % [e[0], e[4], e[1], e[5], e[6]])
			print("   recent: \n     " + "\n     ".join(recent))


# ---------------------------------------------------------------- binding

func _bound() -> bool:
	return is_instance_valid(store) and is_instance_valid(p) and store.is_inside_tree()


func _wait_for_store() -> void:
	changing_scene = true
	for i in 300:
		await get_tree().process_frame
		var s: Node = get_tree().current_scene
		if s and s.name == "Main" and is_instance_valid(Game.store) and Game.store.is_inside_tree() \
				and is_instance_valid(Game.store.player):
			break
	await get_tree().process_frame
	await get_tree().process_frame
	store = Game.store
	p = store.player
	hud = get_tree().current_scene.get_node("HUD")
	# Random clicks and taps mustn't quit the game or leave it for the main
	# menu (saving and loading is its own action).
	for b in hud.pause_menu.find_children("*", "Button", true, false):
		if (b as Button).text in ["Save & Quit", "Save & Main Menu"]:
			b.visible = false
	build = Game.build_mode
	baseline = -1
	shopper_watch = {}
	changing_scene = false
	if not Game.box_ordered.is_connected(_on_ordered):
		Game.box_ordered.connect(_on_ordered)
		Game.rival_bought.connect(func(): baseline = -1)
		Game.day_started.connect(func(_d): days_played += 1)


func _on_ordered(id: String) -> void:
	ordered += int(Game.PRODUCTS[id].box_size)


# ---------------------------------------------------------------- acting

func _pick(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += weights[k]
	var roll := rng.randf() * total
	for k in weights:
		roll -= weights[k]
		if roll <= 0.0:
			return k
	return weights.keys()[-1]


## Staff mode: a big store with every kind of staff working it, all
## products licensed, extra registers, self-checkouts and racks.
func _set_up_big_store() -> void:
	Game.money = 60000.0
	Game.add_xp(Game.xp_for_level(Game.LAST_UNLOCK_LEVEL) + 1.0)  # everything unlocked
	for id in Game.PRODUCTS:
		Game.buy_license(id)
	for id in Game.UPGRADES:
		Game.buy_upgrade(id)
	var wants := ["register", "register", "selfcheckout", "selfcheckout", "storage", "storage", "fridge", "fridge", "shelf", "shelf", "shelf", "lantern", "plant"] \
		+ Game.FURNITURE.keys().filter(func(id): return Game.FURNITURE[id].has("pulls"))
	var cells: Array = store.floor_cells.keys()
	cells.shuffle()
	for id: String in wants:
		for c: Vector2i in cells:
			if store.placement_error(c, id) == "":
				store.add_furniture(id, c)
				store.layout_changed()
				break
	for role in Game.STAFF:
		while Game.hire_problem(role) == "":
			Game.hire(role)
	Game.money = 3000.0
	print("big store: %d registers, %d shelves, %d racks, %d staff" % [store.registers.size(), store.shelves.size(), store.racks.size(), Game.staff.size()])


func _act() -> void:
	if is_instance_valid(hud.cutscene):
		await _vlad()
		return
	if mode == "staff":
		if Game.day_over and rng.randf() < 0.2:
			await _next_day()
		elif not Game.opened and not Game.day_over:
			_note("open the store")
			Game.store.sign.interact(p)
		if Game.money < 500.0:
			Game.money += 1000.0
		if saveload and rng.randf() < 0.002:
			await _save_load()
		return
	# Keep the days going.
	if Game.day_over and rng.randf() < 0.12:
		await _next_day()
		return
	if not Game.opened and not Game.day_over and rng.randf() < 0.3:
		_note("open the store")
		Game.store.sign.interact(p)
		return
	if Game.money < 150.0 and rng.randf() < 0.1:
		Game.money += 400.0
		_note("cash +$400")
	if rng.randf() < 0.004:
		Game.add_xp(rng.randf_range(100.0, 600.0))
		_note("xp boost -> level %d" % Game.level)
	# A storage rack's "which box?" list is up: pick one, or close it.
	if hud.rack_panel.visible and rng.randf() < 0.5:
		var rp: Node = hud.rack_panel
		var kinds: Array = rp.rack.products() if is_instance_valid(rp.rack) else []
		if kinds.is_empty() or rng.randf() < 0.25:
			_note("close the rack list")
			rp.close()
		else:
			var id: String = kinds[rng.randi() % kinds.size()]
			_note("take %s off the rack" % id)
			rp._take(id)
		return
	var what := _pick({
		"walk": 10.0, "tap": 14.0, "use": 10.0, "scan": 3.0, "stock": 8.0, "serve": 8.0,
		"mop": 5.0, "computer": 3.0, "build": 1.5, "shop": 1.5, "rival": 0.5, "pause": 0.5,
		"saveload": 0.5 if saveload else 0.0, "spawn": 2.0, "zoom": 1.0, "staff": 2.0, "teleport": 3.0,
		"settings": 0.4, "wait": 6.0, "click": 4.0, "key": 4.0, "wheel": 0.5, "spy": 1.0,
		"finger": 6.0 if touch else 0.0, "loan": 0.8, "view": 0.6,
	})
	match what:
		"view":
			if Game.fp:
				Game.fp.toggle()
				_note("first person %s" % ("on" if Game.fp.active else "off"))
				if Game.fp.active:
					Game.fp.yaw = rng.randf() * TAU
		"loan":
			_loan()
		"finger":
			_finger()
		"walk":
			var c := _random_reachable()
			_note("walk to %s" % c)
			p._on_tap(Iso.cell_to_world(c))
		"tap":
			var obj := _random_object()
			if obj:
				_note("tap %s at %s" % [_name(obj), obj.cell])
				p._on_tap(obj.position + Vector2(0, -12))
		"use":
			_note("press E (focus %s)" % (_name(p.focused) if is_instance_valid(p.focused) else "none"))
			p.try_interact()
		"scan":
			_note("press Q")
			p.try_scan()
		"stock":
			_stock()
		"serve":
			_serve()
		"mop":
			_mop()
		"computer":
			await _computer()
		"build":
			await _build()
		"shop":
			await _shop()
		"rival":
			await _rival()
		"pause":
			await _pause()
		"saveload":
			await _save_load()
		"spawn":
			if Game.is_open and store.customers.size() < 14:
				var kind: Dictionary = Brand.SHOPPERS.values()[rng.randi() % Brand.SHOPPERS.size()]
				_note("spawn %s" % kind.name)
				store.spawn_customer(kind)
		"zoom":
			p.zoom_by(1.25 if rng.randf() < 0.5 else 0.8)
		"spy":
			_spy()
		"staff":
			_staff()
		"teleport":
			var c := _random_reachable(true)
			_note("teleport to %s" % c)
			p.cancel_action()
			p.path.clear()
			p.position = Iso.cell_to_world(c)
		"settings":
			var g := rng.randi() % 3
			var k: float = Settings.UI_SCALES[rng.randi() % Settings.UI_SCALES.size()]
			_note("graphics %d, UI size %s" % [g, Settings.ui_scale_name(k)])
			Settings.set_graphics(g as Settings.Graphics)
			Settings.set_ui_scale(k)
		"wait":
			pass
		"click":
			var size: Vector2 = get_viewport().get_visible_rect().size
			var at := Vector2(rng.randf() * size.x, rng.randf() * size.y)
			_note("click at %s" % at.round())
			_click(at, MOUSE_BUTTON_LEFT if rng.randf() < 0.85 else MOUSE_BUTTON_RIGHT)
		"wheel":
			var size: Vector2 = get_viewport().get_visible_rect().size
			_click(Vector2(rng.randf() * size.x, rng.randf() * size.y), MOUSE_BUTTON_WHEEL_UP if rng.randf() < 0.5 else MOUSE_BUTTON_WHEEL_DOWN)
		"key":
			var keys := [KEY_E, KEY_E, KEY_Q, KEY_B, KEY_R, KEY_SPACE, KEY_ESCAPE, KEY_P, KEY_ENTER, KEY_TAB, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_3, KEY_V]
			var k: Key = keys[rng.randi() % keys.size()]
			_note("key %s" % OS.get_keycode_string(k))
			_key(k)
			await _frames(1)


func _name(obj: Object) -> String:
	if obj == null or not is_instance_valid(obj):
		return "nothing"
	if obj is Interactable and (obj as Interactable).furniture_id != "":
		return (obj as Interactable).furniture_id
	var s: Script = obj.get_script()
	return s.get_global_name() if s else obj.get_class()


func _random_reachable(inside_only := false) -> Vector2i:
	var cells: Array = store.reachable.keys()
	if inside_only or rng.randf() < 0.85:
		cells = cells.filter(func(c): return store.floor_cells.has(c))
	if cells.is_empty():
		return store.door_cell
	return cells[rng.randi() % cells.size()]


func _random_object() -> Interactable:
	var all: Array = store.objects.values() + store.boxes.values() + store.spills.values()
	if store.town and rng.randf() < 0.15:
		all.append_array(store.town.objects.values())
	all = all.filter(func(o): return is_instance_valid(o))
	if all.is_empty():
		return null
	return all[rng.randi() % all.size()]


## Stands next to `obj` and uses it (like walking up and pressing E).
func _go_use(obj: Interactable) -> void:
	if not is_instance_valid(obj):
		return
	var c := obj.cell if store.is_walkable(obj.cell) else store.stand_cell_for(obj.cell, p.current_cell())
	if c == Store.NO_CELL:
		return
	p.cancel_action()
	p.path.clear()
	p.position = Iso.cell_to_world(c)
	p.use(obj)


func _stock() -> void:
	if p.holding_mop:
		_note("stock: put the mop back")
		_go_use(store.mop_bucket)
		return
	if p.is_carrying():
		var options := store.shelves.filter(func(s): return s.accepts(p.carry_product) and s.stock < Shelf.CAPACITY)
		if not store.racks.is_empty() and rng.randf() < 0.2:
			options = store.racks
		if options.is_empty() or rng.randf() < 0.1:
			_note("stock: drop the box")
			p.try_interact()
			return
		var s: Interactable = options[rng.randi() % options.size()]
		_note("stock: %s on %s %s" % [p.carry_product, _name(s), s.cell])
		_go_use(s)
		return
	var sources: Array = store.boxes.values()
	for r in store.racks:
		if not r.boxes.is_empty():
			sources.append(r)
	if rng.randf() < 0.15:  # empty a shelf into a box
		sources = store.shelves.filter(func(s): return s.stock > 0 or s.is_labeled())
	if sources.is_empty():
		return
	var src: Interactable = sources[rng.randi() % sources.size()]
	_note("stock: take from %s %s" % [_name(src), src.cell])
	_go_use(src)


func _serve() -> void:
	var regs := store.registers.filter(func(r): return r.front_customer() != null or r.has_cashier())
	if regs.is_empty():
		return
	var r: Register = regs[rng.randi() % regs.size()]
	_note("serve at %s %s" % [_name(r), r.cell])
	_go_use(r)


func _mop() -> void:
	if not store.mop_bucket:
		return
	if not p.holding_mop:
		if p.is_carrying():
			return
		_note("mop: grab the mop")
		_go_use(store.mop_bucket)
		return
	if store.spills.is_empty() or rng.randf() < 0.2:
		_note("mop: put it back")
		_go_use(store.mop_bucket)
		return
	var sp: Spill = store.spills.values()[rng.randi() % store.spills.size()]
	_note("mop: spill at %s" % sp.cell)
	_go_use(sp)


func _staff() -> void:
	var roles: Array = Game.STAFF.keys()
	var r := rng.randf()
	if r < 0.5:
		var role: String = roles[rng.randi() % roles.size()]
		_note("hire %s (%s)" % [role, Game.hire_problem(role)])
		Game.hire(role)
	elif r < 0.7 and not Game.staff.is_empty():
		var e: Dictionary = Game.staff[rng.randi() % Game.staff.size()]
		_note("fire %s %s" % [e.role, e.name])
		Game.fire(e.id)
	elif not store.staff.is_empty():
		var s: Staff = store.staff[rng.randi() % store.staff.size()]
		_note("reset %s" % s.role)
		s.reset_to_start()


func _computer() -> void:
	_note("computer: open")
	hud.open_computer()
	await _frames(2)
	var pc: Node = hud.computer
	for i in rng.randi_range(1, 5):
		var r := rng.randf()
		if r < 0.25:
			var t: int = rng.randi() % pc.TAB_NAMES.size()
			_note("computer: app %d" % t)
			if rng.randf() < 0.5:
				pc.desktop_icons[t].pressed.emit()
			else:
				pc.show_tab(t)
		elif r < 0.4:
			var ids := Game.unlocked_ids()
			var id: String = ids[rng.randi() % ids.size()]
			_note("computer: order %s" % id)
			Game.order_box(id)
		elif r < 0.5 and not pc.price_fields.is_empty():
			var f: LineEdit = pc.price_fields[rng.randi() % pc.price_fields.size()]
			var text: String = ["3", "4.50", "$2.25", "abc", "", "-5", "0", "99999", "1,75", "  7 ", "1e3", "0.001"][rng.randi() % 12]
			_note("computer: type price '%s'" % text)
			f.grab_focus()
			f.text = text
			f.release_focus()
		elif r < 0.6:
			var ids: Array = Game.PRODUCTS.keys()
			var id: String = ids[rng.randi() % ids.size()]
			_note("computer: license %s (%s)" % [id, Game.can_license(id)])
			Game.buy_license(id)
		elif r < 0.7:
			var ids: Array = Game.UPGRADES.keys()
			var id: String = ids[rng.randi() % ids.size()]
			_note("computer: upgrade %s (%s)" % [id, Game.upgrade_problem(id)])
			Game.buy_upgrade(id)
		elif r < 0.8:
			_note("computer: match all")
			Game.match_all_prices()
		elif r < 0.85:
			_note("computer: auto price")
			pc.auto_button.button_pressed = not pc.auto_button.button_pressed
		elif r < 0.9:
			var ids := Game.unlocked_ids()
			var id: String = ids[rng.randi() % ids.size()]
			Game.change_price(id, Game.PRICE_STEP * (1 if rng.randf() < 0.5 else -1) * rng.randi_range(1, 8))
			_note("computer: nudge price %s -> %.2f" % [id, Game.prices[id]])
		else:
			_note("computer: home")
			pc.go_home()
		await _frames(rng.randi_range(1, 4))
	for i in 4:
		if pc.visible:
			hud._back()
			await _frames(1)
	_note("computer: closed (%s)" % ("still open!" if pc.visible else "ok"))


## Borrows from Count Vlad, pays some back, or (to see his visit in a
## short run) makes it due tonight.
func _loan() -> void:
	if Game.has_loan():
		var r := rng.randf()
		if r < 0.6:
			var amount: float = [Game.loan_behind(), float(Game.loan.payment), Game.loan_left(), rng.randf_range(1.0, 400.0)][rng.randi() % 4]
			_note("loan: pay $%.2f (owe $%.2f)" % [amount, Game.loan_left()])
			Game.pay_loan(amount)
		elif r < 0.8:
			_note("loan: make it due tonight (day %d)" % Game.day)
			Game.loan.due = Game.day
			Game.loan.day = Game.day - Game.LOAN_DAYS
	else:
		var amounts: Array = Game.LOAN_AMOUNTS.filter(func(a): return float(a) <= Game.loan_limit())
		var a := float(amounts[rng.randi() % amounts.size()])
		_note("loan: borrow $%d (%s)" % [int(a), Game.loan_problem(a)])
		Game.take_loan(a)


## Count Vlad's here: let it play (with the odd key press, click or Esc),
## then start over, and pick up the new store.
func _vlad() -> void:
	var c: Node = hud.cutscene
	visits += 1
	_note("Count Vlad's visit (day %d, owed $%.2f)" % [Game.day, Game.loan_left()])
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(c) and not c.card.visible:
		if Time.get_ticks_msec() - t0 > 120000:
			_fail("Count Vlad's visit never ended", c.step)
			c.skip()
			t0 = Time.get_ticks_msec()
		var r := rng.randf()
		if r < 0.02:
			var k: Key = [KEY_SPACE, KEY_E, KEY_W, KEY_B, KEY_M, KEY_ESCAPE, KEY_ENTER, KEY_5, KEY_V][rng.randi() % 9]
			_note("visit: key %s (%s)" % [OS.get_keycode_string(k), c.step])
			for down in [true, false]:
				var e := InputEventKey.new()
				e.keycode = k
				e.physical_keycode = k
				e.pressed = down
				get_viewport().push_input(e)
		elif r < 0.03:
			_note("visit: click (%s)" % c.step)
			var sz := get_viewport().get_visible_rect().size
			_click(Vector2(rng.randf() * sz.x, rng.randf() * sz.y), MOUSE_BUTTON_LEFT)
		await _frames(1)
	if get_tree().paused:
		_fail("paused during Count Vlad's visit")
	await _frames(3)
	_note("visit: start over")
	changing_scene = true
	if is_instance_valid(c):
		c.restart_button.pressed.emit()
	await _wait_for_store()
	Game.tutorial_hidden = true
	if Game.day != 1 or Game.has_loan() or Game.cutscene or not hud.visible and is_instance_valid(hud):
		_fail("starting over didn't start over", "day %d, loan %s, cutscene %s" % [Game.day, Game.loan, Game.cutscene])
	hud = get_tree().current_scene.get_node("HUD")


func _build() -> void:
	if get_tree().paused:
		return
	_note("build: enter")
	build.enter()
	await _frames(1)
	if not build.active:
		return
	for i in rng.randi_range(1, 4):
		var r := rng.randf()
		if r < 0.35:
			var ids: Array = Game.FURNITURE.keys()
			var id: String = ids[rng.randi() % ids.size()]
			build.select_place(id)
			if rng.randf() < 0.4:
				build.rotate_pressed()
			var c := _random_floor()
			_note("build: place %s at %s (%s)" % [id, c, store.placement_error(c, id, null, build.place_rotation)])
			build.tap(Iso.cell_to_world(c))
		elif r < 0.6:
			var movable := store.objects.values().filter(func(o): return o.is_movable())
			if rng.randf() < 0.2:
				movable = [store.delivery_zone]
			if movable.is_empty():
				continue
			var obj: Interactable = movable[rng.randi() % movable.size()]
			build.select_tool(BuildMode.Tool.MOVE)
			var at := Iso.cell_to_world(store.delivery_anchor()) if obj is DeliveryZone else obj.position
			build.tap(at)
			if rng.randf() < 0.4:
				build.rotate_pressed()
			var c := _random_floor()
			_note("build: move %s from %s to %s (%s)" % [_name(obj), obj.cell, c, build.cursor_error])
			build.tap(Iso.cell_to_world(c))
			if is_instance_valid(build.moving):
				build._back()
		elif r < 0.72:
			var movable := store.objects.values().filter(func(o): return o.is_movable())
			if movable.is_empty():
				continue
			var obj: Interactable = movable[rng.randi() % movable.size()]
			_note("build: turn %s at %s" % [_name(obj), obj.cell])
			build.select_tool(BuildMode.Tool.ROTATE)
			build.tap(obj.position)
		elif r < 0.85:
			var sellable := store.objects.values().filter(func(o): return o.is_sellable())
			if sellable.is_empty():
				continue
			var obj: Interactable = sellable[rng.randi() % sellable.size()]
			_note("build: sell %s at %s" % [_name(obj), obj.cell])
			build.select_tool(BuildMode.Tool.SELL)
			build.tap(obj.position)
		elif r < 0.92:
			var lot := build.next_lot()
			_note("build: expand (%s)" % Game.expansion_problem())
			build.select_tool(BuildMode.Tool.EXPAND)
			if not lot.is_empty():
				build.tap(Iso.cell_to_world(lot[lot.size() / 2]))
		else:
			_note("build: paint")
			Game.buy_floor_style(rng.randi() % Game.FLOOR_STYLES.size())
			Game.buy_wall_color(rng.randi() % Game.WALL_COLORS.size())
		await _frames(1)
	build._back()
	build._back()
	build.exit()
	_note("build: exit")
	await _frames(1)


func _random_floor() -> Vector2i:
	var cells: Array = store.floor_cells.keys()
	return cells[rng.randi() % cells.size()]


func _shop() -> void:
	var shops: Array = Brand.SHOPS.keys()
	var id: String = shops[rng.randi() % shops.size()]
	_note("shop: %s" % id)
	Game.shop_requested.emit(id)
	await _frames(2)
	var brews: Array = Brand.BREWS.keys().filter(func(b): return Brand.BREWS[b].shop == id)
	for i in rng.randi_range(0, 2):
		var b: String = brews[rng.randi() % brews.size()]
		_note("shop: buy %s (%s)" % [b, Game.brew_problem(b)])
		Game.buy_brew(b)
	hud._back()
	await _frames(1)


## The rival sends a spy over (if it's open), or you go throw one out.
func _spy() -> void:
	var spies := store.movers.filter(func(m): return m is RivalSpy and is_instance_valid(m) and m.can_be_caught())
	if not spies.is_empty() and rng.randf() < 0.6:
		var spy: RivalSpy = spies[rng.randi() % spies.size()]
		var c := store.stand_cell_for(spy.cell, spy.cell)
		_note("spy: go throw it out (%s, next to it %s)" % [spy.cell, c])
		if c != Store.NO_CELL:
			p.cancel_action()
			p.path.clear()
			p.position = Iso.cell_to_world(c)
	elif Game.is_open and store.town:
		_note("spy: the rival sends one")
		store.town.send_rival_spy()


func _rival() -> void:
	_note("rival: price list")
	Game.rival_requested.emit()
	await _frames(2)
	if rng.randf() < 0.3:
		_note("rival: buy out (%s)" % Game.rival_buyout_problem())
		hud.rival_panel._on_buy()
		hud.rival_panel._on_buy()
	hud._back()
	await _frames(1)


func _pause() -> void:
	_note("pause")
	hud.open_pause()
	await _frames(2)
	if rng.randf() < 0.5:
		hud._open_options()
		await _frames(2)
		if rng.randf() < 0.5:
			hud.options.show_controls()
			await _frames(1)
		hud._back()
		await _frames(1)
	hud._back()
	await _frames(1)
	hud._back()
	await _frames(1)
	if get_tree().paused and not build.active:
		hud._back()
		await _frames(1)
	if get_tree().paused and not build.active:
		_fail("still paused after closing the pause menu")
		get_tree().paused = false


func _save_load() -> void:
	if get_tree().paused:
		return
	var how := rng.randf()
	_note("save+load (%s)" % ("menu" if how < 0.3 else "load"))
	var before_day := Game.day
	var before_money := Game.money
	changing_scene = true
	var before_xp := Game.xp
	var before_staff := Game.staff.size()
	var before_effects := Game.effects.duplicate()
	if how < 0.3:
		Saves.quit_to_menu()
		for i in 20:
			await get_tree().process_frame
		Saves.continue_game()
	else:
		Saves.save_game()
		Saves.load_game(SLOT)
	# Right after loading (before the game has run a frame), it should all be back.
	if Game.day != before_day or absf(Game.money - before_money) > 0.01 or absf(Game.xp - before_xp) > 0.01 \
			or Game.staff.size() != before_staff or _sorted(Game.effects.keys()) != _sorted(before_effects.keys()):
		_fail("save/load didn't bring everything back", "day %d -> %d, $%.2f -> $%.2f, xp %.1f -> %.1f, staff %d -> %d, effects %s -> %s" % [
			before_day, Game.day, before_money, Game.money, before_xp, Game.xp, before_staff, Game.staff.size(), before_effects.keys(), Game.effects.keys()])
	await _wait_for_store()
	loads += 1
	Game.tutorial_hidden = true


func _click(at: Vector2, button: MouseButton) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = pressed
		e.position = at
		e.global_position = at
		if pressed:
			e.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else 0
		get_viewport().push_input(e)


## A finger (or two) somewhere on the screen: a tap, a slide or a pinch,
## through Input like a real touch screen (so the mouse is emulated too).
func _finger() -> void:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var at := get_tree().root.get_final_transform() * Vector2(rng.randf() * size.x, rng.randf() * size.y)
	var kind := rng.randi() % 3
	_note("finger %s at %s" % [["tap", "slide", "pinch"][kind], at.round()])
	_touch(at, true, 0)
	match kind:
		1:
			var by := Vector2(rng.randf_range(-300, 300), rng.randf_range(-300, 300))
			for i in 6:
				_drag(at + by * (i + 1) / 6.0, by / 6.0, 0)
			at += by
		2:
			var other := at + Vector2(rng.randf_range(40, 200), rng.randf_range(-60, 60))
			_touch(other, true, 1)
			var spread := rng.randf_range(-1.0, 1.0)
			for i in 6:
				var to := other + (other - at) * spread * (i + 1) / 6.0
				_drag(to, (other - at) * spread / 6.0, 1)
			_touch(other + (other - at) * spread, false, 1)
	_touch(at, false, 0)


func _touch(at: Vector2, down: bool, finger: int) -> void:
	var e := InputEventScreenTouch.new()
	e.index = finger
	e.position = at
	e.pressed = down
	Input.parse_input_event(e)


func _drag(at: Vector2, by: Vector2, finger: int) -> void:
	var e := InputEventScreenDrag.new()
	e.index = finger
	e.position = at
	e.relative = by
	e.screen_relative = by
	Input.parse_input_event(e)


func _key(k: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = pressed
		get_viewport().push_input(e)


static func _sorted(a: Array) -> Array:
	var b := a.duplicate()
	b.sort()
	return b


func _next_day() -> void:
	if get_tree().paused:
		return
	for i in 3:
		if not Game.day_over:
			break
		hud._day_over_since = -10.0
		_note("press Space (summary %s)" % hud.summary_panel.visible)
		var e := InputEventKey.new()
		e.keycode = KEY_SPACE
		e.physical_keycode = KEY_SPACE
		e.pressed = true
		get_viewport().push_input(e)
		var up := e.duplicate()
		up.pressed = false
		get_viewport().push_input(up)
		await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
		frame += 1
		_drain_errors()


# ---------------------------------------------------------------- checking

func _check(heavy: bool) -> void:
	var dt := get_process_delta_time() * CHECK_EVERY
	var paused := get_tree().paused
	if not is_finite(Game.money):
		_fail("money is not a number", str(Game.money))
	if Game.level != Game.level_for(Game.xp) or Game.xp < -0.001:
		_fail("level doesn't match XP", "level %d, xp %.2f" % [Game.level, Game.xp])
	for id: String in Game.prices:
		if not is_finite(Game.prices[id]) or Game.prices[id] < Game.MIN_PRICE - 0.001 or Game.prices[id] > Game.MAX_PRICE + 0.001:
			_fail("price out of range", "%s %s" % [id, Game.prices[id]])
	for id: String in Game.effects:
		if not Brand.BREWS.has(id) or Game.effects[id] <= 0.0 or Game.effects[id] > Game.MAX_EFFECT_SECONDS + 0.01:
			_fail("bad effect", "%s %s" % [id, Game.effects[id]])
	_check_store(heavy)
	_check_people(dt, paused)
	_check_stock()
	if heavy:
		_check_nodes()


func _check_store(heavy: bool) -> void:
	for cell: Vector2i in store.objects:
		var obj: Interactable = store.objects[cell]
		if not is_instance_valid(obj) or obj.is_queued_for_deletion():
			_fail("freed object still in the store's map", str(cell))
			continue
		if obj.cell != cell:
			_fail("object's cell doesn't match the map", "%s says %s, map %s" % [_name(obj), obj.cell, cell])
		if not store.astar.is_point_solid(cell):
			_fail("furniture on a walkable cell", "%s %s" % [_name(obj), cell])
		if store.boxes.has(cell):
			_fail("a box under furniture", "%s %s" % [_name(obj), cell])
		if store.spills.has(cell):
			_fail("a puddle under furniture", "%s %s" % [_name(obj), cell])
	for s in store.shelves:
		if not is_instance_valid(s):
			_fail("freed shelf in the list")
			continue
		if store.objects.get(s.cell) != s:
			_fail("shelf missing from the map", "%s %s" % [_name(s), s.cell])
		if s.stock < 0 or s.stock > Shelf.CAPACITY:
			_fail("shelf stock out of range", "%s %d" % [s.cell, s.stock])
		if s.stock > 0 and s.product_id == "":
			_fail("stock on a shelf with no product", str(s.cell))
		if s.product_id != "" and (not Game.PRODUCTS.has(s.product_id) or Game.is_cold(s.product_id) != s.holds_cold()):
			_fail("wrong product on a shelf", "%s %s" % [_name(s), s.product_id])
	for r in store.racks:
		if store.objects.get(r.cell) != r:
			_fail("rack missing from the map", str(r.cell))
		if r.boxes.size() > StorageRack.CAPACITY:
			_fail("rack over capacity", "%d" % r.boxes.size())
		for b in r.boxes:
			if b.count <= 0 or not Game.PRODUCTS.has(b.product_id):
				_fail("bad box on a rack", "%s %d" % [b.product_id, b.count])
	var lines := {}
	for r in store.registers:
		if not is_instance_valid(r):
			_fail("freed register in the list")
			continue
		if store.objects.get(r.cell) != r:
			_fail("register missing from the map", str(r.cell))
		if r.line_cells.size() != store.line_length:
			_fail("register line is the wrong length", "%s %s" % [r.cell, r.line_cells])
		for c in r.line_cells:
			if lines.has(c):
				_fail("two lines share a spot", str(c))
			lines[c] = true
			if not store.floor_cells.has(c) or store.astar.is_point_solid(c) or c in store.delivery_cells or c == store.door_cell:
				_fail("line spot blocked", "%s for register %s" % [c, r.cell])
		for c in r.line:
			if not is_instance_valid(c) or c.is_queued_for_deletion():
				_fail("freed shopper in a line")
			elif c.register != r:
				_fail("shopper in a line they don't know about", "state %s" % Customer.State.keys()[c.state])
		if is_instance_valid(r.cashier) and r.cashier.register != r and r.cashier.role == "cashier":
			_fail("register's cashier works somewhere else")
	var box_nodes := 0
	for cell: Vector2i in store.boxes:
		var b: StockBox = store.boxes[cell]
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			_fail("freed box in the map", str(cell))
			continue
		if b.cell != cell:
			_fail("box's cell doesn't match the map", "%s vs %s" % [b.cell, cell])
		if b.count <= 0 or not Game.PRODUCTS.has(b.product_id):
			_fail("bad box", "%s %d at %s" % [b.product_id, b.count, cell])
		if store.astar.is_point_solid(cell):
			_fail("box on a solid cell", str(cell))
	for cell: Vector2i in store.spills:
		var sp: Spill = store.spills[cell]
		if not is_instance_valid(sp) or sp.cell != cell:
			_fail("puddle out of sync", str(cell))
	for c in store.delivery_cells:
		if not store.floor_cells.has(c) or store.astar.is_point_solid(c) or c == store.door_cell:
			_fail("delivery zone on a bad cell", str(c))
	if heavy:
		for n in store.world.get_children():
			if n is StockBox and not n.is_queued_for_deletion():
				box_nodes += 1
				if store.boxes.get(n.cell) != n:
					_fail("a box nobody knows about (drawn but not in the map)", "%s x%d at %s" % [n.product_id, n.count, n.cell])
		if box_nodes != store.boxes.size():
			_fail("box count mismatch", "%d drawn, %d in the map" % [box_nodes, store.boxes.size()])
		var reach := store.reachable
		if not reach.has(store.door_cell):
			_fail("the door isn't reachable")
		for c in store.delivery_cells:
			if not reach.has(c):
				_fail("delivery zone cell unreachable", str(c))
		for obj: Interactable in store.objects.values():
			if obj is Decoration or not is_instance_valid(obj):
				continue
			if not store._has_reachable_neighbor(obj.cell, reach):
				_fail("can't reach something", "%s at %s" % [_name(obj), obj.cell])
	# Deliveries that should have arrived (the zone had room last time too).
	var room := false
	for c in store.delivery_cells:
		if not store.boxes.has(c):
			room = true
	if get_tree().paused:
		_had_room = 0
		return
	if room and _had_room >= 2:
		for d in store.pending_deliveries:
			if float(d.time) < -30.0:
				_fail("delivery stuck although the zone has room", "%s %.0f, zone %s, boxes on it %s" % [d.id, d.time, store.delivery_cells,
					store.delivery_cells.filter(func(c): return store.boxes.has(c))])
	_had_room = _had_room + 1 if room else 0


func _check_people(dt: float, paused: bool) -> void:
	# You
	if p.carry_count < 0 or (p.carry_count > 0) != (p.carry_product != ""):
		_fail("player carry out of sync", "%s x%d" % [p.carry_product, p.carry_count])
	if p.holding_mop and p.carry_count > 0:
		_fail("holding the mop and a box")
	if not paused:
		if not store.is_walkable(p.current_cell()):
			player_in_wall += dt
			if player_in_wall > 1.5:
				_fail("player stuck inside something", "%s (%s)" % [p.current_cell(), _name(store.objects.get(p.current_cell()))])
				player_in_wall = 0.0
		else:
			player_in_wall = 0.0
	# Shoppers
	var seen := {}
	for c in store.customers:
		if not is_instance_valid(c) or c.is_queued_for_deletion():
			_fail("freed shopper in the list")
			continue
		var id := c.get_instance_id()
		seen[id] = true
		if paused:
			continue
		var w: Array = shopper_watch.get(id, [c.position, 0.0, 0.0, c.state])
		w[2] += dt
		if c.state != w[3]:  # standing in line, then walking off, isn't being stuck
			w[3] = c.state
			w[1] = 0.0
			w[0] = c.position
		elif c.position.distance_to(w[0]) < 0.5:
			w[1] += dt
		else:
			w[1] = 0.0
			w[0] = c.position
		shopper_watch[id] = w
		var walking: bool = c.state in [Customer.State.SHOPPING, Customer.State.TO_LINE, Customer.State.LEAVING, Customer.State.ARRIVING]
		if walking and w[1] > 5.0 and _trace != c and OS.get_environment("TRACE") != "":
			_trace = c
			_trace_frames = 400
		if walking and w[1] > 20.0:
			_fail("shopper stuck", "%s %s at %s (%s), list %s, path %s, in tree %s, processing %s, speed %.2f, still %.1f, pos %s" % [
				c.kind.get("name"), Customer.State.keys()[c.state], c.current_cell(), _name(store.objects.get(c.current_cell())),
				c.shopping_list.size(), c.path, c.is_inside_tree(), c.can_process(), c.speed, c._still, c.position])
			w[1] = -1000.0
		if w[2] > 1500.0:
			_fail("shopper in the store for 25 minutes", "%s %s at %s" % [c.kind.get("name"), Customer.State.keys()[c.state], c.current_cell()])
			w[2] = -100000.0
		if c.state in [Customer.State.SHOPPING, Customer.State.PICKING, Customer.State.LEAVING] and not store.is_walkable(c.current_cell()) and w[1] > 3.0:
			_fail("shopper standing inside something", "%s at %s" % [Customer.State.keys()[c.state], c.current_cell()])
	for id in shopper_watch.keys():
		if not seen.has(id):
			shopper_watch.erase(id)
	# Staff
	for s in store.staff:
		if not is_instance_valid(s):
			_fail("freed staff in the list")
			continue
		if s.carry_count < 0:
			_fail("staff carrying a negative box")
		if not paused and s.is_slacking(150.0):
			_fail("staff stuck on a job", "%s %s %s at %s" % [s.role, s.staff_name, Staff.Job.keys()[s.job], s.current_cell()])
			s._job_time = -10000.0
		if not paused and s.role == "spy" and s.job in [Staff.Job.TO_RIVAL, Staff.Job.TO_REPORT, Staff.Job.CHASING] and s._job_time > 150.0:
			_fail("spy never gets there", "%s %s at %s, path %d" % [s.staff_name, Staff.Job.keys()[s.job], s.current_cell(), s.path.size()])
			s._job_time = -10000.0
	# The rival's spies
	for m in store.movers:
		if not is_instance_valid(m):
			_fail("freed spy in the list")
			continue
		var age: float = m.get_meta("age", 0.0) + (0.0 if paused else dt)
		m.set_meta("age", age)
		if age > 240.0:
			_fail("rival spy hanging around", "%s at %s, inside %s, path %d, wait %.1f" % [RivalSpy.State.keys()[m.state], m.cell, m.is_inside(), m.path.size(), m.wait])
			m.set_meta("age", -100000.0)
	# The day has to end after closing.
	if not paused and Game.opened and not Game.is_open and not Game.day_over:
		closing_time += dt
		if closing_time > 600.0:
			_fail("the day won't end", "%d shoppers: %s" % [store.customers.size(), store.customers.map(func(c): return "%s %s %s" % [c.kind.get("name"), Customer.State.keys()[c.state], c.current_cell()])])
			closing_time = -100000.0
	elif Game.is_open or Game.day_over:
		closing_time = 0.0


## Stock only appears when it's ordered and only leaves the shelves, boxes,
## racks and hands when a shopper takes it (into their basket).
func _check_stock() -> void:
	var parts := {"shelves": 0, "boxes": 0, "racks": 0, "you": p.carry_count, "staff": 0, "on the way": 0}
	for s in store.shelves:
		parts.shelves += s.stock
	for b: StockBox in store.boxes.values():
		parts.boxes += b.count
	for r in store.racks:
		for b in r.boxes:
			parts.racks += b.count
	for s in store.staff:
		parts.staff += s.carry_count
	for d in store.pending_deliveries:
		parts["on the way"] += int(Game.PRODUCTS[d.id].box_size)
	var total := 0
	for k in parts:
		total += int(parts[k])
	var taken := Customer.items_taken - _taken_seen
	_taken_seen = Customer.items_taken
	if baseline < 0:
		baseline = total
		ordered = 0
		_stock_parts = parts
		return
	var expected := baseline + ordered - taken
	if total != expected:
		_fail("stock appeared or vanished", "expected %d, have %d (ordered %d, taken by shoppers %d), was %s, now %s" % [expected, total, ordered, taken, _stock_parts, parts])
	baseline = total
	ordered = 0
	_stock_parts = parts


func _check_nodes() -> void:
	var w := store.world.get_child_count()
	max_world_nodes = maxi(max_world_nodes, w)
	if w > 900:
		_fail("too many nodes in the world", "%d" % w)
	var h: int = hud.root.get_child_count()
	max_hud_nodes = maxi(max_hud_nodes, h)
	if h > 400:
		_fail("too many HUD nodes", "%d" % h)
