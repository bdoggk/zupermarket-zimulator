class_name UI
## Small helpers for building the UI in code, plus the shared colors and
## theme.

const PANEL_BG := Color(0.1, 0.11, 0.13, 0.94)
const PANEL_BORDER := Color(0.34, 0.36, 0.4)
const GOOD := Color(0.56, 0.84, 0.52)
const WARN := Color(0.95, 0.8, 0.4)
const BAD := Color(0.95, 0.45, 0.4)
const INFO := Color(0.6, 0.82, 1.0)
const DIM := Color(1, 1, 1, 0.55)


static func button(text: String, on_press: Callable, min_size := Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # so Space/E keep going to the game
	b.custom_minimum_size = min_size
	b.pressed.connect(on_press)
	return b


## Menus highlight a button for keyboard/controller use, except on touch
## screens with no controller (like a phone). Handhelds with built-in
## controls (e.g. an AYN Thor) count as having a controller.
static func wants_focus() -> bool:
	return not Game.touch_ui or not Input.get_connected_joypads().is_empty()


## True for a controller button press or stick push, used to put focus on a
## menu the first time a controller is touched.
static func is_pad_input(event: InputEvent) -> bool:
	return (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5)


## A button for menus: it can be picked with the keyboard or a controller
## (arrow keys / d-pad, Enter / A), and shows a yellow outline when selected.
static func menu_button(text: String, on_press: Callable, min_size := Vector2(360, 60)) -> Button:
	var b := button(text, on_press, min_size)
	b.focus_mode = Control.FOCUS_ALL
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = WARN
	focus.set_border_width_all(3)
	b.add_theme_stylebox_override("focus", focus)
	return b


## A dark panel with a title, used by the menus.
static func titled_panel(title: String) -> Array:
	var panel := PanelContainer.new()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	var t := label(title, WARN)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	col.add_child(HSeparator.new())
	return [panel, col]


static func label(text := "", color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	if color != Color.WHITE:
		l.add_theme_color_override("font_color", color)
	return l


static func icon(tex: Texture2D, size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return t


static func set_color(l: Label, color: Color) -> void:
	l.add_theme_color_override("font_color", color)


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


static func make_theme(touch: bool) -> Theme:
	var t := Theme.new()
	t.default_font_size = 22 if touch else 18

	var panel := StyleBoxFlat.new()
	panel.bg_color = PANEL_BG
	panel.border_color = PANEL_BORDER
	panel.set_border_width_all(2)
	panel.set_content_margin_all(12)
	t.set_stylebox("panel", "PanelContainer", panel)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.22, 0.24, 0.27)
	normal.border_color = PANEL_BORDER
	normal.set_border_width_all(2)
	normal.set_content_margin_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.3, 0.32, 0.36)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.2, 0.32, 0.24)
	pressed.border_color = Color(0.5, 0.78, 0.5)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.16, 0.16, 0.17)
	disabled.border_color = Color(0.24, 0.24, 0.26)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.55, 0.55))
	t.set_color("font_pressed_color", "Button", Color(0.85, 1.0, 0.85))
	return t
