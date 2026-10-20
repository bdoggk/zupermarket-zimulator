class_name Staff
extends Node2D
## Someone you hired at the computer (Staff tab). They get paid at the end
## of every day, and get faster as they level up (see Game.add_staff_xp).
##
##   Stocker  picks up delivery boxes and stocks the shelves with them:
##            whatever's emptiest on the shelves first, onto the emptiest
##            shelf for it (new, unlabeled shelves last). Whatever doesn't fit
##            goes on a storage rack (racks are shared), or back on the
##            delivery zone if every rack is full.
##   Cashier  walks to a register (one each) and checks out the customers
##            in its line. While a cashier is at a register, you can't use
##            it yourself, so you're free to do other things.
##   Janitor  (zombie game) mops up the blood shoppers leave behind.
##   General manager  walks around checking the shelves and the staff.
##            Orders more of anything whose shelves are down to a third full
##            (Store.reorder_list: enough boxes to fill them back up), gets
##            anyone who's stuck or slacking back to work, and while they're
##            on the payroll everyone else works MANAGED_BOOST faster.
##   Spy      (zombie game) sneaks over to the rival store every couple of
##            game hours, snoops around its shelves and counter, and comes
##            back to the computer with a report (Game.spy_report: its
##            prices, its deal of the day, when its next spy is coming, and
##            a rumor that keeps shoppers away from it for a while). In
##            between, waits by the front door and throws out the rival's
##            spies (RivalSpy).
##
## XP only comes from real work (_earn): items stocked, items scanned, spills
## mopped, boxes ordered, jams fixed, reports made, spies thrown out.
## Walking around doesn't count. A manager
## who tells someone to get back to work gets NUDGE_XP once that person
## actually gets something done.

enum Job { IDLE, TO_BOX, PICKING_UP, TO_SHELF, STOCKING, TO_DROP, TO_RACK, STORING, TO_POST, AT_POST, SCANNING, NO_POST, TO_SPILL, MOPPING, TO_CHECK, CHECKING, TO_COMPUTER, ORDERING,
	TO_RIVAL, SNOOPING, TO_REPORT, REPORTING, CHASING }

const SPEED := 2.8  # cells per second
const PICKUP_SECONDS := 0.4
const STOCK_SECONDS_PER_ITEM := 0.2  # a little slower than you
const SCAN_SLOWDOWN := 1.15  # cashiers scan a little slower than you
const MOP_SECONDS := 1.4  # a little slower than you
const LOOK_FOR_WORK := 0.6  # seconds between looking for something to do
const NEED_WEIGHT := 1500.0  # stockers: an empty product's box beats a full one's this many pixels closer
const XP_PER_SPILL := 4.0
const REORDER_AT := 2  # the manager always orders more of anything down to this many...
const REORDER_SHARE := 0.34  # ...or to a third of the shelf space labeled for it
const MAX_BOXES_PER_ORDER := 4  # of one product, in one trip to the computer
const ORDER_XP := 4.0  # per box the manager orders
const FIX_XP := 4.0  # the manager fixing a jammed self-checkout
const NUDGE_XP := 2.0  # the manager, once someone they told off gets back to work
const NUDGE_CREDIT_SECONDS := 60.0  # ...if they do within this long
const MANAGED_BOOST := 1.15  # everyone works this much faster with a manager around
const CHECK_SECONDS := 1.5  # the manager looking over a shelf or a worker
const ORDER_SECONDS := 1.5  # the manager placing orders at the computer
const SLACK_SECONDS := 20.0  # on the same job this long = stuck or slacking
const SHOUT_EVERY := 12.0  # the manager checks on everyone from afar this often
const SNOOP_SECONDS := 1.6  # the spy, at each of the rival's shelves
const REPORT_SECONDS := 1.5  # the spy, writing it up at the computer
const CHASE_REPATH := 0.4  # the spy, chasing a rival spy: look where it went this often
## Jobs that mean you're getting something done (waiting for work isn't slacking).
const BUSY_JOBS := [Job.TO_BOX, Job.PICKING_UP, Job.TO_SHELF, Job.STOCKING, Job.TO_DROP, Job.TO_RACK,
	Job.STORING, Job.TO_POST, Job.NO_POST, Job.TO_SPILL, Job.MOPPING]
const BOX_SMALL := preload("res://assets/sprites/box_small.png")
const MOP := preload("res://assets/sprites/mop_held.png")

var id := 0
var role := ""
var staff_name := ""
var store: Store
var job := Job.IDLE
var path: Array[Vector2i] = []
var timer := 0.0
var duration := 0.0  # length of the current timed task (for the progress bar)
var level := 1
var speed := 1.0  # how much faster than a new hire (level, and the manager's boost)
var managed := false  # a general manager is keeping them on their toes

# Stocker
var carry_product := ""
var carry_count := 0
var target_box: StockBox = null  # a box on the floor they're fetching...
var target_rack: StorageRack = null  # ...or a box on this rack
var target_stored: StorageRack.Box = null
var target_shelf: Shelf = null
var put_rack: StorageRack = null  # where they're putting a box away

# Cashier
var register: Register = null
var post := Store.NO_CELL  # where they stand to work the register
var on_break_from: Register = null  # you took over this register from them

# Janitor
var target_spill: Spill = null

# Manager
var watching: Staff = null  # who they're checking on
var fixing: SelfCheckout = null  # a jammed self-checkout they're going to fix
var _shout_timer := SHOUT_EVERY
var _broke_timer := 0.0  # don't keep saying we can't afford something

# Spy
var snoop_stops: Array[Vector2i] = []  # where they're still going to snoop at the rival
var snooping_at := Store.NO_CELL  # what they're looking at there
var chasing: RivalSpy = null  # a rival spy they're throwing out
var last_trip := -1.0  # game minute of their last report...
var _trip_day := 0  # ...on this day

var nudged_by := -1  # the manager who told them to get back to work
var _nudge_credit := 0.0  # seconds left for that manager to get credit for it
var _job_time := 0.0  # how long they've been on the current job
var _last_job := Job.IDLE

var sprite: Sprite2D
var _walk_anim := 0.0


func setup(s: Store, entry: Dictionary, cell: Vector2i) -> void:
	store = s
	id = entry.id
	role = entry.role
	staff_name = entry.name
	position = Iso.cell_to_world(cell)
	set_level(int(entry.get("level", 1)))


func set_level(lv: int) -> void:
	level = lv
	_update_speed()


func set_managed(on: bool) -> void:
	managed = on
	_update_speed()


func _update_speed() -> void:
	speed = Game.staff_speed(level) * (MANAGED_BOOST if managed else 1.0)


func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = Game.STAFF[role].texture
	sprite.centered = false
	sprite.offset = Vector2(-8, -34)
	add_child(sprite)
	Game.staff_leveled.connect(_on_leveled)


func _on_leveled(who: int, lv: int) -> void:
	if who != id:
		return
	set_level(lv)
	Game.show_popup(position + Vector2(0, -52), "Level %d!" % lv, Color(1.0, 0.86, 0.35))


func _process(delta: float) -> void:
	match role:
		"stocker":
			_stocker(delta)
		"janitor":
			_janitor(delta)
		"manager":
			_manager(delta)
		"spy":
			_spy(delta)
		_:
			_cashier(delta)
	_nudge_credit -= delta
	if job != _last_job:
		_last_job = job
		_job_time = 0.0
	else:
		_job_time += delta
	_animate(delta)
	queue_redraw()


## Stuck on the same job for `longer_than` seconds (waiting for work doesn't
## count). The manager notices.
func is_slacking(longer_than := SLACK_SECONDS) -> bool:
	if job == Job.NO_POST and register == null:
		return false  # a cashier with no free register just has nothing to do
	return job in BUSY_JOBS and _job_time > longer_than and not on_break()


## Did some real work: XP for it. If the manager had to tell them to get back
## to work, the manager gets credit too.
func _earn(amount: float) -> void:
	if amount <= 0.0:
		return
	Game.add_staff_xp(id, amount)
	if nudged_by >= 0 and _nudge_credit > 0.0:
		Game.add_staff_xp(nudged_by, NUDGE_XP)
	nudged_by = -1


## A cashier whose register you took over.
func on_break() -> bool:
	return is_instance_valid(on_break_from) and on_break_from.taken_over and job == Job.NO_POST


## You took over their register: go work another free one, or take a break
## until you walk away from it.
func relieve(r: Register) -> void:
	on_break_from = r
	register = null
	post = Store.NO_CELL
	path.clear()
	job = Job.IDLE
	timer = 0.0


## The Staff tab's Reset button, for when they're stuck somewhere: back to
## where they start the day (a cashier: their register), dropping whatever
## they were doing. A box in their hands stays in their hands.
func reset_to_start() -> void:
	var cell := store._staff_start(role)
	if role == "cashier" and post != Store.NO_CELL and store.is_walkable(post):
		cell = post
	if not store.is_walkable(cell):
		cell = store.door_cell
	_give_up()
	timer = 0.0
	_job_time = 0.0
	nudged_by = -1  # you got them going, not the manager
	position = Iso.cell_to_world(cell)
	Game.show_popup(position + Vector2(0, -50), "Reset!", Color(0.8, 0.95, 1.0))


## The manager (`by`, their id) told them to get back to work: drop
## whatever they were stuck on and find something to do.
func nudge(by := -1) -> void:
	_job_time = 0.0
	nudged_by = by
	_nudge_credit = NUDGE_CREDIT_SECONDS
	if role == "cashier":
		register = null
		post = Store.NO_CELL
		job = Job.IDLE
		timer = 0.0
	else:
		_give_up()
		timer = 0.0


func _draw() -> void:
	if role == "janitor":
		draw_texture(MOP, Vector2(-12.0 if sprite.flip_h else 0.0, -32.0 + sprite.position.y) + (Vector2(0, -4) if job == Job.MOPPING and int(timer * 8.0) % 2 == 0 else Vector2.ZERO))
	if carry_count > 0:
		draw_texture(BOX_SMALL, Vector2(-10, -24 + sprite.position.y))
		draw_texture(Game.icon(carry_product), Vector2(-4, -56))
	if job in [Job.PICKING_UP, Job.STOCKING, Job.STORING, Job.SCANNING, Job.MOPPING, Job.CHECKING, Job.ORDERING, Job.SNOOPING, Job.REPORTING] and duration > 0.0:
		var f := clampf(1.0 - timer / duration, 0.0, 1.0)
		draw_rect(Rect2(-11, -44, 22, 5), Color(0.08, 0.08, 0.1, 0.9))
		draw_rect(Rect2(-10, -43, 20 * f, 3), Color(0.45, 0.75, 0.95))
	if job == Job.NO_POST and not on_break():
		draw_string(ThemeDB.fallback_font, Vector2(-3, -40), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.85, 0.3))


## What they're up to, for the Staff tab.
func status_text() -> String:
	match job:
		Job.TO_BOX, Job.PICKING_UP:
			return "Fetching a box"
		Job.TO_SHELF, Job.STOCKING:
			return "Stocking %s" % Game.product_name(carry_product)
		Job.TO_DROP:
			return "Shelves are full: taking %s back to the delivery zone" % Game.product_name(carry_product)
		Job.TO_RACK, Job.STORING:
			return "Putting %s in storage" % Game.product_name(carry_product)
		Job.TO_POST:
			return "Walking to register %d" % (store.registers.find(register) + 1)
		Job.AT_POST:
			return "Running register %d" % (store.registers.find(register) + 1)
		Job.SCANNING:
			return "Checking out a %s" % Brand.SAY.shopper
		Job.NO_POST:
			if on_break():
				return "On a break: you took over register %d (they're back once you step away, or press E on it)" % (store.registers.find(on_break_from) + 1)
			return "Can't get to a free register" if store.registers.size() > 0 else "No register"
		Job.TO_SPILL:
			return "Heading to a mess"
		Job.MOPPING:
			return "Mopping"
		Job.TO_CHECK, Job.CHECKING:
			if is_instance_valid(fixing):
				return "Fixing a self-checkout"
			return "Checking on %s" % watching.staff_name if is_instance_valid(watching) else "Checking the shelves"
		Job.TO_COMPUTER:
			return "Going to order more stock"
		Job.ORDERING:
			return "Ordering stock"
		Job.TO_RIVAL:
			return "Sneaking over to %s" % Brand.RIVAL.name
		Job.SNOOPING:
			return "Snooping around %s" % Brand.RIVAL.name
		Job.TO_REPORT:
			return "Coming back with news"
		Job.REPORTING:
			return "Writing a report at the computer"
		Job.CHASING:
			return "Throwing out %s's spy!" % Brand.RIVAL.name
	if role == "spy":
		if Game.rival_owned:
			return "%s is yours: nothing to spy on" % Brand.RIVAL.name
		if Game.day_over:
			return "Off duty for the night"
		return "Keeping watch by the door (next trip about %s)" % Game.time_text(roundi(next_trip() / 30.0) * 30)
	if role == "stocker":
		return "Waiting for deliveries"
	if role == "janitor":
		return "Waiting for a mess"
	if role == "manager":
		return "Walking the floor"
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
				if Iso.chebyshev(current_cell(), _source_cell()) <= 1:
					_start(Job.PICKING_UP, PICKUP_SECONDS / speed)
					_face(Iso.cell_to_world(_source_cell()))
				else:
					_give_up()
		Job.PICKING_UP:
			if not _box_ok():
				_give_up()
				return
			timer -= delta
			if timer <= 0.0:
				if target_rack:
					target_rack.take(target_stored)
					carry_product = target_stored.product_id
					carry_count = target_stored.count
				else:
					carry_product = target_box.product_id
					carry_count = target_box.count
					store.release(target_box)
					store.remove_box(target_box)
				target_box = null
				target_rack = null
				target_stored = null
				if target_shelf:
					_go_to_shelf()
				else:
					_deliver()
		Job.TO_SHELF:
			if not _shelf_ok():
				_give_up()
			elif _walk(delta):
				if Iso.chebyshev(current_cell(), target_shelf.cell) <= 1:
					var n := mini(carry_count, Shelf.CAPACITY - target_shelf.stock)
					_start(Job.STOCKING, n * STOCK_SECONDS_PER_ITEM / speed)
					_face(target_shelf.position)
				else:
					_give_up()
		Job.STOCKING:
			if not _shelf_ok():
				_give_up()
				return
			timer -= delta
			if timer <= 0.0:
				var stocked := target_shelf.add_stock(carry_product, carry_count)
				carry_count -= stocked
				_earn(stocked)
				if carry_count <= 0:
					carry_count = 0
					carry_product = ""
				store.release(target_shelf)
				target_shelf = null
				job = Job.IDLE
				timer = 0.1
		Job.TO_RACK:
			if not _put_rack_ok():
				_give_up()
			elif _walk(delta):
				if Iso.chebyshev(current_cell(), put_rack.cell) <= 1:
					_start(Job.STORING, PICKUP_SECONDS / speed)
					_face(put_rack.position)
				else:
					_give_up()
		Job.STORING:
			if not _put_rack_ok():
				_give_up()
				return
			timer -= delta
			if timer <= 0.0:
				put_rack.store_box(carry_product, carry_count)
				carry_product = ""
				carry_count = 0
				store.release(put_rack)
				put_rack = null
				job = Job.IDLE
				timer = 0.1
		Job.TO_DROP:
			if _walk(delta):
				if store.drop_box(current_cell(), carry_product, carry_count):
					carry_product = ""
					carry_count = 0
				job = Job.IDLE
				timer = 2.0


## Looks for a box (on the floor or in a storage rack) that has a shelf to
## go on: whatever's emptiest on the shelves first (a whole shelf-load of
## difference beats walking across the store), then the closest. With
## nothing to stock, tidies boxes off the floor into a rack.
func _find_box() -> void:
	var best_d := INF
	var pick: Array = []  # [floor box, rack, box on the rack, shelf]
	for box: StockBox in store.boxes.values():
		if store.is_claimed(box, self):
			continue
		var shelf := store.best_shelf_for(box.product_id, box.position, self)
		if shelf == null:
			continue
		var d := position.distance_to(box.position) + store.shelf_fill(box.product_id) * NEED_WEIGHT
		if d < best_d:
			best_d = d
			pick = [box, null, null, shelf]
	for rack in store.racks:
		for b: StorageRack.Box in rack.boxes:
			if store.is_claimed(b, self):
				continue
			var shelf := store.best_shelf_for(b.product_id, rack.position, self)
			if shelf == null:
				continue
			var d := position.distance_to(rack.position) + 64.0 + store.shelf_fill(b.product_id) * NEED_WEIGHT  # boxes on the floor first
			if d < best_d:
				best_d = d
				pick = [null, rack, b, shelf]
	if pick.is_empty():
		_tidy_up()
		return
	if pick[0]:
		if not _go_to(pick[0].cell):
			return
		target_box = pick[0]
		store.claim(target_box, self)
	else:
		var stand := store.stand_cell_for(pick[1].cell, current_cell())
		if stand == Store.NO_CELL or not _go_to(stand):
			return
		target_rack = pick[1]
		target_stored = pick[2]
		store.claim(target_stored, self)
	target_shelf = pick[3]
	store.claim(target_shelf, self)
	job = Job.TO_BOX


## Nothing to stock: put a box that has no shelf to go on (one on the
## delivery zone first) away on a storage rack, to keep the floor clear.
func _tidy_up() -> void:
	if store.racks.is_empty():
		return
	var rack := store.rack_with_room(position, self)
	if rack == null:
		return
	var best: StockBox = null
	var best_d := INF
	for box: StockBox in store.boxes.values():
		if store.is_claimed(box, self):
			continue
		var d := position.distance_to(box.position)
		if not box.cell in store.delivery_cells:
			d += 4000.0
		if d < best_d:
			best_d = d
			best = box
	if best == null or not _go_to(best.cell):
		return
	target_box = best
	store.claim(best, self)
	put_rack = rack  # (racks are shared, not claimed: see Store.rack_with_room)
	target_shelf = null
	job = Job.TO_BOX


## Has a box in hand: take it to a shelf. If every shelf for it is full,
## put it away on a storage rack, or back on the delivery zone (only on the
## floor somewhere if both are full).
func _deliver() -> void:
	target_shelf = store.best_shelf_for(carry_product, position, self)
	if target_shelf:
		store.claim(target_shelf, self)
		if put_rack:
			store.release(put_rack)
			put_rack = null
		_go_to_shelf()
		return
	if not _put_rack_ok():
		put_rack = store.rack_with_room(position, self)
	if put_rack:
		var stand := store.stand_cell_for(put_rack.cell, current_cell())
		if stand != Store.NO_CELL and _go_to(stand):
			job = Job.TO_RACK
			return
		store.release(put_rack)
		put_rack = null
	var c := store.free_delivery_cell(current_cell())
	if c == Store.NO_CELL:
		c = store.nearest_drop_cell(current_cell())
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


## Where the box they're fetching is.
func _source_cell() -> Vector2i:
	return target_rack.cell if target_rack else target_box.cell


func _go_to_source() -> bool:
	if target_rack:
		var stand := store.stand_cell_for(target_rack.cell, current_cell())
		return stand != Store.NO_CELL and _go_to(stand)
	return _go_to(target_box.cell)


func _box_ok() -> bool:
	if target_rack:
		return is_instance_valid(target_rack) and not target_rack.is_queued_for_deletion() \
			and target_stored in target_rack.boxes
	return is_instance_valid(target_box) and not target_box.is_queued_for_deletion() \
		and store.boxes.get(target_box.cell) == target_box


func _shelf_ok() -> bool:
	return is_instance_valid(target_shelf) and not target_shelf.is_queued_for_deletion() \
		and target_shelf.accepts(carry_product) and target_shelf.stock < Shelf.CAPACITY


func _put_rack_ok() -> bool:
	return is_instance_valid(put_rack) and not put_rack.is_queued_for_deletion() \
		and put_rack in store.racks and put_rack.has_room()


## Drops the current plan (someone took the box, the shelf filled up or was
## moved...) and looks for something else to do.
func _give_up() -> void:
	store.release_all(self)
	target_box = null
	target_rack = null
	target_stored = null
	target_shelf = null
	put_rack = null
	target_spill = null
	watching = null
	fixing = null
	chasing = null
	snoop_stops.clear()
	snooping_at = Store.NO_CELL
	path.clear()
	job = Job.IDLE
	timer = 0.3


## Wanders back near the delivery zone (janitors: the mop bucket) when
## there's nothing to do.
func _go_home() -> void:
	var spot := store.delivery_cells[-1] if not store.delivery_cells.is_empty() else Store.NO_CELL
	if role == "janitor" and store.mop_bucket:
		spot = store.mop_bucket.cell
	elif role == "spy":
		spot = store.door_cell
	if spot == Store.NO_CELL or Iso.chebyshev(current_cell(), spot) <= 3:
		return
	var home := store.stand_cell_for(spot, current_cell(), 2.0)
	if home != Store.NO_CELL:
		_go_to(home)


# ---------------------------------------------------------------- cashier

func _cashier(delta: float) -> void:
	if not is_instance_valid(register) or not register in store.registers:
		if job == Job.NO_POST:
			timer -= delta  # don't look for a free register every frame
			if timer > 0.0:
				if not path.is_empty():
					_walk(delta)
				return
		register = store.assign_register(self)
		if register == null:
			job = Job.NO_POST
			timer = 1.0
			if not path.is_empty():
				_walk(delta)
			return
		on_break_from = null
		_go_to_post()
	match job:
		Job.TO_POST:
			if _walk(delta):
				job = Job.AT_POST if current_cell() == post else Job.NO_POST
		Job.AT_POST:
			_face(register.position)
			var c := register.front_customer()
			if c and not register.player_is_scanning():
				_start(Job.SCANNING, register.scan_time(c) * SCAN_SLOWDOWN / speed)
		Job.SCANNING:
			if register.front_customer() == null:
				job = Job.AT_POST
				return
			timer -= delta
			if timer <= 0.0:
				var front := register.front_customer()
				var items := front.item_count() if front else 0
				register.checkout()
				_earn(items)
				job = Job.AT_POST
		Job.NO_POST, Job.IDLE:
			timer -= delta
			if timer <= 0.0:
				timer = 2.0
				_go_to_post()


## Standing at their post, and it's still a good place to work the
## register from (next to it, not in anyone's line).
func _post_still_ok() -> bool:
	return post != Store.NO_CELL and current_cell() == post and Iso.chebyshev(post, register.cell) == 1 \
		and store.is_walkable(post) and not store.is_line_spot(post)


func _go_to_post() -> void:
	post = store.cashier_post(register, self)
	if post == Store.NO_CELL or not _go_to(post):
		job = Job.NO_POST
		timer = 2.0
		return
	job = Job.TO_POST


# ---------------------------------------------------------------- janitor

func _janitor(delta: float) -> void:
	match job:
		Job.IDLE:
			if not path.is_empty():
				_walk(delta)  # wandering back to the mop bucket
			timer -= delta
			if timer > 0.0:
				return
			timer = LOOK_FOR_WORK
			_find_spill()
			if job == Job.IDLE and path.is_empty():
				_go_home()
		Job.TO_SPILL:
			if not _spill_ok():
				_give_up()
			elif _walk(delta):
				if Iso.chebyshev(current_cell(), target_spill.cell) <= 1:
					_start(Job.MOPPING, MOP_SECONDS / speed)
					_face(target_spill.position)
				else:
					_give_up()
		Job.MOPPING:
			if not _spill_ok():
				_give_up()
				return
			timer -= delta
			if timer <= 0.0:
				Game.record_spill_cleaned()
				Game.show_popup(target_spill.position + Vector2(0, -20), "Clean!", Color(0.7, 0.9, 1.0))
				store.remove_spill(target_spill)
				_earn(XP_PER_SPILL)
				_give_up()
				timer = 0.1


## The closest spill nobody else is cleaning.
func _find_spill() -> void:
	var best: Spill = null
	var best_d := INF
	for sp: Spill in store.spills.values():
		if store.is_claimed(sp, self) or not store.reachable.has(sp.cell):
			continue
		var d := position.distance_to(sp.position)
		if d < best_d:
			best_d = d
			best = sp
	if best == null:
		return
	var stand := best.cell if store.is_walkable(best.cell) else store.stand_cell_for(best.cell, current_cell())
	if stand == Store.NO_CELL or not _go_to(stand):
		return
	target_spill = best
	store.claim(best, self)
	job = Job.TO_SPILL


func _spill_ok() -> bool:
	return is_instance_valid(target_spill) and not target_spill.is_queued_for_deletion() \
		and store.spills.get(target_spill.cell) == target_spill


# ---------------------------------------------------------------- manager

func _manager(delta: float) -> void:
	_broke_timer -= delta
	_shout_timer -= delta
	if _shout_timer <= 0.0:
		_shout_timer = SHOUT_EVERY
		for s in store.staff:  # anyone stuck for a long time gets told off from across the store
			if s != self and s.is_slacking(SLACK_SECONDS * 2.0):
				_nudge(s)
	match job:
		Job.IDLE:
			if not path.is_empty():
				_walk(delta)
			timer -= delta
			if timer > 0.0:
				return
			timer = 1.0
			if not _plan_fix() and not _plan_order():
				_patrol()
		Job.TO_CHECK:
			if _walk(delta):
				_start(Job.CHECKING, CHECK_SECONDS / speed)
				if is_instance_valid(watching):
					_face(watching.position)
		Job.CHECKING:
			timer -= delta
			if timer <= 0.0:
				if is_instance_valid(fixing):
					store.release(fixing)
					if fixing.jammed:
						fixing.fix()
						_earn(FIX_XP)
				fixing = null
				if is_instance_valid(watching) and watching.is_slacking():
					_nudge(watching)
				watching = null  # just looking around: no XP for that
				job = Job.IDLE
				timer = 0.3
		Job.TO_COMPUTER:
			if not is_instance_valid(store.computer):
				_give_up()
			elif _walk(delta):
				if Iso.chebyshev(current_cell(), store.computer.cell) <= 1:
					_start(Job.ORDERING, ORDER_SECONDS / speed)
					_face(store.computer.position)
				else:
					_give_up()
		Job.ORDERING:
			timer -= delta
			if timer <= 0.0:
				_place_orders()
				job = Job.IDLE
				timer = 1.0


## A self-checkout is jammed: go fix it (before anything else).
func _plan_fix() -> bool:
	for r in store.registers:
		if r is SelfCheckout and r.jammed and not store.is_claimed(r, self):
			var stand := store.stand_cell_for(r.cell, current_cell())
			if stand != Store.NO_CELL and _go_to(stand):
				fixing = r
				watching = null
				store.claim(r, self)
				job = Job.TO_CHECK
				return true
	return false


## Something's running low: head to the computer to order more.
func _plan_order() -> bool:
	if store.computer == null or _broke_timer > 0.0 or store.reorder_list().is_empty():
		return false
	var stand := store.stand_cell_for(store.computer.cell, current_cell())
	if stand == Store.NO_CELL or not _go_to(stand):
		return false
	job = Job.TO_COMPUTER
	return true


## At the computer: orders what's running low. One box of each first (the
## emptiest first), then more to fill the shelves back up, as long as they
## fit on the delivery zone.
func _place_orders() -> void:
	var wants := store.reorder_list()
	var room := maxi(1, store.delivery_room())
	var got := {}
	var broke: Array[String] = []
	for n in MAX_BOXES_PER_ORDER:  # a round of one box each
		for pid: String in wants:
			if room <= 0:
				break
			if int(got.get(pid, 0)) != n or int(wants[pid]) <= n or Game.product_name(pid) in broke:
				continue
			if not Game.order_box(pid, true):
				broke.append(Game.product_name(pid))
				continue
			got[pid] = int(got.get(pid, 0)) + 1
			room -= 1
			_earn(ORDER_XP)
	var ordered: Array[String] = []
	for pid: String in got:
		ordered.append(("a box of %s" if got[pid] == 1 else "%d boxes of %%s" % got[pid]) % Game.product_name(pid))
	if not ordered.is_empty():
		Game.message.emit("%s ordered %s." % [staff_name, _list(ordered)])
		Game.show_popup(position + Vector2(0, -50), "Ordered!", Color(0.7, 0.9, 1.0))
	if not broke.is_empty():
		_broke_timer = 60.0
		Game.message.emit("%s can't afford more %s right now." % [staff_name, _list(broke)])


static func _list(names: Array[String]) -> String:
	if names.size() == 1:
		return names[0]
	return ", ".join(names.slice(0, -1)) + " and " + names[-1]


## Walks over to look at a shelf, or at one of the other staff.
func _patrol() -> void:
	var others := store.staff.filter(func(s): return s != self and not s.is_queued_for_deletion())
	var target_cell := Store.NO_CELL
	watching = null
	if not others.is_empty() and randf() < 0.5:
		watching = others.pick_random()
		target_cell = store.stand_cell_for(watching.current_cell(), current_cell(), 1.0)
	elif not store.shelves.is_empty():
		var shelf: Shelf = store.shelves.pick_random()
		target_cell = store.stand_cell_for(shelf.cell, current_cell(), 1.0)
	if target_cell != Store.NO_CELL and _go_to(target_cell):
		job = Job.TO_CHECK
	else:
		watching = null


## Tells `s` to get back to work. The XP for it comes later, if they do.
func _nudge(s: Staff) -> void:
	s.nudge(id)
	Game.show_popup(s.position + Vector2(0, -52), "Back to work, %s!" % s.staff_name, Color(1.0, 0.75, 0.4))


# ---------------------------------------------------------------- spy

func _spy(delta: float) -> void:
	match job:
		Job.IDLE:
			if not path.is_empty():
				_walk(delta)  # wandering back to the door
			timer -= delta
			if timer > 0.0:
				return
			timer = LOOK_FOR_WORK
			if not _plan_chase() and not _plan_trip() and path.is_empty():
				_go_home()
		Job.CHASING:
			if not is_instance_valid(chasing) or not chasing.can_be_caught():
				_give_up()
				return
			if Iso.chebyshev(current_cell(), chasing.cell) <= 1:
				chasing.caught(staff_name)
				Game.show_popup(position + Vector2(0, -52), "Out you go!", Color(1.0, 0.75, 0.4))
				_earn(Game.SPY_CATCH_XP)
				_give_up()
				return
			timer -= delta
			if timer <= 0.0 or path.is_empty():  # it keeps moving: keep after it
				timer = CHASE_REPATH
				_go_to(chasing.current_cell())
			_walk(delta)
		Job.TO_RIVAL:
			if Game.rival_owned or Game.day_over:
				_give_up()
			elif _walk(delta):
				_start(Job.SNOOPING, SNOOP_SECONDS / speed)
				if snooping_at != Store.NO_CELL:
					_face(Iso.cell_to_world(snooping_at))
		Job.SNOOPING:
			timer -= delta
			if timer > 0.0:
				return
			if randf() < 0.4:
				Game.show_popup(position + Vector2(0, -50), ["*peeks*", "Psst...", "Hmm!"].pick_random(), Color(0.75, 0.85, 0.75))
			_next_snoop()
		Job.TO_REPORT:
			if not is_instance_valid(store.computer):
				_give_up()
			elif _walk(delta):
				_start(Job.REPORTING, REPORT_SECONDS / speed)
				_face(store.computer.position)
		Job.REPORTING:
			timer -= delta
			if timer <= 0.0:
				Game.spy_report(staff_name)
				Game.show_popup(position + Vector2(0, -50), "Report's in!", Color(0.7, 0.9, 1.0))
				_earn(Game.SPY_REPORT_XP)
				_trip_day = Game.day
				last_trip = Game.minute
				job = Job.IDLE
				timer = 1.0


## The game minute their next trip to the rival is due.
func next_trip() -> float:
	if _trip_day != Game.day:
		return Game.minute
	return last_trip + Game.SPY_EVERY_MINUTES


func _trip_due() -> bool:
	if Game.rival_owned or Game.day_over or store.town == null or store.computer == null:
		return false
	return Game.minute >= next_trip() and Game.minute < Game.CLOSE_MINUTE


## Off to the rival: a couple of its shelves, then its counter.
func _plan_trip() -> bool:
	if not _trip_due():
		return false
	var t: Town = store.town
	var stops: Array[Vector2i] = []
	var spots: Array = []
	spots.assign(t.rival_shelves)
	spots.shuffle()
	spots = spots.slice(0, 2)
	if t.rival_desk:
		spots.append(t.rival_desk)
	for obj in spots:
		var c := store.stand_cell_for(obj.cell, t.rival_door, 1.5)
		if c != Store.NO_CELL and c != t.owner_cell:
			stops.append(c)
	snoop_stops = stops
	if stops.is_empty():
		_trip_day = Game.day  # can't get in there: try again later
		last_trip = Game.minute
		return false
	_next_snoop()
	return job != Job.IDLE


## On to the next spot at the rival, or back to the computer with the news.
func _next_snoop() -> void:
	while not snoop_stops.is_empty():
		var c: Vector2i = snoop_stops.pop_front()
		if _go_to(c):
			snooping_at = _nearest_rival_thing(c)
			job = Job.TO_RIVAL
			return
	snooping_at = Store.NO_CELL
	if Game.rival_owned or not is_instance_valid(store.computer):
		_give_up()
		return
	var stand := store.stand_cell_for(store.computer.cell, current_cell())
	if stand != Store.NO_CELL and _go_to(stand):
		job = Job.TO_REPORT
	else:
		_give_up()


func _nearest_rival_thing(c: Vector2i) -> Vector2i:
	var t: Town = store.town
	var things: Array = []
	things.assign(t.rival_shelves)
	if t.rival_desk:
		things.append(t.rival_desk)
	for obj: Interactable in things:
		if Iso.chebyshev(obj.cell, c) <= 1:
			return obj.cell
	return Store.NO_CELL


## One of the rival's spies is in the store: go throw it out.
func _plan_chase() -> bool:
	for m in store.movers:
		if m is RivalSpy and is_instance_valid(m) and m.can_be_caught() and m.is_inside() and not store.is_claimed(m, self):
			if _go_to(m.current_cell()) or Iso.chebyshev(current_cell(), m.cell) <= 1:
				chasing = m
				store.claim(m, self)
				job = Job.CHASING
				timer = CHASE_REPATH
				return true
	return false


# ---------------------------------------------------------------- both

## Shelves or registers moved in build mode: find new routes.
func on_layout_changed() -> void:
	match job:
		Job.TO_BOX:
			if not _box_ok() or not _go_to_source():
				_give_up()
		Job.TO_SHELF, Job.STOCKING:
			_go_to_shelf()
		Job.TO_DROP:
			path.clear()
			job = Job.IDLE
		Job.TO_SPILL, Job.MOPPING, Job.TO_RACK, Job.STORING, Job.TO_CHECK, Job.CHECKING, Job.TO_COMPUTER, Job.TO_REPORT, Job.CHASING:
			_give_up()
		Job.TO_RIVAL:
			if not path.is_empty():
				_go_to(path[-1])  # the way out might have changed
		Job.TO_POST, Job.AT_POST, Job.SCANNING, Job.NO_POST:
			if is_instance_valid(register) and register in store.registers:
				if job in [Job.AT_POST, Job.SCANNING] and _post_still_ok():
					pass  # still in a good spot: keep ringing people up
				else:
					_go_to_post()
			else:
				register = null
				job = Job.IDLE
		Job.IDLE:
			path.clear()


## Called when they're fired or the store closes down for a load: drop
## what they're holding and let go of everything. They stop right away (not
## at the end of the frame), so they can't finish picking up a box on the
## way out and take it with them.
func leave() -> void:
	set_process(false)
	set_physics_process(false)
	_give_up()
	if carry_count > 0:
		store.stash_box(current_cell(), carry_product, carry_count)  # put down (never lost)
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
	var step := Iso.velocity_toward(to_target, SPEED * speed) * delta
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
