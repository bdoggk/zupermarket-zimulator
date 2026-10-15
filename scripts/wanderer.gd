class_name Wanderer
extends Node2D
## Someone walking around town: shoppers on their way to the rival store,
## its skeleton staff, zombies shambling down the street. They walk to each
## of their stops in turn and wait there a moment. At the end they fade
## away, unless `loop` (start over) or `stay` (stand there) is on.

const FADE_SPEED := 2.5

var store: Store
var stops: Array = []  # [[cell, seconds to wait there], ...]
var loop := false
var stay := false
var speed := 2.0  # cells per second
var path: Array[Vector2i] = []
var wait := 0.0
var sprite: Sprite2D
var _walk_anim := 0.0
var _leaving := false
var _t := randf() * 10.0


func setup(s: Store, tex: Texture2D, cell: Vector2i, stop_list: Array, cells_per_second := 2.0) -> void:
	store = s
	stops = stop_list
	speed = cells_per_second
	position = Iso.cell_to_world(cell)
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.offset = Vector2(-floorf(tex.get_width() / 2.0), -(tex.get_height() - 2))
	add_child(sprite)
	modulate.a = 0.0


func current_cell() -> Vector2i:
	return Iso.world_to_cell(position)


## Walks off and fades away (e.g. the rival's staff once you buy it out).
func leave(exit := Store.NO_CELL) -> void:
	stay = false
	loop = false
	stops.clear()
	path.clear()
	wait = 0.0
	if exit != Store.NO_CELL:
		stops.append([exit, 0.0])


func is_leaving() -> bool:
	return _leaving


func _process(delta: float) -> void:
	_t += delta
	if _leaving:
		modulate.a -= delta * FADE_SPEED
		if modulate.a <= 0.0:
			queue_free()
		return
	modulate.a = minf(1.0, modulate.a + delta * FADE_SPEED)
	if not path.is_empty():
		_walk(delta)
	elif wait > 0.0:
		wait -= delta
	elif not stops.is_empty():
		var stop: Array = stops.pop_front()
		if loop:
			stops.push_back(stop)
		wait = stop[1]
		var p := store.find_path(current_cell(), stop[0])
		if not p.is_empty() and position.distance_to(Iso.cell_to_world(p[0])) < 2.0:
			p.remove_at(0)
		path = p
	elif not stay:
		_leaving = true
	_animate(delta)


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


func _animate(delta: float) -> void:
	if not path.is_empty():
		_walk_anim += delta * 14.0
		sprite.position.y = -roundf(absf(sin(_walk_anim)) * 1.5)
	elif stay:
		sprite.position.y = -1.0 if fmod(_t, 3.0) < 0.25 else 0.0  # a little bob now and then
	else:
		sprite.position.y = 0.0


func face(world_pos: Vector2) -> void:
	if absf(world_pos.x - position.x) > 1.0:
		sprite.flip_h = world_pos.x < position.x
