extends Node
# Goals, the store's rating and trophies (0.18):
#  goals      none on day 1, three from day 2 (at most one closing-time and
#             one "fun" goal, the same ones if rolled again), progress,
#             paid the moment they're done (cash, XP, a message), the
#             closing-time ones at closing, a Perfect Day's bonus and the
#             streak (and what ends it), bigger numbers after a busy day
#  rating     3 stars to start, the average of the last 40 shoppers, half
#             stars, more shoppers above 3 and fewer below, reviews (always
#             for 1 and 5 stars), today's reasons; a shopper scores their
#             visit (finding nothing, waiting, prices, blood on the floor)
#  trophies   earned from the whole game's totals plus today's, paid once,
#             trophy decorations locked until then (and their bonus counts
#             once), the toast
#  looks      walking frames (a leg lifted, the shadow left alone, none for
#             ghosts), emotes over shoppers, the new zombie looks
#  the HUD    the goals list (folds), the stars, the summary's lines
#  the PC     the Goals app: Today, Rating and Trophies
#  saving     goals, rating, trophies and career totals come back
#   godot --headless --path . --fixed-fps 60 res://tests/goals_test.tscn

var fails := 0
var hud: Node
var store: Store


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	seed(1818)
	Engine.max_fps = 0
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	hud = main.get_node("HUD")
	store = Game.store
	Game.tutorial_hidden = true
	hud.tutorial._hide_all()
	Game.money = 5000.0
	hud.levelup_panel.visible = false
	await _goals()
	_rating()
	await _scoring()
	await _trophies()
	_looks()
	await _hud()
	await _pc()
	_saving()
	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- goals

func _goals() -> void:
	var g := Game.goals
	check(Game.day == 1 and g.list.is_empty() and not GoalsPanel.has_goals(), "no goals on day 1 (the tips teach the ropes)")
	Game.add_xp(1200.0)  # store level 4 or so: more kinds of goal
	await _frames(1)
	hud.levelup_panel.visible = false
	Game.day = 2
	g.roll()
	check(g.list.size() == Goals.COUNT and g.day == 2, "three goals on day 2 (%s)" % [g.list.map(func(x): return x.type)])
	var closes := g.list.filter(func(x): return Goals.TYPES[x.type].get("close", false)).size()
	var funs := g.list.filter(func(x): return Goals.TYPES[x.type].get("fun", false)).size()
	check(closes <= 1 and funs <= 1, "at most one closing-time goal and one fun one")
	var types: Array = g.list.map(func(x): return x.type)
	var unique := {}
	for t in types:
		unique[t] = true
	check(unique.size() == types.size(), "three different goals")
	check(g.list.all(func(x): return Goals.text(x) != "" and not Goals.text(x).contains("%") and float(x.cash) > 0.0 and float(x.xp) > 0.0), "each says what to do and pays: " + " / ".join(g.list.map(func(x): return Goals.text(x))))
	var first: Array = g.list.duplicate(true)
	g.roll()
	check(g.list == first, "rolling again the same day changes nothing")
	# every kind of goal can be made and read
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var bad: Array[String] = []
	for t: String in Goals.TYPES:
		if t == "kind" and g._kinds().is_empty():
			continue
		var made := g._make(t, rng)
		var text := Goals.text(made)
		if text == "" or text.contains("%") or Goals.progress(made) < 0.0 or float(made.target) <= 0.0:
			bad.append(t)
	check(bad.is_empty(), "every kind of goal makes sense (%s)" % [bad])

	# progress and pay
	var money := Game.money
	var xp := Game.xp
	var said: Array[String] = []
	var listen := func(t: String): said.append(t)
	Game.message.connect(listen)
	var heard: Array = []
	var on_done := func(x): heard.append(x)
	Game.goal_done.connect(on_done)
	g.list = [
		{"type": "serve", "target": 3, "product": "", "kind": "", "cash": 50.0, "xp": 20.0, "done": false},
		{"type": "mop", "target": 2, "product": "", "kind": "", "cash": 30.0, "xp": 10.0, "done": false},
		{"type": "no_walkouts", "target": 1, "product": "", "kind": "", "cash": 40.0, "xp": 15.0, "done": false},
	]
	Game.stats.customers = 2
	g.check()
	check(not g.list[0].done and Goals.progress_text(g.list[0]) == "2/3", "2 of 3 served: not yet (%s)" % Goals.progress_text(g.list[0]))
	Game.stats.customers = 3
	await _frames(40)  # (Game checks them twice a second)
	check(g.list[0].done and Game.money >= money + 50.0 - 0.01 and Game.xp > xp, "3 served: done, $50 and XP paid at once")
	check(heard.size() == 1 and said.any(func(t): return t.begins_with("Goal done: Serve 3")), "with a message: %s" % [said.filter(func(t): return t.begins_with("Goal"))])
	Game.count("you_cleaned", 2)
	g.check()
	check(g.list[1].done and g.done_count() == 2, "mopping counts (you, not the janitor)")
	g.check()
	check(heard.size() == 2, "a goal only pays once")
	Game.stats.customers = 12
	Game.stats.walkouts = 0
	check(not g.list[2].done, "closing-time goals wait for closing")
	money = Game.money
	var how := g.close()
	check(g.list[2].done and how.perfect and g.streak == 1 and g.perfect_days == 1, "nobody walked out: done at closing, a Perfect Day")
	check(is_equal_approx(Game.money, money + 40.0 + Goals.perfect_bonus(1)), "paid the goal and the Perfect Day bonus ($%d)" % int(Goals.perfect_bonus(1)))
	Game.goal_done.disconnect(on_done)
	Game.message.disconnect(listen)
	check(Goals.perfect_bonus(2) > Goals.perfect_bonus(1) and is_equal_approx(Goals.perfect_bonus(50), Goals.perfect_bonus(7)), "the streak pays more each day, up to a limit")
	# a day that isn't perfect ends the streak
	g.list = [{"type": "serve", "target": 99, "product": "", "kind": "", "cash": 50.0, "xp": 20.0, "done": false}]
	g.streak = 3
	g.best_streak = 3
	how = g.close()
	check(not how.perfect and g.streak == 0 and how.broke == 3 and g.best_streak >= 3, "missing one ends the streak (it remembers the best)")
	check(hud._goals_line(how).contains("3-day"), "and the summary says so: " + hud._goals_line(how))
	# not enough shoppers: the clean-floor goal doesn't count
	Game.stats.customers = 3
	var clean := {"type": "clean", "target": 1, "product": "", "kind": "", "cash": 10.0, "xp": 5.0, "done": false}
	check(not Goals.close_ok(clean), "a clean floor needs a real day's shoppers first")
	# tomorrow's numbers grow with today's
	var lv_serve := g._make("serve", rng).target as int
	g.remember(80, 900.0, 400.0)
	check(int(g._make("serve", rng).target) >= 80 and int(g._make("serve", rng).target) > lv_serve, "a busy day makes tomorrow's numbers bigger (%d, was %d)" % [int(g._make("serve", rng).target), lv_serve])
	g.remember(0, 0.0, 0.0)
	check(int(g._make("revenue", rng).target) >= 50, "and a quiet one doesn't make them silly")
	Game.stats.customers = 0


# ---------------------------------------------------------------- rating

func _rating() -> void:
	var r := StoreRating.new()
	check(is_equal_approx(r.stars(), 3.0) and is_equal_approx(r.traffic_factor(), 1.0), "a new store has 3 stars (no more or fewer shoppers)")
	r.record(5.0, "great")
	check(r.stars() > 3.0 and r.stars() < 3.5, "one happy shopper nudges it up (%.1f), not to 5 stars" % r.stars())
	for i in 9:
		r.record(5.0, "great")
	check(is_equal_approx(r.stars(), 5.0) and is_equal_approx(r.traffic_factor(), 1.2), "five stars: 20% more shoppers")
	check(r.reviews.size() == 10 and r.reviews.all(func(x): return int(x.stars) == 5 and str(x.user).begins_with("@") and not str(x.text).contains("{")), "five-star visits always get a review: \"%s\"" % r.reviews[0].text)
	check(is_equal_approx(r.best, StoreRating.START), "a handful of shoppers don't count for trophies yet")
	for i in StoreRating.WINDOW:
		r.record(5.0, "great")
	check(is_equal_approx(r.best, 5.0), "a full %d do" % StoreRating.WINDOW)
	for i in StoreRating.WINDOW:
		r.record(1.0, "walkout")
	check(is_equal_approx(r.stars(), 1.0) and r.scores.size() == StoreRating.WINDOW, "only the last %d count" % StoreRating.WINDOW)
	check(r.traffic_factor() < 0.85 and is_equal_approx(r.best, 5.0), "1 star keeps shoppers away (and the best is remembered)")
	check(r.reviews.size() == StoreRating.REVIEWS_KEPT and int(r.reviews[0].stars) == 1, "the newest reviews first, %d kept" % StoreRating.REVIEWS_KEPT)
	r.scores = [3.0, 4.0, 3.0, 4.0, 3.0, 4.0, 3.0, 4.0, 3.0, 4.0]
	check(is_equal_approx(r.shown(), 3.5) and StoreRating.words(3.5) == "3.5 stars" and StoreRating.words(4.0) == "4 stars", "half stars on screen (%s)" % StoreRating.words(r.shown()))
	var missing := StoreRating.new()
	var id: String = Game.unlocked_ids()[0]
	for i in 20:
		missing.record(1.0, "missing", Brand.SHOPPERS.zombie, id)
	check(missing.reviews.any(func(x): return str(x.text).to_lower().contains(Game.product_name(id).to_lower()) or not Brand.REVIEWS.missing.any(func(l): return l.contains("{product}"))),
		"reviews say what was missing (%s)" % missing.reviews[0].text)
	var back := StoreRating.new()
	back.from_dict(JSON.parse_string(JSON.stringify(r.to_dict())))
	check(back.scores == r.scores and back.reviews.size() == r.reviews.size() and is_equal_approx(back.best, 5.0), "the rating saves and loads")
	check(Brand.REVIEWS.keys().all(func(k): return not (Brand.REVIEWS[k] as Array).is_empty()), "something to say for every reason")


# ---------------------------------------------------------------- a shopper's score

func _scoring() -> void:
	Game.rating = StoreRating.new()
	for k in ["ratings", "happy", "unhappy"]:
		Game.stats[k] = 0
	Game.stats.stars_sum = 0.0
	Game.stats.why = {}
	var id: String = Game.unlocked_ids()[0]
	var list: Array[Dictionary] = [{"id": id, "qty": 2}]
	var c := store.spawn_customer(Brand.SHOPPERS.zombie, list)
	await _frames(1)
	c.basket = [{"id": id, "price": Game.market_price(id)}, {"id": id, "price": Game.market_price(id)}]
	var s := c.rate_visit()
	check(is_equal_approx(s, 5.0) and Game.rating.scores.size() == 1 and Game.stats.why.has("great"), "found everything, no wait: 5 stars (%.1f)" % s)
	check(c._emote == "heart", "and a heart over their head")
	check(c.rate_visit() < 0.0 and Game.rating.scores.size() == 1, "a shopper only rates once")
	c.queue_free()

	var waited := store.spawn_customer(Brand.SHOPPERS.zombie, list)
	await _frames(1)
	waited.basket = [{"id": id, "price": Game.market_price(id)}, {"id": id, "price": Game.market_price(id)}]
	waited._waited = 0.95
	s = waited.rate_visit()
	check(s <= 3.5 and Game.stats.why.has("wait"), "waited a long time: %.1f, about the wait" % s)
	waited.queue_free()

	var nothing := store.spawn_customer(Brand.SHOPPERS.zombie, list)
	await _frames(1)
	nothing.basket = []
	nothing._missed = 1
	s = nothing.rate_visit()
	check(s <= 2.0 and nothing._emote == "angry", "left with nothing: 2 stars at most, angry (%.1f, %s)" % [s, Game.stats.why.keys()])
	nothing.queue_free()

	var walked := store.spawn_customer(Brand.SHOPPERS.zombie, list)
	await _frames(1)
	s = walked.rate_visit("walkout")
	check(is_equal_approx(s, 1.0) and Game.stats.why.has("walkout") and int(Game.stats.unhappy) >= 2, "walking out of the line: 1 star")
	walked.queue_free()
	check(StoreRating.today() > 0.0 and StoreRating.today_reasons().size() >= 3, "today's average and reasons (%s)" % [StoreRating.today_reasons()])
	check(hud._rating_line(Game.stats).contains("Unhappy about") and hud._rating_line(Game.stats).contains("waiting in line"), "the summary says what shoppers didn't like: " + hud._rating_line(Game.stats))
	# a better rating brings more shoppers
	var before: float = store.traffic_multiplier()
	for i in StoreRating.WINDOW:
		Game.rating.record(5.0, "great")
	check(store.traffic_multiplier() > before * 1.15, "5 stars: more shoppers (%.2f, was %.2f)" % [store.traffic_multiplier(), before])
	await _frames(2)


# ---------------------------------------------------------------- trophies

func _trophies() -> void:
	var t := Game.trophies
	var ids := {}
	for tr: Dictionary in Brand.TROPHIES:
		ids[tr.id] = true
	check(ids.size() == Brand.TROPHIES.size() and Brand.TROPHIES.size() >= 30, "%d trophies, all different" % Brand.TROPHIES.size())
	var unknown := Brand.TROPHIES.filter(func(tr): return Trophies.value(tr.stat) == 0.0 and not tr.stat in ["customers", "revenue", "happy", "you_cleaned", "knockouts", "zt_likes", "spies", "raids", "zomtok", "clean_closes", "loans_repaid", "goals", "streak", "registers", "staff", "staff_level", "lots", "hearse", "vampires_today", "plots", "snake", "licensed"])
	check(unknown.is_empty(), "every trophy counts something real (%s)" % [unknown.map(func(x): return x.id)])
	check(int(Trophies.find("catalog").target) == Game.PRODUCTS.size(), "Full Catalog means every product (%d)" % Game.PRODUCTS.size())
	var decor := Game.FURNITURE.keys().filter(func(id): return Game.FURNITURE[id].has("trophy"))
	check(decor.size() >= 4 and decor.all(func(id): return not Trophies.find(Game.FURNITURE[id].trophy).is_empty()), "%d trophy decorations, each for a real trophy" % decor.size())
	var case_id := "trophy_case"
	check(Game.furniture_problem(case_id).begins_with("Earn the"), "a trophy decoration's locked: " + Game.furniture_problem(case_id))
	var got: Array = []
	var on_got := func(x): got.append(x)
	Game.trophy_earned.connect(on_got)
	var money := Game.money
	t.have.erase("first_sale")
	Game.stats.customers = 1
	t.check()
	check(t.is_earned("first_sale") and got.any(func(x): return x.id == "first_sale"), "first sale: a trophy")
	var paid := float(Trophies.find("first_sale").cash)
	check(Game.money >= money + paid - 0.01, "and it pays ($%d)" % int(paid))
	money = Game.money
	t.check()
	check(is_equal_approx(Game.money, money), "only once")
	await _frames(2)
	check(hud.trophy_toast.visible and hud.trophy_toast.title.text.contains(Trophies.find(got[0].id).name), "the trophy shows across the top: " + hud.trophy_toast.title.text)
	# career totals plus today's
	Game.career.customers = 990.0
	Game.stats.customers = 10
	t.check()
	check(t.is_earned("thousand"), "990 served before and 10 today make a thousand")
	# the trophy case comes with 25 goals done
	Game.goals.completed = 25
	t.check()
	Game.trophy_earned.disconnect(on_got)
	check(t.is_earned("goals_25") and Game.furniture_problem(case_id) == "", "25 goals done: the Trophy Case can be built")
	var deco: Node = store.add_furniture(case_id, _free_cell(case_id))
	await _frames(1)
	var bonus := Game.trophy_decor_bonus("traffic")
	check(deco is Decoration and is_equal_approx(bonus, float(Game.FURNITURE[case_id].traffic)), "it brings shoppers (+%d%%)" % roundi(bonus * 100.0))
	var deco2: Node = store.add_furniture(case_id, _free_cell(case_id))
	await _frames(1)
	check(is_equal_approx(Game.trophy_decor_bonus("traffic"), bonus), "a second one doesn't add more")
	store.remove_furniture(deco)
	store.remove_furniture(deco2)
	await _frames(40)
	Game.stats.customers = 0
	Game.career.customers = 0.0


func _free_cell(id: String) -> Vector2i:
	for c: Vector2i in store.floor_cells:
		if store.placement_error(c, id) == "" and Iso.chebyshev(c, store.door_cell) > 2:
			return c
	return Store.NO_CELL


# ---------------------------------------------------------------- looks

func _looks() -> void:
	var zombie: Texture2D = preload("res://assets/sprites/customer_0.png")
	var frames := CharArt.walk_frames(zombie)
	check(frames.size() == 2, "a zombie gets two walking frames")
	var a: Image = zombie.get_image()
	a.decompress()
	a.convert(Image.FORMAT_RGBA8)
	var left: Image = frames[0].get_image()
	var right: Image = frames[1].get_image()
	check(left.get_size() == a.get_size() and right.get_size() == a.get_size(), "the same size as the picture")
	check(left.get_data() != a.get_data() and right.get_data() != a.get_data() and left.get_data() != right.get_data(), "one leg up in each, a different one")
	var feet := CharArt._feet(a)
	var mid := floori(a.get_width() / 2.0)
	var lifted := false
	var other_still := true
	for x in a.get_width():
		if a.get_pixel(x, feet).a > CharArt.SOLID:
			if x < mid and left.get_pixel(x, feet).a <= CharArt.SOLID:
				lifted = true
			if x >= mid and left.get_pixel(x, feet).a != a.get_pixel(x, feet).a:
				other_still = false
	check(lifted and other_still, "the left foot's off the ground, the right foot isn't")
	var top := 0
	for y in feet - CharArt.LEG_ROWS:
		if a.get_pixel(mid, y) != left.get_pixel(mid, y):
			top += 1
	check(top == 0, "and the rest of them doesn't move")
	check(CharArt.walk_frames(zombie)[0] == frames[0], "made once, then reused")
	var ghost: Texture2D = Brand.SHOPPERS.ghost.looks[0]
	if ghost:
		check(CharArt.walk_frames(ghost).is_empty(), "ghosts float (no legs)")
	var s := Sprite2D.new()
	CharArt.walk(s, zombie, PI / 2.0, true)
	check(s.texture == frames[0], "walking, top of the step: a foot's up")
	CharArt.walk(s, zombie, -PI / 2.0, true)
	check(s.texture == frames[1], "the other foot next")
	CharArt.walk(s, zombie, 0.0, true)
	check(s.texture == zombie, "both feet down in between")
	CharArt.walk(s, zombie, PI / 2.0, false)
	check(s.texture == zombie, "standing still: no walking")
	s.free()
	var looks: Array = Brand.SHOPPERS.zombie.get("looks", [])
	check(looks.size() >= 10, "%d looks for zombies" % looks.size())
	check(CharArt.EMOTES.size() == 6 and CharArt.EMOTES.values().all(func(e): return e != null), "six emotes")
	var c := store.spawn_customer(Brand.SHOPPERS.zombie)
	c.emote("question")
	check(c._emote == "question" and c._emote_t > 0.0, "a shopper can show one")
	c.queue_free()
	check(Brand.CHATTER.any.size() >= 5, "shoppers have things to say")


# ---------------------------------------------------------------- the HUD

func _hud() -> void:
	Game.day = 3
	Game.goals.day = 0
	Game.goals.roll()
	await _frames(3)
	var gp: GoalsPanel = hud.goals_panel
	check(GoalsPanel.has_goals() and gp.visible and gp.rows[0][0].visible, "the goals list is up in the top left")
	check(gp.rows.slice(0, Game.goals.list.size()).all(func(r): return (r[2] as Label).text != ""), "with each goal: " + " / ".join(gp.rows.map(func(r): return (r[2] as Label).text)))
	check(gp.get_global_rect().position.x < hud.get_viewport().get_visible_rect().size.x * 0.4, "on the left")
	gp._on_input(_click())
	await _frames(2)
	check(gp.folded and not gp.list_box.visible and gp.title.text.begins_with("Goals 0/"), "a click folds it to one line: " + gp.title.text)
	gp._on_input(_click())
	await _frames(2)
	check(not gp.folded and gp.list_box.visible, "and back")
	hud.open_computer()
	await _frames(2)
	check(not gp.visible, "hidden behind the computer")
	hud.computer.close()
	await _frames(2)
	var bar: StarBar = hud.star_bar
	check(bar != null and bar.is_visible_in_tree() and bar.stars.size() == 5, "five stars in the top bar")
	Game.rating.scores = [4.0, 3.0, 4.0, 3.0, 4.0, 3.0, 4.0, 3.0, 4.0, 3.0]
	await _frames(2)
	check(bar.stars[3].texture == StarBar.HALF and bar.stars[2].texture == StarBar.FULL and bar.stars[4].texture == StarBar.EMPTY, "3.5 stars: three, a half and one empty")
	check(bar.tooltip_text.contains("3.5 stars"), "point at them for what they mean")


func _click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


# ---------------------------------------------------------------- the PC

func _pc() -> void:
	var pc: Node = hud.computer
	hud.open_computer()
	await _frames(2)
	pc.show_tab(pc.Tab.GOALS)
	await _frames(2)
	check(pc.tab == pc.Tab.GOALS and pc.goals_page == 0, "the Goals app opens on Today")
	var texts := _texts(pc.body)
	check(texts.any(func(t): return t.contains(Goals.text(Game.goals.list[0]))), "with today's goals")
	check(texts.any(func(t): return t.contains("Perfect Day")) and texts.any(func(t): return t.contains("in a row")), "the Perfect Day bonus and the streak")
	var pages: Array = pc.body.get_child(0).get_children().filter(func(b): return b is Button)
	check(pages.size() == 3 and pages[0].button_pressed and pc.body.get_child(0).get_children().any(func(n): return n is StarBar), "pages: Today, Rating, Trophies (and the stars)")
	pages[1].pressed.emit()
	await _frames(2)
	texts = _texts(pc.body)
	check(pc.goals_page == 1 and texts.any(func(t): return t.begins_with("STORE RATING")), "the Rating page")
	check(texts.any(func(t): return t.contains("WHAT SHOPPERS SAY")), "with what shoppers wrote")
	Game.stats.why = {"wait": 4, "great": 2}
	pc._rebuild()
	await _frames(1)
	check(_texts(pc.body).any(func(t): return t.begins_with("Tip:") and t.contains("cashier")), "and a tip for what they didn't like")
	pc.body.get_child(0).get_children().filter(func(b): return b is Button)[2].pressed.emit()
	await _frames(2)
	texts = _texts(pc.body)
	check(pc.goals_page == 2 and texts.any(func(t): return t.begins_with("TROPHIES: %d of %d" % [Game.trophies.count(), Trophies.total()])), "Trophies: %d of %d" % [Game.trophies.count(), Trophies.total()])
	var rows: Array = pc._body_buttons().filter(func(n): return n is Button and n.flat)
	check(pc._body_buttons()[0].text == "Today", "with a controller, the page buttons come first")
	check(rows.size() == Trophies.total(), "every trophy listed (%d)" % rows.size())
	check(rows.slice(-Game.trophies.count()).all(func(b): return b.text.contains("earned on day")), "earned ones at the end, with the day")
	check(rows.any(func(b): return b.text.contains("Trophy Case")), "the ones with decorations say so")
	check(pc._body_buttons().size() >= rows.size(), "a controller can go down the list")
	pc.close()
	await _frames(2)


func _texts(n: Node) -> Array[String]:
	var out: Array[String] = []
	for c in n.get_children():
		if c is Label:
			out.append(c.text)
		elif c is Button:
			out.append(c.text)
		elif c is Container:
			out.append_array(_texts(c))
	return out


# ---------------------------------------------------------------- saving

func _saving() -> void:
	Game.goals.streak = 4
	Game.goals.best_streak = 6
	Game.goals.completed = 31
	Game.goals.list[0].done = true
	Game.rating.scores = [4.0, 5.0, 3.0, 4.0, 5.0, 3.0, 4.0, 5.0, 3.0, 4.0, 5.0, 3.0]
	Game.rating.reviews = [{"day": 2, "stars": 4, "user": "@moaner", "kind": "zombie", "text": "Good brains."}]
	Game.career.customers = 1234.0
	var d: Dictionary = JSON.parse_string(JSON.stringify(Game.to_dict()))
	var list: Array = Game.goals.list.duplicate(true)
	var have: Dictionary = Game.trophies.have.duplicate()
	Game.goals = Goals.new()
	Game.rating = StoreRating.new()
	Game.trophies = Trophies.new()
	Game.career = {}
	Game.from_dict(d)
	check(Game.goals.streak == 4 and Game.goals.best_streak == 6 and Game.goals.completed == 31, "the streak and goals done come back")
	check(Game.goals.list.size() == list.size() and Game.goals.list[0].done and Game.goals.list[0].type == list[0].type and int(Game.goals.list[0].target) == int(list[0].target), "today's goals come back (not new ones)")
	check(Game.rating.scores.size() == 12 and is_equal_approx(Game.rating.stars(), 4.0) and Game.rating.reviews[0].text == "Good brains.", "the rating and reviews come back")
	var keys_now: Array = Game.trophies.have.keys()
	var keys_then: Array = have.keys()
	keys_now.sort()
	keys_then.sort()
	check(keys_now == keys_then and is_equal_approx(float(Game.career.customers), 1234.0), "trophies and career totals come back")
	var old := d.duplicate(true)
	for k in ["goals", "rating", "trophies", "career"]:
		old.erase(k)
	Game.from_dict(old)
	check(is_equal_approx(Game.rating.stars(), 3.0) and Game.trophies.count() == 0 and Game.goals.streak == 0, "an older save starts at 3 stars, no trophies, no streak")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
