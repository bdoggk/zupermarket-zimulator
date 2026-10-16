class_name Lantern
extends Decoration
## A candle lantern on a post (build mode). Like a gravestone it makes the
## store a bit more inviting, and it throws a warm pool of light around
## itself (Medium/High graphics; on High the candle flickers). Handy for
## the dark corners between the ceiling lights, and at night.

const COLOR := Color(1.0, 0.68, 0.32)
const ENERGY := 0.6
const FLAME := Vector2(0, -26)  # where the candle is, from the lantern's foot

var light: PointLight2D
var _t := 0.0
var _phase := 0.0


func _ready() -> void:
	light = PointLight2D.new()
	light.texture = StoreLights.glow_texture()
	light.texture_scale = 1.5
	light.scale = Vector2(1.0, 0.6)  # squashed to match the iso floor
	light.color = COLOR
	light.energy = ENERGY
	light.blend_mode = Light2D.BLEND_MODE_ADD
	light.position = FLAME + Vector2(0, 14)
	add_child(light)
	_phase = randf() * TAU
	Settings.changed.connect(_apply_settings)
	_apply_settings()


func _apply_settings() -> void:
	light.enabled = Settings.lights_enabled()
	light.energy = ENERGY
	queue_redraw()


func _process(delta: float) -> void:
	super._process(delta)
	if not Settings.effects_enabled() or not light.enabled:
		return
	_t += delta
	# a candle, not a bulb: a slow wobble with the odd quick flutter
	var wobble := sin(_t * 2.3 + _phase) * 0.06 + sin(_t * 7.1 + _phase * 2.0) * 0.04 + sin(_t * 13.7) * 0.02
	light.energy = ENERGY * (1.0 + wobble)


func _draw() -> void:
	super._draw()
	if not Settings.lights_enabled():
		return
	# a little halo around the flame so it reads as lit
	draw_circle(FLAME, 5.0, Color(1.0, 0.8, 0.45, 0.18))
	draw_circle(FLAME, 3.0, Color(1.0, 0.85, 0.5, 0.25))


func get_pick_rect() -> Rect2:
	return Rect2(-10, -48, 20, 56)
