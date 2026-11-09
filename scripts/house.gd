class_name House
extends Prop
## A house on the south side of town (0.20, Brand.HOUSES): Count Vlad's
## mansion, the witches' cottage, Ramses' tomb, the werewolves' den. A
## building over a few tiles, drawn from its front tile (this one), where
## you hand over special orders (SpecialOrders): walk up carrying a box of
## what they ordered and use the door.

var id := ""
var info := {}


func _init(house: Dictionary = {}) -> void:
	super._init([house.texture] if house.has("texture") else [], str(house.get("text", "")))
	info = house
	id = str(house.get("id", ""))
	origin = house.get("origin", Vector2(-1, -1))


func get_prompt(p: Player) -> String:
	var o := Game.orders.for_house(id)
	if o.is_empty():
		return prompt
	if Game.orders.can_deliver(id, p):
		return "Deliver %s to %s" % [SpecialOrders.amount(o), info.who]
	return "%s ordered %s: bring a box of them" % [str(info.who).left(1).to_upper() + str(info.who).substr(1), SpecialOrders.amount(o)]


func can_interact(p: Player) -> bool:
	return Game.orders.can_deliver(id, p)


func use_priority(_p: Player) -> int:
	return 3


func interact(p: Player) -> void:
	Game.orders.deliver(id, p)


func _draw() -> void:
	super._draw()
	if not Game.orders.for_house(id).is_empty():  # an order's waiting: a parcel over the door
		var bob := roundf(sin(Time.get_ticks_msec() / 300.0) * 2.0)
		var icon: Texture2D = Brand.ORDERS.icon
		draw_texture_rect(icon, Rect2(Vector2(-12, -70 + bob), icon.get_size() * 1.5), false)


func _process(delta: float) -> void:
	super._process(delta)
	if not Game.orders.for_house(id).is_empty():
		queue_redraw()
