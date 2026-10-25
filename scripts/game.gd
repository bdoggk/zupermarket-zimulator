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
signal rival_spy_sent  # Bone Mart sends a spy over to your store (the town does the walking)
signal shop_requested(shop: String)  # use a little shop's counter (Brand.SHOPS)
signal rack_requested(rack: StorageRack)  # pick which box to take off a storage rack
signal staff_rules_changed  # the Staff app's rules, or a product's Stock switch
signal effects_changed  # a brew started or wore off
signal loan_changed  # borrowed, paid (or a payment was taken)
signal loan_defaulted  # the loan's last night came and it isn't paid: the lender comes for your head
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
const FAVORITE_PULL := 0.75  # each favorite (Brand.SHOPPERS likes) on your shelves brings this many more of the kind that loves it
const FAVORITE_WANT := 4.0  # ...they're this many times as likely to want it...
const FAVORITE_RIVAL := 0.05  # ...and this much less likely to shop at the rival
const SPY_EVERY_MINUTES := 120  # your spy goes back over this often (game minutes)
const SPY_REPORT_XP := 6.0  # your spy, for each report
const SPY_CATCH_XP := 6.0  # your spy, for throwing out one of the rival's
const MIN_PRICE := 0.05
const MARKUP_STEP := 0.05  # Stock & Prices: the markup goes up and down in steps of 5%...
const MARKUP_MIN := -0.25  # ...from 25% under the market...
const MARKUP_MAX := 0.5  # ...to 50% over
const MAX_PRICE := 999.99
const STARTING_MONEY := 100.0

## Store level. You earn 1 XP for every dollar of sales. Each number is the
## XP needed to reach the next level (level 2 at 150 XP, level 3 at 400...).
## There's no top level: after these, each level takes LEVEL_XP_STEP more
## XP than the one before (see xp_for_level).
const LEVEL_XP := [0, 150, 400, 800, 1400, 2200, 3200, 4500, 6000, 8000, 10500, 13500, 17000, 21000]
const LEVEL_XP_STEP := 1000.0
## The last level with something new to unlock. Every level after it pays
## a cash bonus (level_bonus) instead.
const LAST_UNLOCK_LEVEL := 14
const TRAFFIC_LEVELS := 14  # levels past this don't bring more shoppers (the store's full)
## Store levels that let you hire one more of a kind of staff.
const STAFF_PERKS := {"stocker": [8, 12], "cashier": [9], "janitor": [10]}
## Decorations that bring in one kind of shopper (Brand.FURNITURE "pulls"):
## each one brings this many more of them, counting up to DECOR_PULL_MAX.
const DECOR_PULL := 0.5
const DECOR_PULL_MAX := 3
## Upgrades (Brand.UPGRADES) past level 6:
const CONVEYOR_SPEED := 1.25  # Conveyor Belts: registers ring up this much faster
const BILLBOARD_TRAFFIC := 1.15  # Billboard and Neon Billboard: this many more shoppers each
const TRAINING_XP := 2.0  # Staff Training: staff XP this many times as fast...
const TRAINING_LEVEL_XP := [450, 700]  # ...and two more levels at these
const DRAIN_MINUTES := 120  # Floor Drains: a puddle this old (game minutes, while open) drains away
const GOLDEN_SIGN_TOLERANCE := 1.1  # Golden Sign: shoppers pay this much more before it's pricey
## Loans (the computer's Loans app, Brand.LOAN). One at a time, paid back
## in LOAN_DAYS payments taken every morning. The more you borrow, the
## higher the interest (LOAN_RATES, one for each of LOAN_AMOUNTS).
const LOAN_DAYS := 7
const LOAN_AMOUNTS := [250, 500, 1000, 2000, 3000, 5000, 7500, 10000, 15000, 20000]
const LOAN_RATES := [0.05, 0.08, 0.12, 0.15, 0.18, 0.2, 0.23, 0.25, 0.28, 0.3]
const LOAN_LIMIT_PER_LEVEL := 1000.0  # you can borrow up to this times your store level
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
## When the general manager orders more of something (Staff app): once
## everything there is of it (on its shelves, in boxes, on the way) is down
## to `share` of the shelf space labeled for it. -1: as soon as a whole box
## would fit (the busiest, and how it always worked).
const REORDER_POINTS := [
	{"name": "When a box fits", "share": -1.0},
	{"name": "3/4 full", "share": 0.75},
	{"name": "Half full", "share": 0.5},
	{"name": "1/3 full", "share": 0.34},
	{"name": "1/4 full", "share": 0.25},
	{"name": "Almost empty", "share": 0.0},
]
const WALL_COST := 30.0

var money := STARTING_MONEY
var prices := {}  # product id -> what you sell it for
var licensed := {}  # product id -> true once you're allowed to sell it
var upgrades := {}  # upgrade id -> true once bought
var xp := 0.0
var level := 1
var floor_style := 0
var snake_best := 0  # the store computer's Snake: the best score (kept with the store)
var wall_color := 0
var market := Market.new()
var day := 1
var minute := float(OPEN_MINUTE)
var next_market_minute := float(OPEN_MINUTE + Market.UPDATE_EVERY_HOURS * 60)
var opened := false  # the OPEN sign has been flipped today
var is_open := false  # open for customers (after the sign is flipped, until 8 PM)
var day_over := false
var stats := {}
const LOG_SIZE := 60  # messages kept in the log
var message_log: Array[Dictionary] = []  # recent messages, oldest first: {text, day, time}
var price_markup := 0.0  # Stock & Prices: prices are set to the market price plus this much (0.1 = +10%)
var auto_price := false  # your prices follow the market automatically
## How your staff work (the computer's Staff app, and the Stock switch in
## Stock & Prices):
var unstocked := {}  # product id -> true: stockers don't put it on shelves and the manager doesn't order it
var fill_empty_shelves := true  # stockers put things on shelves with no label (and the manager orders for them)
var take_labels_off := true  # stockers take the label off an empty shelf of something you've stopped stocking
var reorder_at := 0  # when the manager orders more: an index into REORDER_POINTS
var play_time := 0.0  # seconds played in this save
var slot := -1  # save slot being played (0-2), -1 = not saving (e.g. tests)
var touch_ui := false  # set by the HUD
var menu_open := false  # a window is open over the store (the computer, a shop...): you stay put (set by the HUD)
var staff: Array[Dictionary] = []  # everyone you've hired: [{id, role, name, xp, level}]
var _next_staff_id := 1
var expansions := 0  # lots next door you've bought (Brand.EXPANSIONS)
var war := GangWar.new()  # the gang war against Bone Mart (from store level 15)
var rival_factor := {}  # product id -> the rival's price today / market price
var rival_deal := ""  # the rival's deal of the day
var rival_seen := {}  # product id -> [price, day] when you last checked the rival
var rival_spies: Array = []  # game minutes today when the rival sends a spy over (soonest first)
var tutorial := {}  # first-day tips you've done (see ui/tutorial.gd)
var tutorial_hidden := false  # you pressed "Hide tips"
var effects := {}  # brew id -> seconds it still works for (Brand.BREWS)
## The loan you're paying back, or {} if none: {amount (borrowed), total
## (to pay back), payment (each morning), paid (so far), day (borrowed on),
## due (the day whose night it all has to be paid by)}.
var loan := {}
var cutscene := false  # the lender is collecting (the HUD and the player stand aside)
var fp: Node  # the first person view (FirstPerson), while a store's open

# Set by these nodes when they load.
var player: Node2D
var store: Node2D
var build_mode: Node2D


func _ready() -> void:
	reset()
	message.connect(_log_message)


## Every message also goes in the message log (HUD > Log, or M).
func _log_message(text: String) -> void:
	message_log.append({"text": text, "day": day, "time": clock_text()})
	while message_log.size() > LOG_SIZE:
		message_log.pop_front()


## Starts a fresh game (the main menu calls this for New Game and before
## loading a save).
func reset() -> void:
	message_log.clear()
	money = STARTING_MONEY
	prices = {}
	licensed = {}
	upgrades = {}
	xp = 0.0
	level = 1
	floor_style = 0
	snake_best = 0
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
	price_markup = 0.0
	unstocked = {}
	fill_empty_shelves = true
	take_labels_off = true
	reorder_at = 0
	play_time = 0.0
	slot = -1
	staff = []
	_next_staff_id = 1
	expansions = 0
	war = GangWar.new()
	rival_seen = {}
	rival_spies = []
	tutorial = {}
	tutorial_hidden = false
	effects = {}
	loan = {}
	cutscene = false
	player = null
	fp = null
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


## The price "=", Set all prices and Auto give a product: the market price
## plus your markup (Stock & Prices), to the nickel.
func target_price(id: String) -> float:
	return clampf(snappedf(market_price(id) * (1.0 + price_markup), 0.05), MIN_PRICE, MAX_PRICE)


func match_market(id: String) -> void:
	prices[id] = target_price(id)


func match_all_prices() -> void:
	for id in unlocked_ids():
		match_market(id)


## One markup for everything (0.1 = 10% over the market). With Auto on,
## every price moves to it right away.
func set_markup(m: float) -> void:
	price_markup = clampf(snappedf(m, 0.01), MARKUP_MIN, MARKUP_MAX)
	if auto_price:
		match_all_prices()


## "+10%", "at market", "-5%".
static func markup_text(m: float) -> String:
	var pct := roundi(m * 100.0)
	return "at market" if pct == 0 else "%+d%%" % pct


## What a markup means for the shoppers who come to your store now:
## "At +10%: vampires always pay it; zombies and brutes buy 84% of the
## time, skeletons 68%."
func markup_effect(m: float) -> String:
	if m > -0.001 and m <= 0.001:
		return "At the market price, every shopper buys what they came for."
	if m <= 0.001:
		return "At %s, every shopper buys what they came for (but you earn less per item)." % markup_text(m)
	var always: Array[String] = []
	var groups := {}  # percent -> kinds that buy that often
	for k: Dictionary in Brand.SHOPPERS.values():
		if level < int(k.get("level", 1)):
			continue
		var chance := buy_chance_at(1.0 + m, float(k.tolerance) * (GOLDEN_SIGN_TOLERANCE if has_upgrade("golden_sign") else 1.0))
		if chance >= 0.999:
			always.append(shopper_plural(k))
		else:
			var pct := roundi(chance * 100.0)
			if not groups.has(pct):
				groups[pct] = []
			groups[pct].append(shopper_plural(k))
	var parts: Array[String] = []
	if not always.is_empty():
		parts.append("%s always pay it" % _and_list(always))
	var pcts := groups.keys()
	pcts.sort()
	pcts.reverse()
	var some: Array[String] = []
	for pct: int in pcts:
		some.append(("%s buy %d%% of the time" if some.is_empty() else "%s %d%%") % [_and_list(groups[pct]), pct])
	if not some.is_empty():
		parts.append(", ".join(some))
	return "At %s: %s." % [markup_text(m), "; ".join(parts)]


## How likely a shopper who pays up to `tolerance` times the market price
## buys at `markup` times it (see buy_chance).
static func buy_chance_at(markup: float, tolerance: float) -> float:
	if markup <= tolerance:
		return 1.0
	return clampf(1.0 - (markup - tolerance) * 1.6, 0.0, 1.0)


static func _and_list(names: Array) -> String:
	if names.size() <= 1:
		return "".join(names)
	return ", ".join(names.slice(0, -1)) + " and " + str(names[-1])


## Chance (0-1) that a customer still buys at your price. `tolerance` is
## how far over the market price they'll go without blinking (1 = not at
## all, 1.5 = half again; see Brand.SHOPPERS).
func buy_chance(id: String, tolerance := 1.0) -> float:
	if has_upgrade("golden_sign"):
		tolerance *= GOLDEN_SIGN_TOLERANCE
	return buy_chance_at(prices[id] / market_price(id), tolerance)


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


## How common a kind of shopper is right now (night owls come out after
## 5 PM, and every one of their favorite products on your shelves brings
## more of them).
func shopper_weight(k: Dictionary) -> float:
	var w := float(k.weight)
	if k.has("night"):
		w *= float(k.night) if minute >= NIGHT_MINUTE else NIGHT_KIND_BY_DAY
	w *= 1.0 + DECOR_PULL * mini(decorations_for(k), DECOR_PULL_MAX)  # cauldrons for witches...
	return w * (1.0 + FAVORITE_PULL * favorites_on_shelves(k))


## How many decorations that bring in this kind of shopper (Brand.FURNITURE
## "pulls": a cauldron for witches...) are in the store.
func decorations_for(k: Dictionary) -> int:
	if not in_game():
		return 0
	var id: Variant = Brand.SHOPPERS.find_key(k)
	if id == null:
		return 0
	var n := 0
	for obj in store.objects.values():
		if obj is Decoration and FURNITURE.get(obj.furniture_id, {}).get("pulls", "") == id:
			n += 1
	return n


## Store level you need to build furniture `id` (1 = from the start).
func furniture_level(id: String) -> int:
	return int(FURNITURE[id].get("level", 1))


## How many of this kind of shopper's favorite products (Brand.SHOPPERS
## "likes") are on your shelves right now.
func favorites_on_shelves(k: Dictionary) -> int:
	if not in_game() or not k.has("likes"):
		return 0
	var n := 0
	for id: String in k.likes:
		if not store.shelves_with(id).is_empty():
			n += 1
	return n


## The kinds of shoppers whose favorite `id` is.
func fans_of(id: String) -> Array:
	return Brand.SHOPPERS.values().filter(func(k): return (k.get("likes", []) as Array).has(id))


## "witches", "skeletons"...
static func shopper_plural(k: Dictionary) -> String:
	return str(k.get("plural", (k.name as String).to_lower() + "s"))


## What someone in town (a skeleton, witch or vampire) tells you about
## their favorite products (Brand.SHOPPERS likes), most useful first: one
## you could license now (that counts as asking for it, like a shopper),
## one that's sold out on your shelves, one you'll be able to sell later,
## or one they love. "" for kinds with no favorites.
func townsfolk_says(kind: Dictionary) -> String:
	var likes: Array = kind.get("likes", [])
	if likes.is_empty():
		return ""
	var now := likes.filter(func(id): return can_license(id))
	if not now.is_empty():
		var id: String = now.pick_random()
		record_wanted(id, kind)
		return (Brand.SAY.town_wants as Array).pick_random() % product_name(id)
	var gone := likes.filter(func(id): return is_licensed(id) and in_game() and store.shelves_with(id).is_empty())
	if not gone.is_empty():
		return (Brand.SAY.town_gone as Array).pick_random() % product_name(gone.pick_random())
	var later := likes.filter(func(id): return not is_licensed(id))
	if not later.is_empty():
		return (Brand.SAY.town_later as Array).pick_random() % product_name(later.pick_random())
	return (Brand.SAY.town_loves as Array).pick_random() % product_name(likes.pick_random())


## "Witches love it" (or "" if nobody has it as a favorite).
func fans_text(id: String) -> String:
	var fans := fans_of(id).map(func(k): return shopper_plural(k))
	if fans.is_empty():
		return ""
	var s: String = " and ".join(fans)
	return s.left(1).to_upper() + s.substr(1) + " love it"


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
	if war.rival_closed or has_effect("stake"):
		return 0.0  # your gang smashed it up today, or there's a stake in its door
	var pull: float = Brand.RIVAL.share + float(kind.get("rival", 0.0)) + war.rival_pull_change()
	if not list.is_empty():
		var diff := 0.0
		for item: Dictionary in list:
			var m := market_price(item.id)
			diff += clampf((prices[item.id] - rival_price(item.id)) / m, -0.6, 0.6)
			if not is_licensed(item.id):
				pull += 0.08  # you don't even sell it
		pull += diff / list.size() * 1.2
	pull -= FAVORITE_RIVAL * favorites_on_shelves(kind)  # you've got what they love
	if in_game():
		if not has_effect("crucifix"):  # a messy store sends a few to the rival (not a couple of puddles)
			pull += minf(0.08, 0.01 * maxi(0, store.settled_spills() - Store.FREE_SPILLS))
		pull -= 0.02 * mini(store.plant_count(), 6)
	if has_effect("rumor"):
		pull -= RUMOR_PULL
	return clampf(pull, 0.05, 0.85)


# ---------------------------------------------------------------- spying

## When the rival's spies come over today (none on the first days, none
## while it's closed). Called each morning.
func roll_rival_spies() -> void:
	rival_spies = []
	if war.rival_closed or Brand.RIVAL.is_empty() or day < int(Brand.RIVAL.get("spy_from_day", 1 << 20)):
		return
	var per_day: Array = Brand.RIVAL.get("spies_per_day", [1, 1])
	var count: int = per_day[1] if level >= 3 else per_day[0]
	var span := (18 * 60 + 30) - (9 * 60)  # between 9 AM and 6:30 PM...
	for i in count:  # ...spread out over the day
		var lo := 9 * 60 + span * i / count
		rival_spies.append(randi_range(lo + 15, lo + span / count - 15))


## The rival's next spy is due: the town sends it over.
func check_rival_spies() -> void:
	if not is_open or war.rival_closed or rival_spies.is_empty() or minute < float(rival_spies[0]):
		return
	rival_spies.pop_front()
	rival_spy_sent.emit()


## The rival's spy got away after looking at your shelves of `seen`
## products: the rival prices them just under yours for the rest of the
## day (what's announced goes in your notes on its prices too).
func rival_spy_got_away(seen: Array) -> void:
	stats.spies_escaped = int(stats.get("spies_escaped", 0)) + 1
	if war.rival_closed:
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
	if war.rival_closed:
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


## Your staff stock `id` (it's licensed and its Stock switch is on).
func staff_stock(id: String) -> bool:
	return licensed.has(id) and not unstocked.has(id)


## The Stock switch in Stock & Prices.
func set_staff_stock(id: String, on: bool) -> void:
	if on:
		unstocked.erase(id)
	else:
		unstocked[id] = true
	staff_rules_changed.emit()


func set_reorder_at(i: int) -> void:
	reorder_at = clampi(i, 0, REORDER_POINTS.size() - 1)
	staff_rules_changed.emit()


func set_fill_empty_shelves(on: bool) -> void:
	fill_empty_shelves = on
	staff_rules_changed.emit()


func set_take_labels_off(on: bool) -> void:
	take_labels_off = on
	staff_rules_changed.emit()


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
	if id == "training":  # staff with the XP for the new levels get them now
		for entry in staff:
			var lv := staff_level_for(entry.xp)
			if lv > entry.level:
				entry.level = lv
				staff_leveled.emit(entry.id, lv)
	unlocks_changed.emit()
	return true


## XP needed to reach store level `lv` (1 needs none). Past the table, each
## level takes LEVEL_XP_STEP more than the one before, with no end.
static func xp_for_level(lv: int) -> float:
	if lv <= 1:
		return 0.0
	if lv <= LEVEL_XP.size():
		return float(LEVEL_XP[lv - 1])
	var need := float(LEVEL_XP[-1])
	var gap := float(LEVEL_XP[-1] - LEVEL_XP[-2])
	for k in range(LEVEL_XP.size() + 1, lv + 1):
		gap += LEVEL_XP_STEP
		need += gap
	return need


static func level_for(amount: float) -> int:
	var lv := 1
	while amount >= xp_for_level(lv + 1):
		lv += 1
	return lv


## XP needed for the next level (there's always one).
func next_level_xp() -> float:
	return xp_for_level(level + 1)


## XP at the start of the current level (you never drop below it).
func level_start_xp() -> float:
	return xp_for_level(level)


## The cash you get for reaching store level `lv`, past the last level
## that unlocks something new (0 before that).
static func level_bonus(lv: int) -> float:
	return 0.0 if lv <= LAST_UNLOCK_LEVEL else 500.0 + 250.0 * (lv - LAST_UNLOCK_LEVEL - 1)


## How far along the current level you are, 0 to 1.
func level_progress() -> float:
	return clampf((xp - level_start_xp()) / (next_level_xp() - level_start_xp()), 0.0, 1.0)


func add_xp(amount: float) -> void:
	xp += amount
	var new_level := level_for(xp)
	if new_level <= level:
		return
	var from := level
	level = new_level
	Settings.vibrate(0.8, 0.35)
	message.emit("Store level %d!" % level)
	var bonus := 0.0
	for lv in range(from + 1, level + 1):
		bonus += level_bonus(lv)
	if bonus > 0.0:
		money += bonus
		message.emit("Level bonus: +$%d!" % int(bonus))
	unlocks_changed.emit()
	leveled_up.emit(from, level)
	war.check_level(level)


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
		lines.append("New shoppers: %s" % ", ".join(kinds.map(func(k): return shopper_plural(k))))
	for id: String in FURNITURE:
		var f: Dictionary = FURNITURE[id]
		if int(f.get("level", 1)) == lv and lv > 1:
			var pulls := " (brings in more %s)" % shopper_plural(Brand.SHOPPERS[f.pulls]) if Brand.SHOPPERS.has(f.get("pulls", "")) else ""
			lines.append("New in Build mode: %s%s" % [f.name, pulls])
	for role: String in STAFF_PERKS:
		if lv in STAFF_PERKS[role] and STAFF.has(role):
			lines.append("You can hire one more %s" % (STAFF[role].name as String).to_lower())
	if level_bonus(lv) > 0.0:
		lines.append("A level bonus: $%d" % int(level_bonus(lv)))
	# "Werewolves love Moon Steak and Howl Jerky" (one line per kind of fan).
	var loves := {}  # "Werewolves" -> product names
	for id: String in products.filter(func(id): return not fans_of(id).is_empty()):
		var who := fans_text(id).trim_suffix(" love it")
		loves[who] = loves.get(who, []) + [product_name(id)]
	if not loves.is_empty():
		var count: int = loves.values().reduce(func(n, names): return n + names.size(), 0)
		lines.append("; ".join(loves.keys().map(func(who): return "%s love %s" % [who, " and ".join(loves[who])]))
			+ (" (stock it to bring more of them in)" if count == 1 else " (stock them to bring more in)"))
	if not Brand.WAR.is_empty() and lv == GangWar.LEVEL:
		lines.append("The gang war against %s starts!" % Brand.RIVAL.name)
	if lv <= TRAFFIC_LEVELS:
		lines.append("%d%% more shoppers come by" % roundi(Store.LEVEL_TRAFFIC * 100.0))
	return lines


# ---------------------------------------------------------------- staff

func staff_count(role: String) -> int:
	return staff.filter(func(s): return s.role == role).size()


## The most of `role` you can have right now. Cashiers are limited to one
## per register.
func staff_limit(role: String) -> int:
	var limit := staff_cap(role)
	if role == "cashier" and in_game():
		limit = mini(limit, store.registers.filter(func(r): return not r is SelfCheckout).size())
	return limit


## The most of `role` a store of your level can have (more stockers,
## cashiers and janitors at higher levels, STAFF_PERKS).
func staff_cap(role: String) -> int:
	var cap: int = STAFF[role].max
	for lv: int in STAFF_PERKS.get(role, []):
		if level >= lv:
			cap += 1
	return cap


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


## XP needed for each staff level: two more with Staff Training.
func staff_levels() -> Array:
	return STAFF_LEVEL_XP + TRAINING_LEVEL_XP if has_upgrade("training") else STAFF_LEVEL_XP


func staff_level_for(amount: float) -> int:
	var lv := 0
	for need in staff_levels():
		if amount >= need:
			lv += 1
	return maxi(lv, 1)


## How much faster than a new hire someone at `lv` works (1.0 = normal).
static func staff_speed(lv: int) -> float:
	return 1.0 + STAFF_SPEED_PER_LEVEL * (lv - 1)


## XP needed for their next level, or -1 at max level.
func staff_next_xp(lv: int) -> float:
	var levels := staff_levels()
	return float(levels[lv]) if lv < levels.size() else -1.0


## Staff member `id` did some work.
func add_staff_xp(id: int, amount: float) -> void:
	var entry := staff_entry(id)
	if entry.is_empty():
		return
	entry.xp += amount * (TRAINING_XP if has_upgrade("training") else 1.0)
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


## Everyone you pay at the end of the day: your staff and your gang.
func all_wages() -> float:
	return daily_wages() + war.wages()


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


## Someone (of `kind`, a Brand.SHOPPERS entry: a local in town, or a shopper
## from an older save) asked for `id`, which you don't sell yet (no license).
## Asked about twice in a day, you get a reminder
## to license it. stats.wanted counts the asks per product, and
## stats.wanted_by who asked ("witch": 2).
func record_wanted(id: String, kind := {}) -> void:
	var wanted: Dictionary = stats.get("wanted", {})
	wanted[id] = int(wanted.get(id, 0)) + 1
	stats.wanted = wanted
	var by: Dictionary = stats.get("wanted_by", {})
	var who: Dictionary = by.get(id, {})
	var name := (str(kind.name) if kind.has("name") else Brand.SAY.shopper).to_lower()
	who[name] = int(who.get(name, 0)) + 1
	by[id] = who
	stats.wanted_by = by
	if wanted[id] == 2:
		message.emit("%s keep asking for %s. License it at the computer (Products)!" % [top_askers(id).capitalize(), product_name(id)])


## Who asked for `id` today, the most first: "2 witches and 1 zombie".
func askers_text(id: String) -> String:
	var who: Dictionary = stats.get("wanted_by", {}).get(id, {})
	if who.is_empty():
		var n := int(stats.get("wanted", {}).get(id, 0))
		return "%d %s" % [n, Brand.SAY.shopper if n == 1 else Brand.SAY.shoppers] if n > 0 else ""
	var names := who.keys()
	names.sort_custom(func(a, b): return int(who[a]) > int(who[b]))
	var parts: Array[String] = []
	for n: String in names:
		var count := int(who[n])
		parts.append("%d %s" % [count, n if count == 1 else plural_of(n)])
	if parts.size() == 1:
		return parts[0]
	return ", ".join(parts.slice(0, -1)) + " and " + parts[-1]


## The kind that asked for `id` most, as a plural: "witches".
func top_askers(id: String) -> String:
	var who: Dictionary = stats.get("wanted_by", {}).get(id, {})
	var best := ""
	for n: String in who:
		if best == "" or int(who[n]) > int(who[best]):
			best = n
	return plural_of(best) if best != "" else Brand.SAY.shoppers


## "witch" -> "witches", "rich zombie" -> "rich zombies".
static func plural_of(singular: String) -> String:
	for k: Dictionary in Brand.SHOPPERS.values():
		if str(k.name).to_lower() == singular:
			return shopper_plural(k)
	return singular + "s"


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


# ---------------------------------------------------------------- loans

## The interest on borrowing `amount`: more, the more you borrow (5% on
## $250, 12% on $1,000, 25% on $10,000).
static func loan_rate(amount: float) -> float:
	var rate: float = LOAN_RATES[0]
	for i in LOAN_AMOUNTS.size():
		if amount + 0.001 >= float(LOAN_AMOUNTS[i]):
			rate = LOAN_RATES[i]
	return rate


## What you pay back for borrowing `amount`.
static func loan_total(amount: float) -> float:
	return snappedf(amount * (1.0 + loan_rate(amount)), 0.01)


## Each morning's payment on a loan of `total` (rounded up to the cent).
static func loan_payment(total: float) -> float:
	return ceilf(total / LOAN_DAYS * 100.0 - 0.001) / 100.0


## "$1,250" (or "$1,250.50" with cents).
static func cash(v: float) -> String:
	var cents := roundi(absf(v) * 100.0)
	var whole := str(cents / 100)
	var grouped := ""
	while whole.length() > 3:
		grouped = "," + whole.right(3) + grouped
		whole = whole.left(whole.length() - 3)
	var out := whole + grouped
	if cents % 100 != 0:
		out += ".%02d" % (cents % 100)
	return ("-" if v < 0.0 else "") + out


## The most you can borrow at your store level.
func loan_limit() -> float:
	return minf(LOAN_LIMIT_PER_LEVEL * level, float(LOAN_AMOUNTS[-1]))


## The store level you need to borrow `amount`.
static func loan_level(amount: float) -> int:
	return maxi(1, ceili(amount / LOAN_LIMIT_PER_LEVEL - 0.0001))


func has_loan() -> bool:
	return not loan.is_empty()


## What you still owe (0 with no loan).
func loan_left() -> float:
	return maxf(0.0, snappedf(float(loan.total) - float(loan.paid), 0.01)) if has_loan() else 0.0


## How much of the loan should be paid by the morning of day `d`: one
## payment for every morning since you borrowed it, and all of it on the last day.
func loan_due_by(d: int) -> float:
	if not has_loan():
		return 0.0
	if d >= int(loan.due):
		return float(loan.total)
	return minf(float(loan.total), float(loan.payment) * clampi(d - int(loan.day), 0, LOAN_DAYS))


## Payments you've missed (0 if you're up to date).
func loan_behind() -> float:
	return maxf(0.0, snappedf(loan_due_by(day) - float(loan.get("paid", 0.0)), 0.01))


## The last night came and the loan isn't paid off: the lender is here.
func loan_overdue() -> bool:
	return has_loan() and day >= int(loan.due) and day_over and loan_left() > 0.0


## Why you can't borrow `amount` right now ("" means you can).
func loan_problem(amount: float) -> String:
	if has_loan():
		return "Pay back what you owe first"
	if not amount in LOAN_AMOUNTS.map(func(a): return float(a)):
		return "Not an amount %s lends" % Brand.LOAN.lender
	if amount > loan_limit() + 0.001:
		return "Store level %d" % loan_level(amount)
	return ""


## Borrows `amount`. It's paid back over the next LOAN_DAYS mornings, and
## all of it is due by the night of the last one.
func take_loan(amount: float) -> bool:
	var problem := loan_problem(amount)
	if problem != "":
		message.emit(problem + ".")
		return false
	var total := loan_total(amount)
	loan = {"amount": amount, "total": total, "payment": loan_payment(total), "paid": 0.0, "day": day, "due": day + LOAN_DAYS}
	money += amount
	stats.borrowed = float(stats.get("borrowed", 0.0)) + amount
	message.emit(Brand.LOAN.taken % [cash(amount), cash(total), cash(loan.payment), LOAN_DAYS, loan.due])
	Settings.vibrate(0.4, 0.1)
	loan_changed.emit()
	return true


## Pays up to `amount` of the loan from your money (and never more than you
## owe or have). Returns how much was paid.
func pay_loan(amount: float, announce := true) -> float:
	if not has_loan():
		return 0.0
	var pay := snappedf(minf(amount, minf(loan_left(), maxf(0.0, money))), 0.01)
	if pay <= 0.0:
		return 0.0
	money -= pay
	loan.paid = snappedf(float(loan.paid) + pay, 0.01)
	stats.loan_paid = float(stats.get("loan_paid", 0.0)) + pay
	if loan_left() <= 0.0:
		loan = {}
		if announce:
			message.emit(Brand.LOAN.paid_off)
	loan_changed.emit()
	return pay


## Each morning: the day's payment is taken (plus any you missed), as much
## of it as you have. On the last day, a warning.
func _loan_morning() -> void:
	if not has_loan():
		return
	var due := loan_behind()
	if due > 0.0:
		var paid := pay_loan(due)
		if paid + 0.001 >= due:
			if has_loan():
				message.emit(Brand.LOAN.paid_morning % [cash(paid), cash(loan_left())])
		else:
			message.emit(Brand.LOAN.short_morning % [cash(paid), cash(due), int(loan.due)])
	if has_loan() and day >= int(loan.due):
		message.emit(Brand.LOAN.last_day % cash(loan_left()))


## The end of the day (after wages): on the loan's last night it's
## collected from your money. False if you can't pay it all.
func _loan_night() -> bool:
	if not has_loan() or day < int(loan.due):
		return true
	var left := loan_left()
	if money + 0.001 < left:
		return false
	pay_loan(left, false)
	message.emit(Brand.LOAN.paid_at_night % cash(left))
	return true


# ---------------------------------------------------------------- saving

## Everything in this script that goes into a save file.
func to_dict() -> Dictionary:
	return {
		"money": money, "xp": xp, "day": day, "minute": minute,
		"next_market_minute": next_market_minute, "is_open": is_open, "opened": opened,
		"between_days": day_over, "prices": prices, "licensed": licensed.keys(),
		"upgrades": upgrades.keys(), "auto_price": auto_price, "markup": price_markup,
		"unstocked": unstocked.keys(),
		"staff_rules": {"fill_empty": fill_empty_shelves, "labels_off": take_labels_off, "reorder_at": reorder_at},
		"floor_style": floor_style, "wall_color": wall_color, "stats": stats, "snake_best": snake_best,
		"play_time": play_time,
		"staff": staff, "next_staff_id": _next_staff_id, "expansions": expansions,
		"rival": {"factor": rival_factor, "deal": rival_deal, "seen": rival_seen, "spies": rival_spies},
		"war": war.to_dict(),
		"tutorial": tutorial.keys(), "tutorial_hidden": tutorial_hidden, "effects": effects, "loan": loan,
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
	price_markup = clampf(float(d.get("markup", 0.0)), MARKUP_MIN, MARKUP_MAX)
	for id: String in d.get("unstocked", []):
		if PRODUCTS.has(id):
			unstocked[id] = true
	var rules: Dictionary = d.get("staff_rules", {})
	fill_empty_shelves = bool(rules.get("fill_empty", true))
	take_labels_off = bool(rules.get("labels_off", true))
	reorder_at = clampi(int(rules.get("reorder_at", 0)), 0, REORDER_POINTS.size() - 1)
	floor_style = clampi(int(d.get("floor_style", 0)), 0, FLOOR_STYLES.size() - 1)
	snake_best = maxi(0, int(d.get("snake_best", 0)))
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
	var ln: Variant = d.get("loan", {})
	if ln is Dictionary and float(ln.get("total", 0.0)) > 0.0:
		loan = {"amount": float(ln.get("amount", 0.0)), "total": float(ln.total), "payment": float(ln.get("payment", loan_payment(float(ln.total)))),
			"paid": float(ln.get("paid", 0.0)), "day": int(ln.get("day", day)), "due": int(ln.get("due", day + LOAN_DAYS))}
	var r: Dictionary = d.get("rival", {})
	war.from_dict(d.get("war", {}), level)
	if bool(r.get("owned", false)):  # from when you could buy Bone Mart: Mr. Bones buys it back
		money += float(Brand.RIVAL.old_buyout)
		war.bought_back = true
		Saves.pending_notice = Brand.RIVAL.bought_back
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
	var wages := all_wages()
	if wages > 0.0:
		money -= wages  # wages are always paid, even if it puts you in the red
		stats.wages += wages
	var take := war.branch_income()
	if take > 0.0:  # what your branches made today
		money += take
		stats.branches += take
	if not _loan_night():
		loan_defaulted.emit()  # the lender comes for your head (no summary tonight)
		return
	var summary := stats.duplicate()
	summary.day = day
	summary.profit = stats.revenue + stats.branches + stats.looted - stats.spent - stats.invested - stats.wages - stats.robbed
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
	if loan_overdue():  # (saved during the lender's visit: he's still here)
		loan_defaulted.emit()
		return
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
	_loan_morning()
	update_market(true)
	war.morning()
	if not war.rival_closed and rival_deal != "":
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
	stats = {"revenue": 0.0, "spent": 0.0, "invested": 0.0, "wages": 0.0, "customers": 0, "items_sold": 0, "missed": 0, "walkouts": 0, "cleaned": 0, "lost": 0, "wanted": {}, "wanted_by": {}, "xp_lost": 0.0, "brews": 0,
		"spies_caught": 0, "spies_escaped": 0, "spy_reports": 0, "borrowed": 0.0, "loan_paid": 0.0,
		"branches": 0.0, "robbed": 0.0, "looted": 0.0, "raids_won": 0, "raids_lost": 0}
