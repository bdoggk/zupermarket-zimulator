class_name Iso
## Helpers for the 2:1 isometric grid. One floor cell is a 64x32 diamond.
##
## Cell (x, y) means column x / row y of the store map in store.gd.
## On screen, +x goes down-right and +y goes down-left.

const TILE_W := 64
const TILE_H := 32


## Center of a cell in world (screen) pixels.
static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x - cell.y) * TILE_W * 0.5, (cell.x + cell.y) * TILE_H * 0.5)


## Which cell a world position is in.
static func world_to_cell(pos: Vector2) -> Vector2i:
	var a := pos.x / (TILE_W * 0.5)
	var b := pos.y / (TILE_H * 0.5)
	return Vector2i(roundi((a + b) * 0.5), roundi((b - a) * 0.5))


## How many cells long a screen-space vector is.
static func cell_length(v: Vector2) -> float:
	var a := v.x / (TILE_W * 0.5)
	var b := v.y / (TILE_H * 0.5)
	return Vector2((a + b) * 0.5, (b - a) * 0.5).length()


## Screen-space velocity that covers `cells_per_second` cells per second in
## screen direction `dir`. Keeps walking speed the same in every direction.
static func velocity_toward(dir: Vector2, cells_per_second: float) -> Vector2:
	if dir.is_zero_approx():
		return Vector2.ZERO
	var n := dir.normalized()
	return n * (cells_per_second / cell_length(n))


## Screen-space velocity in screen direction `dir` that's as fast on screen
## whichever way you go: walking up or down the screen is as quick as
## walking left or right (`cells_per_second` is the left/right speed). The
## player moves like this; everyone else keeps to velocity_toward.
static func even_velocity(dir: Vector2, cells_per_second: float) -> Vector2:
	if dir.is_zero_approx():
		return Vector2.ZERO
	return dir.normalized() * (cells_per_second / cell_length(Vector2.RIGHT))


## Grid distance between two cells (diagonal steps count as one).
static func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))
