extends Node
# Spying. Bone Mart's spies sneak into your store (from day 2), take notes
# at your shelves and get Bone Mart to undercut you, unless you (or your own
# Spy) throw them out. A Spy you hire sneaks over to Bone Mart and comes
# back with its prices, when its next spy is coming, and a rumor that keeps
# shoppers away from it.
#   godot --headless --path . --fixed-fps 60 res://tests/spy_test.tscn

var fails := 0
var said: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	seed(4242)
	Engine.max_fps = 0
	Engine.time_scale = 4.0
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	var store: Store = Game.store
	var town: Town = store.town
	var p: Player = Game.player
	var hud: Node = main.get_node("HUD")
	Game.tutorial_hidden = true
	Game.money = 2000.0
	Game.message.connect(func(t): said.append(t))
	var S0 := TestIds.starter(0)
	var S1 := TestIds.starter(1)
	for i in store.shelves.size():
		var s: Shelf = store.shelves[i]
		if not s.holds_cold():
			s.product_id = S0 if i % 2 == 0 else S1
			s.stock = 8
			s.queue_redraw()

	# ---- when they come
	check(Game.rival_spies.is_empty(), "no spies on day 1")
	Game.start_next_day()
	check(Game.rival_spies.size() == 1 and Game.rival_spies[0] >= 9 * 60 and Game.rival_spies[0] <= 18 * 60 + 30,
		"from day 2, Bone Mart plans a spy for today (at %s)" % [Game.time_text(Game.rival_spies[0]) if not Game.rival_spies.is_empty() else "--"])
	Game.xp = 500.0
	Game.level = Game.level_for(Game.xp)
	Game.roll_rival_spies()
	check(Game.rival_spies.size() == 2 and Game.rival_spies[1] - Game.rival_spies[0] >= 60,
		"from store level 3, two, spread out over the day (%s)" % [Game.rival_spies.map(func(m): return Game.time_text(m))])

	# ---- one that gets away
	Game.open_store()
	store.spawn_timer = 1e9  # no shoppers for now
	Game.rival_spies = []  # this test sends them itself
	for id in [S0, S1]:
		Game.prices[id] = Game.market_price(id)
		Game.rival_factor[id] = 1.05  # Bone Mart is pricier than you...
	said.clear()
	var spy := town.send_rival_spy()
	var box := [spy]  # (lambdas look at it through this, so it can go away)
	check(spy != null and spy in store.movers, "Bone Mart sends a spy over")
	check(await _until(func(): return spy.is_inside(), 40.0), "it sneaks into your store...")
	check(said.any(func(t): return t.contains("snuck in")), "...and you hear about it: " + (said[-1] if not said.is_empty() else ""))
	check(await _until(func(): return spy.wait > 0.0, 30.0), "it stops at a shelf to take notes")
	check(await _until(func(): return not is_instance_valid(box[0]), 90.0), "then it leaves")
	check(int(Game.stats.get("spies_escaped", 0)) == 1, "it got away")
	var cut := [S0, S1].filter(func(id): return Game.rival_price(id) < Game.prices[id])
	check(not cut.is_empty() and said.any(func(t): return t.contains("cut its prices")),
		"so Bone Mart undercuts you on what it saw: " + (said[-1] if not said.is_empty() else ""))
	check(cut.all(func(id): return Game.rival_price(id) >= Game.prices[id] * 0.85 and Game.rival_price(id) >= Game.market_price(id) * 0.49),
		"(by a little: %s)" % [cut.map(func(id): return "%.2f vs %.2f" % [Game.rival_price(id), Game.prices[id]])])
	check(cut.all(func(id): return Game.rival_seen.has(id) and Game.rival_seen[id][1] == Game.day), "and its new prices go in your notes on Bone Mart")

	# ---- one you catch
	var factors := Game.rival_factor.duplicate()
	var xp := Game.xp
	spy = town.send_rival_spy()
	box[0] = spy
	await _until(func(): return spy.is_inside() and spy.wait > 0.0, 60.0)
	var next_to := store.stand_cell_for(spy.cell, spy.cell)
	p.position = Iso.cell_to_world(next_to)
	await _frames(2)
	check(p.focused == spy and spy.get_prompt(p).contains("spy"), "walk up to it and E throws it out: " + spy.get_prompt(p))
	p.try_interact()
	await _frames(2)
	check(spy.state == RivalSpy.State.CAUGHT and int(Game.stats.get("spies_caught", 0)) == 1, "caught it!")
	check(Game.xp >= xp + float(Brand.RIVAL.spy_caught_xp) - 0.01, "(+%d XP)" % roundi(Game.xp - xp))
	check(await _until(func(): return not is_instance_valid(box[0]), 60.0), "it runs off")
	check(Game.rival_factor == factors, "and Bone Mart didn't learn a thing")

	# ---- clicking or tapping it, closing time
	spy = town.send_rival_spy()
	box[0] = spy
	await _until(func(): return spy.is_inside(), 60.0)
	check(store.interactable_at_point(spy.position + Vector2(0, -18)) == spy, "you can click or tap it too")
	Game.is_open = false
	Game.opened = false  # (so the day doesn't end)
	await _frames(3)
	check(spy.state == RivalSpy.State.OUT, "when the store closes, it heads back with what it's got")
	Game.is_open = true
	Game.opened = true
	await _until(func(): return not is_instance_valid(box[0]), 60.0)

	# ---- on time
	Game.rival_spies = [int(Game.minute) - 1]
	await _frames(2)
	check(Game.rival_spies.is_empty() and store.movers.size() == 1, "when it's time, Bone Mart sends one by itself")
	for m in store.movers:
		m.caught()
	await _until(func(): return store.movers.is_empty(), 60.0)

	# ---- your own spy
	Game.rival_seen = {}
	Game.effects.erase("rumor")
	Game.rival_spies = [16 * 60]
	check(Game.hire_problem("spy") == "", "you can hire a spy")
	var entry := Game.hire("spy")
	await _frames(2)
	var agent: Staff = store.staff.filter(func(s): return s.role == "spy")[0]
	check(await _until(func(): return agent.job == Staff.Job.SNOOPING and town.rival_floor.has(agent.current_cell()), 60.0),
		"they sneak into Bone Mart and snoop around")
	var pull := Game.rival_pull([], {})
	said.clear()
	check(await _until(func(): return int(Game.stats.get("spy_reports", 0)) == 1, 90.0), "then come back and report at the computer")
	check(Game.rival_seen.size() == Game.PRODUCTS.size() and Game.rival_seen.values().all(func(v): return v[1] == Game.day),
		"with every one of Bone Mart's prices (%d)" % Game.rival_seen.size())
	if not Game.has_effect("rumor"):
		Game.effects["rumor"] = 1.0  # (so the rest of the test can go on)
	check(Game.has_effect("rumor") and is_equal_approx(Game.rival_pull([], {}), pull - Game.RUMOR_PULL),
		"and a rumor that sends fewer shoppers there (%.2f -> %.2f)" % [pull, Game.rival_pull([], {})])
	var news: String = said.filter(func(t): return t.contains("is back from"))[0] if said.any(func(t): return t.contains("is back from")) else ""
	check(news.contains("deal of the day") and news.contains("4:00 PM"), "the news: " + news)
	check(Game.staff_entry(entry.id).xp > 0.0, "the report earns them XP")
	await _frames(2)
	check(hud._effect_rows.has("rumor") and hud._effect_rows.rumor.text.begins_with("Rumor about"), "the rumor shows under the corner buttons")
	Game.is_open = false
	Game.opened = false
	var left: float = Game.effects.rumor
	await _seconds(0.5)
	check(is_equal_approx(Game.effects.rumor, left), "it only wears off while you're open")
	Game.is_open = true
	Game.opened = true
	check(await _until(func(): return agent.job == Staff.Job.IDLE and agent.path.is_empty(), 30.0) and agent.status_text().contains("Keeping watch"),
		"between trips: " + agent.status_text())
	check(not agent._trip_due(), "they don't go straight back")
	Game.minute += Game.SPY_EVERY_MINUTES
	check(agent._trip_due(), "but %d game minutes later they do" % Game.SPY_EVERY_MINUTES)
	Game.minute -= Game.SPY_EVERY_MINUTES

	# ---- your spy throws theirs out
	said.clear()
	var caught_before := int(Game.stats.get("spies_caught", 0))
	spy = town.send_rival_spy()
	box[0] = spy
	check(await _until(func(): return not is_instance_valid(box[0]) or box[0].state == RivalSpy.State.CAUGHT, 90.0)
		and int(Game.stats.get("spies_caught", 0)) == caught_before + 1, "your spy throws Bone Mart's out")
	check(said.any(func(t): return t.contains(agent.staff_name + " threw")), "and you hear who did")

	# ---- saving
	Game.rival_spies = [700, 900]
	var d: Dictionary = JSON.parse_string(JSON.stringify(Game.to_dict()))  # as a save file has it
	check(d.rival.spies == [700.0, 900.0], "today's spy plan is saved")
	Game.rival_spies = []
	Game.staff.clear()  # (from_dict fills the roster in again)
	Game.from_dict(d)
	check(Game.rival_spies == [700, 900], "and loaded")
	d.rival.erase("spies")
	d.minute = 12.0 * 60.0
	Game.staff.clear()
	Game.from_dict(d)
	check(Game.rival_spies.all(func(m): return m > 12 * 60), "an older save gets a plan for the rest of the day")

	check(hud._spies_line({"spies_caught": 1, "spies_escaped": 2}) == "%s's spies: 1 thrown out, 2 got away" % Brand.RIVAL.name, "the day summary says how it went")

	# ---- once Bone Mart is yours
	Game.rival_owned = true
	check(Game.hire_problem("spy").contains("nobody"), "no hiring spies once Bone Mart is yours: " + Game.hire_problem("spy"))
	Game.roll_rival_spies()
	check(Game.rival_spies.is_empty() and town.send_rival_spy() == null, "and it sends no more")
	check(agent.status_text().contains("nothing to spy on"), "your spy: " + agent.status_text())
	Game.rival_owned = false

	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


## Waits until `cond` is true (up to `seconds` of game time). True if it got there.
func _until(cond: Callable, seconds: float) -> bool:
	var t := 0.0
	while t < seconds:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return cond.call()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(t: float) -> void:
	await get_tree().create_timer(t).timeout
