class_name ControlsList
## The list of controls shown in Options > Controls, so you can look up a
## key you forgot. PCs show keyboard & mouse and controller; phones and
## handhelds show touch and controller.

## [what it does, keyboard & mouse, controller, touch, (what it covers)].
## "" = not available.
static func rows() -> Array:
	var does := "Whatever is in front of you: boxes, shelves, registers, the computer, the OPEN sign"
	if Brand.SPILLS:
		does += ", the mop"
	if not Brand.SHOPS.is_empty():
		does += ", the shop counters across the road"
	if Brand.RIVAL.has("spy_in"):
		does += ", throwing out %s's spies" % Brand.RIVAL.name
	return [
		["Move", "WASD or arrow keys, or click a spot", "Left stick", "Tap a spot"],
		["Sprint", "Hold Shift", "Hold LT, or click the left stick", "RUN button"],
		["Interact", "E", "A", "Tap it, or the big button", does + "."],
		["Scan a shelf (scanner)", "Q", "X", "SCAN button"],
		["Next day (end of the day)", "Space", "A", "Tap the bar at the bottom"],
		["Build mode", "B", "Y", "Build button"],
		["Turn something (build mode)", "R", "RB", "Rotate button, then tap it"],
		["Pick what to buy or a tool (build mode)", "Click its button", "D-pad left / right, LB", "Tap its button"],
		["Place / confirm (build mode)", "Click", "A (on the tile in the middle of the screen)", "Tap twice"],
		["Cancel (build mode)", "Right-click or Esc", "B", "Back button"],
		["Look around (build mode)", "Drag, or WASD", "Left stick", "Drag"],
		["Zoom", "Mouse wheel, or the - / + buttons", "", "Pinch with two fingers, or - / +"],
		["Pause menu", "Esc or P", "Start", "II button"],
		["Recent messages", "M, or the Log button", "Back / View", "Log button"],
		["Menus", "Arrow keys, Enter, Esc", "D-pad, A, B", "Tap; drag a list to scroll it"],
		["Store computer: other apps", "Tab / Shift+Tab, or 1-4", "LB / RB", "Tap an app"],
	]


## A table of the controls: what it does, then the keys for each way of
## playing this device has.
static func build(touch: bool) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	var first := "Touch" if touch else "Keyboard & mouse"
	for head: String in ["", first, "Controller"]:
		grid.add_child(UI.label(head, UI.WARN))
	for r: Array in rows():
		var name_label := UI.label(r[0])
		name_label.custom_minimum_size.x = 250
		if r.size() > 4:  # with a note on what it covers
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", 2)
			cell.add_child(name_label)
			var note := UI.label(r[4], UI.DIM)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.custom_minimum_size.x = 250
			note.add_theme_font_size_override("font_size", 14)
			cell.add_child(note)
			grid.add_child(cell)
		else:
			grid.add_child(name_label)
		var keys := UI.label(r[3] if touch else r[1], UI.INFO)
		keys.custom_minimum_size.x = 300
		keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(keys)
		var pad := UI.label(r[2] if r[2] != "" else "-", UI.INFO if r[2] != "" else UI.DIM)
		pad.custom_minimum_size.x = 190
		pad.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(pad)
	return grid
