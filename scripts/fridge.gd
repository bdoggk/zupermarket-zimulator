class_name Fridge
extends Shelf
## A shelf for cold products (milk, frozen pizza, ice cream...). Buy one in
## build mode.

const GLASS := preload("res://assets/sprites/fridge_glass.png")


func _init() -> void:
	furniture_id = "fridge"


func holds_cold() -> bool:
	return true


func kind_name() -> String:
	return "fridge"


func _draw_front() -> void:
	draw_object_sprite(GLASS)
