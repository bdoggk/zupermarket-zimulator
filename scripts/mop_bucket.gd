class_name MopBucket
extends Interactable
## Where the mop lives (zombie game). Use it to grab the mop, then use a
## blood spill to clean it up. Put the mop back when you're done: you can't
## carry boxes while you're holding it. You can move the bucket in build mode.

const FULL := preload("res://assets/sprites/mop_bucket.png")
const EMPTY := preload("res://assets/sprites/mop_bucket_empty.png")
const GRAB_SECONDS := 0.3


func _draw() -> void:
	var taken: bool = Game.player != null and Game.player.holding_mop
	draw_object_sprite(EMPTY if taken else FULL)


func _process(delta: float) -> void:
	super._process(delta)
	queue_redraw()


func get_prompt(p: Player) -> String:
	if p.holding_mop:
		return "Put the mop back"
	if p.is_carrying():
		return "Put the box down to grab the mop"
	return "Grab the mop"


func can_interact(p: Player) -> bool:
	return p.holding_mop or not p.is_carrying()


func get_action_time(_p: Player) -> float:
	return GRAB_SECONDS


func get_action_label(p: Player) -> String:
	return "Putting the mop back..." if p.holding_mop else "Grabbing the mop..."


func interact(p: Player) -> void:
	p.set_holding_mop(not p.holding_mop)


func is_movable() -> bool:
	return true


func ghost_texture() -> Texture2D:
	return FULL


func display_name() -> String:
	return "mop bucket"


func get_pick_rect() -> Rect2:
	return Rect2(-20, -52, 40, 62)
