extends PanelContainer
## The rival store's price list (use its counter or its price board, down
## the street). Shows what it charges today next to your prices. Looking at
## it notes down its prices, so they show up at your computer too. (It's
## not for sale: from store level 15 it's war instead, see GangWar.)

var title: Label
var grid: GridContainer
var footer_label: Label
var close_button: Button
var _updaters: Array[Callable] = []


func _ready() -> void:
	visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	title = UI.label("", UI.WARN)
	col.add_child(title)
	col.add_child(UI.label(Brand.RIVAL.slogan, UI.DIM))
	col.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	col.add_child(HSeparator.new())
	footer_label = UI.label("", UI.DIM)
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(footer_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	row.alignment = BoxContainer.ALIGNMENT_END
	close_button = UI.button("Close", close, Vector2(130, 52))
	row.add_child(close_button)
	Game.rival_requested.connect(open)


func open() -> void:
	visible = true
	Game.scout_rival(Game.unlocked_ids())
	_rebuild()
	if UI.has_pad():  # Close with A
		UI.pad_focus(close_button)
		close_button.grab_focus.call_deferred()


func close() -> void:
	visible = false


func _process(_delta: float) -> void:
	if not visible:
		return
	for u in _updaters:
		u.call()


func _rebuild() -> void:
	UI.clear(grid)
	_updaters.clear()
	title.text = "%s PRICE LIST  -  Day %d" % [Brand.RIVAL.name.to_upper(), Game.day]
	for h in ["", "Product", Brand.RIVAL.name, "You", ""]:
		grid.add_child(UI.label(h, UI.DIM))
	for id: String in Game.unlocked_ids():
		grid.add_child(UI.icon(Game.icon(id), Vector2(32, 40)))
		var name_text := Game.product_name(id)
		if id == Game.rival_deal:
			name_text += "  (deal of the day!)"
		var n := UI.label(name_text)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(n)
		var theirs := UI.label()
		theirs.custom_minimum_size.x = 110
		grid.add_child(theirs)
		var yours := UI.label()
		yours.custom_minimum_size.x = 90
		grid.add_child(yours)
		var verdict := UI.label()
		verdict.custom_minimum_size.x = 170
		grid.add_child(verdict)
		_updaters.append(func():
			var t := Game.rival_price(id)
			var y: float = Game.prices[id]
			theirs.text = "$%.2f" % t
			yours.text = "$%.2f" % y
			if y <= t + 0.001:
				verdict.text = "You're cheaper"
				UI.set_color(verdict, UI.GOOD)
			else:
				verdict.text = "$%.2f more" % (y - t)
				UI.set_color(verdict, UI.BAD)
		)
	footer_label.text = "Shoppers compare prices: the more of yours beat %s's, the more of them shop with you. A messy store sends them here too." % Brand.RIVAL.name
