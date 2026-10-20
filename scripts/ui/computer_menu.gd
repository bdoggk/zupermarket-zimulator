extends PanelContainer
## The store computer: a little PC running "ZombOS". It opens on the
## desktop (a zombie girl on a graveyard wallpaper, with the day's news on a
## sticky note); click an app icon, or its button on the taskbar, to open it
## in a window:
##   Stock & Prices  order boxes and set your prices (market prices change!),
##                   and see the rival's prices you've checked
##   Products        buy licenses to sell new products as your store levels up
##   Staff           hire stockers, cashiers, janitors and a general manager
##                   (paid every evening); reset anyone who's stuck
##   Upgrades        one-time purchases like the handheld scanner, faster
##                   deliveries and a bigger delivery zone
## The window's X goes back to the desktop; "Close PC" (or Esc) closes it.

enum Tab { STOCK, PRODUCTS, STAFF, UPGRADES }

const TAB_NAMES := ["Stock & Prices", "Products", "Staff", "Upgrades"]
const APP_ICONS := ["stock", "products", "staff", "upgrades"]
const TASKBAR_HEIGHT := 50.0
const WALLPAPER := preload("res://assets/sprites/pc_wallpaper.png")
const GIRL := preload("res://assets/sprites/pc_girl.png")
const SKULL := preload("res://assets/sprites/pc_skull.png")
const SCREEN_BG := Color(0.05, 0.05, 0.07)
const TITLE_BAR := Color(0.24, 0.42, 0.28)
const NOTE_COLOR := Color(0.96, 0.9, 0.55)

var tab := Tab.STOCK
var level_label: Label
var money_label: Label
var clock_label: Label
var news_label: Label
var footer_label: Label
var match_button: Button
var auto_button: CheckButton
var markup_row: HBoxContainer  # Stock & Prices: [<] +10% [>]
var markup_label: Label
var tab_buttons: Array[Button] = []  # the apps on the taskbar
var desktop_icons: Array[Button] = []
var screen: Control
var desktop: Control
var window: PanelContainer
var window_title: Label
var window_icon: TextureRect
var girl: TextureRect
var note_label: Label
var scroll: ScrollContainer
var body: VBoxContainer
var _updaters: Array[Callable] = []  # refresh numbers every frame
var price_fields: Array[LineEdit] = []  # Stock & Prices: type a price in
var _rebuild_later := false  # something changed while you were typing a price
var window_close: Button  # the app window's X


func _ready() -> void:
	visible = false
	var bezel := StyleBoxFlat.new()  # the monitor around the screen
	bezel.bg_color = Color(0.17, 0.17, 0.19)
	bezel.border_color = Color(0.08, 0.08, 0.09)
	bezel.set_border_width_all(3)
	bezel.set_corner_radius_all(16)
	bezel.content_margin_left = 18
	bezel.content_margin_right = 18
	bezel.content_margin_top = 16
	bezel.content_margin_bottom = 8
	add_theme_stylebox_override("panel", bezel)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 6)
	add_child(frame)

	var glass := PanelContainer.new()  # the screen itself
	var glass_style := StyleBoxFlat.new()
	glass_style.bg_color = SCREEN_BG
	glass_style.border_color = Color(0.03, 0.03, 0.04)
	glass_style.set_border_width_all(4)
	glass_style.set_corner_radius_all(6)
	glass.add_theme_stylebox_override("panel", glass_style)
	glass.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(glass)
	screen = Control.new()
	screen.clip_contents = true
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.resized.connect(_fit_girl)
	glass.add_child(screen)
	_build_desktop()
	_build_window()
	_build_taskbar()

	var chin := HBoxContainer.new()  # the bottom of the monitor: a brand and a power light
	chin.alignment = BoxContainer.ALIGNMENT_CENTER
	chin.add_theme_constant_override("separation", 10)
	frame.add_child(chin)
	var brand := UI.label("ZOMBO", Color(0.55, 0.55, 0.6))
	brand.add_theme_font_size_override("font_size", 14)
	chin.add_child(brand)
	var led := ColorRect.new()
	led.color = Color(0.4, 1.0, 0.45)
	led.custom_minimum_size = Vector2(8, 8)
	led.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chin.add_child(led)

	Game.unlocks_changed.connect(_rebuild_if_open)
	Game.market_changed.connect(_rebuild_if_open)
	Game.staff_changed.connect(_rebuild_if_open)


## The home screen: wallpaper, the girl, app icons and a sticky note.
func _build_desktop() -> void:
	desktop = Control.new()
	desktop.set_anchors_preset(Control.PRESET_FULL_RECT)
	desktop.offset_bottom = -TASKBAR_HEIGHT
	screen.add_child(desktop)
	var wall := TextureRect.new()
	wall.texture = WALLPAPER
	wall.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wall.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	wall.set_anchors_preset(Control.PRESET_FULL_RECT)
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desktop.add_child(wall)
	girl = TextureRect.new()
	girl.texture = GIRL
	girl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	girl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	girl.stretch_mode = TextureRect.STRETCH_SCALE
	girl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desktop.add_child(girl)

	var logo := UI.label("ZombOS", Color(0.85, 0.8, 1.0, 0.55))
	logo.add_theme_font_size_override("font_size", 26)
	logo.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	logo.position = Vector2(-150, 10)
	desktop.add_child(logo)

	var icons := VBoxContainer.new()
	icons.position = Vector2(14, 12)
	icons.add_theme_constant_override("separation", 6)
	desktop.add_child(icons)
	for i in TAB_NAMES.size():
		var b := Button.new()
		b.text = TAB_NAMES[i]
		b.icon = load("res://assets/sprites/pc_app_%s.png" % APP_ICONS[i])
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.custom_minimum_size = Vector2(132, 104)
		b.add_theme_constant_override("icon_max_width", 64)
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.focus_mode = Control.FOCUS_ALL
		_style_desktop_icon(b)
		b.pressed.connect(show_tab.bind(i))
		icons.add_child(b)
		desktop_icons.append(b)

	var note := PanelContainer.new()  # a sticky note with the day's news
	var note_style := StyleBoxFlat.new()
	note_style.bg_color = NOTE_COLOR
	note_style.shadow_color = Color(0, 0, 0, 0.35)
	note_style.shadow_size = 4
	note_style.shadow_offset = Vector2(3, 3)
	note_style.set_content_margin_all(12)
	note.add_theme_stylebox_override("panel", note_style)
	note.position = Vector2(170, 14)
	note.custom_minimum_size = Vector2(300, 0)
	desktop.add_child(note)
	note_label = UI.label("", Color(0.2, 0.16, 0.1))
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label.custom_minimum_size.x = 276
	note.add_child(note_label)


func _style_desktop_icon(b: Button) -> void:
	var clear := StyleBoxEmpty.new()
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.6, 0.7, 1.0, 0.18)
	hover.border_color = Color(0.7, 0.8, 1.0, 0.45)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(4)
	var focus := hover.duplicate() as StyleBoxFlat
	focus.border_color = UI.WARN
	focus.set_border_width_all(2)
	focus.draw_center = false
	for state in ["normal", "disabled"]:
		b.add_theme_stylebox_override(state, clear)
	for state in ["hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, hover)
	b.add_theme_stylebox_override("focus", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, Color.WHITE)
	b.add_theme_constant_override("outline_size", 5)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))


## The girl stands in the bottom right corner, as big as fits (in whole
## pixels so she stays sharp).
func _fit_girl() -> void:
	if girl == null:
		return
	var room := screen.size.y - TASKBAR_HEIGHT
	var scale := clampi(floori(room * 0.92 / GIRL.get_height()), 1, 5)
	var sz := Vector2(GIRL.get_width(), GIRL.get_height()) * scale
	girl.size = sz
	girl.position = Vector2(screen.size.x - sz.x - 24, room - sz.y)


## An app's window: title bar with an X, then the app, then its footer.
func _build_window() -> void:
	window = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UI.PANEL_BG, 1.0)  # solid: the desktop shouldn't show through
	style.border_color = Color(0.5, 0.56, 0.62)
	style.set_border_width_all(2)
	style.set_content_margin_all(0)
	window.add_theme_stylebox_override("panel", style)
	window.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.offset_left = 10
	window.offset_top = 8
	window.offset_right = -10
	window.offset_bottom = -TASKBAR_HEIGHT - 8
	window.visible = false
	screen.add_child(window)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	window.add_child(col)

	var bar := PanelContainer.new()
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = TITLE_BAR
	bar_style.set_content_margin_all(4)
	bar_style.content_margin_left = 8
	bar.add_theme_stylebox_override("panel", bar_style)
	col.add_child(bar)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	bar.add_child(title_row)
	window_icon = UI.icon(null, Vector2(28, 28))
	title_row.add_child(window_icon)
	window_title = UI.label("")
	window_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(window_title)
	var x := UI.button("X", go_home, Vector2(44, 36))
	window_close = x
	x.tooltip_text = "Back to the desktop"
	var x_style := StyleBoxFlat.new()
	x_style.bg_color = Color(0.7, 0.22, 0.2)
	x_style.set_corner_radius_all(3)
	x.add_theme_stylebox_override("normal", x_style)
	var x_hover := x_style.duplicate() as StyleBoxFlat
	x_hover.bg_color = Color(0.85, 0.3, 0.26)
	x.add_theme_stylebox_override("hover", x_hover)
	x.add_theme_stylebox_override("pressed", x_hover)
	title_row.add_child(x)

	var inside := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inside.add_theme_constant_override("margin_" + side, 12)
	inside.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(inside)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	inside.add_child(content)
	news_label = UI.label("", UI.WARN)
	content.add_child(news_label)
	content.add_child(HSeparator.new())
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true  # (a controller moving down the list)
	content.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	content.add_child(HSeparator.new())
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	content.add_child(footer)
	footer_label = UI.label("", UI.DIM)
	footer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(footer_label)
	# One markup for every price, instead of setting each one.
	markup_row = HBoxContainer.new()
	markup_row.add_theme_constant_override("separation", 4)
	footer.add_child(markup_row)
	var down := UI.button("<", func(): _change_markup(-Game.MARKUP_STEP), Vector2(44, 52))
	down.tooltip_text = "Lower markup"
	markup_row.add_child(down)
	markup_label = UI.label("", UI.WARN)
	markup_label.custom_minimum_size.x = 104
	markup_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	markup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	markup_row.add_child(markup_label)
	var up := UI.button(">", func(): _change_markup(Game.MARKUP_STEP), Vector2(44, 52))
	up.tooltip_text = "Higher markup"
	markup_row.add_child(up)
	match_button = UI.button("Set all prices", func():
		Game.match_all_prices()
		_rebuild_if_open(), Vector2(0, 52))
	match_button.tooltip_text = "Every price: the market price plus your markup"
	footer.add_child(match_button)
	auto_button = CheckButton.new()
	auto_button.text = "Auto"
	auto_button.tooltip_text = "Keep every price at the market price plus your markup, as the market moves"
	auto_button.focus_mode = Control.FOCUS_NONE
	auto_button.button_pressed = Game.auto_price
	auto_button.toggled.connect(_on_auto_toggled)
	footer.add_child(auto_button)


## Along the bottom of the screen: Home, the apps, the time and Close PC.
func _build_taskbar() -> void:
	var taskbar := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.11, 0.97)
	style.border_color = Color(0.32, 0.34, 0.4)
	style.border_width_top = 2
	style.set_content_margin_all(4)
	taskbar.add_theme_stylebox_override("panel", style)
	taskbar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	taskbar.offset_top = -TASKBAR_HEIGHT
	screen.add_child(taskbar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	taskbar.add_child(row)
	var home := UI.button("Home", go_home, Vector2(0, 40))
	home.icon = SKULL
	home.tooltip_text = "The desktop"
	row.add_child(home)
	row.add_child(VSeparator.new())
	var group := ButtonGroup.new()
	group.allow_unpress = true
	for i in TAB_NAMES.size():
		var b := UI.button(TAB_NAMES[i], show_tab.bind(i), Vector2(0, 40))
		b.icon = load("res://assets/sprites/pc_app_%s.png" % APP_ICONS[i])
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 24)
		b.toggle_mode = true
		b.button_group = group
		row.add_child(b)
		tab_buttons.append(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	level_label = UI.label("", UI.INFO)
	row.add_child(level_label)
	money_label = UI.label("", UI.GOOD)
	row.add_child(money_label)
	clock_label = UI.label("")
	row.add_child(clock_label)
	var off := UI.button("Close PC", close, Vector2(0, 40))
	off.add_theme_color_override("font_color", UI.BAD)
	row.add_child(off)


## The markup: < and > in Stock & Prices.
func _change_markup(step: float) -> void:
	Game.set_markup(Game.price_markup + step)
	_refresh_markup()


func _refresh_markup() -> void:
	markup_label.text = "Markup\n" + Game.markup_text(Game.price_markup)
	if tab == Tab.STOCK:
		footer_label.text = Game.markup_effect(Game.price_markup)


## Auto: your prices follow the market (plus your markup) every time it changes.
func _on_auto_toggled(on: bool) -> void:
	Game.auto_price = on
	if on:
		Game.match_all_prices()


## Turns the computer on: the desktop.
func open() -> void:
	visible = true
	go_home()
	_fit_girl.call_deferred()


func close() -> void:
	visible = false


## Esc / back: from an app back to the desktop, then closes the computer.
func back() -> void:
	if window.visible:
		go_home()
	else:
		close()


## Closes the app window, back to the desktop.
func go_home() -> void:
	window.visible = false
	for b in tab_buttons:
		b.set_pressed_no_signal(false)
	_refresh_note()
	if visible and UI.wants_focus():
		desktop_icons[tab].grab_focus.call_deferred()


## Opens app `t` in the window.
func show_tab(t: Tab) -> void:
	tab = t
	for i in tab_buttons.size():
		tab_buttons[i].set_pressed_no_signal(i == t)
	window_title.text = TAB_NAMES[t]
	window_icon.texture = desktop_icons[t].icon
	window.visible = true
	UI.pad_focus(auto_button)  # (a controller may have been plugged in since)
	UI.pad_focus(match_button)
	_rebuild()
	scroll.scroll_vertical = 0


func is_app_open() -> bool:
	return visible and window.visible


func _refresh_note() -> void:
	var lines: Array[String] = ["DAY %d" % Game.day, ""]
	lines.append(Game.market.news if Game.market.news != "" else "No big news today.")
	var wanted: Dictionary = Game.stats.get("wanted", {})
	if not wanted.is_empty():
		var top := wanted.keys()
		top.sort_custom(func(a, b): return wanted[a] > wanted[b])
		lines.append("")
		lines.append("Townsfolk asked for: %s" % ", ".join(top.slice(0, 3).map(func(id): return Game.product_name(id))))
	var low: Array = Game.store.products_running_low(Staff.REORDER_AT) if Game.in_game() else []
	if not low.is_empty():
		lines.append("")
		lines.append("Running low: %s" % ", ".join(low.slice(0, 4).map(func(id): return Game.product_name(id))))
	note_label.text = "\n".join(lines)


func _process(_delta: float) -> void:
	if not visible:
		return
	money_label.text = "$%.2f" % Game.money
	var next := Game.next_level_xp()
	if next < 0:
		level_label.text = "Lv %d (max)" % Game.level
	else:
		level_label.text = "Lv %d  %d/%d XP" % [Game.level, int(Game.xp - Game.level_start_xp()), int(next - Game.level_start_xp())]
	clock_label.text = Game.clock_text()
	if window.visible:
		for u in _updaters:
			u.call()


func _rebuild_if_open() -> void:
	if visible and window.visible:
		if _typing_price():
			_rebuild_later = true  # not out from under you mid-price
			return
		_rebuild()
	elif visible:
		_refresh_note()


## The buttons in the app, top to bottom (a controller can pick these).
func _body_buttons() -> Array[Control]:
	var out: Array[Control] = []
	var stack: Array[Node] = [body]
	while not stack.is_empty():
		var n: Node = stack.pop_front()
		for c in n.get_children():
			if c is BaseButton and (c as Control).focus_mode == Control.FOCUS_ALL and not c.is_queued_for_deletion():
				out.append(c)
			stack.append(c)
	return out


## After the app was rebuilt: select button `i` again (or the first one).
func _refocus(i: int) -> void:
	if not visible or not window.visible:
		return
	var buttons := _body_buttons()
	if buttons.is_empty():
		var f := UI.first_focusable(window)
		if f == null:  # nothing to press in this app right now: the X, then
			UI.pad_focus(window_close)
			f = window_close
		f.grab_focus()
		return
	buttons[clampi(i, 0, buttons.size() - 1)].grab_focus()


## You're typing a price into Stock & Prices right now.
func _typing_price() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit and f in price_fields


func _rebuild() -> void:
	# With a controller, keep the selection where it was in the list.
	var was := -1
	var had := get_viewport().gui_get_focus_owner()
	if had and body.is_ancestor_of(had):
		was = _body_buttons().find(had)
	UI.clear(body)
	_updaters.clear()
	price_fields.clear()
	if UI.has_pad() and visible:
		_refocus.call_deferred(was)
	news_label.text = "NEWS: " + Game.market.news if Game.market.news != "" else "No big news today."
	match_button.visible = tab == Tab.STOCK
	auto_button.visible = tab == Tab.STOCK
	markup_row.visible = tab == Tab.STOCK
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
	UI.pad_focus(b)
	return b


# ---------------------------------------------------------------- stock tab

## A box you can type a price into (Enter, or click away, to set it). The
## - and + buttons next to it still work, and are what a controller uses.
func _price_field(id: String) -> LineEdit:
	var f := LineEdit.new()
	f.custom_minimum_size = Vector2(100, 46)
	f.alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.max_length = 9
	f.select_all_on_focus = Game.touch_ui  # a mouse click puts the cursor where you clicked; a tap selects it all
	f.focus_mode = Control.FOCUS_CLICK  # controllers use - and + (no getting stuck in a text box)
	f.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	f.tooltip_text = "Type a price and press Enter"
	f.text_submitted.connect(func(_t: String): f.release_focus())
	f.focus_exited.connect(func(): _apply_typed_price(id, f))
	price_fields.append(f)
	return f


func _apply_typed_price(id: String, f: LineEdit) -> void:
	var v := Game.parse_price(f.text)
	if v >= 0.0:
		Game.set_price(id, v)
	f.text = "$%.2f" % Game.prices[id]  # tidied up (or put back, if it wasn't a price)
	if _rebuild_later:
		_rebuild_later = false
		_rebuild_if_open.call_deferred()


## Clicking anywhere else finishes typing a price.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and visible:
		var f := get_viewport().gui_get_focus_owner()
		if f is LineEdit and f in price_fields and not f.get_global_rect().has_point(f.get_global_mouse_position()):
			f.release_focus()

func _build_stock() -> void:
	var rival := Game.store.town != null and not Game.rival_owned
	_refresh_markup()
	var g := _grid(9 if rival else 8)
	var heads := ["", "Product", "Market", "", "Your price", "", "", ""]
	if rival:
		heads.insert(3, Brand.RIVAL.name)
	for h in heads:
		g.add_child(UI.label(h, UI.DIM))
	for id: String in Game.unlocked_ids():
		g.add_child(UI.icon(Game.icon(id), Vector2(32, 40)))

		var info := UI.label()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(info)

		var market := UI.label()
		market.custom_minimum_size.x = 96
		g.add_child(market)
		var theirs: Label = null
		if rival:
			theirs = UI.label("", UI.DIM)
			theirs.custom_minimum_size.x = 104
			g.add_child(theirs)

		g.add_child(_row_button("-", func(): Game.change_price(id, -Game.PRICE_STEP)))
		var price := _price_field(id)
		g.add_child(price)
		g.add_child(_row_button("+", func(): Game.change_price(id, Game.PRICE_STEP)))
		var eq := _row_button("=", func(): Game.match_market(id))
		eq.tooltip_text = "The market price plus your markup"
		g.add_child(eq)
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
			if not price.has_focus():  # don't type over what you're typing
				price.text = "$%.2f" % p
			price.add_theme_color_override("font_color", UI.BAD if p > m * 1.25 else (UI.WARN if p > m + 0.001 else UI.GOOD))
			order.disabled = Game.money < Game.box_cost(id)
			if theirs:
				var seen: Array = Game.rival_seen.get(id, [])
				if seen.is_empty():
					theirs.text = "?\nnot checked"
					UI.set_color(theirs, UI.DIM)
				else:
					var when := "today" if int(seen[1]) == Game.day else "day %d" % int(seen[1])
					theirs.text = "$%.2f\n%s" % [float(seen[0]), when]
					UI.set_color(theirs, UI.GOOD if p <= float(seen[0]) + 0.001 else UI.BAD)
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
	# Why license more: more shoppers, XP, and the ones asking for it.
	var bonus := roundi(Store.variety_bonus() * 100.0)
	var why := UI.label("Every product you license brings %d%% more %s (up to %d%%; you're at +%d%%) and earns XP. %s who can't find what they want may go to %s instead." % [
		roundi(Store.VARIETY_TRAFFIC * 100.0), Brand.SAY.shoppers, roundi(Store.VARIETY_MAX * 100.0), bonus,
		Brand.SAY.shoppers.capitalize(), Brand.RIVAL.get("name", "another store")], UI.INFO)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(why)
	var wanted: Dictionary = Game.stats.get("wanted", {})
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
		if Game.fans_text(id) != "":
			name_text += "\n%s: stock it to bring more in" % Game.fans_text(id)
		if not owned and int(wanted.get(id, 0)) > 0:
			name_text += "\nAsked for today by %s!" % Game.askers_text(id)
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
			var b := _row_button("License $%d  (+%d XP)" % [int(p.license), roundi(p.license * Game.LICENSE_XP)], func(): Game.buy_license(id), Vector2(240, 52))
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
	var boost := "" if not Game.STAFF.has("manager") else " A %s makes everyone else %d%% faster too." % [Game.STAFF.manager.name.to_lower(), roundi((Staff.MANAGED_BOOST - 1.0) * 100.0)]
	var note := UI.label("Staff level up as they work. Every level makes them %d%% faster.%s If someone gets stuck, Reset sends them back to their starting spot." % [roundi(Game.STAFF_SPEED_PER_LEVEL * 100.0), boost], UI.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(note)
	var team := _grid(5)
	for entry: Dictionary in Game.staff:
		var who := _staff_node(entry.id)
		team.add_child(UI.icon(Game.STAFF[entry.role].texture, Vector2(20, 44)))
		var label := UI.label()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		team.add_child(label)
		var status := UI.label("", UI.INFO)
		status.custom_minimum_size.x = 300
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # a long one wraps instead of widening the window
		team.add_child(status)
		_updaters.append(func():
			status.text = who.status_text() if is_instance_valid(who) else ""
			var lv: int = entry.level
			var next := Game.staff_next_xp(lv)
			var progress := "max level" if next < 0 else "%d/%d XP" % [int(entry.xp), int(next)]
			var faster := roundi(((who.speed if is_instance_valid(who) else Game.staff_speed(lv)) - 1.0) * 100.0)
			label.text = "%s  -  %s\nLevel %d (%s)%s" % [entry.name, Game.STAFF[entry.role].name, lv, progress,
				", %d%% faster" % faster if faster > 0 else ""]
		)
		var id: int = entry.id
		var reset := _row_button("Reset", func():
			var w := _staff_node(id)
			if is_instance_valid(w):
				w.reset_to_start(), Vector2(110, 52))
		reset.tooltip_text = "Stuck? Sends them back to their starting spot."
		team.add_child(reset)
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
	footer_label.text = "Want more shelves, registers, a new look or a bigger store? Press Build%s." % ("" if Game.touch_ui else " (B)")
	var g := _grid(3)
	for id: String in Game.UPGRADES:
		var u: Dictionary = Game.UPGRADES[id]
		g.add_child(UI.icon(u.icon, Vector2(48, 48)))
		var info := UI.label("%s\n%s" % [u.name, u.desc])
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		g.add_child(info)
		var problem := Game.upgrade_problem(id)
		if Game.has_upgrade(id):
			var l := UI.label("Owned", UI.GOOD)
			l.custom_minimum_size = Vector2(220, 52)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			g.add_child(l)
		elif problem != "":
			var l := UI.label("%s  ($%d)" % [problem, int(u.cost)], UI.DIM)
			l.custom_minimum_size = Vector2(220, 52)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			g.add_child(l)
		else:
			var b := _row_button("Buy $%d" % int(u.cost), func(): Game.buy_upgrade(id), Vector2(220, 52))
			g.add_child(b)
			_updaters.append(func(): b.disabled = Game.money < u.cost)

	if Game.has_upgrade("scanner"):
		var how := "Press Q next to a shelf to scan it." if not Game.touch_ui else "Stand next to a shelf and press SCAN."
		body.add_child(UI.label(how + " A box of that product is ordered right away.", UI.INFO))
	var t := Game.delivery_seconds()
	body.add_child(UI.label("Deliveries take %s right now." % ("%d seconds" % roundi(t) if t >= 1.5 else "about a second"), UI.DIM))
