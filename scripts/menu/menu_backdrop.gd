extends Node2D
## The main menu's background: the store from your most recent save (its
## layout, stock and paint job) or the starting layout, slowly drifting by,
## with a few shoppers.

const PAN := Vector2(150, 50)  # how far the camera drifts
const DRIFT_SPEED := 0.08
const SHOPPER_CELLS := [Vector2i(7, 5), Vector2i(3, 6), Vector2i(9, 9), Vector2i(12, 6), Vector2i(8, 3)]

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

	var layout: Array = Brand.LAYOUT
	var fixtures := {}  # register / computer / sign / mop bucket -> cell (moved ones come from the save)
	var starter_stock: Array = Brand.STARTING_BOXES
	var shelf_i := 0
	for y in layout.size():
		var row: String = layout[y]
		for x in row.length():
			var cell := Vector2i(x, y)
			var ch := row[x]
			if ch == "#":
				var tex := wall_tall if x == 0 or y == 0 else wall_low
				var s := Sprite2D.new()
				s.texture = tex
				s.centered = false
				s.offset = Vector2(-32, -(tex.get_height() - 16))
				s.position = Iso.cell_to_world(cell)
				world.add_child(s)
				continue
			var tile: Texture2D = tiles[(x + y) % 2]
			if ch == "D":
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

	var saved_fixtures: Dictionary = store_data.get("fixtures", {})
	var saved_regs: Array = saved_fixtures.get("registers", [])
	if saved_regs.is_empty() and saved_fixtures.has("register"):
		saved_regs = [saved_fixtures.register]
	if not saved_regs.is_empty():
		saved_fixtures["register"] = saved_regs[0]
	for i in range(1, saved_regs.size()):
		_place(world, Register.new(), Store._to_cell(saved_regs[i].get("cell")))
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
				var s := Sprite2D.new()
				s.texture = OpenSign.CLOSED_TEX
				s.centered = false
				s.offset = Vector2(-32, -(s.texture.get_height() - 16))
				s.position = Iso.cell_to_world(cell)
				world.add_child(s)

	for v in store_data.get("spills", []):
		if v is Array and v.size() >= 2:
			var sp := Spill.new()
			sp.variant = clampi(int(v[2]) if v.size() > 2 else 0, 0, Spill.TEXTURES.size() - 1)
			sp.position = Iso.cell_to_world(Vector2i(int(v[0]), int(v[1])))
			floor_layer.add_child(sp)

	for f: Dictionary in store_data.get("furniture", []):
		var fid := str(f.get("id", ""))
		if not Game.FURNITURE.has(fid) or Game.FURNITURE[fid].kind == "register":
			continue
		var obj := _furniture(f.id)
		var product := str(f.get("product", ""))
		if obj is Shelf and Game.PRODUCTS.has(product):
			obj.product_id = product
			obj.stock = clampi(int(f.get("stock", 0)), 0, Shelf.CAPACITY)
		_place(world, obj, Store._to_cell(f.get("cell")))

	for i in SHOPPER_CELLS.size():
		var s := Sprite2D.new()
		s.texture = Customer.LOOKS[i % Customer.LOOKS.size()]
		s.centered = false
		s.offset = Vector2(-8, -34)
		s.flip_h = i % 2 == 0
		s.position = Iso.cell_to_world(SHOPPER_CELLS[i])
		world.add_child(s)

	var mood := CanvasModulate.new()
	mood.color = Brand.LIGHT.menu
	add_child(mood)
	center = Iso.cell_to_world(Vector2i(int(layout[0].length() / 2.0), int(layout.size() / 2.0)))
	camera = Camera2D.new()
	camera.zoom = Vector2(2.2, 2.2)
	camera.position = center
	add_child(camera)
	camera.make_current()


func _furniture(id: String) -> Interactable:
	match Game.FURNITURE[id].kind:
		"shelf":
			return Shelf.new()
		"fridge":
			return Fridge.new()
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
