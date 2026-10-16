extends PanelContainer
## First-day tips. All through day 1 this box shows one tip at a time and
## keeps it up until you've done it (or press Next tip), then moves on to
## the next. "Hide tips" turns them off for this game. Which tips you've
## done is saved (Game.tutorial).

## In order. A tip shows once the ones before it are done (some wait for
## the right moment, see _ready_for).
const STEPS := ["box", "stock", "open", "register", "mop", "order", "labels", "build", "town"]

var current := ""  # the tip showing now ("" = none)
var title: Label
var text: Label


func _ready() -> void:
	visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	title = UI.label("", UI.WARN)
	col.add_child(title)
	text = UI.label()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 440
	col.add_child(text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	row.add_child(UI.button("Next tip", _skip, Vector2(0, 44)))
	row.add_child(UI.button("Hide tips", _hide_all, Vector2(0, 44)))
	Game.box_ordered.connect(func(_id): Game.tutorial_step_done("order"))


func _process(_delta: float) -> void:
	if Game.day != 1 or Game.tutorial_hidden or not Game.in_game() or Game.player == null:
		current = ""
		return
	_check_done()
	current = ""
	for step in STEPS:
		if not Game.tutorial.has(step) and _ready_for(step):
			current = step
			break
	if current != "":
		title.text = "FIRST DAY TIPS  (%d of %d)" % [STEPS.find(current) + 1, STEPS.size()]
		text.text = _text(current)


## Marks tips done by looking at what's happened in the game.
func _check_done() -> void:
	var store: Store = Game.store
	var p: Player = Game.player
	if p.is_carrying():
		Game.tutorial_step_done("box")
	if store.shelves.any(func(s): return s.stock > 0):
		Game.tutorial_step_done("box")
		Game.tutorial_step_done("stock")
	if Game.opened:
		Game.tutorial_step_done("open")
	if Game.stats.customers > 0:
		Game.tutorial_step_done("register")
	if Game.stats.cleaned > 0:
		Game.tutorial_step_done("mop")
	if not store.pending_deliveries.is_empty():
		Game.tutorial_step_done("order")
	if store.town and not store.floor_cells.has(p.current_cell()):
		Game.tutorial_step_done("town")


## Some tips wait for the right moment.
func _ready_for(step: String) -> bool:
	match step:
		"register":
			return Game.opened
		"mop":
			return Brand.SPILLS and not Game.store.spills.is_empty()
		"labels":
			return Game.tutorial.has("stock")
		"town":
			return Game.store.town != null
	return true


func _text(step: String) -> String:
	var use := _use_word()
	var use_cap := use[0].to_upper() + use.substr(1)
	match step:
		"box":
			return "Boxes of stock arrive on the yellow-striped delivery zone in the back. Walk over and %s a box to pick it up." % use
		"stock":
			return "Carry the box to a shelf and %s the shelf to stock it. The shelf gets a label (the little sign on top), so only that product goes there and your stockers know what to refill it with." % use
		"open":
			return "Ready? %s the OPEN sign by the front door. The clock starts and the %s come in." % [use_cap, Brand.SAY.shoppers]
		"register":
			return "%s line up at the register with what they grabbed. %s the register to scan their items and get paid. Don't keep them waiting!" % [Brand.SAY.shoppers.capitalize(), use_cap]
		"mop":
			return "Blood on the floor keeps shoppers away! Grab the mop from the yellow bucket, %s the puddles to mop them up, then put the mop back." % use
		"order":
			return "Shelves running low? %s the computer in the back, open Stock & Prices on its desktop and order more boxes." % use_cap
		"labels":
			return "Want a shelf for something else? With empty hands, %s it to take its items off into a box, then %s the empty shelf again to peel off its label." % [use, use]
		"build":
			if Game.touch_ui and Input.get_connected_joypads().is_empty():
				return "Tap Build to buy more shelves, meat coolers, storage racks and more. You can move things around there too."
			return "Press %s to go into Build mode: buy more shelves, meat coolers, storage racks and more, and move things around." % ("Y" if not Input.get_connected_joypads().is_empty() else "B")
		"town":
			return "Some %s shop at %s down the street. Walk out the front door to check its prices, then beat them!" % [Brand.SAY.shoppers, Brand.RIVAL.name]
	return ""


## How to "use" something on this device.
func _use_word() -> String:
	if not Input.get_connected_joypads().is_empty():
		return "press A at"
	if Game.touch_ui:
		return "tap"
	return "press E at"


func _skip() -> void:
	if current != "":
		Game.tutorial_step_done(current)


func _hide_all() -> void:
	Game.tutorial_hidden = true
	Game.message.emit("Tips hidden.")
