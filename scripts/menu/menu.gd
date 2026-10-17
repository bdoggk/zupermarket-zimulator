extends Node
## The main menu: Continue, New Game, Load Game, Options and Quit.
## Continue loads whichever of the 3 save slots was played most recently.
## A card beside the menu shows updates (see Updater): the download's
## progress, then Restart now (Windows) or Download (Android).

const OptionsMenu := preload("res://scripts/ui/options_menu.gd")
const TITLE := preload("res://assets/sprites/title.png")
const TITLE_SCALE := 7
const UPDATE_WIDTH := 340.0

enum Screen { MAIN, NEW, LOAD, CONFIRM, OPTIONS }

var screen := Screen.MAIN
var root: Control
var main_panel: PanelContainer
var main_box: VBoxContainer
var continue_button: Button
var new_button: Button
var load_button: Button
var version_label: Label
var slots_panel: PanelContainer
var slots_title: Label
var slots_list: VBoxContainer
var slots_back: Button
var confirm_panel: PanelContainer
var confirm_label: Label
var confirm_yes: Button
var confirm_no: Button
var options: PanelContainer
var update_panel: PanelContainer
var update_label: Label
var update_headline: Label
var update_bar: ProgressBar
var update_button: Button
var _confirm_action := Callable()
var _confirm_return := Screen.MAIN


func _ready() -> void:
	Game.reset()
	get_tree().paused = false
	var touch := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	Game.touch_ui = touch

	var layer := CanvasLayer.new()
	add_child(layer)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.make_theme(touch)
	layer.add_child(root)

	_build_main()
	_build_slots()
	_build_confirm()
	options = OptionsMenu.new()
	root.add_child(options)
	options.closed.connect(func(): show_screen(Screen.MAIN))
	version_label = UI.label(Updater.version_text(), UI.DIM)
	root.add_child(version_label)
	_build_update()
	Updater.changed.connect(_refresh_update)
	show_screen(Screen.MAIN)
	Updater.check_again_if_failed()


func _process(_delta: float) -> void:
	var s := root.size
	_place(main_panel, Vector2((s.x - main_panel.size.x) / 2.0, maxf(10.0, (s.y - main_panel.size.y) / 2.0)))
	_place(slots_panel, (s - slots_panel.size) / 2.0)
	_place(confirm_panel, (s - confirm_panel.size) / 2.0)
	_place(options, (s - options.size) / 2.0)
	_place(version_label, s - version_label.size - Vector2(14, 10))
	_place_update(s)


## Beside the menu when there's room, otherwise over the top of it.
func _place_update(s: Vector2) -> void:
	if not update_panel.visible:
		return
	var right := main_panel.position.x + main_panel.size.x
	var room := s.x - right - 40.0
	update_panel.custom_minimum_size.x = clampf(room, 260.0, UPDATE_WIDTH)
	update_panel.reset_size()
	var pos := Vector2(right + 20.0, main_panel.position.y)
	if room < 260.0:
		pos = Vector2((s.x - update_panel.size.x) / 2.0, 10.0)
	update_panel.position = pos.round()


func _place(c: Control, pos: Vector2) -> void:
	if c.visible:
		c.reset_size()
		c.position = pos.round()


func _input(event: InputEvent) -> void:
	# A controller was used but nothing is highlighted yet: highlight something.
	if UI.is_pad_input(event) and get_viewport().gui_get_focus_owner() == null:
		match screen:
			Screen.MAIN:
				(continue_button if not continue_button.disabled else new_button).grab_focus()
			Screen.NEW, Screen.LOAD:
				slots_back.grab_focus()
			Screen.CONFIRM:
				confirm_no.grab_focus()
			Screen.OPTIONS:
				options.focus_first()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:  # Android back button
		if screen == Screen.MAIN:
			get_tree().quit()
		else:
			_back()


func _back() -> void:
	match screen:
		Screen.CONFIRM:
			show_screen(_confirm_return)
		Screen.OPTIONS:
			options.close()
		Screen.NEW, Screen.LOAD:
			show_screen(Screen.MAIN)


# ---------------------------------------------------------------- screens

func show_screen(s: Screen) -> void:
	screen = s
	main_panel.visible = s == Screen.MAIN
	slots_panel.visible = s == Screen.NEW or s == Screen.LOAD
	confirm_panel.visible = s == Screen.CONFIRM
	if s != Screen.OPTIONS and options.visible:
		options.visible = false
	_refresh_update()
	match s:
		Screen.MAIN:
			_refresh_main()
			_focus(continue_button if not continue_button.disabled else new_button)
		Screen.NEW, Screen.LOAD:
			_refresh_slots()
		Screen.CONFIRM:
			_focus(confirm_no)
		Screen.OPTIONS:
			options.open()


func _focus(c: Control) -> void:
	if UI.wants_focus() and c:
		c.grab_focus.call_deferred()


func _build_main() -> void:
	main_panel = PanelContainer.new()  # see-through dark backing so it reads over the store
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.055, 0.07, 0.6)
	bg.set_content_margin_all(28)
	bg.set_corner_radius_all(6)
	main_panel.add_theme_stylebox_override("panel", bg)
	root.add_child(main_panel)
	main_box = VBoxContainer.new()
	main_box.add_theme_constant_override("separation", 10)
	main_panel.add_child(main_box)
	var title := UI.icon(TITLE, Vector2(TITLE.get_width(), TITLE.get_height()) * TITLE_SCALE)
	main_box.add_child(title)
	var tagline := UI.label(Brand.TAGLINE, UI.DIM)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_box.add_child(tagline)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_box.add_child(col)
	continue_button = UI.menu_button("Continue", _on_continue, Vector2(380, 76))
	col.add_child(continue_button)
	new_button = UI.menu_button("New Game", func(): show_screen(Screen.NEW))
	col.add_child(new_button)
	load_button = UI.menu_button("Load Game", func(): show_screen(Screen.LOAD))
	col.add_child(load_button)
	col.add_child(UI.menu_button("Options", func(): show_screen(Screen.OPTIONS)))
	if Settings.is_desktop():
		col.add_child(UI.menu_button("Quit", func(): get_tree().quit()))


func _build_update() -> void:
	update_panel = PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.055, 0.07, 0.85)
	bg.border_color = UI.WARN.darkened(0.3)
	bg.set_border_width_all(2)
	bg.set_content_margin_all(18)
	bg.set_corner_radius_all(6)
	update_panel.add_theme_stylebox_override("panel", bg)
	update_panel.visible = false
	root.add_child(update_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	update_panel.add_child(col)
	var title := UI.label("UPDATE", UI.WARN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	update_label = UI.label()
	update_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(update_label)
	update_headline = UI.label("", UI.DIM)
	update_headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(update_headline)
	update_bar = ProgressBar.new()
	update_bar.max_value = 1.0
	update_bar.show_percentage = false
	update_bar.custom_minimum_size.y = 14
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.2, 0.21, 0.24)
	track.set_corner_radius_all(4)
	update_bar.add_theme_stylebox_override("background", track)
	var fill := track.duplicate()
	fill.bg_color = UI.WARN.darkened(0.25)
	update_bar.add_theme_stylebox_override("fill", fill)
	col.add_child(update_bar)
	update_button = UI.menu_button("", func(): Updater.do_action(), Vector2(0, 56))
	col.add_child(update_button)


func _refresh_update() -> void:
	version_label.text = Updater.version_text()
	var text := Updater.status_text()
	update_panel.visible = text != "" and screen == Screen.MAIN
	if text == "":
		return
	update_label.text = text
	update_headline.text = Updater.headline
	update_headline.visible = Updater.headline != "" and Updater.state != Updater.State.FAILED
	update_bar.visible = Updater.state in [Updater.State.DOWNLOADING, Updater.State.VERIFYING]
	update_bar.value = Updater.progress() if Updater.state == Updater.State.DOWNLOADING else 1.0
	var action := Updater.action_text()
	update_button.visible = action != ""
	update_button.text = action


func _build_slots() -> void:
	var parts := UI.titled_panel("")
	slots_panel = parts[0]
	var col: VBoxContainer = parts[1]
	slots_title = col.get_child(0)
	root.add_child(slots_panel)
	slots_list = VBoxContainer.new()
	slots_list.add_theme_constant_override("separation", 10)
	col.add_child(slots_list)
	col.add_child(HSeparator.new())
	slots_back = UI.menu_button("Back", func(): show_screen(Screen.MAIN), Vector2(0, 56))
	col.add_child(slots_back)


func _build_confirm() -> void:
	var parts := UI.titled_panel("ARE YOU SURE?")
	confirm_panel = parts[0]
	var col: VBoxContainer = parts[1]
	root.add_child(confirm_panel)
	confirm_label = UI.label()
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_label.custom_minimum_size.x = 520
	confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(confirm_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	confirm_yes = UI.menu_button("Yes", func(): _confirm_action.call(), Vector2(240, 60))
	confirm_yes.add_theme_color_override("font_color", UI.BAD)
	row.add_child(confirm_yes)
	confirm_no = UI.menu_button("Cancel", func(): show_screen(_confirm_return), Vector2(240, 60))
	row.add_child(confirm_no)


func _ask(text: String, yes_text: String, action: Callable) -> void:
	_confirm_return = screen
	_confirm_action = action
	confirm_label.text = text
	confirm_yes.text = yes_text
	show_screen(Screen.CONFIRM)


# ---------------------------------------------------------------- contents

func _refresh_main() -> void:
	var latest := Saves.latest_slot()
	continue_button.disabled = latest < 0
	if latest >= 0:
		var info := Saves.slot_info(latest)
		continue_button.text = "Continue\nSlot %d  -  Day %d" % [latest + 1, info.day]
	else:
		continue_button.text = "Continue\nNo saved games yet"
	var any := false
	for i in Saves.SLOTS:
		var info := Saves.slot_info(i)
		any = any or (not info.is_empty() and not info.has("damaged"))
	load_button.disabled = not any


func _refresh_slots() -> void:
	var loading := screen == Screen.LOAD
	slots_title.text = "LOAD GAME" if loading else "NEW GAME - PICK A SLOT"
	UI.clear(slots_list)
	var first: Control = null
	for i in Saves.SLOTS:
		var info := Saves.slot_info(i)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		slots_list.add_child(row)
		var b := UI.menu_button(_slot_text(i, info), func(): _on_slot(i), Vector2(600, 84))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var usable := not info.is_empty() and not info.has("damaged")
		b.disabled = loading and not usable
		row.add_child(b)
		if not info.is_empty():
			var del := UI.menu_button("Delete", func(): _on_delete(i), Vector2(120, 84))
			del.add_theme_color_override("font_color", UI.BAD)
			row.add_child(del)
		if first == null and not b.disabled:
			first = b
	_focus(first if first else slots_back)


func _slot_text(i: int, info: Dictionary) -> String:
	if info.is_empty():
		return "SLOT %d\nEmpty" % (i + 1)
	if info.has("damaged"):
		return "SLOT %d\nThis save can't be read" % (i + 1)
	return "SLOT %d    Day %d   $%.2f   Level %d\nSaved %s   -   %s played" % [
		i + 1, info.day, info.money, info.level, Saves.format_date(info.saved_at), Saves.format_play_time(info.play_time)]


func _on_continue() -> void:
	Saves.continue_game()


func _on_slot(i: int) -> void:
	var info := Saves.slot_info(i)
	if screen == Screen.LOAD:
		Saves.load_game(i)
	elif info.is_empty():
		Saves.new_game(i)
	else:
		var what := "Day %d" % info.day if not info.has("damaged") else "a damaged save"
		_ask("Slot %d already has a game (%s).\nStart a new game there? The old one will be deleted." % [i + 1, what],
			"Start over", func(): Saves.new_game(i))


func _on_delete(i: int) -> void:
	_ask("Delete the game in slot %d? This can't be undone." % (i + 1), "Delete", func():
		Saves.delete_slot(i)
		show_screen(_confirm_return)
	)
