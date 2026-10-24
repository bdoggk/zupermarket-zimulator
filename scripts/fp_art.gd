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
	var key := "box:%.3f:%.3f" % [height, width]
	if _cache.has(key):
		return _cache[key]
	var w := width / 2.0
	var mesh := ArrayMesh.new()
	# front (+z)
	_quad(mesh, [Vector3(-w, height, w), Vector3(w, height, w), Vector3(w, 0, w), Vector3(-w, 0, w)])
	# back (-z), seen from behind
	_quad(mesh, [Vector3(w, height, -w), Vector3(-w, height, -w), Vector3(-w, 0, -w), Vector3(w, 0, -w)])
	# the two sides (+x and -x) in one surface
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_quad(st, [Vector3(w, height, w), Vector3(w, height, -w), Vector3(w, 0, -w), Vector3(w, 0, w)])
	_add_quad(st, [Vector3(-w, height, -w), Vector3(-w, height, w), Vector3(-w, 0, w), Vector3(-w, 0, -w)])
	st.commit(mesh)
	# top
	_quad(mesh, [Vector3(-w, height, -w), Vector3(w, height, -w), Vector3(w, height, w), Vector3(-w, height, w)])
	_cache[key] = mesh
	return mesh


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


static func _add_quad(st: SurfaceTool, c: Array) -> void:
	var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var n: Vector3 = (c[3] - c[0]).cross(c[1] - c[0]).normalized()  # (the side that shows; ray tracing lights it from there)
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_color(Color.WHITE)
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(c[i])
