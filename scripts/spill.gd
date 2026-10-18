class_name Spill
extends Interactable
## A puddle of blood a zombie left on the floor (only in the zombie game,
## see Brand.SPILLS). A fresh one (wet and shiny) doesn't bother anyone yet;
## once it's been there for Store.SPILL_SETTLE_MINUTES of open time it puts
## shoppers off (Store.mess_multiplier). Every puddle costs XP while you're
## open. Grab the mop from the mop bucket and mop it up.

const TEXTURES := [
	preload("res://assets/sprites/spill_0.png"),
	preload("res://assets/sprites/spill_1.png"),
	preload("res://assets/sprites/spill_2.png"),
]
const MOP_SECONDS := 1.0

var variant := 0
var age := 0.0  # seconds it's been on the floor while the store was open


func _draw() -> void:
	draw_texture(TEXTURES[variant], Vector2(-32, -16))


func get_prompt(p: Player) -> String:
	if p.holding_mop:
		return "Mop up the blood"
	return "Blood on the floor! Grab the mop"


func can_interact(p: Player) -> bool:
	return p.holding_mop


## With the mop in hand, mopping is what you're there for.
func use_priority(_p: Player) -> int:
	return 2


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


## Been there long enough to put shoppers off.
func is_settled() -> bool:
	return age >= Store.spill_settle_seconds()


func _process(delta: float) -> void:
	if Game.is_open:
		age += delta
	var wet := 1.0 - clampf(age / Store.spill_settle_seconds(), 0.0, 1.0)  # fresh blood shines, then dries darker
	var b := 1.25 if highlighted else 1.0
	modulate = Color(b * (1.0 + 0.45 * wet), b * (1.0 + 0.15 * wet), b * (1.0 + 0.15 * wet))
