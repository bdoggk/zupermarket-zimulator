class_name Register
extends Interactable
## A checkout. Each register has its own line: a few marked spots (and,
## when those fill up, extra spots the store adds after them). Customers
## join the shortest line. The player, or a hired cashier, scans the front
## customer's items to get paid.
##
## The first register comes with the store. You can buy more in build mode;
## the extra ones can be sold again, the first one can only be moved.
##
## You can take a register over from its cashier: they go to another free
## register, or take a break. They come back once you step away from it or
## stop ringing people up for a few seconds, or right away if you press E
## on it with nobody to scan ("Hand the register back").

const TEXTURE := preload("res://assets/sprites/register.png")
const SCAN_SECONDS_PER_ITEM := 0.35
const TAKE_OVER_SECONDS := 0.3
const GIVE_BACK_AFTER := 4.0  # seconds you're away from a register you took over before the cashier comes back...
const IDLE_GIVE_BACK := 6.0  # ...or that you're not ringing anyone up at it, even standing right there

var line_cells: Array[Vector2i] = []  # the marked spots; [0] is the front
var facing := Vector2i(1, 0)  # which side of the register the line starts on
var extra_cells: Array[Vector2i] = []  # overflow spots after them (Store sets these)
var line: Array[Customer] = []
var cashier: Staff = null  # the cashier assigned to this register, if any
var taken_over := false  # you're running it instead of the cashier
var _away := 0.0
var _idle := 0.0


func _draw() -> void:
	draw_object_sprite(TEXTURE)


func _process(delta: float) -> void:
	super._process(delta)
	if not taken_over:
		return
	var p: Player = Game.player
	if p == null or Iso.chebyshev(p.current_cell(), cell) > 1:
		_away += delta
	else:
		_away = 0.0
	if player_is_scanning() or (not line.is_empty() and front_customer() == null):
		_idle = 0.0  # ringing someone up, or someone's on their way to you
	else:
		_idle += delta
	if _away > GIVE_BACK_AFTER or _idle > IDLE_GIVE_BACK:  # you walked off, or stopped ringing people up
		give_back()


## A cashier is assigned here and you haven't taken over.
func has_cashier() -> bool:
	return is_instance_valid(cashier) and not cashier.is_queued_for_deletion()


## You take over from the cashier (they find another register or take a break).
func take_over() -> void:
	taken_over = true
	_away = 0.0
	_idle = 0.0
	if has_cashier():
		var who := cashier
		cashier = null
		who.relieve(self)
		Game.show_popup(position + Vector2(0, -56), "I've got this, %s!" % who.staff_name, Color(0.8, 0.95, 1.0))


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
	return c.item_count() * SCAN_SECONDS_PER_ITEM / (Game.CONVEYOR_SPEED if Game.has_upgrade("conveyor") else 1.0)


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
	if has_cashier():
		return "Take over the register from %s" % cashier.staff_name
	var c := front_customer()
	if c:
		var n := c.item_count()
		return "Scan %d item%s ($%.2f)" % [n, "" if n == 1 else "s", c.checkout_total()]
	var back := waiting_cashier()
	if back:
		return "Hand the register back to %s" % back.staff_name
	if not line.is_empty():
		return "%s on the way..." % Brand.SAY.shopper.capitalize()
	return "Register (no %s)" % Brand.SAY.shoppers


## The cashiers can have it back: the one on a break from it comes straight
## back (any cashier without a register can take it).
func give_back() -> void:
	taken_over = false
	_away = 0.0
	_idle = 0.0
	if not Game.in_game():
		return
	for s in Game.store.staff:
		if s.on_break_from == self:
			s.timer = 0.0  # no waiting for their next look around


## The cashier who's on a break because you took over (null if none).
func waiting_cashier() -> Staff:
	if not taken_over or not Game.in_game():
		return null
	for s in Game.store.staff:
		if s.on_break_from == self and s.on_break():
			return s
	return null


func can_interact(_p: Player) -> bool:
	return has_cashier() or front_customer() != null or waiting_cashier() != null


## Ringing up a shopper is the job; taking over from a cashier is only
## what E does when nothing else is in reach (no more sending them off
## by accident while you reach for a box).
func use_priority(_p: Player) -> int:
	return 2 if not has_cashier() and front_customer() != null else 0


func get_action_time(_p: Player) -> float:
	if has_cashier():
		return TAKE_OVER_SECONDS
	var c := front_customer()
	return scan_time(c) if c else 0.0


func get_action_label(_p: Player) -> String:
	return "Taking over..." if has_cashier() else "Scanning items..."


func interact(_p: Player) -> void:
	if has_cashier():
		take_over()
		return
	if front_customer() == null:
		var back := waiting_cashier()
		if back:
			give_back()
			Game.show_popup(position + Vector2(0, -56), "All yours, %s!" % back.staff_name, Color(0.8, 0.95, 1.0))
		return
	Settings.vibrate(0.4, 0.06)
	checkout()


func get_pick_rect() -> Rect2:
	return Rect2(-30, -48, 60, 62)
