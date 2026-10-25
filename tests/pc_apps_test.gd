extends Node
# The store computer's fun apps (0.17):
#  Snake   moving, eating and growing (faster), turning (no doubling back,
#          quick presses queue up), walls and yourself end it, the best score
#          is kept with the store; keys, the d-pad, swipes and the arrow
#          buttons steer; it pauses when you leave it
#  ZomTok  the feed (the same video for the same day, the town's characters
#          by store level, your staff, Mr. Bones, Count Vlad, the gang),
#          the beat playing, likes (the heart, a double tap, A), comments
#          (yours on top, quick replies, the poster likes yours), next and
#          previous (keys, d-pad, wheel, swipe), B closing the comments first
#  the PC  8 apps: LB / RB and 7 / 8 reach them, the taskbar fits
#   godot --headless --path . --fixed-fps 60 res://tests/pc_apps_test.tscn

var fails := 0
var hud: Node
var pc: Node


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	seed(1717)
	Engine.max_fps = 0
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	hud = main.get_node("HUD")
	pc = hud.computer
	Game.tutorial_hidden = true
	hud.tutorial._hide_all()
	Game.money = 5000.0
	hud.levelup_panel.visible = false
	hud.open_computer()
	await _frames(2)
	check(pc.desktop_icons.size() == 8 and pc.desktop_icons[6].text == "Snake" and pc.desktop_icons[7].text == "ZomTok", "the PC has Snake and ZomTok on the desktop")
	check(pc.tab_buttons[6].text == "" and pc.tab_buttons[6].tooltip_text == "Snake" and pc.tab_buttons[7].icon != null, "and on the taskbar (just their icons)")
	await _snake()
	await _zomtok()
	await _pc()
	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- Snake

func _snake() -> void:
	pc.show_tab(pc.Tab.SNAKE)
	await _frames(2)
	var sn: PcSnake = pc.snake
	check(sn.is_visible_in_tree() and not pc.scroll.visible and not pc.news_label.visible and not pc.zomtok.visible, "Snake fills the window (no list, news or footer)")
	check(sn.state == PcSnake.State.READY and sn.snake.size() == 3 and sn.food.x >= 0 and not sn.food in sn.snake, "a new snake, 3 long, and something to eat")
	_key(KEY_ENTER)
	await _frames(2)
	check(sn.state == PcSnake.State.PLAYING, "Enter starts it")

	# Eating: food right in front.
	sn._turns.clear()
	sn.dir = Vector2i.RIGHT
	sn.snake.assign([Vector2i(6, 7), Vector2i(5, 7), Vector2i(4, 7)])
	sn.food = Vector2i(7, 7)
	var was := sn.step_time
	sn.step()
	check(sn.snake.size() == 4 and sn.snake[0] == Vector2i(7, 7) and sn.score == 1, "it eats what's in front of it and grows")
	check(sn.step_time < was and not sn.food in sn.snake and sn.food_icon != null, "and gets faster, with new food somewhere free")
	sn.step()
	check(sn.snake.size() == 4 and sn.snake[0] == Vector2i(8, 7), "moving on without food: same length")

	# Turning.
	sn.turn(Vector2i.LEFT)
	check(sn._turns.is_empty(), "it can't double back on itself")
	sn.turn(Vector2i.UP)
	sn.turn(Vector2i.LEFT)
	sn.turn(Vector2i.DOWN)
	check(_turns_are(sn, [Vector2i.UP, Vector2i.LEFT]), "quick presses queue up (two at most, never straight back): %s" % [sn._turns])
	sn.step()
	check(sn.dir == Vector2i.UP and sn.snake[0] == Vector2i(8, 6), "and are taken a move at a time")
	sn._turns.clear()

	# Walls and yourself.
	var best_before := Game.snake_best
	sn.score = best_before + 3
	sn.snake.assign([Vector2i(PcSnake.COLS - 1, 3), Vector2i(PcSnake.COLS - 2, 3), Vector2i(PcSnake.COLS - 3, 3)])
	sn.dir = Vector2i.RIGHT
	sn.step()
	check(sn.state == PcSnake.State.OVER, "running into a wall ends it")
	check(Game.snake_best == best_before + 3 and sn.new_best, "a new best score (%d)" % Game.snake_best)
	sn.start()
	sn.snake.assign([Vector2i(5, 5), Vector2i(6, 5), Vector2i(6, 6), Vector2i(5, 6), Vector2i(4, 6)])
	sn.dir = Vector2i.UP
	sn._turns.clear()
	sn.turn(Vector2i.RIGHT)
	sn.food = Vector2i(0, 0)
	sn.step()
	check(sn.state == PcSnake.State.PLAYING and sn.snake[0] == Vector2i(6, 5) or sn.state == PcSnake.State.OVER, "(a twisty snake)")
	sn.start()
	sn.snake.assign([Vector2i(5, 5), Vector2i(5, 6), Vector2i(6, 6), Vector2i(6, 5), Vector2i(6, 4)])
	sn.dir = Vector2i.UP
	sn._turns.clear()
	sn.turn(Vector2i.RIGHT)
	sn.food = Vector2i(0, 0)
	sn.step()
	check(sn.state == PcSnake.State.OVER, "running into yourself ends it")
	sn.start()
	sn.snake.assign([Vector2i(5, 5), Vector2i(5, 6), Vector2i(6, 6), Vector2i(6, 5)])
	sn.dir = Vector2i.UP
	sn._turns.clear()
	sn.turn(Vector2i.RIGHT)
	sn.food = Vector2i(0, 0)
	sn.step()
	check(sn.state == PcSnake.State.PLAYING and sn.snake[0] == Vector2i(6, 5), "but chasing your own tail is fine (it moves out of the way)")

	# Steering: keys, the d-pad, a swipe, the arrow buttons.
	sn.start()
	sn.state = PcSnake.State.PLAYING
	sn.dir = Vector2i.RIGHT
	sn._turns.clear()
	_key(KEY_UP)
	await _frames(1)
	check(_turns_are(sn, [Vector2i.UP]), "the Up arrow turns it")
	sn._turns.clear()
	_key(KEY_S)
	await _frames(1)
	check(_turns_are(sn, [Vector2i.DOWN]), "so does S")
	sn._turns.clear()
	_pad(JOY_BUTTON_DPAD_UP)
	await _frames(1)
	check(_turns_are(sn, [Vector2i.UP]), "and the d-pad")
	sn._turns.clear()
	var c := _at(sn.board, sn.board.size / 2.0)
	_mouse(c, true)
	await _frames(1)
	_drag(c, c + Vector2(0, 60))
	await _frames(1)
	_mouse(c + Vector2(0, 60), false)
	await _frames(1)
	check(Vector2i.DOWN in sn._turns, "a swipe down turns it down: %s" % [sn._turns])
	sn._turns.clear()
	sn.arrow_buttons[Vector2i.UP].pressed.emit()
	check(_turns_are(sn, [Vector2i.UP]), "and the arrow buttons")
	sn._turns.clear()
	var head := sn.snake[0]
	await _frames(30)
	check(sn.snake[0] != head, "it moves on its own (%s -> %s)" % [head, sn.snake[0]])

	# Leaving it pauses it.
	pc.go_home()
	await _frames(2)
	check(sn.state == PcSnake.State.PAUSED, "closing the app pauses it")
	head = sn.snake[0]
	await _frames(20)
	check(sn.snake[0] == head, "(and it stays put)")
	pc.show_tab(pc.Tab.SNAKE)
	await _frames(1)
	_pad(JOY_BUTTON_A)
	await _frames(2)
	check(sn.state == PcSnake.State.PLAYING, "A carries on")

	# Kept with the store.
	Game.snake_best = 42
	var saved: Dictionary = JSON.parse_string(JSON.stringify(Game.to_dict()))
	Game.snake_best = 0
	Game.from_dict(saved)
	check(Game.snake_best == 42, "the best score is saved with the store")
	sn.state = PcSnake.State.OVER


# ---------------------------------------------------------------- ZomTok

func _zomtok() -> void:
	# The feed.
	var a := ZomTokFeed.video(3, 5)
	var b := ZomTokFeed.video(3, 5)
	check(a.handle == b.handle and a.caption == b.caption and a.likes == b.likes and a.comments.size() == b.comments.size(), "the same video for the same day")
	var c := ZomTokFeed.video(4, 5)
	check(c.caption != a.caption or c.handle != a.handle or c.likes != a.likes, "and a different one tomorrow")
	Game.level = 1
	var ok := true
	var kinds := {}
	for i in 120:
		var v := ZomTokFeed.video(9, i)
		kinds[v.get("group", "")] = true
		ok = ok and v.handle.begins_with("@") and (v.looks as Array).size() >= 1 and (v.looks as Array).size() <= 3 \
			and v.looks.all(func(t): return t is Texture2D) and v.dance in ZomTokFeed.DANCES and v.backdrop in ZomTokFeed.BACKDROPS \
			and int(v.beat) >= 0 and int(v.beat) < 3 and str(v.caption) != "" and not "{" in str(v.caption) \
			and (v.comments as Array).size() >= 8 and int(v.comment_count) >= (v.comments as Array).size()
		for k in range(1, (v.comments as Array).size()):
			ok = ok and int(v.comments[k - 1].likes) >= int(v.comments[k].likes) and not "{" in str(v.comments[k].text)
	check(ok, "every video: who, 1-3 dancers, a dance, a place, a track, a caption, comments (top liked first)")
	check(not kinds.has("mummy") and not kinds.has("werewolf") and kinds.has("zombie"), "at store level 1: zombies, no mummies or werewolves yet (%s)" % [kinds.keys()])
	check(kinds.has("bones") and kinds.has("vlad") and not kinds.has("gang"), "Mr. Bones and Count Vlad post too (no gang before the war)")
	Game.hire("stocker")
	var staffer := false
	for i in 200:
		var v := ZomTokFeed.video(9, i)
		if str(v.handle).ends_with("_on_shift"):
			staffer = true
			check(v.looks[0] == Brand.STAFF.stocker.texture, "your stocker dances on shift (%s)" % v.handle)
			break
	check(staffer, "(one of your staff turns up)")
	check(ZomTokFeed.count_text(950) == "950" and ZomTokFeed.count_text(1250) == "1.2K" and ZomTokFeed.count_text(34000) == "34K" and ZomTokFeed.count_text(2100000) == "2.1M", "counts read like 950, 1.2K, 34K, 2.1M")

	# The app.
	pc.show_tab(pc.Tab.ZOMTOK)
	await _frames(3)
	var zt: ZomTokApp = pc.zomtok
	check(zt.is_visible_in_tree() and not pc.snake.visible and not pc.scroll.visible, "ZomTok fills the window")
	check(zt.index == 0 and zt.phone.size.y > 200.0 and absf(zt.phone.size.x / zt.phone.size.y - 9.0 / 16.0) < 0.02, "a phone-shaped screen (%s)" % zt.phone.size)
	var v0 := zt.current()
	check(zt.music.playing and zt.music.stream == ZomTokApp.BEATS[v0.beat] and (zt.music.stream as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD, "its track is playing, on a loop")
	var b0 := zt._beat
	await _frames(20)
	check(zt._beat > b0, "and they dance to it (%.2f -> %.2f beats)" % [b0, zt._beat])
	check(zt.handle_label.text.begins_with(v0.handle) and zt.caption_label.text == v0.caption and zt.like_label.text == ZomTokFeed.count_text(v0.likes), "who posted it, the caption and the likes")

	# Likes.
	zt.like_button.pressed.emit()
	check(zt.is_liked() and zt.like_count() == int(v0.likes) + 1 and zt.like_button.modulate == ZomTokApp.PINK, "the heart likes it (and goes pink)")
	_key(KEY_SPACE)
	await _frames(1)
	check(not zt.is_liked(), "Space un-likes it")
	_pad(JOY_BUTTON_A)
	await _frames(1)
	check(zt.is_liked(), "A likes it")
	zt.set_like(false)
	var mid := _at(zt.view, zt.view.size * Vector2(0.4, 0.4))
	await _tap(mid)
	await _frames(30)
	check(not zt.is_liked(), "one tap doesn't like it")
	await _tap(mid)
	await _frames(2)
	await _tap(mid)
	await _frames(2)
	check(zt.is_liked() and not zt._pops.is_empty(), "a double tap does (with a big heart)")
	zt.set_like(false)
	_touch(mid, true)
	await _frames(2)
	_touch(mid, false)
	await _frames(30)
	check(not zt.is_liked(), "one tap on a touch screen doesn't either (it comes in as a touch and a click)")

	# Next and previous.
	_key(KEY_DOWN)
	await _frames(1)
	check(zt.index == 1 and zt._slide > 0.0, "Down: the next video slides up")
	await _frames(3)
	check(zt.music.stream == ZomTokApp.BEATS[zt.current().beat], "(with its own track)")
	_key(KEY_UP)
	await _frames(1)
	_key(KEY_UP)
	await _frames(1)
	check(zt.index == 0, "Up goes back (not past the first)")
	_pad(JOY_BUTTON_DPAD_DOWN)
	await _frames(1)
	check(zt.index == 1, "the d-pad too")
	await _frames(30)
	_wheel(_at(zt.view, zt.view.size / 2.0), MOUSE_BUTTON_WHEEL_DOWN)
	await _frames(2)
	check(zt.index == 2, "the mouse wheel too")
	var from := _at(zt.view, zt.view.size * Vector2(0.4, 0.7))
	_mouse(from, true)
	await _frames(1)
	_drag(from, from + Vector2(0, -150))
	await _frames(1)
	_mouse(from + Vector2(0, -150), false)
	await _frames(2)
	check(zt.index == 3, "and a swipe up")

	# Comments.
	_pad(JOY_BUTTON_X)
	await _frames(2)
	check(zt.sheet.visible and zt.sheet_list.get_child_count() == zt.comments().size(), "X opens the comments (%d)" % zt.comments().size())
	var total := zt.comment_total()
	zt.post_comment("  this is the one  ")
	await _frames(1)
	check(zt.comments()[0].text == "this is the one" and zt.comments()[0].user == ZomTokApp.ME and zt.comment_total() == total + 1, "your comment goes on top")
	_pad(JOY_BUTTON_DPAD_RIGHT)
	await _frames(1)
	_pad(JOY_BUTTON_A)
	await _frames(1)
	check(zt.chip_pick == 1 and zt.comments()[0].text == ZomTokApp.QUICK[1], "right and A post a quick reply (%s)" % zt.comments()[0].text)
	zt.reply_field.grab_focus()
	_key(KEY_1)
	await _frames(1)
	check(pc.tab == pc.Tab.ZOMTOK and zt.sheet.visible, "typing a 1 in the box doesn't switch apps")
	zt.reply_field.release_focus()
	await _wait(1.8)
	check(int(zt.comments()[0].likes) >= 1 and zt.comments()[0].get("liked_by_creator", false) and zt.toast.text.ends_with("liked your comment"), "a moment later the poster likes your comment")
	hud._back(false)
	await _frames(1)
	check(not zt.sheet.visible and pc.window.visible and pc.tab == pc.Tab.ZOMTOK, "B closes the comments (and only them)")
	zt.toggle_follow()
	check(zt.following.has(zt.current().handle) and not zt.follow_button.visible, "follow whoever posted it")
	var shares := int(zt.current().shares)
	zt.share()
	check(zt.share_label.text == ZomTokFeed.count_text(shares + 1) and zt.toast.visible, "share it")

	# Leaving.
	hud._back(false)
	await _frames(2)
	check(not pc.window.visible and not zt.music.playing, "B again: back to the desktop, and the music stops")
	pc.show_tab(pc.Tab.ZOMTOK)
	await _frames(3)
	check(zt.music.playing and zt.index == 3, "back in ZomTok: where you were, music on")
	Game.day += 1
	await _frames(2)
	check(zt.index == 0 and zt.day == Game.day, "a new day: a new feed, from the top")
	Game.day -= 1
	pc.close()
	await _frames(2)
	check(not zt.music.playing, "closing the PC stops the music")


# ---------------------------------------------------------------- the PC

func _pc() -> void:
	hud.open_computer()
	await _frames(2)
	pc.show_tab(pc.Tab.TURF)
	await _frames(2)
	_pad(JOY_BUTTON_RIGHT_SHOULDER)
	await _frames(2)
	check(pc.tab == pc.Tab.SNAKE and pc.snake.visible, "RB from Turf: Snake")
	_pad(JOY_BUTTON_RIGHT_SHOULDER)
	await _frames(2)
	check(pc.tab == pc.Tab.ZOMTOK and pc.zomtok.visible and not pc.snake.visible, "RB again: ZomTok")
	_pad(JOY_BUTTON_RIGHT_SHOULDER)
	await _frames(2)
	check(pc.tab == pc.Tab.STOCK and pc.scroll.visible and not pc.zomtok.visible and pc.news_label.visible, "and round to Stock & Prices (the list's back)")
	_key(KEY_7)
	await _frames(2)
	check(pc.tab == pc.Tab.SNAKE, "7 opens Snake")
	_key(KEY_8)
	await _frames(2)
	check(pc.tab == pc.Tab.ZOMTOK, "8 opens ZomTok")
	var room: float = pc.screen.size.x
	check(pc.taskbar.get_combined_minimum_size().x <= room + 1.0, "the taskbar still fits (%d of %d)" % [pc.taskbar.get_combined_minimum_size().x, room])
	pc.close()
	await _frames(2)


func _turns_are(sn: PcSnake, want: Array) -> bool:
	if sn._turns.size() != want.size():
		return false
	for i in want.size():
		if sn._turns[i] != want[i]:
			return false
	return true


# ---------------------------------------------------------------- input

func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	var up := e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func _pad(button: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	Input.parse_input_event(e)
	var up := e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


## A point on control `c` (in its own pixels) on the screen.
func _at(c: Control, local: Vector2) -> Vector2:
	return c.get_global_transform_with_canvas() * local


func _mouse(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	e.global_position = at
	if down:
		e.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(e, true)  # (in the viewport's pixels: headless, the window is tiny and stretched)


func _drag(from: Vector2, to: Vector2) -> void:
	for i in range(1, 9):
		var e := InputEventMouseMotion.new()
		e.position = from.lerp(to, i / 8.0)
		e.global_position = e.position
		e.relative = (to - from) / 8.0
		e.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(e, true)


func _tap(at: Vector2) -> void:
	_mouse(at, true)
	await _frames(1)
	_mouse(at, false)


## A real touch (Godot sends it on as a click too), in the window's pixels.
func _touch(at: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = get_viewport().get_final_transform() * at
	e.pressed = down
	Input.parse_input_event(e)


func _wheel(at: Vector2, button: MouseButton) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	e.position = at
	e.global_position = at
	get_viewport().push_input(e, true)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
