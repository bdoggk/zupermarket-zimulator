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
const SPILL_PENALTY := 0.08  # each spill keeps 8% of customers away...
const MIN_SPILL_TRAFFIC := 0.4  # ...but never more than 60%
## With a town, more shoppers come by, since some of them go to the rival.
## Buy the rival out and they all come to you.
const TOWN_TRAFFIC := 1.5
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
var delivery_cells: Array[Vector2i] = []
var delivery_zone: DeliveryZone  # so build mode can pick the zone up and move it
var line_length := 4  # how many numbered line spots the map has
var door_cell := NO_CELL
var player_start := Vector2i(1, 1)
var register: Register  # the first register
var computer: Computer
var sign: OpenSign
var mop_bucket: MopBucket
var player: Player
var customers: Array[Customer] = []
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
	Game.rival_bought.connect(_on_rival_bought)
	Game.box_ordered.connect(_on_box_ordered)
	Game.store_opened.connect(_on_store_opened)
	Game.decor_changed.connect(_apply_decor)
	Game.staff_changed.connect(_sync_staff)
	if Saves.pending_next_day:  # saved between days: start the next one
		Saves.pending_next_day = false
		Game.start_next_day.call_deferred()
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
	delivery_zone = DeliveryZone.new()
	delivery_zone.cell = delivery_anchor()
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


func _make_solid(cell: Vector2i) -> void:
	astar.set_point_solid(cell, true)
	if not _collision.has(cell):
		_collision[cell] = _add_collision_poly(cell)


func _make_walkable(cell: Vector2i) -> void:
	astar.set_point_solid(cell, false)
	if _collision.has(cell):
		_collision[cell].queue_free()
		_collision.erase(cell)


func _add_collision_poly(cell: Vector2i) -> CollisionPolygon2D:
	var c := Iso.cell_to_world(cell)
	var poly := CollisionPolygon2D.new()
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
		if s.carry_count > 0:
			var c := nearest_drop_cell(s.current_cell(), taken)
			if c != NO_CELL:
				taken[c] = true
				box_list.append({"cell": [c.x, c.y], "product": s.carry_product, "count": s.carry_count})
	var deliveries := []
	for d in pending_deliveries:
		deliveries.append({"id": d.id, "time": d.time})
	var spill_list := []
	for sp: Spill in spills.values():
		spill_list.append([sp.cell.x, sp.cell.y, sp.variant])
	var regs := []
	for r in registers:
		var line := []
		for c in r.line_cells:
			line.append([c.x, c.y])
		regs.append({"id": r.furniture_id if r.furniture_id != "" else "register", "cell": [r.cell.x, r.cell.y], "line": line})
	var anchor := delivery_anchor()
	var fixtures := {"registers": regs, "delivery": {"cell": [anchor.x, anchor.y]}}
	for key in ["computer", "sign", "mop_bucket"]:
		var obj: Interactable = get(key)
		if obj:
			fixtures[key] = {"cell": [obj.cell.x, obj.cell.y]}
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
		var obj := add_furniture(id, c)
		var product := str(f.get("product", ""))
		if obj is Shelf and Game.PRODUCTS.has(product) and Game.is_cold(product) == obj.holds_cold():
			obj.product_id = product
			obj.stock = clampi(int(f.get("stock", 0)), 0, Shelf.CAPACITY)
		if obj is StorageRack:
			for v in f.get("boxes", []):
				if v is Array and v.size() >= 2 and Game.PRODUCTS.has(str(v[0])):
					obj.store_box(str(v[0]), maxi(1, int(v[1])))
	for b: Dictionary in d.get("boxes", []):
		var c := _to_cell(b.get("cell"))
		var product := str(b.get("product", ""))
		if Game.PRODUCTS.has(product) and can_drop_at(c) and not objects.has(c):
			_create_box(c, product, maxi(1, int(b.get("count", 1))))
	for v in d.get("spills", []):
		if v is Array and v.size() >= 2:
			add_spill(Vector2i(int(v[0]), int(v[1])), int(v[2]) if v.size() > 2 else -1, false)
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
	var zone := _to_cell(fx.get("delivery", {}).get("cell"))
	if zone != NO_CELL and delivery_cells_at(zone).all(func(c): return floor_cells.has(c) and c != door_cell):
		_shift_delivery_zone(zone)
		_apply_decor()
	for key: String in items:
		var obj: Interactable = items[key]
		if obj == null:
			continue
		var c := _to_cell(entries[key].get("cell"))
		if not _free_spot(c):
			c = home[key] if _free_spot(home[key]) else _nearest_free_spot(home[key])
		_put(obj, c)
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

## Creates a piece of furniture (a key of Game.FURNITURE). Doesn't charge
## money or check the spot; build mode does that first.
func add_furniture(furniture_id: String, cell: Vector2i) -> Interactable:
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
			obj = Decoration.new()
	obj.furniture_id = furniture_id
	_add_object(obj, cell)
	if obj is Shelf:
		shelves.append(obj)
	if obj is StorageRack:
		racks.append(obj)
	if obj is Register:
		registers.append(obj)
		_set_line(obj, _compute_line(cell, register.facing, NO_CELL, obj))
	return obj


## Moves furniture, a register, the computer, the sign or the mop bucket.
## Moving a register brings its checkout line along.
func move_object(obj: Interactable, cell: Vector2i) -> void:
	var new_line: Array[Vector2i] = []
	if obj is Register:
		new_line = preview_line(cell, obj)
	_lift(obj)
	_put(obj, cell)
	if obj is Register and new_line.size() == line_length:
		_set_line(obj, new_line)
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
	_make_solid(cell)
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
	if obj is StorageRack:
		racks.erase(obj)
		var first := true
		for b: StorageRack.Box in obj.boxes:
			release(b)
			var c := obj.cell if first else nearest_drop_cell(obj.cell)
			first = false
			if c != NO_CELL:
				_create_box(c, b.product_id, b.count)
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
## as in the way). Returns fewer cells than needed if the line doesn't fit.
func _compute_line(origin: Vector2i, prefer: Vector2i, freed := NO_CELL, owner: Register = null) -> Array[Vector2i]:
	var blocked := {}
	for c in all_line_cells(owner):
		blocked[c] = true
	var best: Array[Vector2i] = []
	for dir: Vector2i in [prefer, Vector2i(-prefer.y, prefer.x), Vector2i(prefer.y, -prefer.x), -prefer]:
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
## existing register, null when buying a new one.
func preview_line(cell: Vector2i, r: Register = null) -> Array[Vector2i]:
	if r == null:
		return _compute_line(cell, register.facing, NO_CELL, null)
	if cell == r.cell:
		return r.line_cells.duplicate()
	return _compute_line(cell, r.facing, r.cell, r)


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
		if not is_instance_valid(r.cashier) and not r is SelfCheckout:
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
func placement_error(cell: Vector2i, furniture_id: String, moving: Interactable = null) -> String:
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
		new_line = preview_line(cell, moving as Register if moving is Register else null)
		if new_line.size() < line_length:
			return "No room for the checkout line here"
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
	var mess := maxf(MIN_SPILL_TRAFFIC, 1.0 - SPILL_PENALTY * spills.size())
	return appeal * mess * (1.0 + LEVEL_TRAFFIC * (Game.level - 1))


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


## The best shelf for a stocker to put `product_id` on: one that already
## has it and has room, then an empty one that held it before, then a
## brand-new one, then any empty one. Skips shelves another stocker is
## already filling and ones nobody can get to.
func best_shelf_for(product_id: String, from: Vector2, who: Staff) -> Shelf:
	var best: Shelf = null
	var best_score := INF
	var from_cell := Iso.world_to_cell(from)
	for s in shelves:
		if not s.accepts(product_id) or s.stock >= Shelf.CAPACITY or is_claimed(s, who):
			continue
		if stand_cell_for(s.cell, from_cell) == NO_CELL:
			continue
		var rank := 3
		if s.product_id == product_id:
			rank = 0 if s.stock > 0 else 1
		elif s.product_id == "":
			rank = 2
		var score := rank * 100000.0 + from.distance_to(s.position)
		if score < best_score:
			best_score = score
			best = s
	return best


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


## The nearest storage rack with room that no other stocker is filling.
func rack_with_room(from: Vector2, who: Staff) -> StorageRack:
	var best: StorageRack = null
	var best_d := INF
	for r in racks:
		if not r.has_room() or is_claimed(r, who) or stand_cell_for(r.cell, Iso.world_to_cell(from)) == NO_CELL:
			continue
		var d := from.distance_to(r.position)
		if d < best_d:
			best_d = d
			best = r
	return best


# ---------------------------------------------------------------- delivery zone

## The delivery zone's top corner (smallest x and y).
func delivery_anchor() -> Vector2i:
	var a := delivery_cells[0]
	for c in delivery_cells:
		a = Vector2i(mini(a.x, c.x), mini(a.y, c.y))
	return a


## The delivery zone's cells if its top corner was on `anchor`.
func delivery_cells_at(anchor: Vector2i) -> Array[Vector2i]:
	var offset := anchor - delivery_anchor()
	var cells: Array[Vector2i] = []
	for c in delivery_cells:
		cells.append(c + offset)
	return cells


## Why the delivery zone can't go with its top corner on `anchor` ("" means
## it can). Boxes already on the zone move with it.
func delivery_zone_error(anchor: Vector2i) -> String:
	var lines := all_line_cells()
	for c in delivery_cells_at(anchor):
		if not floor_cells.has(c):
			return "It has to fit on the floor"
		if objects.has(c):
			return "Something is in the way"
		if c == door_cell:
			return "Don't block the door"
		if c in lines:
			return "Keep the checkout line clear"
		if boxes.has(c) and not c in delivery_cells:
			return "There's a box in the way"
		if not reachable.has(c):
			return "Nobody could get there"
	return ""


## Moves the delivery zone, along with any boxes waiting on it.
func move_delivery_zone(anchor: Vector2i) -> void:
	_shift_delivery_zone(anchor)
	_apply_decor()
	layout_changed()


func _shift_delivery_zone(anchor: Vector2i) -> void:
	var offset := anchor - delivery_anchor()
	var moving: Array[StockBox] = []
	for c in delivery_cells:
		if boxes.has(c):
			moving.append(boxes[c])
			boxes.erase(c)
	for box in moving:
		box.cell += offset
		box.position = Iso.cell_to_world(box.cell)
		boxes[box.cell] = box
	for i in delivery_cells.size():
		delivery_cells[i] += offset
	delivery_zone.cell = anchor


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


func _staff_start(role: String) -> Vector2i:
	var spot := NO_CELL
	if role == "stocker" and not delivery_cells.is_empty():
		spot = delivery_cells[-1]
	elif role == "janitor" and mop_bucket:
		spot = mop_bucket.cell
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
func add_spill(cell: Vector2i, variant := -1, announce := true) -> void:
	if not Brand.SPILLS or spills.size() >= MAX_SPILLS or spills.has(cell):
		return
	if not floor_cells.has(cell) or astar.is_point_solid(cell) or cell == door_cell or cell in delivery_cells:
		return
	var sp := Spill.new()
	sp.cell = cell
	sp.position = Iso.cell_to_world(cell)
	sp.variant = variant if variant >= 0 and variant < Spill.TEXTURES.size() else randi() % Spill.TEXTURES.size()
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
	return mini(BASE_MAX_CUSTOMERS + Game.level + extra, MAX_CUSTOMERS + extra)


func _update_customers(delta: float) -> void:
	if Game.is_open:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = randf_range(SPAWN_MIN, SPAWN_MAX) / traffic_multiplier()
			if town:
				spawn_timer /= TOWN_TRAFFIC
			_new_shopper()
	elif Game.opened and not Game.day_over and customers.is_empty():
		Game.end_day()  # closing time and the last customer has left


## Someone in town wants to go shopping. With a rival in town they might go
## there instead: more likely if its prices beat yours, your store is a
## mess, or your store is packed.
func _new_shopper() -> void:
	var kind := Game.pick_shopper_kind()
	var list := _make_shopping_list(kind)
	var full := shoppers_inside() >= max_customers()
	if town and not Game.rival_owned and (full or randf() < Game.rival_pull(list, kind)):
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
## the news ("Everyone wants...") get picked more often.
func _make_shopping_list(kind := {}) -> Array[Dictionary]:
	var pool := Game.unlocked_ids()
	var items: Array = kind.get("items", [1, 4])
	var qty: Array = kind.get("qty", [1, 2])
	var n: int = items[0] + floori(pow(randf(), 1.6) * (items[1] - items[0] + 1))
	var list: Array[Dictionary] = []
	for i in mini(n, pool.size()):
		var id := _weighted_pick(pool)
		pool.erase(id)
		list.append({"id": id, "qty": randi_range(qty[0], qty[1])})
	return list


func _weighted_pick(ids: Array) -> String:
	var total := 0.0
	for id in ids:
		total += Game.market.demand[id]
	var roll := randf() * total
	for id in ids:
		roll -= Game.market.demand[id]
		if roll <= 0.0:
			return id
	return ids[-1]


func _on_store_opened() -> void:
	spawn_timer = FIRST_CUSTOMER_DELAY
	_warned_spill = false
	if town and not Game.rival_owned and not _told_about_rival:
		_told_about_rival = true
		Game.message.emit("Some %s shop at %s down the street. Walk out the front door to check its prices." % [Brand.SAY.shoppers, Brand.RIVAL.name])


## Bought out the rival: its owner throws in his leftover stock.
func _on_rival_bought() -> void:
	var ids := Game.unlocked_ids()
	for i in 4:
		pending_deliveries.append({"id": ids.pick_random(), "time": 2.0 + i * 1.5, "warned": false})
	Game.message.emit("%s threw in his leftover stock: 4 boxes are on the way." % Brand.RIVAL.owner)


# ---------------------------------------------------------------- visuals

## Fade shelves out when the player walks behind them (Project Zomboid style).
func _update_cutaways() -> void:
	if player == null:
		return
	var p := player.position
	for s in shelves:
		s.cutaway = p.y < s.position.y and p.y > s.position.y - 74 and absf(p.x - s.position.x) < 36
