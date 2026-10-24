class_name OpenSign
extends Interactable
## The OPEN / CLOSED sign by the front door. Every day starts with the
## store closed and the clock stopped, so you can stock shelves, order and
## build first. Flip the sign to open: the clock starts and customers come in.
## At 8 PM it flips back to CLOSED by itself.

const OPEN_TEX := preload("res://assets/sprites/sign_open.png")
const CLOSED_TEX := preload("res://assets/sprites/sign_closed.png")
const FLIP_SECONDS := 0.4

var _t := 0.0
var _glow: PointLight2D


func _ready() -> void:
	_glow = PointLight2D.new()  # a little colored glow (Medium graphics and up)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	_glow.texture = tex
	_glow.texture_scale = 1.3
	_glow.energy = 0.5
	_glow.blend_mode = Light2D.BLEND_MODE_ADD
	_glow.position = Vector2(0, -20)
	add_child(_glow)


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	_glow.enabled = Settings.lights_enabled()
	_glow.color = Color(0.5, 1.0, 0.5) if Game.is_open else Color(1.0, 0.4, 0.35)
	queue_redraw()


func _draw() -> void:
	draw_object_sprite(OPEN_TEX if Game.is_open else CLOSED_TEX)
	if waiting():
		# a bouncing arrow so you can't miss it in the morning
		var y := -50.0 - absf(sin(_t * 4.0)) * 5.0
		var pts := PackedVector2Array([Vector2(-5, y), Vector2(5, y), Vector2(0, y + 6)])
		draw_colored_polygon(pts, Color(1.0, 0.85, 0.3))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0.15, 0.12, 0.1), 1.0)


func is_movable() -> bool:
	return true


func ghost_texture() -> Texture2D:
	return CLOSED_TEX


func display_name() -> String:
	return "sign"


## True in the morning, before the store has opened.
func waiting() -> bool:
	return not Game.opened and not Game.day_over


func get_prompt(_p: Player) -> String:
	if waiting():
		return "Open the store (start Day %d)" % Game.day
	if Game.is_open:
		return "Open until 8 PM"
	return "Closed for the day"


func can_interact(_p: Player) -> bool:
	return waiting()


func get_action_time(_p: Player) -> float:
	return FLIP_SECONDS


func get_action_label(_p: Player) -> String:
	return "Flipping the sign..."


func interact(_p: Player) -> void:
	if waiting():
		Game.open_store()


func get_pick_rect() -> Rect2:
	return Rect2(-20, -44, 40, 48)


func fp_texture() -> Texture2D:
	return OPEN_TEX if Game.is_open else CLOSED_TEX
