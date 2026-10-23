class_name StockBox
extends Interactable
## A cardboard box of one product, waiting to be carried to a shelf.

const TEXTURE := preload("res://assets/sprites/box.png")
const PICKUP_SECONDS := 0.3

var product_id := ""
var count := 0


func _draw() -> void:
	draw_object_sprite(TEXTURE)
	draw_texture(Game.icon(product_id), Vector2(-4, -24))


func get_prompt(p: Player) -> String:
	if p.is_carrying():
		return ""
	if p.holding_mop:
		return "Put the mop back to carry boxes"
	return "Pick up box: %s x%d" % [Game.product_name(product_id), count]


func can_interact(p: Player) -> bool:
	return not p.is_carrying() and not p.holding_mop


## Picking up a box beats most things around it (like taking over a
## cashier's register).
func use_priority(_p: Player) -> int:
	return 2


func get_action_time(_p: Player) -> float:
	return PICKUP_SECONDS


func get_action_label(_p: Player) -> String:
	return "Picking up box..."


func interact(p: Player) -> void:
	if p.is_carrying():
		return
	p.pick_up(product_id, count)
	Game.store.remove_box(self)


func get_pick_rect() -> Rect2:
	return Rect2(-16, -26, 32, 34)


func fp_texture() -> Texture2D:
	return TEXTURE


## First person: the box with its product's picture on it.
func look_3d() -> Array:
	var layers := super.look_3d()
	layers.append([Game.icon(product_id), Vector2(-4, -24), false])
	return layers
