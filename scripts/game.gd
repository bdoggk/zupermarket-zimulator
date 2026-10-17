extends Node
## Global game state: money, products, the market, store level, product
## licenses, upgrades, staff, store decor, the lots you've bought, the rival
## store down the street, the clock and daily stats.
## Registered as the "Game" autoload, so any script can use Game.money etc.
##
## The catalogs (products, furniture, paint, staff) come from brand.gd, the
## one script that's different between Supermarket Sim and Zupermarket
## Zimulator.

signal message(text: String)
signal popup(world_pos: Vector2, text: String, color: Color)
signal item_popup(world_pos: Vector2, id: String, qty: int)  # a shopper took something
signal prompt_changed(text: String, can_act: bool, scan_text: String)
signal computer_requested
signal box_ordered(product_id: String)
signal store_opened
signal store_closed
signal day_ended(summary: Dictionary)
signal day_started(day: int)
signal market_changed
signal unlocks_changed  # a license, upgrade or store level changed
signal leveled_up(from_level: int, to_level: int)  # the store went up a level (the HUD shows what's new)
signal decor_changed  # floor style or wall color changed
signal staff_changed  # someone was hired or fired
signal staff_leveled(id: int, level: int)
signal store_expanded  # bought the next lot
signal rival_requested  # open the rival's price list
signal rival_bought
signal rival_spy_sent  # Bone Mart sends a spy over to your store (the town does the walking)
signal shop_requested(shop: String)  # use a little shop's counter (Brand.SHOPS)
signal effects_changed  # a brew started or wore off
signal tutorial_changed

const OPEN_MINUTE := 8 * 60
const CLOSE_MINUTE := 20 * 60
## Real seconds per in-game minute. 0.5 means a 12 hour day lasts 6 minutes.
const SECONDS_PER_GAME_MINUTE := 0.5
const DELIVERY_SECONDS := 8.0  # without delivery upgrades
const PRICE_STEP := 0.25
const NIGHT_MINUTE := 17 * 60  # dusk: night owls (vampires) start coming out
const NIGHT_KIND_BY_DAY := 0.3  # ...and before that they're this much rarer
const MAX_EFFECT_SECONDS := 600.0  # brews stack up to this long
const SWIFT_SPEED := 1.5  # Swift Potion: you run this much faster
const QUICKHAND_SPEED := 2.0  # Quickhand Potion: you work this much faster
const CHARM_TRAFFIC := 1.5  # Charm Potion: this many more shoppers
const WINE_PATIENCE := 0.5  # Grave Wine: shoppers lose patience this fast
const RUMOR_PULL := 0.1  # a rumor from your spy sends this many fewer shoppers to the rival
const SPY_EVERY_MINUTES := 120  # your spy goes back over this often (game minutes)
const SPY_REPORT_XP := 6.0  # your spy, for each report
const SPY_CATCH_XP := 6.0  # your spy, for throwing out one of the rival's
const MIN_PRICE := 0.05
const MAX_PRICE := 999.99
const STARTING_MONEY := 100.0

## Store level. You earn 1 XP for every dollar of sales. Each number is the
## XP needed to reach the next level (level 2 at 150 XP, level 3 at 400...).
const LEVEL_XP := [0, 150, 400, 800, 1400, 2200]
## Blood on the floor costs XP while the store is open: this much per spill
## per game hour (you never drop a level, though).
const BLOOD_XP_PER_HOUR := 1.5
## Licensing a product earns XP: this much per dollar the license cost.
const LICENSE_XP := 0.25

## The catalogs. Edit them in brand.gd.
const PRODUCTS := Brand.PRODUCTS
const UPGRADES := Brand.UPGRADES
const FURNITURE := Brand.FURNITURE
const FLOOR_STYLES := Brand.FLOOR_STYLES
const WALL_COLORS := Brand.WALL_COLORS
const STAFF := Brand.STAFF
const SELL_REFUND := 0.5  # selling furniture gives back half what it cost
## Staff level up as they work: 1 XP per item stocked or scanned, more per
## spill mopped. Each number is the XP needed for that level (level 2 at
## 30 XP...). Every level makes them this much faster at everything.
const STAFF_LEVEL_XP := [0, 30, 80, 160, 280]
const STAFF_SPEED_PER_LEVEL := 0.15
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
var staff: Array[Dictionary] = []  # everyone you've hired: [{id, role, name, xp, level}]
var _next_staff_id := 1
var expansions := 0  # lots next door you've bought (Brand.EXPANSIONS)
var rival_owned := false  # bought out the rival store
var rival_factor := {}  # product id -> the rival's price today / market price
var rival_deal := ""  # the rival's deal of the day
var rival_seen := {}  # product id -> [price, day] when you last checked the rival
var rival_spies: Array = []  # game minutes today when the rival sends a spy over (soonest first)
var tutorial := {}  # first-day tips you've done (see ui/tutorial.gd)
var tutorial_hidden := false  # you pressed "Hide tips"
var effects := {}  # brew id -> seconds it still works for (Brand.BREWS)

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
	expansions = 0
	rival_owned = false
	rival_seen = {}
	rival_spies = []
	tutorial = {}
	tutorial_hidden = false
	effects = {}
	player = null
	store = null
	build_mode = null
	for id in PRODUCTS:
		prices[id] = PRODUCTS[id].base_price
		if PRODUCTS[id].license <= 0.0:
			licensed[id] = true
	roll_rival_prices()
	_reset_stats()


## True while the store scene is running (not on the main menu).
func in_game() -> bool:
	return is_instance_valid(store)


func _process(delta: float) -> void:
	if not in_game():
		return
	play_time += delta
	_tick_effects(delta)
	if not is_open:
		return
	minute += delta / SECONDS_PER_GAME_MINUTE
	if Brand.SPILLS and is_instance_valid(store) and not store.spills.is_empty() and not has_effect("crucifix"):
		lose_xp(store.spills.size() * BLOOD_XP_PER_HOUR * delta / (SECONDS_PER_GAME_MINUTE * 60.0))
	if minute >= next_market_minute and next_market_minute < CLOSE_MINUTE:
		next_market_minute += Market.UPDATE_EVERY_HOURS * 60
		update_market(false)
	check_rival_spies()
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


## Buys a box of `id` (it arrives after delivery_seconds()). `quiet`
## skips the messages, for staff who order (they say it themselves).
func order_box(id: String, quiet := false) -> bool:
	if not is_licensed(id):
		return false
	if quiet and money + 0.001 < box_cost(id):
		return false
	if not spend(box_cost(id), true):
		return false
	box_ordered.emit(id)
	if not quiet:
		var t := delivery_seconds()
		message.emit("Ordered %s. It arrives in %s." % [product_name(id), "%d seconds" % roundi(t) if t >= 1.5 else "a moment"])
	return true


## How long a box takes to arrive: the fastest delivery upgrade you own.
func delivery_seconds() -> float:
	var t := DELIVERY_SECONDS
	for id in upgrades:
		if UPGRADES.has(id) and UPGRADES[id].has("delivery"):
			t = minf(t, UPGRADES[id].delivery)
	return t


func change_price(id: String, amount: float) -> void:
	set_price(id, prices[id] + amount)


## A price you typed in (or nudged with - and +), to the cent.
func set_price(id: String, price: float) -> void:
	prices[id] = clampf(snappedf(price, 0.01), MIN_PRICE, MAX_PRICE)


## "3", "3.5", "$3.50" or "3,50" -> 3.5. -1 if it isn't a price.
static func parse_price(text: String) -> float:
	var t := text.strip_edges().trim_prefix("$").strip_edges().replace(",", ".")
	if t.is_empty() or not t.is_valid_float():
		return -1.0
	var v := t.to_float()
	return v if v >= 0.0 else -1.0


func match_market(id: String) -> void:
	prices[id] = market_price(id)


func match_all_prices() -> void:
	for id in unlocked_ids():
		match_market(id)


## Chance (0-1) that a customer still buys at your price. `tolerance` is
## how far over the market price they'll go without blinking (1 = not at
## all, 1.5 = half again; see Brand.SHOPPERS).
func buy_chance(id: String, tolerance := 1.0) -> float:
	var markup: float = prices[id] / market_price(id)
	if markup <= tolerance:
		return 1.0
	return clampf(1.0 - (markup - tolerance) * 1.6, 0.0, 1.0)


# ---------------------------------------------------------------- shoppers

## A random kind of shopper (Brand.SHOPPERS), from the ones that come to a
## store of your level.
func pick_shopper_kind() -> Dictionary:
	var pool := []
	var total := 0.0
	var weights: Array[float] = []
	for id in Brand.SHOPPERS:
		var k: Dictionary = Brand.SHOPPERS[id]
		if level >= int(k.level):
			pool.append(k)
			weights.append(shopper_weight(k))
			total += weights[-1]
	var roll := randf() * total
	for i in pool.size():
		roll -= weights[i]
		if roll <= 0.0:
			return pool[i]
	return pool[-1]


## How common a kind of shopper is right now (night owls come out after 5 PM).
func shopper_weight(k: Dictionary) -> float:
	var w := float(k.weight)
	if k.has("night"):
		w *= float(k.night) if minute >= NIGHT_MINUTE else NIGHT_KIND_BY_DAY
	return w


# ---------------------------------------------------------------- the rival store

## New prices at the rival for the day, plus its deal of the day.
func roll_rival_prices() -> void:
	rival_factor = {}
	for id in PRODUCTS:
		rival_factor[id] = randf_range(Brand.RIVAL.price_low, Brand.RIVAL.price_high)
	var ids := unlocked_ids()
	rival_deal = ids.pick_random() if not ids.is_empty() else ""
	if rival_deal != "":
		rival_factor[rival_deal] = Brand.RIVAL.deal


func rival_price(id: String) -> float:
	return maxf(PRICE_STEP, snappedf(market_price(id) * float(rival_factor.get(id, 1.0)), 0.05))


## Notes down what the rival charges for these products right now.
func scout_rival(ids: Array) -> void:
	for id in ids:
		rival_seen[id] = [rival_price(id), day]


## Chance (0-1) that a shopper who wants `list` goes to the rival instead
## of you. It's cheaper for most things, so match or beat its prices. A
## messy store drives shoppers away; decorations bring them in.
func rival_pull(list: Array, kind: Dictionary) -> float:
	if rival_owned or has_effect("stake"):
		return 0.0  # it's yours, or there's a stake in its door
	var pull: float = Brand.RIVAL.share + float(kind.get("rival", 0.0))
	if not list.is_empty():
		var diff := 0.0
		for item: Dictionary in list:
			var m := market_price(item.id)
			diff += clampf((prices[item.id] - rival_price(item.id)) / m, -0.6, 0.6)
			if not is_licensed(item.id):
				pull += 0.08  # you don't even sell it
		pull += diff / list.size() * 1.2
	if in_game():
		pull += 0.025 * (0 if has_effect("crucifix") else store.spills.size())
		pull -= 0.02 * mini(store.plant_count(), 6)
	if has_effect("rumor"):
		pull -= RUMOR_PULL
	return clampf(pull, 0.05, 0.85)


## Why you can't buy out the rival yet ("" means you can).
func rival_buyout_problem() -> String:
	if rival_owned:
		return "It's yours"
	if level < int(Brand.RIVAL.buyout_level):
		return "Reach store level %d" % int(Brand.RIVAL.buyout_level)
	if money + 0.001 < Brand.RIVAL.buyout:
		return "Not enough money"
	return ""


func buy_out_rival() -> bool:
	if rival_buyout_problem() != "" or not spend(Brand.RIVAL.buyout):
		return false
	rival_owned = true
	Settings.vibrate(0.8, 0.4)
	message.emit(Brand.RIVAL.bought)
	rival_bought.emit()
	return true


# ---------------------------------------------------------------- spying

## When the rival's spies come over today (none on the first days, none
## once you own it). Called each morning.
func roll_rival_spies() -> void:
	rival_spies = []
	if rival_owned or Brand.RIVAL.is_empty() or day < int(Brand.RIVAL.get("spy_from_day", 1 << 20)):
		return
	var per_day: Array = Brand.RIVAL.get("spies_per_day", [1, 1])
	var count: int = per_day[1] if level >= 3 else per_day[0]
	var span := (18 * 60 + 30) - (9 * 60)  # between 9 AM and 6:30 PM...
	for i in count:  # ...spread out over the day
		var lo := 9 * 60 + span * i / count
		rival_spies.append(randi_range(lo + 15, lo + span / count - 15))


## The rival's next spy is due: the town sends it over.
func check_rival_spies() -> void:
	if not is_open or rival_owned or rival_spies.is_empty() or minute < float(rival_spies[0]):
		return
	rival_spies.pop_front()
	rival_spy_sent.emit()


## The rival's spy got away after looking at your shelves of `seen`
## products: the rival prices them just under yours for the rest of the
## day (what's announced goes in your notes on its prices too).
func rival_spy_got_away(seen: Array) -> void:
	stats.spies_escaped = int(stats.get("spies_escaped", 0)) + 1
	if rival_owned:
		return
	var cut: Array[String] = []
	for id: String in seen:
		if not PRODUCTS.has(id):
			continue
		var m := market_price(id)
		var target := maxf(prices[id] * float(Brand.RIVAL.spy_undercut), m * float(Brand.RIVAL.spy_floor)) / m
		if target < float(rival_factor.get(id, 1.0)) - 0.005:
			rival_factor[id] = target
			rival_seen[id] = [rival_price(id), day]
			cut.append("%s $%.2f" % [product_name(id), rival_price(id)])
	if cut.is_empty():
		message.emit(Brand.RIVAL.spy_nothing)
	else:
		message.emit(Brand.RIVAL.spy_cheaper % Staff._list(cut))


## You (or your spy, `by`: their name) threw the rival's spy out.
func rival_spy_caught(by := "") -> void:
	stats.spies_caught = int(stats.get("spies_caught", 0)) + 1
	if by == "":
		add_xp(float(Brand.RIVAL.get("spy_caught_xp", 0.0)))
		message.emit(Brand.RIVAL.spy_caught)
	else:
		message.emit(Brand.RIVAL.spy_caught_by % by)


## Your spy (`who`) is back from the rival with news: its whole price list
## and deal of the day, when its next spy is coming, and a rumor that keeps
## shoppers away from it for a while.
func spy_report(who: String) -> void:
	if rival_owned:
		return
	stats.spy_reports = int(stats.get("spy_reports", 0)) + 1
	scout_rival(PRODUCTS.keys())
	var news: Array[String] = ["%s is back from %s. All its prices are in Stock & Prices now" % [who, Brand.RIVAL.name]]
	if rival_deal != "":
		news[0] += " (deal of the day: %s, $%.2f)" % [product_name(rival_deal), rival_price(rival_deal)]
	news[0] += "."
	if not rival_spies.is_empty():
		news.append("It's sending a spy over at about %s." % time_text(roundi(float(rival_spies[0]) / 30.0) * 30))
	elif day >= int(Brand.RIVAL.get("spy_from_day", 1 << 20)):
		news.append("No more spies coming from it today.")
	var had_rumor := has_effect("rumor")
	effects["rumor"] = maxf(float(effects.get("rumor", 0.0)), float(Brand.BREWS.rumor.seconds))
	news.append("%s spread a rumor about it: fewer %s will go there for a while." % [who, Brand.SAY.shoppers])
	message.emit(" ".join(news))
	if not had_rumor:
		effects_changed.emit()


## "2:30 PM" for a time of day in minutes.
static func time_text(m: int) -> String:
	var h := (m / 60) % 24
	return "%d:%02d %s" % [12 if h % 12 == 0 else h % 12, m % 60, "AM" if h < 12 else "PM"]


# ---------------------------------------------------------------- the lots next door

## The next lot you can buy, or {} if you've bought them all.
func next_expansion() -> Dictionary:
	return Brand.EXPANSIONS[expansions] if expansions < Brand.EXPANSIONS.size() else {}


## Why you can't buy the next lot ("" means you can).
func expansion_problem() -> String:
	var e := next_expansion()
	if e.is_empty():
		return "You've bought all the land there is"
	if level < int(e.level):
		return "Reach store level %d first" % int(e.level)
	if money + 0.001 < e.cost:
		return "Not enough money"
	return ""


func buy_expansion() -> bool:
	if expansion_problem() != "" or not spend(next_expansion().cost):
		return false
	expansions += 1
	Settings.vibrate(0.6, 0.2)
	message.emit("You bought the lot next door! The store is bigger now.")
	store_expanded.emit()
	return true


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
	var bonus := roundf(PRODUCTS[id].license * LICENSE_XP)
	var text := "You can now sell %s! Order it in the Stock tab." % product_name(id)
	if is_cold(id):
		text += " It needs a fridge (Build mode)."
	if bonus > 0.0:
		text += " +%d XP" % int(bonus)
	message.emit(text)
	unlocks_changed.emit()
	if bonus > 0.0:
		add_xp(bonus)
	return true


## Products you could license now (your level is high enough) but haven't.
func licensable_ids() -> Array:
	return PRODUCTS.keys().filter(func(id): return can_license(id))


func has_upgrade(id: String) -> bool:
	return upgrades.has(id)


## Why you can't buy upgrade `id` yet ("" means you can, money aside).
func upgrade_problem(id: String) -> String:
	var u: Dictionary = UPGRADES[id]
	if has_upgrade(id):
		return "Owned"
	var needs: String = u.get("requires", "")
	if needs != "" and not has_upgrade(needs):
		return "Needs the %s" % UPGRADES[needs].name
	if level < int(u.get("level", 1)):
		return "Store level %d" % int(u.level)
	if u.has("zone") and is_instance_valid(store):
		return store.grow_error(store.zone_size_for(u.zone))
	return ""


func buy_upgrade(id: String) -> bool:
	if upgrade_problem(id) != "" or not spend(UPGRADES[id].cost):
		return false
	upgrades[id] = true
	if UPGRADES[id].has("zone") and is_instance_valid(store):
		store.grow_delivery_zone(store.zone_size_for(UPGRADES[id].zone))
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


## XP at the start of the current level (you never drop below it).
func level_start_xp() -> float:
	return LEVEL_XP[level - 1] if level >= 1 and level <= LEVEL_XP.size() else 0.0


## How far along the current level you are, 0 to 1 (1 at max level).
func level_progress() -> float:
	var next := next_level_xp()
	if next < 0.0:
		return 1.0
	return clampf((xp - level_start_xp()) / (next - level_start_xp()), 0.0, 1.0)


func add_xp(amount: float) -> void:
	xp += amount
	var new_level := level_for(xp)
	if new_level <= level:
		return
	var from := level
	level = new_level
	Settings.vibrate(0.8, 0.35)
	message.emit("Store level %d!" % level)
	unlocks_changed.emit()
	leveled_up.emit(from, level)


## Takes XP away (blood on the floor), but never below the start of your
## current level. Returns how much was really lost.
func lose_xp(amount: float) -> float:
	var lost := minf(amount, maxf(0.0, xp - level_start_xp()))
	xp -= lost
	stats.xp_lost = float(stats.get("xp_lost", 0.0)) + lost
	return lost


## What reaching store level `lv` gives you, as lines of text: products you
## can license, upgrades, the next lot, new kinds of shoppers...
func unlocks_at(lv: int) -> Array[String]:
	var lines: Array[String] = []
	var products := PRODUCTS.keys().filter(func(id): return int(PRODUCTS[id].level) == lv)
	if not products.is_empty():
		lines.append("New products to license: %s" % ", ".join(products.map(func(id): return product_name(id))))
	var ups := UPGRADES.keys().filter(func(id): return int(UPGRADES[id].get("level", 1)) == lv)
	if not ups.is_empty():
		lines.append("New upgrades: %s" % ", ".join(ups.map(func(id): return UPGRADES[id].name)))
	for i in Brand.EXPANSIONS.size():
		if int(Brand.EXPANSIONS[i].level) == lv:
			lines.append("You can buy lot %d next door (Build > Expand) to make the store bigger" % (i + 1))
	var kinds := Brand.SHOPPERS.values().filter(func(k): return int(k.get("level", 1)) == lv)
	if not kinds.is_empty():
		lines.append("New shoppers: %s" % ", ".join(kinds.map(func(k): return str(k.get("plural", (k.name as String).to_lower() + "s")))))
	if not Brand.RIVAL.is_empty() and int(Brand.RIVAL.get("buyout_level", 0)) == lv and not rival_owned:
		lines.append("You can buy out %s ($%d)" % [Brand.RIVAL.name, int(Brand.RIVAL.buyout)])
	lines.append("%d%% more shoppers come by" % roundi(Store.LEVEL_TRAFFIC * 100.0))
	return lines


# ---------------------------------------------------------------- staff

func staff_count(role: String) -> int:
	return staff.filter(func(s): return s.role == role).size()


## The most of `role` you can have right now. Cashiers are limited to one
## per register.
func staff_limit(role: String) -> int:
	var limit: int = STAFF[role].max
	if role == "cashier" and in_game():
		limit = mini(limit, store.registers.filter(func(r): return not r is SelfCheckout).size())
	return limit


## Why you can't hire a `role` right now ("" means you can).
func hire_problem(role: String) -> String:
	if role == "spy" and rival_owned:
		return "%s is yours: nobody to spy on" % Brand.RIVAL.name
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
	var entry := {"id": _next_staff_id, "role": role, "name": _pick_staff_name(), "xp": 0.0, "level": 1}
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


func staff_entry(id: int) -> Dictionary:
	for s in staff:
		if s.id == id:
			return s
	return {}


static func staff_level_for(amount: float) -> int:
	var lv := 0
	for need in STAFF_LEVEL_XP:
		if amount >= need:
			lv += 1
	return maxi(lv, 1)


## How much faster than a new hire someone at `lv` works (1.0 = normal).
static func staff_speed(lv: int) -> float:
	return 1.0 + STAFF_SPEED_PER_LEVEL * (lv - 1)


## XP needed for their next level, or -1 at max level.
static func staff_next_xp(lv: int) -> float:
	return STAFF_LEVEL_XP[lv] if lv < STAFF_LEVEL_XP.size() else -1.0


## Staff member `id` did some work.
func add_staff_xp(id: int, amount: float) -> void:
	var entry := staff_entry(id)
	if entry.is_empty():
		return
	entry.xp += amount
	var lv := staff_level_for(entry.xp)
	if lv <= entry.level:
		return
	entry.level = lv
	message.emit("%s is now level %d and works %d%% faster!" % [entry.name, lv, roundi((staff_speed(lv) - 1.0) * 100.0)])
	Settings.vibrate(0.3, 0.08)
	staff_leveled.emit(id, lv)


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


## A shopper wanted `id`, but you don't sell it (no license yet). Asked
## about twice in a day, you get a reminder to license it.
func record_wanted(id: String) -> void:
	var wanted: Dictionary = stats.get("wanted", {})
	wanted[id] = int(wanted.get(id, 0)) + 1
	stats.wanted = wanted
	if wanted[id] == 2:
		message.emit("%s keep asking for %s. License it at the computer (Products)!" % [Brand.SAY.shoppers.capitalize(), product_name(id)])


func record_walkout() -> void:
	stats.walkouts += 1


func record_spill_cleaned() -> void:
	stats.cleaned += 1


## You did one of the first-day tips (ui/tutorial.gd).
func tutorial_step_done(step: String) -> void:
	if not tutorial.has(step):
		tutorial[step] = true
		tutorial_changed.emit()


## A shopper went to the rival store instead.
func record_lost() -> void:
	stats.lost += 1


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
		"staff": staff, "next_staff_id": _next_staff_id, "expansions": expansions,
		"rival": {"owned": rival_owned, "factor": rival_factor, "deal": rival_deal, "seen": rival_seen, "spies": rival_spies},
		"tutorial": tutorial.keys(), "tutorial_hidden": tutorial_hidden, "effects": effects,
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
		if not saved_stats.has(k):
			continue
		if stats[k] is Dictionary:
			if saved_stats[k] is Dictionary:
				stats[k] = (saved_stats[k] as Dictionary).duplicate()
		else:
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
			var xp_have := maxf(0.0, float(entry.get("xp", 0.0)))
			staff.append({"id": int(entry.get("id", 0)), "role": str(entry.role), "name": str(entry.get("name", "?")),
				"xp": xp_have, "level": staff_level_for(xp_have)})
	_next_staff_id = int(d.get("next_staff_id", staff.size() + 1))
	expansions = clampi(int(d.get("expansions", 0)), 0, Brand.EXPANSIONS.size())
	var fx: Variant = d.get("effects", {})
	if fx is Dictionary:
		for id: String in fx:
			if Brand.BREWS.has(id) and float(fx[id]) > 0.0:
				effects[id] = minf(float(fx[id]), MAX_EFFECT_SECONDS)
	var r: Dictionary = d.get("rival", {})
	rival_owned = bool(r.get("owned", false))
	var factors: Dictionary = r.get("factor", {})
	for id: String in factors:
		if PRODUCTS.has(id):
			rival_factor[id] = clampf(float(factors[id]), 0.3, 2.0)
	if PRODUCTS.has(str(r.get("deal", ""))):
		rival_deal = str(r.deal)
	for step in d.get("tutorial", []):
		tutorial[str(step)] = true
	tutorial_hidden = bool(d.get("tutorial_hidden", false))
	var seen: Dictionary = r.get("seen", {})
	for id: String in seen:
		if PRODUCTS.has(id) and seen[id] is Array and seen[id].size() >= 2:
			rival_seen[id] = [float(seen[id][0]), int(seen[id][1])]
	for entry in staff:
		_next_staff_id = maxi(_next_staff_id, entry.id + 1)
	if r.get("spies") is Array:
		rival_spies = []
		for at in r.spies:
			rival_spies.append(int(at))
	else:  # a save from before the rival had spies
		roll_rival_spies()
		rival_spies = rival_spies.filter(func(at): return at > minute)


# ---------------------------------------------------------------- day cycle

func show_popup(world_pos: Vector2, text: String, color := Color.WHITE) -> void:
	popup.emit(world_pos, text, color)


# ---------------------------------------------------------------- brews

## A brew (or charm) from one of the little shops is working right now.
func has_effect(id: String) -> bool:
	return float(effects.get(id, 0.0)) > 0.0


## Why you can't buy brew `id` right now ("" if you can).
func brew_problem(id: String) -> String:
	if str(Brand.BREWS[id].get("shop", "")) == "":
		return "Not for sale"
	if id == "stake" and rival_owned:
		return "%s is yours already" % Brand.RIVAL.name
	if float(effects.get(id, 0.0)) + float(Brand.BREWS[id].seconds) > MAX_EFFECT_SECONDS + 0.01:
		return "You've got plenty"
	if money + 0.001 < float(Brand.BREWS[id].cost):
		return "Not enough money"
	return ""


## Buys brew `id` from its shop. It works straight away; another one
## adds more time.
func buy_brew(id: String) -> bool:
	if not Brand.BREWS.has(id) or brew_problem(id) != "":
		return false
	var b: Dictionary = Brand.BREWS[id]
	if not spend(float(b.cost)):
		return false
	effects[id] = float(effects.get(id, 0.0)) + float(b.seconds)
	stats.brews = int(stats.get("brews", 0)) + 1
	message.emit(Brand.SAY.brew_bought % [b.name, b.desc])
	Settings.vibrate(0.3, 0.08)
	effects_changed.emit()
	return true


func _tick_effects(delta: float) -> void:
	if effects.is_empty():
		return
	for id: String in effects.keys():
		var b: Dictionary = Brand.BREWS[id]
		if b.get("open_only", false) and not is_open:
			continue
		effects[id] = float(effects[id]) - delta
		if effects[id] <= 0.0:
			effects.erase(id)
			message.emit(str(b.done) if b.has("done") else Brand.SAY.brew_done % b.name)
			effects_changed.emit()


## "+2 Canned Guts" with the product's picture, over a shopper's head.
func show_item_popup(world_pos: Vector2, id: String, qty: int) -> void:
	item_popup.emit(world_pos, id, qty)


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


## A save made after the day ended was loaded: it's still that night.
## The day-over prompt comes back up, and the next day starts when you say
## so (the day's wages were already paid).
func resume_day_over() -> void:
	day_over = true
	opened = true
	is_open = false
	minute = CLOSE_MINUTE
	day_ended.emit({"day": day, "resumed": true})


## Moves to the next morning. The clock waits until you flip the OPEN sign.
func start_next_day() -> void:
	day += 1
	minute = OPEN_MINUTE
	next_market_minute = OPEN_MINUTE + Market.UPDATE_EVERY_HOURS * 60
	opened = false
	is_open = false
	day_over = false
	roll_rival_prices()
	roll_rival_spies()
	day_started.emit(day)
	message.emit(Brand.SAY.morning % day)
	update_market(true)
	if not rival_owned and rival_deal != "":
		message.emit(Brand.RIVAL.deal_news % product_name(rival_deal))


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
	stats = {"revenue": 0.0, "spent": 0.0, "invested": 0.0, "wages": 0.0, "customers": 0, "items_sold": 0, "missed": 0, "walkouts": 0, "cleaned": 0, "lost": 0, "wanted": {}, "xp_lost": 0.0, "brews": 0,
		"spies_caught": 0, "spies_escaped": 0, "spy_reports": 0}
