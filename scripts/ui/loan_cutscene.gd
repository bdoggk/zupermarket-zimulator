class_name LoanCutscene
extends CanvasLayer
## Count Vlad comes to collect (Brand.LOAN). It's the last night of your
## loan and you can't pay it all: the lights stutter and go red, he swoops
## in through the door in a cloud of bats, tells you what you owe, and rips
## your head off. He walks off with it, and the game starts over from day 1
## (Saves.start_over).
##
## Any key, A, a click or a tap moves the talking along; Esc, B or Skip
## jumps straight to the end. The HUD starts it (Game.loan_defaulted).

signal over  # the game over card is up
signal finished  # Start over was pressed

const LINE_SECONDS := 3.4  # a line stays up this long if you don't press anything
const LETTERS_PER_SECOND := 42.0
const BAR_HEIGHT := 0.11  # the black bars at the top and bottom, as part of the screen
const TINT := Color(1.0, 0.6, 0.58)  # the store goes this red
const ZOOM_IN := 1.7  # the view closes in this much while he talks
const HAND := Vector2(5, -12)  # where his hand is, from his feet (facing right)
const NECK := Vector2(0, -22)  # the player's neck, from their feet
const HEAD_ROWS := 12  # the player sprite's head: its top 12 rows
const BODY_ROWS := 20  # then the body (the rest is the shadow)
const BAT_TEXTURES: Array[Texture2D] = [preload("res://assets/sprites/bat_0.png"), preload("res://assets/sprites/bat_1.png")]
const SOUNDS := {
	"sting": preload("res://assets/sounds/vlad_sting.wav"),
	"bats": preload("res://assets/sounds/vlad_bats.wav"),
	"rip": preload("res://assets/sounds/vlad_rip.wav"),
	"thud": preload("res://assets/sounds/vlad_thud.wav"),
	"laugh": preload("res://assets/sounds/vlad_laugh.wav"),
}

var hud: Node
var store: Store
var player: Player
var count: Wanderer  # Count Vlad
var head: Sprite2D  # yours
var body: Sprite2D
var root: Control
var tint: ColorRect
var flash: ColorRect
var black: ColorRect
var bars: Array[ColorRect] = []
var box: PanelContainer  # who's talking, and what they say
var speaker_pic: TextureRect
var speaker_name: Label
var line_label: Label
var hint: Label
var skip_button: Button
var big_text: Label  # RIIIP!
var card: VBoxContainer  # GAME OVER
var restart_button: Button
var step := ""  # what's happening (tests watch this)
var auto_start_over := -1.0  # seconds before the card starts over by itself (-1: wait for you)
var _bats: Array[Sprite2D] = []
var _bat_t := 0.0
var _advance := false
var _skipped := false
var _shake := 0.0
var _lights: Array[PointLight2D] = []
var cam := Vector2.ZERO  # where the view is, from the player (the shake goes on top)


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()  # (sized to the screen by UI.fit_layer)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.make_theme(Game.touch_ui)
	add_child(root)
	UI.fit_layer(self, root)

	tint = _rect(Color.WHITE)  # multiplied over the store: white changes nothing
	var mul := CanvasItemMaterial.new()
	mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	tint.material = mul
	flash = _rect(Color(0.8, 0.0, 0.0, 0.0))
	for top in [true, false]:
		var bar := _rect(Color.BLACK)
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.offset_top = 0.0
		bar.offset_bottom = 0.0
		bars.append(bar)

	big_text = UI.label("", Color(0.9, 0.08, 0.1))
	big_text.add_theme_font_size_override("font_size", 96)
	big_text.add_theme_constant_override("outline_size", 14)
	big_text.add_theme_color_override("font_outline_color", Color.BLACK)
	big_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big_text.set_anchors_preset(Control.PRESET_TOP_WIDE)  # above the two of them
	big_text.anchor_bottom = 0.36
	big_text.visible = false
	root.add_child(big_text)

	_build_box()
	skip_button = UI.button("Skip", skip, Vector2(110, 48))
	skip_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_button.offset_left = -124
	skip_button.offset_top = 14
	skip_button.offset_right = -14
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.modulate.a = 0.75
	root.add_child(skip_button)

	black = _rect(Color(0, 0, 0, 0))
	_build_card()


func _rect(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)
	return r


func _build_box() -> void:
	box = PanelContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.visible = false
	root.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	speaker_pic = UI.icon(null, Vector2(64, 144))
	row.add_child(speaker_pic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	speaker_name = UI.label("", UI.BAD)
	speaker_name.add_theme_font_size_override("font_size", 24)
	col.add_child(speaker_name)
	line_label = UI.label("")
	line_label.add_theme_font_size_override("font_size", 26)
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line_label.custom_minimum_size = Vector2(640, 72)
	col.add_child(line_label)
	hint = UI.label("", UI.DIM)
	hint.add_theme_font_size_override("font_size", 15)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(hint)


func _build_card() -> void:
	card = VBoxContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 16)
	card.visible = false
	root.add_child(card)
	var title := UI.label("GAME OVER", Color(0.85, 0.06, 0.1))
	title.add_theme_font_size_override("font_size", 84)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(title)
	for text: String in [Brand.LOAN.game_over, Brand.LOAN.gone]:
		var l := UI.label(text)
		l.add_theme_font_size_override("font_size", 26)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(l)
	var again := UI.label("You start over from Day 1.", UI.WARN)
	again.add_theme_font_size_override("font_size", 26)
	again.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(again)
	restart_button = UI.menu_button("Start over", _start_over, Vector2(320, 64))
	restart_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_child(restart_button)


func _process(delta: float) -> void:
	UI.fit_layer(self, root)
	var s: Vector2 = root.size
	box.reset_size()
	box.custom_minimum_size.x = minf(900.0, s.x - 40.0)
	box.position = Vector2((s.x - box.size.x) / 2.0, s.y - box.size.y - s.y * BAR_HEIGHT * 0.35 - 12.0).round()
	card.reset_size()
	card.position = ((s - card.size) / 2.0).round()
	# Bats flap and flutter.
	_bat_t += delta
	for b in _bats:
		if is_instance_valid(b):
			b.texture = BAT_TEXTURES[int(_bat_t * 12.0 + b.get_instance_id() % 3) % 2]
	# The view, and the screen shaking.
	if is_instance_valid(player) and player.camera:
		_shake = maxf(0.0, _shake - delta)
		player.camera.offset = cam + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 6.0 * _shake
	if is_instance_valid(head) and head.get_parent() == count:
		head.rotation = sin(_bat_t * 3.0) * 0.25 + PI  # dangling by the hair


## Starts it: hides the HUD, then plays the whole visit.
func play(h: Node) -> void:
	hud = h
	store = Game.store
	player = Game.player
	Game.cutscene = true
	if Game.build_mode and Game.build_mode.active:
		Game.build_mode.exit()
	get_tree().paused = false
	if is_instance_valid(player):
		player.cancel_action()
		player.path.clear()
		player.velocity = Vector2.ZERO
		cam = player.camera.offset
	await _run()


func _run() -> void:
	var ln: Dictionary = Game.loan
	var lend: Dictionary = Brand.LOAN
	step = "dark"
	_tween_bars(true)
	await _lights_out()
	if _skipped:
		return
	step = "arrive"
	var door: Vector2i = store.door_cell
	await _pan_to(Iso.cell_to_world(door) - player.position + Vector2(0, -20), 0.9)
	if _skipped:
		return
	_play("bats")
	_bat_burst(Iso.cell_to_world(door) + Vector2(0, -18))
	count = Wanderer.new()
	var stand := store.stand_cell_for(player.current_cell(), door)
	if stand == Store.NO_CELL:
		stand = player.current_cell()
	count.setup(store, lend.sprite, door, [[stand, 0.0]], 1.8)
	count.stay = true
	count.name = "CountVlad"
	store.world.add_child(count)
	await _wait(0.6)
	if _skipped:
		return
	await _say(lend.lender, lend.sprite, lend.arrive % Game.day)
	if _skipped:
		return
	step = "walk"
	var follow := _follow_count()
	for i in 600:  # (10 seconds at most: then he's just there)
		if _skipped:
			return
		if count.path.is_empty() and count.stops.is_empty():
			break
		await get_tree().process_frame
	follow.kill()
	if count.current_cell() != stand:
		count.position = Iso.cell_to_world(stand)
		count.path.clear()
		count.stops.clear()
	count.face(player.position)
	player.sprite.flip_h = count.position.x < player.position.x
	var close := create_tween().set_parallel()  # in close on the two of you
	close.tween_property(self, "cam", (count.position - player.position) / 2.0 + Vector2(0, 10), 0.8).set_trans(Tween.TRANS_SINE)  # (above the talking)
	close.tween_property(player.camera, "zoom", player.camera.zoom * ZOOM_IN, 0.8).set_trans(Tween.TRANS_SINE)
	await close.finished
	player.set_zoom(player.camera.zoom.x)  # (whole screen pixels per art pixel again)
	if _skipped:
		return
	step = "talk"
	await _say(lend.lender, lend.sprite, lend.owed % [Game.cash(float(ln.get("amount", 0.0))), Game.cash(float(ln.get("total", 0.0)))])
	if _skipped:
		return
	await _say(lend.lender, lend.sprite, lend.short % Game.cash(Game.loan_left()))
	if _skipped:
		return
	await _say("You", player.sprite.texture, lend.excuse)
	if _skipped:
		return
	await _say(lend.lender, lend.sprite, lend.threat)
	if _skipped:
		return
	box.visible = false
	step = "rip"
	await _rip()
	if _skipped:
		return
	await _wait(1.2)
	if _skipped:
		return
	step = "gloat"
	await _say(lend.lender, lend.sprite, lend.gloat)
	if _skipped:
		return
	box.visible = false
	_play("laugh")
	count.stay = false
	count.stops = [[store.exit_cell_near(count.current_cell()), 0.0]]
	await _wait(2.2)
	if _skipped:
		return
	_game_over()


## Esc / B / Skip: straight to the end (the outcome's the same).
func skip() -> void:
	if _skipped or card.visible:
		return
	_skipped = true
	_game_over()


func _game_over() -> void:
	step = "over"
	box.visible = false
	skip_button.visible = false
	big_text.visible = false
	var t := create_tween()
	t.tween_property(black, "color:a", 1.0, 0.25 if _skipped else 1.4)
	await t.finished
	card.visible = true
	card.modulate.a = 0.0
	create_tween().tween_property(card, "modulate:a", 1.0, 0.6)
	if UI.wants_focus() or not Game.touch_ui:
		restart_button.grab_focus.call_deferred()
	over.emit()
	if auto_start_over >= 0.0:
		await _wait(auto_start_over, true)
		_start_over()


func _start_over() -> void:
	if step == "starting over":
		return
	step = "starting over"
	finished.emit()
	Saves.start_over()


# ---------------------------------------------------------------- pieces

## The lights stutter, then the store goes dark red. A pipe organ.
func _lights_out() -> void:
	for n in store.get_children():
		if n is StoreLights:
			_lights = (n as StoreLights).lights
	_play("sting")
	for i in 6:
		for l in _lights:
			if is_instance_valid(l):
				l.visible = i % 2 == 1
		await _wait(0.09)
		if _skipped:
			return
	for l in _lights:
		if is_instance_valid(l):
			l.visible = true
			l.energy *= 0.75
	var t := create_tween()
	t.tween_property(tint, "color", TINT, 0.8)
	await t.finished


func _tween_bars(on: bool) -> void:
	var h := root.size.y * BAR_HEIGHT if on else 0.0
	var t := create_tween().set_parallel()
	t.tween_property(bars[0], "offset_bottom", h, 0.5)
	t.tween_property(bars[1], "offset_top", -h, 0.5)


## Moves the view (the player's camera) to `offset` from the player.
func _pan_to(offset: Vector2, seconds: float) -> void:
	var t := create_tween()
	t.tween_property(self, "cam", offset, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished


## The view follows him across the store.
func _follow_count() -> Tween:
	var t := create_tween().set_loops()
	t.tween_callback(func():
		if is_instance_valid(count) and is_instance_valid(player):
			var want := (count.position + player.position) / 2.0 - player.position + Vector2(0, -16)
			cam = cam.lerp(want, 0.08)
	)
	t.tween_interval(1.0 / 60.0)
	return t


func _bat_burst(at: Vector2) -> void:
	for i in 12:
		var b := Sprite2D.new()
		b.texture = BAT_TEXTURES[0]
		b.position = at + Vector2(randf_range(-6, 6), randf_range(-6, 6))
		b.z_index = 100
		store.add_child(b)
		_bats.append(b)
		var dir := Vector2.from_angle(randf_range(-PI, 0.0)) * randf_range(70.0, 150.0)
		var t := create_tween().set_parallel()
		t.tween_property(b, "position", b.position + dir + Vector2(0, -30), randf_range(1.0, 1.6)).set_trans(Tween.TRANS_SINE)
		t.tween_property(b, "modulate:a", 0.0, 0.5).set_delay(1.0)
		t.chain().tween_callback(b.queue_free)


## Your head comes off: he grabs it, it tears loose in a spray of blood and
## ends up in his hand, and the rest of you falls over.
func _rip() -> void:
	var at := player.position
	var tex: Texture2D = player.sprite.texture
	var flip := player.sprite.flip_h
	var toward := signf(count.position.x - at.x) if absf(count.position.x - at.x) > 0.5 else 1.0
	# He lunges.
	var lunge := create_tween()
	var from := count.position
	lunge.tween_property(count, "position", from.lerp(at, 0.45), 0.18).set_trans(Tween.TRANS_BACK)
	await lunge.finished
	if _skipped:
		return
	_play("rip")
	Settings.vibrate(1.0, 0.6)
	_shake = 0.7
	# You come apart.
	player.visible = false
	body = _piece(tex, Rect2(0, HEAD_ROWS, 16, BODY_ROWS), Vector2(-8, -(34 - HEAD_ROWS)), flip)
	body.position = at
	store.world.add_child(body)
	var shadow := _piece(tex, Rect2(0, HEAD_ROWS + BODY_ROWS, 16, 36 - HEAD_ROWS - BODY_ROWS), Vector2(-8, -2), flip)
	body.add_child(shadow)
	shadow.show_behind_parent = true
	var stump := ColorRect.new()  # the neck
	stump.color = Color(0.55, 0.0, 0.05)
	stump.position = Vector2(-3, NECK.y)
	stump.size = Vector2(6, 2)
	body.add_child(stump)
	head = _piece(tex, Rect2(0, 0, 16, HEAD_ROWS), Vector2(-8, -HEAD_ROWS / 2.0), flip)
	head.position = at + NECK + Vector2(0, -HEAD_ROWS / 2.0)
	head.z_index = 50
	store.add_child(head)
	_blood(at + NECK)
	for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		store.add_spill(player.current_cell() + d, -1, false)
	big_text.text = "RIIIIP!"
	big_text.visible = true
	big_text.pivot_offset = big_text.size / 2.0
	big_text.scale = Vector2(0.3, 0.3)
	var pop := create_tween().set_parallel()
	pop.tween_property(big_text, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(flash, "color:a", 0.55, 0.06)
	pop.chain().tween_property(flash, "color:a", 0.0, 0.5)
	pop.tween_property(big_text, "modulate:a", 0.0, 0.4).set_delay(0.7)
	# The head flies up in an arc and lands in his hand.
	count.position = from
	var hand := count.position + Vector2(HAND.x * (1.0 if not count.sprite.flip_h else -1.0), HAND.y)
	var start := head.position
	var top := (start + hand) / 2.0 + Vector2(0, -60)
	var arc := create_tween().set_parallel()
	arc.tween_method(func(f: float):
		if is_instance_valid(head):
			head.position = start.lerp(top, f).lerp(top.lerp(hand, f), f)
	, 0.0, 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	arc.tween_property(head, "rotation", TAU * 2.0 * -toward + PI, 0.9)
	await arc.finished
	if _skipped:
		return
	big_text.visible = false
	head.reparent(count)  # he's holding it now
	head.position = Vector2(HAND.x * (1.0 if not count.sprite.flip_h else -1.0), HAND.y + 4)
	head.z_index = 1
	# And the rest of you falls over.
	await _wait(0.4)
	if _skipped:
		return
	var fall := create_tween()
	fall.tween_property(body, "rotation", PI / 2.0 * -toward, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fall.finished
	_play("thud")
	_shake = 0.3
	Settings.vibrate(0.6, 0.2)


func _piece(tex: Texture2D, region: Rect2, offset: Vector2, flip: bool) -> Sprite2D:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = region
	var s := Sprite2D.new()
	s.texture = a
	s.centered = false
	s.offset = offset
	s.flip_h = flip
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return s


func _blood(at: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = at
	p.z_index = 40
	p.amount = 70
	p.lifetime = 1.1
	p.one_shot = true
	p.explosiveness = 0.55
	p.direction = Vector2(0, -1)
	p.spread = 40.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 150.0
	p.gravity = Vector2(0, 320)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	p.color = Color(0.7, 0.02, 0.06)
	store.add_child(p)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


## Someone says something: the letters type out, then it waits for a key
## (or LINE_SECONDS).
func _say(who: String, pic: Texture2D, text: String) -> void:
	box.visible = true
	speaker_name.text = who.to_upper()
	UI.set_color(speaker_name, UI.BAD if who == Brand.LOAN.lender else UI.GOOD)
	speaker_pic.texture = pic
	line_label.text = text
	line_label.visible_ratio = 0.0
	hint.text = "%s: next     %s: skip" % ["A" if UI.has_pad() else ("Tap" if Game.touch_ui else "Space"), "B" if UI.has_pad() else "Esc"]
	_advance = false
	var typing := create_tween()
	typing.tween_property(line_label, "visible_ratio", 1.0, text.length() / LETTERS_PER_SECOND)
	while typing.is_running():
		if _skipped:
			typing.kill()
			return
		if _advance:  # a press finishes the line at once
			_advance = false
			typing.kill()
			line_label.visible_ratio = 1.0
			break
		await get_tree().process_frame
	var left := LINE_SECONDS
	while left > 0.0 and not _advance and not _skipped:
		await get_tree().process_frame
		left -= get_process_delta_time()
	_advance = false


func _wait(seconds: float, always := false) -> void:
	var left := seconds
	while left > 0.0 and (always or not _skipped):
		await get_tree().process_frame
		left -= get_process_delta_time()


func _play(sound: String) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = SOUNDS[sound]
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## Every press is the cutscene's: nothing reaches the store or the HUD.
func _input(event: InputEvent) -> void:
	if card.visible:
		# The game over card: only its button (and nothing behind it).
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
		return
	# A click (or tap) on Skip is the button's.
	if event is InputEventMouseButton and skip_button.visible and skip_button.get_global_rect().has_point(_to_root(event.position)):
		return
	var pressed := (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton or event is InputEventScreenTouch) \
		and event.is_pressed() and not event.is_echo()
	if event is InputEventMouseMotion or event is InputEventScreenDrag or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
		return
	if not pressed:
		if event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton or event is InputEventScreenTouch:
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") \
			or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B):
		skip()
	else:
		_advance = true


## A screen position in the cutscene's own (UI size) coordinates.
func _to_root(screen_pos: Vector2) -> Vector2:
	return (get_final_transform().affine_inverse() * screen_pos)
