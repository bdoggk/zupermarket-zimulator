class_name Prop
extends Interactable
## Scenery in the town: dead trees, wrecked cars, street lamps, ruins,
## fences... They just stand there and block the way. Some glow (lamps,
## burning barrels) and some have something to say when you walk up.

var textures: Array[Texture2D] = []  # drawn in order, all at the same spot
## Where this node's position is in the textures. By default that's the
## center of the floor tile, 16 px above the bottom like every object sprite.
var origin := Vector2(-1, -1)
var prompt := ""
var prompt_fn := Callable()  # if set, says something that can change (e.g. a price)
var tall := false  # fades out when you walk behind it
var light: PointLight2D
var flicker := false
var _t := randf() * 10.0


func _init(texs: Array = [], text := "") -> void:
	for t in texs:
		textures.append(t)
	prompt = text


func _ready() -> void:
	if origin.x < 0.0 and not textures.is_empty():
		origin = Vector2(32, textures[0].get_height() - 16)


func _draw() -> void:
	for t in textures:
		draw_texture(t, -origin)


func _process(delta: float) -> void:
	super._process(delta)
	if flicker and light and light.enabled:
		_t += delta
		light.energy = light.get_meta("energy", 0.5) * (0.85 + 0.15 * sin(_t * 13.0) * sin(_t * 7.3))


## Adds a pool of light on the ground (lamps, fires). `at` is relative to
## the prop, `scale_by` stretches the glow.
func add_light(color: Color, at: Vector2, energy: float, scale_by: float) -> PointLight2D:
	light = PointLight2D.new()
	light.texture = StoreLights.glow_texture()
	light.texture_scale = scale_by
	light.scale = Vector2(1.0, 0.6)
	light.color = color
	light.energy = energy
	light.set_meta("energy", energy)
	light.blend_mode = Light2D.BLEND_MODE_ADD
	light.position = at
	add_child(light)
	return light


func get_prompt(_p: Player) -> String:
	return prompt_fn.call() if prompt_fn.is_valid() else prompt


func is_movable() -> bool:
	return false


func is_sellable() -> bool:
	return false


func get_pick_rect() -> Rect2:
	return Rect2()  # tapping scenery just walks you there


## First person: every texture, drawn where the normal view draws it.
func look_3d() -> Array:
	return textures.map(func(t): return [t, -origin, false])
