class_name RivalDesk
extends Interactable
## The rival store's counter (its owner stands behind it) and its price
## board. Use either one to see all its prices and, once your store is big
## enough, to buy the place out.

var texture: Texture2D
var is_board := false


func _draw() -> void:
	draw_object_sprite(texture)


func get_prompt(_p: Player) -> String:
	if Game.rival_owned:
		return "%s is yours now" % Brand.RIVAL.name
	if is_board:
		return "Read the %s price list" % Brand.RIVAL.name
	return "Talk to %s" % Brand.RIVAL.owner


func can_interact(_p: Player) -> bool:
	return true


func interact(_p: Player) -> void:
	Game.rival_requested.emit()


func get_pick_rect() -> Rect2:
	return Rect2(-30, -50, 60, 62)


func fp_texture() -> Texture2D:
	return texture
