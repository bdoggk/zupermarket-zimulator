extends Node
# The loan test (see loan_test.gd).

const SLOT := 2
var fails := 0
var shot_dir := OS.get_environment("SHOT_DIR")
var backup := ""
var defaulted := 0
var days_ended := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	Engine.max_fps = 60
	if FileAccess.file_exists(Saves.slot_path(SLOT)):
		backup = FileAccess.get_file_as_string(Saves.slot_path(SLOT))
	Game.loan_defaulted.connect(func(): defaulted += 1)
	Game.day_ended.connect(func(_s): days_ended += 1)
	await _rules()
	await _start_store()
	await _app()
	await _paid_in_time()
	await _cutscene(false)
	await _start_store()
	await _cutscene(true)
	await _saved_during_visit()
	_finish()


func _finish() -> void:
	Saves.delete_slot(SLOT)
	if backup != "":
		var f := FileAccess.open(Saves.slot_path(SLOT), FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- the rules

func _rules() -> void:
	Game.reset()
	var rates: Array = Game.LOAN_AMOUNTS.map(func(a): return Game.loan_rate(float(a)))
	var rising := true
	for i in range(1, rates.size()):
		rising = rising and rates[i] > rates[i - 1]
	check(rising, "the more you borrow, the higher the interest: %s" % [rates.map(func(r): return "%d%%" % roundi(r * 100.0))])
	check(roundi(Game.loan_rate(250.0) * 100.0) == 5 and roundi(Game.loan_rate(1000.0) * 100.0) == 12 and roundi(Game.loan_rate(10000.0) * 100.0) == 25,
		"$250 at 5%, $1,000 at 12%, $10,000 at 25%")
	check(Game.LOAN_RATES.size() == Game.LOAN_AMOUNTS.size(), "(an interest rate for every amount)")
	check(Game.loan_limit() == 1000.0 and Game.loan_problem(2000.0) == "Store level 2" and Game.loan_problem(1000.0) == "",
		"a new store can borrow up to $1,000 (more as it levels up): " + Game.loan_problem(2000.0))
	Game.level = 12
	check(Game.loan_limit() == 12000.0 and Game.loan_problem(15000.0) == "Store level 15", "level 12: up to $12,000")
	Game.level = 1
	check(Game.cash(1234567.5) == "1,234,567.50" and Game.cash(250.0) == "250", "money reads nicely: $" + Game.cash(1234567.5))

	Game.money = 100.0
	Game.day = 3
	check(Game.take_loan(500.0), "borrow $500")
	var ln: Dictionary = Game.loan
	var pay := 77.15  # $540 over 7 days, rounded up to the cent
	check(is_equal_approx(Game.money, 600.0) and is_equal_approx(float(ln.total), 540.0) and is_equal_approx(float(ln.payment), pay) and int(ln.due) == 10,
		"you get $500 and owe $%s: $%s a morning, all by the night of day %d" % [Game.cash(float(ln.total)), Game.cash(float(ln.payment)), int(ln.due)])
	check(not Game.take_loan(250.0) and Game.loan_problem(250.0) != "", "one loan at a time: " + Game.loan_problem(250.0))
	check(is_equal_approx(float(Game.stats.borrowed), 500.0), "the day's summary counts what you borrowed")

	Game.start_next_day()  # day 4
	check(is_equal_approx(Game.money, 600.0 - pay) and is_equal_approx(float(Game.loan.paid), pay), "the next morning a payment comes out ($%.2f left)" % Game.money)
	Game.money = 30.0
	Game.start_next_day()  # day 5: only $30 of it
	check(is_equal_approx(float(Game.loan.paid), pay + 30.0) and is_equal_approx(Game.money, 0.0), "short of money: he takes what you have")
	check(is_equal_approx(Game.loan_behind(), pay - 30.0), "and you're behind by the rest ($%.2f)" % Game.loan_behind())
	var log_text := " ".join(Game.message_log.map(func(m): return m.text))
	check(log_text.contains("couldn't make Count Vlad's payment"), "a message says so")
	Game.money = 1000.0
	check(is_equal_approx(Game.pay_loan(Game.loan_behind()), pay - 30.0) and Game.loan_behind() == 0.0, "paying it in the Loans app catches you up")
	Game.pay_loan(pay)  # tomorrow's, early
	var before := Game.money
	Game.start_next_day()  # day 6: already paid
	check(is_equal_approx(Game.money, before), "paid early: nothing comes out the next morning")
	for d in range(7, 10):
		Game.start_next_day()
	check(Game.day == 9 and is_equal_approx(Game.loan_left(), 540.0 - pay * 6), "by day 9, six payments in ($%s left)" % Game.cash(Game.loan_left()))
	Game.money = 20.0
	Game.start_next_day()  # day 10: the last day, and not enough
	log_text = " ".join(Game.message_log.slice(-3).map(func(m): return m.text))
	check(Game.day == 10 and Game.loan_left() > 0.0 and log_text.contains("Tonight Count Vlad comes"), "the last morning: a warning")
	# The night: not enough money -> he comes (no day summary).
	defaulted = 0
	days_ended = 0
	Game.end_day()
	check(defaulted == 1 and days_ended == 0 and Game.loan_overdue(), "that night, still owing: he comes for your head (no summary)")
	# Saved during his visit and loaded: he's still there.
	var d := Game.to_dict()
	d.between_days = true
	Game.reset()
	Game.from_dict(d)
	check(is_equal_approx(Game.loan_left(), 540.0 - pay * 6 - 20.0) and int(Game.loan.due) == 10, "the loan is saved with the game")
	defaulted = 0
	Game.resume_day_over()
	check(defaulted == 1, "loading a save from that night: he's still coming")
	# The same night with the money: paid, and the day goes on.
	Game.reset()
	Game.from_dict(d)
	Game.money = 500.0
	defaulted = 0
	days_ended = 0
	Game.end_day()
	check(defaulted == 0 and days_ended == 1 and not Game.has_loan(), "with the money that night, he collects it and goes")
	Game.money = 5000.0
	check(Game.take_loan(1000.0) and is_equal_approx(Game.pay_loan(99999.0), Game.loan_total(1000.0)) and not Game.has_loan(), "pay it all off early, any time")
	check(Game.loan_problem(1000.0) == "", "and borrow again")
	var older := Game.to_dict()
	older.erase("loan")
	Game.reset()
	Game.from_dict(older)
	check(not Game.has_loan(), "older saves: no loan")


# ---------------------------------------------------------------- the store

func _start_store() -> void:
	Game.reset()
	Game.slot = -1
	get_tree().change_scene_to_file(Saves.GAME_SCENE)
	await _wait_for_store()
	Game.tutorial_hidden = true


func _wait_for_store() -> void:
	for i in 300:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.name == "Main" and is_instance_valid(Game.store) and Game.store.is_inside_tree() and is_instance_valid(Game.player):
			break
	await _frames(3)


func _hud() -> Node:
	return get_tree().current_scene.get_node("HUD")


func _app() -> void:
	var hud := _hud()
	var pc: Node = hud.computer
	Game.money = 200.0
	hud.open_computer()
	await _frames(2)
	check(pc.TAB_NAMES.size() == pc.desktop_icons.size() and pc.TAB_NAMES[4] == "Loans", "the computer has a Loans app")
	await _key(KEY_5)
	check(pc.is_app_open() and pc.tab == 4, "5 opens it")
	var borrow := _button(pc.body, "Borrow $")
	check(borrow != null and borrow.text == "Borrow $1,000", "it offers the most you can borrow: " + (borrow.text if borrow else "nothing"))
	var texts := _texts(pc.body)
	check(texts.any(func(t): return t.contains("Interest: 12%")) and texts.any(func(t): return t == "Store level 2"),
		"with the interest, and bigger loans for higher levels")
	await _press(_button(pc.body, "<"))
	borrow = _button(pc.body, "Borrow $")
	check(borrow.text == "Borrow $500" and _texts(pc.body).any(func(t): return t.contains("Interest: 8%")), "< borrows less (and the interest drops): " + borrow.text)
	await _press(borrow)
	check(Game.has_loan() and is_equal_approx(Game.money, 700.0), "Borrow: the money's yours")
	texts = _texts(pc.body)
	check(texts.any(func(t): return t.begins_with("You owe Count Vlad $540")), "the app shows what you owe")
	check(_texts(hud.status_panel).any(func(t): return t.begins_with("Owe $540")), "and so does the top bar: " + str(_texts(hud.status_panel).filter(func(t): return t.begins_with("Owe"))))
	var pay_all := _button(pc.body, "Pay it all")
	await _press(pay_all)
	check(not Game.has_loan() and is_equal_approx(Game.money, 700.0 - 540.0), "Pay it all: square again")
	check(_button(pc.body, "Borrow $") != null, "and you can borrow again")
	if shot_dir != "":
		await _press(_button(pc.body, "Borrow $"))
		await _frames(3)
		await _shot("loans_app")
		Game.pay_loan(99999.0)
		pc.show_tab(4)
		await _frames(3)
		await _shot("loans_offer")
	pc.close()
	await _frames(2)


func _paid_in_time() -> void:
	Game.money = 5000.0
	Game.take_loan(1000.0)
	Game.loan.due = Game.day
	defaulted = 0
	days_ended = 0
	_end_day()
	await _frames(5)
	check(defaulted == 0 and days_ended == 1 and not Game.has_loan() and not is_instance_valid(_hud().cutscene), "the last night with enough money: paid, no visit")
	_hud()._on_next_day()
	await _frames(3)


## The last night without the money: the whole visit (or skipped).
func _cutscene(skip: bool) -> void:
	var hud := _hud()
	Game.money = 2000.0
	Game.take_loan(1000.0)
	Game.loan.due = Game.day
	Game.loan.day = Game.day - Game.LOAN_DAYS
	Game.money = 10.0
	var p: Player = Game.player
	var head_cell := p.current_cell()
	if not skip:
		Game.fp.set_active(true)  # (he comes in the view from above, even in first person)
		await _frames(2)
	_end_day()
	await _frames(3)
	var c: Node = hud.cutscene
	if not skip:
		check(not Game.fp.active and Game.store.visible, "first person switches off for his visit")
	check(is_instance_valid(c) and not hud.visible and Game.cutscene, "%s: the cutscene starts and the HUD gets out of the way" % ("skipped" if skip else "watched"))
	if not is_instance_valid(c):
		return
	var start_pos := p.position
	await _key(KEY_D)  # (walking keys do nothing)
	check(p.position.distance_to(start_pos) < 1.0, "you can't walk away")
	if skip:
		await _frames(20)
		await _key(KEY_ESCAPE)
		await _until(func(): return c.card.visible, 4.0)
		check(c.card.visible and not get_tree().paused, "Esc skips to the end (and doesn't pause): " + c.step)
		await _shot("skipped")
	else:
		var seen := {}
		var shots := {}
		var t0 := Time.get_ticks_msec()
		var i := 0
		while Time.get_ticks_msec() - t0 < 90000:
			await get_tree().process_frame
			i += 1
			seen[c.step] = true
			if c.box.visible and c.line_label.visible_ratio >= 1.0 and i % 40 == 0:
				_advance()  # (move the talking along)
			if not shots.has(c.step) and c.step in ["arrive", "talk", "rip", "gloat"]:
				shots[c.step] = true
				if c.step == "rip" and shot_dir != "":
					var t_rip := Time.get_ticks_msec()
					for k in 6:
						await _until(func(): return Time.get_ticks_msec() - t_rip > [150, 300, 500, 750, 1100, 1600][k], 3.0)
						await _shot("cutscene_rip_%d" % k)
				else:
					await _frames(25)
					await _shot("cutscene_" + c.step)
			if c.card.visible:
				break
		check(["dark", "arrive", "walk", "talk", "rip", "gloat", "over"].all(func(s): return seen.has(s)), "it plays through: %s" % [seen.keys()])
		var count: Node = Game.store.world.get_node_or_null("CountVlad")
		check(not p.visible and is_instance_valid(c.body), "your head comes off")
		check(Game.store.spills.has(head_cell) or Game.store.spills.size() > 0, "(blood everywhere)")
		check(count == null or not is_instance_valid(count) or c.head.get_parent() == count, "he walks off with it")
		await _shot("game_over")
	check(c.card.visible and c.restart_button.visible, "GAME OVER, with a Start over button")
	await _key(KEY_ESCAPE)
	check(c.card.visible and not get_tree().paused, "(Esc doesn't get you out of it)")
	c.restart_button.pressed.emit()
	await _wait_for_store()
	check(Game.day == 1 and is_equal_approx(Game.money, Game.STARTING_MONEY) and not Game.has_loan() and Game.level == 1 and not Game.cutscene,
		"starting over: day 1, $%d, level 1, no loan" % int(Game.money))
	check(_hud().visible and _hud()._messages.any(func(m): return (m[0] as Label).text.begins_with("Count Vlad took your head")), "the HUD's back, with a message")


## Saved in a slot: the visit replaces the save with a fresh day 1.
func _saved_during_visit() -> void:
	Saves.new_game(SLOT)
	await _wait_for_store()
	Game.tutorial_hidden = true
	Game.money = 3000.0
	Game.add_xp(500.0)
	Game.take_loan(1000.0)
	Game.loan.due = Game.day
	Game.money = 0.0
	Saves.save_game()
	_end_day()
	await _frames(5)
	check(is_instance_valid(_hud().cutscene), "(in a save slot) he comes")
	Saves.save_game()  # closing the game mid-visit
	Saves.load_game(SLOT)
	await _wait_for_store()
	await _frames(5)
	check(is_instance_valid(_hud().cutscene) and Game.cutscene, "load that save: he's still there, no way out")
	var c: Node = _hud().cutscene
	c.skip()
	await _until(func(): return c.card.visible, 4.0)
	c.restart_button.pressed.emit()
	await _wait_for_store()
	var info := Saves.slot_info(SLOT)
	check(info.get("day", 0) == 1 and info.get("level", 0) == 1 and is_equal_approx(float(info.get("money", 0.0)), Game.STARTING_MONEY), "the slot starts over too: %s" % info)
	check(Game.slot == SLOT, "still playing in the same slot")


# ---------------------------------------------------------------- helpers

func _end_day() -> void:
	Game.opened = true
	Game.is_open = false
	Game.minute = Game.CLOSE_MINUTE
	for cu in Game.store.customers.duplicate():
		if is_instance_valid(cu):
			cu.queue_free()
	Game.store.customers.clear()
	Game.end_day()


func _advance() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE
	e.physical_keycode = KEY_SPACE
	e.pressed = true
	Input.parse_input_event(e)
	var up := e.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func _key(k: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = down
		Input.parse_input_event(e)
		await _frames(3)


func _press(b: Button) -> void:
	if b == null:
		check(false, "(no button)")
		return
	b.pressed.emit()
	await _frames(3)


func _button(from: Node, starts: String) -> Button:
	for b in from.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(starts) and not b.is_queued_for_deletion():
			return b
	return null


func _texts(from: Node) -> Array:
	return from.find_children("*", "Label", true, false).filter(func(l): return not l.is_queued_for_deletion() and l.is_visible_in_tree()).map(func(l): return l.text)


func _shot(name: String) -> void:
	if shot_dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))


## Waits until `cond` is true (or `seconds` pass).
func _until(cond: Callable, seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < seconds * 1000.0:
		await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
