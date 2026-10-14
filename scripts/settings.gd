extends Node
## Player settings from the Options menu. Registered as the "Settings"
## autoload and saved to user://settings.cfg.
##
##   Display mode / Resolution   PC only (phones always use the full screen)
##   Graphics                    Low / Medium / High (see GRAPHICS_INFO)
##   VSync                       on/off
##   Vibration                   phone and controller rumble, when available

signal changed

const PATH := "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3200, 1800), Vector2i(3840, 2160),
]
const MIN_WINDOW := Vector2i(960, 540)

enum Graphics { LOW, MEDIUM, HIGH }
const GRAPHICS_NAMES := ["Low", "Medium", "High"]
const GRAPHICS_INFO := [
	"Simple lighting, 30 FPS. Best for older phones and battery life.",
	"Store lights and soft shadows, up to 60 FPS.",
	"Store lights with flicker and floating dust, no FPS limit.",
]
const MAX_FPS := [30, 60, 0]  # 0 = no limit

var fullscreen := false
var resolution := Vector2i(1280, 720)
var graphics := Graphics.HIGH
var vsync := true
var vibration := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if is_mobile():
		graphics = Graphics.MEDIUM
	load_settings()
	apply()
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool): changed.emit())


## Phones and tablets: no window or resolution options.
func is_mobile() -> bool:
	return OS.has_feature("mobile")


func is_desktop() -> bool:
	return not is_mobile() and not OS.has_feature("web")


## Window sizes that fit on this screen.
func available_resolutions() -> Array[Vector2i]:
	var screen := DisplayServer.screen_get_usable_rect().size
	var list: Array[Vector2i] = []
	for r in RESOLUTIONS:
		if r.x <= screen.x and r.y <= screen.y:
			list.append(r)
	if list.is_empty():
		list.append(RESOLUTIONS[0])
	if not resolution in list:
		list.append(resolution)
		list.sort_custom(func(a, b): return a.x * a.y < b.x * b.y)
	return list


## Phone vibration, or a connected controller that can rumble.
func can_vibrate() -> bool:
	return is_mobile() or not Input.get_connected_joypads().is_empty()


func lights_enabled() -> bool:
	return graphics >= Graphics.MEDIUM


func effects_enabled() -> bool:
	return graphics == Graphics.HIGH


## Applies everything to the window and engine.
func apply() -> void:
	if is_desktop() and DisplayServer.get_name() != "headless":
		var win := get_window()
		win.min_size = MIN_WINDOW
		if fullscreen:
			win.mode = Window.MODE_FULLSCREEN
		else:
			if win.mode != Window.MODE_WINDOWED:
				win.mode = Window.MODE_WINDOWED
			win.size = resolution
			win.move_to_center()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = MAX_FPS[graphics]
	changed.emit()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_save_and_apply()


func set_resolution(r: Vector2i) -> void:
	resolution = r
	_save_and_apply()


func set_graphics(g: Graphics) -> void:
	graphics = g
	_save_and_apply()


func set_vsync(on: bool) -> void:
	vsync = on
	_save_and_apply()


func set_vibration(on: bool) -> void:
	vibration = on
	save_settings()
	changed.emit()
	if on:
		vibrate(0.6, 0.15)  # let them feel it


## Rumbles the phone and any connected controllers (if vibration is on).
## strength 0-1, duration in seconds.
func vibrate(strength := 0.5, duration := 0.08) -> void:
	if not vibration:
		return
	if is_mobile():
		Input.vibrate_handheld(int(duration * 1000.0), strength)
	for pad in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, strength * 0.7, strength, duration)


func _save_and_apply() -> void:
	save_settings()
	apply()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "resolution", resolution)
	cfg.set_value("display", "graphics", graphics)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("controls", "vibration", vibration)
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	var r: Variant = cfg.get_value("display", "resolution", resolution)
	if r is Vector2i:
		resolution = r
	graphics = clampi(int(cfg.get_value("display", "graphics", graphics)), 0, 2) as Graphics
	vsync = bool(cfg.get_value("display", "vsync", vsync))
	vibration = bool(cfg.get_value("controls", "vibration", vibration))
