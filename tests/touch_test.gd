extends Node
# Plays with real touch events (finger down, slide, lift: what Android
# sends) in a 1920x1080 window like an AYN Thor's: tapping to walk, pinching
# to zoom, build mode, scrolling lists by dragging over their buttons and
# prices, typing a price, and every window fitting on screen with the big
# touch-screen text (also at UI size 130%). Needs a real window (xvfb):
#   xvfb-run godot --path . --rendering-driver opengl3 res://tests/touch_test.tscn

var fails := 0
var settings_backup := ""


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	if FileAccess.file_exists(Settings.PATH):
		settings_backup = FileAccess.get_file_as_string(Settings.PATH)
	Input.emulate_touch_from_mouse = true  # (makes this a touch screen, like a phone)
	Settings.display = Settings.Display.WINDOWED
	Settings.resolution = Vector2i(1920, 1080)
	Settings.ui_scale = 1.0
	Settings.apply()
	await _frames(5)
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(5)
	var hud: Node = main.get_node("HUD")
	var store: Store = Game.store
	var p: Player = Game.player
	Game.tutorial_hidden = true
	check(hud.is_touch and Game.touch_ui, "touch screen mode")
	var win := get_tree().root
	check(is_equal_approx(win.get_final_transform().x.x, 1.5), "a 1920x1080 screen (the game drawn 1.5x)")

	# ---- walking: a tap walks there once the finger lifts; a slide doesn't
	var start := p.current_cell()
	var target := _open_cell_near(store, start, Vector2i(3, 0))
	await tap(_world_at(Iso.cell_to_world(target)))
	await _frames(150)
	check(p.current_cell() == target, "tapping the floor walks there (%s -> %s, now %s)" % [start, target, p.current_cell()])
	var here := p.current_cell()
	var from := _world_at(Iso.cell_to_world(_open_cell_near(store, here, Vector2i(0, 3))))
	await drag(from, from + Vector2(240, 0))
	await _frames(60)
	check(p.current_cell() == here and p.path.is_empty(), "sliding a finger over the store doesn't walk you anywhere")

	# ---- pinching zooms (and isn't a tap)
	var z0 := p.camera.zoom.x
	var mid := Vector2(960, 420)
	await pinch(mid, 80.0, 380.0)
	var z1 := p.camera.zoom.x
	check(z1 > z0 + 0.01, "spreading two fingers zooms in (%.2f -> %.2f)" % [z0, z1])
	check(p.current_cell() == here and p.path.is_empty(), "and doesn't walk you anywhere")
	await pinch(mid, 380.0, 80.0)
	check(p.camera.zoom.x < z1 - 0.01, "pinching them together zooms out (%.2f -> %.2f)" % [z1, p.camera.zoom.x])

	# ---- the rest of the game, unlocked
	Game.money = 99999.0
	Game.add_xp(100000.0)
	for id: String in Game.PRODUCTS:
		if Game.can_license(id):
			Game.buy_license(id)
	await _frames(3)
	hud.levelup_panel.visible = false
	await _frames(3)

	# ---- build mode by touch: tap to preview, tap again to place; pinch zooms
	await tap(_screen_of(hud.build_button))
	check(Game.build_mode.active, "the Build button works")
	await tap(_screen_of(hud.build_bar.tool_buttons["shelf"]))
	var shelves := store.shelves.size()
	p.set_zoom(Player.DEFAULT_ZOOM)
	await _frames(2)
	var spot := _free_spot(win)
	Game.build_mode._set_cursor(Store.NO_CELL)
	var spot_at := win.get_final_transform() * (win.get_canvas_transform() * Iso.cell_to_world(spot))
	await tap(spot_at)
	check(Game.build_mode.cursor == spot and store.shelves.size() == shelves, "build mode: the first tap shows where it goes")
	await tap(spot_at)
	check(store.shelves.size() == shelves + 1, "the second tap builds it")
	var bz := p.camera.zoom.x
	await pinch(Vector2(960, 300), 80.0, 380.0)
	check(p.camera.zoom.x > bz + 0.01 and store.shelves.size() == shelves + 1, "pinching zooms in build mode too, without building anything")
	await tap(_screen_of(_button(hud.build_bar, "Done")))
	check(not Game.build_mode.active, "Done")

	# ---- the computer fits, with its big touch-screen text
	for t in 4:
		hud.open_computer()
		hud.computer.show_tab(t)
		await _frames(4)
		check(_computer_fits(hud), "%s fits on the PC's screen, X and all" % hud.computer.TAB_NAMES[t])
	hud.computer.show_tab(0)
	await _frames(4)
	var list: ScrollContainer = hud.computer.scroll
	var prices := Game.prices.duplicate()
	var plus := _button(list, "+")
	await drag(_screen_of(plus), _screen_of(plus) - Vector2(0, 260))
	await _frames(4)
	check(list.scroll_vertical > 50 and Game.prices == prices, "dragging from a + button scrolls the list (to %d) without changing a price" % list.scroll_vertical)
	list.scroll_vertical = 0
	await _frames(3)
	var field: LineEdit = hud.computer.price_fields[2]
	await drag(_screen_of(field), _screen_of(field) - Vector2(0, 260))
	await _frames(4)
	check(list.scroll_vertical > 50 and not field.has_focus(), "dragging from a price scrolls too, without bringing up the keyboard")
	list.scroll_vertical = 0
	await _frames(3)
	field = hud.computer.price_fields[3]
	await tap(_screen_of(field))
	await _frames(3)
	var row_y: float = (field.get_global_transform_with_canvas().origin.y - list.get_global_transform_with_canvas().origin.y)
	check(field.has_focus() and field.get_selected_text() == field.text, "tapping a price starts typing it (all selected): " + field.text)
	check(row_y >= 0.0 and row_y < 40.0, "with its row moved to the top of the list, above the keyboard (%.0f from the top)" % row_y)
	field.text = "$4.40"
	field.text_submitted.emit(field.text)
	await _frames(3)
	var typed: String = Game.unlocked_ids()[3]
	check(is_equal_approx(Game.prices[typed], 4.4), "and the typed price is set ($%.2f)" % Game.prices[typed])
	list.scroll_vertical = 0
	await _frames(3)
	var first: String = Game.unlocked_ids()[0]
	var was: float = Game.prices[first]
	await tap(_screen_of(_button(list, "+")))
	check(is_equal_approx(Game.prices[first], was + Game.PRICE_STEP), "tapping + raises the price once ($%.2f -> $%.2f)" % [was, Game.prices[first]])
	hud.computer.close()
	await _frames(2)

	# ---- Options: drag over the arrows to scroll, tap them to change things
	hud.open_pause()
	await _frames(2)
	await tap(_screen_of(_button(hud.pause_menu, "Options")))
	await _frames(3)
	var opt: Node = hud.options
	var opts: ScrollContainer = opt.settings_scroll
	var gfx := Settings.graphics
	var arrow := _button(opts, ">")
	await drag(_screen_of(arrow), _screen_of(arrow) - Vector2(0, 240))
	await _frames(3)
	check(opts.scroll_vertical > 50 and Settings.graphics == gfx, "Options: dragging from an arrow scrolls (to %d) without changing anything" % opts.scroll_vertical)
	opts.scroll_vertical = 0
	await _frames(3)
	await tap(_screen_of(opt.gfx_value.get_parent().get_child(3)))
	check(Settings.graphics != gfx, "tapping an arrow changes it")
	Settings.set_graphics(gfx)
	opt.close()
	await _frames(1)
	hud.pause_menu.close()
	await _frames(2)

	# ---- a shop: drag over a Buy button to scroll, tap it to buy
	hud.shop_panel.open(Brand.SHOPS.keys()[0])
	await _frames(4)
	var shop_list: ScrollContainer = hud.shop_panel.find_children("*", "ScrollContainer", true, false)[0]
	var buy := _button(shop_list, "$")
	var money := Game.money
	await drag(_screen_of(buy), _screen_of(buy) - Vector2(0, 200))
	await _frames(3)
	check(shop_list.scroll_vertical > 30 and Game.money == money, "a shop: dragging from a Buy button scrolls (to %d) without buying" % shop_list.scroll_vertical)
	shop_list.scroll_vertical = 0
	await _frames(3)
	await tap(_screen_of(_button(shop_list, "$")))
	check(Game.money < money, "tapping Buy buys it")
	hud.shop_panel.close()
	await _frames(2)

	# ---- at UI size 130% everything still fits, and taps still land
	Settings.set_ui_scale(1.3)
	await _frames(4)
	var screen := Rect2(Vector2.ZERO, hud.root.size)
	for t in 4:
		hud.open_computer()
		hud.computer.show_tab(t)
		await _frames(4)
		check(_computer_fits(hud) and screen.encloses(_seen(hud.computer)), "130%%: %s fits, X and all" % hud.computer.TAB_NAMES[t])
	hud.computer.close()
	await _frames(2)
	for panel_name in ["rival_panel", "message_log"]:
		var panel: Control = hud.get(panel_name)
		panel.open()
		await _frames(4)
		check(screen.encloses(_seen(panel)), "130%%: %s fits on screen" % panel_name)
		panel.close()
		await _frames(2)
	hud.shop_panel.open(Brand.SHOPS.keys()[0])
	await _frames(4)
	check(screen.encloses(_seen(hud.shop_panel)), "130%: a shop fits on screen")
	hud.shop_panel.close()
	Game.build_mode.enter()
	await _frames(4)
	check(screen.encloses(_seen(hud.build_bar)), "130%%: the build bar fits on screen (%s)" % _seen(hud.build_bar))
	await tap(_screen_of(_button(hud.build_bar, "Done")))
	check(not Game.build_mode.active, "and its Done button works")

	Settings.set_ui_scale(1.0)
	if settings_backup != "":
		var out := FileAccess.open(Settings.PATH, FileAccess.WRITE)
		out.store_string(settings_backup)
		out.close()
	else:
		DirAccess.remove_absolute(Settings.PATH)
	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- fingers

func _touch(at: Vector2, down: bool, finger := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = finger
	e.position = at
	e.pressed = down
	Input.parse_input_event(e)


func _slide(at: Vector2, by: Vector2, finger := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.index = finger
	e.position = at
	e.relative = by
	e.screen_relative = by
	Input.parse_input_event(e)


func tap(at: Vector2) -> void:
	_touch(at, true)
	await _frames(4)
	_touch(at, false)
	await _frames(4)


func drag(from: Vector2, to: Vector2, steps := 12) -> void:
	_touch(from, true)
	await _frames(2)
	var last := from
	for i in range(1, steps + 1):
		var at := from.lerp(to, float(i) / steps)
		_slide(at, at - last)
		last = at
		await _frames(1)
	await _frames(2)
	_touch(to, false)
	await _frames(4)


## Two fingers on either side of `center`, from `apart` to `to_apart`.
func pinch(center: Vector2, apart: float, to_apart: float) -> void:
	var a := center - Vector2(apart / 2.0, 0)
	var b := center + Vector2(apart / 2.0, 0)
	_touch(a, true, 0)
	await _frames(2)
	_touch(b, true, 1)
	await _frames(2)
	for i in range(1, 13):
		var d := lerpf(apart, to_apart, i / 12.0)
		var na := center - Vector2(d / 2.0, 0)
		var nb := center + Vector2(d / 2.0, 0)
		_slide(na, na - a, 0)
		_slide(nb, nb - b, 1)
		a = na
		b = nb
		await _frames(1)
	_touch(b, false, 1)
	await _frames(2)
	_touch(a, false, 0)
	await _frames(4)


# ---------------------------------------------------------------- where things are

## The middle of a control, in window pixels (where a finger would touch it).
func _screen_of(c: Control) -> Vector2:
	return get_tree().root.get_final_transform() * (c.get_global_transform_with_canvas() * (c.size / 2.0))


func _world_at(world_pos: Vector2) -> Vector2:
	var win := get_tree().root
	return win.get_final_transform() * (win.get_canvas_transform() * world_pos)


## Where a control is drawn, in its layer's units (the HUD's at its UI size).
func _seen(c: Control) -> Rect2:
	return c.get_global_transform() * Rect2(Vector2.ZERO, c.size)


func _computer_fits(hud: Node) -> bool:
	var pc: Node = hud.computer
	var glass: Rect2 = _seen(pc.screen).grow(1.0)
	var ok: bool = glass.encloses(_seen(pc.window_close)) and glass.encloses(_seen(pc.window)) and glass.encloses(_seen(pc.taskbar))
	if not ok:
		print("   glass %s  x %s  window %s  taskbar %s  pc %s scale %s" % [glass, _seen(pc.window_close), _seen(pc.window), _seen(pc.taskbar), _seen(pc), pc.scale])
	return ok


## A spot in the middle part of the screen where a shelf can go.
func _free_spot(win: Window) -> Vector2i:
	var vis := win.get_visible_rect().size
	var b: BuildMode = Game.build_mode
	for fy in [0.35, 0.3, 0.4, 0.25, 0.45]:
		for fx in [0.5, 0.45, 0.55, 0.4, 0.6, 0.35, 0.65]:
			var c := Iso.world_to_cell(win.get_canvas_transform().affine_inverse() * Vector2(vis.x * fx, vis.y * fy))
			b._set_cursor(c)
			if b.cursor_error == "":
				return c
	return Store.NO_CELL


func _open_cell_near(store: Store, from: Vector2i, step: Vector2i) -> Vector2i:
	for k in [1, -1]:
		var c: Vector2i = from + step * k
		if store.is_walkable(c):
			return c
	return from + step


func _button(from: Node, text: String) -> Button:
	for c in from.get_children():
		if c is Button and (c as Button).text.contains(text) and (c as Control).is_visible_in_tree():
			return c
		var b := _button(c, text)
		if b:
			return b
	return null


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
