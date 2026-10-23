class_name FirstPerson
extends Node
## First person: the store in 3D, through your own eyes. V (R3 on a
## controller, or the View button) switches between this and the normal
## isometric view.
##
## The 3D view is built from the same map and objects as the normal view,
## and from the same art (see FpArt): floor tiles laid flat, walls and
## shelves as boxes with their sides unskewed from the iso sprites, and
## people and everything else as billboards that always face you, like the
## sprites in old shooters. The normal 2D store keeps running underneath
## (it's only hidden), so everything plays the same: this only draws it,
## and turns your keys, mouse, stick and taps into walking and looking.
##
## It's drawn at half the screen's resolution (chunky pixels, like the
## art, and quick on phones). One cell of the map is one unit; heights
## come from the art: PX_UP art pixels to a unit.

signal toggled(on: bool)

const PX_UP := 32.0  # art pixels in one unit of height
const PX_ACROSS := 45.25  # art pixels across a cell seen from the side (64 px is its diagonal)
const EYE := 0.88  # your eyes, above the floor
const RES_DIV := 2  # the 3D view's pixels are this many screen pixels across
const FOV := 72.0
const MOUSE_LOOK := 0.0032  # radians per mouse pixel
const TOUCH_LOOK := 0.006  # radians per finger pixel
const STICK_LOOK := 2.8  # radians per second, right stick all the way
const KEY_TURN := 2.4  # radians per second, Left / Right arrow
const MAX_PITCH := 1.2
const TAP_SLOP := 24.0  # a finger that moves farther than this is looking, not tapping
const REACH := 16.0  # how far away (cells) a tap can pick a spot
const RESYNC_EVERY := 4  # frames between checks on things that rarely change
const SKY := Color(0.4, 0.46, 0.46)
const CEILING := Color(0.16, 0.16, 0.18)
const CEILING_LIGHT := Color(0.85, 1.0, 0.78)
const NO_SPOT := Vector2(INF, INF)

var active := false
var yaw := 0.0  # 0 looks toward -y on the map (the top right of the normal view)
var pitch := -0.05
var store: Store
var player: Player
var layer: CanvasLayer
var screen: TextureRect
var crosshair: Control
var view: SubViewport
var camera: Camera3D
var env: Environment
var world: Node3D  # the 3D store
var _floor: Node3D
var _floor_version := -1
var _mirrors := {}  # 2D node instance id -> [node, kind, Node3D]
var _signs := {}  # instance id -> what it looked like last time (rebuild when it changes)
var _spills := {}  # cell -> MeshInstance3D
var _frame := 0
var _suspended := false  # turned off for build mode (or a menu that needs the normal view)
var _finger := NO_SPOT
var _finger_moved := 0.0
var _bob := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.fp = self
	tree_exiting.connect(func():
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)
	layer = CanvasLayer.new()
	layer.layer = 0
	layer.visible = false
	add_child(layer)
	view = SubViewport.new()
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_DISABLED
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.size = Vector2i(640, 360)
	add_child(view)
	screen = TextureRect.new()
	screen.texture = view.get_texture()
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.stretch_mode = TextureRect.STRETCH_SCALE
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(screen)
	crosshair = Control.new()
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crosshair.draw.connect(_draw_crosshair)
	layer.add_child(crosshair)

	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY
	env.fog_enabled = true
	env.fog_light_color = SKY
	env.fog_density = 0.03
	we.environment = env
	view.add_child(we)
	world = Node3D.new()
	view.add_child(world)
	_floor = Node3D.new()
	world.add_child(_floor)
	camera = Camera3D.new()
	camera.fov = FOV
	camera.near = 0.05
	camera.far = 80.0
	view.add_child(camera)
	camera.current = true
	if Game.store:
		attach(Game.store)
		if Settings.first_person:
			set_active.call_deferred(true)  # (as you left it)


## Hooks up the store (the HUD calls this once the store is built).
func attach(s: Store) -> void:
	store = s
	player = s.player
	Game.build_mode.changed.connect(_on_build_changed)


## Off for good (the lender's visit plays in the normal view).
func force_off() -> void:
	_suspended = false
	set_active(false)


## Switches first person on or off. `remember`: keep it that way next
## time the game starts (Settings).
func set_active(on: bool, remember := false) -> void:
	if remember:
		Settings.set_first_person(on)
		_suspended = false
	if on == active or store == null:
		return
	active = on
	if on:
		_look_where_you_face()
		_sync(true)
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	else:
		view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if is_instance_valid(player):
			player.look_dir = Vector2.ZERO
	store.visible = not on
	layer.visible = on
	toggled.emit(on)


func toggle() -> void:
	set_active(not active, true)


## Build mode is seen from above: first person waits until you're done.
func _on_build_changed() -> void:
	var building: bool = Game.build_mode.active
	if building and active:
		_suspended = true
		set_active(false)
	elif not building and _suspended:
		_suspended = false
		set_active(true)


func _look_where_you_face() -> void:
	var f: Vector2 = player.facing if player.facing != Vector2.ZERO else Vector2(0, -1)
	var g := iso_to_grid(f)
	if g.length() > 0.01:
		yaw = atan2(-g.x, -g.y)
	pitch = -0.05


# ---------------------------------------------------------------- conversions

## A 2D (isometric) position or direction as map (grid) coordinates.
static func iso_to_grid(v: Vector2) -> Vector2:
	var a := v.x / (Iso.TILE_W * 0.5)
	var b := v.y / (Iso.TILE_H * 0.5)
	return Vector2((a + b) * 0.5, (b - a) * 0.5)


## A map (grid) direction or position in 2D (isometric) pixels.
static func grid_to_iso(g: Vector2) -> Vector2:
	return Vector2((g.x - g.y) * Iso.TILE_W * 0.5, (g.x + g.y) * Iso.TILE_H * 0.5)


## Where a 2D position is in the 3D store, `height` units off the floor.
static func to_3d(iso_pos: Vector2, height := 0.0) -> Vector3:
	var g := iso_to_grid(iso_pos)
	return Vector3(g.x, height, g.y)


## The way you're looking, on the map.
func forward() -> Vector2:
	return Vector2(-sin(yaw), -cos(yaw))


## Your right, on the map.
func right() -> Vector2:
	return Vector2(cos(yaw), -sin(yaw))


## The way you're looking, in 2D pixels (what the player's `facing` uses).
func facing() -> Vector2:
	return grid_to_iso(forward()).normalized()


## How much `iso_dir` (from you) is ahead of you: 1 straight ahead, 0 to
## the side, -1 behind.
func ahead(iso_dir: Vector2) -> float:
	var g := iso_to_grid(iso_dir)
	return forward().dot(g.normalized()) if g.length() > 0.001 else 1.0


# ---------------------------------------------------------------- walking and looking

## The move keys / left stick, as [strafe, -forward] (like
## Input.get_vector). Left and Right on the arrow keys turn instead.
func move_input() -> Vector2:
	var strafe := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	if Input.is_physical_key_pressed(KEY_RIGHT):
		strafe -= 1.0
	if Input.is_physical_key_pressed(KEY_LEFT):
		strafe += 1.0
	var fwd := Input.get_action_strength("move_up") - Input.get_action_strength("move_down")
	var v := Vector2(clampf(strafe, -1.0, 1.0), -fwd)
	return v.limit_length(1.0) if v.length() > 0.12 else Vector2.ZERO


## The 2D velocity for walking `input` (from move_input) at `speed` cells
## a second, the way you're looking.
func walk_velocity(input: Vector2, speed: float) -> Vector2:
	var g := forward() * -input.y + right() * input.x
	return grid_to_iso(g.limit_length(1.0)) * speed


func _process(delta: float) -> void:
	if not active or store == null or not is_instance_valid(player):
		return
	var win := get_viewport().get_visible_rect().size
	var want := Vector2i(maxi(16, int(win.x / RES_DIV)), maxi(16, int(win.y / RES_DIV)))
	if view.size != want:
		view.size = want
	screen.size = win
	screen.position = Vector2.ZERO
	crosshair.size = win
	crosshair.visible = not Game.menu_open and not get_tree().paused
	crosshair.queue_redraw()
	# The night (and the day's light) the normal view has.
	var mood: Color = store.mood.color
	screen.modulate = Color.WHITE.lerp(mood, 0.55)
	# Looking: the right stick, and Left / Right on the arrow keys.
	if not Game.menu_open and not get_tree().paused:
		var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		if stick.length() > 0.2:
			yaw -= stick.x * absf(stick.x) * STICK_LOOK * delta
			pitch = clampf(pitch - stick.y * absf(stick.y) * STICK_LOOK * 0.6 * delta, -MAX_PITCH, MAX_PITCH)
		var turn := float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT))
		if not player.is_typing():
			yaw -= turn * KEY_TURN * delta
	player.look_dir = facing()
	_update_mouse()
	# The camera is your eyes (bobbing a little as you walk).
	var moving := player.velocity.length() > 5.0
	_bob = _bob + delta * (11.0 if player.sprinting else 8.0) if moving else 0.0
	var at := to_3d(player.position, EYE + (sin(_bob) * 0.025 if moving else 0.0))
	camera.position = at
	camera.rotation = Vector3(pitch, yaw, 0.0)
	_frame += 1
	_sync(_frame % RESYNC_EVERY == 0)


## The mouse looks around (it's hidden) while nothing's open over the store.
func _update_mouse() -> void:
	var want := Settings.is_desktop() and not Game.touch_ui and not Game.menu_open and not get_tree().paused \
		and not Game.cutscene and get_window().has_focus()
	var mode := Input.MOUSE_MODE_CAPTURED if want else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != mode:
		Input.mouse_mode = mode


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("view") and not event.is_echo() and not Game.cutscene and not Game.build_mode.active:
		get_viewport().set_input_as_handled()
		toggle()
		return
	if not active or Game.menu_open or get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_by(event.relative * MOUSE_LOOK)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if event.button_index == MOUSE_BUTTON_LEFT:
				player.try_interact()  # (what's in front of you)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				player.try_scan()
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			tap(event.position)  # (no captured mouse: click where to go)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			_finger = event.position
			_finger_moved = 0.0
		elif _finger != NO_SPOT:
			if _finger_moved < TAP_SLOP and not PinchZoom.pinching:
				tap(event.position)
			_finger = NO_SPOT
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == 0 and not PinchZoom.pinching:
		_finger_moved += event.relative.length()
		if _finger_moved >= TAP_SLOP:
			look_by(event.relative * TOUCH_LOOK)
		get_viewport().set_input_as_handled()


## Turns your head by `by` (radians: x left/right, y up/down).
func look_by(by: Vector2) -> void:
	yaw -= by.x
	pitch = clampf(pitch - by.y, -MAX_PITCH, MAX_PITCH)


## A tap or click on the 3D view at `screen_pos`: walk to that spot, or to
## what's there and use it (like a tap in the normal view).
func tap(screen_pos: Vector2) -> void:
	var hit := pick(screen_pos)
	if hit.is_empty():
		return
	if hit.has("object"):
		var obj: Interactable = hit.object
		player._on_tap(obj.position + Vector2(0, -12))
	else:
		player._on_tap(Iso.cell_to_world(hit.cell))


## What's at `screen_pos` on the 3D view: {"object": Interactable} or
## {"cell": Vector2i} (the floor), or {} for nothing (the sky, a wall).
func pick(screen_pos: Vector2) -> Dictionary:
	var win := get_viewport().get_visible_rect().size
	var p := screen_pos * Vector2(view.size) / win
	var origin := camera.project_ray_origin(p)
	var dir := camera.project_ray_normal(p)
	var t := 0.05
	while t < REACH:
		var at := origin + dir * t
		var cell := Vector2i(roundi(at.x), roundi(at.z))
		var obj: Interactable = _object_at(cell)
		if obj and at.y < _height_of(obj):
			return {"object": obj}
		if store.wall_cells.has(cell) or (obj == null and not store.is_walkable(cell) and at.y < 1.2 and store.astar.is_in_boundsv(cell)):
			return {}
		if at.y <= 0.0:
			return {"cell": cell} if store.is_walkable(cell) else {}
		t += 0.04
	return {}


func _object_at(cell: Vector2i) -> Interactable:
	if store.boxes.has(cell):
		return store.boxes[cell]
	if store.objects.has(cell) and not store.objects[cell] is Decoration:
		return store.objects[cell]
	if store.town and store.town.objects.has(cell) and store.town.objects[cell] is Interactable:
		var o: Interactable = store.town.objects[cell]
		return o if o.can_interact(player) or o.get_prompt(player) != "" else null
	return null


func _height_of(obj: Interactable) -> float:
	if obj is StockBox:
		return 0.5
	if obj is Shelf or obj is StorageRack:
		return FpArt.box_height(Game.FURNITURE[obj.furniture_id].texture) / PX_UP
	return 1.3


## Where 2D position `iso_pos` is on the screen, for popups and the
## shopper card. Those are given as a spot some pixels above someone or
## something ("+2 Canned Guts" over a shopper's head): that's worked out
## from whatever stands right under it. Off the screen if it's behind you.
func to_screen(iso_pos: Vector2) -> Vector2:
	var base := iso_pos
	var best := 120.0
	for n in store.world.get_children():
		if n is Node2D and not n is Player:
			var at: Vector2 = (n as Node2D).position
			var up := at.y - iso_pos.y
			if absf(at.x - iso_pos.x) < 3.0 and up >= 0.0 and up < best:
				best = up
				base = at
	for sp: Spill in store.spills.values():
		var up := sp.position.y - iso_pos.y
		if absf(sp.position.x - iso_pos.x) < 3.0 and up >= 0.0 and up < best:
			best = up
			base = sp.position
	var height := (base.y - iso_pos.y) / PX_UP if best < 120.0 else 1.1
	var p := to_3d(base, height)
	if camera.is_position_behind(p):
		return Vector2(-10000, -10000)
	var win := get_viewport().get_visible_rect().size
	var at := camera.unproject_position(p) * win / Vector2(view.size)
	return Vector2(clampf(at.x, 0.0, win.x), clampf(at.y, win.y * 0.14, win.y))  # (over something right in front of you: the top of the screen)


## A small + in the middle of the screen (yellow when E would use
## something), the bar of what you're doing (stocking, ringing up...), and
## what's in your hands: the box you're carrying, or the mop.
func _draw_crosshair() -> void:
	var c := (crosshair.size / 2.0).round()
	var on := is_instance_valid(player) and player.focused != null and player.focused.highlighted
	var col := UI.WARN if on else Color(1, 1, 1, 0.85)
	var arm := 7.0 if on else 5.0
	for w in [[3.0, Color(0, 0, 0, 0.55)], [1.0, col]]:
		crosshair.draw_line(c - Vector2(arm, 0), c + Vector2(arm, 0), w[1], w[0])
		crosshair.draw_line(c - Vector2(0, arm), c + Vector2(0, arm), w[1], w[0])
	if not is_instance_valid(player):
		return
	if player.is_busy() and player.action_duration > 0.0:
		var bar := Rect2(c + Vector2(-50, 22), Vector2(100, 10))
		crosshair.draw_rect(bar.grow(2), Color(0, 0, 0, 0.7))
		crosshair.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(player.action_time / player.action_duration, 0, 1), bar.size.y)), UI.GOOD)
	var k := roundf(crosshair.size.y / 120.0)  # (art pixels to screen pixels)
	if player.is_carrying():
		var box: Texture2D = StockBox.TEXTURE
		var icon := Game.icon(player.carry_product)
		var at := Vector2(c.x - box.get_width() * k / 2.0, crosshair.size.y - box.get_height() * k * 0.8)
		crosshair.draw_texture_rect(box, Rect2(at, box.get_size() * k), false)
		if icon:
			crosshair.draw_texture_rect(icon, Rect2(at + Vector2(28, box.get_height() - 16 - 24) * k, icon.get_size() * k), false)
	elif player.holding_mop:
		var mop: Texture2D = Player.MOP_TEXTURE
		var at := Vector2(crosshair.size.x * 0.72, crosshair.size.y - mop.get_height() * k * 0.9)
		crosshair.draw_texture_rect(mop, Rect2(at, mop.get_size() * k), false)


# ---------------------------------------------------------------- building the 3D store

## Keeps the 3D store matching the 2D one. `full`: check everything
## (otherwise just the people, who move every frame).
func _sync(full: bool) -> void:
	if store.floor_layer.version != _floor_version:
		_build_floor()
	var seen := {}
	for n in store.world.get_children():
		var id := n.get_instance_id()
		seen[id] = true
		var m: Array = _mirrors.get(id, [])
		if m.is_empty():
			var kind := _kind_of(n)
			m = [n, kind, null]
			_mirrors[id] = m
			full = true
		if m[1] == "person":
			_sync_person(n, m)
		elif m[1] != "skip" and (full or m[2] == null):
			_sync_thing(n, m)
	for id in _mirrors.keys():
		if not seen.has(id):
			var gone: Array = _mirrors[id]
			if is_instance_valid(gone[2]):
				gone[2].queue_free()
			_mirrors.erase(id)
			_signs.erase(id)
	if full:
		_sync_spills()


## What a 2D node becomes in 3D.
func _kind_of(n: Node) -> String:
	if n is Player:
		return "skip"
	if n.get("sprite") is Sprite2D:
		return "person"  # shoppers, staff, townsfolk, spies
	if n is Shelf:
		return "shelf"
	if n is StorageRack:
		return "rack"
	if n is RivalShelf:
		return "box"
	if n is Sprite2D:
		var tex: Texture2D = (n as Sprite2D).texture
		return "wall" if tex and tex.resource_path.get_file().begins_with("wall_") else "skip"
	if n is Prop:
		for t in (n as Prop).textures:
			var f := t.resource_path.get_file()
			if f.begins_with("wall_"):
				return "wall"
			if f.begins_with("shop_shelf"):
				return "box"
		return "sprite"
	if n is Interactable:
		return "sprite"
	return "skip"


func _sync_person(n: Node, m: Array) -> void:
	var sp: Sprite2D = n.get("sprite")
	var s: Sprite3D = m[2]
	if s == null:
		s = _billboard()
		world.add_child(s)
		m[2] = s
	var tex := sp.texture
	s.visible = n.visible and sp.visible and tex != null and (n as CanvasItem).modulate.a > 0.02
	if not s.visible:
		return
	if s.texture != tex:
		s.texture = tex
	var size := tex.get_size()
	var top_left := sp.position + sp.offset - (size / 2.0 if sp.centered else Vector2.ZERO)
	s.offset = Vector2(top_left.x + size.x / 2.0, -(top_left.y + size.y / 2.0))
	s.flip_h = sp.flip_h
	s.modulate = Color(1, 1, 1, (n as CanvasItem).modulate.a * sp.modulate.a) * Color(sp.modulate.r, sp.modulate.g, sp.modulate.b)
	s.position = to_3d((n as Node2D).global_position - store.global_position)


## Things that stand still (furniture, walls, scenery): rebuilt only when
## they look different.
func _sync_thing(n: Node, m: Array) -> void:
	var look := _signature(n, m[1])
	var id := n.get_instance_id()
	if _signs.get(id) == look and is_instance_valid(m[2]):
		var node3: Node3D = m[2]
		node3.visible = (n as CanvasItem).visible
		if n is Interactable:
			_highlight(node3, n.highlighted)
		return
	_signs[id] = look
	if is_instance_valid(m[2]):
		m[2].queue_free()
	var built: Node3D = null
	match m[1]:
		"wall":
			built = _wall(n)
		"shelf":
			built = _shelf(n)
		"rack":
			built = _rack(n)
		"box":
			built = _box(n)
		"sprite":
			built = _sprite_thing(n)
	m[2] = built
	if built:
		world.add_child(built)
		built.visible = (n as CanvasItem).visible


func _signature(n: Node, kind: String) -> String:
	var pos := (n as Node2D).position
	match kind:
		"shelf":
			return "%s|%d|%s|%d" % [pos, n.rotation_step, n.product_id, n.stock]
		"rack":
			return "%s|%d|%s" % [pos, n.rotation_step, ",".join(n.boxes.map(func(b): return b.product_id))]
		"sprite":
			var layers: Array = n.look_3d()
			return "%s|%s" % [pos, ",".join(layers.map(func(l): return "%s%s%s" % [l[0].get_rid() if l[0] else 0, l[1], l[2] if l.size() > 2 else false]))]
		_:
			return "%s|%d" % [pos, n.get("rotation_step") if n.get("rotation_step") != null else 0]


func _highlight(node3: Node3D, on: bool) -> void:
	if node3 is Sprite3D:
		(node3 as Sprite3D).modulate = Color(1.35, 1.3, 1.1) if on else Color.WHITE


func _billboard() -> Sprite3D:
	var s := Sprite3D.new()
	s.pixel_size = 1.0 / PX_UP
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.double_sided = true
	s.scale = Vector3(PX_UP / PX_ACROSS, 1.0, 1.0)
	return s


## A billboard of whatever `n` draws (its look_3d layers, flattened). A
## counter (a register, the computer, a shop's counter) is a box, with a
## billboard of what stands on it.
func _sprite_thing(n: Interactable) -> Node3D:
	var layers: Array = n.look_3d()
	if layers.is_empty():
		return null
	if layers.size() == 1:
		var tex: Texture2D = layers[0][0]
		var h := FpArt.prism_height(tex)
		if h > 0:
			return _counter(n, tex, h, layers[0])
	var flat := _flatten(layers)
	var s := _billboard()
	s.texture = flat[0]
	var size: Vector2 = flat[0].get_size()
	var top_left: Vector2 = flat[1]
	s.offset = Vector2(top_left.x + size.x / 2.0, -(top_left.y + size.y / 2.0))
	s.position = to_3d(n.position)
	return s


## Several [texture, top-left, mirrored] layers as one image: [texture,
## its top-left].
func _flatten(layers: Array) -> Array:
	if layers.size() == 1 and not (layers[0].size() > 2 and layers[0][2]):
		return [layers[0][0], layers[0][1]]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var key := "flat"
	for l: Array in layers:
		var t: Texture2D = l[0]
		lo = lo.min(l[1])
		hi = hi.max(l[1] + t.get_size())
		key += ":%s@%s%s" % [t.get_rid(), l[1], l[2] if l.size() > 2 else false]
	var parts := []
	for l: Array in layers:
		parts.append([l[0], Vector2i(l[1] - lo), l.size() > 2 and l[2]])
	return [FpArt.composite(key, Vector2i(hi - lo), parts), lo]


## A box one cell across with the faces of iso sprite `tex`, standing on
## `cell`'s floor, its front turned to `step` (Interactable.FACINGS).
## `front` replaces the front face (a shelf with its stock on it).
func _box_from(tex: Texture2D, cell_pos: Vector2, step: int, front: Texture2D = null, back_tex: Texture2D = null) -> MeshInstance3D:
	var h := FpArt.box_height(tex) / PX_UP
	var mi := MeshInstance3D.new()
	mi.mesh = FpArt.box_mesh(h, 0.98)
	var side := FpArt.face(tex, false)
	mi.set_surface_override_material(0, FpArt.material(front if front else FpArt.face(tex, true), true))
	mi.set_surface_override_material(1, FpArt.material(FpArt.face(back_tex if back_tex else tex, true), true))
	mi.set_surface_override_material(2, FpArt.material(side, true))
	mi.set_surface_override_material(3, FpArt.material(FpArt.top(tex), true))
	mi.position = to_3d(cell_pos)
	mi.rotation.y = posmod(step, 4) * PI / 2.0
	return mi


## A counter: a box as tall as the sprite's box, and a billboard of
## what's on top of it.
func _counter(n: Interactable, tex: Texture2D, h: int, layer: Array) -> Node3D:
	var base: Texture2D = Interactable.view_of(tex, 0)[0]
	var mi := MeshInstance3D.new()
	mi.mesh = FpArt.box_mesh(h / PX_UP, 0.98)
	var front := FpArt.material(FpArt.face(base, true, h), true)
	mi.set_surface_override_material(0, front)
	mi.set_surface_override_material(1, front)
	mi.set_surface_override_material(2, FpArt.material(FpArt.face(base, false, h), true))
	mi.set_surface_override_material(3, FpArt.material(FpArt.top(base, 32, h), true))
	mi.position = to_3d(n.position)
	mi.rotation.y = posmod(n.rotation_step, 4) * PI / 2.0
	var on_top := _billboard()
	on_top.texture = FpArt.above(layer[0], h)
	on_top.flip_h = layer.size() > 2 and layer[2]
	var size: Vector2 = on_top.texture.get_size()
	var top_left: Vector2 = layer[1]
	on_top.offset = Vector2(top_left.x + size.x / 2.0, -(top_left.y + size.y / 2.0))
	on_top.rotation.y = -mi.rotation.y  # (a billboard: this only undoes the box's turn)
	mi.add_child(on_top)
	return mi


func _wall(n: Node2D) -> Node3D:
	var tex: Texture2D = n.texture if n is Sprite2D else (n as Prop).textures[0]
	var path := tex.resource_path
	if path.ends_with("_low.png"):
		var tall := path.replace("_low.png", "_tall.png")
		if ResourceLoader.exists(tall):
			tex = load(tall)  # every wall is full height in first person
	var mi := MeshInstance3D.new()
	var h := FpArt.box_height(tex) / PX_UP
	mi.mesh = FpArt.box_mesh(h)
	var face := FpArt.material(FpArt.face(tex, true), true)
	for i in 3:
		mi.set_surface_override_material(i, face)
	mi.set_surface_override_material(3, FpArt.material(FpArt.top(tex), true))
	mi.position = to_3d(n.position)
	return mi


func _box(n: Interactable) -> Node3D:
	var tex: Texture2D = n.TEXTURE if n is RivalShelf else (n as Prop).textures[0]
	return _box_from(tex, n.position, n.rotation_step)


## A shelf (or cooler) with what's on it: the products stand on its front,
## as in the normal view, and its label floats over it.
func _shelf(sh: Shelf) -> Node3D:
	var tex: Texture2D = Game.FURNITURE[sh.furniture_id].texture
	var front_face := FpArt.face(tex, true)
	var h := FpArt.box_height(tex)
	var layers := [[front_face, Vector2i.ZERO]]
	if sh.stock > 0 and sh.product_id != "":
		var icon := Game.icon(sh.product_id)
		for i in mini(sh.stock, Shelf.SLOTS.size()):
			var slot: Vector2i = Shelf.SLOTS[i]
			layers.append([icon, Vector2i(slot.x + 32, h - slot.y - icon.get_height() - 3)])
	if sh is Fridge:
		layers.append([FpArt.face(Fridge.GLASS, true), Vector2i.ZERO])
	var front := FpArt.composite("shelf:%s:%s:%d" % [sh.furniture_id, sh.product_id, sh.stock], Vector2i(32, h), layers)
	var box := _box_from(tex, sh.position, sh.rotation_step, front, Interactable.view_of(tex, 2)[0])
	if sh.is_labeled():
		var label := _billboard()
		label.texture = Game.icon(sh.product_id)
		label.position = Vector3(0, h / PX_UP + 0.22, 0)
		label.scale = Vector3.ONE * 0.8
		box.add_child(label)
	return box


## A storage rack with its boxes on it.
func _rack(r: StorageRack) -> Node3D:
	var tex: Texture2D = Game.FURNITURE[r.furniture_id].texture
	var h := FpArt.box_height(tex)
	var layers := [[FpArt.face(tex, true), Vector2i.ZERO]]
	var small: Texture2D = StorageRack.SMALL_BOX
	for i in mini(r.boxes.size(), StorageRack.CAPACITY):
		var at := Vector2i(2 + (i % 2) * 14, h - 4 - small.get_height() - (i / 2) * int(h / 3.0))
		layers.append([small, at])
		layers.append([Game.icon(r.boxes[i].product_id), at + Vector2i(6, 2)])
	var key := "rack:%s" % ",".join(r.boxes.map(func(b): return b.product_id))
	return _box_from(tex, r.position, r.rotation_step, FpArt.composite(key, Vector2i(32, h), layers))


## Blood on the floor.
func _sync_spills() -> void:
	for cell in _spills.keys():
		if not store.spills.has(cell) or not is_instance_valid(_spills[cell]):
			if is_instance_valid(_spills[cell]):
				_spills[cell].queue_free()
			_spills.erase(cell)
	for cell: Vector2i in store.spills:
		if _spills.has(cell):
			continue
		var sp: Spill = store.spills[cell]
		var mi := MeshInstance3D.new()
		mi.mesh = FpArt.floor_mesh()
		mi.material_override = FpArt.material(FpArt.square(Spill.TEXTURES[sp.variant]), true)
		mi.position = Vector3(cell.x, 0.01, cell.y)
		world.add_child(mi)
		_spills[cell] = mi


## The floor (every tile the normal view draws, the town's ground too),
## and a ceiling over the store and the other buildings, with its lights.
func _build_floor() -> void:
	_floor_version = store.floor_layer.version
	for c in _floor.get_children():
		c.queue_free()
	var by_tex := {}  # texture -> [[cell, tint]]
	for t: Array in store.floor_layer.tiles():
		var cell := Iso.world_to_cell(t[1] + Vector2(32, 16))
		if not by_tex.has(t[0]):
			by_tex[t[0]] = []
		by_tex[t[0]].append([cell, t[2]])
	for tex: Texture2D in by_tex:
		var list: Array = by_tex[tex]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = FpArt.floor_mesh()
		mm.instance_count = list.size()
		for i in list.size():
			var cell: Vector2i = list[i][0]
			mm.set_instance_transform(i, Transform3D(Basis(), Vector3(cell.x, 0, cell.y)))
			mm.set_instance_color(i, list[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = FpArt.material(FpArt.square(tex), true)
		_floor.add_child(mmi)
	# A ceiling over the store, Bone Mart and the little shops.
	var inside: Array = store.floor_cells.keys()
	if store.town:
		inside.append_array(store.town.rival_floor.keys())
		inside.append_array(store.town.shop_floor.keys())
	var ceiling_h := FpArt.box_height(load("res://assets/sprites/wall_rival_tall.png")) / PX_UP
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = FpArt.floor_mesh()
	mm.instance_count = inside.size()
	for i in inside.size():
		var cell: Vector2i = inside[i]
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(cell.x, ceiling_h, cell.y)))
	var ceiling := MultiMeshInstance3D.new()
	ceiling.multimesh = mm
	ceiling.material_override = FpArt.color_material(CEILING)
	_floor.add_child(ceiling)
	var lamps := MultiMesh.new()
	lamps.transform_format = MultiMesh.TRANSFORM_3D
	lamps.mesh = FpArt.floor_mesh()
	var spots: Array = []
	for n in store.get_children():
		if n is StoreLights:
			for l in (n as StoreLights).lights:
				spots.append(to_3d(l.position + Vector2(0, 8), ceiling_h - 0.01))
	lamps.instance_count = spots.size()
	for i in spots.size():
		lamps.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(0.7, 1, 0.25)), spots[i]))
	var lights := MultiMeshInstance3D.new()
	lights.multimesh = lamps
	lights.material_override = FpArt.color_material(CEILING_LIGHT)
	_floor.add_child(lights)
