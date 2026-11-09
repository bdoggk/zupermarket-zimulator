class_name TourBus
extends Node2D
## The tour bus (0.19, Calendar event "bus"): drives in along the road from
## the west, stops outside the store, lets out a crowd of tourists (shoppers
## with long lists, Brand.EVENT_SHOPPERS.tourist) one after another, and
## drives off east.

enum State { ARRIVING, UNLOADING, LEAVING }

const ROAD_ROW := 14  # the lane by the store (Brand.TOWN: clear all the way along)
const SPEED := 5.0  # cells per second
const SLOW_FROM := 6.0  # cells before the stop it slows down
const STOP_GAP := 0.55  # seconds between tourists getting off
const WAIT_AFTER := 1.5
const ORIGIN := Vector2(34, 54)  # the middle of its back tile, in the picture (make_sprites.tour_bus)

var store: Store
var state := State.ARRIVING
var x := -6.0  # where its back tile is along the road, in cells
var stop_x := 0.0
var to_drop := 0
var _t := 0.0
var body: Sprite2D  # (not "sprite": first person leaves it out)


func setup(s: Store, tourists: int) -> void:
	store = s
	to_drop = tourists
	stop_x = float(store.door_cell.x) + 1.0  # (just past the door: clear of the wreck parked before it)
	body = Sprite2D.new()
	body.texture = Brand.BUS_TEXTURE
	body.centered = false
	body.offset = -ORIGIN
	add_child(body)
	_place()
	store.world.add_child(self)


func _place() -> void:
	position = Iso.cell_to_world(Vector2i(0, ROAD_ROW)) + Vector2(32, 16) * x


## Where the tourists get off: the pavement by the bus's door.
func door_cell() -> Vector2i:
	var c := Vector2i(roundi(x) + 1, ROAD_ROW - 1)
	if store.is_walkable(c):
		return c
	return store.exit_cell_near(store.door_cell)


func _process(delta: float) -> void:
	_t += delta
	match state:
		State.ARRIVING:
			var left := stop_x - x
			x += minf(left, SPEED * delta * clampf(left / SLOW_FROM, 0.25, 1.0))
			if left <= 0.01:
				x = stop_x
				state = State.UNLOADING
				_t = 0.0
				store.events.play("bus")
		State.UNLOADING:
			if to_drop > 0 and _t >= STOP_GAP:
				_t = 0.0
				to_drop -= 1
				store.events.tourist_off(door_cell())
			elif to_drop <= 0 and _t >= WAIT_AFTER:
				state = State.LEAVING
		State.LEAVING:
			x += SPEED * delta * clampf(_t, 0.3, 1.0)
			if x > float(store.town.size.x) + 4.0 if store.town else x > 80.0:
				queue_free()
				return
	_place()
	body.position.y = -1.0 if state != State.UNLOADING and fmod(_t, 0.3) < 0.15 else 0.0  # the engine rumbling
