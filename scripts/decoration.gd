class_name Decoration
extends Interactable
## Decorations like plants. You can't use them, but every one makes the
## store a bit more inviting, so customers come in more often (see
## Store.traffic_multiplier).


func _draw() -> void:
	draw_object_sprite(Game.FURNITURE[furniture_id].texture)


func get_pick_rect() -> Rect2:
	return Rect2(-14, -44, 28, 54)
