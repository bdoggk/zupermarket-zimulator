class_name Visitor
extends Interactable
## Someone who comes into the store on business of their own (0.19): the
## health inspector (Inspector), a ghost shoplifter (GhostThief). Like
## Bone Mart's spy (RivalSpy) they walk in from town, stop at a few of your
## shelves, and walk back out; the store keeps them in Store.movers, so you
## can walk up to them, click or tap them. Subclasses say where to go next
## (_next) and what happens at each stop (_at_stop, _stop_done).

const FADE_SPEED := 2.5
const UNSTICK_AFTER := 3.0  # not getting anywhere this long: find a new way

var store: Store
var home := Store.NO_CELL  # where they came from in town, and go back to
var path: Array[Vector2i] = []
var goal := Store.NO_CELL
var wait := 0.0  # seconds left at this stop
var sprite: Sprite2D
var look: Texture2D
var speed := 2.0  # cells per second
var floats := false  # a ghost: it bobs in the air instead of walking
var leaving := false
var came_in := false  # has been inside the store
var stop: Interactable = null  # the shelf (or register) they're at or going to
var _fading := false
var _alpha := 0.0
var _stuck := 0.0
var _last_pos := Vector2.ZERO
var _walk_anim := 0.0
var _t := 0.0


## Puts them in the world at `from` (a town cell), on their way in.
func setup(s: Store, from: Vector2i, tex: Texture2D) -> void:
	store = s
	home = from
	cell = from
	position = Iso.cell_to_world(from)
	look = tex
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.offset = Vector2(-floorf(tex.get_width() / 2.0), -(tex.get_height() - 2))
	add_child(sprite)
	store.world.add_child(self)
	store.movers.append(self)
	_go(store.door_cell)


func current_cell() -> Vector2i:
	return Iso.world_to_cell(position)


func is_inside() -> bool:
	return store.floor_cells.has(cell)


func is_movable() -> bool:
	return false


func is_sellable() -> bool:
	return false


func get_pick_rect() -> Rect2:
	return Rect2(-10, -40, 20, 44)


## Furniture moved in build mode: find a new way to where they were going.
func on_layout_changed() -> void:
	if stop != null and not is_instance_valid(stop):
		stop = null
	if goal != Store.NO_CELL:
		_go(goal)


func _process(delta: float) -> void:
	_t += delta
	cell = current_cell()
	if _fading:
		_alpha -= delta * FADE_SPEED
		if _alpha <= 0.0:
			_gone()
			store.movers.erase(self)
			queue_free()
	else:
		_alpha = minf(1.0, _alpha + delta * FADE_SPEED)
	var b := 1.3 if highlighted else 1.0
	modulate = Color(b, b, b, _alpha * (0.85 if floats else 1.0))
	if _fading:
		return
	if is_inside() and not came_in:
		came_in = true
		_came_in()
	if not leaving and (not Game.is_open or Game.day_over):
		leave()  # closing time
	if not path.is_empty():
		_walk(delta)
	elif wait > 0.0:
		wait -= delta
		if wait <= 0.0:
			_stop_done()
			_next()
	else:
		_arrived()
	_animate(delta)
	queue_redraw()


func _arrived() -> void:
	if leaving:
		if is_inside() or current_cell() == store.door_cell:
			_go(home)
			if path.is_empty():
				_fading = true
		else:
			_fading = true  # home (or as far as they could get): gone
		return
	if not came_in and current_cell() != store.door_cell and not is_inside():
		if not _go(store.door_cell):
			leave()  # can't get in: never mind
		return
	if stop != null and is_instance_valid(stop) and Iso.chebyshev(current_cell(), stop.cell) <= 1:
		_face(stop.position)
		wait = _at_stop()
		if wait <= 0.0:
			_next()
	else:
		_next()


## Off they go (to the door, then home).
func leave() -> void:
	if leaving:
		return
	leaving = true
	stop = null
	wait = 0.0
	_leaving()
	_go(store.door_cell if is_inside() else home)


## Walks over to `obj` (a shelf, a register): false if there's no way there.
func go_to_stop(obj: Interactable) -> bool:
	var stand := store.stand_cell_for(obj.cell, current_cell(), 1.5)
	if stand != Store.NO_CELL and _go(stand):
		stop = obj
		return true
	return false


# What subclasses fill in.

## Pick the next stop (go_to_stop) or leave().
func _next() -> void:
	leave()


## At a stop: returns how many seconds to stay.
func _at_stop() -> float:
	return 0.0


func _stop_done() -> void:
	pass


func _came_in() -> void:
	pass


func _leaving() -> void:
	pass


## Faded out (gone for good).
func _gone() -> void:
	pass


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
	if floats:
		sprite.position.y = -3.0 - roundf(sin(_t * 2.5) * 2.0)
		return
	CharArt.walk(sprite, look, _walk_anim, not path.is_empty())
	if not path.is_empty():
		_walk_anim += delta * 12.0 * speed / 2.0
		sprite.position.y = -roundf(absf(sin(_walk_anim)) * 1.5)
	elif wait > 0.0:
		sprite.position.y = -1.0 if fmod(_t, 0.6) < 0.3 else 0.0
	else:
		sprite.position.y = 0.0
