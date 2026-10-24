class_name FpArt
## Turns the game's isometric pixel art into what first person needs
## (scripts/first_person.gd), so the 3D view uses the same art as the
## normal view:
##   square()      a 64x32 floor tile (a diamond) as a square, for the floor
##   face()        one side of an iso box sprite (a wall, a shelf) unskewed
##                 into a rectangle, for the side of a 3D box
##   top()         the top of a box sprite as a square
##   composite()   several layers drawn into one image (a box with its
##                 product's icon, a shelf front with its stock on it)
## Everything is made once and cached. With ray tracing on (see RayTracer)
## the materials take their light from its lightmap.

const TILE_W := 64
const TILE_H := 32

static var _cache := {}  # key -> Texture2D / Material / Mesh
static var rt_lightmap: Texture2D  # ray tracing's lightmap (null: ray tracing is off)
static var rt_world := Vector2.ONE  # the map's size in cells
static var _rt_shaders := {}  # both sides? -> Shader


## Ray tracing went on (the lightmap of `world` cells) or off (null): the
## materials made from now on are made for that.
static func set_lightmap(t: Texture2D, world := Vector2.ONE) -> void:
	if t == rt_lightmap and world == rt_world:
		return
	rt_lightmap = t
	rt_world = world
	for k: String in _cache.keys():
		if k.begins_with("rt"):
			_cache.erase(k)


## The lightmap shader (shaders/rt_fp.gdshader), seen from both sides or one.
static func _rt_shader(both_sides: bool) -> Shader:
	if not _rt_shaders.has(both_sides):
		var base: Shader = load("res://shaders/rt_fp.gdshader")
		if both_sides:
			_rt_shaders[true] = base
		else:
			var one := Shader.new()
			one.code = base.code.replace("cull_disabled", "cull_back")
			_rt_shaders[false] = one
	return _rt_shaders[both_sides]


static func _rt_material(tex: Texture2D, both_sides: bool, tint: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _rt_shader(both_sides)
	m.set_shader_parameter("use_texture", tex != null)
	if tex:
		m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("lightmap", rt_lightmap)
	m.set_shader_parameter("world", rt_world)
	m.set_shader_parameter("encode", RayTracer.ENCODE)
	return m


static func _image(tex: Texture2D) -> Image:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img


## A 64x32 diamond (a floor tile, a puddle) as a 32x32 square: +x of the
## square is +x of the grid (down-right on screen), +y is +y (down-left).
static func square(tex: Texture2D, size := 32) -> Texture2D:
	var key := "sq:%s:%d" % [tex.get_rid(), size]
	if _cache.has(key):
		return _cache[key]
	if tex.resource_path.get_file() == "ground_road_line.png":
		_cache[key] = _road_line(tex, size)
		return _cache[key]
	var src := _image(tex)
	var cy := src.get_height() - TILE_H / 2  # the diamond's center, from the top
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for v in size:
		for u in size:
			var a := (u + 0.5) / size
			var b := (v + 0.5) / size
			var x := int((a - b) * TILE_W * 0.5 + TILE_W * 0.5)
			var y := int((a + b) * TILE_H * 0.5) + cy - TILE_H / 2
			if x >= 0 and y >= 0 and x < src.get_width() and y < src.get_height():
				out.set_pixel(u, v, src.get_pixel(x, y))
	var t := ImageTexture.create_from_image(out)
	_cache[key] = t
	return t


## The road's center line: unskewed, the iso art's dash turns into a
## jagged staircase, so it's the plain road with a straight dash painted on
## (along x, like the road), in the dash's yellow.
static func _road_line(tex: Texture2D, size: int) -> Texture2D:
	var road: Texture2D = load(tex.resource_path.get_base_dir().path_join("ground_road_a.png"))
	var out := square(road, size).get_image()
	var src := _image(tex)
	var yellow := Color(0.78, 0.66, 0.24)
	var best := 0.0
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c.a > 0.5 and c.r + c.g - 2.0 * c.b > best:
				best = c.r + c.g - 2.0 * c.b
				yellow = c
	var half := maxi(1, size / 32)
	for u in range(size / 8, size - size / 8):
		for v in range(size / 2 - half, size / 2 + half):
			var k := 0.92 if (u * 7 + v * 3) % 5 == 0 else 1.0  # (worn)
			out.set_pixel(u, v, Color(yellow.r * k, yellow.g * k, yellow.b * k))
	return ImageTexture.create_from_image(out)


## The height of the box drawn in an object sprite (made by
## tools/make_sprites.py): the sprite's height less its top and bottom
## diamonds.
static func box_height(tex: Texture2D) -> int:
	return maxi(1, tex.get_height() - TILE_H)


## How tall the cell-wide box at the bottom of an iso sprite is (a
## counter under a register, the whole of a shelf), found from the
## sprite's left edge; 0 if the sprite isn't a box a cell across (a sign,
## a mop bucket, a lantern).
static func prism_height(tex: Texture2D) -> int:
	var key := "ph:%s" % tex.get_rid()
	if _cache.has(key):
		return _cache[key]
	var src := _image(tex)
	var cy := src.get_height() - TILE_H / 2
	var h := 0
	for y in range(0, cy + 1):
		if src.get_pixel(0, y).a > 0.5 and src.get_pixel(src.get_width() - 1, y).a > 0.5:
			h = cy - y
			break
	if h < 6:
		h = 0
	_cache[key] = h
	return h


## The box at the bottom of a counter's sprite (a register, the shops'
## counters), which can be narrower than a cell: {"x0", "x1": its leftmost
## and rightmost columns, "top", "bottom": the rows of its left corner, top
## and bottom}; {} if the sprite has no box at the bottom.
static func counter_box(tex: Texture2D) -> Dictionary:
	var key := "cbx:%s" % tex.get_rid()
	if _cache.has(key):
		return _cache[key]
	var src := _image(tex)
	var w := src.get_width()
	var h := src.get_height()
	var x0 := -1
	var x1 := -1
	for x in w:
		for y in h:
			if src.get_pixel(x, y).a > 0.5:
				if x0 < 0:
					x0 = x
				x1 = x
				break
	var box := {}
	if x0 >= 0:
		var top := -1
		var bottom := -1
		for y in h:
			if src.get_pixel(x0, y).a > 0.5:
				if top < 0:
					top = y
				bottom = y
		if bottom - top >= 6:
			box = {"x0": x0, "x1": x1, "top": top, "bottom": bottom}
	_cache[key] = box
	return box


## One side of a counter's box (see counter_box), unskewed into a 32-wide
## rectangle as tall as the box: the left side or the right one.
static func counter_face(tex: Texture2D, left := true) -> Texture2D:
	var key := "cface:%s:%s" % [tex.get_rid(), left]
	if _cache.has(key):
		return _cache[key]
	var box := counter_box(tex)
	var src := _image(tex)
	var hw := (int(box.x1) - int(box.x0) + 1) / 2.0
	var tall := int(box.bottom) - int(box.top) + 1
	var out := Image.create(32, tall, false, Image.FORMAT_RGBA8)
	for u in 32:
		var x: int
		var base: float
		if left:
			x = int(box.x0) + int(u * hw / 32.0)
			base = int(box.bottom) + (x - int(box.x0)) * 0.5
		else:
			x = int(box.x0) + int(hw) + int(u * hw / 32.0)
			base = int(box.bottom) + (int(box.x1) - x) * 0.5
		for v in tall:
			var y := int(base) - tall + 1 + v
			if x >= 0 and y >= 0 and x < src.get_width() and y < src.get_height():
				var c := src.get_pixel(x, y)
				out.set_pixel(u, v, Color(c.r, c.g, c.b, 1.0) if c.a > 0.1 else Color(0, 0, 0, 0))
	var t := ImageTexture.create_from_image(out)
	_cache[key] = t
	return t


## The color of a counter's top (the commonest one near its left corner,
## where nothing stands on it).
static func counter_top_color(tex: Texture2D) -> Color:
	var key := "ctop:%s" % tex.get_rid()
	if _cache.has(key):
		return _cache[key]
	var box := counter_box(tex)
	var src := _image(tex)
	var count := {}
	for x in range(int(box.x0) + 3, int(box.x0) + 11):
		for y in range(int(box.top) - 2, int(box.top) + 3):
			if x < src.get_width() and y >= 0 and y < src.get_height():
				var c := src.get_pixel(x, y)
				if c.a > 0.5:
					var k := c.to_html(false)
					count[k] = int(count.get(k, 0)) + 1
	var best := Color(0.6, 0.6, 0.6)
	var most := 0
	for k: String in count:
		if count[k] > most:
			most = count[k]
			best = Color.html(k)
	_cache[key] = best
	return best


## The sprite with its box (prism_height `h`) cut out: what stands on top
## of a counter (a register, a computer), for a billboard.
static func above(tex: Texture2D, h: int) -> Texture2D:
	var key := "above:%s:%d" % [tex.get_rid(), h]
	if _cache.has(key):
		return _cache[key]
	var src := _image(tex)
	var cy := src.get_height() - TILE_H / 2
	var out := src.duplicate() as Image
	for y in src.get_height():
		for x in src.get_width():
			# Inside the box's outline (a hexagon): the top diamond and the sides.
			var dx := absf(x + 0.5 - TILE_W / 2.0) / (TILE_W / 2.0)
			var top := cy - h - (1.0 - dx) * TILE_H / 2.0
			var bottom := cy + (1.0 - dx) * TILE_H / 2.0
			if y + 0.5 >= top - 0.5 and y + 0.5 <= bottom + 0.5:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
	var t := ImageTexture.create_from_image(out)
	_cache[key] = t
	return t


## One side of the box in an iso sprite, unskewed into a 32-wide
## rectangle as tall as the box (`height`: its prism_height, or the whole
## sprite): the left side (the front, for something facing you) or the
## right side.
static func face(tex: Texture2D, left := true, height := -1) -> Texture2D:
	var key := "face:%s:%s:%d" % [tex.get_rid(), left, height]
	if _cache.has(key):
		return _cache[key]
	var src := _image(tex)
	var h := box_height(tex) if height < 0 else height
	var cy := src.get_height() - TILE_H / 2  # the footprint's center
	var out := Image.create(TILE_W / 2, h, false, Image.FORMAT_RGBA8)
	for u in TILE_W / 2:
		for v in h:
			var x: int
			var y: int
			if left:
				x = u
				y = cy - h + int(u * 0.5) + v
			else:
				x = TILE_W / 2 + u
				y = cy + TILE_H / 2 - h - int(u * 0.5) + v
			if y >= 0 and y < src.get_height():
				out.set_pixel(u, v, src.get_pixel(x, y))
	var t := ImageTexture.create_from_image(out)
	_cache[key] = t
	return t


## The top of the box in an iso sprite, as a square (like square()).
static func top(tex: Texture2D, size := 32, height := -1) -> Texture2D:
	var key := "top:%s:%d:%d" % [tex.get_rid(), size, height]
	if _cache.has(key):
		return _cache[key]
	var src := _image(tex)
	var h := box_height(tex) if height < 0 else height
	var cy := src.get_height() - TILE_H / 2 - h  # the top diamond's center
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for v in size:
		for u in size:
			var a := (u + 0.5) / size
			var b := (v + 0.5) / size
			var x := int((a - b) * TILE_W * 0.5 + TILE_W * 0.5)
			var y := int((a + b) * TILE_H * 0.5) + cy - TILE_H / 2
			if x >= 0 and y >= 0 and x < src.get_width() and y < src.get_height():
				out.set_pixel(u, v, src.get_pixel(x, y))
	var t := ImageTexture.create_from_image(out)
	_cache[key] = t
	return t


## `layers` ([[texture, top-left]...]) drawn in order into one image of
## `size`, cached under `key`.
static func composite(key: String, size: Vector2i, layers: Array) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var out := Image.create(maxi(1, size.x), maxi(1, size.y), false, Image.FORMAT_RGBA8)
	for layer: Array in layers:
		var tex: Texture2D = layer[0]
		if tex == null:
			continue
		var src := _image(tex)
		var at: Vector2i = layer[1]
		if layer.size() > 2 and layer[2]:
			src.flip_x()
		out.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), at)
	var t := ImageTexture.create_from_image(out)
	_cache[key] = t
	return t


## An unshaded material for pixel art: crisp pixels, see-through where the
## art is. `both_sides` for walls seen from inside and out. (With ray
## tracing on, lit by the lightmap.)
static func material(tex: Texture2D, both_sides := false, tint := Color.WHITE) -> Material:
	var key := "mat:%s:%s:%s" % [tex.get_rid() if tex else "none", both_sides, tint.to_html()]
	if rt_lightmap:
		key = "rt" + key
	if _cache.has(key):
		return _cache[key]
	if rt_lightmap:
		_cache[key] = _rt_material(tex, both_sides, tint)
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	if both_sides:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	_cache[key] = m
	return m


## A flat colored material (the ceiling). `lit`: lit by the lightmap
## when ray tracing is on (not the lights themselves).
static func color_material(c: Color, lit := true) -> Material:
	var key := "col:%s" % c.to_html()
	if rt_lightmap and lit:
		key = "rt" + key
	if _cache.has(key):
		return _cache[key]
	if rt_lightmap and lit:
		_cache[key] = _rt_material(null, true, c)
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m


## A box one cell across and `height` tall, its origin on the floor in the
## middle: surface 0 is the front (facing +z), 1 the back, 2 the two sides,
## 3 the top. Each side shows its whole texture.
static func box_mesh(height: float, width := 1.0) -> ArrayMesh:
	return sized_box_mesh(Vector3(width, height, width))


## A box `size` big (x, height, z), its origin on the floor in the middle,
## with the surfaces of box_mesh().
static func sized_box_mesh(size: Vector3) -> ArrayMesh:
	var key := "box:%.3f:%.3f:%.3f" % [size.x, size.y, size.z]
	if _cache.has(key):
		return _cache[key]
	var w := size.x / 2.0
	var d := size.z / 2.0
	var height := size.y
	var mesh := ArrayMesh.new()
	# front (+z)
	_quad(mesh, [Vector3(-w, height, d), Vector3(w, height, d), Vector3(w, 0, d), Vector3(-w, 0, d)])
	# back (-z), seen from behind
	_quad(mesh, [Vector3(w, height, -d), Vector3(-w, height, -d), Vector3(-w, 0, -d), Vector3(w, 0, -d)])
	# the two sides (+x and -x) in one surface
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_quad(st, [Vector3(w, height, d), Vector3(w, height, -d), Vector3(w, 0, -d), Vector3(w, 0, d)])
	_add_quad(st, [Vector3(-w, height, -d), Vector3(-w, height, d), Vector3(-w, 0, d), Vector3(-w, 0, -d)])
	st.commit(mesh)
	# top
	_quad(mesh, [Vector3(-w, height, -d), Vector3(w, height, -d), Vector3(w, height, d), Vector3(-w, height, d)])
	_cache[key] = mesh
	return mesh


## A box of one color (shaded: the top lightest, the sides darker), `size`
## big with its origin on the floor in the middle, in one surface: for
## flat_material(). `bottom`: with a bottom too (something off the floor).
static func color_box_mesh(size: Vector3, color: Color, bottom := false) -> ArrayMesh:
	var key := "cbox:%s:%s:%s" % [size, color.to_html(), bottom]
	if _cache.has(key):
		return _cache[key]
	var w := size.x / 2.0
	var d := size.z / 2.0
	var h := size.y
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_quad(st, [Vector3(-w, h, d), Vector3(w, h, d), Vector3(w, 0, d), Vector3(-w, 0, d)], color)
	_add_quad(st, [Vector3(w, h, -d), Vector3(-w, h, -d), Vector3(-w, 0, -d), Vector3(w, 0, -d)], color)
	_add_quad(st, [Vector3(w, h, d), Vector3(w, h, -d), Vector3(w, 0, -d), Vector3(w, 0, d)], color)
	_add_quad(st, [Vector3(-w, h, -d), Vector3(-w, h, d), Vector3(-w, 0, d), Vector3(-w, 0, -d)], color)
	_add_quad(st, [Vector3(-w, h, -d), Vector3(w, h, -d), Vector3(w, h, d), Vector3(-w, h, d)], color)
	if bottom:
		_add_quad(st, [Vector3(-w, 0, d), Vector3(w, 0, d), Vector3(w, 0, -d), Vector3(-w, 0, -d)], color)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


## The material for color_box_mesh(): its colors are in the mesh.
static func flat_material() -> Material:
	return material(null, true)


## Something that glows (a screen, a lamp): never dimmed by the lights,
## ray traced or not. The colors are in the mesh, times `tex` if there's one.
static func glow_material(tex: Texture2D = null) -> Material:
	var key := "glow:%s" % (tex.get_rid() if tex else "none")
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	_cache[key] = m
	return m


## A soft dark blot for under someone's feet (first person without ray
## tracing).
static func shadow_material() -> Material:
	if _cache.has("shadow"):
		return _cache["shadow"]
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.42))
	g.set_color(1, Color(0, 0, 0, 0))
	g.add_point(0.55, Color(0, 0, 0, 0.3))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = t
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = false
	_cache["shadow"] = m
	return m


## One flat quad: corners top-left, top-right, bottom-right, bottom-left
## as you look at the side that shows (the texture fills it).
static func quad_mesh(corners: Array) -> ArrayMesh:
	var key := "quad:%s" % [corners]
	if _cache.has(key):
		return _cache[key]
	var mesh := ArrayMesh.new()
	_quad(mesh, corners)
	_cache[key] = mesh
	return mesh


## The commonest color in a sprite (a car's paint).
static func main_color(tex: Texture2D) -> Color:
	var key := "main:%s" % tex.get_rid()
	if _cache.has(key):
		return _cache[key]
	var src := _image(tex)
	var count := {}
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c.a > 0.5:
				var k := c.to_html(false)
				count[k] = int(count.get(k, 0)) + 1
	var best := Color(0.5, 0.5, 0.5)
	var most := 0
	for k: String in count:
		if count[k] > most:
			most = count[k]
			best = Color.html(k)
	_cache[key] = best
	return best


## A car's paint, faded and blotchy, with rust spots (32x16).
static func rust_texture(paint: Color) -> Texture2D:
	var key := "rust:%s" % paint.to_html(false)
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var img := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 32:
			var k := 1.0 + rng.randf_range(-0.035, 0.035)
			img.set_pixel(x, y, Color(paint.r * k, paint.g * k, paint.b * k))
	var rust := Color(0.5, 0.29, 0.15)
	for i in 14:
		var at := Vector2i(rng.randi_range(0, 31), rng.randi_range(0, 15))
		img.set_pixelv(at, rust)
		if rng.randf() < 0.5:
			img.set_pixelv(Vector2i(mini(at.x + 1, 31), at.y), rust.darkened(0.2))
	for x in 32:  # the line along the doors
		img.set_pixel(x, 7, img.get_pixel(x, 7).darkened(0.18))
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


## A green computer screen with lines of text on it (16x12).
static func screen_texture() -> Texture2D:
	if _cache.has("screen"):
		return _cache["screen"]
	var img := Image.create(16, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.07, 0.2, 0.1))
	var lines := [10, 6, 12, 8, 4]
	for i in lines.size():
		for x in lines[i]:
			img.set_pixel(2 + x, 2 + i * 2, Color(0.45, 0.95, 0.5))
	img.set_pixel(2, 11, Color(0.45, 0.95, 0.5))  # the cursor
	var t := ImageTexture.create_from_image(img)
	_cache["screen"] = t
	return t


## A flat square on the floor, one cell across (for floor tiles, puddles,
## the ceiling).
static func floor_mesh() -> ArrayMesh:
	if _cache.has("floor"):
		return _cache["floor"]
	var mesh := ArrayMesh.new()
	_quad(mesh, [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5)])
	_cache["floor"] = mesh
	return mesh


## Corners top-left, top-right, bottom-right, bottom-left (as you look at
## the side that shows); the texture fills it.
static func _quad(mesh: ArrayMesh, c: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_quad(st, c)
	st.commit(mesh)


## How bright a side facing `n` is drawn: the top full, the front and back
## a little darker, the left and right sides darker still, so boxes look
## solid even without ray tracing (the iso art is shaded the same way).
static func shade(n: Vector3) -> float:
	if n.y > 0.5:
		return 1.0
	if n.y < -0.5:
		return 0.6
	return 0.93 if absf(n.z) >= absf(n.x) else 0.76


static func _add_quad(st: SurfaceTool, c: Array, color := Color.WHITE) -> void:
	var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var n: Vector3 = (c[3] - c[0]).cross(c[1] - c[0]).normalized()  # (the side that shows; ray tracing lights it from there)
	var k := shade(n)
	var col := Color(color.r * k, color.g * k, color.b * k, color.a)
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_color(col)
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(c[i])
