class_name ShopCounter
extends Interactable
## A market stall's counter in town (Brand.SHOPS): the witch's brewery and
## the vampire's curio stall. Use it to see what they sell (the HUD's shop
## panel); everything works for a little while (Game.buy_brew).

var shop := ""
var texture: Texture2D


func _draw() -> void:
	draw_texture(texture, Vector2(-32, -(texture.get_height() - 16)))


func get_prompt(_p: Player) -> String:
	return "Shop at %s" % Brand.SHOPS[shop].name


func can_interact(_p: Player) -> bool:
	return true


func interact(_p: Player) -> void:
	Game.shop_requested.emit(shop)


func is_movable() -> bool:
	return false


func is_sellable() -> bool:
	return false


func get_pick_rect() -> Rect2:
	return Rect2(-30, -70, 60, 84)
