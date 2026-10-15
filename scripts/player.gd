class_name Player
extends CharacterBody2D
## The store worker.
##   PC:      WASD / arrows to move, E or Space to use what's in front of you,
##            Q to scan a shelf (once you own the scanner), or click a spot to
##            walk there. Mouse wheel zooms.
##   Android: tap a spot to walk there, tap an object to walk over and use it,
##            or press the big buttons in the corner.

enum Action { USE, DROP, SCAN }

const WALK_SPEED := 3.2  # cells per second
const DROP_SECONDS := 0.25

const MOP_TEXTURE := preload("res://assets/sprites/mop_held.png")

var store: Store
var carry_product := ""
var carry_count := 0
var holding_mop := false  # zombie game: grabbed from the mop bucket
var mop_sprite: Sprite2D

var focused: Interactable = null  # what E would use right now
var scan_focus: Interactable = null  # what Q would scan right now
var path: Array[Vector2i] = []
var tap_target: Interactable = null  # object to use when we arrive

# Timed action (the Project Zomboid style progress bar)
var action_target: Interactable = null
var action_kind := Action.USE
var action_time := 0.0
var action_duration := 0.0
var action_label := ""

var _walk_anim := 0.0
var _stuck_time := 0.0
var _last_prompt := ["-", false, "-"]

@onready var sprite: Sprite2D = $Sprite
@onready var carry_sprite: Sprite2D = $CarryBox
@onready var camera: Camera2D = $Camera


func _ready() -> void:
	Game.player = self
	mop_sprite = Sprite2D.new()
	mop_sprite.texture = MOP_TEXTURE
	mop_sprite.position = Vector2(6, -16)
	mop_sprite.visible = false
	add_child(mop_sprite)
	# Lets build mode pan the camera while the game is paused.
	camera.process_mode = Node.PROCESS_MODE_ALWAYS


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if is_busy() and input != Vector2.ZERO:
		cancel_action()

	if is_busy():
		velocity = Vector2.ZERO
		_tick_action(delta)
	elif input != Vector2.ZERO:
		path.clear()
		tap_target = null
		velocity = Iso.velocity_toward(input, WALK_SPEED) * minf(input.length(), 1.0)
	elif not path.is_empty():
		_follow_path(delta)
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_animate(delta)
	_update_focus()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_on_tap(get_canvas_transform().affine_inverse() * event.position)
			MOUSE_BUTTON_WHEEL_UP:
				zoom_by(1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom_by(1.0 / 1.1)
	elif event.is_action_pressed("interact"):
		try_interact()
	elif event.is_action_pressed("scan"):
		try_scan()


func _draw() -> void:
	if is_carrying():
		draw_texture(Game.icon(carry_product), Vector2(-4, -56))
	if not is_busy():
		return
	if action_kind == Action.SCAN and is_instance_valid(action_target):
		# red scanner laser from the player's hand to the shelf
		var hand := Vector2(-5.0 if sprite.flip_h else 5.0, -19.0)
		var to := action_target.position - position + Vector2(0, -22)
		var flicker := 0.55 + 0.45 * sin(action_time * 60.0)
		draw_line(hand, to, Color(1.0, 0.15, 0.1, 0.8 * flicker), 1.0)
		draw_circle(to, 2.0, Color(1.0, 0.3, 0.2, flicker))
	var f := clampf(action_time / action_duration, 0.0, 1.0)
	draw_rect(Rect2(-11, -44, 22, 5), Color(0.08, 0.08, 0.1, 0.9))
	draw_rect(Rect2(-10, -43, 20 * f, 3), Color(0.55, 0.85, 0.45))


# ---------------------------------------------------------------- using things

## Uses whatever is focused (E key / Space / the on-screen button).
func try_interact() -> void:
	if is_busy():
		return
	if is_instance_valid(focused) and focused.can_interact(self):
		use(focused)
	elif can_drop():
		_start_action(null, DROP_SECONDS, Action.DROP)


## Scans the nearest shelf with the handheld scanner (Q / the SCAN button).
func try_scan() -> void:
	if is_busy():
		return
	if is_instance_valid(scan_focus) and scan_focus.can_scan(self):
		_start_action(scan_focus, scan_focus.get_scan_time(self), Action.SCAN)


func use(obj: Interactable) -> void:
	if not obj.can_interact(self):
		var why := obj.get_prompt(self)
		if why != "":
			Game.message.emit(why)
		return
	var t := obj.get_action_time(self)
	if t <= 0.0:
		obj.interact(self)
	else:
		_start_action(obj, t, Action.USE)


func is_busy() -> bool:
	return action_duration > 0.0


func cancel_action() -> void:
	action_target = null
	action_duration = 0.0


func _start_action(target: Interactable, duration: float, kind: Action) -> void:
	action_target = target
	action_kind = kind
	action_time = 0.0
	action_duration = duration
	match kind:
		Action.DROP:
			action_label = "Dropping box..."
		Action.SCAN:
			action_label = "Scanning..."
		_:
			action_label = target.get_action_label(self)
	path.clear()
	tap_target = null
	if target:
		sprite.flip_h = target.position.x < position.x


func _tick_action(delta: float) -> void:
	action_time += delta
	if action_time < action_duration:
		return
	var target := action_target
	var kind := action_kind
	cancel_action()
	match kind:
		Action.DROP:
			_drop_box()
		Action.SCAN:
			if is_instance_valid(target) and target.can_scan(self):
				target.scan(self)
		_:
			if is_instance_valid(target) and target.can_interact(self):
				target.interact(self)


# ---------------------------------------------------------------- carrying

func is_carrying() -> bool:
	return carry_count > 0


func pick_up(product_id: String, count: int) -> void:
	carry_product = product_id
	carry_count = count
	_update_carry()


func take_from_carry(n: int) -> void:
	carry_count -= n
	if carry_count <= 0:
		carry_count = 0
		carry_product = ""
		Game.message.emit("Box empty. Tossed it.")
	_update_carry()


## Lets go of the box without a fuss (it went somewhere, e.g. on a rack).
func drop_carry() -> void:
	carry_product = ""
	carry_count = 0
	_update_carry()


func can_drop() -> bool:
	return is_carrying() and store.can_drop_at(current_cell())


func _drop_box() -> void:
	if store.drop_box(current_cell(), carry_product, carry_count):
		carry_product = ""
		carry_count = 0
		_update_carry()


func _update_carry() -> void:
	carry_sprite.visible = is_carrying()
	mop_sprite.visible = holding_mop


func set_holding_mop(on: bool) -> void:
	holding_mop = on
	_update_carry()


# ---------------------------------------------------------------- moving

func current_cell() -> Vector2i:
	return Iso.world_to_cell(position)


func zoom_by(factor: float) -> void:
	var z := clampf(camera.zoom.x * factor, 1.0, 5.0)
	camera.zoom = Vector2(z, z)


func walk_to(cell: Vector2i) -> bool:
	var p := store.find_path(current_cell(), cell)
	if p.is_empty():
		return false
	if p.size() > 1:
		p.remove_at(0)  # we're already in the first cell
	path = p
	_stuck_time = 0.0
	return true


## Furniture moved in build mode: forget the old route.
func on_layout_changed() -> void:
	path.clear()
	tap_target = null


func _on_tap(world_pos: Vector2) -> void:
	if is_busy():
		cancel_action()
	var obj := store.interactable_at_point(world_pos, holding_mop)
	if obj and not obj is Decoration:
		if obj is Spill and not holding_mop:
			obj = null  # just walk there
	if obj and not obj is Decoration:
		store.floor_layer.show_marker(obj.cell)
		if Iso.chebyshev(current_cell(), obj.cell) <= 1:
			path.clear()
			use(obj)
			return
		var dest := obj.cell if store.is_walkable(obj.cell) else store.stand_cell_for(obj.cell, current_cell())
		if dest != Store.NO_CELL and walk_to(dest):
			tap_target = obj
		return
	var cell := Iso.world_to_cell(world_pos)
	if store.is_walkable(cell):
		store.floor_layer.show_marker(cell)
		tap_target = null
		walk_to(cell)


func _follow_path(delta: float) -> void:
	var to_target := Iso.cell_to_world(path[0]) - position
	if to_target.length() < 2.0:
		path.remove_at(0)
		if path.is_empty():
			velocity = Vector2.ZERO
			_arrived()
			return
		to_target = Iso.cell_to_world(path[0]) - position
	var v := Iso.velocity_toward(to_target, WALK_SPEED)
	if v.length() * delta > to_target.length():
		v = to_target / delta  # don't overshoot the cell center
	velocity = v
	# Give up if something is in the way.
	if get_real_velocity().length() < 2.0:
		_stuck_time += delta
		if _stuck_time > 0.5:
			path.clear()
			tap_target = null
	else:
		_stuck_time = 0.0


func _arrived() -> void:
	if is_instance_valid(tap_target):
		var obj := tap_target
		tap_target = null
		if Iso.chebyshev(current_cell(), obj.cell) <= 1:
			use(obj)


func _animate(delta: float) -> void:
	var moving := velocity.length() > 5.0
	if moving:
		_walk_anim += delta * 14.0
		sprite.position.y = -roundf(absf(sin(_walk_anim)) * 2.0)
		if absf(velocity.x) > 1.0:
			sprite.flip_h = velocity.x < 0.0
	else:
		sprite.position.y = 0.0
	carry_sprite.position.y = -14.0 + sprite.position.y
	mop_sprite.position = Vector2(-6.0 if sprite.flip_h else 6.0, -16.0 + sprite.position.y)
	mop_sprite.flip_h = sprite.flip_h


# ---------------------------------------------------------------- focus + prompt

func _update_focus() -> void:
	var best: Interactable = null
	var info: Interactable = null
	var scannable: Interactable = null
	var best_d := INF
	var info_d := INF
	var scan_d := INF
	for obj in store.interactables_near(current_cell()):
		var d := position.distance_to(obj.position)
		if obj.can_interact(self):
			if d < best_d:
				best_d = d
				best = obj
		elif d < info_d and obj.get_prompt(self) != "":
			info_d = d
			info = obj
		if d < scan_d and obj.can_scan(self):
			scan_d = d
			scannable = obj
	scan_focus = scannable

	var new_focus := best if best else info
	if focused != new_focus:
		if is_instance_valid(focused):
			focused.highlighted = false
		focused = new_focus
	if focused:
		focused.highlighted = best != null

	var text := ""
	var can := false
	var scan_text := ""
	if is_busy():
		text = action_label
	else:
		if best:
			text = best.get_prompt(self)
			can = true
		elif can_drop():
			text = "Drop box"
			can = true
		elif info:
			text = info.get_prompt(self)
		if scannable:
			scan_text = scannable.get_scan_prompt(self)
	var now := [text, can, scan_text]
	if now != _last_prompt:
		_last_prompt = now
		Game.prompt_changed.emit(text, can, scan_text)
