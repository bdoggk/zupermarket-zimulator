extends Node
# See roundtrip_test.gd.

const SLOT := 2
const IGNORE := ["saved_at", "play_time"]  # (these move on by themselves)

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	Engine.max_fps = 0
	_run()


func _run() -> void:
	var backups := {}
	for i in Saves.SLOTS:
		if FileAccess.file_exists(Saves.slot_path(i)):
			backups[i] = FileAccess.get_file_as_string(Saves.slot_path(i))
	Saves.new_game(SLOT)
	await _frames(8)
	var store: Store = Game.store
	check(store != null, "a new game")

	# ---- a bit of everything
	Game.add_xp(Game.xp_for_level(16) - Game.xp)
	Game.war.pending = false
	Game.war.begin()
	Game.money = 60000.0
	for id in Game.PRODUCTS:
		if Game.can_license(id):
			Game.buy_license(id)
	Game.money = 60000.0
	Game.buy_expansion()
	await _frames(3)
	for id in Game.UPGRADES:
		if Game.upgrade_problem(id) == "":
			Game.buy_upgrade(id)
	Game.money = 60000.0
	for role in ["stocker", "cashier", "janitor"]:
		Game.hire(role)
	Game.war.buy_plot(Game.war.free_plots()[0])
	Game.war.hire()
	Game.war.hire()
	Game.war.buy_weapon("nunchucks")
	Game.war.buy_weapon("glock")
	Game.money = 60000.0
	Game.take_loan(1000.0)
	for id in Brand.BREWS:
		Game.effects[id] = 50.0
		break
	var ids := Game.unlocked_ids()
	var placed := 0
	for f: String in ["shelf", "fridge", "storage", "lantern", "plant", "selfcheckout"]:
		if not Game.FURNITURE.has(f):
			continue
		for c: Vector2i in store.floor_cells:
			if store.placement_error(c, f, null, 1) == "":
				var obj := store.add_furniture(f, c, 1)
				if obj is Shelf:
					var fits := ids.filter(func(id): return Game.is_cold(id) == (obj as Shelf).holds_cold())
					obj.product_id = fits[placed % fits.size()]
					obj.stock = 3 + placed
				elif obj is StorageRack:
					obj.store_box(ids[0], 7)
				placed += 1
				break
	store.layout_changed()
	store.add_spill(Vector2i(6, 6), 1, false, 30.0)
	Game.floor_style = Game.FLOOR_STYLES.size() - 1
	Game.wall_color = Game.WALL_COLORS.size() - 1
	Game.decor_changed.emit()
	Game.prices[ids[0]] = 9.99
	Game.price_markup = 0.2
	Game.unstocked[ids[1]] = true
	Game.reorder_at = 1
	Game.fill_empty_shelves = false
	Game.tutorial["stock"] = true
	Game.minute = 14 * 60 + 5
	await _frames(6)

	# ---- save, load, save again
	check(Saves.save_game(), "saved")
	var first := _read()
	check(Saves.load_game(SLOT), "loaded it")
	await _frames(10)
	check(Saves.save_game(), "saved again")
	var second := _read()
	var diffs: Array[String] = []
	_compare(first, second, "", diffs)
	for d in diffs:
		print("      " + d)
	check(diffs.is_empty(), "the second save matches the first (%d differences)" % diffs.size())
	check(not first.is_empty() and first.game.war.plots.has("you") and first.game.war.gang.size() == 2 and not first.game.loan.is_empty(),
		"(and it had the war, the gang and the loan in it)")

	for i in Saves.SLOTS:
		Saves.delete_slot(i)
		if backups.has(i):
			var f := FileAccess.open(Saves.slot_path(i), FileAccess.WRITE)
			f.store_string(backups[i])
	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


func _read() -> Dictionary:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(Saves.slot_path(SLOT)))
	return d if d is Dictionary else {}


## Every difference between `a` and `b` (dictionaries, arrays, values) into
## `out`, as "path: a -> b". Arrays whose order doesn't matter are compared
## as sets of what's in them.
func _compare(a: Variant, b: Variant, path: String, out: Array[String]) -> void:
	if out.size() > 40:
		return
	if a is Dictionary and b is Dictionary:
		for k in a:
			if k in IGNORE:
				continue
			if not b.has(k):
				out.append("%s/%s: only in the first save" % [path, k])
			else:
				_compare(a[k], b[k], "%s/%s" % [path, k], out)
		for k in b:
			if not a.has(k) and not k in IGNORE:
				out.append("%s/%s: only in the second save" % [path, k])
	elif a is Array and b is Array:
		if a.size() != b.size():
			out.append("%s: %d things -> %d" % [path, a.size(), b.size()])
			return
		var sa: Array = (a as Array).map(func(x): return JSON.stringify(x, "", true))
		var sb: Array = (b as Array).map(func(x): return JSON.stringify(x, "", true))
		sa.sort()
		sb.sort()
		if sa != sb:
			for i in sa.size():
				if sa[i] != sb[i]:
					out.append("%s: %s -> %s" % [path, sa[i].left(160), sb[i].left(160)])
	elif typeof(a) in [TYPE_FLOAT, TYPE_INT] and typeof(b) in [TYPE_FLOAT, TYPE_INT]:
		var slack := 1.0 if path.begins_with("/game/effects/") else 0.011  # (brews wear off as it runs)
		if absf(float(a) - float(b)) > slack:
			out.append("%s: %s -> %s" % [path, a, b])
	elif a != b:
		out.append("%s: %s -> %s" % [path, str(a).left(160), str(b).left(160)])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
