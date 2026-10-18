class_name Shelf
extends Interactable
## A shelf unit. Holds one product at a time. Fridges (fridge.gd) are
## shelves for cold food.
##
## The first product you put on a shelf gives it a label (the little sign on
## top). A labeled shelf only takes that product, even when it's empty, so
## you and your stockers know what goes where. With empty hands, use a shelf
## to take its items off (they go into a box you carry), and use the empty
## shelf again to peel the label off; then it takes anything.
##
## With the handheld scanner you can scan a shelf to order more of its
## product without walking to the computer.

const CAPACITY := 12
const STOCK_SECONDS_PER_ITEM := 0.15
const TAKE_SECONDS_PER_ITEM := 0.1
const LABEL_SECONDS := 0.35

## Where items are drawn on the shelf's open front (the left face of the
## sprite): (x of the item's left edge, height of the board it sits on).
## Ordered so the eye-level board fills first.
const SLOTS := [
	Vector2i(-20, 15), Vector2i(-8, 15), Vector2i(-26, 15), Vector2i(-14, 15),
	Vector2i(-20, 2), Vector2i(-8, 2), Vector2i(-26, 2), Vector2i(-14, 2),
	Vector2i(-20, 28), Vector2i(-8, 28), Vector2i(-26, 28), Vector2i(-14, 28),
]

## What the shelf is labeled for ("" = no label). Stays set when the shelf
## runs empty, so stockers know what to refill it with and the scanner knows
## what to reorder.
var product_id := ""
var stock := 0


func _init() -> void:
	furniture_id = "shelf"


## Fridges return true.
func holds_cold() -> bool:
	return false


func kind_name() -> String:
	return "shelf"


func _draw() -> void:
	draw_object_sprite(Game.FURNITURE[furniture_id].texture)
	if stock > 0 and shows_front():  # turned away, you only see its back
		var tex := Game.icon(product_id)
		var filled: Array = SLOTS.slice(0, mini(stock, SLOTS.size()))
		filled.sort_custom(func(a: Vector2i, b: Vector2i): return a.x < b.x)  # back to front
		for slot: Vector2i in filled:
			var x := mirror_x(slot.x, tex.get_width())
			var y := _floor_edge(int(x) + 4) - slot.y - tex.get_height()
			draw_texture(tex, Vector2(x, y))
	_draw_front()
	if is_labeled():
		_draw_label()


## The label: a little sign standing on top of the shelf with the product on
## it. When the shelf is turned away from you, a bar under it shows how full
## it is.
func _draw_label() -> void:
	var top := -float(Game.FURNITURE[furniture_id].texture.get_height() - 32)
	var card := Rect2(-7, top - 15, 14, 13)
	draw_rect(Rect2(-1, top - 3, 2, 4), Color(0.25, 0.24, 0.26))
	draw_rect(card, Color(0.94, 0.92, 0.84) if stock > 0 else Color(0.98, 0.86, 0.52))
	draw_rect(card, Color(0.16, 0.15, 0.17), false, 1.0)
	draw_texture(Game.icon(product_id), Vector2(-4, top - 14))
	if not shows_front():
		draw_rect(Rect2(-7, top - 2, 14, 3), Color(0.16, 0.15, 0.17))
		draw_rect(Rect2(-6, top - 1, 12.0 * stock / CAPACITY, 1), Color(0.55, 0.85, 0.45))


func is_labeled() -> bool:
	return product_id != ""


## Drawn on top of the items. Fridges draw their glass doors here.
func _draw_front() -> void:
	pass


## Bottom edge of the shelf's footprint at local column x (matches the
## diamond drawn in tools/make_sprites.py), so items follow the iso slant.
static func _floor_edge(x: int) -> int:
	if x >= 0:
		return 13 - floori(x / 2.0)
	return 14 - ceili(-x / 2.0)


func get_prompt(p: Player) -> String:
	if p.is_carrying():
		var id := p.carry_product
		if Game.is_cold(id) != holds_cold():
			return "Cold food goes in a fridge" if Game.is_cold(id) else "Fridges are for cold food"
		if not accepts(id):
			return "This %s is labeled for %s" % [kind_name(), Game.product_name(product_id)]
		if stock >= CAPACITY:
			return "%s is full" % kind_name().capitalize()
		return "Stock %s (%d/%d)" % [Game.product_name(id), stock, CAPACITY]
	if p.holding_mop:
		return "%s: %d/%d" % [Game.product_name(product_id), stock, CAPACITY] if is_labeled() else "Empty %s" % kind_name()
	if stock > 0:
		return "Take %s off the %s (%d/%d)" % [Game.product_name(product_id), kind_name(), stock, CAPACITY]
	if is_labeled():
		return "Remove the %s label (empty %s)" % [Game.product_name(product_id), kind_name()]
	return "Empty %s (no label)" % kind_name()


## Carrying a box: stock the shelf. Empty hands: take the items off, or
## remove the label from an empty shelf.
func can_interact(p: Player) -> bool:
	if p.is_carrying():
		return accepts(p.carry_product) and stock < CAPACITY
	return not p.holding_mop and (stock > 0 or is_labeled())


## Stocking it (with a box in hand) is what you came for; taking things off
## it loses to anything else you could do right there (like picking up a
## box), so you don't do it by accident.
func use_priority(p: Player) -> int:
	return 2 if p.is_carrying() else 0


func get_action_time(p: Player) -> float:
	if p.is_carrying():
		return mini(p.carry_count, CAPACITY - stock) * STOCK_SECONDS_PER_ITEM
	if stock > 0:
		return stock * TAKE_SECONDS_PER_ITEM
	return LABEL_SECONDS


func get_action_label(p: Player) -> String:
	if p.is_carrying():
		return "Stocking %s..." % Game.product_name(p.carry_product)
	if stock > 0:
		return "Taking %s off the %s..." % [Game.product_name(product_id), kind_name()]
	return "Peeling off the label..."


func interact(p: Player) -> void:
	if not can_interact(p):
		return
	if p.is_carrying():
		var n := add_stock(p.carry_product, p.carry_count)
		p.take_from_carry(n)
	elif stock > 0:
		var n := stock
		stock = 0
		p.pick_up(product_id, n)
		Game.show_popup(position + Vector2(0, -64), "-%d %s (into a box)" % [n, Game.product_name(product_id)], Color(1.0, 0.85, 0.6))
		Game.tutorial_step_done("labels")
		queue_redraw()
	else:
		Game.show_popup(position + Vector2(0, -64), "%s label removed" % Game.product_name(product_id), Color(1.0, 0.85, 0.6))
		product_id = ""
		Game.tutorial_step_done("labels")
		queue_redraw()
		if Game.in_game():
			Game.store.release(self)
	Settings.vibrate(0.25, 0.04)


## Puts up to `count` of a product on the shelf. Returns how many fit.
## Used by the player and by stockers.
func add_stock(id: String, count: int) -> int:
	if not accepts(id) or count <= 0:
		return 0
	if stock <= 0:
		product_id = id
	var n := mini(count, CAPACITY - stock)
	stock += n
	queue_redraw()
	Game.show_popup(position + Vector2(0, -60), "+%d %s" % [n, Game.product_name(id)], Color(0.75, 1.0, 0.75))
	return n


## True if this shelf can take `id`: the right temperature, and either it
## has no label yet or it's labeled for `id`.
func accepts(id: String) -> bool:
	return Game.is_cold(id) == holds_cold() and (product_id == "" or id == product_id)


## A customer takes one item. Returns false if the shelf is empty.
func take_one() -> bool:
	if stock <= 0:
		return false
	stock -= 1
	queue_redraw()
	return true


# ---------------------------------------------------------------- scanner

func get_scan_prompt(_p: Player) -> String:
	if not Game.has_upgrade("scanner") or product_id == "":
		return ""
	return "Scan: order %s ($%.2f)" % [Game.product_name(product_id), Game.box_cost(product_id)]


func can_scan(_p: Player) -> bool:
	return Game.has_upgrade("scanner") and product_id != "" and Game.is_licensed(product_id)


func scan(_p: Player) -> void:
	if Game.order_box(product_id):
		Settings.vibrate(0.3, 0.05)
		Game.show_popup(position + Vector2(0, -64), "Beep! +1 box of %s" % Game.product_name(product_id), Color(0.7, 0.9, 1.0))


func get_pick_rect() -> Rect2:
	var h: int = Game.FURNITURE[furniture_id].texture.get_height()
	return Rect2(-28, -(h - 18), 56, h - 4)
