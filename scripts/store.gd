class_name Store
extends Node2D
## Builds the store from the text map in brand.gd (Brand.LAYOUT), keeps
## track of furniture (and where build mode is allowed to put it), the
## registers and their checkout lines, deliveries, decor, staff, spills, and
## sends in customers. In the zombie game the store sits in a town
## (Brand.TOWN, see town.gd): shoppers walk in from the edge of town, some
## go to the rival store instead, and the lots next door can be bought to
## make the store bigger.
##
## Map legend
##   #  wall              .  floor            S  shelf
##   F  fridge            L  plant            R  register
##   1-4  checkout line (1 = front of the line)
##   C  computer (stock, prices, product licenses, upgrades, staff)
##   D  delivery zone (boxes appear here)
##   E  entrance / exit door                  P  player start
##   O  the OPEN / CLOSED sign (flip it to start the day)
##   M  mop bucket (zombie game)
##
## This is only the starting layout: in build mode you can add, move and
## sell shelves, fridges, plants, storage racks and extra registers, and
## move the first register (its checkout line comes along), the computer,
## the OPEN sign, the mop bucket and the delivery zone. The door stays put. The top row and left
## column are the tall back walls; the bottom row and right column are drawn
## low so they don't hide the store. Every row must be the same length.

const NO_CELL := Vector2i(-1, -1)
const SIDES := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const CORNERS := [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]
const BASE_MAX_CUSTOMERS := 4  # plus one per store level, up to MAX_CUSTOMERS
const MAX_CUSTOMERS := 10
const EXTRA_CUSTOMERS_PER_REGISTER := 2  # more registers, busier store
const MAX_REGISTERS := 4  # staffed registers...
const MAX_SELF_CHECKOUTS := 4  # ...and self-checkouts
const EXTRA_LINE_SPOTS := 6  # each line can grow this far past its marked spots
const FIRST_CUSTOMER_DELAY := 4.0
const SPAWN_MIN := 7.0
const SPAWN_MAX := 13.0
const PLANT_APPEAL := 0.08  # each plant brings 8% more customers...
const MAX_PLANTS_COUNTED := 6  # ...up to this many plants
const LEVEL_TRAFFIC := 0.1  # each store level brings 10% more customers
const MAX_SPILLS := 14
const SMALL_SOLID := Vector2(11, 6)  # the part of a gravestone or lantern you bump into (half-widths, px)
## Where something tall can stand, from someone's cell, to hide them (see _hides).
const HIDE_OFFSETS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 1),
	Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 1), Vector2i(1, 3), Vector2i(3, 2), Vector2i(2, 3), Vector2i(3, 3)]
const SPILL_SETTLE_MINUTES := 60  # a fresh puddle puts nobody off for an hour (game time)...
const FREE_SPILLS := 2  # ...and nobody minds a couple of old ones (it's a zombie store)...
const SPILL_PENALTY := 0.03  # ...each one after that keeps 3% of customers away...
const MIN_SPILL_TRAFFIC := 0.75  # ...but never more than 25%
## With a town, more shoppers come by, since some of them go to the rival.
## Buy the rival out and they all come to you.
const TOWN_TRAFFIC := 1.5
## Every product you've licensed (beyond the ones you start with) brings
## this many more shoppers, up to VARIETY_MAX.
const VARIETY_TRAFFIC := 0.05
const VARIETY_MAX := 0.5
const LOT_WIDTH := 4  # tiles each lot adds to the store

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const CUSTOMER_SCENE := preload("res://scenes/customer.tscn")
const TILE_DELIVERY := preload("res://assets/sprites/floor_delivery.png")
const TILE_DOORMAT := preload("res://assets/sprites/floor_doormat.png")

var width := 0  # the store's size in tiles (walls included)
var height := 0
var town: Town  # the town outside (null if Brand.TOWN is empty)
var astar := AStarGrid2D.new()
var objects := {}  # cell -> Interactable that blocks the cell
var boxes := {}  # cell -> StockBox
var spills := {}  # cell -> Spill
var shelves: Array[Shelf] = []  # shelves and fridges
var racks: Array[StorageRack] = []
var registers: Array[Register] = []  # [0] is the one that came with the store
var staff: Array[Staff] = []
var floor_cells := {}  # cell -> its character in LAYOUT
var wall_cells := {}  # cell -> [Sprite2D, is_tall]
var delivery_cells: Array[Vector2i] = []  # row by row from its top corner
var delivery_zone: DeliveryZone  # so build mode can pick the zone up and move it
var delivery_size := Vector2i.ONE  # cells along x and y (bigger zones are upgrades)
var delivery_turned := false  # turned a quarter turn in build mode (bigger zones grow that way too)
var line_length := 4  # how many numbered line spots the map has
var door_cell := NO_CELL
var player_start := Vector2i(1, 1)
var register: Register  # the first register
var computer: Computer
var sign: OpenSign
var mop_bucket: MopBucket
var player: Player
var customers: Array[Customer] = []
## Things you can walk up to and use that walk around themselves (the
## rival's spies, see RivalSpy). Their `cell` is wherever they are now.
var movers: Array[Interactable] = []
var pending_deliveries: Array[Dictionary] = []
var spawn_timer := FIRST_CUSTOMER_DELAY
var reachable := {}  # every cell you can walk to from the door
var claims := {}  # box or shelf -> the stocker who's handling it
var _collision := {}  # cell -> CollisionPolygon2D
var _warned_spill := false
static var _told_about_rival := false  # once each time you start the game

## The first register's line (most code only cares about that one).
var line_cells: Array[Vector2i]:
	get:
		if register:
			return register.line_cells
		var none: Array[Vector2i] = []
		return none

@onready var floor_layer: FloorLayer = $Floor
@onready var decals: Node2D = $Decals
@onready var world: Node2D = $World
@onready var collision: StaticBody2D = $Collision
@onready var mood: CanvasModulate = $Mood


func _ready() -> void:
	Game.store = self
	var saved: Dictionary = Saves.pending_store
	Saves.pending_store = {}
	_build(saved.is_empty())
	if saved.is_empty():
		_spawn_player()
		for id in Brand.STARTING_BOXES:
			place_box(id)
	else:
		_load_saved(saved)
	_update_reachable()
	if town:
		town.start()
	_sync_staff()
	Game.store_expanded.connect(expand)
	Game.box_ordered.connect(_on_box_ordered)
	Game.store_opened.connect(_on_store_opened)
	Game.decor_changed.connect(_apply_decor)
	Game.staff_changed.connect(_sync_staff)
	if Saves.pending_next_day:  # saved after the day ended: it's still that night
		Saves.pending_next_day = false
		Game.resume_day_over.call_deferred()
	Saves.save_game.call_deferred()  # marks this slot as the latest played


func _process(delta: float) -> void:
	_update_deliveries(delta)
	_update_customers(delta)
	_update_cutaways()


# ---------------------------------------------------------------- building

## Builds walls, floor and the fixed objects from LAYOUT. Shelves, fridges
## and plants from the map are only added for a new game; a loaded game
## puts back the furniture from the save instead.
func _build(with_furniture := true) -> void:
	var layout: Array = Brand.LAYOUT
	height = layout.size()
	width = (layout[0] as String).length()
	var world_size := Vector2i(width, height)
	if not Brand.TOWN.is_empty():
		world_size = Vector2i((Brand.TOWN[0] as String).length(), Brand.TOWN.size())
	astar.region = Rect2i(Vector2i.ZERO, world_size)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()

	var line := {}
	for y in height:
		var row: String = layout[y]
		assert(row.length() == width, "Every LAYOUT row must be the same length (row %d)" % y)
		for x in width:
			var cell := Vector2i(x, y)
			var ch := row[x]
			if ch == "#":
				_add_wall(cell, x == 0 or y == 0)
				continue
			floor_cells[cell] = ch
			match ch:
				"S":
					if with_furniture:
						add_furniture("shelf", cell)
				"F":
					if with_furniture:
						add_furniture("fridge", cell)
				"L":
					if with_furniture:
						add_furniture("plant", cell)
				"R":
					register = Register.new()
					_add_object(register, cell)
					registers.append(register)
				"C":
					computer = Computer.new()
					_add_object(computer, cell)
				"O":
					sign = OpenSign.new()
					_add_object(sign, cell)
				"M":
					if Brand.SPILLS:
						mop_bucket = MopBucket.new()
						_add_object(mop_bucket, cell)
				"D":
					delivery_cells.append(cell)
					floor_cells[cell] = "."  # the stripes go wherever the zone is
				"E":
					door_cell = cell
				"P":
					player_start = cell
				_:
					if ch.is_valid_int():
						line[int(ch)] = cell

	assert(not delivery_cells.is_empty(), "The map needs a delivery zone (D)")
	var lo := delivery_cells[0]
	var hi := delivery_cells[0]
	for c in delivery_cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	delivery_size = hi - lo + Vector2i.ONE  # the zone is the rectangle around the D's
	delivery_cells = _rect_cells(lo, delivery_size)
	delivery_zone = DeliveryZone.new()
	delivery_zone.cell = lo
	decals.add_child(delivery_zone)
	assert(register != null, "The map needs a register (R)")
	assert(door_cell != NO_CELL, "The map needs a door (E)")
	var keys := line.keys()
	keys.sort()
	var first_line: Array[Vector2i] = []
	for k in keys:
		first_line.append(line[k])
	assert(not first_line.is_empty(), "The map needs a checkout line (1-4)")
	line_length = first_line.size()
	_set_line(register, first_line)

	if not Brand.TOWN.is_empty():
		town = Town.new()
		add_child(town)
		town.build(self)
		for k in range(1, Game.expansions + 1):
			_open_lot(k)

	# Invisible walls just outside the map (or the town) so nobody walks off it.
	for x in range(-1, world_size.x + 1):
		_add_collision_poly(Vector2i(x, -1))
		_add_collision_poly(Vector2i(x, world_size.y))
	for y in world_size.y:
		_add_collision_poly(Vector2i(-1, y))
		_add_collision_poly(Vector2i(world_size.x, y))
	_apply_decor()


## Lot k next door becomes part of the store: the old side wall comes
## down, the lot gets a floor and new walls go up around it.
func _open_lot(k: int) -> void:
	if town == null or k >= town.lots.size():
		return
	var cells: Array = town.lots[k]
	var x1 := 0
	for c: Vector2i in cells:
		x1 = maxi(x1, c.x)
	town.open_lot(k)
	var old_wall := width - 1
	for y in range(1, height - 1):
		var c := Vector2i(old_wall, y)
		_remove_wall(c)
		floor_cells[c] = "."
	for c: Vector2i in cells:
		if c.y >= height:
			continue
		if c.y == 0:
			_add_wall(c, true)
		elif c.y == height - 1 or c.x == x1:
			_add_wall(c, false)
		else:
			floor_cells[c] = "."
			_make_walkable(c)
	width = x1 + 1


func _remove_wall(cell: Vector2i) -> void:
	if wall_cells.has(cell):
		(wall_cells[cell][0] as Sprite2D).queue_free()
		wall_cells.erase(cell)
	_make_walkable(cell)


## Bought the next lot (Game.buy_expansion): make the store bigger.
func expand() -> void:
	_open_lot(Game.expansions)
	_apply_decor()
	$Lights.rebuild()
	layout_changed()


func _add_wall(cell: Vector2i, tall: bool) -> void:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.position = Iso.cell_to_world(cell)
	world.add_child(sprite)
	wall_cells[cell] = [sprite, tall]
	_make_solid(cell)
	if Game.WALL_COLORS.size() > 0 and is_inside_tree():
		var color: String = Game.WALL_COLORS[Game.wall_color].id
		sprite.texture = load("res://assets/sprites/wall_%s_%s.png" % [color, "tall" if tall else "low"])
		sprite.offset = Vector2(-32, -(sprite.texture.get_height() - 16))


## Draws the floor and walls in the colors picked in build mode.
func _apply_decor() -> void:
	var style: String = Game.FLOOR_STYLES[Game.floor_style].id
	var tiles: Array[Texture2D] = []
	for variant in ["a", "b", "stain"]:
		tiles.append(load("res://assets/sprites/floor_%s_%s.png" % [style, variant]))
	floor_layer.clear()
	if town:
		town.add_ground_tiles(floor_layer)
	for cell: Vector2i in floor_cells:
		floor_layer.add_tile(_floor_texture(cell, floor_cells[cell], tiles), cell)

	var color: String = Game.WALL_COLORS[Game.wall_color].id
	var tall: Texture2D = load("res://assets/sprites/wall_%s_tall.png" % color)
	var low: Texture2D = load("res://assets/sprites/wall_%s_low.png" % color)
	for cell: Vector2i in wall_cells:
		var sprite: Sprite2D = wall_cells[cell][0]
		sprite.texture = tall if wall_cells[cell][1] else low
		sprite.offset = Vector2(-32, -(sprite.texture.get_height() - 16))


func _floor_texture(cell: Vector2i, ch: String, tiles: Array[Texture2D]) -> Texture2D:
	if cell in delivery_cells:
		return TILE_DELIVERY
	if ch == "E":
		return TILE_DOORMAT
	if ((cell.x * 73856093) ^ (cell.y * 19349663)) % 13 == 0:
		return tiles[2]
	return tiles[0] if (cell.x + cell.y) % 2 == 0 else tiles[1]


func _add_object(obj: Interactable, cell: Vector2i) -> void:
	world.add_child(obj)
	_put(obj, cell)


## Nobody walks through `cell` (pathfinding goes around it). `small`: only
## a little post in the middle of it blocks you (gravestones, lanterns), so
## you can brush past and slide around it instead of hitting the whole tile.
func _make_solid(cell: Vector2i, small := false) -> void:
	astar.set_point_solid(cell, true)
	if _collision.has(cell):
		_collision[cell].queue_free()
	_collision[cell] = _add_collision_poly(cell, small)


func _make_walkable(cell: Vector2i) -> void:
	astar.set_point_solid(cell, false)
	if _collision.has(cell):
		_collision[cell].queue_free()
		_collision.erase(cell)


func _add_collision_poly(cell: Vector2i, small := false) -> CollisionPolygon2D:
	var c := Iso.cell_to_world(cell)
	var poly := CollisionPolygon2D.new()
	if small:  # a squashed octagon around the foot of the post
		var pts := PackedVector2Array()
		for i in 8:
			var a := TAU * (i + 0.5) / 8.0
			pts.append(c + Vector2(cos(a) * SMALL_SOLID.x, sin(a) * SMALL_SOLID.y))
		poly.polygon = pts
	else:
		poly.polygon = PackedVector2Array([c + Vector2(0, -16), c + Vector2(32, 0), c + Vector2(0, 16), c + Vector2(-32, 0)])
	collision.add_child(poly)
	return poly


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.store = self
	player.position = Iso.cell_to_world(player_start)
	world.add_child(player)


# ---------------------------------------------------------------- saving

## The store's part of a save file: fixtures, furniture, boxes, spills,
## deliveries and the player. (Staff are in Game; boxes they're carrying
## are saved as boxes on the floor.)
func to_dict() -> Dictionary:
	var furniture := []
	for obj: Interactable in objects.values():
		if obj.furniture_id == "" or obj is Register:
			continue
		var f := {"id": obj.furniture_id, "cell": [obj.cell.x, obj.cell.y]}
		if obj.rotation_step != 0:
			f.rot = obj.rotation_step
		if obj is Shelf:
			f.product = obj.product_id
			f.stock = obj.stock
		if obj is StorageRack:
			f.boxes = obj.boxes.map(func(b): return [b.product_id, b.count])
		furniture.append(f)
	var box_list := []
	for box: StockBox in boxes.values():
		box_list.append({"cell": [box.cell.x, box.cell.y], "product": box.product_id, "count": box.count})
	var taken := {}
	for b in box_list:
		taken[_to_cell(b.cell)] = true
	for s in staff:
		if s.carry_count > 0:  # put back on the delivery zone (not wherever they were standing)
			var c := _spare_box_cell(taken)
			if c != NO_CELL:
				taken[c] = true
				box_list.append({"cell": [c.x, c.y], "product": s.carry_product, "count": s.carry_count})
	var deliveries := []
	for d in pending_deliveries:
		deliveries.append({"id": d.id, "time": d.time})
	var spill_list := []
	for sp: Spill in spills.values():
		spill_list.append([sp.cell.x, sp.cell.y, sp.variant, snappedf(sp.age, 0.1)])
	var regs := []
	for r in registers:
		var line := []
		for c in r.line_cells:
			line.append([c.x, c.y])
		regs.append({"id": r.furniture_id if r.furniture_id != "" else "register", "cell": [r.cell.x, r.cell.y], "line": line})
	var anchor := delivery_anchor()
	var zone := {"cell": [anchor.x, anchor.y], "size": [delivery_size.x, delivery_size.y], "turned": delivery_turned}
	var fixtures := {"registers": regs, "delivery": zone}
	for key in ["computer", "sign", "mop_bucket"]:
		var obj: Interactable = get(key)
		if obj:
			fixtures[key] = {"cell": [obj.cell.x, obj.cell.y], "rot": obj.rotation_step}
	var pc := player.current_cell()
	return {
		"fixtures": fixtures,
		"furniture": furniture,
		"boxes": box_list,
		"spills": spill_list,
		"deliveries": deliveries,
		"player": {"cell": [pc.x, pc.y], "carry_product": player.carry_product, "carry_count": player.carry_count, "mop": player.holding_mop},
	}


## Puts back what to_dict() saved. Anything that no longer fits (the map
## changed, a product was removed...) is skipped.
func _load_saved(d: Dictionary) -> void:
	_load_fixtures(d.get("fixtures", {}))
	var lines := all_line_cells()
	for f: Dictionary in d.get("furniture", []):
		var id := str(f.get("id", ""))
		var c := _to_cell(f.get("cell"))
		if not Game.FURNITURE.has(id) or _is_register_kind(id):
			continue
		if not _free_spot(c) or c in lines:
			continue
		var obj := add_furniture(id, c, posmod(int(f.get("rot", 0)), 4))
		var product := str(f.get("product", ""))
		if obj is Shelf and Game.PRODUCTS.has(product) and Game.is_cold(product) == obj.holds_cold():
			obj.product_id = product
			obj.stock = clampi(int(f.get("stock", 0)), 0, Shelf.CAPACITY)
		if obj is StorageRack:
			for v in f.get("boxes", []):
				if v is Array and v.size() >= 2 and Game.PRODUCTS.has(str(v[0])):
					obj.store_box(str(v[0]), maxi(1, int(v[1])))
	reachable = _flood()  # (for finding a spot for boxes that don't fit where they were)
	for b: Dictionary in d.get("boxes", []):
		var c := _to_cell(b.get("cell"))
		var product := str(b.get("product", ""))
		if not Game.PRODUCTS.has(product):
			continue
		if not can_drop_at(c) or objects.has(c):
			c = nearest_drop_cell(c)  # something's there now: the closest free spot
		if c != NO_CELL:
			_create_box(c, product, maxi(1, int(b.get("count", 1))))
	for v in d.get("spills", []):
		if v is Array and v.size() >= 2:
			add_spill(Vector2i(int(v[0]), int(v[1])), int(v[2]) if v.size() > 2 else -1, false,
				float(v[3]) if v.size() > 3 else spill_settle_seconds())  # (older saves: an old puddle)
	for del: Dictionary in d.get("deliveries", []):
		if Game.PRODUCTS.has(str(del.get("id", ""))):
			pending_deliveries.append({"id": str(del.id), "time": float(del.get("time", 0.0)), "warned": false})
	var p: Dictionary = d.get("player", {})
	var pc := _to_cell(p.get("cell"))
	if is_walkable(pc):
		player_start = pc
	_spawn_player()
	var carry := str(p.get("carry_product", ""))
	if Game.PRODUCTS.has(carry) and int(p.get("carry_count", 0)) > 0:
		player.pick_up(carry, int(p.carry_count))
	elif bool(p.get("mop", false)) and mop_bucket:
		player.set_holding_mop(true)


## Puts the registers (and their lines), computer, sign and mop bucket where
## they were saved. They're all picked up first so they can swap places.
func _load_fixtures(fx: Dictionary) -> void:
	if fx.is_empty():
		return  # saved before these could move
	var regs: Array = fx.get("registers", [])
	if regs.is_empty() and fx.has("register"):
		regs = [fx.register]  # saves from before there could be more than one
	var items := {"register": register, "computer": computer, "sign": sign, "mop_bucket": mop_bucket}
	var entries := {"register": regs[0] if not regs.is_empty() else {}}
	for key in ["computer", "sign", "mop_bucket"]:
		entries[key] = fx.get(key, {})
	var home := {}
	for key: String in items:
		var obj: Interactable = items[key]
		if obj:
			home[key] = obj.cell
			_lift(obj)
	# The delivery zone goes first: the rest were saved around it.
	var zd: Dictionary = fx.get("delivery", {})
	var zone := _to_cell(zd.get("cell"))
	var size := _to_cell(zd.get("size"))
	if size.x < 1 or size.y < 1 or size.x > 8 or size.y > 8:
		size = delivery_size
	if zone != NO_CELL and _rect_cells(zone, size).all(func(c): return floor_cells.has(c) and c != door_cell):
		delivery_turned = bool(zd.get("turned", false))
		_set_delivery_zone(zone, size)
		_apply_decor()
	for key: String in items:
		var obj: Interactable = items[key]
		if obj == null:
			continue
		var c := _to_cell(entries[key].get("cell"))
		if not _free_spot(c):
			c = home[key] if _free_spot(home[key]) else _nearest_free_spot(home[key])
		_put(obj, c)
		if key != "register":
			obj.rotation_step = posmod(int(entries[key].get("rot", 0)), 4)
	_restore_line(register, regs[0] if not regs.is_empty() else {})
	for i in range(1, regs.size()):
		var c := _to_cell(regs[i].get("cell"))
		var id := str(regs[i].get("id", "register"))
		if not Game.FURNITURE.has(id) or not _is_register_kind(id):
			id = "register"
		if not _free_spot(c) or c in all_line_cells() or register_count(id) >= register_limit(id):
			continue
		var r: Register = add_furniture(id, c)
		_restore_line(r, regs[i])


func _restore_line(r: Register, entry: Dictionary) -> void:
	var others := all_line_cells(r)
	var saved: Array[Vector2i] = []
	for v in entry.get("line", []):
		var c := _to_cell(v)
		if floor_cells.has(c) and not astar.is_point_solid(c) and c != door_cell and not c in delivery_cells and not c in others:
			saved.append(c)
	if saved.size() == line_length:
		_set_line(r, saved)
	else:
		_set_line(r, _compute_line(r.cell, r.facing, NO_CELL, r))


func _free_spot(c: Vector2i) -> bool:
	return floor_cells.has(c) and not objects.has(c) and c != door_cell and not c in delivery_cells


func _nearest_free_spot(from: Vector2i) -> Vector2i:
	var cells: Array = floor_cells.keys()
	cells.sort_custom(func(a, b): return Vector2(a - from).length() < Vector2(b - from).length())
	var lines := all_line_cells()
	for c: Vector2i in cells:
		if _free_spot(c) and not c in lines:
			return c
	return from


static func _to_cell(v: Variant) -> Vector2i:
	if v is Array and v.size() >= 2:
		return Vector2i(int(v[0]), int(v[1]))
	return NO_CELL


# ---------------------------------------------------------------- furniture

## Creates a piece of furniture (a key of Game.FURNITURE), facing `step`
## (see Interactable.FACINGS; -1 = the usual way). Doesn't charge money or
## check the spot; build mode does that first. A register's line starts on
## the side it faces (or another side, if it doesn't fit there).
func add_furniture(furniture_id: String, cell: Vector2i, step := -1) -> Interactable:
	var obj: Interactable
	match Game.FURNITURE[furniture_id].kind:
		"shelf":
			obj = Shelf.new()
		"fridge":
			obj = Fridge.new()
		"register":
			obj = Register.new()
		"selfcheckout":
			obj = SelfCheckout.new()
		"storage":
			obj = StorageRack.new()
		_:
			obj = Lantern.new() if Game.FURNITURE[furniture_id].has("light") else Decoration.new()
	obj.furniture_id = furniture_id
	if step >= 0:
		obj.rotation_step = step
	_add_object(obj, cell)
	if obj is Shelf:
		shelves.append(obj)
	if obj is StorageRack:
		racks.append(obj)
	if obj is Register:
		registers.append(obj)
		var prefer: Vector2i = Interactable.FACINGS[step] if step >= 0 else register.facing
		_set_line(obj, _compute_line(cell, prefer, NO_CELL, obj))
	return obj


## Moves furniture, a register, the computer, the sign or the mop bucket,
## and turns it to face `step` (-1 = keep its facing). Moving a register
## brings its checkout line along.
func move_object(obj: Interactable, cell: Vector2i, step := -1) -> void:
	var new_line: Array[Vector2i] = []
	if obj is Register:
		new_line = preview_line(cell, obj, step)
	_lift(obj)
	_put(obj, cell)
	if step >= 0:
		obj.rotation_step = step
	if obj is Register and new_line.size() == line_length:
		_set_line(obj, new_line)
	obj.queue_redraw()
	layout_changed()


## Why `obj` can't be turned to face `step` where it stands ("" = it can).
## Turning a register turns its line, which needs room.
func rotate_error(obj: Interactable, step: int) -> String:
	if obj is DeliveryZone:
		if delivery_size.x == delivery_size.y:
			return ""
		return delivery_zone_error(delivery_anchor(), Vector2i(delivery_size.y, delivery_size.x))
	if obj is Register and step != obj.rotation_step:
		var line := _compute_line(obj.cell, Interactable.FACINGS[step], NO_CELL, obj, true)
		if line.size() < line_length:
			return "No room for the checkout line that way"
		var lines := all_line_cells(obj)
		lines.append_array(line)
		if not _layout_ok(obj.cell, true, obj, lines):
			return "The line would block a path that way"
	return ""


## Turns `obj` where it stands (check rotate_error first). The delivery zone
## turns a quarter turn around its top corner.
func rotate_object(obj: Interactable, step: int) -> void:
	step = posmod(step, 4)
	if obj is DeliveryZone:
		delivery_turned = not delivery_turned
		_set_delivery_zone(delivery_anchor(), Vector2i(delivery_size.y, delivery_size.x))
		_apply_decor()
		obj.rotation_step = step
	elif obj is Register:
		var line := _compute_line(obj.cell, Interactable.FACINGS[step], NO_CELL, obj, true)
		if line.size() == line_length:
			_set_line(obj, line)  # (turns the register too)
	else:
		obj.rotation_step = step
	obj.queue_redraw()
	layout_changed()


func move_furniture(obj: Interactable, cell: Vector2i) -> void:
	move_object(obj, cell)


func _lift(obj: Interactable) -> void:
	if objects.get(obj.cell) == obj:
		objects.erase(obj.cell)
		_make_walkable(obj.cell)


func _put(obj: Interactable, cell: Vector2i) -> void:
	obj.cell = cell
	obj.position = Iso.cell_to_world(cell)
	objects[cell] = obj
	_make_solid(cell, obj is Decoration)
	if spills.has(cell):  # furniture covers up a spill
		remove_spill(spills[cell])


## Removes furniture. Anything left on a shelf gets boxed up on the spot.
## Customers in a sold register's line go and find another one.
func remove_furniture(obj: Interactable) -> void:
	objects.erase(obj.cell)
	_make_walkable(obj.cell)
	if obj is Shelf:
		shelves.erase(obj)
		if obj.stock > 0:
			_create_box(obj.cell, obj.product_id, obj.stock)
			obj.stock = 0  # it's in the box now (nobody can take it off the shelf this frame)
	if obj is StorageRack:
		racks.erase(obj)
		var first := true
		var left: Array = obj.boxes.duplicate()
		obj.boxes.clear()  # (so stashing doesn't put them back on this rack)
		for b: StorageRack.Box in left:
			release(b)
			if first:
				_create_box(obj.cell, b.product_id, b.count)
				first = false
			else:
				stash_box(obj.cell, b.product_id, b.count)
	if obj is Register:
		registers.erase(obj)
		obj.release_all()
		if is_instance_valid(obj.cashier):
			obj.cashier.register = null
	obj.queue_free()
	layout_changed()


# ---------------------------------------------------------------- checkout lines

## Uses `cells` as `r`'s checkout line (front first) and points the
## register at it.
func _set_line(r: Register, cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	r.line_cells = cells
	var d: Vector2i = cells[0] - r.cell
	r.facing = d if absi(d.x) + absi(d.y) == 1 else Vector2i(1, 0)
	r.rotation_step = maxi(0, Interactable.FACINGS.find(r.facing))  # the register turns to face its line
	r.queue_redraw()


## Every marked line spot, except `except`'s.
func all_line_cells(except: Register = null) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for r in registers:
		if r != except:
			cells.append_array(r.line_cells)
	return cells


## Where the checkout line would go for a register on `origin`: it starts
## next to the register (trying `prefer` first, then the other sides) and
## runs straight, turning only when something is in the way. `freed` is a
## cell that should count as empty (the register's old spot while moving it).
## `owner` is the register the line is for (its own old line doesn't count
## as in the way). With `fixed`, the line has to start on the `prefer` side.
## Returns fewer cells than needed if the line doesn't fit.
func _compute_line(origin: Vector2i, prefer: Vector2i, freed := NO_CELL, owner: Register = null, fixed := false) -> Array[Vector2i]:
	var blocked := {}
	for c in all_line_cells(owner):
		blocked[c] = true
	var best: Array[Vector2i] = []
	var dirs: Array = [prefer] if fixed else [prefer, Vector2i(-prefer.y, prefer.x), Vector2i(prefer.y, -prefer.x), -prefer]
	for dir: Vector2i in dirs:
		var cells: Array[Vector2i] = []
		var used := {origin: true}
		var tail := origin
		var d := dir
		while cells.size() < line_length:
			var options: Array = [d] if cells.is_empty() else [d, Vector2i(-d.y, d.x), Vector2i(d.y, -d.x)]
			var found := false
			for step: Vector2i in options:
				var c := tail + step
				var open := floor_cells.has(c) and (not astar.is_point_solid(c) or c == freed)
				if open and not used.has(c) and not blocked.has(c) and c != door_cell and not c in delivery_cells:
					cells.append(c)
					used[c] = true
					tail = c
					d = step
					found = true
					break
			if not found:
				break
		if cells.size() == line_length:
			return cells
		if cells.size() > best.size():
			best = cells
	return best


## The checkout line a register would get on `cell`: `r` when moving an
## existing register, null when buying a new one. With `step` (you turned
## it), the line has to start on the side it faces.
func preview_line(cell: Vector2i, r: Register = null, step := -1) -> Array[Vector2i]:
	var fixed := step >= 0
	if r == null:
		return _compute_line(cell, Interactable.FACINGS[step] if fixed else register.facing, NO_CELL, null, fixed)
	if cell == r.cell and (not fixed or step == r.rotation_step):
		return r.line_cells.duplicate()
	return _compute_line(cell, Interactable.FACINGS[step] if fixed else r.facing, r.cell, r, fixed)


## Where a cashier stands to work register `r`: next to it, not in anyone's
## line, preferably on the side away from the line.
func cashier_post(r: Register, who: Staff) -> Vector2i:
	var line_spots := {}
	for reg in registers:
		for c in reg.spots():
			line_spots[c] = true
	var taken := {}
	for s in staff:
		if s != who and s.role == "cashier" and s.post != NO_CELL:
			taken[s.post] = true
	var order: Array = [-r.facing, Vector2i(-r.facing.y, r.facing.x), Vector2i(r.facing.y, -r.facing.x)] + CORNERS
	for dir: Vector2i in order:
		var c := r.cell + dir
		if is_walkable(c) and reachable.has(c) and not line_spots.has(c) and not taken.has(c) \
				and c != door_cell and not c in delivery_cells:
			return c
	return NO_CELL


## Gives a cashier a register that doesn't have one yet (the first register
## first). Returns null if they're all taken.
func assign_register(who: Staff) -> Register:
	for r in registers:
		if r.cashier == who:
			return r
	for r in registers:
		if not is_instance_valid(r.cashier) and not r is SelfCheckout and not r.taken_over:
			r.cashier = who
			return r
	return null


## True for furniture that has a checkout line (registers, self-checkouts).
static func _is_register_kind(furniture_id: String) -> bool:
	return Game.FURNITURE[furniture_id].kind in ["register", "selfcheckout"]


## How many registers (or self-checkouts, for "selfcheckout") the store has.
func register_count(furniture_id: String) -> int:
	var self_service: bool = Game.FURNITURE[furniture_id].kind == "selfcheckout"
	return registers.filter(func(r): return (r is SelfCheckout) == self_service).size()


func register_limit(furniture_id: String) -> int:
	return MAX_SELF_CHECKOUTS if Game.FURNITURE[furniture_id].kind == "selfcheckout" else MAX_REGISTERS


## Why something can't go on `cell` ("" means it can). `furniture_id` is
## what you're buying; when moving something, pass it as `moving` instead
## (its old spot counts as free).
func placement_error(cell: Vector2i, furniture_id: String, moving: Interactable = null, step := -1) -> String:
	if not floor_cells.has(cell):
		return "That's not floor"
	if objects.has(cell) and objects[cell] != moving:
		return "Something is already there"
	if cell == door_cell:
		return "Don't block the door"
	if cell in delivery_cells:
		return "Keep the delivery zone clear"
	var placing_register := moving is Register
	if moving == null and Game.FURNITURE.has(furniture_id):
		placing_register = _is_register_kind(furniture_id)
		if placing_register and register_count(furniture_id) >= register_limit(furniture_id):
			return "You can have up to %d %ss" % [register_limit(furniture_id), Game.FURNITURE[furniture_id].name.to_lower()]
	var other_lines := all_line_cells(moving as Register if moving is Register else null)
	if cell in other_lines:
		return "Keep the checkout line clear"
	var new_line: Array[Vector2i] = []
	if placing_register:
		new_line = preview_line(cell, moving as Register if moving is Register else null, step)
		if new_line.size() < line_length:
			return "No room for the checkout line facing this way" if step >= 0 else "No room for the checkout line here"
	if boxes.has(cell):
		return "There's a box in the way"
	if player and player.current_cell() == cell:
		return "You're standing there"
	for c in customers:
		if c.current_cell() == cell or c.next_cell() == cell:
			return "A %s is in the way" % Brand.SAY.shopper
	for s in staff:
		if s.current_cell() == cell or s.next_cell() == cell:
			return "%s is in the way" % s.staff_name
	for m in movers:
		if is_instance_valid(m) and (m.cell == cell or (m.get("path") is Array and not m.path.is_empty() and m.path[0] == cell)):
			return "%s's spy is in the way" % Brand.RIVAL.name if m is RivalSpy else "Someone is in the way"
	var needs_access := true
	if moving:
		needs_access = not moving is Decoration
	elif Game.FURNITURE.has(furniture_id):
		needs_access = Game.FURNITURE[furniture_id].kind != "decor"
	var lines: Array[Vector2i] = []
	lines.append_array(other_lines)
	lines.append_array(new_line)
	if not _layout_ok(cell, needs_access, moving, lines):
		return "That would block a path"
	return ""


## Checks that, with something new on `cell`, everyone can still get
## everywhere they need to: every checkout line, the delivery zone, every
## box and every shelf, fridge, register and computer.
func _layout_ok(cell: Vector2i, needs_access: bool, moving: Interactable, lines: Array[Vector2i]) -> bool:
	var free := moving.cell if moving else NO_CELL
	var reach := _flood(cell, free)
	var must: Array[Vector2i] = []
	must.append_array(lines)
	must.append_array(delivery_cells)
	for c: Vector2i in boxes:
		must.append(c)
	if player:
		must.append(player.current_cell())
	for c in customers:
		must.append(c.current_cell())
	for s in staff:
		must.append(s.current_cell())
	for m in movers:
		if is_instance_valid(m):
			must.append(m.cell)
	for c in must:
		if not reach.has(c):
			return false
	for obj: Interactable in objects.values():
		if obj == moving or obj is Decoration:
			continue
		if not _has_reachable_neighbor(obj.cell, reach):
			return false
	return not needs_access or _has_reachable_neighbor(cell, reach)


## Every cell you can walk to from the door, treating `blocked` as solid
## and `freed` as walkable.
func _flood(blocked := NO_CELL, freed := NO_CELL) -> Dictionary:
	var seen := {door_cell: true}
	var queue: Array[Vector2i] = [door_cell]
	var i := 0
	while i < queue.size():
		var c := queue[i]
		i += 1
		for dir: Vector2i in SIDES:
			var n := c + dir
			if seen.has(n) or n == blocked or not astar.is_in_boundsv(n):
				continue
			if astar.is_point_solid(n) and n != freed:
				continue
			seen[n] = true
			queue.append(n)
	return seen


func _has_reachable_neighbor(cell: Vector2i, reach: Dictionary) -> bool:
	for dir: Vector2i in SIDES + CORNERS:
		if reach.has(cell + dir):
			return true
	return false


## Call after furniture changes so paths get recalculated.
func layout_changed() -> void:
	_update_reachable()
	for r in registers:
		r.spots_changed()
	for c in customers:
		c.on_layout_changed()
	for s in staff:
		s.on_layout_changed()
	for m in movers:
		if is_instance_valid(m) and m.has_method("on_layout_changed"):
			m.on_layout_changed()
	if player:
		player.on_layout_changed()


func _update_reachable() -> void:
	reachable = _flood()
	var used := {}
	for c in all_line_cells():
		used[c] = true
	for r in registers:
		r.extra_cells = _line_overflow(r, used)


## Extra places to stand in line when a register's marked spots are full.
## The line carries on straight past the last spot and turns along walls
## and shelves. Cells next to a register are left free for cashiers.
func _line_overflow(r: Register, used: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if r.line_cells.size() < 2:
		return cells
	var tail: Vector2i = r.line_cells[-1]
	var dir: Vector2i = r.line_cells[-1] - r.line_cells[-2]
	while cells.size() < EXTRA_LINE_SPOTS:
		var found := false
		for d: Vector2i in [dir, Vector2i(-dir.y, dir.x), Vector2i(dir.y, -dir.x)]:
			var c := tail + d
			if is_walkable(c) and reachable.has(c) and not used.has(c) and c != door_cell \
					and not c in delivery_cells and not _next_to_register(c):
				cells.append(c)
				used[c] = true
				tail = c
				dir = d
				found = true
				break
		if not found:
			break
	return cells


func _next_to_register(c: Vector2i) -> bool:
	for r in registers:
		if Iso.chebyshev(c, r.cell) <= 1:
			return true
	return false


## True if a customer would stand here while waiting in line.
func is_line_spot(cell: Vector2i) -> bool:
	for r in registers:
		if cell in r.spots():
			return true
	return false


func plant_count() -> int:
	var n := 0
	for obj in objects.values():
		if obj is Decoration:
			n += 1
	return n


## How much busier than normal the store is (1.0 = normal).
func traffic_multiplier() -> float:
	var appeal := 1.0 + PLANT_APPEAL * mini(plant_count(), MAX_PLANTS_COUNTED)
	var charm := Game.CHARM_TRAFFIC if Game.has_effect("charm") else 1.0
	var ads := 1.0
	for id in ["billboard", "neon"]:
		if Game.has_upgrade(id):
			ads *= Game.BILLBOARD_TRAFFIC
	return appeal * mess_multiplier() * (1.0 + LEVEL_TRAFFIC * (mini(Game.level, Game.TRAFFIC_LEVELS) - 1)) * (1.0 + variety_bonus()) * charm * ads


## How many shoppers the blood still lets in (1 = all of them).
func mess_multiplier() -> float:
	if Game.has_effect("crucifix"):
		return 1.0  # nobody minds the blood for now
	return maxf(MIN_SPILL_TRAFFIC, 1.0 - SPILL_PENALTY * maxi(0, settled_spills() - FREE_SPILLS))


## Puddles that have been on the floor long enough to put shoppers off.
func settled_spills() -> int:
	var n := 0
	for sp: Spill in spills.values():
		if sp.is_settled():
			n += 1
	return n


## Real seconds of open time before a puddle starts putting shoppers off.
static func spill_settle_seconds() -> float:
	return SPILL_SETTLE_MINUTES * Game.SECONDS_PER_GAME_MINUTE


## Extra shoppers for selling lots of different things (0.15 = 15% more).
static func variety_bonus() -> float:
	var extra := Game.unlocked_ids().filter(func(id): return float(Game.PRODUCTS[id].license) > 0.0).size()
	return minf(VARIETY_MAX, VARIETY_TRAFFIC * extra)


# ---------------------------------------------------------------- queries

func is_walkable(cell: Vector2i) -> bool:
	return astar.is_in_boundsv(cell) and not astar.is_point_solid(cell)


func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not is_walkable(from) or not is_walkable(to):
		var none: Array[Vector2i] = []
		return none
	return astar.get_id_path(from, to)


## A cell next to `target` that you can walk to, to stand on while using
## it. Prefers cells close to `near`; `jitter` adds randomness so customers
## spread out.
func stand_cell_for(target: Vector2i, near: Vector2i, jitter := 0.0) -> Vector2i:
	var best := NO_CELL
	var best_d := INF
	for dirs in [SIDES, CORNERS]:
		for dir: Vector2i in dirs:
			var c := target + dir
			if not is_walkable(c) or not reachable.has(c):
				continue
			var d := Vector2(c - near).length() + randf() * jitter
			if d < best_d:
				best_d = d
				best = c
		if best != NO_CELL:
			return best
	return best


## Everything usable on or next to `cell`.
func interactables_near(cell: Vector2i) -> Array[Interactable]:
	var found: Array[Interactable] = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var c := cell + Vector2i(dx, dy)
			if objects.has(c):
				found.append(objects[c])
			if boxes.has(c):
				found.append(boxes[c])
			if spills.has(c):
				found.append(spills[c])
			if town and town.objects.has(c):
				found.append(town.objects[c])
	for m in movers:
		if is_instance_valid(m) and Iso.chebyshev(m.cell, cell) <= 1:
			found.append(m)
	return found


## The object drawn at a tapped/clicked world position (frontmost wins;
## spills on the floor only count if nothing else is there, unless
## `prefer_spills` is set, e.g. while holding the mop).
func interactable_at_point(p: Vector2, prefer_spills := false) -> Interactable:
	if prefer_spills:
		for sp: Spill in spills.values():
			if sp.get_pick_rect().has_point(p - sp.position):
				return sp
	var best: Interactable = null
	var all: Array = objects.values() + boxes.values()
	if town:
		all.append_array(town.objects.values())
	for m in movers:
		if is_instance_valid(m):
			all.append(m)
	for obj: Interactable in all:
		if obj.get_pick_rect().has_point(p - obj.position):
			if best == null or obj.position.y > best.position.y:
				best = obj
	if best == null:
		for sp: Spill in spills.values():
			if sp.get_pick_rect().has_point(p - sp.position):
				return sp
	return best


func shelves_with(product_id: String) -> Array[Shelf]:
	var found: Array[Shelf] = []
	for s in shelves:
		if s.product_id == product_id and s.stock > 0:
			found.append(s)
	return found


## The best shelf for a stocker to put `product_id` on: of the shelves
## labeled for it, the emptiest (then the closest); a new, unlabeled shelf
## only if none of those has room. Skips shelves another stocker is already
## filling and ones nobody can get to.
func best_shelf_for(product_id: String, from: Vector2, who: Staff) -> Shelf:
	if not Game.staff_stock(product_id):
		return null  # its Stock switch is off (Stock & Prices)
	var best: Shelf = null
	var best_score := INF
	var from_cell := Iso.world_to_cell(from)
	for s in shelves:
		if not s.accepts(product_id) or s.stock >= Shelf.CAPACITY or is_claimed(s, who):
			continue
		if s.product_id == "" and not Game.fill_empty_shelves:
			continue  # the Staff app says: only shelves that already have a label
		if stand_cell_for(s.cell, from_cell) == NO_CELL:
			continue
		var rank := 2  # an empty shelf with no label yet: last
		if s.product_id == product_id:
			rank = 0
		var score := rank * 100000.0 + s.stock * 2000.0 + from.distance_to(s.position)
		if score < best_score:
			best_score = score
			best = s
	return best


## How full the shelves labeled for `product_id` are, 0-1 (0 if none are:
## a new product is as needed as an empty one).
func shelf_fill(product_id: String) -> float:
	var room := 0
	var have := 0
	for s in shelves:
		if s.product_id == product_id:
			room += Shelf.CAPACITY
			have += s.stock
	return float(have) / room if room > 0 else 0.0


## Products that are running low (see reorder_list), most urgent first.
func products_running_low(at := Staff.REORDER_AT) -> Array[String]:
	var low: Array[String] = []
	low.assign(reorder_list(at, false).keys())
	return low


## What the general manager should order: product id -> boxes, most urgent
## (emptiest) first. A product needs more once everything we have of it (on
## its shelves, in boxes anywhere, in anyone's hands, ordered) would fill a
## third of the shelves labeled for it (or `at` items, whichever's more), or
## once a whole box would fit on them (with several shelves for one product,
## an empty one gets filled even while the others are full). Then: enough
## boxes to fill those shelves back up (at least one, at most
## Staff.MAX_BOXES_PER_ORDER). And a box of anything you sell that isn't on
## any shelf yet, for each empty shelf with no label.
func reorder_list(at := Staff.REORDER_AT, new_products := true) -> Dictionary:
	var room := {}
	var have := {}
	var free := {false: 0, true: 0}  # empty, unlabeled shelves (true: coolers)
	for s in shelves:
		if s.product_id != "":
			room[s.product_id] = int(room.get(s.product_id, 0)) + Shelf.CAPACITY
			have[s.product_id] = int(have.get(s.product_id, 0)) + s.stock
		elif s.stock == 0:
			free[s.holds_cold()] += 1
	var coming := stock_on_the_way()
	for id: String in coming:
		if have.has(id):
			have[id] += coming[id]
	var share: float = Game.REORDER_POINTS[Game.reorder_at].share  # (the Staff app)
	var ids: Array = room.keys().filter(func(id: String) -> bool:
		if not Game.staff_stock(id):
			return false
		if share < 0.0:  # as soon as a whole box fits (or a third full)
			return have[id] <= maxi(at, floori(room[id] * Staff.REORDER_SHARE)) or room[id] - have[id] >= int(Game.PRODUCTS[id].box_size)
		return have[id] <= maxi(at, floori(room[id] * share)))
	ids.sort_custom(func(a: String, b: String) -> bool: return float(have[a]) / room[a] < float(have[b]) / room[b])
	var out := {}
	for id: String in ids:
		var size: int = Game.PRODUCTS[id].box_size
		var n := 1
		while n < Staff.MAX_BOXES_PER_ORDER and have[id] + (n + 1) * size <= room[id]:
			n += 1
		out[id] = n
	# Licensed, but on no shelf (and none coming): one box each, the most
	# wanted first, while there are empty shelves (or coolers) to put it on.
	if not new_products or not Game.fill_empty_shelves:
		return out
	for id: String in Game.unlocked_ids():
		if not room.has(id) and int(coming.get(id, 0)) > 0:  # its box will take one of those shelves
			free[Game.is_cold(id)] = maxi(0, free[Game.is_cold(id)] - 1)
	var unshelved: Array = Game.unlocked_ids().filter(func(id: String) -> bool:
		return Game.staff_stock(id) and not room.has(id) and int(coming.get(id, 0)) == 0)
	unshelved.sort_custom(func(a: String, b: String) -> bool: return Game.market.demand[a] > Game.market.demand[b])
	for id: String in unshelved:
		var cold := Game.is_cold(id)
		if free[cold] > 0:
			free[cold] -= 1
			out[id] = 1
	return out


## Stock that isn't on the shelves yet: in boxes on the floor or the racks,
## in someone's hands, or ordered. Product id -> items.
func stock_on_the_way() -> Dictionary:
	var n := {}
	for b: StockBox in boxes.values():
		n[b.product_id] = int(n.get(b.product_id, 0)) + b.count
	for r in racks:
		for b: StorageRack.Box in r.boxes:
			n[b.product_id] = int(n.get(b.product_id, 0)) + b.count
	for s in staff:
		if s.carry_count > 0:
			n[s.carry_product] = int(n.get(s.carry_product, 0)) + s.carry_count
	if player and player.is_carrying():
		n[player.carry_product] = int(n.get(player.carry_product, 0)) + player.carry_count
	for d in pending_deliveries:
		n[d.id] = int(n.get(d.id, 0)) + int(Game.PRODUCTS[d.id].box_size)
	return n


## Room on the delivery zone for more boxes (counting the ones on the way).
func delivery_room() -> int:
	var used := pending_deliveries.size()
	for c in delivery_cells:
		if boxes.has(c):
			used += 1
	return delivery_cells.size() - used


## The closest empty spot on the delivery zone (where spare boxes go back).
func free_delivery_cell(from: Vector2i) -> Vector2i:
	var best := NO_CELL
	var best_d := INF
	for c in delivery_cells:
		if can_drop_at(c) and reachable.has(c):
			var d := Vector2(c - from).length()
			if d < best_d:
				best_d = d
				best = c
	return best


## Where a box someone was carrying goes when the game is saved: a free
## spot on the delivery zone, or the floor closest to it.
func _spare_box_cell(taken: Dictionary) -> Vector2i:
	for c in delivery_cells:
		if can_drop_at(c) and not taken.has(c):
			return c
	return nearest_drop_cell(delivery_anchor(), taken)


## The closest free floor cell to put a box down on (not in a line, not on
## another box). `taken` lists extra cells to avoid.
func nearest_drop_cell(from: Vector2i, taken := {}) -> Vector2i:
	var best := NO_CELL
	var best_d := INF
	for c: Vector2i in reachable:
		if not can_drop_at(c) or taken.has(c) or is_line_spot(c) or not floor_cells.has(c):
			continue
		var d := Vector2(c - from).length()
		if c in delivery_cells:
			d -= 0.5  # the stockroom is a good place for spare boxes
		if d < best_d:
			best_d = d
			best = c
	return best


## The nearest storage rack with room for one more box, counting the
## boxes other stockers are already bringing it (racks are shared: two
## stockers can put boxes on the same one).
func rack_with_room(from: Vector2, who: Staff) -> StorageRack:
	var best: StorageRack = null
	var best_d := INF
	for r in racks:
		if rack_room_for(r, who) <= 0 or stand_cell_for(r.cell, Iso.world_to_cell(from)) == NO_CELL:
			continue
		var d := from.distance_to(r.position)
		if d < best_d:
			best_d = d
			best = r
	return best


## Free spots on rack `r` once the other stockers heading there with a box
## have put theirs down.
func rack_room_for(r: StorageRack, who: Staff) -> int:
	var heading := 0
	for st in staff:
		if st != who and st.put_rack == r:
			heading += 1
	return StorageRack.CAPACITY - r.boxes.size() - heading


# ---------------------------------------------------------------- delivery zone

## The delivery zone's top corner (smallest x and y).
func delivery_anchor() -> Vector2i:
	return delivery_cells[0]


## The cells of a `size` rectangle with its top corner on `anchor`, row by row.
static func _rect_cells(anchor: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			cells.append(anchor + Vector2i(x, y))
	return cells


## The delivery zone's cells if its top corner was on `anchor` (and it was
## `size` big; by default the size it is).
func delivery_cells_at(anchor: Vector2i, size := Vector2i.ZERO) -> Array[Vector2i]:
	return _rect_cells(anchor, size if size != Vector2i.ZERO else delivery_size)


## Why the delivery zone can't go with its top corner on `anchor` ("" means
## it can). Boxes already on the zone move with it; other boxes it lands on
## just become part of it.
func delivery_zone_error(anchor: Vector2i, size := Vector2i.ZERO) -> String:
	var lines := all_line_cells()
	for c in delivery_cells_at(anchor, size):
		if not floor_cells.has(c):
			return "It has to fit on the floor"
		if objects.has(c):
			return "%s is in the way" % (objects[c] as Interactable).display_name().capitalize()
		if c == door_cell:
			return "Don't block the door"
		if c in lines:
			return "Keep the checkout line clear"
		if not reachable.has(c):
			return "Nobody could get there"
	return ""


## Moves the delivery zone, along with any boxes waiting on it. `size` with
## its sides swapped turns it too.
func move_delivery_zone(anchor: Vector2i, size := Vector2i.ZERO) -> void:
	if size == Vector2i.ZERO:
		size = delivery_size
	if size != delivery_size:
		delivery_turned = not delivery_turned
	_set_delivery_zone(anchor, size)
	_apply_decor()
	layout_changed()


## The zone as big as a delivery zone upgrade makes it (`size` as listed in
## Brand.UPGRADES, before turning).
func zone_size_for(size: Vector2i) -> Vector2i:
	return Vector2i(size.y, size.x) if delivery_turned else size


## Where the zone's top corner would go to grow it to `size`: it keeps
## covering the spot it's on now, as close to where it is as fits.
## NO_CELL if there's no room around it.
func grow_anchor(size: Vector2i) -> Vector2i:
	var a := delivery_anchor()
	var best := NO_CELL
	var best_d := 999
	for dy in range(-maxi(0, size.y - delivery_size.y), 1):
		for dx in range(-maxi(0, size.x - delivery_size.x), 1):
			var c := a + Vector2i(dx, dy)
			if absi(dx) + absi(dy) < best_d and delivery_zone_error(c, size) == "":
				best = c
				best_d = absi(dx) + absi(dy)
	return best


## Why the zone can't grow to `size` ("" = it can).
func grow_error(size: Vector2i) -> String:
	if size.x * size.y <= delivery_size.x * delivery_size.y:
		return ""
	if grow_anchor(size) != NO_CELL:
		return ""
	# Name what's in the way of growing where it is now.
	return "No room to grow the delivery zone where it is (%s). Clear some space or move it in Build mode" % \
		delivery_zone_error(delivery_anchor(), size).trim_suffix("!").to_lower()


## Makes the zone `size` big (a delivery zone upgrade). False if it can't fit.
func grow_delivery_zone(size: Vector2i) -> bool:
	if size.x * size.y <= delivery_size.x * delivery_size.y:
		return true
	var anchor := grow_anchor(size)
	if anchor == NO_CELL:
		return false
	_set_delivery_zone(anchor, size)
	_apply_decor()
	layout_changed()
	return true


## Puts the zone on `anchor` at `size`. Boxes on it come along: moving
## keeps them where they were on the zone; growing or turning leaves them
## where they are if they're still on it, otherwise they go to a free spot.
func _set_delivery_zone(anchor: Vector2i, size: Vector2i) -> void:
	var old_anchor := delivery_anchor()
	var resized := size != delivery_size
	var new_cells := _rect_cells(anchor, size)
	var moving: Array[StockBox] = []
	for c in delivery_cells:
		if boxes.has(c):
			moving.append(boxes[c])
			boxes.erase(c)
	var free := {}
	for c in new_cells:
		if not boxes.has(c):
			free[c] = true
	var left: Array[StockBox] = []
	for box in moving:
		var want := box.cell if resized else box.cell - old_anchor + anchor
		if free.has(want):
			free.erase(want)
			_place_box_node(box, want)
		else:
			left.append(box)
	delivery_cells = new_cells
	delivery_size = size
	delivery_zone.cell = anchor
	for box in left:
		var spot := NO_CELL
		for c in new_cells:
			if free.has(c):
				spot = c
				break
		if spot == NO_CELL:
			spot = nearest_drop_cell(anchor)
		if spot == NO_CELL:
			spot = box.cell
		free.erase(spot)
		_place_box_node(box, spot)


func _place_box_node(box: StockBox, cell: Vector2i) -> void:
	box.cell = cell
	box.position = Iso.cell_to_world(cell)
	boxes[cell] = box


# ---------------------------------------------------------------- staff

## Makes the people in the store match Game.staff (after hiring, firing or
## loading a save).
func _sync_staff() -> void:
	var wanted := {}
	for entry in Game.staff:
		wanted[entry.id] = entry
	for s in staff.duplicate():
		if not wanted.has(s.id):
			staff.erase(s)
			s.leave()
	var have := {}
	for s in staff:
		have[s.id] = true
	for id in wanted:
		if not have.has(id):
			var s := Staff.new()
			var start := _staff_start(wanted[id].role)
			s.setup(self, wanted[id], start)
			world.add_child(s)
			staff.append(s)
	# A general manager keeps everyone else working faster.
	var managed := Game.staff_count("manager") > 0
	for s in staff:
		s.set_managed(managed and s.role != "manager")


func _staff_start(role: String) -> Vector2i:
	var spot := NO_CELL
	if role == "stocker" and not delivery_cells.is_empty():
		spot = delivery_cells[-1]
	elif role == "janitor" and mop_bucket:
		spot = mop_bucket.cell
	elif role == "manager" and computer:
		spot = computer.cell
	elif role == "spy":
		spot = door_cell
	if spot != NO_CELL:
		var c := stand_cell_for(spot, spot)
		if c != NO_CELL:
			return c
	return door_cell


func claim(obj: Object, who: Staff) -> void:
	claims[obj] = who


func release(obj: Object) -> void:
	claims.erase(obj)


func release_all(who: Staff) -> void:
	for obj in claims.keys():
		if claims[obj] == who:
			claims.erase(obj)


## True if another stocker is already handling `obj`.
func is_claimed(obj: Object, who: Staff) -> bool:
	return claims.has(obj) and claims[obj] != who and is_instance_valid(claims[obj])


# ---------------------------------------------------------------- spills

## A shopper left a puddle on `cell` (zombie game only). `variant` picks the
## puddle sprite (-1 = random).
func add_spill(cell: Vector2i, variant := -1, announce := true, age := 0.0) -> void:
	if not Brand.SPILLS or spills.size() >= MAX_SPILLS or spills.has(cell):
		return
	if not floor_cells.has(cell) or astar.is_point_solid(cell) or cell == door_cell or cell in delivery_cells:
		return
	var sp := Spill.new()
	sp.cell = cell
	sp.position = Iso.cell_to_world(cell)
	sp.variant = variant if variant >= 0 and variant < Spill.TEXTURES.size() else randi() % Spill.TEXTURES.size()
	sp.age = age
	decals.add_child(sp)
	spills[cell] = sp
	if announce and not _warned_spill:
		_warned_spill = true
		Game.message.emit(Brand.SAY.spill)


func remove_spill(sp: Spill) -> void:
	if spills.get(sp.cell) == sp:
		spills.erase(sp.cell)
	sp.queue_free()


# ---------------------------------------------------------------- boxes

## Puts a full box of a product on a free delivery cell.
func place_box(product_id: String) -> bool:
	for c in delivery_cells:
		if not boxes.has(c):
			_create_box(c, product_id, Game.PRODUCTS[product_id].box_size)
			return true
	return false


func can_drop_at(cell: Vector2i) -> bool:
	return is_walkable(cell) and not boxes.has(cell) and cell != door_cell


func drop_box(cell: Vector2i, product_id: String, count: int) -> bool:
	if not can_drop_at(cell):
		return false
	_create_box(cell, product_id, count)
	return true


## Puts a box down somewhere, whatever it takes, so its stock is never lost
## (someone you fire, a rack you sell): the nearest free spot on the floor,
## else a storage rack with room, else on top of a box of the same thing.
## False only if there's truly nowhere.
func stash_box(near: Vector2i, product_id: String, count: int) -> bool:
	if count <= 0:
		return true
	var c := nearest_drop_cell(near)
	if c != NO_CELL:
		return drop_box(c, product_id, count)
	for r in racks:
		if r.store_box(product_id, count):
			return true
	var best: StockBox = null
	for b: StockBox in boxes.values():
		if b.product_id == product_id and (best == null or Vector2(b.cell - near).length() < Vector2(best.cell - near).length()):
			best = b
	if best:
		best.count += count
		best.queue_redraw()
		return true
	for r in racks:
		for rb in r.boxes:
			if rb.product_id == product_id:
				rb.count += count
				r.queue_redraw()
				return true
	return false


func remove_box(box: StockBox) -> void:
	boxes.erase(box.cell)
	claims.erase(box)
	box.queue_free()


func _create_box(cell: Vector2i, product_id: String, count: int) -> void:
	var box := StockBox.new()
	box.product_id = product_id
	box.count = count
	box.cell = cell
	box.position = Iso.cell_to_world(cell)
	world.add_child(box)
	boxes[cell] = box


func _on_box_ordered(product_id: String) -> void:
	pending_deliveries.append({"id": product_id, "time": Game.delivery_seconds(), "warned": false})


func _update_deliveries(delta: float) -> void:
	var waiting: Array[Dictionary] = []
	for d in pending_deliveries:
		d["time"] -= delta
		if d["time"] <= 0.0:
			if place_box(d["id"]):
				Game.message.emit("Delivery arrived: %s" % Game.product_name(d["id"]))
				continue
			if not d["warned"]:
				d["warned"] = true
				Game.message.emit("The delivery zone is full! Move some boxes.")
		waiting.append(d)
	pending_deliveries = waiting


# ---------------------------------------------------------------- customers

func max_customers() -> int:
	var extra := EXTRA_CUSTOMERS_PER_REGISTER * (registers.size() - 1)
	var bigger := clampi(Game.level - 6, 0, 4)  # levels 7 to 10 make room for one more each
	return mini(BASE_MAX_CUSTOMERS + Game.level + extra, MAX_CUSTOMERS + bigger + extra)


func _update_customers(delta: float) -> void:
	if Game.is_open:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = randf_range(SPAWN_MIN, SPAWN_MAX) / traffic_multiplier()
			if town:
				spawn_timer /= TOWN_TRAFFIC
			if not (town and town.turf and town.turf.raid_on_store()):  # (nobody walks into a gang fight)
				_new_shopper()
	elif Game.opened and not Game.day_over and not Game.cutscene and customers.is_empty() and not movers.any(func(m): return is_instance_valid(m) and floor_cells.has(m.cell)):
		Game.end_day()  # closing time and the last customer (and any spy) has left


## Someone in town wants to go shopping. With a rival in town they might go
## there instead: more likely if its prices beat yours, your store is a
## mess, or your store is packed.
func _new_shopper() -> void:
	var kind := Game.pick_shopper_kind()
	var list := _make_shopping_list(kind)
	var full := shoppers_inside() >= max_customers()
	if town and not Game.war.rival_closed and (full or randf() < Game.rival_pull(list, kind)):
		town.send_to_rival(kind)
		Game.record_lost()
	elif not full:
		spawn_customer(kind, list)


## Sends in a shopper. Without a kind, a regular one with a random list.
func spawn_customer(kind := {}, list: Array[Dictionary] = []) -> Customer:
	if kind.is_empty():
		kind = Brand.SHOPPERS.values()[0]
	if list.is_empty():
		list = _make_shopping_list(kind)
	var c: Customer = CUSTOMER_SCENE.instantiate()
	c.setup(self, _arrival_cell(kind), list, kind)
	world.add_child(c)
	customers.append(c)
	return c


## Where shoppers come from: the edge of town (slow ones from the nearest
## spot), or the door if there's no town.
func _arrival_cell(kind: Dictionary) -> Vector2i:
	if town == null or town.spawns.is_empty():
		return door_cell
	if float(kind.get("speed", 1.0)) < 0.75:
		return exit_cell_near(door_cell)
	return town.spawns.pick_random()


## The edge-of-town spot closest to `from` (where shoppers leave town).
func exit_cell_near(from: Vector2i) -> Vector2i:
	if town == null or town.spawns.is_empty():
		return door_cell
	var best: Vector2i = town.spawns[0]
	for c in town.spawns:
		if Vector2(c - from).length() < Vector2(best - from).length():
			best = c
	return best


## Shoppers in the store (not counting ones still walking over from town).
func shoppers_inside() -> int:
	return customers.filter(func(c): return c.state != Customer.State.ARRIVING).size()


func customer_left(c: Customer) -> void:
	customers.erase(c)


## What a shopper wants: a few different products you sell (how many
## depends on the kind of shopper; most want only one or two). Products in
## the news ("Everyone wants...") get picked more often, and so do the
## shopper's favorites (Brand.SHOPPERS likes).
func _make_shopping_list(kind := {}) -> Array[Dictionary]:
	var pool := Game.unlocked_ids()
	var likes: Array = kind.get("likes", [])
	var items: Array = kind.get("items", [1, 4])
	var qty: Array = kind.get("qty", [1, 2])
	var n: int = items[0] + floori(pow(randf(), 1.6) * (items[1] - items[0] + 1))
	var list: Array[Dictionary] = []
	for i in mini(n, pool.size()):
		var id := _weighted_pick(pool, likes)
		pool.erase(id)
		list.append({"id": id, "qty": randi_range(qty[0], qty[1])})
	# Only things you sell: what to license next is for the townsfolk to
	# hint at (Game.townsfolk_says), not for shoppers to ask for.
	return list


func _weighted_pick(ids: Array, likes: Array = []) -> String:
	var weights: Array[float] = []
	var total := 0.0
	for id in ids:
		weights.append(Game.market.demand[id] * (Game.FAVORITE_WANT if likes.has(id) else 1.0))
		total += weights[-1]
	var roll := randf() * total
	for i in ids.size():
		roll -= weights[i]
		if roll <= 0.0:
			return ids[i]
	return ids[-1]


func _on_store_opened() -> void:
	spawn_timer = FIRST_CUSTOMER_DELAY
	_warned_spill = false
	if town and not _told_about_rival:
		_told_about_rival = true
		Game.message.emit("Some %s shop at %s down the street. Walk out the front door to check its prices." % [Brand.SAY.shoppers, Brand.RIVAL.name])


# ---------------------------------------------------------------- visuals

## Fade shelves (and racks) out when someone walks behind them, Project
## Zomboid style: a lot for you, a little for shoppers, staff and spies, so
## nobody seems to vanish into the shelves.
func _update_cutaways() -> void:
	if player == null:
		return
	var p := player.position
	var people: Array[Vector2] = []
	for c in customers:
		if c.modulate.a > 0.2:
			people.append(c.position)
	for s in staff:
		people.append(s.position)
	for m in movers:
		if is_instance_valid(m):
			people.append(m.position)
	var hidden := {}  # shelves and racks someone is behind
	for q in people:
		var c := Iso.world_to_cell(q)
		for o: Vector2i in HIDE_OFFSETS:  # only what could be in front of them
			var obj: Interactable = objects.get(c + o)
			if (obj is Shelf or obj is StorageRack) and _hides(obj.position, q):
				hidden[obj] = true
	for s in shelves:
		s.cutaway = _hides(s.position, p)
		s.see_through = not s.cutaway and hidden.has(s)
	for r in racks:
		r.cutaway = _hides(r.position, p)
		r.see_through = not r.cutaway and hidden.has(r)


## Something tall standing at `at` covers someone standing at `who`.
static func _hides(at: Vector2, who: Vector2) -> bool:
	return who.y < at.y and who.y > at.y - 74 and absf(who.x - at.x) < 36


## Where a shopper stands to take something off `shelf`: in front of it,
## where its stock is, if there's room there (beside its front corners
## counts too); otherwise beside or behind it.
func shelf_stand_cell(shelf: Shelf, near: Vector2i, jitter := 0.0) -> Vector2i:
	var front := shelf.facing_dir()
	var along := Vector2i(absi(front.y), absi(front.x))
	var best := NO_CELL
	var best_d := INF
	for c: Vector2i in [shelf.cell + front, shelf.cell + front + along, shelf.cell + front - along]:
		if not is_walkable(c) or not reachable.has(c):
			continue
		var d := Vector2(c - near).length() + randf() * jitter
		if d < best_d:
			best_d = d
			best = c
	return best if best != NO_CELL else stand_cell_for(shelf.cell, near, jitter)
