extends PanelContainer
## The bar along the bottom of the screen in build mode: buy furniture,
## move, turn or sell it, repaint the floor and walls, and buy the lot next
## door.

var build: BuildMode
var status_label: Label
var tool_buttons := {}  # furniture id / "move" / "rotate" / "sell" / "expand" -> Button
var paint_button: Button
var expand_button: Button
var paint_box: VBoxContainer
var decor_button: Button  # opens the decorations' own row
var decor_box: VBoxContainer
var locks := {}  # furniture id -> its "Lv 7" label, while it's locked
var _placing := ""  # what build mode was placing last time (to open the decor row when that changes)
var floor_buttons: Array[Button] = []
var wall_buttons: Array[Button] = []


func _ready() -> void:
	visible = false
	build = Game.build_mode
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)

	paint_box = VBoxContainer.new()
	paint_box.visible = false
	col.add_child(paint_box)
	paint_box.add_child(UI.label("FLOOR  ($%d)" % int(Game.FLOOR_COST), UI.DIM))
	var floors := HBoxContainer.new()
	paint_box.add_child(floors)
	for i in Game.FLOOR_STYLES.size():
		var style: Dictionary = Game.FLOOR_STYLES[i]
		var b := UI.button(style.name, func(): Game.buy_floor_style(i), Vector2(0, 52))
		b.icon = load("res://assets/sprites/floor_%s_a.png" % style.id)
		floors.add_child(b)
		floor_buttons.append(b)
	paint_box.add_child(UI.label("WALLS  ($%d)" % int(Game.WALL_COST), UI.DIM))
	var walls := HBoxContainer.new()
	paint_box.add_child(walls)
	for i in Game.WALL_COLORS.size():
		var color: Dictionary = Game.WALL_COLORS[i]
		var b := UI.button(color.name, func(): Game.buy_wall_color(i), Vector2(0, 52))
		b.icon = load("res://assets/sprites/wall_%s_swatch.png" % color.id)
		walls.add_child(b)
		wall_buttons.append(b)
	paint_box.add_child(HSeparator.new())

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	col.add_child(top)
	top.add_child(UI.label("BUILD MODE", UI.WARN))
	status_label = UI.label()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(status_label)

	# Decorations (gravestones, lanterns, cauldrons...) have a row of their
	# own above the main one, opened with the Decor button.
	decor_box = VBoxContainer.new()
	decor_box.visible = false
	col.add_child(decor_box)
	decor_box.add_child(UI.label("DECORATIONS: every one brings more shoppers; some bring more of one kind", UI.DIM))
	var decor_row := HBoxContainer.new()
	decor_row.add_theme_constant_override("separation", 6)
	decor_box.add_child(decor_row)
	decor_box.add_child(HSeparator.new())
	col.move_child(decor_box, 0)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	for id: String in Game.FURNITURE:
		var b := _furniture_button(id)
		if Game.FURNITURE[id].kind == "decor":
			decor_row.add_child(b)
		else:
			row.add_child(b)
	decor_button = _furniture_button("plant", "Decor", _toggle_decor)
	decor_button.tooltip_text = "Gravestones, lanterns, cauldrons..."
	row.add_child(decor_button)
	row.add_child(VSeparator.new())
	tool_buttons["move"] = _tool_button("Move", func(): _toggle_tool(BuildMode.Tool.MOVE))
	row.add_child(tool_buttons["move"])
	# While placing or moving something, Rotate turns it; otherwise it picks
	# the Rotate tool (tap things to turn them).
	tool_buttons["rotate"] = _tool_button("Rotate", func(): build.rotate_pressed(true))
	tool_buttons["rotate"].tooltip_text = "Turn things a quarter turn (R)"
	row.add_child(tool_buttons["rotate"])
	tool_buttons["sell"] = _tool_button("Sell", func(): _toggle_tool(BuildMode.Tool.SELL))
	row.add_child(tool_buttons["sell"])
	paint_button = _tool_button("Paint", _toggle_paint)
	row.add_child(paint_button)
	if not Brand.EXPANSIONS.is_empty() and Game.store.town:
		expand_button = _tool_button("Expand", func(): _toggle_tool(BuildMode.Tool.EXPAND))
		row.add_child(expand_button)
		tool_buttons["expand"] = expand_button
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(UI.button("Done", build.exit, Vector2(88, 70)))

	build.changed.connect(_refresh)
	Game.decor_changed.connect(_refresh)
	Game.unlocks_changed.connect(_refresh)


## The furniture sprite without the empty space around it, so it shows up
## bigger on the button.
static func _cropped(tex: Texture2D) -> Texture2D:
	var used := tex.get_image().get_used_rect()
	if used.size.x <= 0:
		return tex
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = Rect2(used)
	return a


## A button to buy a piece of furniture: its name on top, its picture,
## then the price.
func _furniture_button(id: String, title := "", on_press := Callable()) -> Button:
	var f: Dictionary = Game.FURNITURE[id]
	var b := _tool_button("", on_press if on_press.is_valid() else func(): _toggle_place(id))
	b.custom_minimum_size = Vector2(84, 100)
	b.tooltip_text = "%s  $%d" % [f.name, int(f.cost)]
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 4)
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var name_label := UI.label(title if title != "" else f.name)
	var longest: int = Array(name_label.text.split(" ")).map(func(w): return w.length()).max()
	name_label.add_theme_font_size_override("font_size", 13 if longest <= 10 else 11)  # ("Sarcophagus" on one line)
	name_label.add_theme_constant_override("line_spacing", -3)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(76, 30)  # room for two lines, so every picture lines up
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	var pic := TextureRect.new()
	pic.texture = _cropped(f.texture)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(pic)
	var price := UI.label("$%d" % int(f.cost) if title == "" else "", UI.WARN)
	price.add_theme_font_size_override("font_size", 15)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(price)
	if title != "":
		return b  # (the Decor button)
	tool_buttons[id] = b
	if Game.furniture_level(id) > 1:
		locks[id] = price
	return b


func _toggle_decor() -> void:
	decor_box.visible = not decor_box.visible
	paint_box.visible = false
	_refresh()


func _tool_button(text: String, on_press: Callable) -> Button:
	var b := UI.button(text, on_press, Vector2(80, 70))
	b.toggle_mode = true
	return b


func _toggle_place(id: String) -> void:
	if build.tool == BuildMode.Tool.PLACE and build.place_id == id:
		build.select_tool(BuildMode.Tool.NONE)
	else:
		build.select_place(id)


func _toggle_paint() -> void:
	paint_box.visible = not paint_box.visible
	decor_box.visible = false
	_refresh()


func _toggle_tool(t: BuildMode.Tool) -> void:
	build.select_tool(BuildMode.Tool.NONE if build.tool == t else t)


func _refresh() -> void:
	visible = build.active
	if not visible:
		paint_box.visible = false
		decor_box.visible = false
		return
	# Locked furniture shows the store level it comes with.
	for id: String in locks:
		var lv := Game.furniture_level(id)
		var locked := Game.level < lv
		tool_buttons[id].disabled = locked
		(locks[id] as Label).text = "Lv %d" % lv if locked else "$%d" % int(Game.FURNITURE[id].cost)
		UI.set_color(locks[id], UI.DIM if locked else UI.WARN)
	# Picking a decoration (a controller's d-pad) shows its row.
	var placing := build.place_id if build.tool == BuildMode.Tool.PLACE else ""
	if placing != _placing and Game.FURNITURE.get(placing, {}).get("kind", "") == "decor":
		decor_box.visible = true
		paint_box.visible = false
	_placing = placing
	status_label.text = build.status
	for key: String in tool_buttons:
		var on := false
		match key:
			"move":
				on = build.tool == BuildMode.Tool.MOVE
			"rotate":
				on = build.tool == BuildMode.Tool.ROTATE
			"sell":
				on = build.tool == BuildMode.Tool.SELL
			"expand":
				on = build.tool == BuildMode.Tool.EXPAND
			_:
				on = build.tool == BuildMode.Tool.PLACE and build.place_id == key
		tool_buttons[key].set_pressed_no_signal(on)
	paint_button.set_pressed_no_signal(paint_box.visible)
	decor_button.set_pressed_no_signal(decor_box.visible)
	if expand_button:
		var e := Game.next_expansion()
		expand_button.text = "Expand\n$%d" % int(e.cost) if not e.is_empty() else "Expand\n(done)"
	for i in floor_buttons.size():
		var current := i == Game.floor_style
		floor_buttons[i].disabled = current
		floor_buttons[i].text = Game.FLOOR_STYLES[i].name + (" (now)" if current else "")
	for i in wall_buttons.size():
		var current := i == Game.wall_color
		wall_buttons[i].disabled = current
		wall_buttons[i].text = Game.WALL_COLORS[i].name + (" (now)" if current else "")
