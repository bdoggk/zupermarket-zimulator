class_name Shelf
extends Interactable
## A shelf unit. Holds one product at a time; once empty it takes any
## product that isn't cold. Fridges (fridge.gd) are shelves for cold food.
##
## With the handheld scanner you can scan a shelf to order more of its
## product without walking to the computer.

const CAPACITY := 12
const STOCK_SECONDS_PER_ITEM := 0.15

## Where items are drawn: (x of the item's left edge, height of the board it
## sits on). Ordered so the eye-level shelf fills first.
const SLOTS := [
	Vector2i(-24, 15), Vector2i(4, 15), Vector2i(-14, 15), Vector2i(14, 15),
	Vector2i(-24, 2), Vector2i(4, 2), Vector2i(-14, 2), Vector2i(14, 2),
	Vector2i(-24, 28), Vector2i(4, 28), Vector2i(-14, 28), Vector2i(14, 28),
]

## What's on the shelf. Stays set when it runs empty, so the scanner still
## knows what to reorder.
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
	if stock > 0:
		var tex := Game.icon(product_id)
		for i in mini(stock, SLOTS.size()):
			var slot: Vector2i = SLOTS[i]
			var y := _floor_edge(slot.x + 4) - slot.y - tex.get_height()
			draw_texture(tex, Vector2(slot.x, y))
	_draw_front()


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
			return "This %s holds %s" % [kind_name(), Game.product_name(product_id)]
		if stock >= CAPACITY:
			return "%s is full" % kind_name().capitalize()
		return "Stock %s (%d/%d)" % [Game.product_name(id), stock, CAPACITY]
	if stock <= 0:
		return "Empty %s" % kind_name()
	return "%s: %d/%d" % [Game.product_name(product_id), stock, CAPACITY]


func can_interact(p: Player) -> bool:
	return p.is_carrying() and accepts(p.carry_product) and stock < CAPACITY


func get_action_time(p: Player) -> float:
	return mini(p.carry_count, CAPACITY - stock) * STOCK_SECONDS_PER_ITEM


func get_action_label(p: Player) -> String:
	return "Stocking %s..." % Game.product_name(p.carry_product)


func interact(p: Player) -> void:
	if not can_interact(p):
		return
	var n := add_stock(p.carry_product, p.carry_count)
	p.take_from_carry(n)
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


## True if this shelf can take `id` right now.
func accepts(id: String) -> bool:
	return Game.is_cold(id) == holds_cold() and (stock <= 0 or id == product_id)


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
