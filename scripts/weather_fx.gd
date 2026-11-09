class_name WeatherFx
extends CanvasLayer
## Today's weather on screen (0.19, Calendar): rain streaking down, or fog
## drifting across. It sits over the world (the normal view and first
## person) and under the HUD. A heat wave and a power cut are tints on the
## store's light instead (StoreLights). Lighter with Options > Graphics on
## Low.

const DROPS := 150  # raindrops on a 1920x1080 screen (fewer on a smaller one)
const DROP_SPEED := Vector2(-160.0, 900.0)  # pixels per second (slanting a little)
const DROP_LENGTH := 0.022  # seconds of fall each streak shows
const RAIN_COLOR := Color(0.8, 0.86, 0.96, 0.5)
const FOG_ALPHA := 0.32
const FOG_DRIFT := Vector2(14.0, 3.0)  # pixels per second
const FOG_SCALE := 3.0  # the fog texture drawn this many times bigger

var weather := ""
var _drops: PackedVector2Array = PackedVector2Array()
var _fog: Texture2D
var _t := 0.0
var _canvas: Control


func _init() -> void:
	layer = 1  # (the HUD is on layer 1 too, after this in the tree: on top)


func _ready() -> void:
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_weather)
	add_child(_canvas)


func _process(delta: float) -> void:
	_t += delta
	var w := Game.calendar.weather() if Game.in_game() else "clear"
	if w != weather:
		weather = w
		_drops.clear()
		if weather == "fog" and _fog == null:
			_fog = _make_fog()
	visible = weather in ["rain", "fog"]
	if not visible:
		return
	var s := _canvas.size
	if weather == "rain":
		var want := int(DROPS * (s.x * s.y) / (1920.0 * 1080.0) * (1.0 if Settings.effects_enabled() else 0.5))
		while _drops.size() < want:
			_drops.append(Vector2(randf() * s.x, randf() * s.y))
		if _drops.size() > want:
			_drops.resize(want)
		for i in _drops.size():
			var p := _drops[i] + DROP_SPEED * delta * (0.85 + 0.3 * float(i % 7) / 6.0)
			if p.y > s.y + 20.0:
				p = Vector2(randf() * (s.x + 200.0), -20.0)
			if p.x < -20.0:
				p.x += s.x + 40.0
			_drops[i] = p
	_canvas.queue_redraw()


func _draw_weather() -> void:
	match weather:
		"rain":
			var streak := DROP_SPEED * DROP_LENGTH
			for p in _drops:
				_canvas.draw_line(p, p + streak, RAIN_COLOR, 1.5)
		"fog":
			if _fog:
				var tile := _fog.get_size()
				for i in 2:  # two layers drifting at different speeds and sizes
					var k := FOG_SCALE * (1.0 if i == 0 else 0.6)
					var screen := _canvas.size / k  # (in the fog's own pixels)
					var drift := FOG_DRIFT * _t * (1.0 + 0.6 * i) / k
					var off := Vector2(fposmod(drift.x, tile.x), fposmod(drift.y, tile.y)) - tile
					_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
					_canvas.draw_texture_rect(_fog, Rect2(off, screen + tile * 2.0), true, Color(0.86, 0.89, 0.92, FOG_ALPHA * (0.6 if i == 0 else 0.45)))
				_canvas.draw_set_transform(Vector2.ZERO)


## A soft, seamless cloud of fog (white where it's thick, clear between).
static func _make_fog() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	noise.seed = 19
	var img := noise.get_seamless_image(256, 256)
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var v := img.get_pixel(x, y).r
			img.set_pixel(x, y, Color(1, 1, 1, clampf((v - 0.35) * 1.8, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
