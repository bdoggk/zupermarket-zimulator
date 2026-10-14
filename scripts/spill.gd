class_name Spill
extends Interactable
## A puddle of blood a zombie left on the floor (only in the zombie game,
## see Brand.SPILLS). Every spill makes the store a bit less appealing, so
## fewer shoppers come in. Grab the mop from the mop bucket and mop it up.

const TEXTURES := [
	preload("res://assets/sprites/spill_0.png"),
	preload("res://assets/sprites/spill_1.png"),
	preload("res://assets/sprites/spill_2.png"),
]
const MOP_SECONDS := 1.0

var variant := 0


func _draw() -> void:
	draw_texture(TEXTURES[variant], Vector2(-32, -16))


func get_prompt(p: Player) -> String:
	if p.holding_mop:
		return "Mop up the blood"
	return "Blood on the floor! Grab the mop"


func can_interact(p: Player) -> bool:
	return p.holding_mop


func get_action_time(_p: Player) -> float:
	return MOP_SECONDS


func get_action_label(_p: Player) -> String:
	return "Mopping..."


func interact(_p: Player) -> void:
	Game.record_spill_cleaned()
	Game.show_popup(position + Vector2(0, -20), "Clean!", Color(0.7, 0.9, 1.0))
	Settings.vibrate(0.2, 0.04)
	Game.store.remove_spill(self)


func get_pick_rect() -> Rect2:
	return Rect2(-22, -11, 44, 22)


func _process(_delta: float) -> void:
	modulate = Color(1.25, 1.25, 1.25) if highlighted else Color.WHITE
