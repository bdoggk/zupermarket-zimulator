class_name BuildMode
extends Node2D
## Build mode: buy, move and sell furniture (shelves, fridges, plants and
## extra registers), and move the first register (its checkout line comes
## along), the computer, the OPEN sign and the mop bucket.
## Repainting is done from the build bar in the HUD. The game is paused
## while you build.
##
##   PC:     B to open/close. Hover to preview, click to confirm.
##           Right-click or Esc cancels. Drag or WASD to look around.
##   Touch:  Tap a tile to preview, tap it again to confirm.
##           Drag to look around.

signal changed  # tool, selection or status text changed (the HUD listens)

enum Tool { NONE, PLACE, MOVE, SELL }

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
var status := ""

var _grid: Node2D  # draws the floor markings underneath the furniture
var _pressed := false
var _dragging := false
var _press_pos := Vector2.ZERO

@onready var store: Store = get_parent()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.build_mode = self
	_grid = Node2D.new()
	_grid.z_index = -1  # under the furniture (the floor tiles are at -2)
	_grid.draw.connect(_draw_grid)
	add_child(_grid)


func enter() -> void:
	if active or Game.day_over or get_tree().paused:  # not on top of the pause menu
		return
	active = true
	get_tree().paused = true
	select_tool(Tool.NONE)


func exit() -> void:
	if not active:
		return
	_clear_selection()
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

	if event.is_action_pressed("build") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_back()
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_pressed = true
					_dragging = false
					_press_pos = event.position
				elif _pressed:
					_pressed = false
					if not _dragging:
						var touch: bool = event.device == InputEvent.DEVICE_ID_EMULATION
						tap(_to_world(event.position), touch)
			MOUSE_BUTTON_RIGHT:
				if event.pressed:
					_back()
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					Game.player.zoom_by(1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					Game.player.zoom_by(1.0 / 1.1)
	elif event is InputEventMouseMotion:
		if _pressed and (event.position - _press_pos).length() > DRAG_THRESHOLD:
			_dragging = true
		if _dragging:
			_pan(-event.relative)
		elif event.device != InputEvent.DEVICE_ID_EMULATION:
			_hover(_to_world(event.position))
	else:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not active:
		return
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v != Vector2.ZERO:
		_pan(v * PAN_SPEED * delta)


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
	_refresh()


## Furniture you can sell, drawn at `world_pos` or standing on that cell.
func furniture_at(world_pos: Vector2) -> Interactable:
	var obj := _object_at(world_pos, func(o: Interactable): return o.is_sellable())
	return obj


## Anything the Move tool can pick up (furniture, register, computer, sign).
func movable_at(world_pos: Vector2) -> Interactable:
	return _object_at(world_pos, func(o: Interactable): return o.is_movable())


func _object_at(world_pos: Vector2, ok: Callable) -> Interactable:
	var obj := store.interactable_at_point(world_pos)
	if obj == null or not ok.call(obj):
		obj = store.objects.get(Iso.world_to_cell(world_pos))
	if obj and ok.call(obj):
		return obj
	return null


# ---------------------------------------------------------------- actions

func _try_place(cell: Vector2i) -> void:
	if cursor_error != "":
		Game.message.emit(cursor_error)
		Settings.vibrate(0.6, 0.1)
		return
	var cost: float = Game.FURNITURE[place_id].cost
	if not Game.spend(cost):
		return
	store.add_furniture(place_id, cell)
	store.layout_changed()
	Settings.vibrate(0.3, 0.05)
	Game.show_popup(Iso.cell_to_world(cell) + Vector2(0, -50), "-$%d" % int(cost), BAD_COLOR)
	_set_cursor(cell)  # re-check the spot (now taken)


func _pick_up(obj: Interactable) -> void:
	_set_selected(null)
	moving = obj
	moving.modulate = Color(1, 1, 1, 0.35)
	_set_cursor(obj.cell)


func _try_move(cell: Vector2i) -> void:
	if cell == moving.cell:
		_put_down()  # dropped it back where it was
		return
	if cursor_error != "":
		Game.message.emit(cursor_error)
		return
	store.move_object(moving, cell)
	Settings.vibrate(0.3, 0.05)
	_put_down()


func _put_down() -> void:
	if is_instance_valid(moving):
		moving.modulate = Color.WHITE
	moving = null
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


func _set_selected(obj: Interactable) -> void:
	if selected == obj:
		return
	if is_instance_valid(selected):
		selected.modulate = Color.WHITE
	selected = obj
	if selected:
		selected.modulate = SELL_TINT if tool == Tool.SELL else PICK_TINT
	_refresh()


func _set_cursor(cell: Vector2i) -> void:
	cursor = cell
	cursor_error = ""
	preview_line.clear()
	if cell != Store.NO_CELL:
		if tool == Tool.PLACE:
			cursor_error = store.placement_error(cell, place_id)
			if cursor_error == "" and Game.money < Game.FURNITURE[place_id].cost:
				cursor_error = "Not enough money"
			if _placing_register():
				preview_line = store.preview_line(cell)
		elif moving:
			if cell != moving.cell:
				cursor_error = store.placement_error(cell, moving.furniture_id, moving)
			if moving is Register:
				preview_line = store.preview_line(cell, moving)
	_refresh()


func _placing_register() -> bool:
	return tool == Tool.PLACE and Game.FURNITURE[place_id].kind == "register"


func _refresh() -> void:
	var click := "tap again" if Game.touch_ui else "click"
	match tool:
		Tool.NONE:
			status = "Buy furniture, or pick Move / Sell. Drag to look around."
		Tool.PLACE:
			var f: Dictionary = Game.FURNITURE[place_id]
			if cursor == Store.NO_CELL:
				status = "%s ($%d): pick a spot." % [f.name, int(f.cost)]
			elif cursor_error != "":
				status = "%s: %s" % [f.name, cursor_error]
			elif _placing_register():
				status = "%s ($%d): %s to buy. Its line (yellow) needs to stay clear." % [f.name, int(f.cost), click]
			else:
				status = "%s ($%d): %s to buy." % [f.name, int(f.cost), click]
		Tool.MOVE:
			if moving == null:
				status = "Pick up anything to move it: furniture, registers, the computer, the sign..."
			elif cursor_error != "":
				status = "Can't move the %s here: %s" % [moving.display_name(), cursor_error]
			elif moving is Register:
				status = "Pick a spot and %s to put the register down. The line (yellow) comes with it." % click
			else:
				status = "Pick a new spot and %s to put the %s down." % [click, moving.display_name()]
		Tool.SELL:
			if selected:
				var refund: float = Game.FURNITURE[selected.furniture_id].cost * Game.SELL_REFUND
				status = "Sell this %s for $%d? %s to sell." % [Game.FURNITURE[selected.furniture_id].name.to_lower(), int(refund), click.capitalize()]
			else:
				status = "Pick something to sell (you get half back). The first register can't be sold."
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
		var pos := Iso.cell_to_world(cursor) + Vector2(-32, -(ghost.get_height() - 16))
		draw_texture(ghost, pos, Color(1, 1, 1, 0.65) if ok else Color(1, 0.5, 0.5, 0.5))


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
	if (tool == Tool.PLACE or is_instance_valid(moving)) and cursor != Store.NO_CELL:
		var color := OK_COLOR if cursor_error == "" else BAD_COLOR
		_diamond(cursor, Color(color, 0.3), true)
		_diamond(cursor, color, false)


func _diamond(cell: Vector2i, color: Color, filled: bool) -> void:
	var c := Iso.cell_to_world(cell)
	var pts := PackedVector2Array([c + Vector2(0, -16), c + Vector2(32, 0), c + Vector2(0, 16), c + Vector2(-32, 0)])
	if filled:
		_grid.draw_colored_polygon(pts, color)
	else:
		pts.append(pts[0])
		_grid.draw_polyline(pts, color, 1.0)
