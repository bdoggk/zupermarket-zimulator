extends Node
# The gang war (GangWar, Turf, Gangster): Bone Mart isn't for sale anymore
# (an old save that bought it gets its money back), the land east of Bone
# Mart, the cutscene at store level 15, buying land for branch stores and
# what they make, hiring a gang, weapons, Bone Mart's raids on your store
# (fought off, or the register robbed) and on a branch (taken over), your
# raids on Bone Mart (closed for the day) and its branches (taken), getting
# knocked out, saving, the Turf app and first person.
#   godot --headless --path . --fixed-fps 60 res://tests/war_test.tscn

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	seed(1513)
	Settings.first_person = false
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(4)
	var hud: Node = main.get_node("HUD")
	var store: Store = Game.store
	var p: Player = Game.player
	var town: Town = store.town
	var turf: Turf = town.turf
	var war: GangWar = Game.war
	Game.tutorial_hidden = true
	Engine.time_scale = 3.0

	# ---- before the war
	check(not Game.has_method("buy_out_rival") and not ("buy_button" in hud.rival_panel), "Bone Mart isn't for sale anymore")
	check(turf != null and turf.plots.size() == 4, "four plots of land east of Bone Mart (%d)" % (turf.plots.size() if turf else -1))
	var lot: Dictionary = turf.plots[0]
	check(lot.cells.all(func(c): return not store.is_walkable(c)), "behind a fence: nobody walks in")
	var sale: Prop = null
	for n in lot.nodes:
		if n is Prop and Town.FOR_SALE in n.textures:
			sale = n
	check(sale != null and sale.get_prompt(p) == Brand.WAR.land_before, "its sign: not for sale yet (%s)" % (sale.get_prompt(p) if sale else "no sign"))
	check(war.buy_problem(0) != "" and war.hire_problem() != "" and war.weapon_problem("nunchucks") != "", "no land, gang or weapons before the war")
	hud.open_computer()
	hud.computer.show_tab(hud.computer.Tab.TURF)
	await _frames(2)
	check(_texts(hud.computer.body).any(func(t): return t.contains("level %d" % GangWar.LEVEL)), "the Turf app says it starts at level %d" % GangWar.LEVEL)
	hud.computer.close()
	await _frames(1)

	# ---- an old save that bought Bone Mart gets its money back
	var d := Game.to_dict()
	d.rival["owned"] = true
	var old_money := Game.money
	Game.from_dict(d)
	check(is_equal_approx(Game.money, old_money + float(Brand.RIVAL.old_buyout)) and war.bought_back and Saves.pending_notice == Brand.RIVAL.bought_back,
		"an old save that bought Bone Mart: Mr. Bones buys it back ($%d back)" % int(Game.money - old_money))
	Saves.pending_notice = ""
	Game.money = old_money

	# ---- level 15: the cutscene
	Game.money = 60000.0
	Game.xp = Game.xp_for_level(GangWar.LEVEL) - 1.0
	Game.level = GangWar.LEVEL - 1
	Game.add_xp(5.0)
	check(Game.level == GangWar.LEVEL and war.pending and not war.on, "store level %d: the war is coming" % GangWar.LEVEL)
	check(Game.unlocks_at(GangWar.LEVEL).any(func(l): return l.contains("gang war")), "the level-up list says so")
	hud.levelup_panel.visible = false
	await _frames(3)
	var cut: Node = hud.war_cutscene
	check(is_instance_valid(cut) and Game.cutscene and not hud.visible, "the cutscene starts (the HUD steps aside)")
	var steps := {}
	for i in 900:
		if not is_instance_valid(cut):
			break
		steps[cut.step] = true
		if cut.step == "talk":
			break
		await get_tree().process_frame
	check(steps.has("bones") and steps.has("talk") and cut.actors.size() == 3, "Mr. Bones walks in with two thugs and talks (%s)" % [steps.keys()])
	cut._advance = true
	await _frames(2)
	cut.skip()
	await _frames(3)
	check(cut.step == "card" and cut.card.visible and cut.actors.is_empty(), "skipping goes to the GANG WAR card")
	cut.go_button.pressed.emit()
	await _frames(3)
	check(war.on and not war.pending and not Game.cutscene and hud.visible, "Let's go: it's war")
	var bone := war.owned_by(GangWar.BONE)
	check(bone.size() == 1 and bone[0] == 1, "Bone Mart buys the far north lot straight away (%s)" % [bone])
	var branch: Dictionary = turf.plots[1]
	var shelves: Array = branch.nodes.filter(func(n): return n is BranchShelf)
	check(shelves.size() == 8 and shelves.all(func(s): return not s.ours and s.product_id != ""), "a Bone Mart Express: 8 shelves of stock")
	check(branch.nodes.any(func(n): return n is RivalDesk) and is_instance_valid(branch.crew_walker), "a counter, and a skeleton behind it")
	check(store.reachable.has(branch.door) and store.reachable.has(branch.stand), "you can walk in, up to its counter")
	check(store.floor_layer.tiles().any(func(t): return Iso.world_to_cell(t[1] + Vector2(32, 16)) == branch.stand), "it has a floor")

	# ---- buying land
	var cost := war.plot_cost()
	var before := Game.money
	check(war.buy_plot(0), "bought the north lot")
	await _frames(2)
	check(is_equal_approx(before - Game.money, cost) and war.plots[0] == GangWar.YOU, "for $%d" % int(cost))
	var mine: Dictionary = turf.plots[0]
	check(mine.nodes.filter(func(n): return n is BranchShelf and n.ours).size() == 8 and is_instance_valid(mine.crew_walker), "a %s with your shelves and your crew" % Brand.WAR.your_branch)
	check(war.plot_cost() > cost, "the next plot costs more ($%d)" % int(war.plot_cost()))
	check(Game.rival_pull([], Brand.SHOPPERS.zombie) >= 0.0, "(shoppers still compare)")

	# ---- the gang and weapons
	for i in 3:
		war.hire()
	await _frames(3)
	check(war.gang_size() == 3 and turf.members.size() == 3, "hired 3 gangsters: they're out front")
	check(turf.members.values().all(func(m): return turf.guard_spots.has(m.home)), "standing guard outside your store")
	check(is_equal_approx(Game.all_wages(), Game.daily_wages() + 3 * GangWar.GANG_WAGE), "their wages")
	check(war.buy_weapon("nunchucks") and war.weapon() == "nunchucks", "bought nunchucks")
	check(war.buy_weapon("glock") and war.weapon() == "glock", "bought a Glock (it's what's in your hand)")
	hud.open_computer()
	hud.computer.show_tab(hud.computer.Tab.TURF)
	await _frames(2)
	var texts := _texts(hud.computer.body)
	check(texts.any(func(t): return t.contains("Only while you're open")) and texts.any(func(t): return t == "Yours") and texts.any(func(t): return t.begins_with("Buy $")),
		"the Turf app: your branch, Bone Mart's (raids only while you're open) and land for sale")
	check(texts.any(func(t): return t.contains("In your hand")), "and the Glock in your hand")
	hud.computer.close()
	await _frames(1)

	# ---- Bone Mart raids your store: your gang (and your Glock) fights them off
	Game.open_store()
	await _frames(2)
	for c in store.customers.duplicate():
		c.queue_free()
	store.customers.clear()
	p.position = Iso.cell_to_world(store.door_cell + Vector2i(0, -1))
	turf.start_defense(GangWar.MAIN)
	await _frames(2)
	check(turf.fighting() and turf.enemies().size() == war.raid_size(), "a raid: %d skeletons set off from Bone Mart" % turf.enemies().size())
	check(turf.members.values().all(func(m): return m.job == Gangster.Job.RESPOND), "your gang runs to meet them")
	check(hud.fight_panel.visible and hud.fight_label.text.begins_with("RAID!"), "RAID! on the screen: " + hud.fight_label.text)
	var shot := false
	for i in 1800:
		if not turf.fighting():
			break
		var near := turf.enemies_within(p.current_cell(), Player.GLOCK_RANGE)
		if not near.is_empty() and p._attack_cd <= 0.0:
			var r := p.rounds
			p.attack(near[0])
			shot = shot or p.rounds < r
		await get_tree().process_frame
	check(shot, "you shot at them")
	check(not turf.fighting() and int(Game.stats.raids_won) == 1, "fought them off (fights won: %d)" % int(Game.stats.raids_won))
	await _wait(3.0)
	check(turf.members.values().all(func(m): return is_instance_valid(m) and (m.job == Gangster.Job.GUARD or m.is_out() or m.job == Gangster.Job.HOME)), "your gang goes back out front")

	# ---- nobody stops them: they smash a shelf and rob the register
	for id in turf.members.keys():
		war.fire(id)
	await _frames(2)
	war.weapons.clear()
	for sh: Shelf in store.shelves:
		sh.product_id = Game.unlocked_ids()[0]
		sh.stock = 8
	p.position = Iso.cell_to_world(branch.outside + Vector2i(0, 2))  # (far away, at the branches)
	Game.money = 10000.0
	var robbed_before := float(Game.stats.robbed)
	turf.start_defense(GangWar.MAIN)
	for i in 3600:
		if not turf.fighting():
			break
		await get_tree().process_frame
	var took := float(Game.stats.robbed) - robbed_before
	check(took >= 1499.0 and took <= 1501.0 and is_equal_approx(Game.money, 10000.0 - took), "they robbed the register: $%d (15%%)" % int(took))
	check(store.shelves.any(func(s): return s.product_id != "" and s.stock == 0), "and smashed a shelf")
	check(not turf.fighting(), "then went back to Bone Mart")

	# ---- you get knocked out: they help themselves
	p.position = Iso.cell_to_world(store.door_cell + Vector2i(0, -1))
	Game.money = 1000.0
	robbed_before = float(Game.stats.robbed)
	turf.start_defense(GangWar.MAIN)
	p.health = 1.0
	for i in 2400:
		if p.knocked_out > 0.0 or not turf.fighting():
			break
		await get_tree().process_frame
	check(p.knocked_out > 0.0 and float(Game.stats.robbed) > robbed_before, "knocked out: they rob you while you're down")
	await _wait(Player.KNOCKED_OUT_SECONDS + 0.5)
	check(p.knocked_out <= 0.0 and is_equal_approx(p.health, Player.MAX_HEALTH), "back on your feet, good as new")
	for i in 1200:
		if not turf.fighting():
			break
		await get_tree().process_frame

	# ---- Bone Mart takes your branch over
	p.position = Iso.cell_to_world(store.door_cell + Vector2i(0, -2))
	turf.start_defense(0)
	check(turf.fight.target == 0 and turf.enemies().all(func(g): return g.job == Gangster.Job.TAKE_BRANCH), "a raid on your %s" % Brand.WAR.your_branch)
	for i in 3600:
		if not turf.fighting():
			break
		await get_tree().process_frame
	check(war.plots[0] == GangWar.BONE, "nobody stopped them: it's a %s now" % Brand.WAR.bone_branch)
	check(turf.plots[0].nodes.filter(func(n): return n is BranchShelf and not n.ours).size() == 8, "(and looks it)")

	# ---- your gang raids Bone Mart
	Game.money = 5000.0
	for i in 4:
		war.hire()
	await _frames(3)
	for m: Gangster in turf.members.values():
		m.max_hp = 9  # (a tough gang, so the test knows how it ends)
		m.hp = 9
	Game.money = 5000.0
	check(war.send_problem(GangWar.MAIN, false) == "" and war.send_raid(GangWar.MAIN, turf.fighting()), "sent your gang to raid Bone Mart")
	await _frames(2)
	check(turf.fight.kind == "attack" and turf.enemies().size() == war.defenders(GangWar.MAIN), "%d skeletons guard it" % turf.enemies().size())
	for i in 3600:
		if not turf.fighting():
			break
		await get_tree().process_frame
	check(war.rival_closed and Game.money > 5000.0, "your gang won: Bone Mart is closed, and you took $%d from its till" % int(Game.money - 5000.0))
	check(Game.rival_pull([], Brand.SHOPPERS.zombie) == 0.0 and town.rival_sign.textures[0] == Brand.RIVAL.textures.sign_closed, "nobody shops there today (the sign says CLOSED)")
	check(war.send_problem(GangWar.MAIN, false) != "", "and you can't raid it again today")

	# ---- and takes a branch
	await _wait(2.0)
	check(war.send_raid(0, turf.fighting()), "sent your gang to take Bone Mart's branch on the north lot")
	for i in 3600:
		if not turf.fighting():
			break
		await get_tree().process_frame
	check(war.plots[0] == GangWar.YOU, "it's yours again")

	# ---- a raid that goes wrong
	await _wait(2.0)
	for id in turf.members.keys().slice(1):
		war.fire(id)
	await _frames(2)
	var last: Gangster = turf.members.values()[0]
	last.max_hp = 2
	last.hp = 2
	var lost_before := int(Game.stats.raids_lost)
	check(war.send_raid(1, turf.fighting()), "sent one gangster alone to the far north lot")
	for i in 3600:
		if not turf.fighting():
			break
		await get_tree().process_frame
	check(int(Game.stats.raids_lost) == lost_before + 1 and war.plots[1] == GangWar.BONE, "beaten: the branch stays Bone Mart's")
	check(war.ready_gang().is_empty(), "and your gangster is out cold until tomorrow")

	# ---- the end of the day: your branch makes money; next morning
	Game.is_open = false
	Game.minute = Game.CLOSE_MINUTE
	for c in store.customers.duplicate():
		c.queue_free()
	store.customers.clear()
	await _frames(2)
	Game.money = 1000.0
	var wages := Game.all_wages()
	Game.day_over = false
	Game.end_day()
	check(is_equal_approx(Game.money, 1000.0 - wages + war.branch_take()), "closing: your branch made $%d (wages $%d)" % [int(war.branch_take()), int(wages)])
	Game.start_next_day()
	await _frames(3)
	check(not war.rival_closed and town.rival_sign.textures[0] == Brand.RIVAL.textures.sign, "the next morning Bone Mart is open again")
	check(war.ready_gang().size() == war.gang_size() and turf.members.size() == war.gang_size(), "and your gang is back")
	check(not war.raids.is_empty() and war.raids.all(func(r): return int(r[0]) >= GangWar.RAID_FROM and int(r[0]) <= GangWar.RAID_TO), "Bone Mart's gangs will come today at %s" % [war.raids.map(func(r): return Game.time_text(int(r[0])))])

	# ---- saving
	var saved := Game.to_dict()
	var copy := GangWar.new()
	copy.from_dict(saved.war, Game.level)
	check(copy.on and copy.plots == war.plots and copy.gang.size() == war.gang_size() and copy.weapons.keys() == war.weapons.keys() and copy.raids.size() == war.raids.size(),
		"the war is saved: land, gang, weapons, today's raids")

	# ---- first person: the gangsters are there, the weapon's in your hand
	war.weapons["nunchucks"] = true
	turf.start_defense(GangWar.MAIN)
	await _frames(3)
	var fp: FirstPerson = Game.fp
	fp.set_active(true)
	await _frames(fp.RESYNC_EVERY + 3)
	var thugs := 0
	for m: Array in fp._mirrors.values():
		if is_instance_valid(m[0]) and m[0] is Gangster and m[1] == "person" and is_instance_valid(m[2]):
			thugs += 1
	check(thugs >= turf.enemies().size(), "first person: the gangsters are there (%d)" % thugs)
	p.fight_t = 2.0
	check(p.weapon_shown() == "nunchucks", "and the nunchucks are in your hand")
	fp.set_active(false)
	for g in turf.enemies():
		g.go_home(town.rival_door)

	Engine.time_scale = 1.0
	print("RESULT: %d failure%s" % [fails, "" if fails == 1 else "s"])
	get_tree().quit(1 if fails > 0 else 0)


func _dump(turf: Turf) -> void:
	var lines := []
	for g: Gangster in turf.gangsters:
		if is_instance_valid(g):
			lines.append("%s/%s hp%d job%d cell%s spot%s foe%s out%s path%s hold%s pos%s" % [g.gang_name, g.side, g.hp, g.job, g.current_cell(), g.spot, (g.foe.get("gang_name") if g.foe is Gangster else str(g.foe)) if g.foe else "-", g.is_out(), g.path, g.holding, g.position])
	print("  fight=%s  %s" % [turf.fight.get("kind", "-"), "; ".join(lines)])


func _texts(n: Node) -> Array:
	var out := []
	for c in n.find_children("*", "", true, false):
		if c is Label:
			out.append((c as Label).text)
		elif c is Button:
			out.append((c as Button).text)
	return out


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
