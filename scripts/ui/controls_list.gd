class_name ControlsList
## The list of controls shown in Options > Controls, so you can look up a
## key you forgot. PCs show keyboard & mouse and controller; phones and
## handhelds show touch and controller.

## [what it does, keyboard & mouse, controller, touch]. "" = not available.
static func rows() -> Array:
	var list := [
		["Move", "WASD or arrow keys, or click a spot", "Left stick", "Tap a spot"],
		["Sprint", "Hold Shift", "Hold LT, or click the left stick", "RUN button"],
		["Use / pick up / stock", "E or Space (or click it)", "A", "Tap it, or the big button"],
		["Scan a shelf (scanner)", "Q", "X", "SCAN button"],
		["Drop the box you carry", "E with nothing to use nearby", "A", "Big button (\"Drop box\")"],
		["Take items off a shelf", "E at it with empty hands", "A", "Tap the shelf"],
		["Ring up a shopper", "E at the register", "A", "Tap the register"],
		["Take over a register", "E at a cashier's register", "A", "Tap the register"],
	]
	if Brand.SPILLS:
		list.append(["Grab the mop / mop up", "E at the bucket or a puddle", "A", "Tap it"])
	list.append_array([
		["Open the store", "E at the OPEN sign", "A", "Tap the sign"],
		["End of day / next day", "Space", "A", "Tap the bar at the bottom"],
		["Build mode", "B", "Y", "Build button"],
		["Turn something (build mode)", "R", "RB", "Rotate button, then tap it"],
		["Place / confirm (build mode)", "Click", "", "Tap twice"],
		["Cancel (build mode)", "Right-click or Esc", "B", "Back button"],
		["Look around (build mode)", "Drag, or WASD", "Left stick", "Drag"],
		["Zoom", "Mouse wheel, or the - / + buttons", "", "- / + buttons"],
		["Pause menu", "Esc or P", "Start", "II button"],
		["Menus", "Arrow keys, Enter, Esc", "D-pad, A, B", "Tap"],
	])
	return list


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
