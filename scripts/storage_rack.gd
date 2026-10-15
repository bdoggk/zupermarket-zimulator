class_name StorageRack
extends Interactable
## Storage for spare boxes (buy one in Build mode). Holds up to CAPACITY
## boxes of anything. Use it while carrying a box to put the box away, or
## with empty hands to take the top box out.
##
## Stockers use racks too: boxes that have no shelf to go on get moved off
## the delivery zone into a rack, and come back out once a shelf has room.

const CAPACITY := 6
const ACTION_SECONDS := 0.35
const SMALL_BOX := preload("res://assets/sprites/box_small.png")
## Height of each board above the floor (matches tools/make_sprites.py).
const LEVELS := [3, 19, 35]


## One box sitting on the rack. (An object, so a stocker can claim it.)
class Box:
	extends RefCounted
	var product_id := ""
	var count := 0

	func _init(id := "", n := 0) -> void:
		product_id = id
		count = n


var boxes: Array[Box] = []  # bottom-left first


func _init() -> void:
	furniture_id = "storage"


## Where each box sits on its board (the floor center of the box, on the
## sprite's front face, before mirroring): back one first.
const SPOTS := [Vector2(-19, -2), Vector2(-7, 4)]


func _draw() -> void:
	draw_object_sprite(Game.FURNITURE[furniture_id].texture)
	for i in mini(boxes.size(), CAPACITY):
		var spot: Vector2 = SPOTS[i % 2]
		var foot := Vector2(mirror_x(spot.x), spot.y - LEVELS[i / 2])
		draw_texture(SMALL_BOX, foot - Vector2(10, 13))
		draw_texture(Game.icon(boxes[i].product_id), foot - Vector2(4, 11))


func has_room() -> bool:
	return boxes.size() < CAPACITY


## Puts a box on the rack. Returns false if it's full.
func store_box(product_id: String, count: int) -> bool:
	if not has_room() or count <= 0:
		return false
	boxes.append(Box.new(product_id, count))
	queue_redraw()
	return true


## Takes a particular box off the rack (stockers). False if it's gone.
func take(b: Box) -> bool:
	if not b in boxes:
		return false
	boxes.erase(b)
	if Game.in_game():
		Game.store.release(b)
	queue_redraw()
	return true


func count_of(product_id: String) -> int:
	var n := 0
	for b in boxes:
		if b.product_id == product_id:
			n += 1
	return n


func get_prompt(p: Player) -> String:
	if p.holding_mop:
		return "Put the mop back to carry boxes"
	if p.is_carrying():
		if not has_room():
			return "Storage rack is full (%d/%d)" % [boxes.size(), CAPACITY]
		return "Store %s x%d (%d/%d)" % [Game.product_name(p.carry_product), p.carry_count, boxes.size(), CAPACITY]
	if boxes.is_empty():
		return "Empty storage rack"
	var top: Box = boxes[-1]
	return "Take %s x%d (%d/%d)" % [Game.product_name(top.product_id), top.count, boxes.size(), CAPACITY]


func can_interact(p: Player) -> bool:
	if p.holding_mop:
		return false
	return has_room() if p.is_carrying() else not boxes.is_empty()


func get_action_time(_p: Player) -> float:
	return ACTION_SECONDS


func get_action_label(p: Player) -> String:
	return "Storing the box..." if p.is_carrying() else "Taking a box..."


func interact(p: Player) -> void:
	if not can_interact(p):
		return
	if p.is_carrying():
		store_box(p.carry_product, p.carry_count)
		p.drop_carry()
	else:
		var top: Box = boxes[-1]
		take(top)
		p.pick_up(top.product_id, top.count)
	Settings.vibrate(0.2, 0.04)


func get_pick_rect() -> Rect2:
	return Rect2(-28, -58, 56, 70)
