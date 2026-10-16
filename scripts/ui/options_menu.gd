extends PanelContainer
## The Options screen: display mode, window size (PC), frame rate, graphics
## level, VSync, an FPS counter, sound volume and vibration. Changes apply right away and
## are saved. "Controls" shows every key and button (ControlsList). Used by
## the main menu and the in-game pause menu.

signal closed

const ROW_SEPARATION := 8

var settings_page: VBoxContainer
var controls_page: VBoxContainer
var settings_scroll: ScrollContainer
var controls_scroll: ScrollContainer
var mode_value: Label
var mode_info: Label
var res_value: Label
var res_left: Button
var res_right: Button
var fps_value: Label
var gfx_value: Label
var gfx_info: Label
var vsync_check: CheckButton
var vsync_info: Label
var fps_check: CheckButton
var vol_slider: HSlider
var vol_value: Label
var _preview: AudioStreamPlayer  # a growl so you can hear how loud it is
var vib_check: CheckButton
var vib_note: Label
var controls_button: Button
var back_button: Button
var controls_back: Button
var _first: Control


func _ready() -> void:
	visible = false
	custom_minimum_size.x = 680
	var stack := VBoxContainer.new()
	add_child(stack)
	_build_settings(stack)
	_build_controls(stack)
	Settings.changed.connect(_refresh)


func _build_settings(parent: Control) -> void:
	settings_page = VBoxContainer.new()
	settings_page.add_theme_constant_override("separation", 12)
	parent.add_child(settings_page)
	var title := UI.label("OPTIONS", UI.WARN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_page.add_child(title)
	settings_page.add_child(HSeparator.new())

	settings_scroll = ScrollContainer.new()
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_scroll.follow_focus = true
	settings_page.add_child(settings_scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", ROW_SEPARATION)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_scroll.add_child(col)

	if Settings.is_desktop():
		var mode := _selector(col, "Display", _change_mode)
		mode_value = mode[0]
		mode_info = _info(col)
		var res := _selector(col, "Window size", _change_resolution)
		res_value = res[0]
		res_left = res[1]
		res_right = res[2]

	fps_value = _selector(col, "Frame rate", _change_fps)[0]
	vsync_check = _check(col, "VSync", func(on: bool): Settings.set_vsync(on))
	vsync_info = _info(col)
	fps_check = _check(col, "Show FPS", func(on: bool): Settings.set_show_fps(on))

	gfx_value = _selector(col, "Graphics", _change_graphics)[0]
	gfx_info = _info(col)

	var vol := _slider(col, "Sound", func(v: float):
		Settings.set_volume(v / 100.0)
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_play_preview())  # moved with the keyboard or a controller
	vol_slider = vol[0]
	vol_value = vol[1]
	vol_slider.drag_ended.connect(func(_changed: bool): _play_preview())
	vib_check = _check(col, "Vibration", func(on: bool): Settings.set_vibration(on))
	vib_note = _info(col)

	settings_page.add_child(HSeparator.new())
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	settings_page.add_child(buttons)
	controls_button = UI.menu_button("Controls", show_controls, Vector2(0, 56))
	controls_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(controls_button)
	back_button = UI.menu_button("Back", close, Vector2(0, 56))
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(back_button)


func _build_controls(parent: Control) -> void:
	controls_page = VBoxContainer.new()
	controls_page.add_theme_constant_override("separation", 12)
	controls_page.visible = false
	parent.add_child(controls_page)
	var title := UI.label("CONTROLS", UI.WARN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_page.add_child(title)
	controls_page.add_child(HSeparator.new())
	controls_scroll = ScrollContainer.new()
	controls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	controls_page.add_child(controls_scroll)
	controls_scroll.add_child(ControlsList.build(Game.touch_ui or Settings.is_mobile()))
	controls_page.add_child(HSeparator.new())
	controls_back = UI.menu_button("Back", show_settings, Vector2(0, 56))
	controls_page.add_child(controls_back)


func open() -> void:
	visible = true
	show_settings()


func focus_first() -> void:
	if controls_page.visible:
		controls_back.grab_focus()
	else:
		_first.grab_focus()


## The list of controls (Back returns to the settings).
func show_controls() -> void:
	settings_page.visible = false
	controls_page.visible = true
	controls_scroll.scroll_vertical = 0
	_fit()
	if UI.wants_focus():
		controls_back.grab_focus()


func show_settings() -> void:
	var from_controls := controls_page.visible
	controls_page.visible = false
	settings_page.visible = true
	_refresh()
	if UI.wants_focus():
		(controls_button if from_controls else _first).grab_focus()
	if not from_controls:
		settings_scroll.set_deferred("scroll_vertical", 0)  # start at the top


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if controls_page.visible:
		# The list itself can't be selected, so up/down scroll it.
		for dir: String in ["ui_up", "ui_down"]:
			if event.is_action_pressed(dir, true):
				controls_scroll.scroll_vertical += 60 if dir == "ui_down" else -60
				get_viewport().set_input_as_handled()
				return
	if UI.is_pad_input(event) and get_viewport().gui_get_focus_owner() == null:
		focus_first()
		get_viewport().set_input_as_handled()


## Esc / Back: from the controls list back to the settings, otherwise close.
func close() -> void:
	if controls_page.visible:
		show_settings()
		return
	visible = false
	closed.emit()


## Keeps the panel on the screen: the lists scroll when the window is small.
func _fit() -> void:
	var h := get_viewport_rect().size.y
	var room := clampf(h - 230.0, 240.0, 560.0)
	settings_scroll.custom_minimum_size = Vector2(640, minf(room, settings_scroll.get_child(0).get_combined_minimum_size().y))
	controls_scroll.custom_minimum_size = Vector2(800, room)


## A row like:  Graphics   [<]   Medium   [>]
## Returns [value label, left button, right button].
func _selector(parent: Control, text: String, on_change: Callable) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var name_label := UI.label(text)
	name_label.custom_minimum_size.x = 190
	row.add_child(name_label)
	var left := UI.menu_button("<", func(): on_change.call(-1), Vector2(56, 52))
	row.add_child(left)
	var value := UI.label()
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	var right := UI.menu_button(">", func(): on_change.call(1), Vector2(56, 52))
	row.add_child(right)
	if _first == null:
		_first = right
	return [value, left, right]


## A row like:  Sound   [=======O-----]  60%
## Drag it, or select it and press left/right (keyboard or controller).
## Returns [slider, value label].
func _slider(parent: Control, text: String, on_change: Callable) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var name_label := UI.label(text)
	name_label.custom_minimum_size.x = 190
	row.add_child(name_label)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(0, 40)
	s.focus_mode = Control.FOCUS_ALL
	s.scrollable = false  # the mouse wheel scrolls the page, not the slider
	var track := StyleBoxFlat.new()  # a thicker bar that's easy to grab on a touch screen
	track.bg_color = Color(0.2, 0.21, 0.24)
	track.set_corner_radius_all(4)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	s.add_theme_stylebox_override("slider", track)
	var filled := track.duplicate()
	filled.bg_color = UI.WARN.darkened(0.25)
	s.add_theme_stylebox_override("grabber_area", filled)
	s.add_theme_stylebox_override("grabber_area_highlight", filled)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = UI.WARN
	focus.set_border_width_all(3)
	focus.set_expand_margin_all(4)
	s.add_theme_stylebox_override("focus", focus)
	s.value_changed.connect(on_change)
	row.add_child(s)
	var value := UI.label()
	value.custom_minimum_size.x = 64
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return [s, value]


## Plays a growl at the new volume (after you let go of the slider).
func _play_preview() -> void:
	if Settings.volume <= 0.0:
		return
	if _preview == null:
		_preview = AudioStreamPlayer.new()
		for k: Dictionary in Brand.SHOPPERS.values():
			if k.get("sound") is AudioStream:
				_preview.stream = k.sound
				break
		add_child(_preview)
	if _preview.stream and not _preview.playing:
		_preview.play()


func _check(parent: Control, text: String, on_toggle: Callable) -> CheckButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var name_label := UI.label(text)
	name_label.custom_minimum_size.x = 190
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var c := CheckButton.new()
	c.custom_minimum_size = Vector2(120, 52)
	c.toggled.connect(on_toggle)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = UI.WARN
	focus.set_border_width_all(3)
	c.add_theme_stylebox_override("focus", focus)
	row.add_child(c)
	return c


func _info(parent: Control) -> Label:
	var l := UI.label("", UI.DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 600
	parent.add_child(l)
	return l


func _change_mode(step: int) -> void:
	Settings.set_display(wrapi(Settings.display + step, 0, Settings.DISPLAY_NAMES.size()) as Settings.Display)


func _change_resolution(step: int) -> void:
	var list := Settings.available_resolutions()
	var i := list.find(Settings.resolution)
	Settings.set_resolution(list[wrapi(i + step, 0, list.size())])


func _change_fps(step: int) -> void:
	var list: Array = Settings.FPS_LIMITS
	var i := list.find(Settings.fps_limit)
	if i < 0:
		i = list.size() - 1
	Settings.set_fps_limit(list[wrapi(i + step, 0, list.size())])


func _change_graphics(step: int) -> void:
	Settings.set_graphics(wrapi(Settings.graphics + step, 0, 3) as Settings.Graphics)


func _refresh() -> void:
	if Settings.is_desktop():
		var windowed := not Settings.is_fullscreen()
		mode_value.text = Settings.DISPLAY_NAMES[Settings.display]
		mode_info.text = Settings.DISPLAY_INFO[Settings.display]
		res_value.text = Settings.resolution_name(Settings.resolution) if windowed else "Your screen's"
		res_left.disabled = not windowed
		res_right.disabled = not windowed
		res_value.modulate.a = 1.0 if windowed else 0.5
	fps_value.text = Settings.fps_name(Settings.fps_limit)
	gfx_value.text = Settings.GRAPHICS_NAMES[Settings.graphics]
	gfx_info.text = Settings.GRAPHICS_INFO[Settings.graphics]
	vsync_check.set_pressed_no_signal(Settings.vsync)
	vsync_info.text = Settings.vsync_info()
	fps_check.set_pressed_no_signal(Settings.show_fps)
	vol_slider.set_value_no_signal(roundf(Settings.volume * 100.0))
	vol_value.text = Settings.volume_name(Settings.volume)
	vib_check.set_pressed_no_signal(Settings.vibration)
	var can := Settings.can_vibrate()
	vib_check.disabled = not can
	if Settings.is_mobile():
		vib_note.text = "Phone vibration and controller rumble."
	elif can:
		vib_note.text = "Controller rumble."
	else:
		vib_note.text = "Connect a controller to use vibration."
	if visible:
		_fit()
