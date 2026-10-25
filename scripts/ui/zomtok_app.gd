class_name ZomTokApp
extends Control
## ZomTok, on the store computer: short videos of the town's characters
## dancing (ZomTokFeed makes them), one at a time on a phone-shaped screen,
## with the beat playing. Like a video (the heart, a double tap, Space or
## A), read its comments and post your own, share it, follow whoever posted
## it. Swipe up (or the wheel, Down, the d-pad) for the next one.
##
##   Keys:        Up / Down next video, Space or L like, C comments
##   Controller:  d-pad / stick up and down, A like, X comments, B back
##   Touch/mouse: swipe or the wheel, double-tap to like, tap the buttons
## In the comments: type in the box (Enter posts) or pick a quick reply
## (left / right and A on a controller); B or Esc closes them.

const BEATS := [
	preload("res://assets/sounds/zomtok_beat_0.wav"),
	preload("res://assets/sounds/zomtok_beat_1.wav"),
	preload("res://assets/sounds/zomtok_beat_2.wav"),
]
const BPM := [100, 120, 128]  # (tools/make_sounds.py: BEAT_BPM)
const LOOP_BEATS := 8
const LIKE_SOUND := preload("res://assets/sounds/zomtok_like.wav")
const HEART := preload("res://assets/sprites/zt_heart.png")
const BUBBLE := preload("res://assets/sprites/zt_comment.png")
const SHARE := preload("res://assets/sprites/zt_share.png")
const NOTE := preload("res://assets/sprites/zt_note.png")
const GRAVEYARD := preload("res://assets/sprites/pc_wallpaper.png")
const SHELF := preload("res://assets/sprites/shelf.png")
const LAMP := preload("res://assets/sprites/prop_lamp.png")
const PINK := Color(0.95, 0.29, 0.48)
const MINT := Color(0.45, 0.95, 0.75)
const QUICK := ["BRAAAINS", "so good", "10/10", "teach me!", "the spin!!", "rotten (compliment)"]
const ME := "@zupermarket_boss"
const SWIPE := 60.0  # pixels up or down that change the video
const DOUBLE_TAP := 0.35

var index := 0  # the video you're watching
var day := -1
var liked := {}  # "day:index" -> true
var comment_liked := {}  # "day:index:text" -> true
var my_comments := {}  # "day:index" -> [{user, text, likes, mine}], newest first
var following := {}  # handle -> true
var shared := {}  # "day:index" -> true

var phone: PanelContainer
var view: Control  # the video (drawn), and everything over it
var help_label: Label  # how it works, left of the phone (if there's room)
var logo: Label
var avatar: Button
var follow_button: Button
var like_button: Button
var like_label: Label
var comment_button: Button
var comment_label: Label
var share_button: Button
var share_label: Label
var handle_label: Label
var caption_label: Label
var sound_label: Label
var info_box: VBoxContainer
var rail: VBoxContainer
var sheet: PanelContainer  # the comments
var sheet_title: Label
var sheet_scroll: ScrollContainer
var sheet_list: VBoxContainer
var reply_field: LineEdit
var chips: Array[Button] = []
var chip_pick := 0
var toast: Label
var music: AudioStreamPlayer

var _videos := {}  # index -> today's video
var _t := 0.0  # seconds into the video
var _slide := 0.0  # 1 (or -1): the video just came in from below (above), settling to 0
var _pops: Array = []  # [where, age]: big hearts from a double tap
var _last_tap := -10.0
var _drag_from := Vector2.INF
var _wheel_cd := 0.0
var _stick := 0
var _toast_t := 0.0
var _beat := 0.0  # beats into the video (the dancers move to this)
var _playing := -1  # the track that's playing
var _clock := 0.0  # seconds the app's been showing (double taps are timed on this)
var _heard := -1.0  # the track's position last frame (to tell it's really playing)


func _init() -> void:
	custom_minimum_size = Vector2(300, 300)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	logo = UI.label("ZomTok", PINK)
	logo.add_theme_font_size_override("font_size", 34)
	logo.add_theme_constant_override("outline_size", 6)
	logo.add_theme_color_override("font_outline_color", Color(0.1, 0.35, 0.28))
	add_child(logo)
	help_label = UI.label("", UI.DIM)
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(help_label)

	phone = PanelContainer.new()
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.01, 0.01, 0.02)
	frame.border_color = Color(0.2, 0.2, 0.23)
	frame.set_border_width_all(5)
	frame.set_corner_radius_all(16)
	frame.set_content_margin_all(5)
	phone.add_theme_stylebox_override("panel", frame)
	add_child(phone)
	view = Control.new()
	view.clip_contents = true
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.draw.connect(_draw_video)
	view.gui_input.connect(_view_input)
	phone.add_child(view)

	# Down the right side: who posted it (+ to follow), like, comments, share.
	rail = VBoxContainer.new()
	rail.add_theme_constant_override("separation", 2)
	rail.alignment = BoxContainer.ALIGNMENT_END
	view.add_child(rail)
	avatar = _rail_button(null, func(): toggle_follow())
	var ring := StyleBoxFlat.new()  # their picture in a white circle
	ring.bg_color = Color(0.2, 0.2, 0.24)
	ring.border_color = Color.WHITE
	ring.set_border_width_all(2)
	ring.set_corner_radius_all(40)
	ring.set_content_margin_all(4)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		avatar.add_theme_stylebox_override(st, ring)
	rail.add_child(avatar)
	follow_button = UI.button("+", func(): toggle_follow(), Vector2(22, 22))
	var round_style := StyleBoxFlat.new()
	round_style.bg_color = PINK
	round_style.set_corner_radius_all(11)
	round_style.set_content_margin_all(0)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		follow_button.add_theme_stylebox_override(st, round_style)
	follow_button.add_theme_font_size_override("font_size", 16)
	follow_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rail.add_child(follow_button)
	like_button = _rail_button(HEART, func(): toggle_like())
	rail.add_child(like_button)
	like_label = _rail_label()
	rail.add_child(like_label)
	comment_button = _rail_button(BUBBLE, func(): open_comments())
	rail.add_child(comment_button)
	comment_label = _rail_label()
	rail.add_child(comment_label)
	share_button = _rail_button(SHARE, func(): share())
	rail.add_child(share_button)
	share_label = _rail_label()
	rail.add_child(share_label)

	# Along the bottom: who, what they wrote, the sound.
	info_box = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 2)
	info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(info_box)
	handle_label = _info_label(Color.WHITE)
	info_box.add_child(handle_label)
	caption_label = _info_label(Color(1, 1, 1, 0.92))
	caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_label.max_lines_visible = 3
	info_box.add_child(caption_label)
	var sound_row := HBoxContainer.new()
	sound_row.add_theme_constant_override("separation", 4)
	sound_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_box.add_child(sound_row)
	var note := UI.icon(NOTE, Vector2(14, 14))
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sound_row.add_child(note)
	sound_label = _info_label(Color(1, 1, 1, 0.85))
	sound_label.clip_text = true
	sound_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sound_row.add_child(sound_label)

	_build_sheet()
	toast = UI.label("", Color.WHITE)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var toast_style := StyleBoxFlat.new()
	toast_style.bg_color = Color(0, 0, 0, 0.75)
	toast_style.set_corner_radius_all(8)
	toast_style.set_content_margin_all(8)
	toast.add_theme_stylebox_override("normal", toast_style)
	toast.visible = false
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(toast)

	music = AudioStreamPlayer.new()
	add_child(music)
	resized.connect(_layout)


func _rail_button(tex: Texture2D, on_press: Callable) -> Button:
	var b := UI.button("", on_press, Vector2(48, 44))
	b.icon = tex
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var clear := StyleBoxEmpty.new()  # (no button around it: just the icon, as big as it fits)
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, clear)
	return b


func _rail_label() -> Label:
	var l := _info_label(Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _info_label(c: Color) -> Label:
	var l := UI.label("", c)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## The comments: a panel that comes up over the bottom of the video.
func _build_sheet() -> void:
	sheet = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.14, 0.98)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.set_content_margin_all(10)
	sheet.add_theme_stylebox_override("panel", style)
	sheet.visible = false
	view.add_child(sheet)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	sheet.add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	sheet_title = UI.label("", Color.WHITE)
	sheet_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(sheet_title)
	top.add_child(UI.button("X", close_comments, Vector2(36, 32)))
	sheet_scroll = ScrollContainer.new()
	sheet_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sheet_scroll)
	sheet_list = VBoxContainer.new()
	sheet_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_list.add_theme_constant_override("separation", 8)
	sheet_scroll.add_child(sheet_list)
	var chip_scroll := ScrollContainer.new()  # quick replies, in one row you can scroll along
	chip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chip_scroll.follow_focus = true
	col.add_child(chip_scroll)
	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 4)
	chip_scroll.add_child(quick)
	for q: String in QUICK:
		var b := UI.button(q, func(): post_comment(q), Vector2(0, 30))
		b.add_theme_font_size_override("font_size", 13)
		quick.add_child(b)
		chips.append(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	col.add_child(row)
	reply_field = LineEdit.new()
	reply_field.placeholder_text = "Add a comment..."
	reply_field.max_length = 120
	reply_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reply_field.text_submitted.connect(func(t: String): post_comment(t))
	row.add_child(reply_field)
	var post := UI.button("Post", func(): post_comment(reply_field.text), Vector2(64, 0))
	post.add_theme_color_override("font_color", PINK)
	row.add_child(post)


# ---------------------------------------------------------------- the feed

func _key(i := -1) -> String:
	return "%d:%d" % [Game.day, index if i < 0 else i]


## The video you're on (today's feed).
func current() -> Dictionary:
	if day != Game.day:  # a new day, a new feed (from the top)
		day = Game.day
		_videos.clear()
		index = 0
	if not _videos.has(index):
		_videos[index] = ZomTokFeed.video(Game.day, index)
	return _videos[index]


func next() -> void:
	_go(index + 1, 1.0)


func previous() -> void:
	if index > 0:
		_go(index - 1, -1.0)


func _go(i: int, from: float) -> void:
	close_comments()
	index = i
	_t = 0.0
	_slide = from
	_pops.clear()
	_refresh()
	_playing = -1  # (its own track, from the start)


func is_liked(i := -1) -> bool:
	return liked.has(_key(i))


func like_count() -> int:
	return int(current().likes) + (1 if is_liked() else 0)


func toggle_like() -> void:
	set_like(not is_liked())


func set_like(on: bool) -> void:
	if on == is_liked():
		return
	if on:
		liked[_key()] = true
		_play(LIKE_SOUND)
		Settings.vibrate(0.2, 0.05)
	else:
		liked.erase(_key())
	_refresh()


func toggle_follow() -> void:
	var h: String = current().handle
	if following.has(h):
		following.erase(h)
		show_toast("Unfollowed %s" % h)
	else:
		following[h] = true
		show_toast("Following %s" % h)
	_refresh()


func share() -> void:
	if not shared.has(_key()):
		shared[_key()] = true
	show_toast("Sent to the group chat")
	_refresh()


## Every comment on the video: yours first (newest first), then the top ones.
func comments() -> Array:
	var out: Array = (my_comments.get(_key(), []) as Array).duplicate()
	out.append_array(current().comments)
	return out


func comment_total() -> int:
	return int(current().comment_count) + (my_comments.get(_key(), []) as Array).size()


func post_comment(text: String) -> void:
	text = text.strip_edges()
	if text == "":
		return
	var mine: Array = my_comments.get(_key(), [])
	var c := {"user": ME, "text": text.left(120), "likes": 0, "mine": true}
	mine.insert(0, c)
	my_comments[_key()] = mine
	reply_field.clear()
	reply_field.release_focus()
	_refresh()
	_fill_comments()
	sheet_scroll.scroll_vertical = 0
	# A moment later, whoever posted it likes your comment.
	var who: String = current().handle
	var at := _key()
	get_tree().create_timer(1.6).timeout.connect(func():
		c.likes = int(c.likes) + 1
		c.liked_by_creator = true
		if is_visible_in_tree() and _key() == at:
			show_toast("%s liked your comment" % who)
			if sheet.visible:
				_fill_comments()
	)


func open_comments() -> void:
	sheet.visible = true
	chip_pick = clampi(chip_pick, 0, chips.size() - 1)
	_fill_comments()
	sheet_scroll.scroll_vertical = 0
	_layout()


func close_comments() -> void:
	if sheet == null:
		return
	sheet.visible = false
	if reply_field.has_focus():
		reply_field.release_focus()


## Esc / B: closes the comments if they're open (true), or leaves it to the
## computer (false: back to the desktop).
func back() -> bool:
	if sheet.visible:
		close_comments()
		return true
	return false


func _fill_comments() -> void:
	UI.clear(sheet_list)
	sheet_title.text = "%s comments" % ZomTokFeed.count_text(comment_total())
	var k := _font_k()
	var all := comments()
	for i in all.size():
		var c: Dictionary = all[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		sheet_list.add_child(row)
		var face := Label.new()  # a round picture: their first letter
		var user: String = c.user
		face.text = user.substr(1, 1).to_upper()
		face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		face.custom_minimum_size = Vector2(30, 30)
		var dot := StyleBoxFlat.new()
		dot.bg_color = PINK if c.get("mine", false) else Color.from_hsv(float(hash(user) % 360) / 360.0, 0.45, 0.6)
		dot.set_corner_radius_all(15)
		face.add_theme_stylebox_override("normal", dot)
		face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(face)
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", 0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		var who := UI.label(user + ("  (you)" if c.get("mine", false) else ""), UI.DIM)
		who.add_theme_font_size_override("font_size", roundi(13 * k))
		words.add_child(who)
		var text := UI.label(str(c.text), Color.WHITE)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_theme_font_size_override("font_size", roundi(15 * k))
		words.add_child(text)
		if c.get("liked_by_creator", false):
			var by := UI.label("Liked by the creator", PINK)
			by.add_theme_font_size_override("font_size", roundi(12 * k))
			words.add_child(by)
		var likes := VBoxContainer.new()
		likes.add_theme_constant_override("separation", 0)
		row.add_child(likes)
		var ck := "%s:%s" % [_key(), c.text]
		var heart := UI.button("", func():
			if comment_liked.has(ck):
				comment_liked.erase(ck)
			else:
				comment_liked[ck] = true
				_play(LIKE_SOUND)
			_fill_comments(), Vector2(32, 26))
		heart.icon = HEART
		heart.flat = true
		heart.expand_icon = true
		heart.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		heart.add_theme_constant_override("icon_max_width", 16)
		heart.modulate = PINK if comment_liked.has(ck) else Color(1, 1, 1, 0.6)
		likes.add_child(heart)
		var n := UI.label(ZomTokFeed.count_text(int(c.likes) + (1 if comment_liked.has(ck) else 0)), UI.DIM)
		n.add_theme_font_size_override("font_size", roundi(12 * k))
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		likes.add_child(n)
	for i in chips.size():  # (the quick reply A would post, with a controller)
		if i == chip_pick and UI.has_pad():
			chips[i].add_theme_stylebox_override("normal", UI.focus_style())
			var row := chips[i].get_parent().get_parent() as ScrollContainer
			row.ensure_control_visible.call_deferred(chips[i])
		else:
			chips[i].remove_theme_stylebox_override("normal")


## The numbers and words over the video.
func _refresh() -> void:
	var v := current()
	avatar.icon = _face(v.looks[0])
	follow_button.visible = not following.has(v.handle)
	like_button.modulate = PINK if is_liked() else Color.WHITE
	like_label.text = ZomTokFeed.count_text(like_count())
	comment_label.text = ZomTokFeed.count_text(comment_total())
	share_label.text = ZomTokFeed.count_text(int(v.shares) + (1 if shared.has(_key()) else 0))
	handle_label.text = v.handle + ("  · Following" if following.has(v.handle) else "")
	caption_label.text = v.caption
	sound_label.text = v.sound
	if sheet.visible:
		_fill_comments()


## The top of a dancer's sprite (their head), for the round picture.
static func _face(tex: Texture2D) -> Texture2D:
	var a := AtlasTexture.new()
	a.atlas = tex
	var w := tex.get_width()
	a.region = Rect2(0, 0, w, mini(tex.get_height(), w))
	return a


func show_toast(text: String) -> void:
	toast.text = text
	toast.visible = true
	toast.reset_size()
	_toast_t = 1.6
	_layout()


func _play(stream: AudioStream) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


# ---------------------------------------------------------------- layout

func _font_k() -> float:
	return clampf(phone.size.y / 480.0, 0.8, 1.6) if phone else 1.0


## The phone in the middle, as tall as there's room for (9:16), with the
## logo and how it works on the left if there's space.
func _layout() -> void:
	if phone == null:
		return
	var h := size.y
	var w := minf(floorf(h * 9.0 / 16.0), size.x)
	phone.position = Vector2(floorf((size.x - w) / 2.0), 0)
	phone.size = Vector2(w, h)
	var left := phone.position.x
	logo.visible = left > 170.0
	help_label.visible = left > 170.0
	logo.position = Vector2(maxf(0.0, left - 300.0), 8)
	help_label.position = Vector2(logo.position.x, 64)
	help_label.size = Vector2(minf(280.0, left - 20.0), 0)
	var k := _font_k()
	var vw := w - 10.0
	var vh := h - 10.0
	for l: Label in [handle_label]:
		l.add_theme_font_size_override("font_size", roundi(17 * k))
	for l: Label in [caption_label, sound_label]:
		l.add_theme_font_size_override("font_size", roundi(14 * k))
	for l: Label in [like_label, comment_label, share_label]:
		l.add_theme_font_size_override("font_size", roundi(13 * k))
	var b := roundf(40 * k)
	for btn: Button in [like_button, comment_button, share_button]:
		btn.custom_minimum_size = Vector2(b + 6, b)
		btn.add_theme_constant_override("icon_max_width", roundi(b * 0.85))
	avatar.custom_minimum_size = Vector2(b + 6, b + 6)
	avatar.add_theme_constant_override("icon_max_width", roundi(b * 0.62))
	rail.reset_size()
	rail.position = Vector2(vw - rail.size.x - 4, vh - rail.size.y - vh * 0.14)
	info_box.position = Vector2(10, 0)
	info_box.size = Vector2(vw - rail.size.x - 22, 0)
	info_box.reset_size()
	info_box.size.x = vw - rail.size.x - 22
	info_box.position.y = vh - info_box.size.y - 14
	sheet.position = Vector2(0, roundf(vh * 0.36))
	sheet.size = Vector2(vw, vh - sheet.position.y)
	# The toast: one line, in smaller letters if it's wider than the phone.
	var font := toast.get_theme_font("font")
	var fsz := roundi(15 * k)
	var natural := font.get_string_size(toast.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x + 20.0
	if natural > vw - 24.0:
		fsz = maxi(9, floori(fsz * (vw - 44.0) / (natural - 20.0)))
	toast.add_theme_font_size_override("font_size", fsz)
	toast.size = Vector2.ZERO
	toast.reset_size()
	toast.position = Vector2(roundf((vw - toast.size.x) / 2.0), roundf(vh * 0.1))


# ---------------------------------------------------------------- running

func _process(delta: float) -> void:
	var on := is_visible_in_tree() and not get_tree().paused
	if not on:
		if music.playing:
			music.stop()
		_playing = -1
		return
	if day != Game.day:
		current()
		_refresh()
	var v := current()
	if Engine.time_scale > 0.0:
		delta /= Engine.time_scale  # (real time, whatever speed the store runs at)
	var bpm: float = BPM[v.beat]
	var loop := LOOP_BEATS * 60.0 / bpm
	if _playing != int(v.beat):
		_playing = int(v.beat)
		music.stream = BEATS[v.beat]
		music.play()
		_t = 0.0
	_clock += delta
	# The dancers keep their own time, in step with the music while it's
	# really playing (no sound card, or the track not started yet: they
	# carry on anyway).
	_t = fmod(_t + delta, loop)
	var pos := music.get_playback_position() if music.playing else -1.0
	if pos > 0.0 and pos != _heard:
		_t = fmod(pos + AudioServer.get_time_since_last_mix(), loop)
	_heard = pos
	_beat = _t * bpm / 60.0
	_slide = move_toward(_slide, 0.0, delta * 5.0)
	_wheel_cd = maxf(0.0, _wheel_cd - delta)
	for p: Array in _pops:
		p[1] += delta
	_pops = _pops.filter(func(p): return p[1] < 0.9)
	if _toast_t > 0.0:
		_toast_t -= delta
		toast.visible = _toast_t > 0.0
	if UI.has_pad():
		help_label.text = "D-pad up / down: next video\nA: like\nX: comments\nB: back"
	elif Game.touch_ui:
		help_label.text = "Swipe up: next video\nDouble-tap: like\nTap the bubble for the comments"
	else:
		help_label.text = "Up / Down or the wheel: next video\nSpace, L or a double-click: like\nC: comments\nEsc: back"
	view.queue_redraw()


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or get_tree().paused:
		return
	if reply_field.has_focus():
		return  # (typing a comment: the keys are the box's; Esc closes the comments)
	var handled := true
	if sheet.visible:
		handled = _sheet_input(event)
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP, KEY_W:
				previous()
			KEY_DOWN, KEY_S:
				next()
			KEY_SPACE, KEY_L, KEY_ENTER, KEY_KP_ENTER:
				if event.echo:
					return
				toggle_like()
			KEY_C:
				open_comments()
			_:
				handled = false
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_UP:
				previous()
			JOY_BUTTON_DPAD_DOWN:
				next()
			JOY_BUTTON_A:
				toggle_like()
			JOY_BUTTON_X:
				open_comments()
			_:
				handled = false
	elif event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y:
		var now := 0 if absf(event.axis_value) < 0.6 else signi(roundi(event.axis_value))
		if now != _stick and now != 0:
			if now > 0:
				next()
			else:
				previous()
		_stick = now
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


## The comments are open: up / down scroll, left / right pick a quick reply,
## A posts it, Enter (keys) goes to the box to type. True if it was used.
func _sheet_input(event: InputEvent) -> bool:
	var d := 0
	var side := 0
	var go := false
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP, KEY_W:
				d = -1
			KEY_DOWN, KEY_S:
				d = 1
			KEY_LEFT, KEY_A:
				side = -1
			KEY_RIGHT, KEY_D:
				side = 1
			KEY_ENTER, KEY_KP_ENTER, KEY_T:
				reply_field.grab_focus()
				return true
			_:
				return false
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_UP:
				d = -1
			JOY_BUTTON_DPAD_DOWN:
				d = 1
			JOY_BUTTON_DPAD_LEFT:
				side = -1
			JOY_BUTTON_DPAD_RIGHT:
				side = 1
			JOY_BUTTON_A:
				go = true
			JOY_BUTTON_X:
				close_comments()
				return true
			_:
				return false
	else:
		return false
	if d != 0:
		sheet_scroll.scroll_vertical += d * 60
	if side != 0:
		chip_pick = wrapi(chip_pick + side, 0, chips.size())
		_fill_comments()
	if go:
		post_comment(QUICK[chip_pick])
	return true


## On the video: a double tap likes it (a big heart where you tapped), a
## swipe up or down (or the wheel) changes the video.
func _view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if _wheel_cd <= 0.0 and not sheet.visible:
			_wheel_cd = 0.35
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				next()
			else:
				previous()
		view.accept_event()
		return
	# (A touch comes in as the mouse too, so only the mouse is read: one tap
	# is one tap, and two quick ones are a double tap.)
	var pos := Vector2.INF
	var down := false
	var up := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		down = event.pressed
		up = not event.pressed
	else:
		return
	view.accept_event()
	if sheet.visible:
		if down and not sheet.get_rect().has_point(pos):
			close_comments()  # (a tap above the comments closes them)
		return
	if down:
		if _drag_from == Vector2.INF:
			_drag_from = pos
		var now := _clock
		if now - _last_tap < DOUBLE_TAP and pos.distance_to(_drag_from) < SWIPE:
			set_like(true)
			_pops.append([pos, 0.0])
			_last_tap = -10.0
		else:
			_last_tap = now
	elif up and _drag_from != Vector2.INF:
		var dy := pos.y - _drag_from.y
		_drag_from = Vector2.INF
		if dy < -SWIPE:
			next()
		elif dy > SWIPE:
			previous()


# ---------------------------------------------------------------- drawing the video

func _draw_video() -> void:
	var v := current()
	var sz := view.size
	var s := maxf(1.0, floorf(sz.y * 0.36 / 36.0))  # how big the dancers are (whole pixels)
	var floor_y := roundf(sz.y * 0.66)
	var lift := roundf(_slide * sz.y * 0.25)
	view.draw_set_transform(Vector2(0, lift))
	_draw_backdrop(v.backdrop, sz, s, floor_y)
	var looks: Array = v.looks
	var n := looks.size()
	var spacing := minf(sz.x * 0.3, 22.0 * s)
	for j in n:
		var x := sz.x / 2.0 + (j - (n - 1) / 2.0) * spacing - (sz.x * 0.06 if n == 1 else 0.0)
		var feet := Vector2(roundf(x), floor_y + roundf(sz.y * 0.1) + (0.0 if j == 0 else -s * 2.0))
		_draw_dancer(looks[j], feet, s, str(v.dance), j)
	var flash := maxf(0.0, 1.0 - fmod(_beat, 1.0) * 4.0)
	if v.backdrop in ["disco", "store"]:
		view.draw_rect(Rect2(Vector2.ZERO, sz), Color(1, 1, 1, 0.06 * flash))
	view.draw_set_transform(Vector2.ZERO)
	# Darker at the bottom (for the words) and the top.
	_gradient(Rect2(0, sz.y * 0.62, sz.x, sz.y * 0.38), Color(0, 0, 0, 0), Color(0, 0, 0, 0.6))
	_gradient(Rect2(0, 0, sz.x, sz.y * 0.12), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0))
	if absf(_slide) > 0.0:
		view.draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, absf(_slide) * 0.7))
	var font := get_theme_default_font()
	var fs := roundi(15 * _font_k())
	var mid := sz.x / 2.0
	view.draw_string(font, Vector2(mid - 104 * _font_k(), 26 * _font_k()), "Following", HORIZONTAL_ALIGNMENT_RIGHT, 92 * _font_k(), fs, Color(1, 1, 1, 0.6))
	view.draw_string(font, Vector2(mid + 8 * _font_k(), 26 * _font_k()), "For You", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	view.draw_rect(Rect2(mid + 8 * _font_k() + 12 * _font_k(), 32 * _font_k(), 30 * _font_k(), 2), Color.WHITE)
	for p: Array in _pops:  # big hearts from a double tap
		var age: float = p[1]
		var hs := 6.0 * (1.0 + age * 0.6)
		var a := clampf(1.0 - (age - 0.4) / 0.5, 0.0, 1.0)
		view.draw_set_transform(p[0] - Vector2(0, age * 40.0), -0.25 + age * 0.2, Vector2(hs, hs))
		view.draw_texture(HEART, -HEART.get_size() / 2.0, Color(PINK, a))
	view.draw_set_transform(Vector2.ZERO)
	var bpm: float = BPM[v.beat]
	var f := fmod(_t, LOOP_BEATS * 60.0 / bpm) / (LOOP_BEATS * 60.0 / bpm)
	view.draw_rect(Rect2(0, sz.y - 3, sz.x, 3), Color(1, 1, 1, 0.2))
	view.draw_rect(Rect2(0, sz.y - 3, sz.x * f, 3), Color(1, 1, 1, 0.85))


func _gradient(r: Rect2, top: Color, bottom: Color) -> void:
	view.draw_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]),
		PackedColorArray([top, top, bottom, bottom]))


## Where it was filmed.
func _draw_backdrop(kind: String, sz: Vector2, s: float, floor_y: float) -> void:
	match kind:
		"store", "bonemart":
			var bones := kind == "bonemart"
			var wall: Texture2D = load("res://assets/sprites/wall_%s_swatch.png" % ("bone" if bones else Brand.WALL_COLORS[Game.wall_color].id))
			var k := s * 0.75
			var ws := wall.get_size() * k
			for y in ceili(floor_y / ws.y) + 1:
				for x in ceili(sz.x / ws.x) + 1:
					view.draw_texture_rect(wall, Rect2(Vector2(x * ws.x, floor_y - (y + 1) * ws.y).floor(), ws.ceil()), false, Color(0.55, 0.55, 0.6) if not bones else Color(0.62, 0.62, 0.58))
			view.draw_rect(Rect2(0, floor_y, sz.x, sz.y - floor_y), Color(0.1, 0.1, 0.1))
			if bones:  # Bone Mart's black and white floor
				var t := 8.0 * k
				for y in ceili((sz.y - floor_y) / t):
					for x in ceili(sz.x / t):
						if (x + y) % 2 == 0:
							view.draw_rect(Rect2(x * t, floor_y + y * t, t, t), Color(0.82, 0.8, 0.74))
			else:
				var tile: Texture2D = load("res://assets/sprites/floor_%s_a.png" % Brand.FLOOR_STYLES[Game.floor_style].id)
				var tk := k * 0.5
				var tw := tile.get_width() * tk
				var th := tile.get_height() * tk
				for row in ceili((sz.y - floor_y) / (th / 2.0)) + 2:
					for x in ceili(sz.x / tw) + 2:
						view.draw_texture_rect(tile, Rect2(Vector2(x * tw - (tw / 2.0 if row % 2 else 0.0) - tw / 2.0, floor_y + row * th / 2.0 - th / 2.0).floor(), Vector2(tw, th).ceil()), false)
			var shelf: Texture2D = RivalShelf.TEXTURE if bones else SHELF
			var sk := maxf(1.0, floorf(k * 0.8))
			var ss := shelf.get_size() * sk
			for x in [sz.x * 0.08, sz.x * 0.62]:
				view.draw_texture_rect(shelf, Rect2(Vector2(x, floor_y - ss.y + 16 * sk).floor(), ss), false, Color(0.75, 0.75, 0.78))
			for x in [sz.x * 0.25, sz.x * 0.75]:  # ceiling lights
				view.draw_rect(Rect2(x - 20, 0, 40, 6), Color(0.95, 1.0, 0.85) if not bones else Color(1.0, 0.9, 0.85))
		"street":
			_gradient(Rect2(0, 0, sz.x, floor_y), Color(0.05, 0.05, 0.14), Color(0.28, 0.14, 0.3))
			view.draw_circle(Vector2(sz.x * 0.78, sz.y * 0.14), sz.x * 0.08, Color(0.95, 0.92, 0.75))
			for i in 7:  # buildings
				var bw := sz.x / 5.0
				var bh := sz.y * (0.18 + 0.12 * fmod(i * 0.37, 1.0))
				view.draw_rect(Rect2(i * bw * 0.8 - 10, floor_y - bh, bw * 0.75, bh), Color(0.07, 0.06, 0.1))
			view.draw_rect(Rect2(0, floor_y, sz.x, sz.y - floor_y), Color(0.16, 0.16, 0.18))
			var dash := sz.x / 6.0
			for i in 7:
				view.draw_rect(Rect2(i * dash - fmod(_beat * 6.0, dash), floor_y + (sz.y - floor_y) * 0.55, dash * 0.5, 4), Color(0.85, 0.75, 0.25))
			var lk := maxf(1.0, floorf(s * 0.75))
			var ls := LAMP.get_size() * lk
			view.draw_texture_rect(LAMP, Rect2(Vector2(sz.x * 0.02, floor_y - ls.y + 16 * lk).floor(), ls), false)
		"graveyard":
			var gk := sz.y / GRAVEYARD.get_height()
			var gs := GRAVEYARD.get_size() * gk
			view.draw_texture_rect(GRAVEYARD, Rect2(Vector2((sz.x - gs.x) * 0.3, 0), gs), false)
			_gradient(Rect2(0, floor_y, sz.x, sz.y - floor_y), Color(0.1, 0.06, 0.12, 0.0), Color(0.08, 0.05, 0.1, 0.9))
		_:  # "disco": a dance floor that lights up on the beat, and a mirror ball
			view.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.04, 0.02, 0.07))
			var b := int(_beat)
			for i in 5:  # light beams, fanning down from the ball
				var from := Vector2(sz.x / 2.0, sz.y * 0.08)
				var ang := (i - 2) * 0.35 + sin(_beat * 0.8 + i) * 0.25
				var to := from + Vector2(sin(ang), cos(ang)) * sz.y
				var c := Color.from_hsv(fmod(i * 0.2 + _beat * 0.05, 1.0), 0.7, 1.0, 0.12)
				var perp := (to - from).normalized().orthogonal() * sz.x * 0.08
				view.draw_colored_polygon(PackedVector2Array([from, to + perp, to - perp]), c)
			var t := maxf(12.0, floorf(sz.x / 6.0))
			for y in ceili((sz.y - floor_y) / t) + 1:
				for x in ceili(sz.x / t) + 1:
					var lit := (x + y + b) % 3 == 0
					var c := Color.from_hsv(fmod((x * 7 + y * 3 + b) * 0.13, 1.0), 0.6, 0.85 if lit else 0.25)
					view.draw_rect(Rect2(x * t + 1, floor_y + y * t + 1, t - 2, t - 2), c)
			view.draw_circle(Vector2(sz.x / 2.0, sz.y * 0.08), sz.x * 0.06, Color(0.75, 0.78, 0.85))
			for i in 6:
				var a := _beat * 2.0 + i
				view.draw_rect(Rect2(Vector2(sz.x / 2.0, sz.y * 0.08) + Vector2(cos(a), sin(a) * 0.6) * sz.x * 0.04 - Vector2(1.5, 1.5), Vector2(3, 3)), Color.WHITE)


## One dancer, feet at `feet`, `s` screen pixels to a sprite pixel.
func _draw_dancer(tex: Texture2D, feet: Vector2, s: float, dance: String, j: int) -> void:
	var b := _beat + (j * 0.25 if dance == "wave" else 0.0)
	var p := fmod(b, 1.0)
	var dx := 0.0
	var dy := 0.0
	var rot := 0.0
	var sx := -1.0 if j % 2 == 1 else 1.0  # (friends face the other way)
	var sy := 1.0
	match dance:
		"bounce", "wave":
			dy = -absf(sin(PI * b)) * 4.0
			if p < 0.12:
				sy = 0.92
				sx *= 1.08
		"sway":
			dx = sin(PI * b) * 3.0
			rot = sin(PI * b) * 0.14
		"spin":
			var q := fmod(b, 2.0)
			if q < 0.5:
				sx *= cos(q / 0.5 * TAU)
				dy = -sin(q / 0.5 * PI) * 5.0
		"flip":
			if int(floor(b)) % 2 == 1:
				sx = -sx
			dy = -absf(sin(PI * b)) * 3.0
		"moonwalk":
			dx = sin(PI * b / 4.0) * 9.0
			sx = (-1.0 if cos(PI * b / 4.0) > 0.0 else 1.0)
			dy = -absf(sin(PI * b * 2.0)) * 1.0
		"headbang":
			rot = absf(sin(PI * b * 2.0)) * 0.3 * (1.0 if j % 2 == 0 else -1.0)
		"jump":
			var q := fmod(b, 2.0) / 2.0
			dy = -sin(PI * q) * 14.0
			if q > 0.92 or q < 0.04:
				sy = 0.88
				sx *= 1.1
		"shuffle":
			dx = (1.0 if int(floor(b * 2.0)) % 2 == 0 else -1.0) * 2.0
			dy = -absf(sin(PI * b * 2.0)) * 2.0
	var w := tex.get_width()
	var h := tex.get_height()
	view.draw_set_transform(feet + Vector2(0, roundf(_slide * view.size.y * 0.25)), 0.0, Vector2(1.0, 0.3))  # a shadow
	view.draw_circle(Vector2.ZERO, w * s * 0.45 * (1.0 + dy / 40.0), Color(0, 0, 0, 0.35))
	var at := feet + Vector2(roundf(dx * s), roundf(dy * s) + roundf(_slide * view.size.y * 0.25))
	view.draw_set_transform(at, rot, Vector2(sx * s, sy * s))
	view.draw_texture(tex, Vector2(-w / 2.0, -(h - 3)))
	view.draw_set_transform(Vector2(0, roundf(_slide * view.size.y * 0.25)))
