extends Node
# Checks sprinting, smooth movement (the player moves every frame, not just
# on physics ticks), crisp zoom steps, the Controls list in Options, and the
# frame rate / window settings.
#   godot --headless --path . --fixed-fps 60 res://tests/controls_test.tscn

var fails := 0
var settings_backup := ""


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	seed(11)
	if FileAccess.file_exists(Settings.PATH):
		settings_backup = FileAccess.get_file_as_string(Settings.PATH)
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	var store: Store = Game.store
	var p: Player = Game.player
	var hud: Node = main.get_node("HUD")
	Game.tutorial_hidden = true

	# ---- moving every frame
	check(p.is_processing() and not p.is_physics_processing(), "the player moves every frame (not only on physics ticks)")

	# ---- sprinting
	var start := Vector2i(6, 6)
	var walked := await _walk_for(p, start, 1.0, false)
	var ran := await _walk_for(p, start, 1.0, true)
	check(walked > 10.0, "walking moves you (%.0f px in a second)" % walked)
	check(ran > walked * 1.4, "sprinting is faster (%.0f px vs %.0f)" % [ran, walked])
	check(absf(ran / walked - Player.SPRINT_SPEED / Player.WALK_SPEED) < 0.3, "by about %.1fx" % (Player.SPRINT_SPEED / Player.WALK_SPEED))
	p.position = Iso.cell_to_world(start)
	await _frames(2)
	var target := start + Vector2i(4, 0)
	p.walk_to(target)
	p.run_toggle = true
	var t := 0.0
	while not p.path.is_empty() and t < 5.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	p.run_toggle = false
	await _frames(1)
	check(p.current_cell() == target and not p.sprinting and t < 4.0 / Player.WALK_SPEED, "RUN works when walking to a tapped spot too (%.1fs for 4 tiles)" % t)
	check(hud.run_button.visible == hud.is_touch, "the RUN button is there on touch screens only")
	hud.run_button.button_pressed = true
	check(p.run_toggle and hud.run_button.text == "RUN: ON", "tapping RUN turns sprinting on")
	hud.run_button.button_pressed = false
	check(not p.run_toggle, "and off again")

	# ---- crisp zoom (needs a real window: run this test with xvfb-run too)
	var scale := p._screen_scale()
	if scale < 0.5:
		print("(no real window: skipping the zoom checks)")
		scale = 1.0
		p.get_viewport().size = Vector2i(1280, 720)
	var px := p.camera.zoom.x * scale
	check(is_equal_approx(px, roundf(px)), "the zoom makes each art pixel a whole number of screen pixels (%.2f)" % px)
	p.zoom_by(1.1)
	var px_in := p.camera.zoom.x * scale
	check(is_equal_approx(px_in, px + 1.0), "zooming in goes up one step (%.0f -> %.0f)" % [px, px_in])
	p.zoom_by(0.8)
	p.zoom_by(0.8)
	var px_out := p.camera.zoom.x * scale
	check(is_equal_approx(px_out, px - 1.0), "zooming out goes down a step at a time (%.0f)" % px_out)
	for i in 10:
		p.zoom_by(0.5)
	check(p.camera.zoom.x >= Player.MIN_ZOOM - 0.01, "and stops at the widest view")
	p.set_zoom(Player.DEFAULT_ZOOM)
	if DisplayServer.get_name() != "headless":
		get_window().size = Vector2i(1920, 1080)  # a bigger window: everything scales up 1.5x
		await _frames(4)
		var s2 := p._screen_scale()
		var px2 := p.camera.zoom.x * s2
		check(is_equal_approx(s2, 1.5) and is_equal_approx(px2, roundf(px2)), "in a 1920x1080 window the zoom still lands on whole pixels (%.2f px, zoom %.2f)" % [px2, p.camera.zoom.x])
		get_window().size = Vector2i(1280, 720)
		await _frames(4)
		check(is_equal_approx(p.camera.zoom.x * p._screen_scale(), px), "back to 1280x720, the zoom is back where it was")

	# ---- the Controls list
	hud.open_pause()
	await _frames(1)
	hud._open_options()
	await _frames(2)
	var opt: Node = hud.options
	check(opt.visible and opt.settings_page.visible and opt.controls_button.visible, "Options has a Controls button")
	opt.show_controls()
	await _frames(2)
	check(opt.controls_page.visible and not opt.settings_page.visible, "it shows the controls")
	var grid: GridContainer = opt.controls_scroll.get_child(0)
	var texts := []
	for c in grid.get_children():
		texts.append((c as Label).text)
	check(grid.get_child_count() == (ControlsList.rows().size() + 1) * 3, "every control is listed (%d rows)" % ControlsList.rows().size())
	check(texts.has("Sprint") and texts.has("Hold Shift"), "including sprinting")
	check(texts.has("Turn something (build mode)") and texts.has("R"), "and turning things in build mode")
	check(opt.controls_scroll.custom_minimum_size.y <= get_viewport().get_visible_rect().size.y - 200, "the list scrolls instead of running off the screen")
	opt.close()
	await _frames(1)
	check(opt.visible and opt.settings_page.visible, "Back (or Esc) goes back to the settings")
	opt.close()
	await _frames(1)
	check(not opt.visible, "and again closes Options")
	hud.pause_menu.close()
	await _frames(1)

	# ---- frame rate and window settings
	Settings.set_fps_limit(144)
	check(Engine.max_fps == 144, "the frame rate limit applies (%d)" % Engine.max_fps)
	Settings.set_fps_limit(0)
	check(Engine.max_fps == 0, "No limit means no limit")
	check(Settings.fps_name(0) == "No limit" and Settings.fps_name(60) == "60 FPS", "frame rate names")
	var res := Settings.available_resolutions()
	check(res[-1] == Settings.FIT_SCREEN, "the window sizes end with 'Fill the screen': %s" % [res.map(func(r): return Settings.resolution_name(r))])
	Settings.set_display(Settings.Display.EXCLUSIVE)
	Settings.set_resolution(Settings.FIT_SCREEN)
	Settings.set_show_fps(true)
	Settings.display = Settings.Display.WINDOWED
	Settings.resolution = Vector2i(1280, 720)
	Settings.show_fps = false
	Settings.load_settings()
	check(Settings.display == Settings.Display.EXCLUSIVE and Settings.resolution == Settings.FIT_SCREEN and Settings.show_fps, "display mode, window size and Show FPS are saved")
	await _frames(2)
	check(hud.fps_label.visible and hud.fps_label.text.ends_with("FPS"), "Show FPS puts a counter by the clock: " + hud.fps_label.text)
	# Settings from before this version: just a fullscreen on/off.
	var old := ConfigFile.new()
	old.set_value("display", "fullscreen", true)
	old.set_value("display", "resolution", Vector2i(1600, 900))
	old.set_value("display", "graphics", 1)
	old.save(Settings.PATH)
	Settings.load_settings()
	check(Settings.display == Settings.Display.FULLSCREEN and Settings.resolution == Vector2i(1600, 900) and Settings.fps_limit == 0, "older settings files still load")

	# Put back the real settings.
	if settings_backup != "":
		var out := FileAccess.open(Settings.PATH, FileAccess.WRITE)
		out.store_string(settings_backup)
		out.close()
	else:
		DirAccess.remove_absolute(Settings.PATH)
	Settings.load_settings()
	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


## Walks to the right for `seconds` (holding sprint or not) and returns how
## far the player went.
func _walk_for(p: Player, cell: Vector2i, seconds: float, sprint: bool) -> float:
	p.position = Iso.cell_to_world(cell)
	await _frames(2)
	var from := p.position
	if sprint:
		Input.action_press("sprint")
	Input.action_press("move_right")
	var t := 0.0
	while t < seconds:
		await get_tree().process_frame
		t += get_process_delta_time()
	Input.action_release("move_right")
	Input.action_release("sprint")
	await _frames(1)
	return p.position.distance_to(from)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
