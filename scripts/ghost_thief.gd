class_name GhostThief
extends Visitor
## A ghost shoplifter (0.19, Calendar event "ghost"): floats in, empties a
## few items off a couple of shelves into its sack, and floats back out with
## them. Catch it (walk up and use it, or click or tap it) and it drops the
## lot: back on the shelves they came from (or in a box on the floor) and a
## little reward for you. If it gets away, the stock's gone.

const SHELVES := 2  # shelves it robs...
const TAKE := 3  # ...taking up to this many items from each
const GRAB_SECONDS := 1.6

static var stolen := 0  # items ghosts have got away with, ever (for the tests' stock count)

var loot: Array[Dictionary] = []  # [{shelf, id, n}]
var shelves_left: Array = []
var caught := false


func _init() -> void:
	floats = true
	speed = 1.7


func loot_count() -> int:
	var n := 0
	for l in loot:
		n += int(l.n)
	return n


func can_be_caught() -> bool:
	return not caught and not _fading and (is_inside() or loot_count() > 0)


func get_prompt(_p: Player) -> String:
	return "Boo the ghost away" if can_be_caught() else ""


func can_interact(_p: Player) -> bool:
	return can_be_caught()


func use_priority(_p: Player) -> int:
	return 5  # before the shelf it's robbing


func interact(_p: Player) -> void:
	catch()


## Caught (by you): it drops what it took and flees.
func catch() -> void:
	if not can_be_caught():
		return
	caught = true
	var n := loot_count()
	for l: Dictionary in loot:
		var left := int(l.n)
		var s: Variant = l.shelf
		if is_instance_valid(s) and (s as Shelf).accepts(l.id):
			left -= (s as Shelf).add_stock(l.id, left)
		if left > 0:
			store.stash_box(current_cell(), l.id, left)
	loot.clear()
	var reward := roundf(15.0 + 5.0 * Game.level)
	Game.money += reward
	Game.count("ghosts_caught")
	Game.message.emit(Brand.GHOST_THIEF.caught % [_items(n), Game.cash(reward)])
	Game.show_popup(position + Vector2(0, -50), "Eeeek!", Color(0.85, 0.9, 1.0))
	Settings.vibrate(0.4, 0.12)
	store.events.play("ghost")
	speed = 4.0
	leave()


static func _items(n: int) -> String:
	return "%d item%s" % [n, "" if n == 1 else "s"]


func _came_in() -> void:
	var stocked := store.shelves.filter(func(s: Shelf): return s.stock > 0)
	stocked.shuffle()
	shelves_left = stocked.slice(0, SHELVES)


func _next() -> void:
	if leaving:
		return
	while not shelves_left.is_empty():
		var next: Variant = shelves_left.pop_front()
		if is_instance_valid(next) and (next as Shelf).stock > 0 and go_to_stop(next):
			return
	leave()


func _at_stop() -> float:
	return GRAB_SECONDS


## Done hovering at a shelf: into the sack it goes.
func _stop_done() -> void:
	if caught or not is_instance_valid(stop) or not (stop is Shelf):  # (sold in Build mode while it hovered there)
		return
	var s := stop as Shelf
	var n := 0
	var id := s.product_id
	while n < TAKE and s.take_one():
		n += 1
	if n > 0:
		loot.append({"shelf": s, "id": id, "n": n})
		Game.show_popup(position + Vector2(0, -50), "*yoink* %d %s" % [n, Game.product_name(id)], Color(0.8, 0.85, 1.0))


func _gone() -> void:
	var n := loot_count()
	if n > 0 and not caught:
		stolen += n
		Game.stats.lost_to_ghosts = int(Game.stats.get("lost_to_ghosts", 0)) + n
		Game.message.emit(Brand.GHOST_THIEF.escaped % _items(n))
	loot.clear()


func _draw() -> void:
	if can_be_caught() and is_inside():
		draw_string(ThemeDB.fallback_font, Vector2(-3, -44 + sprite.position.y), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.6, 0.8, 1.0))
