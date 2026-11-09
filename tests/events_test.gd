extends Node
# The week (0.19): the calendar, weather and the day's events.
#  calendar   weekdays (day 1 a Moanday, the weekend busiest), the week
#             ahead picked once and saved, events settled 3 days ahead
#             (re-picked further off as the store grows), full moons every
#             7th day, no events on days 1-2, the morning message
#  weather    rain (fewer shoppers, more blood), fog (ghosts, spies), heat
#             (cold products), the tint and the rain/fog on screen
#  events     at their time once open: the tour bus and its tourists, the
#             inspector (points, grades A/B/C and what they do, the walk
#             round), the power cut (dead registers and computer, dark
#             store, the fuse box fixed at the computer, or after 2 hours),
#             the ghost (steals, caught: gives it back; escapes: gone), the
#             celebrity (viral or roasted tomorrow, the ZomTok post), the
#             full moon (werewolves early, more night owls)
#  goals, trophies, the HUD's icons, the Calendar app (and keys 8/9/0),
#  saving
#   godot --headless --path . --fixed-fps 60 res://tests/events_test.tscn

var fails := 0
var hud: Node
var store: Store
var p: Player


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	seed(1919)
	Engine.max_fps = 0
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	hud = main.get_node("HUD")
	store = Game.store
	p = Game.player
	Game.tutorial_hidden = true
	hud.tutorial._hide_all()
	Game.money = 5000.0
	_calendar()
	_weather()
	await _weather_fx()
	Game.add_xp(Game.xp_for_level(8) - Game.xp)
	await _frames(2)
	hud.levelup_panel.visible = false
	Game.open_store()
	await _frames(2)
	await _bus()
	await _inspector()
	await _power()
	await _ghost()
	await _celebrity()
	_moon()
	await _on_time()
	_goals_and_trophies()
	await _hud()
	await _pc()
	_saving()
	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


func _set_today(weather: String, event := "", minute := 0) -> void:
	Game.calendar.days[Game.day] = {"weather": weather, "event": event, "minute": minute}


# ---------------------------------------------------------------- the calendar

func _calendar() -> void:
	var cal := Game.calendar
	check(Calendar.weekday(1) == "Moanday" and Calendar.weekday(7) == "Sundead" and Calendar.weekday(8) == "Moanday", "day 1 is a Moanday, day 7 a Sundead, then round again")
	check(Calendar.weekday_traffic(6) > Calendar.weekday_traffic(3) and Calendar.weekday_traffic(1) < 1.0, "the weekend's busy, Moanday quiet")
	check(cal.days.size() == Calendar.AHEAD and cal.days.has(1) and cal.days.has(7), "a week on the calendar from day 1")
	check(cal.event(1) == "" and cal.event(2) == "" and cal.weather(1) == "clear", "the first two days are calm (and day 1 is clear)")
	check(cal.event(7) == "moon" and Calendar.is_moon_day(14) and not Calendar.is_moon_day(13), "a full moon every 7th day")
	var other := Calendar.new()
	other.seed = cal.seed
	var same := true
	for d in range(3, 7):
		if other.day_info(d).weather != cal.day_info(d).weather:
			same = false
	check(same, "the same game gets the same week")
	# events settle 3 days ahead; further off they can change as the store grows
	var lv := Game.level
	Game.level = 12
	var counts := {}
	var seen_far := 0
	for d in range(20, 60):
		var picked := cal._pick(d)
		if picked.event != "":
			counts[picked.event] = int(counts.get(picked.event, 0)) + 1
			if picked.event != "moon" and (int(picked.minute) < 600 or int(picked.minute) > 960 or int(picked.minute) % 15 != 0):
				seen_far += 1
	check(counts.size() >= 5, "every kind of event turns up: %s" % [counts])
	check(seen_far == 0, "events start between 10 AM and 4 PM, on the quarter hour")
	Game.level = 1
	var low := 0
	for d in range(20, 60):
		var e: String = cal._pick(d).event
		if e != "" and e != "moon":
			low += 1
	check(low == 0, "a level 1 store gets no events (but the full moon)")
	Game.level = lv
	var firm_before: Dictionary = cal.day_info(3).duplicate()
	Game.level = 12
	cal.fill_week(true)
	check(cal.day_info(3).event == firm_before.event, "a settled day doesn't change when the store levels up")
	check(not Calendar.is_firm(Game.day + 5) and Calendar.is_firm(Game.day + 2) and Calendar.is_firm(7), "3 days are settled (and full moons always)")
	Game.level = lv
	# a new morning
	Game.day = 3
	cal.morning()
	check(not cal.days.has(1) and cal.days.has(9) and cal.days.size() == Calendar.AHEAD, "the next morning: yesterday's gone, a new day on the end")
	_set_today("rain", "inspector", 14 * 60 + 15)
	var text := cal.morning_text()
	check(text.contains("Rain") and text.contains("inspector") and text.contains("2:15 PM"), "the morning says what's coming: " + text)
	check(Calendar.day_name(10) == "Wednesdead, day 10", "Wednesdead, day 10")


# ---------------------------------------------------------------- weather

func _weather() -> void:
	var cal := Game.calendar
	_set_today("clear")
	var clear := cal.traffic_factor()
	_set_today("rain")
	check(cal.traffic_factor() < clear * 0.9, "rain: fewer shoppers (%.2f vs %.2f)" % [cal.traffic_factor(), clear])
	var wet := 0
	for i in 60:
		var c := store.spawn_customer(Brand.SHOPPERS.zombie)
		if c.leaky:
			wet += 1
		store.customers.erase(c)
		c.free()
	check(wet > 60 * 0.35 * 1.2, "rain: more shoppers drip blood (%d of 60)" % wet)
	_set_today("fog")
	var ghost: Dictionary = Brand.SHOPPERS.ghost
	var foggy := Game.shopper_weight(ghost)
	_set_today("clear")
	check(foggy > Game.shopper_weight(ghost) * 2.5, "fog: three times the ghosts")
	_set_today("fog")
	Game.roll_rival_spies()
	var fog_spies := Game.rival_spies.size()
	_set_today("clear")
	Game.roll_rival_spies()
	check(fog_spies >= Game.rival_spies.size() * 2 or Game.rival_spies.is_empty(), "fog: twice the spies (%d vs %d)" % [fog_spies, Game.rival_spies.size()])
	var cold := ""
	var warm := ""
	for id: String in Game.unlocked_ids():
		if Game.is_cold(id) and cold == "":
			cold = id
		elif not Game.is_cold(id) and warm == "":
			warm = id
	if cold == "":
		for id: String in Game.PRODUCTS:
			if Game.is_cold(id):
				Game.licensed[id] = true
				cold = id
				break
	var picks := func() -> int:
		var n := 0
		for i in 600:
			if store._weighted_pick([cold, warm]) == cold:
				n += 1
		return n
	_set_today("clear")
	var plain: int = picks.call()
	_set_today("heat")
	var hot: int = picks.call()
	check(hot > plain * 1.3, "a heat wave: cold products wanted more (%d vs %d of 600)" % [hot, plain])
	_set_today("rain")
	var lights: StoreLights = store.get_node("Lights")
	lights._process(0.0)
	var rainy := store.mood.color
	_set_today("clear")
	lights._process(0.0)
	check(rainy.b / maxf(rainy.r, 0.01) > store.mood.color.b / maxf(store.mood.color.r, 0.01), "rain tints the light blue-grey")


func _weather_fx() -> void:
	var fx: WeatherFx = null
	for n in store.get_children():
		if n is WeatherFx:
			fx = n
	check(fx != null, "the weather's drawn over the store")
	_set_today("rain")
	await _frames(3)
	check(fx.visible and fx._drops.size() > 0, "rain falls on screen (%d drops)" % fx._drops.size())
	_set_today("fog")
	await _frames(3)
	check(fx.visible and fx._fog != null and fx._drops.is_empty(), "fog drifts instead")
	_set_today("clear")
	await _frames(2)
	check(not fx.visible, "nothing on a clear day")


# ---------------------------------------------------------------- the bus

func _bus() -> void:
	var before := int(Game.stats.get("tourists", 0))
	var shoppers := store.customers.size()
	var bus := store.events.send_bus()
	check(bus != null and bus.state == TourBus.State.ARRIVING, "the tour bus drives in")
	var stopped := false
	var most := 0  # tourists in the store at once
	for i in 2400:  # (up to 11 tourists, then the length of the road)
		await get_tree().process_frame
		if is_instance_valid(bus) and bus.state == TourBus.State.UNLOADING:
			stopped = true
		most = maxi(most, store.customers.filter(func(c): return c.kind == Brand.EVENT_SHOPPERS.tourist).size())
		if not is_instance_valid(bus):
			break
	check(stopped, "it stops outside the store")
	var came := int(Game.stats.get("tourists", 0)) - before
	check(came >= DayEvents.TOURISTS[0] and came <= DayEvents.TOURISTS[1], "and %d tourists get off" % came)
	check(not is_instance_valid(bus), "then it drives off")
	check(most >= 3, "the tourists head for the store (%d at once)" % most)
	var lists := []
	for i in 20:
		lists.append(store._make_shopping_list(Brand.EVENT_SHOPPERS.tourist).size())
	check(lists.min() >= mini(3, Game.unlocked_ids().size()), "with long shopping lists (%s)" % [lists.slice(0, 8)])
	var tourists := store.customers.filter(func(c): return c.kind == Brand.EVENT_SHOPPERS.tourist)
	for c in tourists:
		store.customer_left(c)
		c.queue_free()
	await _frames(2)


# ---------------------------------------------------------------- the inspector

func _inspector() -> void:
	var ev := store.events
	for c: Vector2i in store.spills.keys():
		store.spills[c].queue_free()
	store.spills.clear()
	for s: Shelf in store.shelves:
		if s.stock <= 0:
			s.product_id = Game.unlocked_ids()[0] if not s.holds_cold() else s.product_id
			if s.product_id != "":
				s.add_stock(s.product_id, 4)
	var clean: Array = ev.inspection()
	check(int(clean[0]) >= DayEvents.GRADE_A, "a clean, full store: %d points" % clean[0])
	var money := Game.money
	check(ev.grade() == "A" and Game.money > money and is_equal_approx(Game.calendar.boost, DayEvents.BOOST_A), "grade A: paid, and more shoppers today")
	check(Game.calendar.outcome.contains("A"), "the summary says so: " + Game.calendar.outcome)
	var shelf: Shelf = store.shelves[0]
	var kept := shelf.stock
	shelf.stock = 0
	for i in 3:
		store.add_spill(_free_floor(), -1, false)
	var dirty: Array = ev.inspection()
	check(int(dirty[0]) < int(clean[0]) - 30 and str(dirty[1]).contains("empty") and str(dirty[1]).contains("blood"), "blood and an empty shelf cost points (%d: %s)" % [dirty[0], dirty[1]])
	for s: Shelf in store.shelves:
		s.stock = 0
	money = Game.money
	var g := ev.grade()
	check(g == "C" and Game.money < money and is_equal_approx(Game.calendar.boost, DayEvents.BOOST_C), "empty shelves everywhere: a C, a fine, fewer shoppers (%s)" % g)
	for s: Shelf in store.shelves:
		if s.product_id != "":
			s.stock = 6
	shelf.stock = maxi(kept, 4)
	Game.calendar.boost = 1.0
	Game.stats.erase("inspection")
	# the real thing: walks in, looks round, grades on the way out
	var who := ev.send_inspector()
	check(who is Inspector and who in store.movers and not who.can_interact(p), "the inspector walks over (and can't be thrown out)")
	var inside := false
	for i in 6000:
		await get_tree().process_frame
		if is_instance_valid(who) and who.is_inside():
			inside = true
		if Game.stats.has("inspection"):
			break
	check(inside, "comes in")
	check(Game.stats.has("inspection"), "and grades the store: %s" % Game.stats.get("inspection", "nothing"))
	for i in 1500:
		await get_tree().process_frame
		if not is_instance_valid(who):
			break
	check(not is_instance_valid(who), "then leaves")
	Game.calendar.boost = 1.0


func _free_floor() -> Vector2i:
	for c: Vector2i in store.floor_cells:
		if store.is_walkable(c) and not store.spills.has(c) and not c in store.delivery_cells and not store.astar.is_point_solid(c) and Iso.chebyshev(c, store.door_cell) > 2:
			return c
	return Store.NO_CELL


# ---------------------------------------------------------------- the power cut

func _power() -> void:
	var ev := store.events
	var reg: Register = store.registers[0]
	var shopper := store.spawn_customer(Brand.SHOPPERS.zombie)
	shopper.set_process(false)
	shopper.set_physics_process(false)
	reg.line.insert(0, shopper)
	var ready_before := reg.front_customer()
	ev.power_cut()
	await _frames(2)
	check(Game.calendar.power_out, "the power goes out")
	check(reg.front_customer() == null and not reg.can_interact(p) and reg.get_prompt(p).contains("fuse box"), "the registers are dead (and say why)")
	var lights: StoreLights = store.get_node("Lights")
	check(lights.lights.all(func(l): return not l.enabled) or lights.lights.is_empty(), "the lights go out")
	hud.open_computer()
	await _frames(2)
	check(not hud.computer.visible, "the computer's dead too")
	var pc: Computer = null
	for o in store.objects.values():
		if o is Computer:
			pc = o
	check(pc != null and pc.get_prompt(p).contains("fuse box") and pc.get_action_time(p) > 0.0, "the computer's corner: fix the fuse box")
	p.position = Iso.cell_to_world(store.stand_cell_for(pc.cell, p.current_cell()))
	await _frames(2)
	p.use(pc)
	for i in 400:
		await get_tree().process_frame
		if not Game.calendar.power_out:
			break
	check(not Game.calendar.power_out and int(Game.stats.get("fuses_fixed", 0)) == 1, "holding E there fixes it")
	await _frames(2)
	check(lights.lights.all(func(l): return l.enabled == Settings.lights_enabled()), "the lights come back")
	check(reg.front_customer() == ready_before or ready_before == null, "and the register works again")
	reg.line.erase(shopper)
	store.customer_left(shopper)
	shopper.queue_free()
	ev.power_cut()
	ev._power_off_at = Game.minute - DayEvents.POWER_BACK_AFTER - 1.0
	await _frames(2)
	check(not Game.calendar.power_out, "left alone, the power company fixes it after 2 hours")


# ---------------------------------------------------------------- the ghost

func _ghost() -> void:
	var ev := store.events
	for s: Shelf in store.shelves:
		if s.product_id != "":
			s.stock = maxi(s.stock, 6)
	var ghost := ev.send_ghost()
	check(ghost is GhostThief and ghost.floats, "a ghost floats over")
	for i in 6000:
		await get_tree().process_frame
		if ghost.loot_count() > 0:
			break
	var took := ghost.loot_count()
	var robbed: Shelf = ghost.loot[0].shelf if took > 0 else null
	var robbed_had := robbed.stock if robbed else 0
	check(took > 0 and robbed != null, "it takes %d items off a shelf" % took)
	check(ghost.can_interact(p) and ghost.get_prompt(p).begins_with("Boo"), "you can boo it away")
	var money := Game.money
	ghost.catch()
	check(ghost.loot_count() == 0 and robbed.stock >= mini(Shelf.CAPACITY, robbed_had + took) - 0 and Game.money > money and int(Game.stats.get("ghosts_caught", 0)) == 1, "caught: it puts it back (%d -> %d) and you get a reward" % [robbed_had, robbed.stock])
	for i in 1200:
		await get_tree().process_frame
		if not is_instance_valid(ghost):
			break
	check(not is_instance_valid(ghost), "and flees")
	# one that gets away
	var stolen := GhostThief.stolen
	var g2 := ev.send_ghost()
	for i in 6000:
		await get_tree().process_frame
		if g2.loot_count() > 0 and g2.leaving:
			break
	var had := g2.loot_count()
	g2.position = Iso.cell_to_world(g2.home)
	g2.path.clear()
	g2.leaving = true
	g2._fading = true
	for i in 200:
		await get_tree().process_frame
		if not is_instance_valid(g2):
			break
	check(had > 0 and GhostThief.stolen == stolen + had, "one that gets away keeps what it took (%d)" % had)


# ---------------------------------------------------------------- the celebrity

func _celebrity() -> void:
	var ev := store.events
	for sp in store.spills.values().duplicate():  # (a clean floor: the blood would cost a star)
		store.remove_spill(sp)
	var c := ev.send_celebrity()
	check(c.kind == Brand.EVENT_SHOPPERS.celebrity and c._emote == "star", "the celebrity walks in, starry")
	await _frames(1)
	var id: String = Game.unlocked_ids()[0]
	c.basket = []
	for i in 4:
		c.basket.append({"id": id, "price": Game.market_price(id)})
	c._missed = 0
	c._waited = 0.0
	c.rate_visit()
	var tomorrow := Game.day + 1
	check(is_equal_approx(float(Game.calendar.buzz.get(tomorrow, 1.0)), Calendar.VIRAL) and int(Game.calendar.post.day) == tomorrow, "a great visit: viral, more shoppers tomorrow")
	check(int(Game.stats.get("viral", 0)) == 1, "a 5-star post counts")
	var v := ZomTokFeed.video(tomorrow, 0)
	check(v.handle == "@" + Brand.EVENT_SHOPPERS.celebrity.handle and int(v.likes) >= 1000000 and str(v.caption).contains("stars"), "tomorrow's ZomTok opens with their post: \"%s\" (%d likes)" % [v.caption, v.likes])
	check(ZomTokFeed.video(tomorrow, 1).handle != v.handle, "just the one")
	store.customer_left(c)
	c.queue_free()
	var bad := ev.send_celebrity()
	await _frames(1)
	bad.rate_visit("walkout")
	check(is_equal_approx(float(Game.calendar.buzz.get(tomorrow, 1.0)), Calendar.ROASTED) and str(ZomTokFeed.video(tomorrow, 0).caption).contains("never again"), "walking out on them: roasted, fewer shoppers tomorrow")
	store.customer_left(bad)
	bad.queue_free()
	Game.calendar.buzz.clear()
	Game.calendar.post = {}


# ---------------------------------------------------------------- the full moon

func _moon() -> void:
	var lv := Game.level
	Game.level = 6
	_set_today("clear", "moon", Game.NIGHT_MINUTE)
	var was := Game.minute
	Game.minute = Game.NIGHT_MINUTE + 30
	var vamp: Dictionary = Brand.SHOPPERS.vampire
	var full := Game.shopper_weight(vamp)
	var wolves := 0
	for i in 400:
		if Game.pick_shopper_kind() == Brand.SHOPPERS.werewolf:
			wolves += 1
	_set_today("clear")
	check(full > Game.shopper_weight(vamp) * 2.0, "a full moon night: more vampires")
	var none := 0
	for i in 400:
		if Game.pick_shopper_kind() == Brand.SHOPPERS.werewolf:
			none += 1
	check(wolves > 0 and none == 0, "and werewolves at level 6 (%d), not on other nights" % wolves)
	Game.minute = was
	Game.level = lv


# ---------------------------------------------------------------- on time

func _on_time() -> void:
	var cal := Game.calendar
	cal.started = 0
	_set_today("clear", "inspector", int(Game.minute) + 30)
	await _frames(2)
	check(cal.started != Game.day, "not before its time")
	_set_today("clear", "inspector", int(Game.minute) - 1)
	var heard: Array = []
	var listen := func(e): heard.append(e)
	Game.event_started.connect(listen)
	await _frames(2)
	Game.event_started.disconnect(listen)
	check(cal.started == Game.day and heard == ["inspector"], "the event starts at its time")
	await _frames(2)
	check(heard.size() == 1, "once")
	for m in store.movers.duplicate():
		if m is Visitor:
			store.movers.erase(m)
			m.queue_free()
	_set_today("clear")


# ---------------------------------------------------------------- goals and trophies

func _goals_and_trophies() -> void:
	var g := Game.goals
	_set_today("clear", "inspector", 14 * 60)
	check(g.can_pick("inspection") and not g.can_pick("catch_ghost"), "the inspector's day can have a goal to pass the inspection")
	var goal := {"type": "inspection", "target": 1, "product": "", "kind": "", "cash": 10.0, "xp": 5.0, "done": false}
	Game.stats.inspection = "B"
	check(is_equal_approx(Goals.progress(goal), 1.0) and Goals.text(goal).contains("inspection"), "a B passes")
	_set_today("clear", "ghost", 14 * 60)
	check(g.can_pick("catch_ghost") and not g.can_pick("inspection"), "a ghost day: catch it")
	_set_today("clear")
	check(not Trophies.find("clean_bill").is_empty() and not Trophies.find("ghostbuster").is_empty() and not Trophies.find("viral").is_empty(), "trophies for the events")
	Game.stats.inspections_a = 1
	Game.trophies.check()
	check(Game.trophies.is_earned("clean_bill"), "an A earns Clean Bill of Health")


# ---------------------------------------------------------------- the HUD

func _hud() -> void:
	Game.calendar.started = 0
	_set_today("rain", "ghost", 15 * 60)
	await _frames(2)
	check(hud.clock_label.text.begins_with(Calendar.day_name(Game.day)), "the clock says the day of the week: " + hud.clock_label.text)
	check(hud.weather_icon.texture == Brand.CALENDAR.weather.rain.icon and hud.weather_icon.tooltip_text.begins_with("Rain"), "and the weather: " + hud.weather_icon.tooltip_text)
	check(hud.event_icon.visible and hud.event_icon.texture == Brand.CALENDAR.events.ghost.icon and hud.event_icon.tooltip_text.contains("3:00 PM"), "and today's event: " + hud.event_icon.tooltip_text)
	_set_today("clear")
	await _frames(2)
	check(not hud.event_icon.visible, "no event, no icon")
	var s := Game.stats.duplicate(true)
	s.day = Game.day
	s.profit = Game.profit_today()
	s.goals = {}
	s.rating = Game.rating.stars()
	s.event = "A ghost came shoplifting."
	hud._show_summary(s)
	await _frames(2)
	check(hud.summary_notes.text.contains("A ghost came shoplifting."), "the day's summary says how today's event went")
	hud.summary_panel.visible = false
	await _frames(1)


# ---------------------------------------------------------------- the PC

func _pc() -> void:
	var pc: Node = hud.computer
	check(pc.TAB_NAMES.size() == 10 and pc.TAB_NAMES[7] == "Calendar", "the computer has a Calendar app")
	hud.open_computer()
	await _frames(2)
	pc.show_tab(pc.Tab.CALENDAR)
	await _frames(2)
	var rows: Array = pc._body_buttons().filter(func(b): return b is Button and b.flat)
	var first := rows.find(rows.filter(func(b): return b.text.contains("(today)"))[0]) if rows.any(func(b): return b.text.contains("(today)")) else -1
	check(first >= 0 and rows.size() >= first + Calendar.AHEAD and rows[first + 1].text.contains("(tomorrow)"), "the week ahead, today first: " + (rows[first].text if first >= 0 else "?"))
	check(rows.slice(first, first + Calendar.AHEAD).any(func(b): return b.text.contains("   ?")), "days too far off show a ?")
	check(rows.any(func(b): return b.text.begins_with("Health inspector:")), "and what each event does")
	_key(KEY_8)
	await _frames(2)
	check(pc.tab == pc.Tab.CALENDAR, "8 opens it")
	_key(KEY_0)
	await _frames(2)
	check(pc.tab == pc.Tab.ZOMTOK, "0 opens the tenth app (ZomTok)")
	pc.close()
	await _frames(2)


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	get_viewport().push_input(e, true)
	var up := e.duplicate()
	up.pressed = false
	get_viewport().push_input(up, true)


# ---------------------------------------------------------------- saving

func _saving() -> void:
	var cal := Game.calendar
	_set_today("fog", "outage", 13 * 60)
	cal.power_out = true
	cal.buzz[Game.day + 1] = Calendar.VIRAL
	cal.post = {"day": Game.day + 1, "stars": 5}
	cal.outcome = "The power went out."
	var seed_was := cal.seed
	var d: Dictionary = JSON.parse_string(JSON.stringify(Game.to_dict()))
	Game.calendar = Calendar.new()
	Game.from_dict(d)
	var back := Game.calendar
	check(back.seed == seed_was and back.weather() == "fog" and back.event() == "outage" and back.event_minute() == 13 * 60, "the week comes back")
	check(back.power_out and is_equal_approx(float(back.buzz.get(Game.day + 1, 1.0)), Calendar.VIRAL) and int(back.post.day) == Game.day + 1 and back.outcome != "", "a power cut, tomorrow's buzz and the post too")
	back.power_out = false
	var old := d.duplicate(true)
	old.erase("calendar")
	Game.calendar = Calendar.new()
	Game.from_dict(old)
	check(Game.calendar.days.size() == Calendar.AHEAD and not Game.calendar.power_out, "an older save gets a fresh week")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
