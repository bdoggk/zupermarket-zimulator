extends Node
# Automated play-test. A bot runs the store for several days using the same
# code paths a player uses (taps, build mode, scanner), buying licenses,
# furniture and the scanner as it can afford them.
#
#   DAYS=4 BOT_SPEED=4 godot --headless --path . --fixed-fps 60 res://tests/bot_test.tscn

const CANDIDATE_CELLS := [
	Vector2i(9, 4), Vector2i(10, 4), Vector2i(11, 4), Vector2i(9, 7), Vector2i(10, 7), Vector2i(11, 7),
	Vector2i(12, 4), Vector2i(12, 7), Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2), Vector2i(7, 2),
]
const RESERVE := 50.0
const PLANT_CELLS := [Vector2i(13, 9), Vector2i(1, 8), Vector2i(14, 3), Vector2i(1, 4)]

var days := 4
var main: Node
var store: Store
var p: Player
var b: BuildMode
var wait := 0.0
var claims := {}  # Shelf -> product id the bot wants on it
var scans := 0
var mopped := 0
var log_lines: Array[String] = []


func _ready() -> void:
	seed(int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 7)
	days = int(OS.get_environment("DAYS")) if OS.get_environment("DAYS") != "" else 4
	Engine.max_fps = 0
	main = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	Engine.time_scale = float(OS.get_environment("BOT_SPEED")) if OS.get_environment("BOT_SPEED") != "" else 4.0
	store = Game.store
	p = Game.player
	b = Game.build_mode
	Game.day_ended.connect(_on_day_ended)
	Game.message.connect(_on_message)


func _process(delta: float) -> void:
	if get_tree().paused or Game.day_over:
		return
	wait -= delta
	if p.is_busy() or not p.path.is_empty() or wait > 0.0:
		return
	wait = 0.25
	if not Game.opened:
		_tap(store.sign.position + Vector2(0, -20))  # walk to the sign and flip it
		return
	var reg: Register = store.register
	if reg.front_customer() and not reg.is_staffed():
		_tap(reg.position + Vector2(0, -10))
		return
	if _mop(reg):
		return
	if p.is_carrying():
		var s := _home_shelf_with_space(p.carry_product)
		if s:
			_tap(s.position + Vector2(0, -20))
		else:
			p.try_interact()
		return
	for box: StockBox in store.boxes.values():
		if _space_for(box.product_id) >= 1:
			_tap(box.position + Vector2(0, -8))
			return
	if not Game.has_upgrade("scanner") and Game.money > Game.UPGRADES.scanner.cost + 80.0:
		Game.buy_upgrade("scanner")
		log_lines.append("  [day %d] bought the scanner" % Game.day)
	_order_stock()


## Zombie game: grab the mop when blood piles up, clean, put it back.
func _mop(reg: Register) -> bool:
	if not Brand.SPILLS or store.mop_bucket == null:
		return false
	var busy := reg.line.size() >= 2 and not reg.is_staffed()
	if p.holding_mop:
		if store.spills.is_empty() or busy:
			_tap(store.mop_bucket.position + Vector2(0, -20))
		else:
			var best: Spill = null
			for sp: Spill in store.spills.values():
				if best == null or sp.position.distance_to(p.position) < best.position.distance_to(p.position):
					best = sp
			_tap(best.position)
			mopped += 1
		return true
	if store.spills.size() >= 3 and not busy and not p.is_carrying():
		_tap(store.mop_bucket.position + Vector2(0, -20))
		return true
	return false


func _on_message(t: String) -> void:
	if t.begins_with("NEWS") or t.begins_with("Store level"):
		log_lines.append("  [day %d] %s" % [Game.day, t])


# ---------------------------------------------------------------- stocking

## Which shelves the bot uses for each product.
func _homes() -> Dictionary:
	var homes := {}
	for id in Game.unlocked_ids():
		homes[id] = []
	for s in store.shelves:
		var id := ""
		if s.stock > 0:
			id = s.product_id
		elif claims.has(s):
			id = claims[s]
		elif s.product_id != "":
			id = s.product_id
		if id != "" and homes.has(id):
			homes[id].append(s)
	# products without a shelf claim a free one
	for id in homes:
		if homes[id].is_empty():
			for s in store.shelves:
				if s.stock == 0 and not claims.has(s) and s.product_id == "" and s.holds_cold() == Game.is_cold(id):
					claims[s] = id
					homes[id].append(s)
					break
	return homes


func _home_shelf_with_space(id: String) -> Shelf:
	var best: Shelf = null
	for s: Shelf in _homes().get(id, []):
		if s.accepts(id) and s.stock < Shelf.CAPACITY:
			if best == null or s.position.distance_to(p.position) < best.position.distance_to(p.position):
				best = s
	return best


func _space_for(id: String) -> int:
	var space := 0
	for s: Shelf in _homes().get(id, []):
		if s.accepts(id):
			space += Shelf.CAPACITY - s.stock
	if p.carry_product == id:
		space -= p.carry_count
	return space


func _in_flight(id: String) -> int:
	var n := 0
	for box: StockBox in store.boxes.values():
		if box.product_id == id:
			n += box.count
	for d in store.pending_deliveries:
		if d.id == id:
			n += Game.PRODUCTS[id].box_size
	return n


func _order_stock() -> void:
	if store.pending_deliveries.size() >= 3 or store.boxes.size() >= 5:
		return
	var homes := _homes()
	for id: String in Game.unlocked_ids():
		if homes[id].is_empty():
			continue
		var size: int = Game.PRODUCTS[id].box_size
		if _space_for(id) - _in_flight(id) < size or Game.money < Game.box_cost(id) + 5.0:
			continue
		if Game.has_upgrade("scanner"):
			var s: Shelf = homes[id][0]
			if s.product_id == id:
				_scan_at(s)
				return
		Game.order_box(id)
		return


## Walks next to a shelf and scans it.
func _scan_at(s: Shelf) -> void:
	if Iso.chebyshev(p.current_cell(), s.cell) <= 1:
		p.scan_focus = s
		p.try_scan()
		scans += 1
		return
	var stand := store.stand_cell_for(s.cell, p.current_cell())
	if stand != Store.NO_CELL:
		p.walk_to(stand)


func _tap(world_pos: Vector2) -> void:
	p._on_tap(world_pos)


# ---------------------------------------------------------------- mornings

func _on_day_ended(summary: Dictionary) -> void:
	var furn := "shelves %d, fridges %d, plants %d" % [_count("shelf"), _count("fridge"), store.plant_count()]
	print("DAY %d: sales $%.2f, stock $%.2f, upgrades $%.2f, wages $%.2f, profit $%.2f | served %d, items %d, missed %d, walkouts %d, mopped %d | money $%.2f, level %d, xp %d | %s, staff %d | selling %s | scans %d" % [
		summary.day, summary.revenue, summary.spent, summary.invested, summary.wages, summary.profit,
		summary.customers, summary.items_sold, summary.missed, summary.walkouts, summary.cleaned,
		Game.money, Game.level, int(Game.xp), furn, Game.staff.size(), ",".join(Game.unlocked_ids()), scans])
	for l in log_lines:
		print(l)
	log_lines.clear()
	if summary.day >= days:
		print("BOT: done")
		get_tree().quit()
		return
	await get_tree().create_timer(0.5).timeout
	main.get_node("HUD")._on_next_day()
	_morning_shopping()


func _count(fid: String) -> int:
	var n := 0
	for obj in store.objects.values():
		if obj.furniture_id == fid:
			n += 1
	return n


func _morning_shopping() -> void:
	b.enter()
	_build_homes()  # furniture for what we already sell comes first
	for id: String in Game.PRODUCTS:
		if not Game.can_license(id):
			continue
		var cold := Game.is_cold(id)
		var fridge_free := _count("fridge") > _cold_count()
		var extra: float = 0.0 if not cold or fridge_free else Game.FURNITURE.fridge.cost
		if Game.money >= Game.PRODUCTS[id].license + extra + RESERVE:
			Game.buy_license(id)
			log_lines.append("  [day %d] licensed %s" % [Game.day, id])
			_build_homes()
	if store.plant_count() < 6 and Game.money > 400.0:
		_build("plant")
	if Game.day >= 3 and Game.staff_count("stocker") == 0 and Game.money > 300.0:
		Game.hire("stocker")
		log_lines.append("  [day %d] hired a stocker" % Game.day)
	b.exit()


func _cold_count() -> int:
	return Game.unlocked_ids().filter(func(id): return Game.is_cold(id)).size()


## Buys shelves/fridges until every product has one (plus a spare shelf).
func _build_homes() -> void:
	var dry := Game.unlocked_ids().size() - _cold_count()
	for i in maxi(0, _cold_count() - _count("fridge")):
		_build("fridge")
	for i in maxi(0, dry + 1 - _count("shelf")):
		_build("shelf")


func _build(fid: String) -> void:
	if Game.money < Game.FURNITURE[fid].cost + RESERVE:
		return
	var cells: Array = PLANT_CELLS if fid == "plant" else CANDIDATE_CELLS
	for c: Vector2i in cells:
		if store.placement_error(c, fid) == "":
			b.select_place(fid)
			b.tap(Iso.cell_to_world(c))
			log_lines.append("  [day %d] built a %s at %s" % [Game.day, fid, c])
			return
