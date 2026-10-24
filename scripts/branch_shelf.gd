class_name BranchShelf
extends RivalShelf
## A shelf in a branch store on the land east of Bone Mart (Turf): one of
## Bone Mart's (its prices, like any of its shelves) or one of yours (your
## branch runs itself, so it's just for show).

var ours := false


func _draw() -> void:
	draw_object_sprite(fp_texture())
	if stock <= 0 or product_id == "":
		return
	var tex := Game.icon(product_id)
	for i in mini(stock, Shelf.SLOTS.size()):
		var slot: Vector2i = Shelf.SLOTS[i]
		var y := Shelf._floor_edge(slot.x + 4) - slot.y - tex.get_height()
		draw_texture(tex, Vector2(slot.x, y))


func get_prompt(p: Player) -> String:
	if ours:
		return "%s: %s" % [Brand.WAR.your_branch, Game.product_name(product_id)] if product_id != "" else ""
	if product_id == "":
		return "Empty shelf"
	var text := "%s %s: $%.2f" % [Brand.WAR.bone_branch, Game.product_name(product_id), Game.rival_price(product_id)]
	if Game.is_licensed(product_id):
		text += " (yours: $%.2f)" % Game.prices[product_id]
	return text


func can_interact(p: Player) -> bool:
	return not ours and product_id != ""


func fp_texture() -> Texture2D:
	return Game.FURNITURE.shelf.texture if ours else TEXTURE
