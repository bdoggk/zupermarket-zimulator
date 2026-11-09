class_name SpecialOrders
extends RefCounted
## Special orders (0.20): each morning from store level FROM_LEVEL, the
## notice board in the town square (NoticeBoard) has a few orders from the
## houses on the south side of town (Brand.HOUSES): "Count Vlad wants 6
## Blood Bottles". Take up to TAKE_MAX, carry a box of the product (from a
## delivery, or off a shelf) to the house before DUE and deliver it at the
## door (House) for about twice what the store would get, and XP. Orders
## not delivered by DUE go to waste. Game.orders is the one in play.

signal changed

const FROM_LEVEL := 4
const POSTED := 3  # orders on the board each morning
const TAKE_MAX := 2  # taken at once
const DUE := 18 * 60  # 6 PM
const MARKUP := 2.2  # paid this many times the market price...
const BONUS := 20.0  # ...plus this...
const BONUS_PER_LEVEL := 5.0  # ...and this a store level
const QTY := [3, 8]  # how many (never more than a box holds)

static var items_out := 0  # items that left the store in orders, ever (for the tests' stock count)

var day := 0
## Today's orders: [{house (Brand.HOUSES id), product, qty, pay, xp, line,
## taken, done, late}].
var list: Array[Dictionary] = []
var delivered := 0  # orders delivered, ever


## The house `id` ("vlad"...) in Brand.HOUSES, or {}.
static func house(id: String) -> Dictionary:
	for h: Dictionary in Brand.HOUSES.values():
		if h.id == id:
			return h
	return {}


## "6 Blood Bottles".
static func amount(o: Dictionary) -> String:
	return "%d %s" % [int(o.qty), product_plural(o)]


## The product's name, plural unless there's just one ("Blood Bottles").
static func product_plural(o: Dictionary) -> String:
	var name := Game.product_name(o.product)
	return name if int(o.qty) == 1 or name.ends_with("s") else name + "s"


## Posts this morning's orders (once a day).
func roll() -> void:
	if day == Game.day:
		return
	day = Game.day
	list.clear()
	if Game.level >= FROM_LEVEL and Game.in_game():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([Game.day, "orders", Game.calendar.seed])
		var houses: Array = Brand.HOUSES.values()
		for i in range(houses.size() - 1, 0, -1):  # (shuffled with this morning's rng: the same game gets the same orders)
			var j := rng.randi() % (i + 1)
			var t: Variant = houses[i]
			houses[i] = houses[j]
			houses[j] = t
		var ids := Game.unlocked_ids()
		var used := {}  # (three different things, if you sell that many)
		for h: Dictionary in houses.slice(0, POSTED):
			var kind: Dictionary = Brand.SHOPPERS.get(h.kind, {})
			var fresh := ids.filter(func(p): return not used.has(p))
			if fresh.is_empty():
				fresh = ids
			var liked: Array = (kind.get("likes", []) as Array).filter(func(p): return p in fresh)
			var product: String = liked[rng.randi() % liked.size()] if not liked.is_empty() and rng.randf() < 0.6 else fresh[rng.randi() % fresh.size()]
			used[product] = true
			var box := int(Game.PRODUCTS[product].box_size)
			var qty := mini(box, rng.randi_range(QTY[0], QTY[1] + floori(Game.level / 4.0)))
			var lines: Array = Brand.ORDERS.lines.get(h.id, [""])
			list.append({
				"house": h.id, "product": product, "qty": qty,
				"pay": roundf(qty * Game.market_price(product) * MARKUP + BONUS + BONUS_PER_LEVEL * Game.level),
				"xp": 15.0 + qty * 3.0, "line": lines[rng.randi() % lines.size()],
				"taken": false, "done": false, "late": false,
			})
	changed.emit()


## Orders you've taken that are still to deliver.
func open_orders() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o in list:
		if o.taken and not o.done and not o.late:
			out.append(o)
	return out


func can_take(o: Dictionary) -> bool:
	return not o.taken and open_orders().size() < TAKE_MAX and Game.minute < DUE


func take(o: Dictionary) -> bool:
	if not can_take(o):
		return false
	o.taken = true
	var h := house(o.house)
	Game.message.emit(Brand.ORDERS.taken % [int(o.qty), product_plural(o), h.who, Game.clock_text_at(DUE), h.place])
	changed.emit()
	return true


## The order you've taken for house `id` (or {}).
func for_house(id: String) -> Dictionary:
	for o in open_orders():
		if o.house == id:
			return o
	return {}


## You can hand house `id` its order right now (carrying enough of it).
func can_deliver(id: String, p: Player) -> bool:
	var o := for_house(id)
	return not o.is_empty() and p.carry_product == o.product and p.carry_count >= int(o.qty)


## Hands house `id` its order from the box you're carrying.
func deliver(id: String, p: Player) -> bool:
	if not can_deliver(id, p):
		return false
	var o := for_house(id)
	p.take_from_carry(int(o.qty))
	items_out += int(o.qty)
	o.done = true
	delivered += 1
	Game.money += float(o.pay)
	Game.stats.orders_paid = float(Game.stats.get("orders_paid", 0.0)) + float(o.pay)
	Game.add_xp(float(o.xp))
	Game.count("orders")
	Game.message.emit(Brand.ORDERS.done % [int(o.qty), product_plural(o), house(o.house).who, Game.cash(float(o.pay)), int(o.xp)])
	changed.emit()
	return true


## Game calls this now and then: orders not delivered by DUE are off.
func tick() -> void:
	if Game.minute < DUE:
		return
	for o in list:
		if o.taken and not o.done and not o.late:
			o.late = true
			Game.message.emit(Brand.ORDERS.late % [_first_up(str(house(o.house).who)), product_plural(o)])
			changed.emit()



func to_dict() -> Dictionary:
	return {"day": day, "list": list, "delivered": delivered}


func from_dict(d: Dictionary) -> void:
	day = int(d.get("day", 0))
	delivered = int(d.get("delivered", 0))
	list.clear()
	var l: Variant = d.get("list", [])
	if l is Array:
		for o: Variant in l:
			if o is Dictionary and Game.PRODUCTS.has(str(o.get("product", ""))) and not house(str(o.get("house", ""))).is_empty():
				list.append({
					"house": str(o.house), "product": str(o.product), "qty": int(o.get("qty", 1)),
					"pay": float(o.get("pay", 0.0)), "xp": float(o.get("xp", 0.0)), "line": str(o.get("line", "")),
					"taken": bool(o.get("taken", false)), "done": bool(o.get("done", false)), "late": bool(o.get("late", false)),
				})


static func _first_up(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)
