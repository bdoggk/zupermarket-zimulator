class_name Staff
extends Node2D
## Someone you hired at the computer (Staff tab). They get paid at the end
## of every day.
##
##   Stocker  picks up delivery boxes and stocks the shelves with them. Tops
##            up shelves that already hold that product first, then fills
##            empty ones. Puts a box down if there's nowhere for it to go.
##   Cashier  walks to a register (one each) and checks out the customers
##            in its line. While a cashier is at a register, you can't use
##            it yourself, so you're free to do other things.

enum Job { IDLE, TO_BOX, PICKING_UP, TO_SHELF, STOCKING, TO_DROP, TO_POST, AT_POST, SCANNING, NO_POST }

const SPEED := 2.8  # cells per second
const PICKUP_SECONDS := 0.4
const STOCK_SECONDS_PER_ITEM := 0.2  # a little slower than you
const SCAN_SLOWDOWN := 1.15  # cashiers scan a little slower than you
const LOOK_FOR_WORK := 0.6  # seconds between looking for something to do
const BOX_SMALL := preload("res://assets/sprites/box_small.png")

var id := 0
var role := ""
var staff_name := ""
var store: Store
var job := Job.IDLE
var path: Array[Vector2i] = []
var timer := 0.0
var duration := 0.0  # length of the current timed task (for the progress bar)

# Stocker
var carry_product := ""
var carry_count := 0
var target_box: StockBox = null
var target_shelf: Shelf = null

# Cashier
var register: Register = null
var post := Store.NO_CELL  # where they stand to work the register

var sprite: Sprite2D
var _walk_anim := 0.0


func setup(s: Store, entry: Dictionary, cell: Vector2i) -> void:
	store = s
	id = entry.id
	role = entry.role
	staff_name = entry.name
	position = Iso.cell_to_world(cell)


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = Game.STAFF[role].texture
	sprite.centered = false
	sprite.offset = Vector2(-8, -34)
	add_child(sprite)


func _process(delta: float) -> void:
	if role == "stocker":
		_stocker(delta)
	else:
		_cashier(delta)
	_animate(delta)
	queue_redraw()


func _draw() -> void:
	if carry_count > 0:
		draw_texture(BOX_SMALL, Vector2(-10, -24 + sprite.position.y))
		draw_texture(Game.icon(carry_product), Vector2(-4, -56))
	if job in [Job.PICKING_UP, Job.STOCKING, Job.SCANNING] and duration > 0.0:
		var f := clampf(1.0 - timer / duration, 0.0, 1.0)
		draw_rect(Rect2(-11, -44, 22, 5), Color(0.08, 0.08, 0.1, 0.9))
		draw_rect(Rect2(-10, -43, 20 * f, 3), Color(0.45, 0.75, 0.95))
	if job == Job.NO_POST:
		draw_string(ThemeDB.fallback_font, Vector2(-3, -40), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.85, 0.3))


## What they're up to, for the Staff tab.
func status_text() -> String:
	match job:
		Job.TO_BOX, Job.PICKING_UP:
			return "Fetching a box"
		Job.TO_SHELF, Job.STOCKING:
			return "Stocking %s" % Game.product_name(carry_product)
		Job.TO_DROP:
			return "No room for %s, putting the box down" % Game.product_name(carry_product)
		Job.TO_POST:
			return "Walking to register %d" % (store.registers.find(register) + 1)
		Job.AT_POST:
			return "Running register %d" % (store.registers.find(register) + 1)
		Job.SCANNING:
			return "Checking out a %s" % Brand.SAY.shopper
		Job.NO_POST:
			return "Can't get to a free register" if store.registers.size() > 0 else "No register"
	if role == "stocker":
		return "Waiting for deliveries"
	return "Idle"


func is_at_post() -> bool:
	return job == Job.AT_POST or job == Job.SCANNING


func is_scanning() -> bool:
	return job == Job.SCANNING


func current_cell() -> Vector2i:
	return Iso.world_to_cell(position)


## The cell they're walking into next.
func next_cell() -> Vector2i:
	return path[0] if not path.is_empty() else current_cell()


# ---------------------------------------------------------------- stocker

func _stocker(delta: float) -> void:
	match job:
		Job.IDLE:
			if not path.is_empty():
				_walk(delta)  # wandering back to the stockroom
			timer -= delta
			if timer > 0.0:
				return
			timer = LOOK_FOR_WORK
			if carry_count > 0:
				_deliver()
			else:
				_find_box()
			if job == Job.IDLE and path.is_empty():
				_go_home()
		Job.TO_BOX:
			if not _box_ok():
				_give_up()
			elif _walk(delta):
				if Iso.chebyshev(current_cell(), target_box.cell) <= 1:
					_start(Job.PICKING_UP, PICKUP_SECONDS)
				else:
					_give_up()
		Job.PICKING_UP:
			if not _box_ok():
				_give_up()
				return
			timer -= delta
			if timer <= 0.0:
				carry_product = target_box.product_id
				carry_count = target_box.count
				store.release(target_box)
				store.remove_box(target_box)
				target_box = null
				_go_to_shelf()
		Job.TO_SHELF:
			if not _shelf_ok():
				_give_up()
			elif _walk(delta):
				if Iso.chebyshev(current_cell(), target_shelf.cell) <= 1:
					var n := mini(carry_count, Shelf.CAPACITY - target_shelf.stock)
					_start(Job.STOCKING, n * STOCK_SECONDS_PER_ITEM)
					_face(target_shelf.position)
				else:
					_give_up()
		Job.STOCKING:
			if not _shelf_ok():
				_give_up()
				return
			timer -= delta
			if timer <= 0.0:
				carry_count -= target_shelf.add_stock(carry_product, carry_count)
				if carry_count <= 0:
					carry_count = 0
					carry_product = ""
				store.release(target_shelf)
				target_shelf = null
				job = Job.IDLE
				timer = 0.1
		Job.TO_DROP:
			if _walk(delta):
				if store.drop_box(current_cell(), carry_product, carry_count):
					carry_product = ""
					carry_count = 0
				job = Job.IDLE
				timer = 2.0


## Looks for a box that has somewhere to go.
func _find_box() -> void:
	var best: StockBox = null
	var best_shelf: Shelf = null
	var best_d := INF
	for box: StockBox in store.boxes.values():
		if store.is_claimed(box, self):
			continue
		var shelf := store.best_shelf_for(box.product_id, box.position, self)
		if shelf == null:
			continue
		var d := position.distance_to(box.position)
		if d < best_d:
			best_d = d
			best = box
			best_shelf = shelf
	if best == null or not _go_to(best.cell):
		return
	target_box = best
	target_shelf = best_shelf
	store.claim(best, self)
	store.claim(best_shelf, self)
	job = Job.TO_BOX


## Has a box in hand: take it to a shelf, or put it down if there's no room.
func _deliver() -> void:
	target_shelf = store.best_shelf_for(carry_product, position, self)
	if target_shelf:
		store.claim(target_shelf, self)
		_go_to_shelf()
		return
	var c := store.nearest_drop_cell(current_cell())
	if c != Store.NO_CELL and _go_to(c):
		job = Job.TO_DROP


func _go_to_shelf() -> void:
	if not _shelf_ok():
		target_shelf = store.best_shelf_for(carry_product, position, self)
		if target_shelf:
			store.claim(target_shelf, self)
	if target_shelf:
		var stand := store.stand_cell_for(target_shelf.cell, current_cell())
		if stand != Store.NO_CELL and _go_to(stand):
			job = Job.TO_SHELF
			return
	_give_up()


func _box_ok() -> bool:
	return is_instance_valid(target_box) and not target_box.is_queued_for_deletion() \
		and store.boxes.get(target_box.cell) == target_box


func _shelf_ok() -> bool:
	return is_instance_valid(target_shelf) and not target_shelf.is_queued_for_deletion() \
		and target_shelf.accepts(carry_product) and target_shelf.stock < Shelf.CAPACITY


## Drops the current plan (someone took the box, the shelf filled up or was
## moved...) and looks for something else to do.
func _give_up() -> void:
	store.release_all(self)
	target_box = null
	target_shelf = null
	path.clear()
	job = Job.IDLE
	timer = 0.3


## Wanders back near the delivery zone when there's nothing to do.
func _go_home() -> void:
	if store.delivery_cells.is_empty() or Iso.chebyshev(current_cell(), store.delivery_cells[0]) <= 3:
		return
	var home := store.stand_cell_for(store.delivery_cells[-1], current_cell(), 2.0)
	if home != Store.NO_CELL:
		_go_to(home)


# ---------------------------------------------------------------- cashier

func _cashier(delta: float) -> void:
	if not is_instance_valid(register) or not register in store.registers:
		register = store.assign_register(self)
		if register == null:
			job = Job.NO_POST
			if not path.is_empty():
				_walk(delta)
			return
		_go_to_post()
	match job:
		Job.TO_POST:
			if _walk(delta):
				job = Job.AT_POST if current_cell() == post else Job.NO_POST
		Job.AT_POST:
			_face(register.position)
			var c := register.front_customer()
			if c and not register.player_is_scanning():
				_start(Job.SCANNING, register.scan_time(c) * SCAN_SLOWDOWN)
		Job.SCANNING:
			if register.front_customer() == null:
				job = Job.AT_POST
				return
			timer -= delta
			if timer <= 0.0:
				register.checkout()
				job = Job.AT_POST
		Job.NO_POST, Job.IDLE:
			timer -= delta
			if timer <= 0.0:
				timer = 2.0
				_go_to_post()


func _go_to_post() -> void:
	post = store.cashier_post(register, self)
	if post == Store.NO_CELL or not _go_to(post):
		job = Job.NO_POST
		timer = 2.0
		return
	job = Job.TO_POST


# ---------------------------------------------------------------- both

## Shelves or registers moved in build mode: find new routes.
func on_layout_changed() -> void:
	match job:
		Job.TO_BOX:
			if not _box_ok() or not _go_to(target_box.cell):
				_give_up()
		Job.TO_SHELF, Job.STOCKING:
			_go_to_shelf()
		Job.TO_DROP:
			path.clear()
			job = Job.IDLE
		Job.TO_POST, Job.AT_POST, Job.SCANNING, Job.NO_POST:
			if is_instance_valid(register) and register in store.registers:
				_go_to_post()
			else:
				register = null
				job = Job.IDLE
		Job.IDLE:
			path.clear()


## Called when they're fired or the store closes down for a load: drop
## what they're holding and let go of everything.
func leave() -> void:
	store.release_all(self)
	if carry_count > 0:
		var c := store.nearest_drop_cell(current_cell())
		if c != Store.NO_CELL:
			store.drop_box(c, carry_product, carry_count)
		carry_count = 0
	if is_instance_valid(register) and register.cashier == self:
		register.cashier = null
	queue_free()


func _start(new_job: Job, seconds: float) -> void:
	job = new_job
	timer = seconds
	duration = seconds


func _face(target: Vector2) -> void:
	if absf(target.x - position.x) > 1.0:
		sprite.flip_h = target.x < position.x


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


func _animate(delta: float) -> void:
	if not path.is_empty():
		_walk_anim += delta * 14.0
		sprite.position.y = -roundf(absf(sin(_walk_anim)) * 2.0)
	else:
		sprite.position.y = 0.0
