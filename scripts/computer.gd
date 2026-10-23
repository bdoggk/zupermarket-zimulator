class_name Computer
extends Interactable
## The back-office PC: order stock, set prices, buy product licenses and
## upgrades.

const TEXTURE := preload("res://assets/sprites/computer.png")


func _draw() -> void:
	draw_object_sprite(TEXTURE)


func is_movable() -> bool:
	return true


func ghost_texture() -> Texture2D:
	return TEXTURE


func display_name() -> String:
	return "computer"


func get_prompt(_p: Player) -> String:
	return "Use computer"


func can_interact(_p: Player) -> bool:
	return true


func interact(_p: Player) -> void:
	Game.computer_requested.emit()


func get_pick_rect() -> Rect2:
	return Rect2(-28, -50, 56, 64)


func fp_texture() -> Texture2D:
	return TEXTURE
