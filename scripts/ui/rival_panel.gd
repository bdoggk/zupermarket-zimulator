extends PanelContainer
## The rival store's price list (use its counter or its price board, down
## the street). Shows what it charges today next to your prices, and once
## your store is big enough, lets you buy the place out. Looking at it notes
## down its prices, so they show up at your computer too.

var title: Label
var grid: GridContainer
var footer_label: Label
var buy_button: Button
var _confirming := false
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
	buy_button = UI.button("", _on_buy, Vector2(0, 52))
	buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(buy_button)
	row.add_child(UI.button("Close", close, Vector2(130, 52)))
	Game.rival_requested.connect(open)
	Game.rival_bought.connect(func(): if visible: _rebuild())


func open() -> void:
	visible = true
	_confirming = false
	Game.scout_rival(Game.unlocked_ids())
	_rebuild()


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
	if Game.rival_owned:
		grid.add_child(UI.label("%s is yours. Every shopper in town comes to your store now." % Brand.RIVAL.name, UI.GOOD))
		footer_label.text = ""
		buy_button.visible = false
		return
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
	buy_button.visible = true
	_updaters.append(_update_buy_button)


func _update_buy_button() -> void:
	var problem := Game.rival_buyout_problem()
	var cost := int(Brand.RIVAL.buyout)
	buy_button.disabled = problem != ""
	if problem != "":
		_confirming = false
		buy_button.text = "Buy out %s: $%d  (%s)" % [Brand.RIVAL.name, cost, problem]
	elif _confirming:
		buy_button.text = "Really buy %s for $%d? Press again" % [Brand.RIVAL.name, cost]
	else:
		buy_button.text = "Buy out %s: $%d" % [Brand.RIVAL.name, cost]


func _on_buy() -> void:
	if not _confirming:
		_confirming = true
		return
	_confirming = false
	if Game.buy_out_rival():
		_rebuild()
