class_name Town
extends Node2D
## The barren town around the store, built from Brand.TOWN: the road and
## sidewalks, wrecked cars, ruins, street lamps, the lots next door (buy
## them in Build mode to make the store bigger) and the rival store down the
## street (Brand.RIVAL), and the market stalls down the path across the
## street (Brand.SHOPS: a witch's brewery and a vampire's curios). It also
## sends townsfolk walking around: shoppers who picked the rival over you,
## the rival's skeleton staff, and zombies shambling through.
##
## The town shares the store's grid (Store.astar), so everyone can walk
## between the two. Store cells are marked @ in the map.

const NO_CELL := Vector2i(-1, -1)
const SHAMBLE_MIN := 10.0  # seconds between townsfolk wandering through town
const SHAMBLE_MAX := 24.0
const MAX_SHAMBLERS := 4
const LOCALS := 3  # skeletons who hang around town all the time
const SKELETON_CHANCE := 0.5  # how many of the passers-by are skeletons
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
var _keeper_cells := {}  # shop id -> where its keeper stands
var _near_shop := ""  # the stall you're standing at (they say hello once)


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
	for y in size.y:
		var row: String = rows[y]
		assert(row.length() == size.x, "Every TOWN row must be the same length (row %d)" % y)
		for x in size.x:
			var cell := Vector2i(x, y)
			var ch := row[x]
			if ch == "@":
				continue
			if ch.is_valid_int():
				var k := int(ch)
				while lots.size() <= k:
					lots.append([])
				lots[k].append(cell)
				continue
			if ch != "#":
				ground[cell] = ground_texture(under(ch, cell, rows), cell)
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
					rival_sign.textures = [Brand.RIVAL.textures.sign_sold if Game.rival_owned else Brand.RIVAL.textures.sign]
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
				_:
					_market_stall(ch, cell)
	_build_lots()


## A market stall's counter, or where its keeper stands (Brand.SHOPS).
func _market_stall(ch: String, cell: Vector2i) -> void:
	for id: String in Brand.SHOPS:
		var shop: Dictionary = Brand.SHOPS[id]
		if ch == shop.map:
			var counter := ShopCounter.new()
			counter.shop = id
			counter.texture = shop.stall
			_place(counter, cell, true)
			shop_counters[id] = counter
			var glow := PointLight2D.new()  # its lantern
			glow.texture = StoreLights.glow_texture()
			glow.texture_scale = 1.4
			glow.scale = Vector2(1.0, 0.6)
			glow.color = shop.light
			glow.energy = 0.7
			glow.blend_mode = Light2D.BLEND_MODE_ADD
			glow.position = Vector2(14, -30)
			counter.add_child(glow)
			fires.append(glow)
		elif ch == shop.keeper_map:
			_keeper_cells[id] = cell
			store._make_solid(cell)


## Once the store is built: staff the rival and stock its shelves.
func start() -> void:
	Game.day_started.connect(func(_d): refresh_rival_stock())
	Game.rival_bought.connect(_on_rival_bought)
	Settings.changed.connect(_apply_settings)
	refresh_rival_stock()
	if not Game.rival_owned:
		_hire_rival_staff()
	for id: String in _keeper_cells:
		var keeper := _walker(Brand.SHOPS[id].keeper_look, _keeper_cells[id], [], 1.0)
		keeper.stay = true
		keeper.modulate.a = 1.0
		if shop_counters.has(id):
			keeper.face(shop_counters[id].position + Vector2(40, 0))
		shop_keepers[id] = keeper
	_add_locals()
	_apply_settings()


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
	if inside and not _player_in_rival and not Game.rival_owned and owner_cell != NO_CELL:
		Game.show_popup(Iso.cell_to_world(owner_cell) + Vector2(0, -46), Brand.RIVAL.hello, Color(0.92, 0.9, 0.82))
	_player_in_rival = inside
	var near := ""
	for id: String in shop_counters:
		if Iso.chebyshev(p.current_cell(), shop_counters[id].cell) <= 1:
			near = id
	if near != "" and near != _near_shop and shop_keepers.has(near):
		Game.show_popup(shop_keepers[near].position + Vector2(0, -50), Brand.SHOPS[near].hello, Color(0.92, 0.86, 1.0))
	_near_shop = near


func _apply_settings() -> void:
	for l in lamps + fires:
		l.enabled = Settings.lights_enabled()


# ---------------------------------------------------------------- building

## The tile for ground `ch` (a key of GROUND) at `cell`. Also used by the
## main menu's background.
static func ground_texture(ch: String, cell: Vector2i) -> Texture2D:
	var names: Array = GROUND.get(ch, GROUND[","])
	return load("res://assets/sprites/%s.png" % names[_hash(cell) % names.size()])


## The ground under map character `ch`: fixed for some things, otherwise
## whatever bare ground is next to it.
static func under(ch: String, cell: Vector2i, rows: Array) -> String:
	if GROUND.has(ch):
		return ch
	if UNDER.has(ch):
		return UNDER[ch]
	for d: Vector2i in Store.SIDES:
		var n := cell + d
		if n.x >= 0 and n.y >= 0 and n.y < rows.size() and n.x < (rows[n.y] as String).length():
			var nch: String = (rows[n.y] as String)[n.x]
			if nch in [",", ";", ":"]:
				return nch
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
		sh.product_id = "" if Game.rival_owned else pool[i % pool.size()]
		sh.stock = 0 if Game.rival_owned else 5 + rng.randi() % 8
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
	var w := _walker((kind.looks as Array).pick_random(), spawns.pick_random(), stops, Customer.SPEED * kind.speed)
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
	var kind: Dictionary = Brand.SHOPPERS.skeleton if randf() < SKELETON_CHANCE else Game.pick_shopper_kind()
	var stops := [[to, 0.0]]
	for i in randi_range(1, 2):
		var middle := _random_street_cell()
		if middle != NO_CELL:
			stops.push_front([middle, randf_range(2.0, 6.0)])
	var w := _walker((kind.looks as Array).pick_random(), from, stops, 1.6 * kind.speed)
	w.set_meta("shambler", true)
	walkers.append(w)


## A few skeletons who live in town: they stroll around between spots on
## the street, the cemetery and the ruins, all day and all night.
func _add_locals() -> void:
	var looks: Array = Brand.SHOPPERS.skeleton.looks
	for i in LOCALS:
		var stops := []
		for j in 4:
			var c := _random_town_cell()
			if c != NO_CELL:
				stops.append([c, randf_range(3.0, 9.0)])
		if stops.size() < 2:
			continue
		var w := _walker(looks[i % looks.size()], stops[0][0], stops, 1.3)
		w.loop = true
		w.modulate.a = 1.0
		w.set_meta("local", true)


## Somewhere outdoors anyone can walk to (not in either store, not on a lot).
func _random_town_cell() -> Vector2i:
	for i in 40:
		var c := Vector2i(randi_range(1, size.x - 2), randi_range(12, size.y - 2))
		if ground.has(c) and not rival_floor.has(c) and store.is_walkable(c) and store.reachable.has(c):
			return c
	return NO_CELL


func _random_street_cell() -> Vector2i:
	for i in 20:
		var c := Vector2i(randi_range(2, size.x - 3), randi_range(12, 20))
		if ground.has(c) and store.is_walkable(c) and store.reachable.has(c):
			return c
	return NO_CELL


func _walker(tex: Texture2D, cell: Vector2i, stops: Array, speed: float) -> Wanderer:
	var w := Wanderer.new()
	w.setup(store, tex, cell, stops, speed)
	store.world.add_child(w)
	return w


func _on_rival_bought() -> void:
	for w in rival_staff:
		if is_instance_valid(w):
			w.leave()
			w.stops = [[rival_door, 0.0], [spawns.pick_random(), 0.0]]
	rival_staff.clear()
	refresh_rival_stock()
	if rival_sign:
		rival_sign.textures = [Brand.RIVAL.textures.sign_sold]
		rival_sign.prompt = "Bought out by you!"
		rival_sign.queue_redraw()
