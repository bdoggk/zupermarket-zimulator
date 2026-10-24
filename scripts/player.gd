class_name Player
extends CharacterBody2D
## The store worker.
##   PC:      WASD / arrows to move (hold Shift to sprint), E or Space to use
##            what's in front of you, Q to scan a shelf (once you own the
##            scanner), or click a spot to walk there. Mouse wheel zooms.
##   Android: tap a spot to walk there, tap an object to walk over and use it,
##            or press the big buttons in the corner. RUN toggles sprinting.
##
## Moving happens every frame (in _process, like everyone else in the
## store), so the player stays in step with the camera at any frame rate.
## The zoom always makes each art pixel a whole number of screen pixels, so
## the pixel art stays sharp while the view scrolls.

enum Action { USE, DROP, SCAN }

const WALK_SPEED := 3.2  # cells per second going left or right (up and down is as fast on screen)
const SPRINT_SPEED := 5.2  # holding Shift (or the RUN button)
const DROP_SECONDS := 0.25
const REACH_SECONDS := 0.3  # first person: your hands reaching out when you use something
const DEFAULT_ZOOM := 2.5  # before rounding to whole screen pixels
const MIN_ZOOM := 1.0
const MAX_ZOOM := 5.0

const MOP_TEXTURE := preload("res://assets/sprites/mop_held.png")

# The gang war (GangWar): you can hit Bone Mart's gangsters, and they hit back.
const MAX_HEALTH := 10.0
const REGEN_AFTER := 4.0  # seconds without being hit: then you get better...
const REGEN_PER_SECOND := 2.0  # ...this fast
const KNOCKED_OUT_SECONDS := 3.0
const GLOCK_RANGE := 8.0  # cells
const GLOCK_ROUNDS := 15
const RELOAD_SECONDS := 1.4
## Damage per hit and seconds between hits, for each weapon.
const WEAPONS := {"fists": {"damage": 1, "every": 0.4}, "nunchucks": {"damage": 2, "every": 0.5}, "glock": {"damage": 2, "every": 0.3}}
const HAND := Vector2(5, -17)  # where your hand is, from your feet (facing right)

var store: Store
var carry_product := ""
var carry_count := 0
var holding_mop := false  # zombie game: grabbed from the mop bucket
var mop_sprite: Sprite2D

var focused: Interactable = null  # what E would use right now
var scan_focus: Interactable = null  # what Q would scan right now
var path: Array[Vector2i] = []
var tap_target: Interactable = null  # object to use when we arrive
var run_toggle := false  # the RUN button on touch screens
var sprinting := false  # moving at SPRINT_SPEED right now
var _zoom_goal := DEFAULT_ZOOM  # the zoom you picked (before rounding to whole pixels)
const NO_FINGER := Vector2(INF, INF)
const TAP_SLOP := 28.0  # a finger that slides farther than this isn't tapping
var _finger_down := NO_FINGER  # where a finger came down on the store

# Timed action (the Project Zomboid style progress bar)
var action_target: Interactable = null
var action_kind := Action.USE
var action_time := 0.0
var action_duration := 0.0
var action_label := ""

var _walk_anim := 0.0
var facing := Vector2.ZERO  # the way you last walked (E prefers what's in front of you)
var look_dir := Vector2.ZERO  # first person: where you're looking (you face that way, whichever way you walk)
var _stuck_time := 0.0
var _last_prompt := ["-", false, "-"]

var health := MAX_HEALTH
var knocked_out := 0.0  # seconds before you're back on your feet
var rounds := GLOCK_ROUNDS  # left in the Glock
var reloading := 0.0
var _attack_cd := 0.0
var _since_hurt := 99.0
var _hurt_flash := 0.0
var _swing := 0.0  # a punch or the nunchucks whirling (counts down)
var _shot_t := 0.0  # the muzzle flash (counts down)
var _shot_to := Vector2.ZERO  # where the last shot went (from you)
var fight_t := 0.0  # seconds left showing what's in your hand after a fight
var reach_t := 0.0  # you just used or grabbed something (counts down): first person's hands reach out

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
	set_zoom(DEFAULT_ZOOM)
	get_viewport().size_changed.connect(_apply_zoom)


func _process(delta: float) -> void:
	_tick_fighting(delta)
	if knocked_out > 0.0:
		velocity = Vector2.ZERO
		path.clear()
		queue_redraw()
		return
	var typing := is_typing() or Game.menu_open  # (the keys are working the menu)
	var fp := first_person()
	var input := Vector2.ZERO if typing else (fp.move_input() if fp else Input.get_vector("move_left", "move_right", "move_up", "move_down"))
	if is_busy() and input != Vector2.ZERO:
		cancel_action()

	sprinting = (run_toggle or (Input.is_action_pressed("sprint") and not typing)) and not is_busy() \
		and (input != Vector2.ZERO or not path.is_empty())
	var speed := (SPRINT_SPEED if sprinting else WALK_SPEED) * (Game.SWIFT_SPEED if Game.has_effect("swift") else 1.0)
	if is_busy():
		velocity = Vector2.ZERO
		_tick_action(delta)
	elif input != Vector2.ZERO:
		path.clear()
		tap_target = null
		if fp:
			velocity = fp.walk_velocity(input, speed)  # the way you're looking
		else:
			velocity = Iso.even_velocity(input, speed) * minf(input.length(), 1.0)  # as fast up/down as left/right
	elif not path.is_empty():
		_follow_path(delta, speed)
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	if velocity.length() > 5.0:
		facing = velocity.normalized()
	if fp and look_dir != Vector2.ZERO:
		facing = look_dir
	_animate(delta)
	_update_focus()
	queue_redraw()


## The first person view, while you're in it (null otherwise).
func first_person() -> FirstPerson:
	var fp: FirstPerson = Game.fp
	return fp if fp != null and is_instance_valid(fp) and fp.active else null


## Typing in a text box (a price on the computer): WASD and Shift are
## letters, not walking.
func is_typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


func _unhandled_input(event: InputEvent) -> void:
	if first_person() and (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventScreenDrag):
		return  # first person does clicks and taps itself
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device == InputEvent.DEVICE_ID_EMULATION:
		# A finger: walk there (or use what's there) once it lifts, unless it
		# slid (just looking) or a second finger joined it (zooming).
		if event.pressed:
			_finger_down = event.position
		elif _finger_down != NO_FINGER:
			if not PinchZoom.pinching and event.position.distance_to(_finger_down) < TAP_SLOP:
				_on_tap(get_canvas_transform().affine_inverse() * _finger_down)
			_finger_down = NO_FINGER
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_on_tap(get_canvas_transform().affine_inverse() * event.position)
			MOUSE_BUTTON_WHEEL_UP:
				if not _over_menu():
					zoom_by(1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if not _over_menu():
					zoom_by(1.0 / 1.1)
	elif Game.menu_open:
		return  # E / Q don't reach the store under the computer (or a shop)
	elif event.is_action_pressed("interact"):
		try_interact()
	elif event.is_action_pressed("scan"):
		try_scan()


## The mouse is over a menu or panel (the wheel scrolls that, not the view).
func _over_menu() -> bool:
	return get_viewport().gui_get_hovered_control() != null


func _draw() -> void:
	_draw_weapon()
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
	if is_busy() or knocked_out > 0.0:
		return
	if is_instance_valid(focused) and focused.can_interact(self):
		use(focused)
	elif can_drop():
		_start_action(null, DROP_SECONDS, Action.DROP)


## Scans the nearest shelf with the handheld scanner (Q / the SCAN button).
func try_scan() -> void:
	if is_busy() or knocked_out > 0.0:
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
	reach_t = REACH_SECONDS
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
	action_time += delta * (Game.QUICKHAND_SPEED if Game.has_effect("quickhand") else 1.0)
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


## Zooms in (factor > 1) or out one step: to the next whole number of
## screen pixels per art pixel, so the art stays crisp.
func zoom_by(factor: float) -> void:
	var s := _screen_scale()
	if s < 0.5:  # a tiny (or no) window: no rounding
		set_zoom(camera.zoom.x * factor)
		return
	var px := camera.zoom.x * s  # screen pixels per art pixel now
	var target := floorf(px + 0.01) + 1.0 if factor > 1.0 else ceilf(px - 0.01) - 1.0
	set_zoom(target / s)


## Sets the zoom, rounded so each art pixel is a whole number of screen
## pixels (as close to `z` as that allows).
func set_zoom(z: float) -> void:
	_zoom_goal = clampf(z, MIN_ZOOM, MAX_ZOOM)
	_apply_zoom()


## Rounds the zoom you picked for the window's size (again when the window
## is resized).
func _apply_zoom() -> void:
	var s := _screen_scale()
	var z := _zoom_goal
	if s >= 0.5:
		var lo := ceilf(MIN_ZOOM * s - 0.01)
		var hi := maxf(lo, floorf(MAX_ZOOM * s + 0.01))
		z = clampf(roundf(z * s), lo, hi) / s
	camera.zoom = Vector2.ONE * z


## How much the window is scaled up from the 1280x720 the game is laid out
## for (1.5 in a 1920x1080 window).
func _screen_scale() -> float:
	if not is_inside_tree():
		return 1.0
	var sc := get_viewport().get_final_transform().x.x
	return sc if sc > 0.01 else 1.0


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
	if obj is Gangster and obj.can_interact(self):  # close enough to hit (or in the Glock's range)
		path.clear()
		tap_target = null
		use(obj)
		return
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


func _follow_path(delta: float, speed := WALK_SPEED) -> void:
	var to_target := Iso.cell_to_world(path[0]) - position
	if to_target.length() < 2.0:
		path.remove_at(0)
		if path.is_empty():
			velocity = Vector2.ZERO
			_arrived()
			return
		to_target = Iso.cell_to_world(path[0]) - position
	var v := Iso.even_velocity(to_target, speed)
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
		_walk_anim += delta * (20.0 if sprinting else 14.0)
		sprite.position.y = -roundf(absf(sin(_walk_anim)) * 2.0)
		if absf(velocity.x) > 1.0:
			sprite.flip_h = velocity.x < 0.0
	else:
		sprite.position.y = 0.0
	sprite.position.x = (-2.0 if sprite.flip_h else 2.0) if _swing > 0.1 and Game.war.weapon() == "fists" else 0.0  # (a punch)
	carry_sprite.position.y = -14.0 + sprite.position.y
	mop_sprite.position = Vector2(-6.0 if sprite.flip_h else 6.0, -16.0 + sprite.position.y)
	mop_sprite.flip_h = sprite.flip_h


# ---------------------------------------------------------------- focus + prompt

func _update_focus() -> void:
	var fp_now := first_person()
	var best: Interactable = null
	var info: Interactable = null
	var scannable: Interactable = null
	var best_d := INF
	var best_pr := -1
	var info_d := INF
	var scan_d := INF
	var near := store.interactables_near(current_cell())
	var turf := _turf()
	if turf and Game.war.weapon() == "glock":  # anyone in range, not just next to you
		for g in turf.enemies_within(current_cell(), GLOCK_RANGE):
			near.append(g)
	for obj in near:
		var d := position.distance_to(obj.position)
		if obj is Gangster and Game.war.weapon() == "glock":
			d *= 0.25  # (anyone in the Glock's range is close enough)
		if obj.can_interact(self):
			var pr := obj.use_priority(self)
			# Same priority: what's in front of you counts as up to 40% closer.
			var ahead := maxf(0.0, facing.dot((obj.position - position).normalized())) if d > 0.5 else 1.0
			var score := d * (1.0 - 0.4 * ahead)
			if fp_now:  # first person: what you're looking at, never what's behind you
				var look := fp_now.ahead(obj.position - position) if d > 0.5 else 1.0
				if look < -0.2:
					continue
				score = d * (2.0 - 1.6 * maxf(0.0, look))
			if pr > best_pr or (pr == best_pr and score < best_d):
				best_pr = pr
				best_d = score
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


# ---------------------------------------------------------------- fighting (the gang war)

func _turf() -> Turf:
	return store.town.turf if store and store.town else null


## You can hit (or shoot) gangster `g` from where you are.
func can_hit(g: Gangster) -> bool:
	if knocked_out > 0.0 or Game.cutscene:
		return false
	if Game.war.weapon() == "glock":
		return Vector2(g.current_cell() - current_cell()).length() <= GLOCK_RANGE
	return Iso.chebyshev(g.current_cell(), current_cell()) <= 1


## Bone Mart's gangsters can hit you (not while you're down, or in a cutscene).
func can_be_hit() -> bool:
	return knocked_out <= 0.0 and not Game.cutscene


## Hits (or shoots) gangster `g` with whatever you've got (GangWar.weapon).
func attack(g: Gangster) -> void:
	if not can_hit(g) or _attack_cd > 0.0:
		return
	var w := Game.war.weapon()
	var turf := _turf()
	if w == "glock":
		if reloading > 0.0:
			return
		if rounds <= 0:
			_reload()
			return
		rounds -= 1
		_shot_t = 0.07
		_shot_to = g.position + Vector2(0, -20) - position
		if turf:
			turf.play("shot", position)
	else:
		_swing = 0.2
		if turf:
			turf.play("nunchucks" if w == "nunchucks" else "punch", g.position)
	_attack_cd = float(WEAPONS[w].every)
	fight_t = 6.0
	sprite.flip_h = g.position.x < position.x
	facing = (g.position - position).normalized()
	cancel_action()
	Settings.vibrate(0.35 if w == "glock" else 0.25, 0.06)
	g.hurt(int(WEAPONS[w].damage), self)
	if w == "glock" and rounds <= 0:
		_reload()


func _reload() -> void:
	if reloading > 0.0:
		return
	reloading = RELOAD_SECONDS
	var turf := _turf()
	if turf:
		turf.play("reload", position)


## A gangster hit you. At no health you're knocked out for a few seconds
## (and if Bone Mart's gang is in your store, they help themselves to the till).
func hurt(amount: int, from: Node2D) -> void:
	if not can_be_hit():
		return
	health = maxf(0.0, health - amount)
	_since_hurt = 0.0
	_hurt_flash = 0.2
	fight_t = 6.0
	cancel_action()
	Settings.vibrate(0.5, 0.12)
	Game.show_popup(position + Vector2(0, -48), "-%d" % amount, Color(1.0, 0.3, 0.3))
	if from:
		var pushed := position + (position - from.position).normalized() * 3.0  # (knocked back a little)
		if store.is_walkable(Iso.world_to_cell(pushed)):
			position = pushed
	if health <= 0.0:
		knocked_out = KNOCKED_OUT_SECONDS
		path.clear()
		tap_target = null
		Settings.vibrate(1.0, 0.5)
		var turf := _turf()
		if turf:
			turf.player_knocked_out()
		else:
			Game.message.emit(Brand.WAR.knocked_out)


func _tick_fighting(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_swing = maxf(0.0, _swing - delta)
	_shot_t = maxf(0.0, _shot_t - delta)
	reach_t = maxf(0.0, reach_t - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta)
	fight_t = maxf(0.0, fight_t - delta)
	_since_hurt += delta
	if reloading > 0.0:
		reloading -= delta
		if reloading <= 0.0:
			reloading = 0.0
			rounds = GLOCK_ROUNDS
	if knocked_out > 0.0:
		knocked_out -= delta
		sprite.rotation = lerpf(sprite.rotation, -PI / 2.0 if sprite.flip_h else PI / 2.0, minf(1.0, delta * 12.0))
		if knocked_out <= 0.0:
			knocked_out = 0.0
			health = MAX_HEALTH
			sprite.rotation = 0.0
	elif health < MAX_HEALTH and _since_hurt > REGEN_AFTER:
		health = minf(MAX_HEALTH, health + REGEN_PER_SECOND * delta)
	sprite.modulate = Color(1.6, 0.5, 0.5) if _hurt_flash > 0.0 else Color.WHITE
	var turf := _turf()
	if turf and turf.fighting() and not turf.enemies_within(current_cell(), 10.0).is_empty():
		fight_t = maxf(fight_t, 1.0)


## What's in your hand in a fight: "nunchucks", "glock" or "" (fists, or no fight).
func weapon_shown() -> String:
	if fight_t <= 0.0 or knocked_out > 0.0 or is_carrying() or holding_mop:
		return ""
	var w := Game.war.weapon()
	return "" if w == "fists" else w


func _draw_weapon() -> void:
	var w := weapon_shown()
	if w == "":
		return
	var flip := -1.0 if sprite.flip_h else 1.0
	var hand := Vector2(HAND.x * flip, HAND.y + sprite.position.y)
	if w == "nunchucks":
		# Hanging from your hand; a hit whirls them right round.
		var angle := PI - 0.4 if _swing <= 0.0 else PI - 0.4 + TAU * (1.0 - _swing / 0.2)
		draw_set_transform(hand, angle * flip, Vector2(flip, 1))
		draw_texture(Brand.WAR.textures.nunchucks, Vector2(-2, -17))
	else:
		draw_set_transform(hand + Vector2(0, 2), 0.0, Vector2(flip, 1))
		draw_texture(Brand.WAR.textures.glock, Vector2(-1, -4))
		if _shot_t > 0.0:
			draw_texture(Brand.WAR.textures.flash, Vector2(7, -8))
	draw_set_transform(Vector2.ZERO)
	if w == "glock" and _shot_t > 0.0:
		draw_line(hand + Vector2(9 * flip, 0), _shot_to, Color(1.0, 0.9, 0.5, 0.8), 1.0)
