class_name StoreLights
extends Node2D
## Fluorescent store lighting and the day/night tint. What you get depends
## on Options > Graphics:
##   Low     no lights, just a tint at night (fastest)
##   Medium  pools of light from the ceiling lights, darker corners
##   High    the same, plus a flickering tube and dust floating in the air

const LIGHT_SPACING := Vector2i(4, 3)  # cells between ceiling lights
const DAY_AMBIENT: Color = Brand.LIGHT.day  # how dark it is away from lights
const NIGHT_AMBIENT: Color = Brand.LIGHT.night
const NO_LIGHTS_NIGHT: Color = Brand.LIGHT.plain_night
const LIGHT_COLOR: Color = Brand.LIGHT.lamp
const LIGHT_ENERGY := 0.36

var lights: Array[PointLight2D] = []
var flicker_light: PointLight2D
var dust: CPUParticles2D
var _flicker_timer := 3.0
var _flicker_steps := 0

@onready var store: Store = get_parent()


func _ready() -> void:
	Settings.changed.connect(_apply_settings)
	_build.call_deferred()  # after the store has built its floor


func _build() -> void:
	var tex := _light_texture()
	for cell: Vector2i in store.floor_cells:
		var inner := cell.x > 1 and cell.y > 1 and cell.x < store.width - 1 and cell.y < store.height - 1
		if inner and (cell.x - 2) % LIGHT_SPACING.x == 0 and (cell.y - 2) % LIGHT_SPACING.y == 0:
			var light := PointLight2D.new()
			light.texture = tex
			light.texture_scale = 2.0
			light.scale = Vector2(1.0, 0.6)  # squashed to match the iso floor
			light.color = LIGHT_COLOR
			light.energy = LIGHT_ENERGY
			light.blend_mode = Light2D.BLEND_MODE_ADD
			light.position = Iso.cell_to_world(cell) + Vector2(0, -8)
			add_child(light)
			lights.append(light)
	if not lights.is_empty():
		flicker_light = lights.pick_random()

	dust = CPUParticles2D.new()
	dust.amount = 50
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	var mid := (Iso.cell_to_world(Vector2i(0, store.height)) + Iso.cell_to_world(Vector2i(store.width, 0))) / 2.0
	dust.position = mid + Vector2(0, -40)
	dust.emission_rect_extents = Vector2(store.width * 22.0, store.height * 10.0)
	dust.direction = Vector2(0.3, -1.0)
	dust.spread = 60.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 1.0
	dust.initial_velocity_max = 4.0
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 1.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 0.97, 0.9, 0.35))
	fade.add_point(0.7, Color(1, 0.97, 0.9, 0.35))
	dust.color_ramp = fade
	add_child(dust)
	_apply_settings()


## A soft round glow.
func _light_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 0.45))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


func _apply_settings() -> void:
	for l in lights:
		l.enabled = Settings.lights_enabled()
		l.energy = LIGHT_ENERGY
	if dust:
		dust.emitting = Settings.effects_enabled()
		dust.visible = Settings.effects_enabled()


func _process(delta: float) -> void:
	var dusk := clampf((Game.minute - 17 * 60) / 180.0, 0.0, 1.0)
	if Settings.lights_enabled():
		store.mood.color = DAY_AMBIENT.lerp(NIGHT_AMBIENT, dusk)
	else:
		store.mood.color = Color.WHITE.lerp(NO_LIGHTS_NIGHT, dusk)
	if Settings.effects_enabled() and flicker_light:
		_flicker(delta)


## Every so often one tube stutters, like an old fluorescent light.
func _flicker(delta: float) -> void:
	_flicker_timer -= delta
	if _flicker_timer > 0.0:
		return
	if _flicker_steps <= 0:
		_flicker_steps = randi_range(3, 7)
	_flicker_steps -= 1
	flicker_light.energy = LIGHT_ENERGY * (0.15 if _flicker_steps % 2 == 0 else 1.0)
	_flicker_timer = randf_range(0.04, 0.12)
	if _flicker_steps == 0:
		flicker_light.energy = LIGHT_ENERGY
		_flicker_timer = randf_range(4.0, 12.0)
