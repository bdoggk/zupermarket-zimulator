class_name Register
extends Interactable
## A checkout. Each register has its own line: a few marked spots (and,
## when those fill up, extra spots the store adds after them). Customers
## join the shortest line. The player, or a hired cashier, scans the front
## customer's items to get paid.
##
## The first register comes with the store. You can buy more in build mode;
## the extra ones can be sold again, the first one can only be moved.

const TEXTURE := preload("res://assets/sprites/register.png")
const SCAN_SECONDS_PER_ITEM := 0.35

var line_cells: Array[Vector2i] = []  # the marked spots; [0] is the front
var facing := Vector2i(1, 0)  # which side of the register the line starts on
var extra_cells: Array[Vector2i] = []  # overflow spots after them (Store sets these)
var line: Array[Customer] = []
var cashier: Staff = null  # the cashier assigned to this register, if any


func _draw() -> void:
	draw_object_sprite(TEXTURE)


func is_movable() -> bool:
	return true


func ghost_texture() -> Texture2D:
	return TEXTURE


func display_name() -> String:
	return "register"


## Every place to stand in line, front first.
func spots() -> Array[Vector2i]:
	var all: Array[Vector2i] = []
	all.append_array(line_cells)
	all.append_array(extra_cells)
	return all


func spot(i: int) -> Vector2i:
	var all := spots()
	return all[mini(i, all.size() - 1)]


func has_room() -> bool:
	return line.size() < spots().size()


## Returns the customer's place in line, or -1 if the line is full.
func join_line(c: Customer) -> int:
	if line.has(c):
		return line.find(c)
	if not has_room():
		return -1
	line.append(c)
	return line.size() - 1


## The overflow spots changed (furniture was moved): customers past the
## end of the line step out and find another line.
func spots_changed() -> void:
	var n := spots().size()
	while line.size() > n:
		var c: Customer = line.pop_back()
		c.on_bumped_from_line()


## The register is being sold: everyone in line goes to find another one.
func release_all() -> void:
	var waiting := line.duplicate()
	line.clear()
	for c: Customer in waiting:
		c.on_bumped_from_line()


func leave_line(c: Customer) -> void:
	if not line.has(c):
		return
	line.erase(c)
	for i in line.size():
		if line[i].line_index != i:
			line[i].set_line_index(i)  # everyone shuffles forward


## The customer standing at the front, ready to pay (or null).
func front_customer() -> Customer:
	if not line.is_empty() and line[0].is_ready_for_checkout():
		return line[0]
	return null


## A cashier is standing at this register, working it.
func is_staffed() -> bool:
	return is_instance_valid(cashier) and cashier.is_at_post()


func player_is_scanning() -> bool:
	return Game.player != null and Game.player.action_target == self


## True while someone is checking out `c` (their patience doesn't run out).
func is_serving(c: Customer) -> bool:
	if line.is_empty() or line[0] != c:
		return false
	return player_is_scanning() or (is_instance_valid(cashier) and cashier.is_scanning())


func scan_time(c: Customer) -> float:
	return c.item_count() * SCAN_SECONDS_PER_ITEM


## Rings up the front customer. Used by both the player and cashiers.
func checkout() -> void:
	var c := front_customer()
	if c == null:
		return
	var total := c.checkout_total()
	Game.record_sale(total, c.item_count())
	Game.show_popup(position + Vector2(0, -50), "+$%.2f" % total, Color(0.6, 1.0, 0.6))
	c.on_checked_out()


func get_prompt(_p: Player) -> String:
	if is_staffed():
		return "%s is running this register" % cashier.staff_name
	var c := front_customer()
	if c:
		var n := c.item_count()
		return "Scan %d item%s ($%.2f)" % [n, "" if n == 1 else "s", c.checkout_total()]
	if not line.is_empty():
		return "%s on the way..." % Brand.SAY.shopper.capitalize()
	return "Register (no %s)" % Brand.SAY.shoppers


func can_interact(_p: Player) -> bool:
	return front_customer() != null and not is_staffed() and not (is_instance_valid(cashier) and cashier.is_scanning())


func get_action_time(_p: Player) -> float:
	var c := front_customer()
	return scan_time(c) if c else 0.0


func get_action_label(_p: Player) -> String:
	return "Scanning items..."


func interact(_p: Player) -> void:
	if front_customer() == null:
		return
	Settings.vibrate(0.4, 0.06)
	checkout()


func get_pick_rect() -> Rect2:
	return Rect2(-30, -48, 60, 62)
