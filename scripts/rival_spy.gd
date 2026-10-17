class_name RivalSpy
extends Interactable
## A spy from the rival store (Brand.RIVAL): a skeleton in a trench coat who
## sneaks into your store while you're open, stands at a few of your shelves
## taking notes, and walks back out. If it gets away, the rival undercuts
## your prices on what it saw (Game.rival_spy_got_away). Walk up to it and
## use it to throw it out (Game.rival_spy_caught). A Spy on your staff
## throws it out too.
##
## The town sends one over when Game.rival_spies says so. It walks around
## like a shopper, and the store keeps it in Store.movers so you can walk up
## to it, click it or tap it.

enum State { IN, SNOOPING, OUT, CAUGHT }

const SPEED := 2.2  # cells per second
const RUN_SPEED := 4.6  # running off once it's caught
const NOTE_SECONDS := 2.5  # taking notes at each shelf
const MAX_SHELVES := 3
const FADE_SPEED := 2.5
const UNSTICK_AFTER := 3.0  # not getting anywhere this long: find a new way

var store: Store
var state := State.IN
var home := Store.NO_CELL  # the rival's door: where it comes from and goes back to
var shelves: Array = []  # the shelves it's still going to look at (some may get sold)
var looking_at: Shelf = null
var seen: Array[String] = []  # products it took notes on
var path: Array[Vector2i] = []
var goal := Store.NO_CELL
var wait := 0.0
var sprite: Sprite2D
var _came_in := false  # has been inside your store
var _told := false  # the rival has heard what it saw
var _fading := false
var _alpha := 0.0
var _stuck := 0.0
var _last_pos := Vector2.ZERO
var _walk_anim := 0.0
var _t := 0.0


func setup(s: Store, from: Vector2i) -> void:
	store = s
	home = from
	cell = from
	position = Iso.cell_to_world(from)
	sprite = Sprite2D.new()
	sprite.texture = Brand.RIVAL.textures.spy
	sprite.centered = false
	sprite.offset = Vector2(-8, -34)
	add_child(sprite)
	_go(store.door_cell)


func current_cell() -> Vector2i:
	return Iso.world_to_cell(position)


## Inside your store right now.
func is_inside() -> bool:
	return store.floor_cells.has(cell)


## You (or your spy) can still throw it out.
func can_be_caught() -> bool:
	return state != State.CAUGHT and not _fading


func get_prompt(_p: Player) -> String:
	return "Throw out %s's spy" % Brand.RIVAL.name if can_be_caught() else ""


func can_interact(_p: Player) -> bool:
	return can_be_caught()


func use_priority(_p: Player) -> int:
	return 5  # before the shelf it's standing next to


func interact(_p: Player) -> void:
	caught()


func get_pick_rect() -> Rect2:
	return Rect2(-10, -40, 20, 44)


func is_movable() -> bool:
	return false


func is_sellable() -> bool:
	return false


## Thrown out (by you, or by `by`: one of your staff). It runs off without
## telling the rival anything.
func caught(by := "") -> void:
	if not can_be_caught():
		return
	state = State.CAUGHT
	looking_at = null
	wait = 0.0
	Game.rival_spy_caught(by)
	Game.show_popup(position + Vector2(0, -50), "Eek!", Color(0.92, 0.9, 0.82))
	Settings.vibrate(0.4, 0.12)
	_go(store.door_cell if is_inside() else home)


## Furniture moved in build mode: find a new way to where it was going.
func on_layout_changed() -> void:
	if looking_at != null and not is_instance_valid(looking_at):
		looking_at = null
	if goal != Store.NO_CELL:
		_go(goal)


func _process(delta: float) -> void:
	_t += delta
	cell = current_cell()
	if _fading:
		_alpha -= delta * FADE_SPEED
		if _alpha <= 0.0:
			store.movers.erase(self)
			queue_free()
	else:
		_alpha = minf(1.0, _alpha + delta * FADE_SPEED)
	var b := 1.3 if highlighted else 1.0
	modulate = Color(b, b, b, _alpha)
	if _fading:
		return
	if is_inside() and not _came_in:
		_came_in = true
		Game.message.emit(Brand.RIVAL.spy_in)
		Settings.vibrate(0.3, 0.1)
	if state in [State.IN, State.SNOOPING] and (not Game.is_open or Game.rival_owned):
		_leave()  # closing time: off it goes with whatever it has
	if not path.is_empty():
		_walk(delta)
	elif wait > 0.0:
		wait -= delta
		if wait <= 0.0:
			_done_looking()
	else:
		_arrived()
	_animate(delta)
	queue_redraw()


func _draw() -> void:
	if is_inside() and can_be_caught():  # easy to spot once it's in
		draw_string(ThemeDB.fallback_font, Vector2(-3, -40 + sprite.position.y), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.35, 0.3))


## Got where it was going.
func _arrived() -> void:
	match state:
		State.IN:
			if current_cell() == store.door_cell or is_inside():
				_pick_shelves()
				_next_shelf()
			elif not _go(store.door_cell):
				_fading = true  # can't get in: never mind
		State.SNOOPING:
			if looking_at != null and is_instance_valid(looking_at) and Iso.chebyshev(current_cell(), looking_at.cell) <= 1:
				wait = NOTE_SECONDS
				_face(looking_at.position)
				var notes: Array = Brand.RIVAL.get("spy_notes", ["..."])
				Game.show_popup(position + Vector2(0, -50), notes.pick_random(), Color(0.8, 0.8, 0.78))
			else:
				_next_shelf()
		State.OUT, State.CAUGHT:
			if is_inside() or current_cell() == store.door_cell:
				_go(home)
				if path.is_empty():
					_fading = true
			else:
				_fading = true  # home (or as far as it could get): gone


## Up to MAX_SHELVES of your shelves with something on them.
func _pick_shelves() -> void:
	shelves.clear()
	var stocked := store.shelves.filter(func(s: Shelf): return s.product_id != "")
	stocked.shuffle()
	for s: Shelf in stocked.slice(0, MAX_SHELVES):
		shelves.append(s)
	state = State.SNOOPING


func _next_shelf() -> void:
	looking_at = null
	while not shelves.is_empty():
		var next: Variant = shelves.pop_front()
		if not is_instance_valid(next):
			continue  # sold in build mode
		var s: Shelf = next
		var stand := store.stand_cell_for(s.cell, current_cell(), 1.5)
		if stand != Store.NO_CELL and _go(stand):
			looking_at = s
			return
	_leave()


## Done taking notes at a shelf: what's on it goes in the notebook.
func _done_looking() -> void:
	if state == State.SNOOPING and looking_at != null and is_instance_valid(looking_at):
		var id := looking_at.product_id
		if id != "" and not id in seen:
			seen.append(id)
	_next_shelf()


## Heads back to the rival with what it saw (it tells them on the way out).
func _leave() -> void:
	if state == State.OUT or state == State.CAUGHT:
		return
	state = State.OUT
	looking_at = null
	wait = 0.0
	shelves.clear()
	_tell()
	_go(store.door_cell if is_inside() else home)


func _tell() -> void:
	if _told or not _came_in:
		return
	_told = true
	Game.rival_spy_got_away(seen)


func _go(to: Vector2i) -> bool:
	goal = to
	var p := store.find_path(current_cell(), to)
	if p.is_empty():
		path.clear()
		return current_cell() == to
	if position.distance_to(Iso.cell_to_world(p[0])) < 2.0:
		p.remove_at(0)
	path = p
	_stuck = 0.0
	return true


func _walk(delta: float) -> void:
	var speed := RUN_SPEED if state == State.CAUGHT else SPEED
	var to_target := Iso.cell_to_world(path[0]) - position
	var step := Iso.velocity_toward(to_target, speed) * delta
	if step.length() >= to_target.length():
		position = Iso.cell_to_world(path[0])
		path.remove_at(0)
	else:
		position += step
	if absf(step.x) > 0.01:
		sprite.flip_h = step.x < 0.0
	if position.distance_to(_last_pos) > 0.5:
		_last_pos = position
		_stuck = 0.0
	else:
		_stuck += delta
		if _stuck > UNSTICK_AFTER and goal != Store.NO_CELL:
			_go(goal)


func _face(target: Vector2) -> void:
	if absf(target.x - position.x) > 1.0:
		sprite.flip_h = target.x < position.x


func _animate(delta: float) -> void:
	if not path.is_empty():
		_walk_anim += delta * (20.0 if state == State.CAUGHT else 12.0)
		sprite.position.y = -roundf(absf(sin(_walk_anim)) * 1.5)
	elif wait > 0.0:
		sprite.position.y = -1.0 if fmod(_t, 0.6) < 0.3 else 0.0  # scribbling away
	else:
		sprite.position.y = 0.0
