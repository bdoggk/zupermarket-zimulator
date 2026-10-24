class_name Turf
extends Node2D
## The gang war in town (Game.war, GangWar). Builds the land east of Bone
## Mart (P in Brand.TOWN): an empty lot behind a fence, or a branch store
## (yours or Bone Mart's) with its shelves, counter and crew. And it plays
## out the fighting (Gangster): your gang standing guard outside your
## store, Bone Mart's gangs raiding your store or a branch, and your gang
## raiding Bone Mart or one of its branches. One fight at a time.

const NO_CELL := Vector2i(-1, -1)
const TAKEOVER_SECONDS := 20.0  # Bone Mart's gang holding your branch's counter this long takes it
const RALLY_SECONDS := 10.0  # your gang waits this long at most for everyone before charging
const FIGHT_LIMIT := 180.0  # seconds: a fight still going after this (someone stuck somewhere) just ends
const VISIT_MIN := 10.0  # seconds between townsfolk shopping at a branch
const VISIT_MAX := 22.0
const SOUNDS := {
	"punch": preload("res://assets/sounds/war_punch.wav"),
	"nunchucks": preload("res://assets/sounds/war_nunchucks.wav"),
	"shot": preload("res://assets/sounds/war_shot.wav"),
	"crack": preload("res://assets/sounds/war_crack.wav"),
	"smash": preload("res://assets/sounds/war_smash.wav"),
	"reload": preload("res://assets/sounds/war_reload.wav"),
}

var town: Town
var store: Store
var plots: Array[Dictionary] = []  # see _plot_info
var plot_cells := {}  # every cell of every plot (and its sign) -> plot number
var gangsters: Array[Gangster] = []  # everyone in the war who's out and about
var members := {}  # your gang: GangWar id -> Gangster
var guard_spots: Array[Vector2i] = []  # outside your store, where your gang hangs out
## The fight going on, or {}: {kind: "defend" (Bone Mart raids you) or
## "attack" (you raid it), target (GangWar.MAIN or a plot), bone: [Gangster],
## downed (skeletons knocked out), done (robbed you or took your branch:
## they're leaving), takeover (seconds holding your branch's counter)}.
var fight := {}
static var items_smashed := 0  # stock Bone Mart's gangs have smashed (since the game started: tests use it)
var _visit_timer := 8.0
var _held_at := -1  # the frame a raider last held your branch's counter


## Finds the plots in the town map (P). Called while the town builds.
func setup(t: Town, cells: Array) -> void:
	town = t
	store = t.store
	var left := {}
	for c: Vector2i in cells:
		left[c] = true
	var blocks: Array = []
	for c: Vector2i in cells:
		if not left.has(c):
			continue
		var block: Array[Vector2i] = []
		var queue: Array[Vector2i] = [c]
		left.erase(c)
		while not queue.is_empty():
			var q: Vector2i = queue.pop_back()
			block.append(q)
			for d: Vector2i in Store.SIDES:
				if left.has(q + d):
					left.erase(q + d)
					queue.append(q + d)
		blocks.append(block)
	blocks.sort_custom(func(a: Array, b: Array):
		var ma := _corner(a)
		var mb := _corner(b)
		return ma.y < mb.y or (ma.y == mb.y and ma.x < mb.x))
	for block: Array in blocks:
		plots.append(_plot_info(block))
		for c: Vector2i in block:
			plot_cells[c] = plots.size() - 1
		plot_cells[plots[-1].sign] = plots.size() - 1
	for i in plots.size():
		dress(i, true)


static func _corner(cells: Array) -> Vector2i:
	var m := Vector2i(1 << 20, 1 << 20)
	for c: Vector2i in cells:
		m = Vector2i(mini(m.x, c.x), mini(m.y, c.y))
	return m


## Where everything goes on a plot: {cells, min, north (the road's below
## it), rows (Brand.WAR's branch layout), door, counter, crew, stand (where
## you stand at its counter), shelves, sign, nodes (what's built there now),
## crew_walker}.
func _plot_info(cells: Array) -> Dictionary:
	var lo := _corner(cells)
	var north := lo.y < 12
	var rows: Array = Brand.WAR.branch_north if north else Brand.WAR.branch_south
	var info := {"cells": cells, "min": lo, "north": north, "rows": rows, "shelves": [], "nodes": [], "crew_walker": null,
		"door": NO_CELL, "counter": NO_CELL, "crew": NO_CELL}
	for y in rows.size():
		for x in (rows[y] as String).length():
			var c := lo + Vector2i(x, y)
			match (rows[y] as String)[x]:
				"d":
					info.door = c
				"c":
					info.counter = c
				"k":
					info.crew = c
				"s":
					info.shelves.append(c)
	info.stand = info.counter + Vector2i(0, 1)  # in front of the counter (it faces down-left)
	info.outside = info.door + (Vector2i(0, 1) if north else Vector2i(0, -1))
	info.sign = lo + Vector2i(5, 8) if north else lo + Vector2i(5, -1)
	return info


## Builds plot `i` for whoever owns it now: an empty lot for sale, or a
## branch store. `building` while the town is first built (the store draws
## the floor and works out the paths itself afterwards).
func dress(i: int, building := false) -> void:
	var info: Dictionary = plots[i]
	for n: Node in info.nodes:
		if is_instance_valid(n):
			if n is Interactable and town.objects.get((n as Interactable).cell) == n:
				town.objects.erase((n as Interactable).cell)
			town._tall.erase(n)
			n.queue_free()
	info.nodes = []
	if is_instance_valid(info.crew_walker):
		info.crew_walker.queue_free()
	info.crew_walker = null
	for c: Vector2i in info.cells:
		town.ground.erase(c)
		store._make_walkable(c)
	if town.objects.has(info.sign):
		town.objects.erase(info.sign)
	store._make_walkable(info.sign)
	var who: String = Game.war.plots[i] if i < Game.war.plots.size() else ""
	if who == "":
		_build_lot(i, info)
	else:
		_build_branch(i, info, who == GangWar.YOU)
	if not building:
		if who != "":
			_staff_branch(i)
		store._apply_decor()
		store.layout_changed()


## An empty lot: bare ground behind a fence, with a FOR SALE sign out front.
func _build_lot(i: int, info: Dictionary) -> void:
	var lo: Vector2i = info.min
	var hi: Vector2i = lo + Vector2i(7, 7)
	var front_y: int = hi.y if info.north else lo.y
	for c: Vector2i in info.cells:
		town.ground[c] = Town.ground_texture("lot", c)
		store._make_solid(c)
		var texs := []
		if c.y == lo.y or c.y == hi.y:
			texs.append(Town.FENCE_X)
		if c.x == lo.x or c.x == hi.x:
			texs.append(Town.FENCE_Y)
		if c.y == front_y and c.x == lo.x + 2:
			texs.append(Town.FOR_SALE)
		if texs.is_empty():
			continue
		var p := town._prop(c, texs)
		if Town.FOR_SALE in texs:
			var plot := i
			p.prompt_fn = func(): return _lot_prompt(plot)
		info.nodes.append(p)


func _lot_prompt(i: int) -> String:
	if not Game.war.on:
		return Brand.WAR.land_before
	return Brand.WAR.land_for_sale % Game.cash(Game.war.plot_cost()).trim_suffix(".00")


## A branch store: walls, a floor, shelves of stock, a counter and a sign.
func _build_branch(i: int, info: Dictionary, ours: bool) -> void:
	var rows: Array = info.rows
	var lo: Vector2i = info.min
	var tall_tex: Texture2D
	var low_tex: Texture2D
	if ours:
		var color: String = Game.WALL_COLORS[Game.wall_color].id
		tall_tex = load("res://assets/sprites/wall_%s_tall.png" % color)
		low_tex = load("res://assets/sprites/wall_%s_low.png" % color)
	else:
		tall_tex = Town.WALL_TALL
		low_tex = Town.WALL_LOW
	var style: String = Game.FLOOR_STYLES[Game.floor_style].id
	var products := _shelf_products(ours, i)
	for y in rows.size():
		for x in (rows[y] as String).length():
			var c := lo + Vector2i(x, y)
			var ch := (rows[y] as String)[x]
			if ch == "#":
				var tall := y == 0 or x == 0
				var wall := town._prop(c, [tall_tex if tall else low_tex], "", tall)
				info.nodes.append(wall)
				continue
			if ch == "d":
				town.ground[c] = Store.TILE_DOORMAT if ours else Town.ground_texture("e", c)
			elif ours:
				town.ground[c] = load("res://assets/sprites/floor_%s_%s.png" % [style, "ab"[(c.x + c.y) % 2]])
			else:
				town.ground[c] = Town.ground_texture("b", c)
			match ch:
				"s":
					var sh := BranchShelf.new()
					sh.ours = ours
					sh.product_id = products[(info.nodes.size() + c.x) % products.size()] if not products.is_empty() else ""
					sh.stock = 4 + (c.x * 7 + c.y * 3 + Game.day) % 9
					town._place(sh, c, true)
					info.nodes.append(sh)
				"c":
					var counter: Interactable
					if ours:
						var p := Prop.new([load("res://assets/sprites/register.png")])
						p.prompt_fn = func(): return Brand.WAR.your_branch_says % [Brand.WAR.your_branch, int(Game.war.branch_take())]
						counter = p
					else:
						var d := RivalDesk.new()
						d.texture = load("res://assets/sprites/rival_counter.png")
						counter = d
					town._place(counter, c, false)
					info.nodes.append(counter)
				"k":
					store._make_solid(c)  # (the crew stands here)
	var sign_prop := town._prop(info.sign, [Brand.WAR.textures.your_sign if ours else Brand.WAR.textures.bone_sign],
		"%s on %s" % [Brand.WAR.your_branch if ours else Brand.WAR.bone_branch, GangWar.plot_name(i)], true)
	info.nodes.append(sign_prop)


## Today's stock on a branch's shelves: what you sell (yours), or what Bone
## Mart has (its).
func _shelf_products(ours: bool, i: int) -> Array:
	var ids: Array = Game.unlocked_ids()
	if ids.is_empty():
		ids = Game.PRODUCTS.keys()
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.day * 131 + i * 17 + (1 if ours else 0)
	var out := ids.duplicate()
	Town._shuffle(out, rng)
	return out


## The branch's crew behind its counter.
func _staff_branch(i: int) -> void:
	var info: Dictionary = plots[i]
	if Game.war.plots[i] == "" or info.crew == NO_CELL:
		return
	var ours: bool = Game.war.plots[i] == GangWar.YOU
	var w := town._walker(Brand.WAR.textures.crew if ours else Brand.WAR.textures.bone_crew, info.crew, [], 1.0)
	w.stay = true
	w.modulate.a = 1.0
	w.face(Iso.cell_to_world(info.counter))
	info.crew_walker = w


## Once the store is ready: crews, your gang, and listening for the war.
func start() -> void:
	for i in plots.size():
		_staff_branch(i)
	_find_guard_spots()
	Game.war.plot_changed.connect(func(i): dress(i))
	Game.war.changed.connect(sync_gang)
	Game.war.raid_due.connect(start_defense)
	Game.war.raid_sent.connect(start_attack)
	Game.day_started.connect(func(_d): _restock())
	sync_gang()
	z_index = 60  # (the progress bars over everyone)


func _find_guard_spots() -> void:
	guard_spots.clear()
	var door := store.door_cell
	for dy in [2, 1]:
		for dx in [-2, 2, -3, 3, -4, 4, -5, 5]:
			var c: Vector2i = door + Vector2i(dx, dy)
			if store.is_walkable(c) and store.reachable.has(c) and not store.floor_cells.has(c):
				guard_spots.append(c)


func _restock() -> void:
	for i in plots.size():
		if Game.war.plots[i] != "":
			var products := _shelf_products(Game.war.plots[i] == GangWar.YOU, i)
			var k := 0
			for n: Node in plots[i].nodes:
				if n is BranchShelf and not products.is_empty():
					var sh := n as BranchShelf
					sh.product_id = products[k % products.size()]
					sh.stock = 4 + (sh.cell.x * 7 + sh.cell.y * 3 + Game.day) % 9
					sh.queue_redraw()
					k += 1


# ---------------------------------------------------------------- every frame

func _process(delta: float) -> void:
	gangsters = gangsters.filter(func(g): return is_instance_valid(g))
	if Game.war.on and Game.is_open:
		Game.war.check_raids(fighting())
	if not fight.is_empty():
		_run_fight(delta)
	_visit_timer -= delta
	if _visit_timer <= 0.0:
		_visit_timer = randf_range(VISIT_MIN, VISIT_MAX)
		if Game.is_open:
			_send_visitor()
	queue_redraw()


## A fight is going on (no other raid starts until it's over).
func fighting() -> bool:
	return not fight.is_empty()


## Bone Mart's gang is raiding your store right now.
func raid_on_store() -> bool:
	return not fight.is_empty() and fight.kind == "defend" and int(fight.target) == GangWar.MAIN


## Bone Mart's gangsters still standing.
func enemies() -> Array[Gangster]:
	var out: Array[Gangster] = []
	for g in gangsters:
		if is_instance_valid(g) and g.side == Gangster.BONE and not g.is_out():
			out.append(g)
	return out


## Bone Mart's gangsters within `cells` of `from` (for the Glock).
func enemies_within(from: Vector2i, cells: float) -> Array[Gangster]:
	var out: Array[Gangster] = []
	for g in enemies():
		if Vector2(g.current_cell() - from).length() <= cells:
			out.append(g)
	return out


func _draw() -> void:
	if fight.is_empty() or fight.kind != "defend" or int(fight.target) == GangWar.MAIN:
		return
	var t := float(fight.get("takeover", 0.0))
	if t <= 0.0:
		return
	var info: Dictionary = plots[int(fight.target)]
	var at := Iso.cell_to_world(info.counter) - position + Vector2(0, -70)
	draw_rect(Rect2(at + Vector2(-31, -4), Vector2(62, 9)), Color(0.05, 0.05, 0.07, 0.9))
	draw_rect(Rect2(at + Vector2(-30, -3), Vector2(60 * t / TAKEOVER_SECONDS, 7)), Color(0.9, 0.2, 0.18))


# ---------------------------------------------------------------- your gang

## Your gang in town matches Game.war.gang: whoever's ready stands guard
## outside your store; whoever you fired walks off.
func sync_gang() -> void:
	var ids := {}
	for g: Dictionary in Game.war.gang:
		ids[int(g.id)] = g
	for id: int in members.keys():
		var m: Gangster = members[id]
		if not is_instance_valid(m):
			members.erase(id)
		elif not ids.has(id) and not m.is_out():
			m.retired = true  # (fired: out of the war)
			m.go_home(store.exit_cell_near(m.current_cell()))
			members.erase(id)
	var k := 0
	for g: Dictionary in Game.war.gang:
		var id := int(g.id)
		if members.has(id) or not Game.war.is_ready(g):
			continue
		var spot := _free_guard_spot(k)
		k += 1
		var looks: Array = Brand.WAR.textures.zombie_gang
		var m := _spawn(Gangster.ZOMBIE, str(g.name), looks[int(g.look) % looks.size()], spot)
		m.member_id = id
		m.job = Gangster.Job.GUARD
		m.spot = spot
		m.home = spot
		members[id] = m
		if not fight.is_empty():
			_send_member(m)


func _free_guard_spot(k: int) -> Vector2i:
	var used := {}
	for m: Gangster in members.values():
		if is_instance_valid(m):
			used[m.home] = true
	for c in guard_spots:
		if not used.has(c):
			return c
	return guard_spots[k % guard_spots.size()] if not guard_spots.is_empty() else store.door_cell


func _spawn(side: String, name_text: String, look: Texture2D, at: Vector2i) -> Gangster:
	var g := Gangster.new()
	g.setup(store, self, side, name_text, look, at)
	store.world.add_child(g)
	store.movers.append(g)
	gangsters.append(g)
	return g


## Gone for good (faded away).
func forget(g: Gangster) -> void:
	gangsters.erase(g)
	store.movers.erase(g)
	if members.get(g.member_id) == g:
		members.erase(g.member_id)


# ---------------------------------------------------------------- Bone Mart raids you

## A Bone Mart gang sets off for your store (GangWar.MAIN) or branch `target`.
func start_defense(target: int) -> void:
	if fighting() or town.rival_door == NO_CELL:
		return
	if target != GangWar.MAIN and (target >= plots.size() or Game.war.plots[target] != GangWar.YOU):
		target = GangWar.MAIN
	fight = {"kind": "defend", "target": target, "bone": [], "downed": 0, "done": false, "takeover": 0.0, "in_store": false}
	var names: Array = (Brand.WAR.bone_names as Array).duplicate()
	names.shuffle()
	var looks: Array = Brand.WAR.textures.bone_gang
	for k in Game.war.raid_size():
		var g := _spawn(Gangster.BONE, str(names[k % names.size()]), looks[k % looks.size()], town.rival_door)
		g.home = town.rival_door
		if target == GangWar.MAIN:
			g.job = Gangster.Job.RAID_STORE
		else:
			g.job = Gangster.Job.TAKE_BRANCH
			g.target_plot = target
			g.spot = _spot_near(plots[target].stand, k)
		fight.bone.append(g)
	if target == GangWar.MAIN:
		Game.message.emit(Brand.WAR.raid_coming)
	else:
		Game.message.emit(Brand.WAR.raid_coming_branch % [Brand.WAR.your_branch, GangWar.plot_name(target)])
	Settings.vibrate(0.6, 0.3)
	for m: Gangster in members.values():
		if is_instance_valid(m) and not m.is_out():
			_send_member(m)


## One of your gang runs to the fight.
func _send_member(m: Gangster) -> void:
	if fight.is_empty():
		return
	var target := int(fight.target)
	if fight.kind == "defend":
		m.job = Gangster.Job.RESPOND
		m.spot = store.door_cell + Vector2i(0, 1) if target == GangWar.MAIN else plots[target].outside
	else:
		m.job = Gangster.Job.RAID
		var k := members.values().find(m)
		if bool(fight.get("rallying", false)):  # everyone meets up first, then they go in together
			m.spot = _spot_near(fight.rally, k)
			m.holding = true
		else:
			m.spot = _raid_spot(target, k)
	m.target_plot = target


## A walkable cell near `c` (the k-th one around it), so a gang doesn't
## all stand on one tile.
func _spot_near(c: Vector2i, k: int) -> Vector2i:
	var around: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0)]
	for j in around.size():
		var n: Vector2i = c + around[(k + j) % around.size()]
		if store.is_walkable(n) and store.reachable.has(n):
			return n
	return c


func taking_over(_g: Gangster, _delta: float) -> void:
	_held_at = Engine.get_process_frames()


## Somebody's down. Your gang's are out until tomorrow.
func on_knocked_out(g: Gangster, _by: Node2D) -> void:
	play("crack" if g.side == Gangster.BONE else "punch", g.position)
	Settings.vibrate(0.3, 0.1)
	if g.side == Gangster.ZOMBIE and g.member_id != 0:
		Game.war.knocked_out(g.member_id)
	elif g.side == Gangster.BONE and not fight.is_empty():
		fight.downed = int(fight.downed) + 1


## You hit one of Bone Mart's: the rest of them come for you.
func bone_angry() -> void:
	for g in enemies():
		g.angry = true


func shelf_to_smash(g: Gangster) -> Shelf:
	var taken := {}
	for other: Gangster in fight.get("bone", []):
		if is_instance_valid(other) and other != g and other.smashing != null:
			taken[other.smashing] = true
	var best: Shelf = null
	var best_d := INF
	for s: Shelf in store.shelves:
		if s.stock <= 0 or taken.has(s):
			continue
		var d := Vector2(s.cell - g.current_cell()).length() + randf() * 3.0
		if d < best_d:
			best_d = d
			best = s
	return best


func register_to_rob() -> Register:
	if not fight.is_empty() and bool(fight.done):
		return null
	return store.register


## Smashed up a shelf: its stock is on the floor (gone), and shoppers nearby run.
func smash(g: Gangster, s: Shelf) -> void:
	if s.stock > 0:
		items_smashed += s.stock
		s.stock = 0
		s.queue_redraw()
	Game.show_popup(s.position + Vector2(0, -60), "CRASH!", Color(1.0, 0.55, 0.4))
	play("smash", s.position)
	Settings.vibrate(0.5, 0.2)
	scare_near(g, Gangster.SCARE_RANGE + 2)


func scare_near(g: Gangster, cells: int) -> void:
	if not fight.is_empty() and not bool(fight.in_store):
		fight.in_store = true
		Game.message.emit(Brand.WAR.raid_in)
	for c in store.customers.duplicate():
		if is_instance_valid(c) and Iso.chebyshev(c.current_cell(), g.current_cell()) <= cells:
			c.scare()


## Robbed your register: they've got what they came for and leave.
func rob(_g: Gangster) -> void:
	if fight.is_empty() or bool(fight.done):
		return
	fight.done = true
	Game.war.robbed()
	play("smash", store.register.position)
	_send_home(fight.bone)


## Nothing left to do here: off they go.
func raid_done(g: Gangster) -> void:
	g.go_home(town.rival_door)


## You got knocked out in a fight: Bone Mart's gang helps itself to your till.
func player_knocked_out() -> void:
	Game.message.emit(Brand.WAR.knocked_out)
	if raid_on_store() and not bool(fight.done):
		fight.done = true
		Game.war.robbed()
		_send_home(fight.bone)


func _send_home(list: Array) -> void:
	for g: Gangster in list:
		if is_instance_valid(g) and not g.is_out():
			g.go_home(town.rival_door)


# ---------------------------------------------------------------- you raid Bone Mart

## Sends your gang (everyone who's ready) to Bone Mart (MAIN) or its branch
## `target`, where its skeletons are waiting.
func start_attack(target: int) -> void:
	if fighting():
		return
	fight = {"kind": "attack", "target": target, "bone": [], "downed": 0, "done": false, "takeover": 0.0, "in_store": false,
		"rallying": true, "rally": _rally_spot(target), "rally_t": 0.0}
	var names: Array = (Brand.WAR.bone_names as Array).duplicate()
	names.shuffle()
	var looks: Array = Brand.WAR.textures.bone_gang
	var at: Vector2i = town.rival_door if target == GangWar.MAIN else plots[target].stand
	for k in Game.war.defenders(target):
		var g := _spawn(Gangster.BONE, str(names[k % names.size()]), looks[k % looks.size()], at)
		g.job = Gangster.Job.DEFEND
		g.spot = _defend_spot(target, k)
		g.home = at
		fight.bone.append(g)
	for m: Gangster in members.values():
		if is_instance_valid(m) and not m.is_out():
			_send_member(m)


## Where Bone Mart's skeletons wait for your gang: out front of its door,
## or inside the branch.
func _defend_spot(target: int, k: int) -> Vector2i:
	if target == GangWar.MAIN:
		return _spot_near(town.rival_door + Vector2i(0, 1), k)
	return _spot_near(plots[target].stand + Vector2i(1, 0), k)


## Where your gang meets up before a raid: down the street from the target.
func _rally_spot(target: int) -> Vector2i:
	if target == GangWar.MAIN:
		return _spot_near(town.rival_door + Vector2i(-8, 2), 0)
	var info: Dictionary = plots[target]
	return _spot_near(info.outside + Vector2i(-5, 1 if info.north else -1), 0)


func _raid_spot(target: int, k: int) -> Vector2i:
	if target == GangWar.MAIN:
		return _spot_near(town.rival_door + Vector2i(0, 2), k)
	return _spot_near(plots[target].door, k)


# ---------------------------------------------------------------- how the fight's going

func _run_fight(delta: float) -> void:
	var bone: Array = (fight.bone as Array).filter(func(g): return is_instance_valid(g))
	fight.bone = bone
	fight.t = float(fight.get("t", 0.0)) + delta
	if float(fight.t) > FIGHT_LIMIT:
		for g: Gangster in bone:
			if not g.is_out():
				g.vanish()
		_end_fight()
		return
	var standing := bone.filter(func(g): return not g.is_out())
	if fight.kind == "defend":
		var target := int(fight.target)
		if target != GangWar.MAIN and not bool(fight.done):
			if _held_at >= Engine.get_process_frames() - 1 and standing.any(func(g): return g.foe == null):
				fight.takeover = float(fight.takeover) + delta
				if float(fight.takeover) >= TAKEOVER_SECONDS:
					fight.done = true
					Game.war.branch_lost(target)
					_send_home(standing)
			else:
				fight.takeover = maxf(0.0, float(fight.takeover) - delta * 0.5)
		if target == GangWar.MAIN and not Game.is_open and not bool(fight.done):
			fight.done = true  # closing time: they head back
			_send_home(standing)
		if standing.is_empty():
			if not bool(fight.done):
				Game.war.defended(target, int(fight.downed))
				Settings.vibrate(0.6, 0.3)
			_end_fight()
	else:
		var mine := members.values().filter(func(m): return is_instance_valid(m) and not m.is_out() and m.job == Gangster.Job.RAID)
		if bool(fight.rallying):
			fight.rally_t = float(fight.rally_t) + delta
			var there := mine.all(func(m): return Iso.chebyshev(m.current_cell(), m.spot) <= 1)
			if there or float(fight.rally_t) > RALLY_SECONDS or mine.any(func(m): return m.foe != null):
				fight.rallying = false  # charge!
				var k := 0
				for m: Gangster in mine:
					m.holding = false
					m.spot = _raid_spot(int(fight.target), k)
					k += 1
		if standing.is_empty():
			Game.war.raid_won(int(fight.target), int(fight.downed))
			Settings.vibrate(0.7, 0.35)
			_end_fight()
		elif mine.is_empty():
			Game.war.raid_lost()
			_send_home(standing)
			_end_fight()


func _end_fight() -> void:
	fight = {}
	for m: Gangster in members.values():
		if is_instance_valid(m) and not m.is_out():
			m.foe = null
			m.holding = false
			m.hp = m.max_hp  # (patched up on the way back)
			m.go_home(m.home)


# ---------------------------------------------------------------- the rest

## A townsperson shops at one of the branches (yours or Bone Mart's).
func _send_visitor() -> void:
	var open: Array[int] = []
	for i in plots.size():
		if Game.war.plots[i] != "":
			open.append(i)
	if open.is_empty() or town.spawns.is_empty():
		return
	var info: Dictionary = plots[open.pick_random()]
	var stops := [[info.door, 0.0]]
	var shelves: Array = info.shelves.duplicate()
	shelves.shuffle()
	var stand := store.stand_cell_for(shelves[0], info.door, 1.0) if not shelves.is_empty() else NO_CELL
	if stand != NO_CELL:
		stops.append([stand, randf_range(1.0, 2.0)])
	stops.append([info.stand, randf_range(1.2, 2.0)])
	stops.append([info.door, 0.0])
	stops.append([town.spawns.pick_random(), 0.0])
	var kind := Game.pick_shopper_kind()
	var w := town._walker((kind.looks as Array).pick_random(), town.spawns.pick_random(), stops, Customer.SPEED * float(kind.get("speed", 1.0)))
	town.walkers.append(w)


func play_hit(at: Vector2, side: String) -> void:
	play("punch", at, 0.9 if side == Gangster.BONE else 1.1)


## A sound out in the world (louder the closer you are).
func play(sound: String, at: Vector2, pitch := 1.0) -> void:
	var p := AudioStreamPlayer2D.new()
	p.stream = SOUNDS[sound]
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.max_distance = 1400.0
	p.position = at - position
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
