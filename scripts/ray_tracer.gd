class_name RayTracer
extends Node
## Ray tracing (Options > Graphics > Ray tracing): every light casts real
## shadows, in the normal view and in first person.
##
## Each frame the light on the whole map is worked out into a lightmap, a
## texture with TEXELS pixels to a cell (shaders/rt_light.gdshader): for
## every spot a light reaches, rays are traced to a few points on the light
## (so the shadows have soft edges), cell by cell through a height map of
## what stands on the floor (walls, shelves, counters, boxes, cars, ruins),
## and past everyone walking around. Walls and roofs keep the street lamps
## out of the buildings, and the lights indoors in.
##
## Then everything is drawn with that light instead of the normal 2D lights:
##   the normal view  the floor, and the things on it, get a shader that
##                    looks up their light (shaders/rt_canvas.gdshader)
##   first person     the 3D store's materials do the same
##                    (shaders/rt_fp.gdshader, see FpArt.material), and the
##                    billboards (people, signs) get the light where they
##                    stand, from light_at()
## The lightmap holds the day/night light too, so a spot no light reaches is
## just as dark as before, and a lit spot just as bright as the 2D lights
## make it (the same falloff), only now with shadows.
##
## It's all done in shaders that any graphics card that runs the game can
## run (no ray tracing hardware needed), but it's a lot more work for it,
## so phones start with it off.

signal toggled(on: bool)

const TEXELS := 8  # lightmap pixels to a cell, each way
const ENCODE := 3.0  # the lightmap holds light / ENCODE (so up to 3x the full light fits)
const RAYS := 8  # rays to each light (the soft edges of the shadows)
const MAX_PEOPLE := 32  # people whose shadows are traced (the ones nearest you)
const PERSON_RADIUS := 0.2  # how wide someone is, in cells (from the middle)
const BOX_H := 0.5  # a stock box on the floor
const COUNTER_H := 0.8  # registers, the computer, the shops' counters
const CAR_H := 0.7
const LIGHT_RANGE_2D := 18.0  # lights farther than this from you (cells) don't matter in the normal view
const LIGHT_RANGE_FP := 30.0  # ...or in first person
const HEIGHTS_EVERY := 0.25  # seconds between looks at what's moved (the height map)
const LIGHTS_EVERY := 2.0  # ...and at which lights there are (a new one is seen right away)
const PX_UP := 32.0  # art pixels in a unit of height (as in first person)
## Ray-traced light has more contrast than the normal lights: a bit less of
## the day/night light everywhere, a bit more from the lights themselves
## (about as bright overall, with darker shadows).
const AMBIENT_SCALE := 0.8
const LIGHT_SCALE := 1.35

enum Mode { FLOOR, BOX, UPRIGHT }

static var _light_shader: Shader
static var _canvas_shader: Shader

var store: Store
var active := false
var grid := Vector2i.ONE  # the map, in cells
var wall_h := 1.75  # and the roof
var view: SubViewport  # the lightmap is drawn here
var lightmap: ViewportTexture
var heights := PackedFloat32Array()  # cell -> how tall what stands there is
var roofed := PackedByteArray()  # cell -> 1 under a roof
var height_tex: ImageTexture
var people_nodes: Array[Node2D] = []
var lights: Array[PointLight2D] = []
## The lights this frame, for light_at(): [map spot, height, radius, color * energy]
var cpu_lights: Array = []
var ambient := Color.WHITE
var materials := {}  # Mode -> ShaderMaterial (the normal view)
var _ambient_rect: ColorRect
var _quads: MultiMeshInstance2D
var _light_mat: ShaderMaterial
var _heights_t := 0.0
var _lights_t := 0.0
var _lights_dirty := false  # a light was put up: look again


func _init(s: Store = null) -> void:
	store = s


func _ready() -> void:
	if store == null:
		store = get_parent() as Store
	process_mode = Node.PROCESS_MODE_ALWAYS
	grid = store.astar.region.size
	wall_h = FpArt.box_height(load("res://assets/sprites/wall_rival_tall.png")) / PX_UP
	heights.resize(grid.x * grid.y)
	roofed.resize(grid.x * grid.y)
	if _light_shader == null:
		_light_shader = load("res://shaders/rt_light.gdshader")
		_canvas_shader = load("res://shaders/rt_canvas.gdshader")
	view = SubViewport.new()
	view.size = grid * TEXELS
	view.disable_3d = true
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(view)
	_ambient_rect = ColorRect.new()  # the day/night light, under all the lights
	_ambient_rect.size = Vector2(view.size)
	_ambient_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(_ambient_rect)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	mm.mesh = quad
	_quads = MultiMeshInstance2D.new()
	_quads.multimesh = mm
	_light_mat = ShaderMaterial.new()
	_light_mat.shader = _light_shader
	_light_mat.set_shader_parameter("grid", grid)
	_light_mat.set_shader_parameter("texels", float(TEXELS))
	_light_mat.set_shader_parameter("ceiling", wall_h)
	_light_mat.set_shader_parameter("encode", ENCODE)
	_light_mat.set_shader_parameter("rays", RAYS)
	_quads.material = _light_mat
	view.add_child(_quads)
	lightmap = view.get_texture()
	var img := Image.create(grid.x, grid.y, false, Image.FORMAT_RG8)
	height_tex = ImageTexture.create_from_image(img)
	_light_mat.set_shader_parameter("heights", height_tex)
	for m: Mode in [Mode.FLOOR, Mode.BOX, Mode.UPRIGHT]:
		var mat := ShaderMaterial.new()
		mat.shader = _canvas_shader
		mat.set_shader_parameter("lightmap", lightmap)
		mat.set_shader_parameter("world", Vector2(grid))
		mat.set_shader_parameter("encode", ENCODE)
		mat.set_shader_parameter("mode", m)
		materials[m] = mat
	Settings.changed.connect(_apply_settings)
	get_tree().node_added.connect(_on_node_added)
	tree_exiting.connect(func():
		if FpArt.rt_lightmap == lightmap:
			FpArt.set_lightmap(null))
	_apply_settings.call_deferred()  # (once the town has put up its lights)


func _apply_settings() -> void:
	set_active(Settings.ray_tracing())


func set_active(on: bool) -> void:
	if on == active or not is_inside_tree():
		return
	active = on
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if on:
		_refresh_heights(true)
		_refresh_lights()
		_update(0.0)
		FpArt.set_lightmap(lightmap, Vector2(grid))
	else:
		FpArt.set_lightmap(null)
	_set_2d(on)
	toggled.emit(on)


func _process(delta: float) -> void:
	if active:
		_update(delta)


func _update(delta: float) -> void:
	_heights_t -= delta
	if _heights_t <= 0.0:
		_heights_t = HEIGHTS_EVERY
		_refresh_heights()
	_lights_t -= delta
	if _lights_t <= 0.0 or _lights_dirty:
		_lights_t = LIGHTS_EVERY
		_refresh_lights()
	ambient = store.mood.color
	var k := AMBIENT_SCALE / ENCODE
	_ambient_rect.color = Color(ambient.r * k, ambient.g * k, ambient.b * k, 1.0)
	for m in materials.values():
		(m as ShaderMaterial).set_shader_parameter("ambient", Vector3(ambient.r, ambient.g, ambient.b))
		(m as ShaderMaterial).set_shader_parameter("origin", store.global_position)
	_update_lights()
	_update_people()


# ---------------------------------------------------------------- what stands where

## How tall `n` is for its shadow (0: it doesn't cast one). The same
## heights first person builds its boxes with: every wall is full height.
func block_height(n: Node) -> float:
	if n is Sprite2D:
		var t: Texture2D = (n as Sprite2D).texture
		return wall_h if t and t.resource_path.get_file().begins_with("wall_") else 0.0
	if n is Shelf or n is StorageRack:
		return FpArt.box_height(Game.FURNITURE[n.furniture_id].texture) / PX_UP
	if n is RivalShelf:
		return FpArt.box_height(RivalShelf.TEXTURE) / PX_UP
	if n is StockBox:
		return BOX_H
	if n is Register or n is Computer or n is RivalDesk or n is ShopCounter:
		return COUNTER_H
	if n is Prop:
		var p := n as Prop
		if p.textures.is_empty() or p.textures[0] == null:
			return 0.0
		var f := p.textures[0].resource_path.get_file()
		if f.begins_with("wall_"):
			return wall_h
		if f.begins_with("shop_shelf"):
			return FpArt.box_height(p.textures[0]) / PX_UP
		if f.begins_with("prop_car"):
			return CAR_H
		if f.begins_with("prop_ruin"):
			return FpArt.prism_height(p.textures[0]) / PX_UP
	return 0.0


static func is_person(n: Node) -> bool:
	return n is Player or n.get("sprite") is Sprite2D


func _index(c: Vector2i) -> int:
	return c.y * grid.x + c.x


func _inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < grid.x and c.y < grid.y


## Looks at what stands where (and who's walking around). `force`: send
## the height map to the graphics card even if nothing changed.
func _refresh_heights(force := false) -> void:
	var hs := PackedFloat32Array()
	hs.resize(grid.x * grid.y)
	var roof := PackedByteArray()
	roof.resize(grid.x * grid.y)
	var indoors: Array = store.floor_cells.keys()
	if store.town:
		indoors.append_array(store.town.rival_floor.keys())
		indoors.append_array(store.town.shop_floor.keys())
		if store.town.turf:
			indoors.append_array(store.town.turf.roofed_cells())
	for c: Vector2i in indoors:
		if _inside(c):
			roof[_index(c)] = 1
	people_nodes.clear()
	for n in store.world.get_children():
		if not n is Node2D or not (n as Node2D).visible:
			continue
		if is_person(n):
			people_nodes.append(n)
			continue
		var h := block_height(n)
		if h <= 0.0:
			continue
		var c := Iso.world_to_cell((n as Node2D).position)
		if _inside(c):
			hs[_index(c)] = maxf(hs[_index(c)], h)
	if store.town:  # a car's back half
		for c: Vector2i in store.town.objects:
			var o: Object = store.town.objects[c]
			if o is Prop and is_instance_valid(o) and (o as Prop).visible and _inside(c):
				var h := block_height(o)
				if h > 0.0:
					hs[_index(c)] = maxf(hs[_index(c)], h)
	if not force and hs == heights and roof == roofed:
		return
	heights = hs
	roofed = roof
	var data := PackedByteArray()
	data.resize(grid.x * grid.y * 2)
	for i in hs.size():
		data[i * 2] = clampi(roundi(hs[i] / 4.0 * 255.0), 0, 255)
		data[i * 2 + 1] = 255 if roof[i] else 0
	height_tex.update(Image.create_from_data(grid.x, grid.y, false, Image.FORMAT_RG8, data))


# ---------------------------------------------------------------- lights

func _refresh_lights() -> void:
	_lights_dirty = false
	lights.clear()
	for n in store.find_children("*", "PointLight2D", true, false):
		lights.append(n)


## Is `n` shown (as far as the store goes: first person hides the store itself)?
func _shown(n: Node) -> bool:
	while n != null and n != store:
		if n is CanvasItem and not (n as CanvasItem).visible:
			return false
		n = n.get_parent()
	return n == store


## Where light `l` is on the map (its spot on the floor), how high up, and
## how big it is (for the soft edges).
func _light_place(l: PointLight2D) -> Array:
	var parent := l.get_parent()
	var at: Vector2
	var h := 1.2
	var size := 0.15
	if parent is StoreLights:  # a ceiling light, just under the roof
		at = l.position + Vector2(0, 8)
		h = wall_h - 0.08
		size = 0.3
	elif parent is Node2D:
		var p := parent as Node2D
		at = p.position + Vector2(l.position.x, maxf(l.position.y, 0.0))
		if parent is Prop:
			var f: String = (parent as Prop).textures[0].resource_path.get_file() if not (parent as Prop).textures.is_empty() else ""
			if f.begins_with("prop_lamp"):
				h = 2.6
				size = 0.25
			elif f.begins_with("prop_barrel"):
				h = 0.9
				size = 0.25
			else:
				h = 0.8
		elif parent is ShopCounter:
			h = 1.3
		elif parent is Lantern:
			h = clampf(-(parent as Lantern).flame.y / PX_UP, 0.4, 1.6)
		elif parent is OpenSign:
			h = 0.9
		if p.get_parent() != store.world and p.get_parent() is Node2D:
			at += (p.get_parent() as Node2D).position  # (something inside something)
	else:
		at = l.global_position - store.global_position
	return [FirstPerson.iso_to_grid(at), h, size]


## The light's radius in cells: its glow texture is an ellipse on the
## screen, which is (about) a circle this big on the map.
static func light_radius(l: PointLight2D) -> float:
	if l.texture == null:
		return 0.0
	var w := float(l.texture.get_width()) * l.texture_scale
	var rx := w * 0.5 * absf(l.scale.x)
	var ry := w * 0.5 * absf(l.scale.y)
	return sqrt(rx * ry) / PX_UP


func _update_lights() -> void:
	cpu_lights.clear()
	var me := _viewer()
	var reach := LIGHT_RANGE_FP if Game.fp and Game.fp.active else LIGHT_RANGE_2D
	var mm := _quads.multimesh
	var list := []
	for l in lights:
		if not is_instance_valid(l) or not l.enabled or l.energy <= 0.001 or not _shown(l):
			continue
		var place := _light_place(l)
		var at: Vector2 = place[0]
		var r := light_radius(l)
		if r <= 0.05 or at.distance_to(me) > reach + r:
			continue
		var e := l.energy * LIGHT_SCALE
		var col := Color(l.color.r * e, l.color.g * e, l.color.b * e)
		list.append([at, place[1], r, col, place[2]])
		cpu_lights.append([at, place[1], r, col])
	if mm.instance_count < list.size():
		mm.instance_count = list.size() + 16
	mm.visible_instance_count = list.size()
	for i in list.size():
		var e: Array = list[i]
		var at: Vector2 = e[0]
		var r: float = e[2]
		var center := (at + Vector2(0.5, 0.5)) * TEXELS
		mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2.ONE * (r * 2.0 * TEXELS + 2.0), 0.0, center))
		var col: Color = e[3]
		mm.set_instance_color(i, Color(col.r, col.g, col.b, e[4]))
		mm.set_instance_custom_data(i, Color(at.x, at.y, r, e[1]))


## Where you are on the map (the lights near you are the ones that matter).
func _viewer() -> Vector2:
	if is_instance_valid(store.player):
		return FirstPerson.iso_to_grid(store.player.position)
	return Vector2(grid) / 2.0


func _update_people() -> void:
	var me := _viewer()
	var found := []
	for n in people_nodes:
		if not is_instance_valid(n) or not n.visible or n.modulate.a < 0.3:
			continue
		var sp: Sprite2D = n.get("sprite")
		if sp == null or not sp.visible or sp.texture == null:
			continue
		var at := FirstPerson.iso_to_grid(n.position)
		var tall := clampf((sp.texture.get_height() - 2.0) / PX_UP, 0.6, 1.6)
		found.append([at.distance_squared_to(me), Vector4(at.x, at.y, PERSON_RADIUS, tall)])
	if found.size() > MAX_PEOPLE:
		found.sort_custom(func(a, b): return a[0] < b[0])
		found.resize(MAX_PEOPLE)
	var arr := PackedVector4Array()
	arr.resize(MAX_PEOPLE)
	for i in found.size():
		arr[i] = found[i][1]
	_light_mat.set_shader_parameter("people", arr)
	_light_mat.set_shader_parameter("people_count", found.size())


# ---------------------------------------------------------------- light, worked out here

## The light at map spot `at` (the day/night light plus every light that
## reaches it, blocked by walls and shelves): what first person tints its
## billboards with. One ray to each light (no soft edges or people).
func light_at(at: Vector2) -> Color:
	var total := Color(ambient.r * AMBIENT_SCALE, ambient.g * AMBIENT_SCALE, ambient.b * AMBIENT_SCALE)
	var cell := Vector2i(roundi(at.x), roundi(at.y))
	var h0 := (heights[_index(cell)] if _inside(cell) else 0.0) + 0.03
	for e: Array in cpu_lights:
		var l: Vector2 = e[0]
		var r: float = e[2]
		var d := at.distance_to(l)
		if d >= r:
			continue
		var x := d / r
		var fall := 1.0 - 1.1 * x if x < 0.5 else 0.9 * (1.0 - x)
		if trace(at, h0, l, e[1]) > 0.0:
			var col: Color = e[3]
			total += Color(col.r * fall, col.g * fall, col.b * fall)
	total.a = 1.0
	return total


## 1 if the ray from `p` (`h0` off the floor) to the light at `l` (`lh`
## up) gets through, 0 if a wall, a shelf or a roof is in the way: the same
## steps as trace() in shaders/rt_light.gdshader.
func trace(p: Vector2, h0: float, l: Vector2, lh: float) -> float:
	var d := l - p
	var length := d.length()
	if length < 0.0001:
		return 1.0
	var dir := d / length
	var cell := Vector2i(floori(p.x + 0.5), floori(p.y + 0.5))
	var end := Vector2i(floori(l.x + 0.5), floori(l.y + 0.5))
	var light_inside := _inside(end) and roofed[_index(end)] == 1
	var stp := Vector2i(1 if dir.x > 0.0 else -1, 1 if dir.y > 0.0 else -1)
	var inv := Vector2(1e9, 1e9)
	var tmax := Vector2(1e9, 1e9)
	if absf(dir.x) > 1e-6:
		inv.x = 1.0 / absf(dir.x)
		tmax.x = (cell.x + 0.5 * stp.x - p.x) / dir.x
	if absf(dir.y) > 1e-6:
		inv.y = 1.0 / absf(dir.y)
		tmax.y = (cell.y + 0.5 * stp.y - p.y) / dir.y
	var slope := (lh - h0) / length
	for i in 32:
		var t1: float
		if tmax.x < tmax.y:
			t1 = tmax.x
			tmax.x += inv.x
			cell.x += stp.x
		else:
			t1 = tmax.y
			tmax.y += inv.y
			cell.y += stp.y
		if t1 >= length or cell == end:
			return 1.0
		if not _inside(cell):
			continue
		var t2 := minf(minf(tmax.x, tmax.y), length)
		var ha := h0 + slope * t1
		var hb := h0 + slope * t2
		var k := _index(cell)
		if minf(ha, hb) < heights[k]:
			return 0.0
		if not light_inside and roofed[k] == 1 and maxf(ha, hb) > wall_h:
			return 0.0
	return 1.0


# ---------------------------------------------------------------- the normal view

## Puts the lightmap shaders on the floor and on everything in the store
## (or takes them off again).
func _set_2d(on: bool) -> void:
	var floor_layer := store.floor_layer
	floor_layer.material = materials[Mode.FLOOR] if on else null
	floor_layer.light_mask = 0 if on else 1
	for root: Node in [store.world, store.decals]:
		for n in root.find_children("*", "", true, false):
			if on:
				_hook(n)
			else:
				_unhook(n)


func _on_node_added(n: Node) -> void:
	if not active or not is_instance_valid(store):
		return
	if n is PointLight2D and store.is_ancestor_of(n):
		_lights_dirty = true
	elif store.world.is_ancestor_of(n) or store.decals.is_ancestor_of(n):
		_hook.call_deferred(n)  # (once it has its texture)


func _hook(n: Node) -> void:
	if not active or not is_instance_valid(n) or not n.is_inside_tree() or not n is Node2D or n.has_meta("rt"):
		return
	if n is Light2D or n is Camera2D or n is CPUParticles2D or n is GPUParticles2D or n is CollisionShape2D or n is CollisionPolygon2D:
		return
	var ci := n as CanvasItem
	if ci.material != null:
		return  # (it has its own)
	var mode := Mode.UPRIGHT
	var host := n
	if n.get_parent() != store.world and n.get_parent() != store.decals:
		host = n.get_parent()  # (a person's sprite, say)
	if store.decals.is_ancestor_of(n):
		mode = Mode.FLOOR
	elif not is_person(host) and block_height(host) > 0.05:
		mode = Mode.BOX
	ci.set_meta("rt", ci.light_mask)
	ci.material = materials[mode]
	ci.light_mask = 0


func _unhook(n: Node) -> void:
	if not n.has_meta("rt"):
		return
	var ci := n as CanvasItem
	ci.material = null
	ci.light_mask = int(n.get_meta("rt"))
	n.remove_meta("rt")
