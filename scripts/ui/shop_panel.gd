extends PanelContainer
## A market stall's wares (use its counter in town): the witch's potions
## and wine, the vampire's garlic, crucifixes and stakes (Brand.SHOPS and
## Brand.BREWS). Each one works straight away for a little while; buying
## another adds more time. What's working right now shows by the clock
## (the HUD's effects list).

var shop := ""
var title: Label
var hello: Label
var grid: GridContainer
var close_button: Button
var _updaters: Array[Callable] = []
var _first_buy: Button


func _ready() -> void:
	visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	title = UI.label("", UI.WARN)
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
	var footer := UI.label("It works straight away. Buying another adds more time.", UI.DIM)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(footer)
	close_button = UI.menu_button("Close", close, Vector2(140, 52))
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	col.add_child(close_button)
	Game.shop_requested.connect(open)


func open(id: String) -> void:
	shop = id
	visible = true
	_rebuild()
	if UI.wants_focus():
		(_first_buy if _first_buy else close_button).grab_focus.call_deferred()


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
	_first_buy = null
	var s: Dictionary = Brand.SHOPS[shop]
	title.text = s.name.to_upper()
	hello.text = "%s: \"%s\"  %s" % [s.keeper, s.hello, s.blurb]
	for id: String in Brand.BREWS:
		var b: Dictionary = Brand.BREWS[id]
		if b.shop != shop:
			continue
		var pic := UI.icon(b.icon, Vector2(48, 48))
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		grid.add_child(pic)
		var info := UI.label("%s\n%s" % [b.name, b.desc])
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.custom_minimum_size.x = 300
		grid.add_child(info)
		var left := UI.label("", UI.GOOD)
		left.custom_minimum_size.x = 96
		grid.add_child(left)
		var buy := UI.menu_button("", func(): Game.buy_brew(id), Vector2(170, 52))
		grid.add_child(buy)
		if _first_buy == null:
			_first_buy = buy
		_updaters.append(func():
			var t := float(Game.effects.get(id, 0.0))
			left.text = "Working:\n%s" % time_text(t) if t > 0.0 else ""
			var problem := Game.brew_problem(id)
			buy.disabled = problem != ""
			buy.text = "Buy  $%d" % int(b.cost) if problem == "" else problem
		)


## 75.2 -> "1:15"
static func time_text(seconds: float) -> String:
	var s := ceili(seconds)
	return "%d:%02d" % [s / 60, s % 60]
