extends PanelContainer
## The Options screen: display mode and resolution (PC), graphics level,
## VSync and vibration. Changes apply right away and are saved. Used by the
## main menu and the in-game pause menu.

signal closed

var mode_value: Label
var res_value: Label
var res_left: Button
var res_right: Button
var res_note: Label
var gfx_value: Label
var gfx_info: Label
var vsync_check: CheckButton
var vib_check: CheckButton
var vib_note: Label
var back_button: Button
var _first: Control


func _ready() -> void:
	visible = false
	custom_minimum_size.x = 640
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	var title := UI.label("OPTIONS", UI.WARN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	col.add_child(HSeparator.new())

	if Settings.is_desktop():
		var mode := _selector(col, "Display", _change_mode)
		mode_value = mode[0]
		var res := _selector(col, "Resolution", _change_resolution)
		res_value = res[0]
		res_left = res[1]
		res_right = res[2]
		res_note = UI.label("Fullscreen uses your screen's resolution.", UI.DIM)
		col.add_child(res_note)

	var gfx := _selector(col, "Graphics", _change_graphics)
	gfx_value = gfx[0]
	gfx_info = UI.label("", UI.DIM)
	gfx_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(gfx_info)

	vsync_check = _check(col, "VSync", func(on: bool): Settings.set_vsync(on))
	vib_check = _check(col, "Vibration", func(on: bool): Settings.set_vibration(on))
	vib_note = UI.label("", UI.DIM)
	col.add_child(vib_note)

	col.add_child(HSeparator.new())
	back_button = UI.menu_button("Back", close, Vector2(0, 56))
	col.add_child(back_button)
	Settings.changed.connect(_refresh)


func open() -> void:
	visible = true
	_refresh()
	if UI.wants_focus():
		_first.grab_focus()


func focus_first() -> void:
	_first.grab_focus()


func _input(event: InputEvent) -> void:
	if visible and UI.is_pad_input(event) and get_viewport().gui_get_focus_owner() == null:
		_first.grab_focus()
		get_viewport().set_input_as_handled()


func close() -> void:
	visible = false
	closed.emit()


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


func _change_mode(_step: int) -> void:
	Settings.set_fullscreen(not Settings.fullscreen)  # only two choices


func _change_resolution(step: int) -> void:
	var list := Settings.available_resolutions()
	var i := list.find(Settings.resolution)
	Settings.set_resolution(list[wrapi(i + step, 0, list.size())])


func _change_graphics(step: int) -> void:
	Settings.set_graphics(wrapi(Settings.graphics + step, 0, 3) as Settings.Graphics)


func _refresh() -> void:
	if Settings.is_desktop():
		mode_value.text = "Fullscreen" if Settings.fullscreen else "Windowed"
		res_value.text = "%d x %d" % [Settings.resolution.x, Settings.resolution.y]
		res_left.disabled = Settings.fullscreen
		res_right.disabled = Settings.fullscreen
		res_value.modulate.a = 0.5 if Settings.fullscreen else 1.0
		res_note.visible = Settings.fullscreen
	gfx_value.text = Settings.GRAPHICS_NAMES[Settings.graphics]
	gfx_info.text = Settings.GRAPHICS_INFO[Settings.graphics]
	vsync_check.set_pressed_no_signal(Settings.vsync)
	vib_check.set_pressed_no_signal(Settings.vibration)
	var can := Settings.can_vibrate()
	vib_check.disabled = not can
	if Settings.is_mobile():
		vib_note.text = "Phone vibration and controller rumble."
	elif can:
		vib_note.text = "Controller rumble."
	else:
		vib_note.text = "Connect a controller to use vibration."
