extends PanelContainer
## Picking a box off a storage rack that holds more than one product: one
## row per product (how many boxes, how full), and Take gives you the
## fullest box of it. Works with a tap or a click, the arrow keys and Enter,
## or the d-pad and A. Closes by itself if you walk off, pick something up,
## or the rack ends up with one product (or none) on it.

var rack: StorageRack
var title: Label
var grid: GridContainer
var close_button: Button
var _first_take: Button
var _shown := ""  # what the list shows, to rebuild it when the rack changes


func _ready() -> void:
	visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	title = UI.label("", UI.WARN)
	title.add_theme_font_size_override("font_size", 26)
	col.add_child(title)
	col.add_child(UI.label("Which box do you want?", UI.DIM))
	col.add_child(HSeparator.new())
	grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(grid)
	col.add_child(HSeparator.new())
	close_button = UI.menu_button("Close", close, Vector2(140, 52))
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(close_button)
	Game.rack_requested.connect(open)


func open(r: StorageRack) -> void:
	rack = r
	visible = true
	_rebuild()
	if UI.wants_focus():
		(_first_take if _first_take else close_button).grab_focus.call_deferred()


func close() -> void:
	visible = false
	rack = null


func _process(_delta: float) -> void:
	if not visible:
		return
	var p: Player = Game.player
	if not is_instance_valid(rack) or not rack.is_inside_tree() or p == null or not is_instance_valid(p) \
			or p.is_carrying() or Iso.chebyshev(p.current_cell(), rack.cell) > 1 or rack.products().size() < 2:
		close()
		return
	if _describe() != _shown:  # a stocker took a box, or put one on
		var had := get_viewport().gui_get_focus_owner()
		var at := grid.get_children().find(had)
		_rebuild()
		if at >= 0 and UI.wants_focus():
			var takes := grid.get_children().filter(func(c): return c is Button)
			if not takes.is_empty():
				(takes[mini(at / grid.columns, takes.size() - 1)] as Button).grab_focus()


## "guts:8,5;lungs:6" (what's on the rack, to notice changes).
func _describe() -> String:
	var parts: Array[String] = []
	for id in rack.products():
		var counts: Array[String] = []
		for b in rack.boxes:
			if b.product_id == id:
				counts.append(str(b.count))
		parts.append("%s:%s" % [id, ",".join(counts)])
	return ";".join(parts)


func _rebuild() -> void:
	UI.clear(grid)
	_first_take = null
	_shown = _describe()
	title.text = "STORAGE RACK  (%d/%d)" % [rack.boxes.size(), StorageRack.CAPACITY]
	for id in rack.products():
		var pic := UI.icon(Game.icon(id), Vector2(40, 40))
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		grid.add_child(pic)
		var counts: Array[String] = []
		for b in rack.boxes:
			if b.product_id == id:
				counts.append(str(b.count))
		var n := counts.size()
		var info := UI.label("%s\n%d box%s: %s" % [Game.product_name(id), n, "" if n == 1 else "es",
			" + ".join(counts.map(func(c): return "x" + c))])
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.custom_minimum_size.x = 260
		grid.add_child(info)
		var take := UI.menu_button("Take x%d" % rack.fullest(id).count, _take.bind(id), Vector2(150, 52))
		grid.add_child(take)
		if _first_take == null:
			_first_take = take


func _take(product_id: String) -> void:
	if is_instance_valid(rack) and rack.take_product(Game.player, product_id):
		close()
