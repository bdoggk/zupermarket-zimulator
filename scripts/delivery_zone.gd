class_name DeliveryZone
extends Interactable
## The striped area where deliveries get dropped off. Nothing stands on it,
## so it isn't really furniture, but you can pick it up and move it in build
## mode (boxes waiting on it come along). The stripes are floor tiles drawn
## by the store; `cell` is the zone's top corner.


func is_movable() -> bool:
	return true


func is_sellable() -> bool:
	return false


func display_name() -> String:
	return "delivery zone"


func ghost_texture() -> Texture2D:
	return null  # build mode draws the zone's tiles under the cursor instead


func get_pick_rect() -> Rect2:
	return Rect2()  # picked by tapping one of its cells (see BuildMode.movable_at)
