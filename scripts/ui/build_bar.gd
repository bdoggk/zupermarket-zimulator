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

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	for id: String in Game.FURNITURE:
		var f: Dictionary = Game.FURNITURE[id]
		var b := _tool_button("$%d" % int(f.cost), func(): _toggle_place(id))
		b.custom_minimum_size = Vector2(76, 78)
		b.icon = _cropped(f.texture)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.tooltip_text = f.name
		row.add_child(b)
		tool_buttons[id] = b
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
	row.add_child(UI.button("Done", build.exit, Vector2(104, 70)))

	build.changed.connect(_refresh)
	Game.decor_changed.connect(_refresh)


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


func _tool_button(text: String, on_press: Callable) -> Button:
	var b := UI.button(text, on_press, Vector2(94, 70))
	b.toggle_mode = true
	return b


func _toggle_place(id: String) -> void:
	if build.tool == BuildMode.Tool.PLACE and build.place_id == id:
		build.select_tool(BuildMode.Tool.NONE)
	else:
		build.select_place(id)


func _toggle_paint() -> void:
	paint_box.visible = not paint_box.visible
	_refresh()


func _toggle_tool(t: BuildMode.Tool) -> void:
	build.select_tool(BuildMode.Tool.NONE if build.tool == t else t)


func _refresh() -> void:
	visible = build.active
	if not visible:
		paint_box.visible = false
		return
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
