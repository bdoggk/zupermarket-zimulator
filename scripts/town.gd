class_name Town
extends Node2D
## The barren town around the store, built from Brand.TOWN: the road and
## sidewalks, wrecked cars, ruins, street lamps, the lots next door (buy
## them in Build mode to make the store bigger), the rival store down the
## street (Brand.RIVAL), and the two little shops across the road
## (Brand.SHOPS: a witch's brewery and a vampire's curio shop). It also
## sends townsfolk walking around: shoppers who picked the rival over you,
## the rival's skeleton staff and its spies (RivalSpy), zombies shambling
## through, skeletons and witches who live here, and vampires after dark.
##
## The town shares the store's grid (Store.astar), so everyone can walk
## between the two. Store cells are marked @ in the map.

const NO_CELL := Vector2i(-1, -1)
const SHAMBLE_MIN := 10.0  # seconds between townsfolk wandering through town
const SHAMBLE_MAX := 24.0
const MAX_SHAMBLERS := 4
const LOCALS := 3  # skeletons who hang around town all the time
const WITCHES := 2  # witches who wander around town all day
const VAMPIRES := 2  # vampires who come out at dusk (Game.NIGHT_MINUTE)
const SKELETON_CHANCE := 0.4  # how many of the passers-by are skeletons...
const WITCH_CHANCE := 0.15  # ...witches...
const VAMPIRE_CHANCE := 0.15  # ...and, after dusk, vampires
const TALK_RANGE := 4  # cells: townsfolk this close tell you what they'd buy...
const TALK_GAP := 20.0  # ...one remark every this many seconds at most...
const TALK_AGAIN := 150.0  # ...and the same person waits this long to say anything again
const LAMP_DAY := 0.14
const LAMP_NIGHT := 0.8
const GROUND := {
	",": ["ground_dirt_a", "ground_dirt_b", "ground_dirt_c", "ground_dirt_d"],
	";": ["ground_grass_a", "ground_grass_b", "ground_grass_c", "ground_grass_d"],
	":": ["ground_path"],
	"_": ["ground_sidewalk_a", "ground_sidewalk_b", "ground_sidewalk_c", "ground_sidewalk_d"],
	"=": ["ground_road_a", "ground_road_b", "ground_road_c", "ground_road_d"],
	"lot": ["ground_lot_a", "ground_lot_b", "ground_lot_c", "ground_lot_d"],
	"-": ["ground_road_line"],
	"b": ["ground_bone_a", "ground_bone_b"],
	"e": ["ground_bone_mat"],
}
## What's on the ground under things that stand on a fixed kind of floor.
const UNDER := {"l": "_", "h": "_", "S": "_", "C": "=", "c": "=", "s": "b", "r": "b", "m": "b", "p": "b", "k": "b"}
const FENCE_X := preload("res://assets/sprites/prop_fence_x.png")
const FENCE_Y := preload("res://assets/sprites/prop_fence_y.png")
const FOR_SALE := preload("res://assets/sprites/prop_for_sale.png")
const WALL_TALL := preload("res://assets/sprites/wall_rival_tall.png")
const WALL_LOW := preload("res://assets/sprites/wall_rival_low.png")

var store: Store
var size := Vector2i.ZERO
var ground := {}  # cell -> Texture2D
var objects := {}  # cell -> Interactable (scenery and the rival's things)
var lots: Array = [[]]  # lots[k] = the cells of lot k (1, 2, 3)
var spawns: Array[Vector2i] = []
var rival_floor := {}  # cells inside the rival store
var rival_door := NO_CELL
var rival_shelves: Array[RivalShelf] = []
var rival_desk: RivalDesk
var rival_sign: Prop
var owner_cell := NO_CELL
var rival_staff: Array[Wanderer] = []
var walkers: Array[Wanderer] = []  # shoppers going to the rival, shamblers
var lamps: Array[PointLight2D] = []
var fires: Array[PointLight2D] = []
var _lot_props := {}  # lot number -> [Prop]
var _tall: Array[Interactable] = []  # fade out when you walk behind them
var _shamble_timer := 6.0
var _player_in_rival := false
var shop_counters := {}  # shop id -> ShopCounter
var shop_keepers := {}  # shop id -> Wanderer
var shop_floor := {}  # cell -> shop id: inside the little shops (their doors too)
var shop_doors := {}  # shop id -> its door
var _keeper_cells := {}  # shop id -> where its keeper stands
var _in_shop := ""  # the shop you're in (its keeper says hello as you walk in)
var _vampires: Array[Wanderer] = []  # out for the night
var _vampires_out := false
var folk: Array[Wanderer] = []  # townsfolk with a kind (meta "kind": a Brand.SHOPPERS key): they talk
var turf: Turf  # the land east of Bone Mart and the gang war (P in the map)
var _talk_timer := 6.0
var _clock := 0.0


## Builds everything outside the store. Called by the store while it
## builds itself; `start` runs once the store is ready.
func build(s: Store) -> void:
	store = s
	var rows: Array = Brand.TOWN
	size = Vector2i((rows[0] as String).length(), rows.size())
	for c in Brand.TOWN_SPAWNS:
		spawns.append(c)
	var rival_min := Vector2i(size.x, size.y)
	for y in size.y:
		for x in size.x:
			if (rows[y] as String)[x] == "#":
				rival_min = Vector2i(mini(rival_min.x, x), mini(rival_min.y, y))
	var shops := shop_layout(rows)
	var plot_cells: Array[Vector2i] = []
	for y in size.y:
		var row: String = rows[y]
		assert(row.length() == size.x, "Every TOWN row must be the same length (row %d)" % y)
		for x in size.x:
			var cell := Vector2i(x, y)
			var ch := row[x]
			if ch == "@":
				continue
			if ch == "P":
				plot_cells.append(cell)  # (the Turf builds these)
				continue
			if ch.is_valid_int():
				var k := int(ch)
				while lots.size() <= k:
					lots.append([])
				lots[k].append(cell)
				continue
			var part := shop_part(ch)
			if ch != "#" and not (not part.is_empty() and part[1] == "wall"):
				ground[cell] = ground_texture(under(ch, cell, rows), cell)
			if not part.is_empty():
				_shop_piece(part[0], part[1], cell, shops[part[0]])
				continue
			match ch:
				"#":
					_wall(cell, cell.x == rival_min.x or cell.y == rival_min.y)
				"e":
					rival_door = cell
					rival_floor[cell] = true
				"b":
					rival_floor[cell] = true
				"m":
					owner_cell = cell
					rival_floor[cell] = true
				"s":
					var sh := RivalShelf.new()
					_place(sh, cell, true)
					rival_shelves.append(sh)
				"r", "p":
					var d := RivalDesk.new()
					d.is_board = ch == "p"
					d.texture = load("res://assets/sprites/%s.png" % ("rival_board" if d.is_board else "rival_counter"))
					_place(d, cell, false)
					if not d.is_board:
						rival_desk = d
				"k":
					_prop(cell, [prop_sprite(ch, cell)])
				"S":
					rival_sign = _prop(cell, [], Brand.RIVAL.slogan, true)
					rival_sign.textures = [Brand.RIVAL.textures.sign_closed if Game.war.rival_closed else Brand.RIVAL.textures.sign]
				"T":
					_prop(cell, [prop_sprite(ch, cell)], "", true)
				"C":
					_car(cell)
				"l":
					var lamp := _prop(cell, ["prop_lamp"], "", true)
					lamps.append(lamp.add_light(Color(1.0, 0.86, 0.6), Vector2(12, 2), LAMP_NIGHT, 2.6))
				"x", "w", "h", "g", "v":
					_prop(cell, [prop_sprite(ch, cell)])
				"B":
					var barrel := _prop(cell, ["prop_barrel"])
					fires.append(barrel.add_light(Color(1.0, 0.55, 0.25), Vector2(0, -6), 0.7, 1.7))
					barrel.flicker = true
				"c":
					store._make_solid(cell)  # the front half of a car
				"Q":
					_prop(cell, ["prop_coffin"], "A coffin. Something inside is snoring.", true)
				"K":
					var pot := _prop(cell, ["prop_cauldron"], "Something green is bubbling in the cauldron.")
					fires.append(pot.add_light(Color(0.45, 1.0, 0.4), Vector2(0, -14), 0.8, 1.6))
					pot.flicker = true
	_build_lots()
	if not plot_cells.is_empty():
		turf = Turf.new()
		add_child(turf)
		turf.setup(self, plot_cells)


## One piece of a little shop (Brand.SHOPS): `part` is which of its map
## letters this is. `info` is where its pieces are (shop_layout).
func _shop_piece(id: String, part: String, cell: Vector2i, info: Dictionary) -> void:
	var shop: Dictionary = Brand.SHOPS[id]
	var look: String = shop.look
	match part:
		"wall":
			var tall := shop_wall_tall(id, info, cell)
			_prop(cell, ["wall_%s_%s" % [look, "tall" if tall else "low"]], "", tall)  # tall ones fade when you're behind them
		"floor":
			shop_floor[cell] = id
		"door":
			shop_floor[cell] = id
			shop_doors[id] = cell
			store.world.add_child(shop_sign(id, cell))
		"shelf":
			_prop(cell, ["shop_shelf_" + look], str(shop.get("shelf_text", "")), true)
		"map":
			var counter := ShopCounter.new()
			counter.shop = id
			counter.texture = load("res://assets/sprites/shop_counter_%s.png" % look)
			counter.rotation_step = counter_step(info)
			_place(counter, cell, false)
			shop_counters[id] = counter
			var glow := PointLight2D.new()  # a warm light over the counter
			glow.texture = StoreLights.glow_texture()
			glow.texture_scale = 2.2
			glow.scale = Vector2(1.0, 0.6)
			glow.color = shop.light
			glow.energy = 0.75
			glow.blend_mode = Light2D.BLEND_MODE_ADD
			glow.position = Vector2(0, -26)
			counter.add_child(glow)
			fires.append(glow)
		"keeper_map":
			_keeper_cells[id] = cell
			store._make_solid(cell)


## The name board over shop `id`'s door at `door`.
static func shop_sign(id: String, door: Vector2i) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/shop_sign_%s.png" % Brand.SHOPS[id].look)
	s.centered = false
	s.offset = Vector2(-64, -88)
	s.position = Iso.cell_to_world(door)
	return s


## Which shop map letter `ch` is (Brand.SHOPS) and what it is there:
## ["curios", "wall"], ["brewery", "map"] (its counter)... [] if none.
static func shop_part(ch: String) -> Array:
	for id: String in Brand.SHOPS:
		var shop: Dictionary = Brand.SHOPS[id]
		for part: String in ["wall", "floor", "door", "shelf", "map", "keeper_map"]:
			if str(shop.get(part, "")) == ch:
				return [id, part]
	return []


## Where each shop's pieces are in `rows` (Brand.TOWN): the corner of its
## walls (smallest x and y), its door, its counter and its keeper.
static func shop_layout(rows: Array) -> Dictionary:
	var out := {}
	for id: String in Brand.SHOPS:
		out[id] = {"min": Vector2i(1 << 20, 1 << 20), "door": NO_CELL, "counter": NO_CELL, "keeper": NO_CELL}
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var part := shop_part(row[x])
			if part.is_empty():
				continue
			var info: Dictionary = out[part[0]]
			var c := Vector2i(x, y)
			match part[1]:
				"wall":
					info.min = Vector2i(mini(info.min.x, x), mini(info.min.y, y))
				"door":
					info.door = c
				"map":
					info.counter = c
				"keeper_map":
					info.keeper = c
	return out


## A shop's back walls are tall (its top row, and its left side unless
## `tall_left` is off); the ones facing you are low, so you can see in.
static func shop_wall_tall(id: String, info: Dictionary, cell: Vector2i) -> bool:
	var corner: Vector2i = info.min
	return cell.y == corner.y or (cell.x == corner.x and bool(Brand.SHOPS[id].get("tall_left", true)))


## Which way a shop's counter faces: away from its keeper (Interactable.FACINGS).
static func counter_step(info: Dictionary) -> int:
	var counter: Vector2i = info.counter
	var keeper: Vector2i = info.keeper
	return maxi(0, Interactable.FACINGS.find(counter - keeper))


## Once the store is built: staff the rival and stock its shelves.
func start() -> void:
	Game.day_started.connect(func(_d): refresh_rival_stock())
	Game.war.rival_closed_changed.connect(_on_rival_closed_changed)
	Game.rival_spy_sent.connect(send_rival_spy)
	Settings.changed.connect(_apply_settings)
	refresh_rival_stock()
	if not Game.war.rival_closed:
		_hire_rival_staff()
	for id: String in _keeper_cells:
		var keeper := _walker(Brand.SHOPS[id].keeper_look, _keeper_cells[id], [], 1.0)
		keeper.stay = true
		keeper.modulate.a = 1.0
		if shop_counters.has(id):
			keeper.face(shop_counters[id].position)
		shop_keepers[id] = keeper
	_add_locals()
	_apply_settings()
	if turf:
		turf.start()


func _process(delta: float) -> void:
	var dusk := clampf((Game.minute - 17 * 60) / 180.0, 0.0, 1.0)
	for l in lamps:
		l.energy = lerpf(LAMP_DAY, LAMP_NIGHT, dusk)
	walkers = walkers.filter(func(w): return is_instance_valid(w))
	_shamble_timer -= delta
	if _shamble_timer <= 0.0:
		_shamble_timer = randf_range(SHAMBLE_MIN, SHAMBLE_MAX)
		_send_shambler()
	var p: Player = store.player
	if p == null:
		return
	for obj in _tall:
		obj.cutaway = p.position.y < obj.position.y and p.position.y > obj.position.y - 96.0 \
			and absf(p.position.x - obj.position.x) < 34.0
	var inside := rival_floor.has(p.current_cell())
	if inside and not _player_in_rival and not Game.war.rival_closed and owner_cell != NO_CELL:
		Game.show_popup(Iso.cell_to_world(owner_cell) + Vector2(0, -46), Brand.RIVAL.hello, Color(0.92, 0.9, 0.82))
	_player_in_rival = inside
	var in_shop: String = shop_floor.get(p.current_cell(), "")
	if in_shop != "" and in_shop != _in_shop and shop_keepers.has(in_shop):
		Game.show_popup(shop_keepers[in_shop].position + Vector2(0, -50), Brand.SHOPS[in_shop].hello, Color(0.92, 0.86, 1.0))
	_in_shop = in_shop
	_townsfolk_talk(delta, p)
	var night := Game.minute >= Game.NIGHT_MINUTE
	if night != _vampires_out:
		_vampires_out = night
		if night:
			_vampires_come_out()
		else:  # morning: back to their coffins
			for w in _vampires:
				if is_instance_valid(w) and not w.is_leaving():
					w.leave(spawns.pick_random() if not spawns.is_empty() else Store.NO_CELL)
			_vampires.clear()


## Skeletons, witches and vampires near you in town tell you what they'd
## come in for (see Game.townsfolk_says): one of them every TALK_GAP
## seconds at most.
func _townsfolk_talk(delta: float, p: Player) -> void:
	_clock += delta
	_talk_timer -= delta
	if _talk_timer > 0.0:
		return
	_talk_timer = 1.0  # nobody near: look again in a second
	folk = folk.filter(func(w): return is_instance_valid(w) and not w.is_leaving())
	var here := p.current_cell()
	for w in folk:
		if w.modulate.a < 0.8 or Iso.chebyshev(w.current_cell(), here) > TALK_RANGE:
			continue
		if _clock - float(w.get_meta("said_at", -INF)) < TALK_AGAIN:
			continue
		var line := Game.townsfolk_says(Brand.SHOPPERS.get(w.get_meta("kind"), {}))
		if line == "":
			continue
		w.set_meta("said_at", _clock)
		Game.show_popup(w.position + Vector2(0, -44), line, Color(0.92, 0.86, 1.0))
		_talk_timer = TALK_GAP
		return


func _apply_settings() -> void:
	for l in lamps + fires:
		l.enabled = Settings.lights_enabled()


# ---------------------------------------------------------------- building

## The tile for ground `ch` (a key of GROUND) at `cell`. Also used by the
## main menu's background.
static func ground_texture(ch: String, cell: Vector2i) -> Texture2D:
	var part := shop_part(ch)
	if not part.is_empty():
		var look: String = Brand.SHOPS[part[0]].look
		if part[1] == "door":
			return load("res://assets/sprites/ground_%s_mat.png" % look)
		return load("res://assets/sprites/ground_%s_%s.png" % [look, "ab"[_hash(cell) % 2]])
	var names: Array = GROUND.get(ch, GROUND[","])
	return load("res://assets/sprites/%s.png" % names[_hash(cell) % names.size()])


## The ground under map character `ch`: fixed for some things, otherwise
## whatever bare ground is next to it.
static func under(ch: String, cell: Vector2i, rows: Array) -> String:
	if GROUND.has(ch):
		return ch
	if UNDER.has(ch):
		return UNDER[ch]
	var part := shop_part(ch)
	if not part.is_empty():  # in a shop: its floor (its door has a mat)
		return ch if part[1] in ["floor", "door"] else str(Brand.SHOPS[part[0]].floor)
	var near_shop := ""
	for d: Vector2i in Store.SIDES:
		var n := cell + d
		if n.x >= 0 and n.y >= 0 and n.y < rows.size() and n.x < (rows[n.y] as String).length():
			var nch: String = (rows[n.y] as String)[n.x]
			if nch in [",", ";", ":"]:
				return nch
			var np := shop_part(nch)
			if not np.is_empty() and np[1] != "wall":
				near_shop = np[0]
	if near_shop != "":  # something standing inside a shop (the coffin, the cauldron)
		return str(Brand.SHOPS[near_shop].floor)
	return ","


static func _hash(cell: Vector2i) -> int:
	return absi(hash(cell))


static func variant(pattern: String, count: int, cell: Vector2i) -> String:
	return pattern % (_hash(cell) % count)


## The sprite for a simple piece of scenery in the map ("" if `ch` isn't one).
static func prop_sprite(ch: String, cell: Vector2i) -> String:
	match ch:
		"T":
			return variant("prop_tree_%d", 3, cell)
		"l":
			return "prop_lamp"
		"x":
			return variant("prop_rubble_%d", 2, cell)
		"w":
			return variant("prop_ruin_%d", 3, cell)
		"B":
			return "prop_barrel"
		"h":
			return "prop_hydrant"
		"g":
			return "plant"
		"v":
			return variant("prop_bush_%d", 2, cell)
		"k":
			return "rival_skulls"
	return ""


## Adds a piece of scenery. `texs` are sprite names or textures.
func _prop(cell: Vector2i, texs: Array, text := "", tall := false) -> Prop:
	var list := []
	for t in texs:
		list.append(load("res://assets/sprites/%s.png" % t) if t is String else t)
	var p := Prop.new(list, text)
	p.tall = tall
	_place(p, cell, tall)
	return p


func _place(obj: Interactable, cell: Vector2i, tall: bool) -> void:
	obj.cell = cell
	obj.position = Iso.cell_to_world(cell)
	store.world.add_child(obj)
	objects[cell] = obj
	store._make_solid(cell)
	if tall:
		_tall.append(obj)


## A wrecked car across two tiles (C is the back, the tile after it the front).
func _car(cell: Vector2i) -> void:
	var tex: Texture2D = load("res://assets/sprites/" + variant("prop_car_%d", 3, cell) + ".png")
	var p := Prop.new([tex])
	p.origin = Vector2(64, tex.get_height() - 17)  # drawn from the front tile
	_place(p, cell + Vector2i(1, 0), false)
	objects[cell] = p
	store._make_solid(cell)


func _wall(cell: Vector2i, tall: bool) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = WALL_TALL if tall else WALL_LOW
	sprite.centered = false
	sprite.offset = Vector2(-32, -(sprite.texture.get_height() - 16))
	sprite.position = Iso.cell_to_world(cell)
	store.world.add_child(sprite)
	store._make_solid(cell)


## The lots next door: bare ground behind a chain-link fence, each with a
## FOR SALE sign. Nobody can walk in until you buy one.
func _build_lots() -> void:
	var front := 0
	var right := 0
	for k in range(1, lots.size()):
		for c: Vector2i in lots[k]:
			front = maxi(front, c.y)
			right = maxi(right, c.x)
	for k in range(1, lots.size()):
		_lot_props[k] = []
		if k <= Game.expansions:
			continue  # already part of the store
		var x0 := size.x
		for c: Vector2i in lots[k]:
			x0 = mini(x0, c.x)
		for c: Vector2i in lots[k]:
			ground[c] = ground_texture("lot", c)
			store._make_solid(c)
			var texs := []
			if c.y == front:
				texs.append(FENCE_X)
			if c.x == right:
				texs.append(FENCE_Y)
			if c.y == front and c.x == x0 + 1:
				texs.append(FOR_SALE)
			if texs.is_empty():
				continue
			var p := _prop(c, texs)
			if FOR_SALE in texs:
				var lot := k
				p.prompt_fn = func(): return _lot_prompt(lot)
			_lot_props[k].append(p)


func _lot_prompt(k: int) -> String:
	if k != Game.expansions + 1:
		return "Lot for sale. Buy the one next to the store first."
	var e: Dictionary = Brand.EXPANSIONS[k - 1]
	var when := "" if Game.level >= e.level else ", store level %d" % e.level
	return "Lot for sale: $%d%s. Buy it in Build mode to make the store bigger." % [int(e.cost), when]


## Lot k is part of the store now: take down its fence and sign.
func open_lot(k: int) -> void:
	for p: Prop in _lot_props.get(k, []):
		objects.erase(p.cell)
		_tall.erase(p)
		p.queue_free()
	_lot_props[k] = []
	for c: Vector2i in lots[k]:
		ground.erase(c)


## Adds the town's ground tiles to the floor (darker toward the edge of town).
func add_ground_tiles(layer: FloorLayer) -> void:
	for cell: Vector2i in ground:
		var edge := mini(mini(cell.x, cell.y), mini(size.x - 1 - cell.x, size.y - 1 - cell.y))
		var light: float = [0.35, 0.6, 0.82][edge] if edge < 3 else 1.0
		layer.add_tile(ground[cell], cell, Color(light, light, light))


# ---------------------------------------------------------------- the rival

func _hire_rival_staff() -> void:
	if owner_cell != NO_CELL:
		var boss := _walker(Brand.RIVAL.textures.owner, owner_cell, [], 1.0)
		boss.stay = true
		boss.modulate.a = 1.0
		if rival_desk:
			boss.face(rival_desk.position)
		rival_staff.append(boss)
	var stops := []
	for sh in rival_shelves:
		var c := store.stand_cell_for(sh.cell, sh.cell)
		if c != NO_CELL:
			stops.append([c, randf_range(1.5, 3.5)])
	if not stops.is_empty():
		var stocker := _walker(Brand.RIVAL.textures.stocker, stops[0][0], stops, 1.5)
		stocker.loop = true
		stocker.modulate.a = 1.0
		rival_staff.append(stocker)


## Puts today's products on the rival's shelves (its deal of the day first).
func refresh_rival_stock() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.day * 7919
	var yours: Array = Game.unlocked_ids()
	var others: Array = Game.PRODUCTS.keys().filter(func(id): return not id in yours)
	_shuffle(yours, rng)
	_shuffle(others, rng)
	if Game.rival_deal in yours:
		yours.erase(Game.rival_deal)
		yours.push_front(Game.rival_deal)
	var pool := yours + others
	for i in rival_shelves.size():
		var sh := rival_shelves[i]
		sh.product_id = "" if Game.war.rival_closed else pool[i % pool.size()]
		sh.stock = 0 if Game.war.rival_closed else 5 + rng.randi() % 8
		sh.queue_redraw()


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t


## A shopper who picked the rival: walks in from the edge of town, browses
## a shelf or two, pays at the counter and walks off again.
func send_to_rival(kind: Dictionary) -> Wanderer:
	if rival_door == NO_CELL or rival_shelves.is_empty():
		return null
	var stops := [[rival_door, 0.0]]
	var shelves := rival_shelves.duplicate()
	shelves.shuffle()
	for i in mini(randi_range(1, 2), shelves.size()):
		var c := store.stand_cell_for(shelves[i].cell, rival_door, 1.5)
		if c != NO_CELL:
			stops.append([c, randf_range(0.8, 1.6)])
	if rival_desk:
		var pay := store.stand_cell_for(rival_desk.cell, rival_door, 1.0)
		if pay != NO_CELL and pay != owner_cell:
			stops.append([pay, randf_range(1.5, 2.5)])
	stops.append([rival_door, 0.0])
	stops.append([spawns.pick_random(), 0.0])
	var w := _walker((kind.looks as Array).pick_random(), spawns.pick_random(), stops, Customer.SPEED * kind.speed, _kind_id(kind))
	walkers.append(w)
	return w


## Someone passing through town: in at one edge, a stop or two along the
## way, out at another edge. Half of them are skeletons.
func _send_shambler() -> void:
	var shamblers := walkers.filter(func(w): return w.has_meta("shambler"))
	if shamblers.size() >= MAX_SHAMBLERS or spawns.size() < 2:
		return
	var from: Vector2i = spawns.pick_random()
	var to: Vector2i = spawns.pick_random()
	while to == from:
		to = spawns.pick_random()
	var kind := Game.pick_shopper_kind()
	var r := randf()
	if r < SKELETON_CHANCE:
		kind = Brand.SHOPPERS.skeleton
	elif r < SKELETON_CHANCE + WITCH_CHANCE and Brand.SHOPPERS.has("witch"):
		kind = Brand.SHOPPERS.witch
	elif r < SKELETON_CHANCE + WITCH_CHANCE + VAMPIRE_CHANCE and Brand.SHOPPERS.has("vampire") and Game.minute >= Game.NIGHT_MINUTE:
		kind = Brand.SHOPPERS.vampire
	var stops := [[to, 0.0]]
	for i in randi_range(1, 2):
		var middle := _random_street_cell()
		if middle != NO_CELL:
			stops.push_front([middle, randf_range(2.0, 6.0)])
	var w := _walker((kind.looks as Array).pick_random(), from, stops, 1.6 * kind.speed, _kind_id(kind))
	w.set_meta("shambler", true)
	walkers.append(w)


## A few skeletons and witches who live in town: they stroll around between
## spots on the street, the cemetery and the ruins, all day and all night.
func _add_locals() -> void:
	_add_strollers(Brand.SHOPPERS.skeleton.looks, LOCALS, 1.3, NO_CELL, "skeleton")
	if Brand.SHOPPERS.has("witch"):
		_add_strollers(Brand.SHOPPERS.witch.looks, WITCHES, 1.2, NO_CELL, "witch")


## `count` townsfolk who loop around town (starting somewhere along the way
## unless `from` says where).
func _add_strollers(looks: Array, count: int, speed: float, from := NO_CELL, kind_id := "") -> Array[Wanderer]:
	var out: Array[Wanderer] = []
	for i in count:
		var stops := []
		for j in 4:
			var c := _random_town_cell()
			if c != NO_CELL:
				stops.append([c, randf_range(3.0, 9.0)])
		if stops.size() < 2:
			continue
		var w := _walker(looks[i % looks.size()], from if from != NO_CELL else stops[0][0], stops, speed, kind_id)
		w.loop = true
		if from == NO_CELL:
			w.modulate.a = 1.0
		w.set_meta("local", true)
		out.append(w)
	return out


## Dusk: a couple of vampires come out of the curio shop for the night.
func _vampires_come_out() -> void:
	if not Brand.SHOPPERS.has("vampire"):
		return
	var from: Vector2i = shop_doors.get("curios", spawns.pick_random() if not spawns.is_empty() else NO_CELL)
	_vampires = _add_strollers(Brand.SHOPPERS.vampire.looks, VAMPIRES, 1.4, from, "vampire")


## The rival sends a spy over to your store (Game.rival_spies).
func send_rival_spy() -> RivalSpy:
	if rival_door == NO_CELL or Game.war.rival_closed or not Brand.RIVAL.textures.has("spy"):
		return null
	var spy := RivalSpy.new()
	spy.setup(store, rival_door)
	store.world.add_child(spy)
	store.movers.append(spy)
	return spy


## Somewhere outdoors anyone can walk to (not in either store, not on a lot).
func _random_town_cell() -> Vector2i:
	for i in 40:
		var c := Vector2i(randi_range(1, size.x - 2), randi_range(12, size.y - 2))
		if ground.has(c) and not rival_floor.has(c) and not shop_floor.has(c) and store.is_walkable(c) and store.reachable.has(c) \
				and not (turf and turf.plot_cells.has(c)):
			return c
	return NO_CELL


func _random_street_cell() -> Vector2i:
	for i in 20:
		var c := Vector2i(randi_range(2, size.x - 3), randi_range(12, 20))
		if ground.has(c) and store.is_walkable(c) and store.reachable.has(c):
			return c
	return NO_CELL


## Someone walking around town. `kind_id` (a Brand.SHOPPERS key) for
## townsfolk who can talk to you about what they'd buy.
func _walker(tex: Texture2D, cell: Vector2i, stops: Array, speed: float, kind_id := "") -> Wanderer:
	var w := Wanderer.new()
	w.setup(store, tex, cell, stops, speed)
	store.world.add_child(w)
	if kind_id != "":
		w.set_meta("kind", kind_id)
		folk.append(w)
	return w


static func _kind_id(kind: Dictionary) -> String:
	var id: Variant = Brand.SHOPPERS.find_key(kind)
	return str(id) if id != null else ""


## Your gang smashed Bone Mart up (it's closed for the rest of the day), or
## it's morning and it's open again.
func _on_rival_closed_changed() -> void:
	var closed := Game.war.rival_closed
	if closed:
		for w in rival_staff:
			if is_instance_valid(w):
				w.leave()
				w.stops = [[rival_door, 0.0], [spawns.pick_random(), 0.0]]
		rival_staff.clear()
	elif rival_staff.is_empty():
		_hire_rival_staff()
	refresh_rival_stock()
	if rival_sign:
		rival_sign.textures = [Brand.RIVAL.textures.sign_closed if closed else Brand.RIVAL.textures.sign]
		rival_sign.prompt = "Closed for the day: your gang smashed it up!" if closed else Brand.RIVAL.slogan
		rival_sign.queue_redraw()
