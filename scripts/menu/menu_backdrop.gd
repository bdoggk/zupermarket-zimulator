extends Node2D
## The main menu's background: the store from your most recent save (its
## layout, stock, paint job and any lots you've bought) or the starting
## layout, with the town around it and a few shoppers, slowly drifting by.

const PAN := Vector2(150, 50)  # how far the camera drifts
const DRIFT_SPEED := 0.08
const SHOPPER_CELLS := [Vector2i(7, 5), Vector2i(3, 6), Vector2i(9, 9), Vector2i(12, 6), Vector2i(8, 3)]
const STREET_CELLS := [Vector2i(5, 13), Vector2i(17, 15), Vector2i(11, 18)]

var camera: Camera2D
var center := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	var save := {}
	var slot := Saves.latest_slot()
	if slot >= 0:
		save = Saves.read_slot(slot)
	var game: Dictionary = save.get("game", {})
	var store_data: Dictionary = save.get("store", {})
	var floor_id: String = Game.FLOOR_STYLES[clampi(int(game.get("floor_style", 0)), 0, Game.FLOOR_STYLES.size() - 1)].id
	var wall_id: String = Game.WALL_COLORS[clampi(int(game.get("wall_color", 0)), 0, Game.WALL_COLORS.size() - 1)].id
	var expansions := clampi(int(game.get("expansions", 0)), 0, Brand.EXPANSIONS.size()) if not Brand.TOWN.is_empty() else 0
	var tiles := [
		load("res://assets/sprites/floor_%s_a.png" % floor_id),
		load("res://assets/sprites/floor_%s_b.png" % floor_id),
	]
	var wall_tall: Texture2D = load("res://assets/sprites/wall_%s_tall.png" % wall_id)
	var wall_low: Texture2D = load("res://assets/sprites/wall_%s_low.png" % wall_id)

	var floor_layer := FloorLayer.new()
	add_child(floor_layer)
	var world := Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	if not Brand.TOWN.is_empty():
		var rival: Variant = game.get("rival", {})
		_town(floor_layer, world, expansions, rival is Dictionary and bool(rival.get("owned", false)))

	# The store's map, made wider by the lots you've bought.
	var layout: Array = []
	for y in Brand.LAYOUT.size():
		var row: String = Brand.LAYOUT[y]
		var fill := "#" if y == 0 or y == Brand.LAYOUT.size() - 1 else "."
		layout.append(row.substr(0, row.length() - 1) + fill.repeat(Store.LOT_WIDTH * expansions) + row[-1])

	var saved_fixtures: Dictionary = store_data.get("fixtures", {})
	var fixtures := {}  # register / computer / sign / mop bucket -> cell (moved ones come from the save)
	var delivery: Array[Vector2i] = []
	for y in layout.size():
		var row: String = layout[y]
		for x in row.length():
			if row[x] == "D":
				delivery.append(Vector2i(x, y))
	var zone_offset := Vector2i.ZERO
	var zone := Store._to_cell(saved_fixtures.get("delivery", {}).get("cell"))
	if zone != Store.NO_CELL and not delivery.is_empty():
		var top := delivery[0]
		for c in delivery:
			top = Vector2i(mini(top.x, c.x), mini(top.y, c.y))
		zone_offset = zone - top
	var starter_stock: Array = Brand.STARTING_BOXES
	var shelf_i := 0
	for y in layout.size():
		var row: String = layout[y]
		for x in row.length():
			var cell := Vector2i(x, y)
			var ch := row[x]
			if ch == "#":
				_sprite(world, wall_tall if x == 0 or y == 0 else wall_low, cell)
				continue
			var tile: Texture2D = tiles[(x + y) % 2]
			if cell - zone_offset in delivery:
				tile = Store.TILE_DELIVERY
			elif ch == "E":
				tile = Store.TILE_DOORMAT
			floor_layer.add_tile(tile, cell)
			match ch:
				"R":
					fixtures.register = cell
				"C":
					fixtures.computer = cell
				"O":
					fixtures.sign = cell
				"M":
					if Brand.SPILLS:
						fixtures.mop_bucket = cell
				"S", "F", "L":
					if store_data.is_empty():
						var obj := _furniture({"S": "shelf", "F": "fridge", "L": "plant"}[ch])
						if obj is Shelf and not obj.holds_cold():
							obj.product_id = starter_stock[shelf_i % starter_stock.size()]
							obj.stock = 8 + (shelf_i * 3) % 5
							shelf_i += 1
						_place(world, obj, cell)

	var saved_regs: Array = saved_fixtures.get("registers", [])
	if saved_regs.is_empty() and saved_fixtures.has("register"):
		saved_regs = [saved_fixtures.register]
	if not saved_regs.is_empty():
		saved_fixtures["register"] = saved_regs[0]
	for i in range(1, saved_regs.size()):
		var reg: Register = SelfCheckout.new() if str(saved_regs[i].get("id", "")) == "selfcheckout" else Register.new()
		_place(world, reg, Store._to_cell(saved_regs[i].get("cell")))
	for key: String in fixtures:
		var c := Store._to_cell(saved_fixtures.get(key, {}).get("cell"))
		var cell: Vector2i = c if c != Store.NO_CELL else fixtures[key]
		match key:
			"register":
				_place(world, Register.new(), cell)
			"computer":
				_place(world, Computer.new(), cell)
			"mop_bucket":
				_place(world, MopBucket.new(), cell)
			"sign":
				_sprite(world, OpenSign.CLOSED_TEX, cell)

	for v in store_data.get("spills", []):
		if v is Array and v.size() >= 2:
			var sp := Spill.new()
			sp.variant = clampi(int(v[2]) if v.size() > 2 else 0, 0, Spill.TEXTURES.size() - 1)
			sp.position = Iso.cell_to_world(Vector2i(int(v[0]), int(v[1])))
			floor_layer.add_child(sp)

	for f: Dictionary in store_data.get("furniture", []):
		var fid := str(f.get("id", ""))
		if not Game.FURNITURE.has(fid) or Game.FURNITURE[fid].kind in ["register", "selfcheckout"]:
			continue
		var obj := _furniture(fid)
		var product := str(f.get("product", ""))
		if obj is Shelf and Game.PRODUCTS.has(product):
			obj.product_id = product
			obj.stock = clampi(int(f.get("stock", 0)), 0, Shelf.CAPACITY)
		if obj is StorageRack:
			for b in f.get("boxes", []):
				if b is Array and b.size() >= 2 and Game.PRODUCTS.has(str(b[0])):
					obj.store_box(str(b[0]), int(b[1]))
		_place(world, obj, Store._to_cell(f.get("cell")))

	var looks: Array = Customer.LOOKS
	for i in SHOPPER_CELLS.size():
		_sprite(world, looks[i % looks.size()], SHOPPER_CELLS[i], true).flip_h = i % 2 == 0
	if not Brand.TOWN.is_empty():
		var kinds: Array = Brand.SHOPPERS.values()
		for i in STREET_CELLS.size():
			var tex: Texture2D = (kinds[(i * 2 + 1) % kinds.size()].looks as Array)[0]
			_sprite(world, tex, STREET_CELLS[i], true).flip_h = i % 2 == 1

	var mood := CanvasModulate.new()
	mood.color = Brand.LIGHT.menu
	add_child(mood)
	var wide: int = (layout[0] as String).length()
	center = Iso.cell_to_world(Vector2i(int(wide / 2.0), int(layout.size() / 2.0) + 1))
	camera = Camera2D.new()
	camera.zoom = Vector2(2.2, 2.2)
	camera.position = center
	add_child(camera)
	camera.make_current()


## The town around the store: ground, scenery, the lots for sale and the
## rival store (just the look of it; nothing moves).
func _town(floor_layer: FloorLayer, world: Node2D, expansions: int, rival_owned: bool) -> void:
	var rows: Array = Brand.TOWN
	var front := 0
	var right := 0
	var rival_min := Vector2i(1 << 20, 1 << 20)
	var lot_x0 := {}
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch.is_valid_int():
				front = maxi(front, y)
				right = maxi(right, x)
				lot_x0[int(ch)] = mini(int(lot_x0.get(int(ch), x)), x)
			if ch == "#":
				rival_min = Vector2i(mini(rival_min.x, x), mini(rival_min.y, y))
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var cell := Vector2i(x, y)
			var ch := row[x]
			if ch == "@":
				continue
			if ch.is_valid_int():
				if int(ch) <= expansions:
					continue  # part of the store now
				floor_layer.add_tile(Town.ground_texture("lot", cell), cell)
				if y == front:
					_sprite(world, Town.FENCE_X, cell)
				if x == right:
					_sprite(world, Town.FENCE_Y, cell)
				if y == front and x == int(lot_x0[int(ch)]) + 1:
					_sprite(world, Town.FOR_SALE, cell)
				continue
			if ch != "#":
				floor_layer.add_tile(Town.ground_texture(Town.under(ch, cell, rows), cell), cell)
			var prop := Town.prop_sprite(ch, cell)
			if prop != "":
				_sprite(world, load("res://assets/sprites/%s.png" % prop), cell)
				continue
			match ch:
				"#":
					_sprite(world, Town.WALL_TALL if x == rival_min.x or y == rival_min.y else Town.WALL_LOW, cell)
				"s":
					_place(world, RivalShelf.new(), cell)
				"r", "p":
					var d := RivalDesk.new()
					d.texture = load("res://assets/sprites/%s.png" % ("rival_counter" if ch == "r" else "rival_board"))
					_place(world, d, cell)
				"S":
					_sprite(world, Brand.RIVAL.textures.sign_sold if rival_owned else Brand.RIVAL.textures.sign, cell)
				"C":
					var tex: Texture2D = load("res://assets/sprites/%s.png" % Town.variant("prop_car_%d", 3, cell))
					_sprite(world, tex, cell + Vector2i(1, 0)).offset = -Vector2(64, tex.get_height() - 17)
				"m":
					if not rival_owned:
						_sprite(world, Brand.RIVAL.textures.owner, cell, true)


func _sprite(world: Node2D, tex: Texture2D, cell: Vector2i, person := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	if person:
		s.offset = Vector2(-floorf(tex.get_width() / 2.0), -(tex.get_height() - 2))
	else:
		s.offset = Vector2(-32, -(tex.get_height() - 16))
	s.position = Iso.cell_to_world(cell)
	world.add_child(s)
	return s


func _furniture(id: String) -> Interactable:
	match Game.FURNITURE[id].kind:
		"shelf":
			return Shelf.new()
		"fridge":
			return Fridge.new()
		"storage":
			return StorageRack.new()
	var d := Decoration.new()
	d.furniture_id = id
	return d


func _place(world: Node2D, obj: Interactable, cell: Vector2i) -> void:
	obj.cell = cell
	obj.position = Iso.cell_to_world(cell)
	world.add_child(obj)


func _process(delta: float) -> void:
	_t += delta * DRIFT_SPEED
	camera.position = center + Vector2(sin(_t) * PAN.x, sin(_t * 0.7) * PAN.y)
