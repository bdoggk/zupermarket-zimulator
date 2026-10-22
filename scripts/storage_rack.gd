class_name StorageRack
extends Interactable
## Storage for spare boxes (buy one in Build mode). Holds up to CAPACITY
## boxes of anything. Use it while carrying a box to put the box away, or
## with empty hands to take one out: with more than one product on it, a
## list comes up to pick which (the HUD's RackPanel), and you get the
## fullest box of that product.
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


## The products on the rack, in the order their first box went on.
func products() -> Array[String]:
	var out: Array[String] = []
	for b in boxes:
		if not b.product_id in out:
			out.append(b.product_id)
	return out


## The fullest box of `product_id` on the rack (null if there's none).
func fullest(product_id: String) -> Box:
	var best: Box = null
	for b in boxes:
		if b.product_id == product_id and (best == null or b.count > best.count):
			best = b
	return best


## Takes the fullest box of `product_id` off the rack into your hands.
func take_product(p: Player, product_id: String) -> bool:
	if p.is_carrying() or p.holding_mop:
		return false
	var b := fullest(product_id)
	if b == null or not take(b):
		return false
	p.pick_up(b.product_id, b.count)
	Settings.vibrate(0.2, 0.04)
	return true


## Picking from a list (more than one product on the rack).
func asks_which(p: Player) -> bool:
	return not p.is_carrying() and products().size() > 1


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
	var kinds := products()
	if kinds.size() > 1:
		return "Take a box: pick from %d products (%d/%d)" % [kinds.size(), boxes.size(), CAPACITY]
	var b := fullest(kinds[0])
	return "Take %s x%d (%d/%d)" % [Game.product_name(b.product_id), b.count, boxes.size(), CAPACITY]


func can_interact(p: Player) -> bool:
	if p.holding_mop:
		return false
	return has_room() if p.is_carrying() else not boxes.is_empty()


func get_action_time(p: Player) -> float:
	return 0.0 if asks_which(p) else ACTION_SECONDS  # (the list comes up straight away)


func get_action_label(p: Player) -> String:
	return "Storing the box..." if p.is_carrying() else "Taking a box..."


func interact(p: Player) -> void:
	if not can_interact(p):
		return
	if p.is_carrying():
		store_box(p.carry_product, p.carry_count)
		p.drop_carry()
		Settings.vibrate(0.2, 0.04)
	elif asks_which(p):
		Game.rack_requested.emit(self)
	else:
		take_product(p, products()[0])


func get_pick_rect() -> Rect2:
	return Rect2(-28, -58, 56, 70)
