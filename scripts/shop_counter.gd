class_name ShopCounter
extends Interactable
## The counter in one of the little shops across the road (Brand.SHOPS):
## the witch's brewery and the vampire's curio shop. Use it to see what they
## sell (the HUD's shop panel); everything works for a little while
## (Game.buy_brew). It faces away from its keeper (rotation_step).

var shop := ""
var texture: Texture2D


func _draw() -> void:
	draw_object_sprite(texture)


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
	return Rect2(-30, -48, 60, 62)


func fp_texture() -> Texture2D:
	return texture
