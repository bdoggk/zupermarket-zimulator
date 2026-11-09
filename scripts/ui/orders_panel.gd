extends PanelContainer
## The notice board in the town square (0.20, NoticeBoard): today's special
## orders from the houses on the south side of town (SpecialOrders). Take
## up to two at a time, then bring each house a box of what it wants before
## 6 PM. What you've taken shows under today's goals, with an arrow pointing
## the way while you're carrying the right box.

var title: Label
var hello: Label
var grid: GridContainer
var footer: Label
var close_button: Button
var _updaters: Array[Callable] = []
var _first_take: Button


func _ready() -> void:
	visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	title = UI.label("SPECIAL ORDERS", UI.WARN)
	title.add_theme_font_size_override("font_size", 26)
	col.add_child(title)
	hello = UI.label("", UI.DIM)
	hello.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hello)
	col.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	col.add_child(HSeparator.new())
	footer = UI.label("", UI.DIM)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(footer)
	close_button = UI.menu_button("Close", close, Vector2(140, 52))
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(close_button)
	Game.orders_requested.connect(open)


func open() -> void:
	visible = true
	_rebuild()
	if UI.wants_focus():
		(_first_take if _first_take else close_button).grab_focus.call_deferred()


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
	_first_take = null
	var orders := Game.orders
	hello.text = "Pinned to the board, in shaky handwriting. Take up to %d at a time, carry a box of what they want to their door before %s, and they pay well over the odds." \
		% [SpecialOrders.TAKE_MAX, Game.clock_text_at(SpecialOrders.DUE)]
	for o: Dictionary in orders.list:
		var h := SpecialOrders.house(o.house)
		var pic := UI.icon(Game.icon(o.product), Vector2(40, 48))
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		grid.add_child(pic)
		var info := UI.label("%s: %s\n\"%s\"  (%s)" % [_first_up(str(h.who)), SpecialOrders.amount(o), o.line, h.place])
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.custom_minimum_size.x = 320
		grid.add_child(info)
		var pay := UI.label("$%d\n+%d XP" % [int(o.pay), int(o.xp)], UI.GOOD)
		pay.custom_minimum_size.x = 80
		grid.add_child(pay)
		var take := UI.menu_button("", func():
			if orders.take(o):
				Settings.vibrate(0.2, 0.06), Vector2(180, 52))
		take.mouse_filter = Control.MOUSE_FILTER_PASS  # (a drag that starts on it still scrolls the list)
		grid.add_child(take)
		if _first_take == null and orders.can_take(o):
			_first_take = take
		_updaters.append(func():
			var why := _state(o)
			take.disabled = why != ""
			take.text = "Take it" if why == "" else why
			UI.set_color(info, UI.DIM if o.done or o.late else Color.WHITE)
		)
	if orders.list.is_empty():
		grid.add_child(Control.new())
		grid.add_child(UI.label("Nothing on the board today. Check again tomorrow morning.", UI.DIM))
	_updaters.append(func():
		var n := orders.open_orders().size()
		footer.text = "Taken: %d of %d. Grab a box from a delivery, or take one off a shelf (use it with nothing in your hands), then use the house's door." % [n, SpecialOrders.TAKE_MAX]
	)


## Why you can't take order `o` right now ("" if you can).
func _state(o: Dictionary) -> String:
	if o.done:
		return "Delivered"
	if o.late:
		return "Too late"
	if o.taken:
		return "Taken"
	if Game.minute >= SpecialOrders.DUE:
		return "Too late today"
	if Game.orders.open_orders().size() >= SpecialOrders.TAKE_MAX:
		return "%d at a time" % SpecialOrders.TAKE_MAX
	return ""


static func _first_up(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)
