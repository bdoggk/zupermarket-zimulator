class_name BuildMode
extends Node2D
## Build mode: buy, move and sell furniture (shelves, fridges, plants,
## storage racks and extra registers), and move the first register (its
## checkout line comes along), the computer, the OPEN sign, the mop bucket
## and the delivery zone. Anything you can move you can also turn (the
## Rotate tool, or R while placing or moving something); a register's line
## turns with it. With a town outside, you can also buy the lot next door to
## make the store bigger (the Expand tool).
## Repainting is done from the build bar in the HUD. The game is paused
## while you build.
##
##   PC:     B to open/close. Hover to preview, click to confirm.
##           R turns what you're holding (or what's under the mouse).
##           Right-click or Esc cancels. Drag or WASD to look around.
##   Touch:  Tap a tile to preview, tap it again to confirm.
##           Drag to look around.
##   Controller: the tile in the middle of the screen is the cursor. Left
##           stick looks around, d-pad left/right (or LB) picks what to build
##           or Move / Rotate / Sell / Expand, A places (or picks up, sells...),
##           RB turns it, B cancels, Y leaves build mode.

signal changed  # tool, selection or status text changed (the HUD listens)

enum Tool { NONE, PLACE, MOVE, SELL, EXPAND, ROTATE }

const PAN_SPEED := 600.0
const DRAG_THRESHOLD := 12.0
const OK_COLOR := Color(0.45, 1.0, 0.5)
const BAD_COLOR := Color(1.0, 0.35, 0.3)
const SELL_TINT := Color(1.5, 0.55, 0.5)
const PICK_TINT := Color(0.8, 1.1, 1.5)
const LINE_COLOR := Color(1.0, 0.85, 0.3)

var active := false
var tool := Tool.NONE
var place_id := ""  # furniture to buy with the PLACE tool
var moving: Interactable = null  # picked up with the MOVE tool
var selected: Interactable = null  # highlighted, waiting for a second tap
var cursor := Store.NO_CELL
var cursor_error := ""
var preview_line: Array[Vector2i] = []  # where a register's checkout line would go
var zone_grab := Vector2i.ZERO  # which cell of the delivery zone you picked it up by
var zone_size := Vector2i.ZERO  # the delivery zone you're moving (turning it swaps the sides)
var place_rotation := -1  # which way what you're placing or moving faces (-1 = its usual way)
var _expand_armed := false  # touch: the lot was tapped once, tap again to buy
var status := ""

var _grid: Node2D  # draws the floor markings underneath the furniture
var _pressed := false
var _dragging := false
var _press_pos := Vector2.ZERO
var _hover_pos := Vector2.INF  # where the mouse is in the world (for R with nothing in hand)
var _pad_cell := Store.NO_CELL  # with a controller: the tile in the middle of the screen
var _pad_tap := false  # A was pressed: pick what's on that tile, not what's drawn over it

@onready var store: Store = get_parent()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.build_mode = self
	_grid = Node2D.new()
	_grid.z_index = -1  # under the furniture (the floor tiles are at -2)
	_grid.draw.connect(_draw_grid)
	add_child(_grid)


func enter() -> void:
	if active or get_tree().paused:  # not on top of the pause menu (you can build after closing too)
		return
	active = true
	_end_drag()
	Game.tutorial_step_done("build")
	get_tree().paused = true
	select_tool(Tool.NONE)


func exit() -> void:
	if not active:
		return
	_clear_selection()
	_end_drag()
	active = false
	tool = Tool.NONE
	get_tree().paused = false
	Game.player.camera.offset = Vector2.ZERO
	queue_redraw()
	_grid.queue_redraw()
	changed.emit()


func select_tool(t: Tool) -> void:
	_clear_selection()
	tool = t
	place_id = ""
	if t == Tool.EXPAND:
		_look_at_lot()
	_refresh()


func select_place(furniture_id: String) -> void:
	_clear_selection()
	tool = Tool.PLACE
	place_id = furniture_id
	_refresh()


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not active:
		if event.is_action_pressed("build"):
			enter()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventJoypadButton and event.pressed and _pad_button(event.button_index):
		pass  # a controller picked a tool or used the tile in the middle of the screen
	elif event.is_action_pressed("build") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_back()
	elif event.is_action_pressed("rotate") and not event.is_echo():
		rotate_pressed()
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_pressed = true
					_dragging = false
					_press_pos = event.position
				elif _pressed:
					var was_drag := _dragging
					_end_drag()
					if not was_drag:
						var touch: bool = event.device == InputEvent.DEVICE_ID_EMULATION
						tap(_to_world(event.position), touch)
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					_back()
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed and get_viewport().gui_get_hovered_control() == null:
					Game.player.zoom_by(1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed and get_viewport().gui_get_hovered_control() == null:
					Game.player.zoom_by(1.0 / 1.1)
	elif event is InputEventMouseMotion:
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			_end_drag()  # the button was let go somewhere we didn't hear about
		if _pressed and (event.position - _press_pos).length() > DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			_pan(-event.relative)
		elif event.device != InputEvent.DEVICE_ID_EMULATION:
			_hover_pos = _to_world(event.position)
			_hover(_hover_pos)
	else:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not active:
		return
	if (_pressed or _dragging) and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_end_drag()
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v != Vector2.ZERO:
		_pan(v * PAN_SPEED * delta)
	if UI.has_pad():  # the middle of the screen is the cursor
		var c := Iso.world_to_cell(_screen_center())
		if c != _pad_cell:
			_pad_cell = c
			_hover_pos = _screen_center()
			_hover(_hover_pos)


# ---------------------------------------------------------------- controller

func _screen_center() -> Vector2:
	return _to_world(get_viewport().get_visible_rect().size / 2.0)


## A controller button in build mode. Returns true if it did something.
func _pad_button(b: JoyButton) -> bool:
	match b:
		JOY_BUTTON_DPAD_RIGHT:
			_pad_cycle(1)
		JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_LEFT_SHOULDER:
			_pad_cycle(-1)
		JOY_BUTTON_A:
			_pad_tap = true  # what's on the tile under the cursor comes first
			tap(_screen_center(), true)
			_pad_tap = false
		_:
			return false
	return true


## What the d-pad goes through: the furniture, then the tools.
func _pad_tools() -> Array:
	var list: Array = Game.FURNITURE.keys()
	list.append_array(["move", "rotate", "sell"])
	if store.town and not Brand.EXPANSIONS.is_empty():
		list.append("expand")
	return list


func _pad_current() -> String:
	match tool:
		Tool.PLACE:
			return place_id
		Tool.MOVE:
			return "move"
		Tool.ROTATE:
			return "rotate"
		Tool.SELL:
			return "sell"
		Tool.EXPAND:
			return "expand"
	return ""


## Picks the next (or previous) thing to build or tool.
func _pad_cycle(step: int) -> void:
	var list := _pad_tools()
	var i := list.find(_pad_current())
	i = posmod(i + step, list.size()) if i >= 0 else (0 if step > 0 else list.size() - 1)
	match list[i]:
		"move":
			select_tool(Tool.MOVE)
		"rotate":
			select_tool(Tool.ROTATE)
		"sell":
			select_tool(Tool.SELL)
		"expand":
			select_tool(Tool.EXPAND)
		var id:
			select_place(id)
	_pad_cell = Store.NO_CELL  # preview at the middle of the screen again


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_end_drag()


## Forgets a click or drag in progress. Only a held mouse button (or finger)
## drags the view; once it's let go (even over a menu or outside the
## window, where build mode never sees it) the view stops following the
## mouse.
func _end_drag() -> void:
	_pressed = false
	_dragging = false


## Esc / right-click: cancel what you're doing, or leave build mode.
func _back() -> void:
	if moving or selected or tool != Tool.NONE:
		select_tool(Tool.NONE)
	else:
		exit()


func _to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos


func _pan(screen_delta: Vector2) -> void:
	var cam: Camera2D = Game.player.camera
	cam.offset += screen_delta / cam.zoom.x


## Mouse hover (PC only): preview without clicking.
func _hover(world_pos: Vector2) -> void:
	match tool:
		Tool.PLACE:
			_set_cursor(Iso.world_to_cell(world_pos))
		Tool.MOVE:
			if moving:
				_set_cursor(Iso.world_to_cell(world_pos))
			else:
				_set_selected(movable_at(world_pos))
		Tool.SELL:
			_set_selected(furniture_at(world_pos))
		Tool.EXPAND:
			var c := Iso.world_to_cell(world_pos)
			_set_cursor(c if c in next_lot() else Store.NO_CELL)
		Tool.ROTATE:
			_set_selected(movable_at(world_pos))


## A click or tap on the store. With `touch`, the first tap only previews
## and a second tap on the same spot confirms.
func tap(world_pos: Vector2, touch := false) -> void:
	var cell := Iso.world_to_cell(world_pos)
	match tool:
		Tool.PLACE:
			if touch and cell != cursor:
				_set_cursor(cell)
				return
			_set_cursor(cell)
			_try_place(cell)
		Tool.MOVE:
			if moving == null:
				var obj := movable_at(world_pos)
				if obj == null:
					Game.message.emit("Tap something to move it.")
					return
				if obj is DeliveryZone:
					zone_grab = cell - store.delivery_anchor()
					zone_size = store.delivery_size
				_pick_up(obj)
			else:
				if touch and cell != cursor:
					_set_cursor(cell)
					return
				_set_cursor(cell)  # always re-check the spot being clicked
				_try_move(cell)
		Tool.SELL:
			var obj := furniture_at(world_pos)
			if obj == null:
				var fixed := movable_at(world_pos)
				if fixed:
					Game.message.emit("You can't sell the %s, but you can move it." % fixed.display_name())
				_set_selected(null)
				return
			if touch and obj != selected:
				_set_selected(obj)
				return
			_sell(obj)
		Tool.EXPAND:
			if not cell in next_lot():
				Game.message.emit("Tap the lot next door (outlined) to buy it." if not next_lot().is_empty() else "There's no more land to buy.")
				return
			if touch and not _expand_armed:
				_expand_armed = true
				_set_cursor(cell)
				return
			_try_expand()
		Tool.ROTATE:
			var obj := movable_at(world_pos)
			if obj == null:
				Game.message.emit("Tap something to turn it." if touch else "Click something to turn it.")
				return
			turn(obj)
			_set_selected(obj)
	_refresh()


## Furniture you can sell, drawn at `world_pos` or standing on that cell.
func furniture_at(world_pos: Vector2) -> Interactable:
	var obj := _object_at(world_pos, func(o: Interactable): return o.is_sellable())
	return obj


## Anything the Move tool can pick up (furniture, register, computer, sign,
## the delivery zone).
func movable_at(world_pos: Vector2) -> Interactable:
	var obj := _object_at(world_pos, func(o: Interactable): return o.is_movable())
	if obj == null and Iso.world_to_cell(world_pos) in store.delivery_cells:
		obj = store.delivery_zone
	return obj


func _object_at(world_pos: Vector2, ok: Callable) -> Interactable:
	if _pad_tap:
		var on_tile: Interactable = store.objects.get(Iso.world_to_cell(world_pos))
		if on_tile and ok.call(on_tile):
			return on_tile
	var obj := store.interactable_at_point(world_pos)
	if obj == null or not ok.call(obj):
		obj = store.objects.get(Iso.world_to_cell(world_pos))
	if obj and ok.call(obj):
		return obj
	return null


# ---------------------------------------------------------------- actions

## R or the Rotate button: turns what you're placing or moving. With
## nothing in hand, R turns whatever is under the mouse; the button picks
## the Rotate tool (tap things to turn them).
func rotate_pressed(from_button := false) -> void:
	if tool == Tool.PLACE or is_instance_valid(moving):
		if moving is DeliveryZone:
			zone_size = Vector2i(zone_size.y, zone_size.x)
			zone_grab = Vector2i(zone_grab.y, zone_grab.x)
		else:
			place_rotation = (held_step() + 1) % 4
		_set_cursor(cursor)
		return
	if from_button:
		select_tool(Tool.NONE if tool == Tool.ROTATE else Tool.ROTATE)
		return
	var obj: Interactable = selected if is_instance_valid(selected) else null
	if obj == null and _hover_pos != Vector2.INF:
		obj = movable_at(_hover_pos)
	if obj:
		turn(obj)
	else:
		select_tool(Tool.ROTATE)


## Turns `obj` a quarter turn where it stands. If a register's line doesn't
## fit the next way, it tries the way after that.
func turn(obj: Interactable) -> void:
	if not obj.can_rotate():
		Game.message.emit("The %s can't be turned." % obj.display_name())
		return
	var problem := ""
	for i in range(1, 4):
		var step := (obj.rotation_step + i) % 4
		var err := store.rotate_error(obj, step)
		if err == "":
			store.rotate_object(obj, step)
			Settings.vibrate(0.2, 0.04)
			if obj is DeliveryZone and store.delivery_size.x == store.delivery_size.y:
				Game.message.emit("The delivery zone is square, so it looks the same turned.")
			_refresh()
			return
		if problem == "":
			problem = err
	Game.message.emit("Can't turn the %s: %s" % [obj.display_name(), problem])
	Settings.vibrate(0.6, 0.1)


## Which way what you're placing or moving faces right now.
func held_step() -> int:
	if place_rotation >= 0:
		return place_rotation
	if (_placing_register() or moving is Register) and cursor != Store.NO_CELL and not preview_line.is_empty():
		var i := Interactable.FACINGS.find(preview_line[0] - cursor)
		if i >= 0:
			return i  # a register faces where its line ends up
	if is_instance_valid(moving):
		return moving.rotation_step
	if _placing_register():
		return maxi(0, Interactable.FACINGS.find(store.register.facing))
	return 0


## The cells of the next lot you can buy ([] if none are left).
func next_lot() -> Array:
	if store.town == null or Game.expansions + 1 >= store.town.lots.size():
		return []
	return store.town.lots[Game.expansions + 1]


func _try_expand() -> void:
	var problem := Game.expansion_problem()
	if problem != "":
		Game.message.emit(problem)
		Settings.vibrate(0.6, 0.1)
		return
	var cost: float = Game.next_expansion().cost
	var center := _lot_center()
	if Game.buy_expansion():
		Game.show_popup(center + Vector2(0, -40), "-$%d" % int(cost), BAD_COLOR)
	select_tool(Tool.NONE)


func _lot_center() -> Vector2:
	var lot := next_lot()
	var sum := Vector2.ZERO
	for c: Vector2i in lot:
		sum += Iso.cell_to_world(c)
	return sum / maxf(1.0, lot.size())


## Moves the view over to the lot for sale.
func _look_at_lot() -> void:
	if next_lot().is_empty():
		return
	var cam: Camera2D = Game.player.camera
	cam.offset = _lot_center() - cam.global_position

func _try_place(cell: Vector2i) -> void:
	if cursor_error != "":
		Game.message.emit(cursor_error)
		Settings.vibrate(0.6, 0.1)
		return
	var cost: float = Game.FURNITURE[place_id].cost
	if not Game.spend(cost):
		return
	store.add_furniture(place_id, cell, place_rotation)
	store.layout_changed()
	Settings.vibrate(0.3, 0.05)
	Game.show_popup(Iso.cell_to_world(cell) + Vector2(0, -50), "-$%d" % int(cost), BAD_COLOR)
	_set_cursor(cell)  # re-check the spot (now taken)


func _pick_up(obj: Interactable) -> void:
	_set_selected(null)
	place_rotation = -1
	moving = obj
	moving.modulate = Color(1, 1, 1, 0.35)
	_set_cursor(obj.cell + zone_grab if obj is DeliveryZone else obj.cell)


func _try_move(cell: Vector2i) -> void:
	if moving is DeliveryZone:
		var anchor := cell - zone_grab
		if anchor == store.delivery_anchor() and zone_size == store.delivery_size:
			_put_down()
		elif cursor_error != "":
			Game.message.emit(cursor_error)
		else:
			store.move_delivery_zone(anchor, zone_size)
			Settings.vibrate(0.3, 0.05)
			_put_down()
		return
	var turned := place_rotation >= 0 and place_rotation != moving.rotation_step
	if cell == moving.cell and not turned:
		_put_down()  # dropped it back where it was
		return
	if cursor_error != "":
		Game.message.emit(cursor_error)
		return
	if cell == moving.cell:
		store.rotate_object(moving, place_rotation)
		Settings.vibrate(0.3, 0.05)
		_put_down()
		return
	store.move_object(moving, cell, place_rotation)
	Settings.vibrate(0.3, 0.05)
	_put_down()


func _put_down() -> void:
	if is_instance_valid(moving):
		moving.modulate = Color.WHITE
	moving = null
	place_rotation = -1
	_set_cursor(Store.NO_CELL)


func _sell(obj: Interactable) -> void:
	var refund: float = Game.FURNITURE[obj.furniture_id].cost * Game.SELL_REFUND
	var had_stock: bool = obj is Shelf and obj.stock > 0
	_set_selected(null)
	store.remove_furniture(obj)
	Game.refund(refund)
	Game.show_popup(obj.position + Vector2(0, -50), "+$%d" % int(refund), OK_COLOR)
	if had_stock:
		Game.message.emit("The leftover stock was boxed up.")


# ---------------------------------------------------------------- state

func _clear_selection() -> void:
	if is_instance_valid(moving):
		moving.modulate = Color.WHITE
	moving = null
	_set_selected(null)
	cursor = Store.NO_CELL
	cursor_error = ""
	preview_line.clear()
	place_rotation = -1
	_expand_armed = false


func _set_selected(obj: Interactable) -> void:
	if selected == obj:
		return
	if is_instance_valid(selected):
		selected.modulate = Color.WHITE
	selected = obj
	if selected and not selected is DeliveryZone:
		selected.modulate = SELL_TINT if tool == Tool.SELL else PICK_TINT
	_refresh()


func _set_cursor(cell: Vector2i) -> void:
	cursor = cell
	cursor_error = ""
	preview_line.clear()
	if cell != Store.NO_CELL:
		if tool == Tool.PLACE:
			cursor_error = store.placement_error(cell, place_id, null, place_rotation)
			if cursor_error == "" and Game.money < Game.FURNITURE[place_id].cost:
				cursor_error = "Not enough money"
			if _placing_register():
				preview_line = store.preview_line(cell, null, place_rotation)
		elif moving is DeliveryZone:
			var anchor := cell - zone_grab
			if anchor != store.delivery_anchor() or zone_size != store.delivery_size:
				cursor_error = store.delivery_zone_error(anchor, zone_size)
		elif moving:
			if cell != moving.cell:
				cursor_error = store.placement_error(cell, moving.furniture_id, moving, place_rotation)
			elif place_rotation >= 0 and place_rotation != moving.rotation_step:
				cursor_error = store.rotate_error(moving, place_rotation)
			if moving is Register:
				preview_line = store.preview_line(cell, moving, place_rotation)
	_refresh()


func _placing_register() -> bool:
	return tool == Tool.PLACE and Game.FURNITURE[place_id].kind in ["register", "selfcheckout"]


func _refresh() -> void:
	var pad := UI.has_pad() and not Game.touch_ui
	var click := "press A" if pad else ("tap again" if Game.touch_ui else "click")
	var turn_how := "RB turns it" if pad else ("Rotate turns it" if Game.touch_ui else "R turns it")
	match tool:
		Tool.NONE:
			if pad:
				status = "D-pad left/right: pick something to buy, or Move / Rotate / Sell. Left stick: look around. B: done."
			else:
				status = "Buy furniture, or pick Move / Rotate / Sell. Drag to look around."
		Tool.PLACE:
			var f: Dictionary = Game.FURNITURE[place_id]
			if cursor == Store.NO_CELL:
				status = "%s ($%d): pick a spot." % [f.name, int(f.cost)]
			elif cursor_error != "":
				status = "%s: %s" % [f.name, cursor_error]
			elif _placing_register():
				status = "%s ($%d): %s to buy. Its line (yellow) needs to stay clear. %s." % [f.name, int(f.cost), click, turn_how]
			else:
				status = "%s ($%d): %s to buy. %s." % [f.name, int(f.cost), click, turn_how]
		Tool.MOVE:
			if moving == null:
				status = "Pick up anything to move it: furniture, registers, the computer, the sign, the delivery zone...%s" % (" (look at it and press A)" if pad else "")
			elif cursor_error != "":
				status = "Can't move the %s here: %s" % [moving.display_name(), cursor_error]
			elif moving is Register:
				status = "Pick a spot and %s to put the register down. The line (yellow) comes with it. %s." % [click, turn_how]
			elif moving is DeliveryZone:
				status = "Pick a spot and %s to put the delivery zone down. Boxes on it come along. %s." % [click, turn_how]
			else:
				status = "Pick a new spot and %s to put the %s down. %s." % [click, moving.display_name(), turn_how]
		Tool.SELL:
			if selected:
				var refund: float = Game.FURNITURE[selected.furniture_id].cost * Game.SELL_REFUND
				status = "Sell this %s for $%d? %s to sell." % [Game.FURNITURE[selected.furniture_id].name.to_lower(), int(refund), click.capitalize()]
			else:
				status = "Pick something to sell (you get half back). The first register can't be sold.%s" % (" (look at it and press A)" if pad else "")
		Tool.ROTATE:
			if selected and not Game.touch_ui:
				status = "%s to turn the %s a quarter turn.%s" % [click.capitalize(), selected.display_name(), " Its line turns with it." if selected is Register else ""]
			elif pad:
				status = "Look at something and press A to turn it a quarter turn. A register's line turns with it."
			else:
				status = "%s anything to turn it a quarter turn. A register's line turns with it." % ("Tap" if Game.touch_ui else "Click")
		Tool.EXPAND:
			var e := Game.next_expansion()
			var problem := Game.expansion_problem()
			if e.is_empty():
				status = "You've bought all the land there is."
			elif problem != "":
				status = "Lot next door ($%d): %s." % [int(e.cost), problem]
			elif _expand_armed:
				status = "Buy the lot next door for $%d? %s to buy." % [int(e.cost), "Press A again" if pad else "Tap it again"]
			else:
				status = "Lot next door: $%d. It makes the store %d tiles wider. %s the lot to buy it." % [int(e.cost), Store.LOT_WIDTH, "Look at it and press A on" if pad else ("Tap" if Game.touch_ui else "Click")]
	queue_redraw()
	_grid.queue_redraw()
	changed.emit()


# ---------------------------------------------------------------- drawing

## The ghost of what you're placing, drawn on top of everything.
func _draw() -> void:
	if not active:
		return
	var ghost: Texture2D = null
	if tool == Tool.PLACE:
		ghost = Game.FURNITURE[place_id].texture
	elif is_instance_valid(moving):
		ghost = moving.ghost_texture()
	if ghost and cursor != Store.NO_CELL:
		var ok := cursor_error == ""
		Interactable.draw_view(self, ghost, held_step(), Iso.cell_to_world(cursor), Color(1, 1, 1, 0.65) if ok else Color(1, 0.5, 0.5, 0.5))


## The floor markings: the grid, no-build tiles, checkout lines and the cursor.
func _draw_grid() -> void:
	if not active:
		return
	var no_build := {}
	var moving_register := is_instance_valid(moving) and moving is Register
	for c in store.delivery_cells:
		no_build[c] = true
	for c in store.all_line_cells(moving as Register if moving_register else null):
		no_build[c] = true
	no_build[store.door_cell] = true
	for cell: Vector2i in store.floor_cells:
		if no_build.has(cell):
			_diamond(cell, Color(1, 0.3, 0.2, 0.12), true)
		_diamond(cell, Color(1, 1, 1, 0.1), false)

	if (moving_register or _placing_register()) and cursor != Store.NO_CELL:
		var ok_line := cursor_error == ""
		for c in preview_line:
			_diamond(c, Color(LINE_COLOR if ok_line else BAD_COLOR, 0.25), true)
			_diamond(c, LINE_COLOR if ok_line else BAD_COLOR, false)
	if tool == Tool.EXPAND:
		var ok := Game.expansion_problem() == ""
		for c: Vector2i in next_lot():
			_diamond(c, Color(OK_COLOR if ok else BAD_COLOR, 0.22 if c != cursor else 0.4), true)
			_diamond(c, Color(OK_COLOR if ok else BAD_COLOR, 0.6), false)
	if moving is DeliveryZone and cursor != Store.NO_CELL:
		var color := OK_COLOR if cursor_error == "" else BAD_COLOR
		for c in store.delivery_cells_at(cursor - zone_grab, zone_size):
			var at := Iso.cell_to_world(c) - Vector2(32, 16)
			_grid.draw_texture(Store.TILE_DELIVERY, at, Color(1, 1, 1, 0.6))
			_diamond(c, color, false)
	elif (tool == Tool.PLACE or is_instance_valid(moving)) and cursor != Store.NO_CELL:
		var color := OK_COLOR if cursor_error == "" else BAD_COLOR
		_diamond(cursor, Color(color, 0.3), true)
		_diamond(cursor, color, false)
	elif UI.has_pad() and _pad_cell != Store.NO_CELL:
		_diamond(_pad_cell, Color(1, 1, 1, 0.7), false)  # the controller's cursor


func _diamond(cell: Vector2i, color: Color, filled: bool) -> void:
	var c := Iso.cell_to_world(cell)
	var pts := PackedVector2Array([c + Vector2(0, -16), c + Vector2(32, 0), c + Vector2(0, 16), c + Vector2(-32, 0)])
	if filled:
		_grid.draw_colored_polygon(pts, color)
	else:
		pts.append(pts[0])
		_grid.draw_polyline(pts, color, 1.0)
