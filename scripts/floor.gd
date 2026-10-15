class_name FloorLayer
extends Node2D
## Draws the floor tiles under everything else, plus the little diamond that
## flashes where you tap.

const MARKER_SECONDS := 0.6

var _tiles: Array = []  # [texture, top-left position, tint]
var _marker_cell := Vector2i.ZERO
var _marker_time := 0.0


func clear() -> void:
	_tiles.clear()
	queue_redraw()


func add_tile(tex: Texture2D, cell: Vector2i, tint := Color.WHITE) -> void:
	_tiles.append([tex, Iso.cell_to_world(cell) - Vector2(32, 16), tint])
	queue_redraw()


func show_marker(cell: Vector2i) -> void:
	_marker_cell = cell
	_marker_time = MARKER_SECONDS
	queue_redraw()


func _process(delta: float) -> void:
	if _marker_time > 0.0:
		_marker_time -= delta
		queue_redraw()


func _draw() -> void:
	for t in _tiles:
		draw_texture(t[0], t[1], t[2])
	if _marker_time > 0.0:
		var c := Iso.cell_to_world(_marker_cell)
		var pts := PackedVector2Array([
			c + Vector2(0, -16), c + Vector2(32, 0), c + Vector2(0, 16), c + Vector2(-32, 0), c + Vector2(0, -16),
		])
		draw_polyline(pts, Color(1, 1, 1, 0.8 * _marker_time / MARKER_SECONDS), 1.0)
