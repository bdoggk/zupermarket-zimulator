class_name MessageLog
extends PanelContainer
## Recent messages: everything that popped up at the top of the screen
## lately (Game.message_log), newest first, with the day and time. Opened
## with M, the Back / View button on a controller, the Log button, or from
## the pause menu.

var list: VBoxContainer
var scroll: ScrollContainer
var close_button: Button


func _ready() -> void:
	visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	var title := UI.label("MESSAGES", UI.WARN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	col.add_child(HSeparator.new())
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	col.add_child(HSeparator.new())
	close_button = UI.button("Close", close, Vector2(160, 52))
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(close_button)
	Game.message.connect(_on_message)


func _on_message(_text: String) -> void:
	if visible:
		_rebuild.call_deferred()


func open() -> void:
	visible = true
	_rebuild()
	if UI.has_pad():
		UI.pad_focus(close_button)
		close_button.grab_focus.call_deferred()


func close() -> void:
	visible = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _rebuild() -> void:
	UI.clear(list)
	if Game.message_log.is_empty():
		list.add_child(UI.label("Nothing yet today.", UI.DIM))
	for i in range(Game.message_log.size() - 1, -1, -1):
		var m: Dictionary = Game.message_log[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		list.add_child(row)
		var when := UI.label("Day %d  %s" % [int(m.day), str(m.time)], UI.DIM)
		when.custom_minimum_size.x = 170
		row.add_child(when)
		var text := UI.label(str(m.text))
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
	scroll.scroll_vertical = 0
