extends CanvasLayer
## On-screen UI: money, level and clock, the action prompts (or the big
## USE / SCAN buttons on touch screens), messages, the store computer, the
## build bar and the end-of-day summary. Built in code so it's easy to read
## and change. The computer and build bar live in scripts/ui/.

const ComputerMenu := preload("res://scripts/ui/computer_menu.gd")
const BuildBar := preload("res://scripts/ui/build_bar.gd")
const RivalPanel := preload("res://scripts/ui/rival_panel.gd")
const ShopPanel := preload("res://scripts/ui/shop_panel.gd")
const Tutorial := preload("res://scripts/ui/tutorial.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const OptionsMenu := preload("res://scripts/ui/options_menu.gd")
const MARGIN := 14.0
const MAX_MESSAGES := 3
const MESSAGE_SECONDS := 4.0
const FIRST_DAY_MESSAGE_SECONDS := 8.0  # messages stay up longer while you learn

## Tick this in the Inspector (HUD node in main.tscn) to preview the phone
## controls on your PC.
@export var force_touch_ui := false

var is_touch := false
var root: Control
var status_panel: PanelContainer
var money_label: Label
var level_label: Label
var xp_bar: Control  # progress to the next store level
var levelup_panel: PanelContainer  # "Store level 3!" and what it unlocks
var levelup_title: Label
var levelup_list: Label
var levelup_scroll: ScrollContainer  # a long list (several levels at once) scrolls
var shopper_card: PanelContainer  # what the shopper you point at (or stand by) is buying
var shopper_text: Label
var _player_still := 0.0  # seconds since you last moved
var _player_was := Vector2.INF
var _xp_shown := -1.0  # XP the bar showed last frame (to flash red when it drops)
var _xp_flash := 0.0
var _levelup_left := 0.0  # seconds before the level-up panel closes by itself
const LEVELUP_SECONDS := 15.0
var clock_label: Label
var scanner_icon: TextureRect
var mess_label: Label
var fps_label: Label  # Options > Show FPS
var prep_panel: PanelContainer
var tutorial: PanelContainer  # first-day tips
var corner_box: VBoxContainer
var build_button: Button
var prompt_panel: PanelContainer
var prompt_label: Label
var scan_label: Label
var use_button: Button
var scan_button: Button
var run_button: Button  # touch screens: sprint on/off
var message_box: VBoxContainer
var computer: PanelContainer
var rival_panel: PanelContainer
var shop_panel: PanelContainer  # a little shop's wares (the witch's, the vampire's)
var effects_box: VBoxContainer  # brews working right now, under the corner buttons
var _effect_rows := {}  # brew id -> its Label in effects_box
var build_bar: PanelContainer
var pause_menu: PanelContainer
var options: PanelContainer
var pause_button: Button
var dimmer: ColorRect
var summary_panel: PanelContainer
var summary_label: Label
var summary_hint: Label
var next_day_button: Button
var day_over_bar: Button  # "Day 3 is over! Press Space..." along the bottom
var _summary := {}  # the day that just ended, waiting to be shown
var _day_over_since := 0.0  # when the day-over prompt (or the summary) came up, in seconds
const DAY_OVER_WAIT := 1.0  # Space is ignored this long, so a key you were mashing doesn't skip the day
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
	rival_panel = RivalPanel.new()
	root.add_child(rival_panel)
	shop_panel = ShopPanel.new()
	root.add_child(shop_panel)
	effects_box = VBoxContainer.new()
	effects_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_box.add_theme_constant_override("separation", 4)
	root.add_child(effects_box)
	root.move_child(effects_box, 0)
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
	# Panels keep the mouse to themselves: scrolling or clicking on a menu
	# mustn't zoom the view or walk you somewhere behind it.
	for panel: Control in [status_panel, tutorial, computer, rival_panel, shop_panel, build_bar, summary_panel, pause_menu, options, day_over_bar, levelup_panel]:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP

	Game.message.connect(show_message)
	Game.popup.connect(_show_popup)
	Game.item_popup.connect(_show_item_popup)
	Game.prompt_changed.connect(_on_prompt_changed)
	Game.computer_requested.connect(open_computer)
	Game.day_ended.connect(_on_day_ended)
	Game.leveled_up.connect(_on_leveled_up)
	Game.effects_changed.connect(_rebuild_effects)
	Game.shop_requested.connect(func(_id): computer.close(); rival_panel.close())
	_rebuild_effects()
	Game.build_mode.changed.connect(_on_build_changed)

	if is_touch:
		show_message("Tap to walk (RUN to sprint). Tap boxes, shelves and the register to use them.")
	else:
		show_message("WASD to move (hold Shift to sprint), E to use things, B to build. Esc > Options > Controls lists every key.")


func _process(delta: float) -> void:
	money_label.text = "$%.2f" % Game.money
	UI.set_color(money_label, UI.GOOD if Game.money >= 0.0 else UI.BAD)
	level_label.text = "Lv %d" % Game.level
	if Game.xp < _xp_shown - 0.001:
		_xp_flash = 0.6  # losing XP (blood on the floor)
	_xp_shown = Game.xp
	_xp_flash = maxf(0.0, _xp_flash - delta)
	xp_bar.tooltip_text = "Store XP: %d / %d" % [int(Game.xp), int(Game.next_level_xp())] if Game.next_level_xp() > 0.0 else "Store XP: max level"
	xp_bar.queue_redraw()
	if levelup_panel.visible:
		_levelup_left -= delta
		if _levelup_left <= 0.0:
			levelup_panel.visible = false
	var mess: int = Game.store.spills.size()
	mess_label.visible = mess > 0
	if Game.has_effect("crucifix"):
		mess_label.text = "Blood: %d (the crucifix keeps everyone calm)" % mess
	else:
		mess_label.text = "Blood: %d (-%d%% shoppers)" % [mess, roundi((1.0 - Game.store.mess_multiplier()) * 100.0)]
	clock_label.text = "Day %d   %s   %s" % [Game.day, Game.clock_text(), "OPEN" if Game.is_open else "CLOSED"]
	scanner_icon.visible = Game.has_upgrade("scanner")
	fps_label.visible = Settings.show_fps
	if fps_label.visible:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()

	var building: bool = Game.build_mode.active
	var paused := pause_menu.visible or options.visible
	dimmer.visible = paused
	message_box.visible = not paused and not summary_panel.visible  # (it would show through the summary)
	build_button.visible = not building and not summary_panel.visible and not paused
	pause_button.visible = not building and not paused
	var menu_open: bool = computer.visible or rival_panel.visible or shop_panel.visible or summary_panel.visible
	# After closing you can keep working (stock, order, build...) until you
	# press Space for the summary and the next day.
	var summing_up := summary_panel.visible
	day_over_bar.visible = Game.day_over and not _summary.is_empty() and not summing_up and not paused and not building
	tutorial.visible = tutorial.current != "" and not building and not paused and not menu_open and not Game.day_over
	prep_panel.visible = not Game.opened and not Game.day_over and not building and not paused and not tutorial.visible
	prompt_panel.visible = not is_touch and not building and not summing_up and (_prompt[0] != "" or _prompt[2] != "")
	use_button.visible = is_touch and not building and not summing_up and _prompt[0] != ""
	scan_button.visible = is_touch and not building and not summing_up and _prompt[2] != ""
	run_button.visible = is_touch and not building and not paused and not summing_up and not menu_open
	_update_shopper_card(delta, building or paused or menu_open or levelup_panel.visible or Game.day_over)

	# Keep things pinned to the screen edges whatever the window size.
	var s := root.size
	computer.custom_minimum_size = Vector2(minf(1100.0, s.x - 2 * MARGIN), minf(660.0, s.y - 2 * MARGIN))
	rival_panel.custom_minimum_size = Vector2(minf(860.0, s.x - 2 * MARGIN), minf(600.0, s.y - 2 * MARGIN))
	shop_panel.custom_minimum_size = Vector2(minf(820.0, s.x - 2 * MARGIN), minf(560.0, s.y - 2 * MARGIN))
	build_bar.custom_minimum_size.x = minf(1180.0, s.x - 2 * MARGIN)
	_place(status_panel, Vector2(MARGIN, MARGIN))
	_place(prep_panel, Vector2(MARGIN, status_panel.position.y + status_panel.size.y + 8))
	_place(tutorial, Vector2(MARGIN, status_panel.position.y + status_panel.size.y + 8))
	_place(corner_box, Vector2(s.x - corner_box.size.x - MARGIN, MARGIN))
	_place(message_box, Vector2((s.x - message_box.size.x) / 2.0, 70))
	_place(prompt_panel, Vector2((s.x - prompt_panel.size.x) / 2.0, s.y - prompt_panel.size.y - MARGIN))
	_place(use_button, Vector2(s.x - use_button.size.x - MARGIN, s.y - use_button.size.y - MARGIN))
	_place(scan_button, Vector2(s.x - use_button.size.x - scan_button.size.x - 2 * MARGIN, s.y - scan_button.size.y - MARGIN))
	_place(run_button, Vector2(MARGIN, s.y - run_button.size.y - MARGIN))
	_place(computer, (s - computer.size) / 2.0)
	_place(rival_panel, (s - rival_panel.size) / 2.0)
	_place(shop_panel, (s - shop_panel.size) / 2.0)
	effects_box.visible = not effects_box.get_children().is_empty() and not paused
	_place(effects_box, Vector2(s.x - effects_box.size.x - MARGIN, corner_box.position.y + corner_box.size.y + 8))
	for id: String in _effect_rows:
		(_effect_rows[id] as Label).text = "%s  %s" % [Brand.BREWS[id].name, ShopPanel.time_text(float(Game.effects.get(id, 0.0)))]
	_place(build_bar, Vector2((s.x - build_bar.size.x) / 2.0, s.y - build_bar.size.y - MARGIN))
	_place(summary_panel, (s - summary_panel.size) / 2.0)
	# Above whatever is along the bottom (the E prompt, or the big touch buttons).
	var bottom := s.y - MARGIN
	if prompt_panel.visible:
		bottom = prompt_panel.position.y - 8
	elif is_touch:
		bottom = s.y - use_button.size.y - 2 * MARGIN
	_place(day_over_bar, Vector2((s.x - day_over_bar.size.x) / 2.0, bottom - day_over_bar.size.y))
	_place(levelup_panel, Vector2((s.x - levelup_panel.size.x) / 2.0, roundf(s.y * 0.2)))
	_place(pause_menu, (s - pause_menu.size) / 2.0)
	_place(options, (s - options.size) / 2.0)


func _unhandled_input(event: InputEvent) -> void:
	# End of the day: Space (or A, or Enter) shows the summary, then starts
	# the next day. Only a fresh press, a moment after it comes up: never a
	# key held down (or E) from scanning the last shopper.
	if summary_panel.visible and event.is_action_pressed("build"):
		get_viewport().set_input_as_handled()  # not on top of the summary
		return
	if (summary_panel.visible or day_over_bar.visible) and event.is_action_pressed("ui_accept") \
			and not event.is_echo() and not pause_menu.visible and not options.visible:
		get_viewport().set_input_as_handled()
		if _now() - _day_over_since < DAY_OVER_WAIT:
			return
		if summary_panel.visible:
			_on_next_day()
		elif _summary.get("resumed", false):
			_on_next_day()  # nothing to sum up after loading a save
		else:
			show_day_summary()
		return
	if not (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		return
	if Game.build_mode.active:
		return  # build mode handles Esc itself
	get_viewport().set_input_as_handled()
	_back(event.is_action_pressed("pause"))  # B on a controller closes things; only Start/Esc pauses


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


## Esc / back: close the top thing that's open, or (`or_pause`) pause the game.
func _back(or_pause := true) -> void:
	if levelup_panel.visible:
		levelup_panel.visible = false
	elif options.visible:
		options.close()
	elif pause_menu.visible:
		pause_menu.close()
	elif computer.visible:
		computer.back()  # an app back to the desktop, then off
	elif rival_panel.visible:
		rival_panel.close()
	elif shop_panel.visible:
		shop_panel.close()
	elif or_pause:
		open_pause()


func open_pause() -> void:
	computer.close()
	rival_panel.close()
	shop_panel.close()
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
	tw.tween_interval(FIRST_DAY_MESSAGE_SECONDS if Game.day == 1 else MESSAGE_SECONDS)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func open_computer() -> void:
	rival_panel.close()
	shop_panel.close()
	computer.open()


## The brews working right now: icon, name and time left, under the
## corner buttons.
func _rebuild_effects() -> void:
	UI.clear(effects_box)
	_effect_rows.clear()
	for id: String in Game.effects:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_END
		row.add_theme_constant_override("separation", 6)
		var l := _popup_label("", Color(0.85, 0.95, 1.0))
		row.add_child(l)
		var pic := UI.icon(Brand.BREWS[id].icon, Vector2(32, 32))
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pic)
		effects_box.add_child(row)
		_effect_rows[id] = l
	effects_box.reset_size()


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
	xp_bar = Control.new()
	xp_bar.custom_minimum_size = Vector2(130 if is_touch else 110, 20 if is_touch else 16)
	xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	xp_bar.draw.connect(_draw_xp_bar)
	row.add_child(xp_bar)
	clock_label = UI.label()
	row.add_child(clock_label)
	scanner_icon = UI.icon(Game.UPGRADES.scanner.icon, Vector2(24, 24))
	scanner_icon.visible = false
	row.add_child(scanner_icon)
	mess_label = UI.label("", UI.BAD)  # how many spills need mopping (zombie game)
	mess_label.visible = false
	row.add_child(mess_label)
	fps_label = UI.label("", UI.DIM)
	fps_label.visible = false
	row.add_child(fps_label)

	# Morning hint: the clock doesn't start until you flip the sign.
	prep_panel = PanelContainer.new()
	prep_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(prep_panel)
	var how := "tap" if is_touch else "walk over and press E on"
	var hint := UI.label("Store closed. Stock up, then %s the OPEN sign by the door." % how, UI.WARN)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 420
	prep_panel.add_child(hint)
	tutorial = Tutorial.new()
	root.add_child(tutorial)
	_build_levelup_panel()
	_build_shopper_card()


## The bar next to the store level: how close you are to the next one.
## It flashes red while blood on the floor is costing you XP.
func _draw_xp_bar() -> void:
	var r := Rect2(Vector2.ZERO, xp_bar.size)
	xp_bar.draw_rect(r, Color(0.08, 0.08, 0.1))
	var f := Game.level_progress()
	var maxed := Game.next_level_xp() < 0.0
	var fill := Color(0.95, 0.8, 0.4) if maxed else UI.INFO.darkened(0.15)
	if _xp_flash > 0.0:
		fill = fill.lerp(UI.BAD, minf(1.0, _xp_flash * 3.0))
	xp_bar.draw_rect(Rect2(1, 1, (r.size.x - 2) * f, r.size.y - 2), fill)
	xp_bar.draw_rect(r, UI.PANEL_BORDER, false, 1.0)
	var text := "MAX" if maxed else "%d/%d" % [int(Game.xp - Game.level_start_xp()), int(Game.next_level_xp() - Game.level_start_xp())]
	var font := ThemeDB.fallback_font
	var fs := 12 if not is_touch else 15
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2((r.size.x - w) / 2.0, (r.size.y + fs * 0.7) / 2.0)
	xp_bar.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.8))
	xp_bar.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _build_levelup_panel() -> void:
	levelup_panel = PanelContainer.new()
	levelup_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.13, 0.96)
	style.border_color = UI.WARN
	style.set_border_width_all(3)
	style.set_content_margin_all(18)
	levelup_panel.add_theme_stylebox_override("panel", style)
	root.add_child(levelup_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	levelup_panel.add_child(col)
	levelup_title = UI.label("", UI.WARN)
	levelup_title.add_theme_font_size_override("font_size", 34 if is_touch else 30)
	levelup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(levelup_title)
	levelup_list = UI.label()
	levelup_list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	levelup_list.custom_minimum_size.x = 560
	levelup_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	levelup_scroll = ScrollContainer.new()
	levelup_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	levelup_scroll.add_child(levelup_list)
	col.add_child(levelup_scroll)
	var hint := UI.label("License products and buy upgrades at the store computer.", UI.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 560
	col.add_child(hint)
	var ok := UI.button("Nice!", func(): levelup_panel.visible = false, Vector2(160, 52))
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ok)


## The store went up a level (or several): say so, and what you can do now.
func _on_leveled_up(from_level: int, to_level: int) -> void:
	var lines: Array[String] = []
	for lv in range(from_level + 1, to_level + 1):
		if to_level - from_level > 1:
			lines.append("Level %d:" % lv)
		for line in Game.unlocks_at(lv):
			lines.append("  •  " + line)
	levelup_title.text = "STORE LEVEL %d!" % to_level
	levelup_list.text = "\n".join(lines)
	# As tall as the list, up to most of the screen; then it scrolls.
	var fs := levelup_list.get_theme_font_size("font_size")
	var line_h := levelup_list.get_theme_font("font").get_height(fs) + levelup_list.get_theme_constant("line_spacing")
	var max_h := maxf(120.0, root.size.y * 0.75 - 200.0)
	levelup_scroll.custom_minimum_size.y = minf(lines.size() * line_h + 4.0, max_h)
	levelup_scroll.scroll_vertical = 0
	levelup_panel.reset_size()
	levelup_panel.visible = true
	_levelup_left = LEVELUP_SECONDS


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
	# Sprinting on a touch screen: RUN stays on until you tap it again.
	run_button = UI.button("RUN", func(): pass, Vector2(130, 84))
	run_button.toggle_mode = true
	run_button.toggled.connect(func(on: bool):
		Game.player.run_toggle = on
		run_button.text = "RUN: ON" if on else "RUN"
		for state in ["font_color", "font_pressed_color", "font_hover_pressed_color"]:
			run_button.add_theme_color_override(state, UI.WARN if on else Color.WHITE))
	run_button.tooltip_text = "Sprint (Shift)"
	root.add_child(run_button)


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
	summary_hint = UI.label("", UI.DIM)
	summary_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(summary_hint)

	day_over_bar = UI.button("", show_day_summary, Vector2(560, 64))
	day_over_bar.visible = false
	day_over_bar.add_theme_color_override("font_color", UI.WARN)
	root.add_child(day_over_bar)


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
		rival_panel.close()
		shop_panel.close()


func _show_popup(world_pos: Vector2, text: String, color: Color) -> void:
	_float_up(_popup_label(text, color), world_pos)


## "+2 Canned Guts" and its picture: a shopper took something off a shelf.
func _show_item_popup(world_pos: Vector2, id: String, qty: int) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	var pic := TextureRect.new()
	pic.texture = Game.icon(id)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = pic.texture.get_size() * (3.0 if is_touch else 2.0)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pic)
	row.add_child(_popup_label("+%d %s" % [qty, Game.product_name(id)], Color(0.72, 1.0, 0.66)))
	_float_up(row, world_pos + Vector2(0, -8))


func _popup_label(text: String, color: Color) -> Label:
	var l := UI.label(text, color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_font_size_override("font_size", 20 if is_touch else 16)
	return l


## Shows `c` over `world_pos`, drifting up and fading away.
func _float_up(c: Control, world_pos: Vector2) -> void:
	root.add_child(c)
	root.move_child(c, 0)  # under all the menus and panels
	c.reset_size()
	var screen := get_viewport().get_canvas_transform() * world_pos
	c.position = (screen - Vector2(c.size.x / 2.0, c.size.y)).round()
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "position:y", c.position.y - 30.0, 1.2)
	tw.tween_property(c, "modulate:a", 0.0, 0.8).set_delay(0.4)
	tw.chain().tween_callback(c.queue_free)


func _build_shopper_card() -> void:
	shopper_card = PanelContainer.new()
	shopper_card.visible = false
	shopper_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.09, 0.9)
	style.border_color = Color(0.45, 0.75, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	shopper_card.add_theme_stylebox_override("panel", style)
	root.add_child(shopper_card)
	root.move_child(shopper_card, 0)  # under the menus
	shopper_text = UI.label()
	shopper_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shopper_text.add_theme_font_size_override("font_size", 17 if is_touch else 15)
	shopper_card.add_child(shopper_text)


## The shopper card: what the shopper under the mouse (or the one right
## next to you, once you stop) has in their basket and still wants.
func _update_shopper_card(delta: float, hidden: bool) -> void:
	var p: Player = Game.player
	if p.position.distance_to(_player_was) > 0.5:
		_player_still = 0.0
	else:
		_player_still += delta
	_player_was = p.position
	var c: Customer = null if hidden else shopper_of_interest()
	shopper_card.visible = c != null
	if c == null:
		return
	shopper_text.text = c.describe()
	shopper_card.reset_size()
	var head := get_viewport().get_canvas_transform() * c.head_position()
	var s := root.size
	var pos := Vector2(head.x - shopper_card.size.x / 2.0, head.y - shopper_card.size.y)
	pos.x = clampf(pos.x, MARGIN, maxf(MARGIN, s.x - shopper_card.size.x - MARGIN))
	pos.y = clampf(pos.y, MARGIN, maxf(MARGIN, s.y - shopper_card.size.y - MARGIN))
	shopper_card.position = pos.round()


## The shopper the mouse is over (the one in front, if they overlap), or
## else the closest one right next to you once you've stopped moving.
func shopper_of_interest() -> Customer:
	var store: Store = Game.store
	if not is_touch:
		var m := store.get_global_mouse_position()
		var front: Customer = null
		for c: Customer in store.customers:
			if is_instance_valid(c) and c.pick_rect().has_point(m) and (front == null or c.position.y > front.position.y):
				front = c
		if front:
			return front
	if _player_still < 0.3:
		return null
	var p: Player = Game.player
	var best: Customer = null
	var best_d := INF
	for c: Customer in store.customers:
		if is_instance_valid(c) and Iso.chebyshev(p.current_cell(), c.current_cell()) <= 1:
			var d := p.position.distance_to(c.position)
			if d < best_d:
				best_d = d
				best = c
	return best


## The last shopper has left: ask before showing how the day went.
func _on_day_ended(s: Dictionary) -> void:
	_summary = s
	_day_over_since = _now()
	if s.get("resumed", false):
		day_over_bar.text = "Day %d is over.  %s to start Day %d." % [s.day, _key_hint("here"), s.day + 1]
	else:
		day_over_bar.text = "Day %d is over!  %s when you're ready to see how you did." % [s.day, _key_hint("here")]


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## "Press Space" / "Press A" / "Tap here", for whatever you play with.
## `tap_what` is what to tap on a touch screen.
func _key_hint(tap_what: String) -> String:
	if not Input.get_connected_joypads().is_empty():
		return "Press A" if not is_touch else "Press A (or tap %s)" % tap_what
	if is_touch:
		return "Tap %s" % tap_what
	return "Press Space"


func show_day_summary() -> void:
	if _summary.get("resumed", false):
		_on_next_day()
	elif not _summary.is_empty():
		_day_over_since = _now()
		_show_summary(_summary)


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
		"Went to %s instead: %d" % [Brand.RIVAL.name, s.get("lost", 0)],
		_wanted_line(s.get("wanted", {})),
		_spies_line(s),
		"Your spy's reports: %d" % int(s.get("spy_reports", 0)) if int(s.get("spy_reports", 0)) > 0 else "--",
		"Blood mopped up: %d" % s.cleaned,
		"XP lost to blood on the floor: %d" % roundi(float(s.get("xp_lost", 0.0))),
		"",
		"Store level %d" % Game.level,
	].filter(func(line: String): return (Brand.SPILLS or not line.begins_with("Blood")) \
		and (not line.begins_with("Went to") or s.get("lost", 0) > 0) \
		and (not line.begins_with("XP lost") or roundi(float(s.get("xp_lost", 0.0))) > 0) \
		and line != "--"))
	next_day_button.text = "Go to Day %d" % (s.day + 1)
	summary_hint.text = "" if is_touch and Input.get_connected_joypads().is_empty() else "%s to go to Day %d" % [_key_hint("the button"), s.day + 1]
	summary_hint.visible = summary_hint.text != ""
	summary_panel.visible = true


## "Bone Mart's spies: 1 thrown out, 1 got away", or "--" if none came.
static func _spies_line(s: Dictionary) -> String:
	var caught := int(s.get("spies_caught", 0))
	var away := int(s.get("spies_escaped", 0))
	if caught + away == 0:
		return "--"
	var parts: Array[String] = []
	if caught > 0:
		parts.append("%d thrown out" % caught)
	if away > 0:
		parts.append("%d got away" % away)
	return "%s's spies: %s" % [Brand.RIVAL.name, ", ".join(parts)]


## "Asked for things you don't sell: 5 (Brains x3, Lungs x2)", or "--"
## (left out) if nobody did.
static func _wanted_line(wanted: Dictionary) -> String:
	if wanted.is_empty():
		return "--"
	var total := 0
	var parts: Array[String] = []
	for id: String in wanted:
		total += int(wanted[id])
		parts.append("%s x%d" % [Game.product_name(id), int(wanted[id])])
	return "Asked for things you don't sell: %d (%s)" % [total, ", ".join(parts)]


func _on_next_day() -> void:
	summary_panel.visible = false
	_summary = {}
	Game.start_next_day()
