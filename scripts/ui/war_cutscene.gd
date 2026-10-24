class_name WarCutscene
extends CanvasLayer
## The gang war starts (Brand.WAR, GangWar): your store just reached level
## 15. A drum hit, and Mr. Bones walks in with two of his thugs. Bone Mart
## isn't for sale (and if you bought it before, he's bought it back); every
## lot he gets east of his store is another Bone Mart, and his boys will be
## paying you visits. A thug smashes a shelf to make the point. Then Big
## Rotto and his zombie crew show up: put them on the payroll, and get
## yourself some nunchucks... or a Glock. A card sums up how the war works.
##
## Any key, A, a click or a tap moves the talking along; Esc, B or Skip
## jumps to the card. The HUD starts it (Game.war.pending).

signal finished  # the card's button was pressed: the war is on

const LINE_SECONDS := 3.6  # a line stays up this long if you don't press anything
const LETTERS_PER_SECOND := 42.0
const BAR_HEIGHT := 0.11
const ZOOM_IN := 1.5
const WALK_LIMIT := 9.0  # seconds: anyone still walking after this is just there
const STING := preload("res://assets/sounds/war_sting.wav")
const SMASH := preload("res://assets/sounds/war_smash.wav")

var hud: Node
var store: Store
var player: Player
var root: Control
var bars: Array[ColorRect] = []
var flash: ColorRect
var box: PanelContainer
var speaker_pic: TextureRect
var speaker_name: Label
var line_label: Label
var hint: Label
var skip_button: Button
var big_text: Label  # GANG WAR
var card: VBoxContainer
var go_button: Button
var step := ""  # what's happening (tests watch this)
var actors: Array[Wanderer] = []
var cam := Vector2.ZERO
var _zoom := 1.0
var _advance := false
var _skipped := false
var _shake := 0.0
var _was_first_person := false


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.make_theme(Game.touch_ui)
	add_child(root)
	UI.fit_layer(self, root)
	flash = _rect(Color(1.0, 0.95, 0.8, 0.0))
	for top in [true, false]:
		var bar := _rect(Color.BLACK)
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.offset_top = 0.0
		bar.offset_bottom = 0.0
		bars.append(bar)
	big_text = UI.label("", Color(0.92, 0.12, 0.12))
	big_text.add_theme_font_size_override("font_size", 92)
	big_text.add_theme_constant_override("outline_size", 14)
	big_text.add_theme_color_override("font_outline_color", Color.BLACK)
	big_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big_text.set_anchors_preset(Control.PRESET_TOP_WIDE)
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
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_theme_constant_override("separation", 14)
	card.visible = false
	root.add_child(card)
	var panel_bg := ColorRect.new()  # (a dark backdrop behind the card)
	panel_bg.color = Color(0, 0, 0, 0.72)
	panel_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_bg.visible = false
	panel_bg.name = "Backdrop"
	root.add_child(panel_bg)
	root.move_child(panel_bg, card.get_index())
	var title := UI.label("GANG WAR", Color(0.92, 0.12, 0.12))
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(title)
	var sub := UI.label("%s's skeletons against your zombies" % Brand.RIVAL.name, UI.WARN)
	sub.add_theme_font_size_override("font_size", 26)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(sub)
	for text: String in Brand.WAR.cut_card:
		var l := UI.label("-  " + text)
		l.add_theme_font_size_override("font_size", 22)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 760
		card.add_child(l)
	go_button = UI.menu_button("Let's go", _finish, Vector2(300, 64))
	go_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.add_child(go_button)


func _process(delta: float) -> void:
	UI.fit_layer(self, root)
	var s: Vector2 = root.size
	box.reset_size()
	box.custom_minimum_size.x = minf(900.0, s.x - 40.0)
	box.position = Vector2((s.x - box.size.x) / 2.0, s.y - box.size.y - s.y * BAR_HEIGHT * 0.35 - 12.0).round()
	for l: Control in card.get_children():
		if l is Label and (l as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
			l.custom_minimum_size.x = minf(760.0, s.x - 60.0)
	card.reset_size()
	card.position = ((s - card.size) / 2.0).round()
	if is_instance_valid(player) and player.camera:
		_shake = maxf(0.0, _shake - delta)
		player.camera.offset = cam + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 5.0 * _shake


## Starts it: hides the HUD and plays the whole thing.
func play(h: Node) -> void:
	hud = h
	store = Game.store
	player = Game.player
	Game.cutscene = true
	if Game.build_mode and Game.build_mode.active:
		Game.build_mode.exit()
	var fp: FirstPerson = Game.fp
	_was_first_person = fp != null and is_instance_valid(fp) and fp.active
	if _was_first_person:
		fp.force_off()  # (it plays in the view from above)
	if is_instance_valid(player):
		player.cancel_action()
		player.path.clear()
		player.velocity = Vector2.ZERO
		cam = player.camera.offset
		_zoom = player.camera.zoom.x
	await _run()


func _run() -> void:
	var war: Dictionary = Brand.WAR
	var boss_pic: Texture2D = Brand.RIVAL.textures.owner
	var thugs: Array = war.textures.bone_gang
	step = "dark"
	_tween_bars(true)
	_play(STING)
	_shake = 0.5
	await _wait(0.9)
	if _skipped:
		return
	step = "bones"
	var from := _entrance()
	var stand := _stand_near(from, 0)
	var boss := _actor(boss_pic, from, stand, 1.8)
	await _wait(0.35)
	var thug1 := _actor(thugs[0], from, _stand_near(from, 1), 1.8)
	await _wait(0.35)
	var thug2 := _actor(thugs[1], from, _stand_near(from, 2), 1.8)
	await _walk_in([boss, thug1, thug2])
	if _skipped:
		return
	await _close_in(boss)
	if _skipped:
		return
	step = "talk"
	await _say(Brand.RIVAL.owner, boss_pic, war.cut_arrive)
	if _skipped:
		return
	await _say(Brand.RIVAL.owner, boss_pic, war.cut_bought_back if Game.war.bought_back else war.cut_not_for_sale)
	if _skipped:
		return
	await _say(Brand.RIVAL.owner, boss_pic, war.cut_land)
	if _skipped:
		return
	await _say(str(war.bone_names[0]), thugs[0], war.cut_thug)
	if _skipped:
		return
	step = "smash"
	box.visible = false
	await _smash(thug1)
	if _skipped:
		return
	await _say(Brand.RIVAL.owner, boss_pic, war.cut_war)
	if _skipped:
		return
	box.visible = false
	for a in [boss, thug1, thug2]:
		_leave(a)
	await _wait(1.6)
	if _skipped:
		return
	step = "rotto"
	var rotto_pic: Texture2D = war.textures.zombie_boss
	var crew: Array = war.textures.zombie_gang
	from = _entrance()
	var rotto := _actor(rotto_pic, from, _stand_near(from, 0), 1.9)
	await _wait(0.35)
	var z1 := _actor(crew[0], from, _stand_near(from, 1), 1.9)
	await _wait(0.35)
	var z2 := _actor(crew[1], from, _stand_near(from, 2), 1.9)
	await _walk_in([rotto, z1, z2])
	if _skipped:
		return
	await _say(war.zombie_boss, rotto_pic, war.cut_rotto_1)
	if _skipped:
		return
	await _say(war.zombie_boss, rotto_pic, war.cut_rotto_2)
	if _skipped:
		return
	await _say(war.zombie_boss, rotto_pic, war.cut_rotto_3)
	if _skipped:
		return
	await _say("You", player.sprite.texture, war.cut_you)
	if _skipped:
		return
	box.visible = false
	for a in [rotto, z1, z2]:
		_leave(a)
	await _wait(0.6)
	if _skipped:
		return
	_show_card()


## Esc / B / Skip: straight to the card.
func skip() -> void:
	if _skipped or card.visible:
		return
	_skipped = true
	_show_card()


func _show_card() -> void:
	step = "card"
	box.visible = false
	skip_button.visible = false
	big_text.visible = false
	for a in actors:
		if is_instance_valid(a):
			a.queue_free()
	actors.clear()
	var bg: ColorRect = root.get_node("Backdrop")
	bg.visible = true
	bg.modulate.a = 0.0
	create_tween().tween_property(bg, "modulate:a", 1.0, 0.4)
	card.visible = true
	card.modulate.a = 0.0
	create_tween().tween_property(card, "modulate:a", 1.0, 0.5)
	if UI.wants_focus() or not Game.touch_ui:
		go_button.grab_focus.call_deferred()


func _finish() -> void:
	if step == "done":
		return
	step = "done"
	if is_instance_valid(player):
		player.camera.offset = Vector2.ZERO
		player.set_zoom(_zoom)
	Game.cutscene = false
	if _was_first_person and is_instance_valid(Game.fp):
		(Game.fp as FirstPerson).set_active(true)
	Game.war.begin()
	finished.emit()
	queue_free()


# ---------------------------------------------------------------- pieces

## Where they come from: your store's door if you're inside, otherwise
## somewhere down the street from you.
func _entrance() -> Vector2i:
	var here := player.current_cell()
	if store.floor_cells.has(here) or store.town == null:
		return store.door_cell
	for r in [6, 5, 7, 4, 8, 3]:
		for d: Vector2i in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r)]:
			var c := here + d
			if store.is_walkable(c) and store.reachable.has(c) and not store.floor_cells.has(c):
				return c
	return store.door_cell


## The k-th spot near you (on your side of any wall), the ones toward
## where they come from first; each of them gets a different one.
func _stand_near(from: Vector2i, k: int) -> Vector2i:
	var here := player.current_cell()
	var dir := Vector2(from - here).normalized()
	var spots: Array[Vector2i] = []
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var c := here + Vector2i(dx, dy)
			if c == here or not store.is_walkable(c) or not store.reachable.has(c):
				continue
			var way := store.find_path(here, c)
			if way.is_empty() or way.size() > 4:
				continue  # (on the other side of a wall or a shelf)
			spots.append(c)
	spots.sort_custom(func(a: Vector2i, b: Vector2i):
		var sa := Vector2(a - here).length() - 0.6 * Vector2(a - here).normalized().dot(dir)
		var sb := Vector2(b - here).length() - 0.6 * Vector2(b - here).normalized().dot(dir)
		return sa < sb)
	if spots.is_empty():
		return store.stand_cell_for(here, from)
	return spots[mini(k, spots.size() - 1)]


func _actor(tex: Texture2D, from: Vector2i, to: Vector2i, speed: float) -> Wanderer:
	var w := Wanderer.new()
	w.setup(store, tex, from, [[to, 0.0]], speed)
	w.stay = true
	store.world.add_child(w)
	actors.append(w)
	return w


## Waits for them to get where they're going (or WALK_LIMIT, then puts them there).
func _walk_in(list: Array) -> void:
	var follow := _follow(list)
	var left := WALK_LIMIT
	while left > 0.0 and not _skipped:
		if list.all(func(a): return not is_instance_valid(a) or (a.path.is_empty() and a.stops.is_empty())):
			break
		await get_tree().process_frame
		left -= get_process_delta_time()
	follow.kill()
	for a: Wanderer in list:
		if is_instance_valid(a):
			a.face(player.position)
	if is_instance_valid(list[0]):
		player.sprite.flip_h = list[0].position.x < player.position.x


func _follow(list: Array) -> Tween:
	var t := create_tween().set_loops()
	t.tween_callback(func():
		if is_instance_valid(list[0]) and is_instance_valid(player):
			var want: Vector2 = (list[0].position + player.position) / 2.0 - player.position + Vector2(0, -16)
			cam = cam.lerp(want, 0.08)
	)
	t.tween_interval(1.0 / 60.0)
	return t


func _close_in(who: Wanderer) -> void:
	var close := create_tween().set_parallel()
	close.tween_property(self, "cam", (who.position - player.position) / 2.0 + Vector2(0, 10), 0.7).set_trans(Tween.TRANS_SINE)
	close.tween_property(player.camera, "zoom", Vector2.ONE * _zoom * ZOOM_IN, 0.7).set_trans(Tween.TRANS_SINE)
	await close.finished
	player.set_zoom(player.camera.zoom.x)


## The thug makes his point on the nearest shelf (just a scare: nothing breaks).
func _smash(thug: Wanderer) -> void:
	var target_pos := thug.position + Vector2(0, -30)
	var near: Shelf = null
	for s: Shelf in store.shelves:
		if near == null or s.position.distance_to(thug.position) < near.position.distance_to(thug.position):
			near = s
	if near and near.position.distance_to(thug.position) < 220.0:
		target_pos = near.position + Vector2(0, -50)
		thug.face(near.position)
	var lunge := create_tween()
	var from := thug.position
	lunge.tween_property(thug, "position", from.lerp(target_pos + Vector2(0, 30), 0.35), 0.15).set_trans(Tween.TRANS_BACK)
	lunge.tween_property(thug, "position", from, 0.25)
	await _wait(0.15)
	_play(SMASH)
	_shake = 0.6
	Settings.vibrate(0.8, 0.3)
	Game.show_popup(target_pos, "CRASH!", Color(1.0, 0.55, 0.4))
	var f := create_tween()
	f.tween_property(flash, "color:a", 0.45, 0.05)
	f.tween_property(flash, "color:a", 0.0, 0.35)
	await _wait(1.0)


func _leave(a: Wanderer) -> void:
	if not is_instance_valid(a):
		return
	a.stay = false
	a.stops = [[store.exit_cell_near(a.current_cell()), 0.0]]


func _tween_bars(on: bool) -> void:
	var h := root.size.y * BAR_HEIGHT if on else 0.0
	var t := create_tween().set_parallel()
	t.tween_property(bars[0], "offset_bottom", h, 0.5)
	t.tween_property(bars[1], "offset_top", -h, 0.5)


## Someone says something: the letters type out, then it waits for a key
## (or LINE_SECONDS).
func _say(who: String, pic: Texture2D, text: String) -> void:
	box.visible = true
	speaker_name.text = who.to_upper()
	var ours := who == "You" or who == Brand.WAR.zombie_boss
	UI.set_color(speaker_name, UI.GOOD if ours else UI.BAD)
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
		if _advance:
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


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not _skipped:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _play(stream: AudioStream) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


## Every press is the cutscene's: nothing reaches the store or the HUD.
func _input(event: InputEvent) -> void:
	if card.visible:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
		return
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


func _to_root(screen_pos: Vector2) -> Vector2:
	return (get_final_transform().affine_inverse() * screen_pos)
