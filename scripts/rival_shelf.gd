class_name RivalShelf
extends Interactable
## A shelf in the rival store down the street (Brand.RIVAL). Walk up to one
## to check what they charge for what's on it. Prices you've checked show
## up at your computer (Stock tab), so you know what to beat.

const TEXTURE := preload("res://assets/sprites/rival_shelf.png")

var product_id := ""
var stock := 0


func _draw() -> void:
	draw_object_sprite(TEXTURE)
	if stock <= 0 or product_id == "":
		return
	var tex := Game.icon(product_id)
	for i in mini(stock, Shelf.SLOTS.size()):
		var slot: Vector2i = Shelf.SLOTS[i]
		var y := Shelf._floor_edge(slot.x + 4) - slot.y - tex.get_height()
		draw_texture(tex, Vector2(slot.x, y))


func get_prompt(_p: Player) -> String:
	if Game.rival_owned or product_id == "":
		return "Empty shelf"
	var text := "%s %s: $%.2f" % [Brand.RIVAL.name, Game.product_name(product_id), Game.rival_price(product_id)]
	if Game.is_licensed(product_id):
		text += " (yours: $%.2f)" % Game.prices[product_id]
	else:
		text += " (you don't sell it yet)"
	return text


func can_interact(_p: Player) -> bool:
	return not Game.rival_owned and product_id != ""


func get_action_label(_p: Player) -> String:
	return "Checking the price..."


func get_action_time(_p: Player) -> float:
	return 0.3


func interact(_p: Player) -> void:
	if not can_interact(_p):
		return
	Game.scout_rival([product_id])
	var theirs := Game.rival_price(product_id)
	var color := Color(1.0, 0.6, 0.5)
	if Game.is_licensed(product_id) and Game.prices[product_id] <= theirs + 0.001:
		color = Color(0.6, 1.0, 0.6)  # you're already cheaper
	Game.show_popup(position + Vector2(0, -64), "%s $%.2f" % [Game.product_name(product_id), theirs], color)


func get_pick_rect() -> Rect2:
	return Rect2(-28, -58, 56, 70)
