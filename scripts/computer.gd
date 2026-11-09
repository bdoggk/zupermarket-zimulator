class_name Computer
extends Interactable
## The back-office PC: order stock, set prices, buy product licenses and
## upgrades. The store's fuse box is on the wall beside it: in a power cut
## (0.19) it sparks, and using the computer fixes the fuse box instead.

const TEXTURE := preload("res://assets/sprites/computer.png")
const FIX_SECONDS := 3.0  # fixing the fuse box
const FUSE_AT := Vector2(18, -60)  # the fuse box, beside the screen
const FUSE_GLOW := Color(1.9, 1.9, 1.7)  # (drawn brighter than the dimmed store, so you can find it)


func _draw() -> void:
	draw_object_sprite(TEXTURE)
	if Game.calendar.power_out:
		var t := Time.get_ticks_msec() / 1000.0
		var sparks: Texture2D = Brand.FUSE_BOX[1] if fmod(t, 0.5) < 0.25 else Brand.FUSE_BOX[0]
		var size := sparks.get_size() * 1.5
		draw_texture_rect(sparks, Rect2(FUSE_AT - size / 2.0, size), false, FUSE_GLOW)
		var bob := roundf(sin(t * 5.0) * 2.0)
		draw_string(ThemeDB.fallback_font, FUSE_AT + Vector2(-4, -size.y / 2.0 - 6 + bob), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(2.0, 0.6, 0.4))


func _process(delta: float) -> void:
	super._process(delta)
	if Game.calendar.power_out:
		queue_redraw()  # (the sparks)


func is_movable() -> bool:
	return true


func ghost_texture() -> Texture2D:
	return TEXTURE


func display_name() -> String:
	return "computer"


func get_prompt(_p: Player) -> String:
	return "Fix the fuse box (the power's out)" if Game.calendar.power_out else "Use computer"


func use_priority(_p: Player) -> int:
	return 6 if Game.calendar.power_out else 1  # (the most important thing in the store right now)


func get_action_time(_p: Player) -> float:
	return FIX_SECONDS if Game.calendar.power_out else 0.0


func get_action_label(_p: Player) -> String:
	return "Fixing the fuse box..."


func can_interact(_p: Player) -> bool:
	return true


func interact(_p: Player) -> void:
	if Game.calendar.power_out:
		if Game.in_game() and Game.store.events:
			Game.store.events.fix_power()
		queue_redraw()
		return
	Game.computer_requested.emit()


func get_pick_rect() -> Rect2:
	return Rect2(-28, -50, 56, 64)


func fp_texture() -> Texture2D:
	return TEXTURE
