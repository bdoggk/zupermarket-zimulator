extends Node
# Build mode used to keep dragging the view after a click was let go over
# the build bar (or outside the window): the camera then followed the mouse
# around. Needs a real window (xvfb) so input goes through the GUI:
#   xvfb-run godot --path . --rendering-driver opengl3 res://tests/camera_test.tscn

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	var hud: Node = main.get_node("HUD")
	var b: BuildMode = Game.build_mode
	var cam: Camera2D = Game.player.camera
	b.enter()
	await _frames(3)
	var bar: Control = hud.build_bar
	var over_bar := bar.get_global_rect().get_center()
	var on_store := Vector2(get_viewport().get_visible_rect().size.x / 2.0, 120)

	# Press on the store, let go over the build bar, then move the mouse.
	_button(on_store, true)
	await _frames(2)
	_button(over_bar, false)
	await _frames(2)
	var before := cam.offset
	var p := over_bar
	for i in 20:
		p += Vector2(-12, -8)
		_motion(p, Vector2(-12, -8), 0)
		await _frames(1)
	check(cam.offset.is_equal_approx(before), "the view stays put when you move the mouse without holding a button (moved %s)" % (cam.offset - before))

	# A real drag still pans.
	_button(on_store, true)
	p = on_store
	for i in 10:
		p += Vector2(10, 6)
		_motion(p, Vector2(10, 6), MOUSE_BUTTON_MASK_LEFT)
		await _frames(1)
	_button(p, false)
	await _frames(2)
	check(not cam.offset.is_equal_approx(before), "dragging with the button held still pans the view")
	var after_drag := cam.offset
	for i in 10:
		p += Vector2(-10, 4)
		_motion(p, Vector2(-10, 4), 0)
		await _frames(1)
	check(cam.offset.is_equal_approx(after_drag), "and it stops when you let go")

	b.exit()
	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


func _button(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(e)


func _motion(pos: Vector2, rel: Vector2, mask: int) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = rel
	e.button_mask = mask
	Input.parse_input_event(e)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
