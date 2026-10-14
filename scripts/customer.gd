class_name Customer
extends Node2D
## A shopper. Walks in, visits shelves for each item on their list, lines up
## at the register with the shortest line, waits to be scanned, pays and
## leaves. If every line is full they browse around until there's room. If
## they wait too long they give up and walk out.
##
## In the zombie game (Brand.SPILLS) some of them drip blood on the floor
## as they shamble around.

enum State { ENTERING, SHOPPING, PICKING, WAIT_FOR_LINE, TO_LINE, IN_LINE, LEAVING, EXITING }

const SPEED := 2.2  # cells per second
const PICK_SECONDS := 0.9
const PATIENCE := 60.0  # seconds they'll wait for checkout
const BROWSE_RADIUS := 3  # how far they wander while waiting for room in line
const LEAKY_CHANCE := 0.35  # how many shoppers drip (when Brand.SPILLS is on)
const DRIP_MIN := 10.0  # seconds between drips
const DRIP_MAX := 22.0
const LOOKS := [
	preload("res://assets/sprites/customer_0.png"),
	preload("res://assets/sprites/customer_1.png"),
	preload("res://assets/sprites/customer_2.png"),
	preload("res://assets/sprites/customer_3.png"),
	preload("res://assets/sprites/customer_4.png"),
	preload("res://assets/sprites/customer_5.png"),
]

var store: Store
var state := State.ENTERING
var shopping_list: Array[Dictionary] = []  # [{id, qty}]
var basket: Array[Dictionary] = []  # [{id, price}]
var path: Array[Vector2i] = []
var target_shelf: Shelf = null
var register: Register = null  # the register whose line they're in
var line_index := -1
var leaky := false
var drip_timer := 0.0
var patience := PATIENCE
var timer := 0.0
var _wanted := ""  # product shown in the thought bubble
var _walk_anim := 0.0

@onready var sprite: Sprite2D = $Sprite


func setup(s: Store, door: Vector2i, list: Array[Dictionary]) -> void:
	store = s
	shopping_list = list
	position = Iso.cell_to_world(door)


func _ready() -> void:
	sprite.texture = LOOKS.pick_random()
	modulate.a = 0.0
	leaky = Brand.SPILLS and randf() < LEAKY_CHANCE
	drip_timer = randf_range(DRIP_MIN * 0.3, DRIP_MAX)


func _process(delta: float) -> void:
	match state:
		State.ENTERING:
			modulate.a = minf(1.0, modulate.a + delta * 2.5)
			if modulate.a >= 1.0:
				_next_item()
		State.SHOPPING, State.LEAVING:
			if _walk(delta):
				_on_arrived()
		State.TO_LINE:
			_tick_patience(delta)
			if state == State.TO_LINE and _walk(delta):
				state = State.IN_LINE
		State.IN_LINE:
			_tick_patience(delta)
		State.WAIT_FOR_LINE:
			_tick_patience(delta)
			if state != State.WAIT_FOR_LINE:
				pass
			elif not path.is_empty():
				_walk(delta)  # browsing
			else:
				timer -= delta
				if timer <= 0.0:
					_try_join_line()
		State.PICKING:
			timer -= delta
			if timer <= 0.0:
				_pick_from_shelf()
		State.EXITING:
			modulate.a -= delta * 2.5
			if modulate.a <= 0.0:
				store.customer_left(self)
				queue_free()
	if leaky and not path.is_empty():
		_drip(delta)
	_animate(delta)
	queue_redraw()


func _draw() -> void:
	if _wanted != "" and (state == State.SHOPPING or state == State.PICKING):
		# thought bubble with the product they're looking for
		draw_rect(Rect2(-8, -54, 16, 14), Color(0.95, 0.94, 0.9))
		draw_rect(Rect2(-8, -54, 16, 14), Color(0.15, 0.15, 0.18), false, 1.0)
		draw_rect(Rect2(-1, -40, 2, 2), Color(0.95, 0.94, 0.9))
		draw_texture(Game.icon(_wanted), Vector2(-4, -52))
	if state == State.TO_LINE or state == State.IN_LINE or state == State.WAIT_FOR_LINE:
		var f := clampf(patience / PATIENCE, 0.0, 1.0)
		draw_rect(Rect2(-9, -42, 18, 4), Color(0.08, 0.08, 0.1, 0.85))
		draw_rect(Rect2(-8, -41, 16 * f, 2), Color(1.0 - f, 0.4 + 0.5 * f, 0.25))


# ---------------------------------------------------------------- shopping

func _next_item() -> void:
	while not shopping_list.is_empty():
		var want: Dictionary = shopping_list[0]
		var shelf := _find_shelf(want.id)
		if shelf == null:
			_think(Brand.SAY.no_product % Game.product_name(want.id).to_lower())
			Game.record_missed()
			shopping_list.pop_front()
			continue
		var stand := store.stand_cell_for(shelf.cell, current_cell(), 1.5)
		if stand == Store.NO_CELL or not _go_to(stand):
			shopping_list.pop_front()
			continue
		target_shelf = shelf
		_wanted = want.id
		state = State.SHOPPING
		return
	_wanted = ""
	if basket.is_empty():
		_leave()
	else:
		_try_join_line()


func _find_shelf(id: String) -> Shelf:
	var best: Shelf = null
	var best_d := INF
	for s in store.shelves_with(id):
		var d := position.distance_to(s.position)
		if d < best_d:
			best_d = d
			best = s
	return best


func _pick_from_shelf() -> void:
	var want: Dictionary = shopping_list.pop_front()
	var shelf := target_shelf
	target_shelf = null
	if is_instance_valid(shelf) and shelf.product_id == want.id and shelf.stock > 0:
		if randf() <= Game.buy_chance(want.id):
			for _i in want.qty:
				if shelf.take_one():
					basket.append({"id": want.id, "price": Game.prices[want.id]})
		else:
			_think(Brand.SAY.too_pricey)
			Game.record_missed()
	elif _find_shelf(want.id):
		shopping_list.push_front(want)  # someone beat us to it, try another shelf
	else:
		_think(Brand.SAY.sold_out)
		Game.record_missed()
	_next_item()


# ---------------------------------------------------------------- checkout

func _try_join_line() -> void:
	var r := _pick_register()
	if r == null:
		# Every line's full: look around the shelves for a bit, then try again.
		state = State.WAIT_FOR_LINE
		timer = randf_range(0.5, 1.5)
		_browse()
		return
	register = r
	set_line_index(r.join_line(self))


## The register with the shortest line (nearest one wins a tie). A register
## with a cashier at it is worth a slightly longer wait.
func _pick_register() -> Register:
	var best: Register = null
	var best_score := INF
	for r in store.registers:
		if not r.has_room():
			continue
		var score := r.line.size() + position.distance_to(r.position) / 2000.0
		if r.is_staffed():
			score -= 1.5
		if score < best_score:
			best_score = score
			best = r
	return best


func set_line_index(i: int) -> void:
	line_index = i
	_go_to(register.spot(i))
	state = State.TO_LINE


## Their line got shorter (furniture moved onto the end of it) or their
## register was sold: find another line.
func on_bumped_from_line() -> void:
	register = null
	line_index = -1
	state = State.WAIT_FOR_LINE
	timer = 0.5
	_browse()


## Wanders to a random nearby spot that isn't part of the line.
func _browse() -> void:
	var here := current_cell()
	var options: Array[Vector2i] = []
	for dx in range(-BROWSE_RADIUS, BROWSE_RADIUS + 1):
		for dy in range(-BROWSE_RADIUS, BROWSE_RADIUS + 1):
			var c := here + Vector2i(dx, dy)
			if c == here or not store.reachable.has(c) or not store.is_walkable(c):
				continue
			if store.is_line_spot(c) or c == store.door_cell or c in store.delivery_cells:
				continue
			options.append(c)
	if not options.is_empty():
		_go_to(options.pick_random())


func is_ready_for_checkout() -> bool:
	return state == State.IN_LINE and line_index == 0


func item_count() -> int:
	return basket.size()


func checkout_total() -> float:
	var total := 0.0
	for item in basket:
		total += item.price
	return total


func on_checked_out() -> void:
	if is_instance_valid(register):
		register.leave_line(self)
	basket.clear()
	_leave()


func _tick_patience(delta: float) -> void:
	if is_instance_valid(register) and register.is_serving(self):
		return
	patience -= delta
	if patience <= 0.0:
		_think(Brand.SAY.walkout)
		Settings.vibrate(0.5, 0.15)
		Game.record_walkout()
		if is_instance_valid(register):
			register.leave_line(self)
		basket.clear()
		_leave()


func _leave() -> void:
	register = null
	line_index = -1
	_wanted = ""
	if _go_to(store.door_cell):
		state = State.LEAVING
	else:
		state = State.EXITING


# ---------------------------------------------------------------- movement

func current_cell() -> Vector2i:
	return Iso.world_to_cell(position)


## The cell they're walking into next.
func next_cell() -> Vector2i:
	return path[0] if not path.is_empty() else current_cell()


## Shelves were added, moved or sold in build mode: find new routes.
func on_layout_changed() -> void:
	match state:
		State.SHOPPING:
			target_shelf = null
			_next_item()
		State.PICKING:
			if not is_instance_valid(target_shelf) or Iso.chebyshev(current_cell(), target_shelf.cell) > 1:
				target_shelf = null
				_next_item()
		State.TO_LINE:
			if is_instance_valid(register):
				_go_to(register.spot(line_index))
		State.IN_LINE:
			if is_instance_valid(register) and current_cell() != register.spot(line_index):
				set_line_index(line_index)  # their spot moved
		State.WAIT_FOR_LINE:
			path.clear()
		State.LEAVING:
			if not _go_to(store.door_cell):
				state = State.EXITING


func _go_to(cell: Vector2i) -> bool:
	var p := store.find_path(current_cell(), cell)
	if p.is_empty():
		return false
	if position.distance_to(Iso.cell_to_world(p[0])) < 2.0:
		p.remove_at(0)
	path = p
	return true


## Moves along the path. Returns true once the destination is reached.
func _walk(delta: float) -> bool:
	if path.is_empty():
		return true
	var to_target := Iso.cell_to_world(path[0]) - position
	var step := Iso.velocity_toward(to_target, SPEED) * delta
	if step.length() >= to_target.length():
		position = Iso.cell_to_world(path[0])
		path.remove_at(0)
	else:
		position += step
	if absf(step.x) > 0.01:
		sprite.flip_h = step.x < 0.0
	return path.is_empty()


func _on_arrived() -> void:
	match state:
		State.SHOPPING:
			state = State.PICKING
			timer = PICK_SECONDS
			if is_instance_valid(target_shelf):
				sprite.flip_h = target_shelf.position.x < position.x
		State.LEAVING:
			state = State.EXITING


func _animate(delta: float) -> void:
	if not path.is_empty() and state in [State.SHOPPING, State.TO_LINE, State.LEAVING]:
		_walk_anim += delta * 14.0
		sprite.position.y = -roundf(absf(sin(_walk_anim)) * 1.5)
	else:
		sprite.position.y = 0.0


## Leaves a blood spill now and then (zombie game).
func _drip(delta: float) -> void:
	drip_timer -= delta
	if drip_timer > 0.0:
		return
	drip_timer = randf_range(DRIP_MIN, DRIP_MAX)
	store.add_spill(current_cell())


func _think(text: String) -> void:
	Game.show_popup(position + Vector2(0, -44), text, Color(1.0, 0.88, 0.62))
