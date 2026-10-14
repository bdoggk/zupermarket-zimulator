extends PanelContainer
## The in-game pause menu (Esc, the Start button, the II button or the
## phone's back button): resume, save, options, or go back to the main menu.

signal options_requested

var info_label: Label
var save_button: Button
var resume_button: Button


func _ready() -> void:
	visible = false
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	add_child(col)
	var title := UI.label("PAUSED", UI.WARN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	info_label = UI.label("", UI.DIM)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(info_label)
	col.add_child(HSeparator.new())
	resume_button = UI.menu_button("Resume", close)
	col.add_child(resume_button)
	save_button = UI.menu_button("Save Game", _save)
	col.add_child(save_button)
	col.add_child(UI.menu_button("Options", func(): options_requested.emit()))
	col.add_child(UI.menu_button("Save & Main Menu", Saves.quit_to_menu))
	if Settings.is_desktop():
		col.add_child(UI.menu_button("Save & Quit", Saves.quit_game))


func open() -> void:
	visible = true
	get_tree().paused = true
	if Game.slot >= 0:
		info_label.text = "Slot %d  -  Day %d  -  %s played" % [Game.slot + 1, Game.day, Saves.format_play_time(Game.play_time)]
	else:
		info_label.text = "Not playing in a save slot"
	save_button.disabled = Game.slot < 0
	if UI.wants_focus():
		resume_button.grab_focus()


func close() -> void:
	visible = false
	get_tree().paused = false


## Hides the menu without unpausing (while Options is open on top).
func hide_for_options() -> void:
	visible = false


func show_again() -> void:
	visible = true
	if UI.wants_focus():
		resume_button.grab_focus()


func _input(event: InputEvent) -> void:
	if visible and UI.is_pad_input(event) and get_viewport().gui_get_focus_owner() == null:
		resume_button.grab_focus()
		get_viewport().set_input_as_handled()


func _save() -> void:
	if Saves.save_game():
		Game.message.emit("Game saved to slot %d." % (Game.slot + 1))
		Settings.vibrate(0.3, 0.05)
		close()
