extends PanelContainer
## The store computer, with four tabs:
##   Stock     order boxes and set your prices (market prices change!)
##   Products  buy licenses to sell new products as your store levels up
##   Staff     hire stockers and cashiers (they're paid every evening)
##   Upgrades  one-time purchases like the handheld scanner

enum Tab { STOCK, PRODUCTS, STAFF, UPGRADES }

const TAB_NAMES := ["Stock & Prices", "Products", "Staff", "Upgrades"]

var tab := Tab.STOCK
var level_label: Label
var money_label: Label
var news_label: Label
var footer_label: Label
var match_button: Button
var auto_button: CheckButton
var tab_buttons: Array[Button] = []
var scroll: ScrollContainer
var body: VBoxContainer
var _updaters: Array[Callable] = []  # refresh numbers every frame


func _ready() -> void:
	visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	col.add_child(header)
	var title := UI.label("STORE COMPUTER")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	level_label = UI.label("", UI.INFO)
	header.add_child(level_label)
	money_label = UI.label("", UI.GOOD)
	header.add_child(money_label)

	var tabs := HBoxContainer.new()
	col.add_child(tabs)
	var group := ButtonGroup.new()
	for i in TAB_NAMES.size():
		var b := UI.button(TAB_NAMES[i], func(): show_tab(i), Vector2(0, 48))
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
		tab_buttons.append(b)

	news_label = UI.label("", UI.WARN)
	col.add_child(news_label)
	col.add_child(HSeparator.new())

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)

	col.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	col.add_child(footer)
	footer_label = UI.label("", UI.DIM)
	footer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(footer_label)
	auto_button = CheckButton.new()
	auto_button.text = "Auto-match"
	auto_button.focus_mode = Control.FOCUS_NONE
	auto_button.button_pressed = Game.auto_price
	auto_button.toggled.connect(_on_auto_toggled)
	footer.add_child(auto_button)
	match_button = UI.button("Match all to market", Game.match_all_prices, Vector2(0, 52))
	footer.add_child(match_button)
	footer.add_child(UI.button("Close", close, Vector2(130, 52)))

	Game.unlocks_changed.connect(_rebuild_if_open)
	Game.market_changed.connect(_rebuild_if_open)
	Game.staff_changed.connect(_rebuild_if_open)


## Auto-match: your prices follow the market every time it changes.
func _on_auto_toggled(on: bool) -> void:
	Game.auto_price = on
	if on:
		Game.match_all_prices()


func open() -> void:
	visible = true
	show_tab(tab)


func close() -> void:
	visible = false


func show_tab(t: Tab) -> void:
	tab = t
	tab_buttons[t].button_pressed = true
	_rebuild()
	scroll.scroll_vertical = 0


func _process(_delta: float) -> void:
	if not visible:
		return
	money_label.text = "$%.2f" % Game.money
	var next := Game.next_level_xp()
	if next < 0:
		level_label.text = "Store level %d (max)" % Game.level
	else:
		level_label.text = "Store level %d   %d / %d XP" % [Game.level, int(Game.xp), int(next)]
	for u in _updaters:
		u.call()


func _rebuild_if_open() -> void:
	if visible:
		_rebuild()


func _rebuild() -> void:
	UI.clear(body)
	_updaters.clear()
	news_label.text = "NEWS: " + Game.market.news if Game.market.news != "" else "No big news today."
	match_button.visible = tab == Tab.STOCK
	auto_button.visible = tab == Tab.STOCK
	match tab:
		Tab.STOCK:
			_build_stock()
		Tab.PRODUCTS:
			_build_products()
		Tab.STAFF:
			_build_staff()
		Tab.UPGRADES:
			_build_upgrades()


func _grid(columns: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 10)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(g)
	return g


## Buttons inside the scroll area let drags through, so you can scroll on a
## touch screen by dragging over them.
func _row_button(text: String, on_press: Callable, min_size := Vector2(52, 52)) -> Button:
	var b := UI.button(text, on_press, min_size)
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	return b


# ---------------------------------------------------------------- stock tab

func _build_stock() -> void:
	footer_label.text = "Prices change every few hours. Price above market and %s may skip it." % Brand.SAY.shoppers
	var g := _grid(8)
	for h in ["", "Product", "Market", "", "Your price", "", "", ""]:
		g.add_child(UI.label(h, UI.DIM))
	for id: String in Game.unlocked_ids():
		g.add_child(UI.icon(Game.icon(id), Vector2(32, 40)))

		var info := UI.label()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(info)

		var market := UI.label()
		market.custom_minimum_size.x = 96
		g.add_child(market)

		g.add_child(_row_button("-", func(): Game.change_price(id, -Game.PRICE_STEP)))
		var price := UI.label()
		price.custom_minimum_size.x = 88
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g.add_child(price)
		g.add_child(_row_button("+", func(): Game.change_price(id, Game.PRICE_STEP)))
		g.add_child(_row_button("=", func(): Game.match_market(id)))
		var order := _row_button("Order box", func(): Game.order_box(id), Vector2(0, 52))
		g.add_child(order)

		_updaters.append(func():
			var cold := "  (%s)" % Game.FURNITURE.fridge.name.to_lower() if Game.is_cold(id) else ""
			info.text = "%s%s\nBox of %d: $%.2f" % [Game.product_name(id), cold, Game.PRODUCTS[id].box_size, Game.box_cost(id)]
			var change := roundi(Game.market.change(id) * 100.0)
			market.text = "$%.2f\n%s" % [Game.market_price(id), "%+d%%" % change if change != 0 else "steady"]
			UI.set_color(market, UI.GOOD if change > 0 else (UI.BAD if change < 0 else UI.DIM))
			var p: float = Game.prices[id]
			var m := Game.market_price(id)
			price.text = "$%.2f" % p
			UI.set_color(price, UI.BAD if p > m * 1.25 else (UI.WARN if p > m + 0.001 else UI.GOOD))
			order.disabled = Game.money < Game.box_cost(id)
		)
	var waiting := UI.label("", UI.DIM)
	body.add_child(waiting)
	_updaters.append(func():
		var count: int = Game.store.pending_deliveries.size()
		waiting.text = "On the way: %d box%s" % [count, "" if count == 1 else "es"] if count > 0 else "No deliveries on the way."
	)


# ---------------------------------------------------------------- products tab

func _build_products() -> void:
	footer_label.text = "Sell more to level up your store and unlock new products. Cold products need a %s." % Game.FURNITURE.fridge.name.to_lower()
	var g := _grid(4)
	for id: String in Game.PRODUCTS:
		var p: Dictionary = Game.PRODUCTS[id]
		var owned := Game.is_licensed(id)
		var pic := UI.icon(p.icon, Vector2(32, 40))
		if not owned and Game.level < p.level:
			pic.modulate = Color(0.25, 0.25, 0.3)
		g.add_child(pic)

		var name_text: String = p.name
		if p.cold:
			name_text += "\nCold: needs a %s" % Game.FURNITURE.fridge.name.to_lower()
		var info := UI.label(name_text)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(info)
		g.add_child(UI.label("Sells for ~$%.2f" % Game.market_price(id), UI.DIM))

		if owned:
			var l := UI.label("Unlocked", UI.GOOD)
			l.custom_minimum_size = Vector2(200, 52)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			g.add_child(l)
		elif Game.level < p.level:
			var l := UI.label("Level %d  ($%d)" % [p.level, int(p.license)], UI.DIM)
			l.custom_minimum_size = Vector2(200, 52)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			g.add_child(l)
		else:
			var b := _row_button("License $%d" % int(p.license), func(): Game.buy_license(id), Vector2(200, 52))
			g.add_child(b)
			_updaters.append(func(): b.disabled = Game.money < p.license)


# ---------------------------------------------------------------- staff tab

func _build_staff() -> void:
	var wages := Game.daily_wages()
	if wages > 0.0:
		footer_label.text = "Staff are paid at the end of every day (now $%d a day)." % int(wages)
	else:
		footer_label.text = "Staff are paid at the end of every day. Hire someone to get help around the store."
	var g := _grid(4)
	for role: String in Game.STAFF:
		var r: Dictionary = Game.STAFF[role]
		g.add_child(UI.icon(r.texture, Vector2(32, 72)))
		var info := UI.label("%s\n%s" % [r.name, r.desc])
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		g.add_child(info)
		var cost := UI.label("Hire $%d\nWage $%d / day" % [int(r.hire), int(r.wage)], UI.DIM)
		cost.custom_minimum_size.x = 150
		g.add_child(cost)
		var b := _row_button("", func(): Game.hire(role), Vector2(220, 52))
		g.add_child(b)
		_updaters.append(func():
			var problem := Game.hire_problem(role)
			b.disabled = problem != ""
			b.text = "Hire (%d/%d)" % [Game.staff_count(role), Game.staff_limit(role)] if problem == "" else problem
		)

	body.add_child(HSeparator.new())
	if Game.staff.is_empty():
		body.add_child(UI.label("Nobody works here yet.", UI.DIM))
		return
	var team := _grid(4)
	for entry: Dictionary in Game.staff:
		var who := _staff_node(entry.id)
		team.add_child(UI.icon(Game.STAFF[entry.role].texture, Vector2(20, 44)))
		var label := UI.label("%s  -  %s" % [entry.name, Game.STAFF[entry.role].name])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		team.add_child(label)
		var status := UI.label("", UI.INFO)
		status.custom_minimum_size.x = 330
		team.add_child(status)
		_updaters.append(func():
			status.text = who.status_text() if is_instance_valid(who) else ""
		)
		var id: int = entry.id
		var fire := _row_button("Let go", func(): Game.fire(id), Vector2(120, 52))
		fire.add_theme_color_override("font_color", UI.BAD)
		team.add_child(fire)


func _staff_node(id: int) -> Staff:
	if Game.in_game():
		for s: Staff in Game.store.staff:
			if s.id == id:
				return s
	return null


# ---------------------------------------------------------------- upgrades tab

func _build_upgrades() -> void:
	footer_label.text = "Want more shelves, registers or a new look? Press Build (B)."
	var g := _grid(3)
	for id: String in Game.UPGRADES:
		var u: Dictionary = Game.UPGRADES[id]
		g.add_child(UI.icon(u.icon, Vector2(48, 48)))
		var info := UI.label("%s\n%s" % [u.name, u.desc])
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		g.add_child(info)
		if Game.has_upgrade(id):
			var l := UI.label("Owned", UI.GOOD)
			l.custom_minimum_size = Vector2(160, 52)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			g.add_child(l)
		else:
			var b := _row_button("Buy $%d" % int(u.cost), func(): Game.buy_upgrade(id), Vector2(160, 52))
			g.add_child(b)
			_updaters.append(func(): b.disabled = Game.money < u.cost)

	if Game.has_upgrade("scanner"):
		var how := "Press Q next to a shelf to scan it." if not Game.touch_ui else "Stand next to a shelf and press SCAN."
		body.add_child(UI.label(how + " A box of that product is ordered right away.", UI.INFO))
