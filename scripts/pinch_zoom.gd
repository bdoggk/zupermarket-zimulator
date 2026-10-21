class_name PinchZoom
extends Node
## Touch screens: two fingers on the store zoom the view in and out (spread
## them apart to zoom in), in the same whole-pixel steps as the + and -
## buttons. Works in build mode too. The HUD adds one.

const STEP := 1.2  # how much farther apart (or closer) the fingers move for each zoom step

## A second finger came down since the first one did, so letting go isn't
## a tap: the player doesn't walk, and build mode doesn't place anything.
static var pinching := false

var _fingers := {}  # finger index -> where it is on screen
var _spread_at_step := 0.0  # how far apart the fingers were at the last zoom step


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # (build mode pauses the game)
	pinching = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_fingers[event.index] = event.position
		else:
			_fingers.erase(event.index)
		if _fingers.size() >= 2:
			pinching = true
			_spread_at_step = _spread()
		elif _fingers.is_empty():
			pinching = false
	elif event is InputEventScreenDrag and _fingers.has(event.index):
		_fingers[event.index] = event.position
		if _fingers.size() < 2 or Game.player == null:
			return
		var d := _spread()
		if d > _spread_at_step * STEP:
			Game.player.zoom_by(1.25)
			_spread_at_step = d
		elif d * STEP < _spread_at_step:
			Game.player.zoom_by(0.8)
			_spread_at_step = d


func _spread() -> float:
	var at: Array = _fingers.values()
	return (at[0] as Vector2).distance_to(at[1])


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_fingers.clear()
		pinching = false
