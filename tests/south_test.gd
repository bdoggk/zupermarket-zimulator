extends Node
# The south side of town (0.20): the bigger map, the houses, special orders
# from the notice board, and the showdown with Mr. Bones.
#  map        70x50, townsfolk come from the south edge, every house's door,
#             the notice board and the crypt are reachable
#  orders     from store level 4: three a morning (the same for the same
#             game), up to two taken at once, a box of it to the right door
#             pays and gives XP, late after 6 PM; the board's panel, the
#             goals panel, the arrow to the house, the summary, saving
#  showdown   once you've won 3 raids: the note, tonight's event (no raids
#             today), Mr. Bones and his guards at the crypt waiting for you,
#             engaged when you walk up (your gang comes too), only you can
#             hurt him, two more guards at half, losing (back tomorrow),
#             not turning up, winning: Bone Mart's yours (its branches, the
#             sign, no raids or spies, its takings, the trophy, the panel),
#             saving
#   godot --headless --path . --fixed-fps 60 res://tests/south_test.tscn

var fails := 0
var hud: Node
var store: Store
var town: Town
var p: Player
var said: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	seed(2020)
	Engine.max_fps = 0
	Settings.first_person = false
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	hud = main.get_node("HUD")
	store = Game.store
	town = store.town
	p = Game.player
	Game.tutorial_hidden = true
	hud.tutorial._hide_all()
	Game.money = 50000.0
	Game.message.connect(func(t: String): said.append(t))
	_map()
	_houses()
	await _first_person()
	await _orders()
	await _showdown()
	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- the map

func _map() -> void:
	check(town.size == Vector2i(70, 50), "the town is 70x50 (%s)" % town.size)
	check(town.spawns.filter(func(c): return c.y == town.size.y - 1).size() == 2 and not town.spawns.any(func(c): return c.y > 17 and c.y < town.size.y - 1),
		"townsfolk come in along the road and from the south edge (%s)" % [town.spawns])
	check(town.spawns.all(func(c): return store.reachable.has(c)), "and can walk from there")
	var doors: Array[Vector2i] = []
	for h: House in town.houses.values():
		doors.append(h.cell + Vector2i(0, 1))
	check(doors.size() == 4 and doors.all(func(c): return store.reachable.has(c)), "every house's front door is reachable (%s)" % [doors])
	check(town.crypt_cell != Town.NO_CELL and store.reachable.has(town.crypt_door()), "so is Mr. Bones' crypt (%s)" % town.crypt_door())
	check(town.notice_board != null and store.stand_cell_for(town.notice_board.cell, store.door_cell) != Store.NO_CELL, "and the notice board in the square")
	check(town.fountain != null and town.fountain.light != null, "the fountain glows red")
	var path := store.find_path(store.door_cell, town.crypt_door())
	check(path.size() > 20, "a long walk from the store to the graveyard (%d steps)" % path.size())


func _houses() -> void:
	check(town.houses.size() == 4 and town.houses.has("vlad") and town.houses.has("wolf"), "four houses: %s" % [town.houses.keys()])
	var h: House = town.houses.vlad
	check(h.tall and h.get_prompt(p) == str(Brand.HOUSES.A.text), "Count Vlad's mansion (%s)" % h.get_prompt(p))
	check(not h.can_interact(p), "nothing to do there without an order")
	check(town.notice_board.get_prompt(p).contains("store level %d" % SpecialOrders.FROM_LEVEL) and not town.notice_board.can_interact(p),
		"the notice board: special orders from level %d (%s)" % [SpecialOrders.FROM_LEVEL, town.notice_board.get_prompt(p)])


## In first person the houses and the crypt are buildings, the benches benches.
func _first_person() -> void:
	var fp: FirstPerson = Game.fp
	p.position = Iso.cell_to_world(town.notice_board.cell + Vector2i(2, 3))
	fp.set_active(true)
	await _frames(fp.RESYNC_EVERY + 3)
	var kinds := {}
	for m: Array in fp._mirrors.values():
		if is_instance_valid(m[0]) and (m[0] is House or m[0] == town.objects.get(town.crypt_cell)):
			kinds["house" if m[0] is House else "crypt"] = [m[1], is_instance_valid(m[2]) and m[2].get_child_count() >= 4]
		elif is_instance_valid(m[0]) and m[0] is Prop and (m[0] as Prop).textures.size() > 0 and (m[0] as Prop).textures[0].resource_path.contains("prop_bench"):
			kinds["bench"] = [m[1], is_instance_valid(m[2]) and m[2].get_child_count() >= 6]
	check(kinds.get("house", []) == ["building", true] and kinds.get("crypt", []) == ["building", true] and kinds.get("bench", []) == ["bench", true],
		"first person: the houses and the crypt are buildings, the benches benches (%s)" % [kinds])
	fp.set_active(false)
	await _frames(2)


# ---------------------------------------------------------------- orders

func _orders() -> void:
	var orders := Game.orders
	orders.day = 0
	orders.roll()
	check(orders.list.is_empty(), "no orders before level %d" % SpecialOrders.FROM_LEVEL)
	Game.add_xp(Game.xp_for_level(SpecialOrders.FROM_LEVEL) - Game.xp + 1.0)
	await _frames(2)
	hud.levelup_panel.visible = false
	orders.day = 0
	orders.roll()
	check(orders.list.size() == SpecialOrders.POSTED, "level %d: %d orders on the board" % [Game.level, orders.list.size()])
	var houses := {}
	var sane := true
	for o in orders.list:
		houses[o.house] = true
		var box := int(Game.PRODUCTS[o.product].box_size)
		sane = sane and int(o.qty) >= 1 and int(o.qty) <= box and float(o.pay) > int(o.qty) * Game.market_price(o.product) and o.product in Game.unlocked_ids()
	check(houses.size() == SpecialOrders.POSTED and sane, "from different houses, a box or less of something you sell, paying well (%s)" % [orders.list.map(func(o): return "%s: %s $%d" % [o.house, SpecialOrders.amount(o), int(o.pay)])])
	var first := orders.list.duplicate(true)
	orders.day = 0
	orders.roll()
	check(str(orders.list) == str(first), "the same game gets the same orders")
	check(town.notice_board.can_interact(p) and town.notice_board.get_prompt(p).contains("3 special orders"), "the board: %s" % town.notice_board.get_prompt(p))

	# the board's panel
	Game.open_store()
	await _frames(2)
	town.notice_board.interact(p)
	await _frames(3)
	var panel: Node = hud.orders_panel
	check(panel.visible and Game.menu_open, "using the board opens the orders")
	var takes: Array = panel.grid.get_children().filter(func(n): return n is Button)
	check(takes.size() == 3 and takes.all(func(b): return b.text == "Take it" and not b.disabled), "three to take")
	takes[0].pressed.emit()
	takes[1].pressed.emit()
	await _frames(2)
	check(orders.open_orders().size() == 2 and takes[0].text == "Taken", "took two")
	check(takes[2].disabled and takes[2].text == "%d at a time" % SpecialOrders.TAKE_MAX, "and that's the limit (%s)" % takes[2].text)
	check(said.any(func(t): return t.begins_with("Order taken:")), "the order's taken: %s" % [said.filter(func(t): return t.begins_with("Order taken"))])
	panel.close()
	await _frames(2)
	check(hud.goals_panel.visible and hud.goals_panel.orders_title.visible and hud.goals_panel.order_rows[1][0].visible, "they're under today's goals")

	# fetch it and deliver it
	var o: Dictionary = orders.open_orders()[0]
	var h: House = town.houses[o.house]
	check(hud._guide_target().is_empty(), "no arrow until you have what they want")
	p.pick_up(o.product, int(o.qty) + 1)
	await _frames(2)
	var target: Array = hud._guide_target()
	check(not target.is_empty() and (target[0] as Vector2).is_equal_approx(h.position), "carrying it: an arrow to %s" % h.info.place)
	check(str(hud.goals_panel.order_rows[0][3].text) == "Got them!", "the goals panel says you've got them")
	var wrong := orders.open_orders()[1]
	check(not orders.can_deliver(wrong.house, p) or wrong.product == o.product, "the other house doesn't want this")
	p.position = Iso.cell_to_world(h.cell + Vector2i(0, 1))
	p.path.clear()
	await _frames(4)
	check(p.focused == h and h.get_prompt(p).begins_with("Deliver %s" % SpecialOrders.amount(o)), "at the door: %s" % h.get_prompt(p))
	var money := Game.money
	var xp := Game.xp
	var out := SpecialOrders.items_out
	p.try_interact()
	await _frames(3)
	check(o.done and is_equal_approx(Game.money - money, float(o.pay)) and Game.xp > xp, "delivered: +$%d and XP" % int(Game.money - money))
	check(p.carry_count == 1 and SpecialOrders.items_out == out + int(o.qty), "the order came out of the box (1 left)")
	check(int(Game.stats.orders) == 1 and is_equal_approx(float(Game.stats.orders_paid), float(o.pay)) and Trophies.value("orders") == 1.0, "counted for the day and the courier trophy")
	check(Game.profit_today() >= float(o.pay) - Game.stats.spent - Game.stats.wages - Game.stats.invested - 0.01, "and in today's profit")
	check(said.any(func(t): return t.begins_with("Delivered")), "a message says so")
	p.take_from_carry(p.carry_count)

	# late
	Game.minute = SpecialOrders.DUE
	orders.tick()
	check(wrong.late and orders.open_orders().is_empty(), "6 PM: the other one's too late")
	check(said.any(func(t): return t.contains("gave up waiting")), "they gave up waiting")
	town.notice_board.interact(p)
	await _frames(3)
	takes = panel.grid.get_children().filter(func(n): return n is Button)
	check(takes.size() == 3 and takes[2].disabled and takes[2].text == "Too late today", "nothing more to take today (%s)" % takes[2].text)
	panel.close()

	# a goal, saving, the summary
	var g := {"type": "deliver", "target": 1}
	check(Goals.text(g).contains("special order"), "a goal can be to deliver one: %s" % Goals.text(g))
	var d := Game.orders.to_dict()
	var again := SpecialOrders.new()
	again.from_dict(JSON.parse_string(JSON.stringify(d)))
	check(again.list.size() == 3 and again.list.filter(func(x): return x.done).size() == 1 and again.list.filter(func(x): return x.late).size() == 1 and again.day == orders.day,
		"orders save and load")
	hud._show_summary(Game.stats.merged({"day": Game.day, "profit": Game.profit_today(), "goals": {}, "rating": 3.0, "event": ""}))
	check(hud.summary_money.text.contains("Special orders (1)"), "the day's summary counts them")
	hud.summary_panel.visible = false
	Game.minute = Game.OPEN_MINUTE + 60
	await _frames(2)


# ---------------------------------------------------------------- the showdown

func _showdown() -> void:
	var war: GangWar = Game.war
	var turf: Turf = town.turf
	Game.add_xp(Game.xp_for_level(GangWar.LEVEL) - Game.xp + 1.0)
	war.begin()
	await _frames(3)
	hud.levelup_panel.visible = false
	for i in 3:
		war.hire()
	war.buy_weapon("nunchucks")
	await _frames(3)
	check(war.on and not Game.cutscene and turf.members.size() == 3, "the war's on, with a gang of 3")
	check(not war.showdown_ready(), "no showdown yet")
	Game.career.raids = float(GangWar.SHOWDOWN_RAIDS)
	check(war.showdown_ready(), "%d raids won: Mr. Bones has had enough" % GangWar.SHOWDOWN_RAIDS)

	# the morning
	said.clear()
	war.raids = [[600, GangWar.MAIN]]
	war.plan_showdown()
	war.morning()
	check(war.showdown == "due" and Game.calendar.event() == "showdown" and Game.calendar.event_minute() == GangWar.SHOWDOWN_MINUTE, "tonight's event: the showdown at 6 PM")
	check(war.raids.is_empty(), "no raids today: he's saving his gang")
	check(said.has(Brand.SHOWDOWN.challenge) and Brand.SHOWDOWN.challenge.contains("6 PM"), "his note: %s" % Brand.SHOWDOWN.challenge)

	# not turning up
	Game.minute = GangWar.SHOWDOWN_MINUTE
	await _frames(3)
	check(turf.fight.get("kind", "") == "showdown" and Game.calendar.started == Game.day, "6 PM: it's on")
	var boss: BossBones = turf.fight.boss
	check(is_instance_valid(boss) and boss.max_hp == BossBones.HP and turf.fight.bone.size() == 1 + Turf.SHOWDOWN_GUARDS, "Mr. Bones (%d HP) and %d guards" % [boss.max_hp if boss else 0, Turf.SHOWDOWN_GUARDS])
	check(Iso.chebyshev(boss.current_cell(), town.crypt_cell) <= 3, "at his crypt")
	check(not bool(turf.fight.engaged) and not boss.angry, "waiting for you")
	await _frames(2)
	check(hud.fight_panel.visible and str(hud.fight_label.text).contains("waiting at his crypt"), "the HUD: %s" % hud.fight_label.text)
	var target: Array = hud._guide_target()
	check(not target.is_empty() and (target[0] as Vector2).is_equal_approx(Iso.cell_to_world(town.crypt_door())), "an arrow points the way")
	said.clear()
	Game.day_over = true
	await _frames(3)
	check(turf.fight.is_empty() and said.has(Brand.SHOWDOWN.no_show) and war.showdown == "due", "didn't turn up: he'll be back tomorrow")
	Game.day_over = false
	await _frames(45)

	# losing
	check(turf.start_showdown(), "the next night")
	boss = turf.fight.boss
	_go_near_crypt()
	await _frames(4)
	check(bool(turf.fight.engaged) and boss.angry, "walk up: it's on")
	check(turf.members.values().all(func(m): return m.job == Gangster.Job.RESPOND), "your gang comes running")
	var zombie: Gangster = turf.members.values()[0]
	boss.hurt(5, zombie)
	check(boss.hp == boss.max_hp, "your gang can't hurt him")
	check(not boss._can_fight(zombie) and not zombie._can_fight(boss), "(he and your gang leave each other alone)")
	await _frames(2)
	check(str(hud.fight_label.text).begins_with("SHOWDOWN!") and str(hud.fight_label.text).contains("%d/%d" % [boss.hp, boss.max_hp]), "the HUD: %s" % hud.fight_label.text)
	for i in boss.max_hp / 2:
		boss.hurt(1, p)
	check(boss.hp == boss.max_hp / 2 and boss.summoned and turf.fight.bone.size() == 1 + Turf.SHOWDOWN_GUARDS + 2, "half way: two more of his gang come out")
	said.clear()
	turf.player_knocked_out()
	await _frames(2)
	check(turf.fight.is_empty() and said.has(Brand.SHOWDOWN.lost) and war.showdown == "due" and not war.taken_over, "knocked out: he laughs, and he'll be back")
	await _frames(45)

	# winning, in a real fight: you (with nunchucks) and your gang, against him and his
	var bone_plot := war.owned_by(GangWar.BONE)
	check(not bone_plot.is_empty(), "Bone Mart has a branch (%s)" % [bone_plot])
	said.clear()
	var won := await _fair_fight(turf)
	check(won != "", "a real fight with nunchucks and your gang: %s" % won)
	await _frames(3)
	check(war.taken_over and war.showdown == "won" and turf.fight.is_empty(), "beat him: Bone Mart is yours")
	check(said.has(Brand.SHOWDOWN.won) and said.has(Brand.SHOWDOWN.takeover), "he says so")
	check(war.owned_by(GangWar.BONE).is_empty() and war.plots[bone_plot[0]] == GangWar.YOU, "and his branches are yours")
	check(town.rival_owner == null and town.rival_sign.textures[0] == Brand.RIVAL.textures.sign_sold, "he's gone from behind his counter, and the sign says SOLD")
	check(hud.levelup_panel.visible and hud.levelup_title.text == "BONE MART IS YOURS!", "a big panel: %s" % hud.levelup_title.text)
	Game.trophies.check()
	check(Game.trophies.is_earned("bone_breaker"), "the Bone Breaker trophy")
	war.roll_raids()
	check(war.raids.is_empty(), "no more raids")
	Game.roll_rival_spies()
	check(Game.rival_spies.is_empty(), "no more spies")
	check(Game.rival_pull([], Brand.SHOPPERS.zombie) == 0.0, "no shoppers go to Bone Mart")
	check(war.branch_income() >= GangWar.TAKEOVER_TAKE, "its takings come to you ($%d a night)" % int(war.branch_income()))
	war.plan_showdown()
	check(war.showdown == "won", "and no more showdowns")
	var d := war.to_dict()
	var w2 := GangWar.new()
	w2.from_dict(JSON.parse_string(JSON.stringify(d)), Game.level)
	check(w2.taken_over and w2.showdown == "won", "saved and loaded")
	hud.levelup_panel.visible = false


## Fights Mr. Bones properly: waits for your gang to get to the graveyard,
## walks up and keeps hitting him (backing off to get better when it's
## going badly). What happened ("" if it took too long).
func _fair_fight(turf: Turf) -> String:
	p.health = Player.MAX_HEALTH
	p.path.clear()
	p.position = Iso.cell_to_world(store.door_cell + Vector2i(0, 2))  # (away from the crypt till your gang's there)
	for m: Gangster in turf.members.values():
		m.position = Iso.cell_to_world(m.home)
	await _frames(10)
	turf.start_showdown()
	var boss: BossBones = turf.fight.boss
	for i in 3000:  # your gang walks over
		await get_tree().process_frame
		if turf.members.values().all(func(m): return m.current_cell() == m.spot):
			break
	var waited := turf.members.values().all(func(m): return m.current_cell() == m.spot)
	_go_near_crypt()
	var t := 0.0
	var backed_off := 0
	while t < 120.0:
		await get_tree().process_frame
		t += 1.0 / 60.0
		if not turf.fighting():
			break
		if p.knocked_out > 0.0:
			break
		if OS.get_environment("FIGHT_DEBUG") != "" and Engine.get_process_frames() % 30 == 0:
			var foes := []
			for g: Gangster in turf.fight.get("bone", []):
				if is_instance_valid(g):
					foes.append("%s>%s%s" % [g.gang_name.left(5), "P" if g.foe == p else (g.foe.gang_name.left(5) if g.foe is Gangster else "-"), "x" if g.is_out() else ""])
			print("  t %.1f hp %.1f boss %d d %d %s" % [t, p.health, boss.hp, Iso.chebyshev(p.current_cell(), boss.current_cell()), foes])
		if p.health <= 3.0 and boss.hp > 6 and boss.foe == p:  # run off and get your breath back
			backed_off += 1
			p.run_toggle = true
			p._on_tap(Iso.cell_to_world(town.crypt_door() + Vector2i(-14, 2)))
			for j in 900:
				await get_tree().process_frame
				t += 1.0 / 60.0
				if p.health >= Player.MAX_HEALTH - 0.5 or not turf.fighting() or p.knocked_out > 0.0:
					break
				if OS.get_environment("FIGHT_DEBUG") != "" and j % 30 == 0:
					print("  (running) t %.1f hp %.1f d %d sprint %s path %d boss foe %s at %s" % [t, p.health, Iso.chebyshev(p.current_cell(), boss.current_cell()), p.sprinting, p.path.size(), boss.foe == p, boss.current_cell()])
			p.run_toggle = false
			continue
		if p.can_hit(boss):
			p.path.clear()
			p.attack(boss)
		elif p.path.is_empty() or Engine.get_process_frames() % 20 == 0:
			p._on_tap(boss.position + Vector2(0, -12))
	var down := turf.members.values().filter(func(m): return m.is_out()).size()
	if Game.war.taken_over:
		return "won in %.0f s (the gang waited at the graveyard: %s; backed off %d times; %d of your gang knocked out)" % [t, waited, backed_off, down]
	print("  (lost: t %.1f, knocked out %s, boss hp %d, fighting %s, waited %s, backed off %d, gang down %d, bone %d)" % [t, p.knocked_out > 0.0, boss.hp if is_instance_valid(boss) else -1, turf.fighting(), waited, backed_off, down, turf.fight.get("bone", []).size()])
	return ""


func _go_near_crypt() -> void:
	p.path.clear()
	p.position = Iso.cell_to_world(town.crypt_door() + Vector2i(-3, 1))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
