extends Node
## Player settings from the Options menu. Registered as the "Settings"
## autoload and saved to user://settings.cfg.
##
##   Display       PC only: a window, fullscreen, or exclusive fullscreen
##                 (the game takes the screen over; usually the most FPS on
##                 Windows). Phones always use the full screen.
##   Window size   PC, in a window. Dragging the window's edges or
##                 maximizing it works too, and the game remembers.
##   Frame rate    a cap on the frames per second (or none)
##   Graphics      Low / Medium / High / Ray tracing (see GRAPHICS_INFO);
##                 PC starts on Ray tracing, phones on Medium
##   First person  Sharp (full resolution, PC's default) or Chunky (half
##                 resolution, big pixels; phones' default)
##   UI size       how big the menus, buttons and text are (UI_SCALES); the
##                 store itself stays the same size (see UI.fit_layer)
##   VSync         on/off (on: the frame rate matches the screen)
##   Show FPS      a frame counter in the corner
##   Sound         how loud the game is (Off to 100%)
##   Vibration     phone and controller rumble, when available
##   Automatic updates  Windows: download and install new versions by
##                 itself; Android: say when one is out (see Updater)

signal changed

const PATH := "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3200, 1800), Vector2i(3840, 2160),
]
const FIT_SCREEN := Vector2i.ZERO  # as a window size: maximized, filling the screen
const MIN_WINDOW := Vector2i(960, 540)

enum Display { WINDOWED, FULLSCREEN, EXCLUSIVE }
const DISPLAY_NAMES := ["Windowed", "Fullscreen", "Exclusive fullscreen"]
const DISPLAY_INFO := [
	"Drag the window's edges or maximize it to resize it too.",
	"Fills the screen at your screen's resolution.",
	"Takes over the whole screen. Usually the highest frame rate on Windows.",
]

const FPS_LIMITS := [30, 60, 90, 120, 144, 165, 240, 0]  # 0 = no limit
const UI_SCALES := [0.7, 0.8, 0.9, 1.0, 1.1, 1.2, 1.3]
const UI_MIN_ROOM := Vector2(960, 540)  # the UI needs this much room (in its own units) to fit, so big sizes stop there

enum Graphics { LOW, MEDIUM, HIGH, RAY_TRACING }
const GRAPHICS_NAMES := ["Low", "Medium", "High", "Ray tracing"]
const GRAPHICS_INFO := [
	"Simple lighting. Best for older phones and battery life.",
	"Store lights and soft shadows.",
	"Store lights with flicker and floating dust.",
	"Every light casts real shadows: shelves, walls, people. Needs a good graphics card.",
]

var display := Display.WINDOWED
var resolution := Vector2i(1280, 720)  # the window's size (FIT_SCREEN = maximized)
var fps_limit := 0
var graphics := Graphics.RAY_TRACING
var vsync := true
var show_fps := false
var volume := 0.75  # 0-1, for the whole game
var vibration := true
var ui_scale := 1.0
var auto_update := true
var first_person := false  # the store in first person (V); remembered for next time
var fp_sharp := true  # first person at full resolution (else half: chunky pixels)

var _applying := false  # we're resizing the window ourselves
var _save_queued := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if is_mobile():
		graphics = Graphics.MEDIUM
		fps_limit = 60
		fp_sharp = false
	load_settings()
	apply()
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool):
		if Input.get_connected_joypads().is_empty():
			UI.pad_seen = false
		changed.emit())
	if is_desktop():
		get_window().size_changed.connect(_on_window_resized)


## A controller button or stick: there's a controller, even if the system
## hasn't listed it (built-in controls on some handhelds), see UI.has_pad.
func _input(event: InputEvent) -> void:
	if not UI.pad_seen and UI.is_pad_input(event):
		UI.pad_seen = true


## Phones and tablets: no window or resolution options.
func is_mobile() -> bool:
	return OS.has_feature("mobile")


func is_desktop() -> bool:
	return not is_mobile() and not OS.has_feature("web")


func is_fullscreen() -> bool:
	return display != Display.WINDOWED


## Window sizes that fit on this screen, then FIT_SCREEN (maximized). A size
## you got by dragging the window's edges is in the list too.
func available_resolutions() -> Array[Vector2i]:
	var screen := DisplayServer.screen_get_usable_rect().size
	var list: Array[Vector2i] = []
	for r in RESOLUTIONS:
		if r.x <= screen.x and r.y <= screen.y:
			list.append(r)
	if list.is_empty():
		list.append(RESOLUTIONS[0])
	if resolution != FIT_SCREEN and not resolution in list:
		list.append(resolution)
		list.sort_custom(func(a, b): return a.x * a.y < b.x * b.y)
	list.append(FIT_SCREEN)
	return list


static func resolution_name(r: Vector2i) -> String:
	return "Fill the screen" if r == FIT_SCREEN else "%d x %d" % [r.x, r.y]


static func fps_name(limit: int) -> String:
	return "No limit" if limit <= 0 else "%d FPS" % limit


static func ui_scale_name(v: float) -> String:
	return "%d%%" % roundi(v * 100.0)


## The biggest UI size this window has room for (at least 100%).
func max_ui_scale() -> float:
	var room: Vector2 = get_viewport().get_visible_rect().size
	return maxf(1.0, minf(room.x / UI_MIN_ROOM.x, room.y / UI_MIN_ROOM.y))


## The UI sizes to choose from in Options (the ones that fit this window).
func available_ui_scales() -> Array:
	var most := max_ui_scale() + 0.001
	return UI_SCALES.filter(func(k: float): return k <= most)


## The UI size actually used: the setting, or the biggest that fits.
func effective_ui_scale() -> float:
	return clampf(ui_scale, 0.5, max_ui_scale())


func set_ui_scale(v: float) -> void:
	ui_scale = clampf(snappedf(v, 0.05), 0.5, 2.0)
	save_settings()
	changed.emit()


static func volume_name(v: float) -> String:
	return "Off" if v <= 0.0 else "%d%%" % roundi(v * 100.0)


## Phone vibration, or a connected controller that can rumble.
func can_vibrate() -> bool:
	return is_mobile() or not Input.get_connected_joypads().is_empty()


func lights_enabled() -> bool:
	return graphics >= Graphics.MEDIUM


func effects_enabled() -> bool:
	return graphics >= Graphics.HIGH


## Shadows from every light (see RayTracer).
func ray_tracing() -> bool:
	return graphics == Graphics.RAY_TRACING


## What VSync does to the frame rate on this screen.
func vsync_info() -> String:
	var hz := roundi(DisplayServer.screen_get_refresh_rate())
	if not vsync:
		return "Off: as many FPS as your computer can do (the picture may tear a little)."
	if hz > 0:
		return "On: the frame rate matches your screen (%d Hz). Turn it off for more FPS." % hz
	return "On: the frame rate matches your screen. Turn it off for more FPS."


## Applies everything to the window and engine.
func apply() -> void:
	if is_desktop() and DisplayServer.get_name() != "headless":
		_applying = true
		var win := get_window()
		win.min_size = MIN_WINDOW
		match display:
			Display.FULLSCREEN:
				win.mode = Window.MODE_FULLSCREEN
			Display.EXCLUSIVE:
				win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
			_:
				var usable := DisplayServer.screen_get_usable_rect(win.current_screen).size
				if resolution == FIT_SCREEN or resolution.x > usable.x or resolution.y > usable.y:
					win.mode = Window.MODE_MAXIMIZED  # fills the screen, title bar and all
				else:
					if win.mode != Window.MODE_WINDOWED:
						win.mode = Window.MODE_WINDOWED
					win.size = resolution
					win.move_to_center()
		_applying = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = fps_limit
	AudioServer.set_bus_mute(0, volume <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
	changed.emit()


## You dragged the window's edges or maximized it: remember that size.
func _on_window_resized() -> void:
	if _applying or display != Display.WINDOWED:
		return
	var win := get_window()
	var now := resolution
	if win.mode == Window.MODE_MAXIMIZED:
		now = FIT_SCREEN
	elif win.mode == Window.MODE_WINDOWED:
		now = win.size
	if now != resolution:
		resolution = now
		changed.emit()
		_save_soon()


func _save_soon() -> void:
	if _save_queued:
		return
	_save_queued = true
	await get_tree().create_timer(0.5, true, false, true).timeout
	_save_queued = false
	save_settings()


func set_display(d: Display) -> void:
	display = d
	_save_and_apply()


func set_fullscreen(on: bool) -> void:
	set_display(Display.FULLSCREEN if on else Display.WINDOWED)


func set_resolution(r: Vector2i) -> void:
	resolution = r
	_save_and_apply()


func set_fps_limit(limit: int) -> void:
	fps_limit = maxi(0, limit)
	_save_and_apply()


func set_graphics(g: Graphics) -> void:
	graphics = g
	_save_and_apply()


func set_vsync(on: bool) -> void:
	vsync = on
	_save_and_apply()


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	_save_and_apply()


func set_show_fps(on: bool) -> void:
	show_fps = on
	save_settings()
	changed.emit()


func set_auto_update(on: bool) -> void:
	auto_update = on
	save_settings()
	changed.emit()
	if on:
		Updater.check()


func set_fp_sharp(on: bool) -> void:
	fp_sharp = on
	save_settings()
	changed.emit()


func fp_sharp_info() -> String:
	if fp_sharp:
		return "Sharp: the 3D view at full resolution."
	return "Chunky: half resolution, with big pixels like the art. Faster on phones."


func set_first_person(on: bool) -> void:
	if first_person == on:
		return
	first_person = on
	save_settings()


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
	cfg.set_value("display", "mode", display)
	cfg.set_value("display", "fullscreen", display != Display.WINDOWED)  # for older versions
	cfg.set_value("display", "resolution", resolution)
	cfg.set_value("display", "fps_limit", fps_limit)
	cfg.set_value("display", "graphics", graphics)
	cfg.set_value("display", "ray_tracing_offered", true)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("display", "show_fps", show_fps)
	cfg.set_value("display", "ui_scale", ui_scale)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("controls", "vibration", vibration)
	cfg.set_value("updates", "automatic", auto_update)
	cfg.set_value("view", "first_person", first_person)
	cfg.set_value("view", "fp_sharp", fp_sharp)
	cfg.save(PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	if cfg.has_section_key("display", "mode"):
		display = clampi(int(cfg.get_value("display", "mode", 0)), 0, 2) as Display
	else:  # settings from before 0.8.3
		display = Display.FULLSCREEN if bool(cfg.get_value("display", "fullscreen", false)) else Display.WINDOWED
	var r: Variant = cfg.get_value("display", "resolution", resolution)
	if r is Vector2i and (r == FIT_SCREEN or (r.x >= MIN_WINDOW.x and r.y >= MIN_WINDOW.y)):
		resolution = r
	fps_limit = maxi(0, int(cfg.get_value("display", "fps_limit", fps_limit)))
	graphics = clampi(int(cfg.get_value("display", "graphics", graphics)), 0, Graphics.size() - 1) as Graphics
	if graphics == Graphics.HIGH and is_desktop() and not cfg.has_section_key("display", "ray_tracing_offered"):
		graphics = Graphics.RAY_TRACING  # (High was the best there was before 0.14.0: PC goes up to ray tracing once)
	vsync = bool(cfg.get_value("display", "vsync", vsync))
	show_fps = bool(cfg.get_value("display", "show_fps", show_fps))
	ui_scale = clampf(float(cfg.get_value("display", "ui_scale", ui_scale)), 0.5, 2.0)
	volume = clampf(float(cfg.get_value("audio", "volume", volume)), 0.0, 1.0)
	vibration = bool(cfg.get_value("controls", "vibration", vibration))
	auto_update = bool(cfg.get_value("updates", "automatic", auto_update))
	first_person = bool(cfg.get_value("view", "first_person", first_person))
	fp_sharp = bool(cfg.get_value("view", "fp_sharp", fp_sharp))
