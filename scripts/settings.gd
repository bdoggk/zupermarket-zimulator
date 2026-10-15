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
##   Graphics      Low / Medium / High (see GRAPHICS_INFO)
##   VSync         on/off (on: the frame rate matches the screen)
##   Show FPS      a frame counter in the corner
##   Vibration     phone and controller rumble, when available

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

enum Graphics { LOW, MEDIUM, HIGH }
const GRAPHICS_NAMES := ["Low", "Medium", "High"]
const GRAPHICS_INFO := [
	"Simple lighting. Best for older phones and battery life.",
	"Store lights and soft shadows.",
	"Store lights with flicker and floating dust.",
]

var display := Display.WINDOWED
var resolution := Vector2i(1280, 720)  # the window's size (FIT_SCREEN = maximized)
var fps_limit := 0
var graphics := Graphics.HIGH
var vsync := true
var show_fps := false
var vibration := true

var _applying := false  # we're resizing the window ourselves
var _save_queued := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if is_mobile():
		graphics = Graphics.MEDIUM
		fps_limit = 60
	load_settings()
	apply()
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool): changed.emit())
	if is_desktop():
		get_window().size_changed.connect(_on_window_resized)


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


## Phone vibration, or a connected controller that can rumble.
func can_vibrate() -> bool:
	return is_mobile() or not Input.get_connected_joypads().is_empty()


func lights_enabled() -> bool:
	return graphics >= Graphics.MEDIUM


func effects_enabled() -> bool:
	return graphics == Graphics.HIGH


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


func set_show_fps(on: bool) -> void:
	show_fps = on
	save_settings()
	changed.emit()


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
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("display", "show_fps", show_fps)
	cfg.set_value("controls", "vibration", vibration)
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
	graphics = clampi(int(cfg.get_value("display", "graphics", graphics)), 0, 2) as Graphics
	vsync = bool(cfg.get_value("display", "vsync", vsync))
	show_fps = bool(cfg.get_value("display", "show_fps", show_fps))
	vibration = bool(cfg.get_value("controls", "vibration", vibration))
