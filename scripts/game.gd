extends Node
## Global game state: money, products, the market, store level, product
## licenses, upgrades, staff, store decor, the clock and daily stats.
## Registered as the "Game" autoload, so any script can use Game.money etc.
##
## The catalogs (products, furniture, paint, staff) come from brand.gd, the
## one script that's different between Supermarket Sim and Zupermarket
## Zimulator.

signal message(text: String)
signal popup(world_pos: Vector2, text: String, color: Color)
signal prompt_changed(text: String, can_act: bool, scan_text: String)
signal computer_requested
signal box_ordered(product_id: String)
signal store_opened
signal store_closed
signal day_ended(summary: Dictionary)
signal day_started(day: int)
signal market_changed
signal unlocks_changed  # a license, upgrade or store level changed
signal decor_changed  # floor style or wall color changed
signal staff_changed  # someone was hired or fired

const OPEN_MINUTE := 8 * 60
const CLOSE_MINUTE := 20 * 60
## Real seconds per in-game minute. 0.5 means a 12 hour day lasts 6 minutes.
const SECONDS_PER_GAME_MINUTE := 0.5
const DELIVERY_SECONDS := 8.0
const PRICE_STEP := 0.25
const STARTING_MONEY := 100.0

## Store level. You earn 1 XP for every dollar of sales. Each number is the
## XP needed to reach the next level (level 2 at 150 XP, level 3 at 400...).
const LEVEL_XP := [0, 150, 400, 800, 1400, 2200]

## The catalogs. Edit them in brand.gd.
const PRODUCTS := Brand.PRODUCTS
const UPGRADES := Brand.UPGRADES
const FURNITURE := Brand.FURNITURE
const FLOOR_STYLES := Brand.FLOOR_STYLES
const WALL_COLORS := Brand.WALL_COLORS
const STAFF := Brand.STAFF
const SELL_REFUND := 0.5  # selling furniture gives back half what it cost
const FLOOR_COST := 40.0
const WALL_COST := 30.0

var money := STARTING_MONEY
var prices := {}  # product id -> what you sell it for
var licensed := {}  # product id -> true once you're allowed to sell it
var upgrades := {}  # upgrade id -> true once bought
var xp := 0.0
var level := 1
var floor_style := 0
var wall_color := 0
var market := Market.new()
var day := 1
var minute := float(OPEN_MINUTE)
var next_market_minute := float(OPEN_MINUTE + Market.UPDATE_EVERY_HOURS * 60)
var opened := false  # the OPEN sign has been flipped today
var is_open := false  # open for customers (after the sign is flipped, until 8 PM)
var day_over := false
var stats := {}
var auto_price := false  # your prices follow the market automatically
var play_time := 0.0  # seconds played in this save
var slot := -1  # save slot being played (0-2), -1 = not saving (e.g. tests)
var touch_ui := false  # set by the HUD
var staff: Array[Dictionary] = []  # everyone you've hired: [{id, role, name}]
var _next_staff_id := 1

# Set by these nodes when they load.
var player: Node2D
var store: Node2D
var build_mode: Node2D


func _ready() -> void:
	reset()


## Starts a fresh game (the main menu calls this for New Game and before
## loading a save).
func reset() -> void:
	money = STARTING_MONEY
	prices = {}
	licensed = {}
	upgrades = {}
	xp = 0.0
	level = 1
	floor_style = 0
	wall_color = 0
	market = Market.new()
	market.setup(PRODUCTS.keys())
	day = 1
	minute = float(OPEN_MINUTE)
	next_market_minute = float(OPEN_MINUTE + Market.UPDATE_EVERY_HOURS * 60)
	opened = false
	is_open = false
	day_over = false
	auto_price = false
	play_time = 0.0
	slot = -1
	staff = []
	_next_staff_id = 1
	player = null
	store = null
	build_mode = null
	for id in PRODUCTS:
		prices[id] = PRODUCTS[id].base_price
		if PRODUCTS[id].license <= 0.0:
			licensed[id] = true
	_reset_stats()


## True while the store scene is running (not on the main menu).
func in_game() -> bool:
	return is_instance_valid(store)


func _process(delta: float) -> void:
	if not in_game():
		return
	play_time += delta
	if not is_open:
		return
	minute += delta / SECONDS_PER_GAME_MINUTE
	if minute >= next_market_minute and next_market_minute < CLOSE_MINUTE:
		next_market_minute += Market.UPDATE_EVERY_HOURS * 60
		update_market(false)
	if minute >= CLOSE_MINUTE:
		minute = CLOSE_MINUTE
		is_open = false
		message.emit(Brand.SAY.closing)
		store_closed.emit()


# ---------------------------------------------------------------- products

func product_name(id: String) -> String:
	return PRODUCTS[id].name


func icon(id: String) -> Texture2D:
	return PRODUCTS[id].icon


func is_cold(id: String) -> bool:
	return PRODUCTS[id].cold


## What customers expect to pay right now.
func market_price(id: String) -> float:
	return snappedf(PRODUCTS[id].base_price * market.factor[id], 0.05)


## What a box costs you right now.
func box_cost(id: String) -> float:
	var p: Dictionary = PRODUCTS[id]
	return snappedf(p.unit_cost * p.box_size * market.factor[id], 0.05)


func order_box(id: String) -> bool:
	if not is_licensed(id):
		return false
	if not spend(box_cost(id), true):
		return false
	box_ordered.emit(id)
	message.emit("Ordered %s. It arrives in %d seconds." % [product_name(id), int(DELIVERY_SECONDS)])
	return true


func change_price(id: String, amount: float) -> void:
	prices[id] = maxf(PRICE_STEP, snappedf(prices[id] + amount, 0.01))


func match_market(id: String) -> void:
	prices[id] = market_price(id)


func match_all_prices() -> void:
	for id in unlocked_ids():
		match_market(id)


## Chance (0-1) that a customer still buys at your price.
func buy_chance(id: String) -> float:
	var markup: float = prices[id] / market_price(id)
	if markup <= 1.0:
		return 1.0
	return clampf(1.0 - (markup - 1.0) * 1.6, 0.0, 1.0)


# ---------------------------------------------------------------- market

## Called at the start of every day and every few hours while open.
func update_market(new_day: bool) -> void:
	var names := {}
	for id in PRODUCTS:
		names[id] = product_name(id)
	var news := market.update(new_day, unlocked_ids(), names)
	if auto_price:
		match_all_prices()
	market_changed.emit()
	if news != "":
		message.emit("NEWS: " + news)
	else:
		message.emit("Market prices changed: " + _movers_text())


## The biggest price moves, e.g. "Soda +12%, Chips -8%".
func _movers_text() -> String:
	var ids := unlocked_ids()
	ids.sort_custom(func(a, b): return absf(market.change(a)) > absf(market.change(b)))
	var parts: Array[String] = []
	for id in ids.slice(0, 2):
		parts.append("%s %+d%%" % [product_name(id), roundi(market.change(id) * 100.0)])
	return ", ".join(parts)


# ---------------------------------------------------------------- unlocks

func is_licensed(id: String) -> bool:
	return licensed.has(id)


## Products you can sell, in the order they're listed in PRODUCTS.
func unlocked_ids() -> Array:
	return PRODUCTS.keys().filter(func(id): return licensed.has(id))


func can_license(id: String) -> bool:
	return not is_licensed(id) and level >= PRODUCTS[id].level


func buy_license(id: String) -> bool:
	if not can_license(id) or not spend(PRODUCTS[id].license):
		return false
	licensed[id] = true
	prices[id] = market_price(id)
	var text := "You can now sell %s! Order it in the Stock tab." % product_name(id)
	if is_cold(id):
		text += " It needs a fridge (Build mode)."
	message.emit(text)
	unlocks_changed.emit()
	return true


func has_upgrade(id: String) -> bool:
	return upgrades.has(id)


func buy_upgrade(id: String) -> bool:
	if has_upgrade(id) or not spend(UPGRADES[id].cost):
		return false
	upgrades[id] = true
	message.emit("Bought the %s!" % UPGRADES[id].name)
	unlocks_changed.emit()
	return true


static func level_for(amount: float) -> int:
	var lv := 0
	for need in LEVEL_XP:
		if amount >= need:
			lv += 1
	return lv


## XP needed for the next level, or -1 at max level.
func next_level_xp() -> float:
	return LEVEL_XP[level] if level < LEVEL_XP.size() else -1.0


func add_xp(amount: float) -> void:
	xp += amount
	var new_level := level_for(xp)
	if new_level <= level:
		return
	level = new_level
	var count := 0
	for id in PRODUCTS:
		if PRODUCTS[id].level == level:
			count += 1
	Settings.vibrate(0.8, 0.35)
	var text := "Store level %d!" % level
	if count > 0:
		text += " %d new product%s at the computer." % [count, "" if count == 1 else "s"]
	message.emit(text)
	unlocks_changed.emit()


# ---------------------------------------------------------------- staff

func staff_count(role: String) -> int:
	return staff.filter(func(s): return s.role == role).size()


## The most of `role` you can have right now. Cashiers are limited to one
## per register.
func staff_limit(role: String) -> int:
	var limit: int = STAFF[role].max
	if role == "cashier" and in_game():
		limit = mini(limit, store.registers.size())
	return limit


## Why you can't hire a `role` right now ("" means you can).
func hire_problem(role: String) -> String:
	if staff_count(role) >= staff_limit(role):
		if role == "cashier" and staff_count(role) < STAFF[role].max:
			return "Buy another register first (Build mode)"
		return "You have as many as you can hire"
	if money + 0.001 < STAFF[role].hire:
		return "Not enough money"
	return ""


## Hires someone. Returns their roster entry, or {} if you can't.
func hire(role: String) -> Dictionary:
	if hire_problem(role) != "" or not spend(STAFF[role].hire):
		return {}
	var entry := {"id": _next_staff_id, "role": role, "name": _pick_staff_name()}
	_next_staff_id += 1
	staff.append(entry)
	message.emit("Hired %s the %s! Wages are $%d a day." % [entry.name, STAFF[role].name.to_lower(), int(STAFF[role].wage)])
	staff_changed.emit()
	return entry


func fire(id: int) -> void:
	for i in staff.size():
		if staff[i].id == id:
			var entry: Dictionary = staff[i]
			staff.remove_at(i)
			message.emit("%s has left the store." % entry.name)
			staff_changed.emit()
			return


func daily_wages() -> float:
	var total := 0.0
	for s in staff:
		total += STAFF[s.role].wage
	return total


func _pick_staff_name() -> String:
	var used := staff.map(func(s): return s.name)
	var names: Array = Brand.STAFF_NAMES.filter(func(n): return not n in used)
	if names.is_empty():
		return "%s %d" % [Brand.STAFF_NAMES.pick_random(), _next_staff_id]
	return names.pick_random()


# ---------------------------------------------------------------- money

## Pays for something. Boxes of stock count as `stock`; everything else
## (licenses, furniture, paint, upgrades) counts as investing in the store.
func spend(amount: float, stock := false) -> bool:
	if money + 0.001 < amount:
		message.emit("Not enough money ($%.2f needed)." % amount)
		return false
	money -= amount
	if stock:
		stats.spent += amount
	else:
		stats.invested += amount
	return true


func refund(amount: float) -> void:
	money += amount
	stats.invested -= amount


func record_sale(total: float, items: int) -> void:
	money += total
	stats.revenue += total
	stats.items_sold += items
	stats.customers += 1
	add_xp(total)


func record_missed() -> void:
	stats.missed += 1


func record_walkout() -> void:
	stats.walkouts += 1


func record_spill_cleaned() -> void:
	stats.cleaned += 1


# ---------------------------------------------------------------- decor

func buy_floor_style(i: int) -> bool:
	if i == floor_style or not spend(FLOOR_COST):
		return false
	floor_style = i
	decor_changed.emit()
	return true


func buy_wall_color(i: int) -> bool:
	if i == wall_color or not spend(WALL_COST):
		return false
	wall_color = i
	decor_changed.emit()
	return true


# ---------------------------------------------------------------- saving

## Everything in this script that goes into a save file.
func to_dict() -> Dictionary:
	return {
		"money": money, "xp": xp, "day": day, "minute": minute,
		"next_market_minute": next_market_minute, "is_open": is_open, "opened": opened,
		"between_days": day_over, "prices": prices, "licensed": licensed.keys(),
		"upgrades": upgrades.keys(), "auto_price": auto_price,
		"floor_style": floor_style, "wall_color": wall_color, "stats": stats,
		"play_time": play_time,
		"staff": staff, "next_staff_id": _next_staff_id,
		"market": {"factor": market.factor, "previous": market.previous, "demand": market.demand, "news": market.news},
	}


## Loads what to_dict() saved. Unknown products are skipped and missing
## values keep their defaults, so old saves still load after you add stuff.
func from_dict(d: Dictionary) -> void:
	money = float(d.get("money", money))
	xp = float(d.get("xp", xp))
	level = level_for(xp)
	day = int(d.get("day", day))
	minute = float(d.get("minute", minute))
	next_market_minute = float(d.get("next_market_minute", next_market_minute))
	is_open = bool(d.get("is_open", is_open))
	opened = bool(d.get("opened", true))  # saves from before the sign existed were always open
	day_over = false
	auto_price = bool(d.get("auto_price", false))
	floor_style = clampi(int(d.get("floor_style", 0)), 0, FLOOR_STYLES.size() - 1)
	wall_color = clampi(int(d.get("wall_color", 0)), 0, WALL_COLORS.size() - 1)
	play_time = float(d.get("play_time", 0.0))
	for id: String in d.get("prices", {}):
		if PRODUCTS.has(id):
			prices[id] = float(d.prices[id])
	for id: String in d.get("licensed", []):
		if PRODUCTS.has(id):
			licensed[id] = true
	for id: String in d.get("upgrades", []):
		if UPGRADES.has(id):
			upgrades[id] = true
	var saved_stats: Dictionary = d.get("stats", {})
	for k: String in stats:
		if saved_stats.has(k):
			stats[k] = int(saved_stats[k]) if stats[k] is int else float(saved_stats[k])
	var m: Dictionary = d.get("market", {})
	for key in ["factor", "previous", "demand"]:
		var src: Dictionary = m.get(key, {})
		var dst: Dictionary = market.get(key)
		for id: String in src:
			if PRODUCTS.has(id):
				dst[id] = float(src[id])
	market.news = str(m.get("news", ""))
	for entry: Variant in d.get("staff", []):
		if entry is Dictionary and STAFF.has(str(entry.get("role", ""))):
			staff.append({"id": int(entry.get("id", 0)), "role": str(entry.role), "name": str(entry.get("name", "?"))})
	_next_staff_id = int(d.get("next_staff_id", staff.size() + 1))
	for entry in staff:
		_next_staff_id = maxi(_next_staff_id, entry.id + 1)


# ---------------------------------------------------------------- day cycle

func show_popup(world_pos: Vector2, text: String, color := Color.WHITE) -> void:
	popup.emit(world_pos, text, color)


func end_day() -> void:
	if day_over:
		return
	day_over = true
	var wages := daily_wages()
	if wages > 0.0:
		money -= wages  # wages are always paid, even if it puts you in the red
		stats.wages += wages
	var summary := stats.duplicate()
	summary.day = day
	summary.profit = stats.revenue - stats.spent - stats.invested - stats.wages
	_reset_stats()  # anything bought overnight counts toward tomorrow
	day_ended.emit(summary)


## Moves to the next morning. The clock waits until you flip the OPEN sign.
func start_next_day() -> void:
	day += 1
	minute = OPEN_MINUTE
	next_market_minute = OPEN_MINUTE + Market.UPDATE_EVERY_HOURS * 60
	opened = false
	is_open = false
	day_over = false
	day_started.emit(day)
	message.emit(Brand.SAY.morning % day)
	update_market(true)


## Flips the sign: the clock starts and customers start coming in.
func open_store() -> void:
	if opened or day_over:
		return
	opened = true
	is_open = true
	Settings.vibrate(0.4, 0.1)
	message.emit(Brand.SAY.opened)
	store_opened.emit()


func clock_text() -> String:
	var h := int(minute / 60.0)
	var m := int(minute) % 60
	var suffix := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, suffix]


func _reset_stats() -> void:
	stats = {"revenue": 0.0, "spent": 0.0, "invested": 0.0, "wages": 0.0, "customers": 0, "items_sold": 0, "missed": 0, "walkouts": 0, "cleaned": 0}
