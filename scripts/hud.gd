extends CanvasLayer
## On-screen UI: money, level and clock, the action prompts (or the big
## USE / SCAN buttons on touch screens), messages, the store computer, the
## build bar and the end-of-day summary. Built in code so it's easy to read
## and change. The computer and build bar live in scripts/ui/.

const ComputerMenu := preload("res://scripts/ui/computer_menu.gd")
const BuildBar := preload("res://scripts/ui/build_bar.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const OptionsMenu := preload("res://scripts/ui/options_menu.gd")
const MARGIN := 14.0
const MAX_MESSAGES := 3
const MESSAGE_SECONDS := 4.0

## Tick this in the Inspector (HUD node in main.tscn) to preview the phone
## controls on your PC.
@export var force_touch_ui := false

var is_touch := false
var root: Control
var status_panel: PanelContainer
var money_label: Label
var level_label: Label
var clock_label: Label
var scanner_icon: TextureRect
var mess_label: Label
var prep_panel: PanelContainer
var corner_box: VBoxContainer
var build_button: Button
var prompt_panel: PanelContainer
var prompt_label: Label
var scan_label: Label
var use_button: Button
var scan_button: Button
var message_box: VBoxContainer
var computer: PanelContainer
var build_bar: PanelContainer
var pause_menu: PanelContainer
var options: PanelContainer
var pause_button: Button
var dimmer: ColorRect
var summary_panel: PanelContainer
var summary_label: Label
var next_day_button: Button
var _prompt := ["", false, ""]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps working in build mode
	is_touch = force_touch_ui or DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	Game.touch_ui = is_touch
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.make_theme(is_touch)
	add_child(root)

	_build_status()
	_build_corner_buttons()
	_build_prompt()
	message_box = VBoxContainer.new()
	message_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(message_box)
	computer = ComputerMenu.new()
	root.add_child(computer)
	build_bar = BuildBar.new()
	root.add_child(build_bar)
	_build_summary_panel()
	dimmer = ColorRect.new()  # darkens the game behind the pause menu
	dimmer.color = Color(0, 0, 0, 0.55)
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.visible = false
	root.add_child(dimmer)
	pause_menu = PauseMenu.new()
	root.add_child(pause_menu)
	pause_menu.options_requested.connect(_open_options)
	options = OptionsMenu.new()
	root.add_child(options)
	options.closed.connect(_on_options_closed)

	Game.message.connect(show_message)
	Game.popup.connect(_show_popup)
	Game.prompt_changed.connect(_on_prompt_changed)
	Game.computer_requested.connect(open_computer)
	Game.day_ended.connect(_show_summary)
	Game.build_mode.changed.connect(_on_build_changed)

	if is_touch:
		show_message("Tap to walk. Tap boxes, shelves and the register to use them.")
	else:
		show_message("WASD to move, E to use things, B to build. You can also click to walk.")


func _process(_delta: float) -> void:
	money_label.text = "$%.2f" % Game.money
	UI.set_color(money_label, UI.GOOD if Game.money >= 0.0 else UI.BAD)
	level_label.text = "Lv %d" % Game.level
	var mess: int = Game.store.spills.size()
	mess_label.visible = mess > 0
	mess_label.text = "Blood: %d" % mess
	clock_label.text = "Day %d   %s   %s" % [Game.day, Game.clock_text(), "OPEN" if Game.is_open else "CLOSED"]
	scanner_icon.visible = Game.has_upgrade("scanner")

	var building: bool = Game.build_mode.active
	var paused := pause_menu.visible or options.visible
	dimmer.visible = paused
	message_box.visible = not paused
	build_button.visible = not building and not summary_panel.visible and not paused
	pause_button.visible = not building and not paused
	prep_panel.visible = not Game.opened and not Game.day_over and not building and not paused
	prompt_panel.visible = not is_touch and not building and (_prompt[0] != "" or _prompt[2] != "")
	use_button.visible = is_touch and not building and _prompt[0] != ""
	scan_button.visible = is_touch and not building and _prompt[2] != ""

	# Keep things pinned to the screen edges whatever the window size.
	var s := root.size
	computer.custom_minimum_size = Vector2(minf(1100.0, s.x - 2 * MARGIN), minf(660.0, s.y - 2 * MARGIN))
	build_bar.custom_minimum_size.x = minf(1180.0, s.x - 2 * MARGIN)
	_place(status_panel, Vector2(MARGIN, MARGIN))
	_place(prep_panel, Vector2(MARGIN, status_panel.position.y + status_panel.size.y + 8))
	_place(corner_box, Vector2(s.x - corner_box.size.x - MARGIN, MARGIN))
	_place(message_box, Vector2((s.x - message_box.size.x) / 2.0, 70))
	_place(prompt_panel, Vector2((s.x - prompt_panel.size.x) / 2.0, s.y - prompt_panel.size.y - MARGIN))
	_place(use_button, Vector2(s.x - use_button.size.x - MARGIN, s.y - use_button.size.y - MARGIN))
	_place(scan_button, Vector2(s.x - use_button.size.x - scan_button.size.x - 2 * MARGIN, s.y - scan_button.size.y - MARGIN))
	_place(computer, (s - computer.size) / 2.0)
	_place(build_bar, Vector2((s.x - build_bar.size.x) / 2.0, s.y - build_bar.size.y - MARGIN))
	_place(summary_panel, (s - summary_panel.size) / 2.0)
	_place(pause_menu, (s - pause_menu.size) / 2.0)
	_place(options, (s - options.size) / 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if not (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		return
	if Game.build_mode.active:
		return  # build mode handles Esc itself
	get_viewport().set_input_as_handled()
	_back()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:  # Android back button
			if Game.build_mode.active:
				Game.build_mode.exit()
			else:
				_back()
		NOTIFICATION_APPLICATION_PAUSED:  # phone app sent to the background
			if not Game.build_mode.active and not pause_menu.visible and not options.visible:
				open_pause()


## Esc / back: close the top thing that's open, or pause the game.
func _back() -> void:
	if options.visible:
		options.close()
	elif pause_menu.visible:
		pause_menu.close()
	elif computer.visible:
		computer.close()
	else:
		open_pause()


func open_pause() -> void:
	computer.close()
	pause_menu.open()


func _open_options() -> void:
	pause_menu.hide_for_options()
	options.open()


func _on_options_closed() -> void:
	pause_menu.show_again()


## Shows a message at the top of the screen. Up to 3 at once; old ones fade.
func show_message(text: String) -> void:
	var l := UI.label(text)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	message_box.add_child(l)
	while message_box.get_child_count() > MAX_MESSAGES:
		var old := message_box.get_child(0)
		message_box.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(MESSAGE_SECONDS)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func open_computer() -> void:
	computer.open()


# ---------------------------------------------------------------- building

func _build_status() -> void:
	status_panel = PanelContainer.new()
	root.add_child(status_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	status_panel.add_child(row)
	money_label = UI.label("", UI.GOOD)
	row.add_child(money_label)
	level_label = UI.label("", UI.INFO)
	row.add_child(level_label)
	clock_label = UI.label()
	row.add_child(clock_label)
	scanner_icon = UI.icon(Game.UPGRADES.scanner.icon, Vector2(24, 24))
	scanner_icon.visible = false
	row.add_child(scanner_icon)
	mess_label = UI.label("", UI.BAD)  # how many spills need mopping (zombie game)
	mess_label.visible = false
	row.add_child(mess_label)

	# Morning hint: the clock doesn't start until you flip the sign.
	prep_panel = PanelContainer.new()
	prep_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(prep_panel)
	var how := "tap" if is_touch else "walk over and press E on"
	var hint := UI.label("Store closed. Stock up, then %s the OPEN sign by the door." % how, UI.WARN)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 420
	prep_panel.add_child(hint)


func _build_corner_buttons() -> void:
	corner_box = VBoxContainer.new()
	root.add_child(corner_box)
	var zoom_row := HBoxContainer.new()
	zoom_row.alignment = BoxContainer.ALIGNMENT_END
	corner_box.add_child(zoom_row)
	for z in [["-", 0.8], ["+", 1.25]]:
		var factor: float = z[1]
		zoom_row.add_child(UI.button(z[0], func(): Game.player.zoom_by(factor), Vector2(56, 56)))
	pause_button = UI.button("II", open_pause, Vector2(56, 56))
	zoom_row.add_child(pause_button)
	build_button = UI.button("Build" if is_touch else "Build (B)", func(): Game.build_mode.enter(), Vector2(0, 56))
	corner_box.add_child(build_button)


func _build_prompt() -> void:
	prompt_panel = PanelContainer.new()
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(prompt_panel)
	var col := VBoxContainer.new()
	prompt_panel.add_child(col)
	prompt_label = UI.label()
	col.add_child(prompt_label)
	scan_label = UI.label("", UI.INFO)
	col.add_child(scan_label)

	use_button = UI.button("", func(): Game.player.try_interact(), Vector2(300, 84))
	use_button.clip_text = true
	use_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	root.add_child(use_button)
	scan_button = UI.button("", func(): Game.player.try_scan(), Vector2(280, 84))
	scan_button.clip_text = true
	scan_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	scan_button.add_theme_color_override("font_color", UI.INFO)
	root.add_child(scan_button)


func _build_summary_panel() -> void:
	summary_panel = PanelContainer.new()
	summary_panel.visible = false
	root.add_child(summary_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	summary_panel.add_child(col)
	summary_label = UI.label()
	col.add_child(summary_label)
	next_day_button = UI.button("Next day", _on_next_day, Vector2(240, 56))
	next_day_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(next_day_button)


# ---------------------------------------------------------------- updates

func _place(c: Control, pos: Vector2) -> void:
	if c.visible:
		c.reset_size()
		c.position = pos.round()


func _on_prompt_changed(text: String, can_act: bool, scan_text: String) -> void:
	_prompt = [text, can_act, scan_text]
	prompt_label.text = ("[E]  " + text) if can_act else text
	prompt_label.modulate.a = 1.0 if can_act else 0.7
	prompt_label.visible = text != ""
	scan_label.text = "[Q]  " + scan_text
	scan_label.visible = scan_text != ""
	use_button.text = text
	use_button.disabled = not can_act
	scan_button.text = "SCAN  +1 box\n" + scan_text.trim_prefix("Scan: order ")


func _on_build_changed() -> void:
	if Game.build_mode.active:
		computer.close()


func _show_popup(world_pos: Vector2, text: String, color: Color) -> void:
	var l := UI.label(text, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_font_size_override("font_size", 20 if is_touch else 16)
	root.add_child(l)
	root.move_child(l, message_box.get_index())  # under the menus and panels
	l.reset_size()
	var screen := get_viewport().get_canvas_transform() * world_pos
	l.position = (screen - Vector2(l.size.x / 2.0, l.size.y)).round()
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 30.0, 1.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


func _show_summary(s: Dictionary) -> void:
	summary_label.text = "\n".join([
		"DAY %d COMPLETE" % s.day,
		"",
		"Sales: $%.2f" % s.revenue,
		"Stock bought: $%.2f" % s.spent,
		"Store upgrades: $%.2f" % s.invested,
		"Staff wages: $%.2f" % s.wages,
		"Profit: $%.2f" % s.profit,
		"",
		"%s served: %d" % [Brand.SAY.shoppers.capitalize(), s.customers],
		"Items sold: %d" % s.items_sold,
		"Missed sales: %d" % s.missed,
		"Walked out: %d" % s.walkouts,
		"Blood mopped up: %d" % s.cleaned,
		"",
		"Store level %d" % Game.level,
	].filter(func(line: String): return Brand.SPILLS or not line.begins_with("Blood")))
	next_day_button.text = "Go to Day %d" % (s.day + 1)
	summary_panel.visible = true


func _on_next_day() -> void:
	summary_panel.visible = false
	Game.start_next_day()
