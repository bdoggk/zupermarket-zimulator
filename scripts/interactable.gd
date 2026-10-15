class_name Interactable
extends Node2D
## Base class for everything the player can use: shelves, fridges, boxes,
## the register and the computer. Override the methods below in a subclass.

var cell := Vector2i.ZERO
## Set for furniture you can move and sell in build mode (a key of
## Game.FURNITURE). Empty for fixed things like the register.
var furniture_id := ""
var highlighted := false  # the player is close and this is what E will use
var cutaway := false  # the player is hidden behind this, so fade it out
## Which way it faces; build mode turns it a quarter turn at a time (R).
## 0 = its front faces the bottom left of the screen, 1 = bottom right,
## 2 = top right (you see its back), 3 = top left. See FACINGS.
var rotation_step := 0

## The grid direction the front faces for each rotation_step.
const FACINGS: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
static var _views := {}  # texture -> how to draw it each way (see view_of)


## Text shown to the player, e.g. "Stock Canned Beans". "" = nothing to say.
func get_prompt(_player: Player) -> String:
	return ""


## True if pressing E right now would do something.
func can_interact(_player: Player) -> bool:
	return false


## When several things nearby can be used, the highest priority wins (then
## the closest). Things you'd rarely want to do by accident return 0.
func use_priority(_player: Player) -> int:
	return 1


## How long the action takes in seconds (0 = instant). While it runs the
## player stands still and a progress bar fills, like Project Zomboid.
func get_action_time(_player: Player) -> float:
	return 0.0


## Shown while the timed action runs, e.g. "Stocking...".
func get_action_label(_player: Player) -> String:
	return "Working..."


## Called when the action finishes.
func interact(_player: Player) -> void:
	pass


# The handheld scanner (Q / the SCAN button) uses these.

func get_scan_prompt(_player: Player) -> String:
	return ""


func can_scan(_player: Player) -> bool:
	return false


func get_scan_time(_player: Player) -> float:
	return 0.6


func scan(_player: Player) -> void:
	pass


# Build mode uses these.

## Can be picked up with the Move tool.
func is_movable() -> bool:
	return furniture_id != ""


## Can be sold for half price (the register, computer and sign can't).
func is_sellable() -> bool:
	return furniture_id != ""


## The sprite shown under the cursor while moving or buying this.
func ghost_texture() -> Texture2D:
	return Game.FURNITURE[furniture_id].texture if furniture_id != "" else null


## What to call this in build mode messages, e.g. "register".
func display_name() -> String:
	return Game.FURNITURE[furniture_id].name.to_lower() if furniture_id != "" else "thing"


## Build mode's Rotate tool can turn it (anything you can move).
func can_rotate() -> bool:
	return is_movable()


func facing_dir() -> Vector2i:
	return FACINGS[rotation_step]


## True when you can see its front (it isn't turned away from you).
func shows_front() -> bool:
	return rotation_step < 2


## True when it's drawn mirrored (turned to face the right of the screen).
func mirrored() -> bool:
	return rotation_step % 2 == 1


## x of something `width` wide drawn at local x `x` on the front view,
## after mirroring.
func mirror_x(x: float, width := 0.0) -> float:
	return -x - width if mirrored() else x


## Area (in local pixels) you can tap or click to select this object.
func get_pick_rect() -> Rect2:
	return Rect2(-28, -40, 56, 52)


func _process(_delta: float) -> void:
	var b := 1.3 if highlighted else 1.0
	var a := 0.4 if cutaway else 1.0
	modulate = Color(b, b, b, a)


## Draws a sprite made by tools/make_sprites.py so its floor footprint sits
## on this node's position, turned the way it faces.
func draw_object_sprite(tex: Texture2D) -> void:
	draw_view(self, tex, rotation_step, Vector2.ZERO)


## Draws `tex` turned to `step` with its floor footprint centered on `at`
## (build mode uses this for the ghost under the cursor).
static func draw_view(canvas: CanvasItem, tex: Texture2D, step: int, at: Vector2, color := Color.WHITE) -> void:
	var view := view_of(tex, step)
	var t: Texture2D = view[0]
	var corner := Vector2(-32, -(t.get_height() - 16))
	if view[1]:
		canvas.draw_set_transform(at, 0.0, Vector2(-1, 1))
		canvas.draw_texture(t, corner, color)
		canvas.draw_set_transform(Vector2.ZERO)
	else:
		canvas.draw_texture(t, at + corner, color)


## How to draw `tex` facing `step`: [texture, mirrored]. Sprites come with
## a front view (the texture itself) and maybe a back view (name_back.png);
## the other two directions are those mirrored. A sprite that mustn't be
## mirrored (the sign's lettering) has its own name_r1.png (and _r2/_r3).
static func view_of(tex: Texture2D, step: int) -> Array:
	if tex == null:
		return [null, false]
	if not _views.has(tex):
		var base := tex.resource_path.get_basename()
		var r1 := _load_if(base + "_r1.png")
		var r2 := _load_if(base + "_r2.png")
		var r3 := _load_if(base + "_r3.png")
		var back := _load_if(base + "_back.png")
		var v := [[tex, false]]
		v.append([r1, false] if r1 else [tex, true])
		v.append([r2, false] if r2 else ([back, false] if back else [tex, false]))
		if r3:
			v.append([r3, false])
		elif back:
			v.append([back, true])
		else:
			v.append([r1, false] if r1 else [tex, true])
		_views[tex] = v
	return _views[tex][posmod(step, 4)]


static func _load_if(path: String) -> Texture2D:
	return load(path) if path.begins_with("res://") and ResourceLoader.exists(path) else null
