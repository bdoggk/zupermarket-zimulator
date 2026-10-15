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


## Area (in local pixels) you can tap or click to select this object.
func get_pick_rect() -> Rect2:
	return Rect2(-28, -40, 56, 52)


func _process(_delta: float) -> void:
	var b := 1.3 if highlighted else 1.0
	var a := 0.4 if cutaway else 1.0
	modulate = Color(b, b, b, a)


## Draws a sprite made by tools/make_sprites.py so its floor footprint sits
## on this node's position.
func draw_object_sprite(tex: Texture2D) -> void:
	draw_texture(tex, Vector2(-32, -(tex.get_height() - 16)))
