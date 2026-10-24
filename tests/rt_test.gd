extends Node
# Ray tracing (Options > Graphics > Ray tracing): it's the PC default (and
# High from before moves up to it once), the height map has the walls and
# shelves, every light is in it, a shelf or a person put between a light
# and the floor darkens the floor behind it, the street lamps don't shine
# through a roof, the normal view and first person switch to the lightmap
# and back. The lightmap checks need a real renderer:
#   xvfb-run godot --path . --rendering-driver opengl3 res://tests/rt_test.tscn
# (headless, the rest still runs).

var fails := 0
var gpu := DisplayServer.get_name() != "headless"


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		fails += 1


func _ready() -> void:
	# ---- the setting
	check(Settings.GRAPHICS_NAMES.size() == 4 and Settings.GRAPHICS_NAMES[3] == "Ray tracing", "Graphics has a fourth level: Ray tracing")
	if Settings.is_desktop():
		check(Settings.graphics == Settings.Graphics.RAY_TRACING, "on PC it starts on Ray tracing")
	var keep := Settings.graphics
	var cfg := ConfigFile.new()
	cfg.set_value("display", "graphics", 2)
	cfg.save(Settings.PATH)
	Settings.load_settings()
	check(Settings.graphics == (Settings.Graphics.RAY_TRACING if Settings.is_desktop() else Settings.Graphics.HIGH), "High from an older version moves up to Ray tracing on PC")
	Settings.graphics = Settings.Graphics.HIGH
	Settings.save_settings()
	Settings.load_settings()
	check(Settings.graphics == Settings.Graphics.HIGH, "...once: picking High again stays High")
	cfg = ConfigFile.new()
	cfg.set_value("display", "graphics", 1)
	cfg.save(Settings.PATH)
	Settings.load_settings()
	check(Settings.graphics == Settings.Graphics.MEDIUM, "Medium stays Medium")
	Settings.graphics = Settings.Graphics.RAY_TRACING
	check(Settings.ray_tracing() and Settings.effects_enabled() and Settings.lights_enabled(), "Ray tracing keeps the lights, flicker and dust of High")

	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	Settings.set_graphics(Settings.Graphics.RAY_TRACING)
	await _frames(4)
	Game.tutorial_hidden = true
	var store: Store = Game.store
	var rt: RayTracer = store.ray_tracer
	var p: Player = store.player
	for c in store.customers.duplicate():
		c.queue_free()
	await _frames(2)
	check(rt != null and rt.active, "the store has a ray tracer, and it's on")
	check(rt.grid == store.astar.region.size and rt.view.size == rt.grid * RayTracer.TEXELS, "its lightmap covers the whole town, %d pixels to a cell" % RayTracer.TEXELS)

	# ---- the height map
	var wall: Vector2i = store.wall_cells.keys()[0]
	var sh: Shelf = store.shelves[0]
	var shelf_h := FpArt.box_height(Game.FURNITURE[sh.furniture_id].texture) / 32.0
	check(is_equal_approx(rt.heights[rt._index(wall)], rt.wall_h), "a wall is full height (%.2f)" % rt.heights[rt._index(wall)])
	check(is_equal_approx(rt.heights[rt._index(sh.cell)], shelf_h), "a shelf is as tall as in first person (%.2f)" % shelf_h)
	check(rt.heights[rt._index(store.door_cell)] == 0.0 and rt.roofed[rt._index(store.door_cell)] == 1, "the floor is open, under the roof")
	var street := _street_cell(store)
	check(rt.roofed[rt._index(street)] == 0, "the street has no roof")

	# ---- the lights
	await _frames(2)
	var lamps := 0
	for e: Array in rt.cpu_lights:
		if e[1] > 2.0:
			lamps += 1
	var store_lights: StoreLights = store.get_node("Lights")
	check(rt.lights.size() >= store_lights.lights.size() + store.town.lamps.size(), "every light is in it (%d)" % rt.lights.size())
	check(lamps > 0, "street lamps up high (%d near you)" % lamps)
	# A ceiling light with open floor on both sides of it (east and west).
	var light := _open_light(store, store_lights)
	check(light != Vector2i(-1, -1), "a ceiling light over open floor: %s" % light)
	if light == Vector2i(-1, -1):
		_finish()
		return
	p.position = Iso.cell_to_world(Vector2i(light.x, light.y + 3) if store.is_walkable(Vector2i(light.x, light.y + 3)) else store.door_cell)
	await _frames(3)
	var g := Vector2(light)
	var near := rt.light_at(g + Vector2(0.3, 0))
	var far_away := rt.light_at(Vector2(street.x, street.y))
	check(near.g > rt.ambient.g * RayTracer.AMBIENT_SCALE + 0.2, "light_at: bright under a ceiling light (%.2f)" % near.g)
	# The CPU trace: a shelf in the way, a roof in the way.
	var behind := g + Vector2(2.0, 0.0)
	check(rt.trace(behind, 0.03, g, rt.wall_h - 0.08) == 1.0, "trace: nothing between the floor and the light")
	var lamp := _a_lamp(rt)
	if lamp.size() > 0:
		var inside := Vector2(store.door_cell) + Vector2(0, -2)
		check(rt.trace(inside, 0.03, lamp[0], lamp[1]) == 0.0, "trace: a street lamp doesn't shine in through the roof")
		var below: Vector2 = lamp[0] + Vector2(0.4, 0.4)
		check(rt.trace(below, 0.03, lamp[0], lamp[1]) == 1.0, "...but it does on the street under it")

	# ---- shadows in the lightmap: a shelf put between the light and the floor
	var shelf_cell := Vector2i(light.x + 1, light.y)
	var spot := Vector2(light.x + 2.2, light.y)
	var lit := await _sample(rt, spot)
	var added: Interactable = store.add_furniture("shelf", shelf_cell)
	rt._refresh_heights()
	await _frames(3)
	var shaded := await _sample(rt, spot)
	check(rt.heights[rt._index(shelf_cell)] > 1.0, "a new shelf goes into the height map")
	if gpu:
		check(shaded.g < lit.g - 0.03, "a shelf casts a shadow: the floor behind it darkens (%.3f -> %.3f)" % [lit.g, shaded.g])
		var cpu := rt.light_at(spot)
		check(rt.trace(spot, 0.03, g, rt.wall_h - 0.08) == 0.0, "and the CPU trace agrees (%.2f)" % cpu.g)
	if added:
		store.remove_furniture(added)
	rt._refresh_heights()
	await _frames(3)
	if gpu:
		var back := await _sample(rt, spot)
		check(absf(back.g - lit.g) < 0.02, "take the shelf away and the light's back (%.3f)" % back.g)

	# ---- a person between the light and the floor
	var person_spot := Vector2(light.x, light.y) + Vector2(0, 1.4)
	var no_one := await _sample(rt, person_spot)
	p.position = FirstPerson.grid_to_iso(Vector2(light.x, light.y) + Vector2(0, 0.75))
	rt._refresh_heights()
	await _frames(3)
	var someone := await _sample(rt, person_spot)
	if gpu:
		check(someone.g < no_one.g - 0.02, "people cast shadows too (%.3f -> %.3f)" % [no_one.g, someone.g])

	# ---- night: the lightmap has the night in it
	Game.minute = 22 * 60
	await _frames(4)
	if gpu:
		var dark := await _sample(rt, Vector2(street.x, street.y))
		var want := rt.ambient.g * RayTracer.AMBIENT_SCALE / RayTracer.ENCODE
		check(dark.g <= want + 0.03, "at night a spot no light reaches is just the night (%.3f, night %.3f)" % [dark.g, want])
	Game.minute = 12 * 60

	# ---- the normal view
	var fl := store.floor_layer
	check(fl.material == rt.materials[RayTracer.Mode.FLOOR] and fl.light_mask == 0, "the floor takes its light from the lightmap")
	var wall_sprite: Sprite2D = store.wall_cells[wall][0]
	check(wall_sprite.material == rt.materials[RayTracer.Mode.BOX], "walls are lit as boxes")
	check(sh.material == rt.materials[RayTracer.Mode.BOX] and sh.light_mask == 0, "shelves too")
	check(p.sprite.material == rt.materials[RayTracer.Mode.UPRIGHT], "you're lit where you stand")
	var cu := store.spawn_customer()
	await _frames(2)
	check(cu != null and cu.sprite.material == rt.materials[RayTracer.Mode.UPRIGHT], "a shopper who walks in is lit by it too")
	var sign_light: PointLight2D = null
	for l in rt.lights:
		if l.get_parent() is OpenSign:
			sign_light = l
	check(sign_light != null, "the OPEN sign's glow is a light too")

	Settings.set_graphics(Settings.Graphics.HIGH)
	await _frames(2)
	check(not rt.active and rt.view.render_target_update_mode == SubViewport.UPDATE_DISABLED, "High: ray tracing stops")
	check(fl.material == null and fl.light_mask == 1 and sh.material == null and sh.light_mask == 1 and p.sprite.material == null, "and everything is lit by the normal lights again")
	check(FpArt.rt_lightmap == null and FpArt.material(StoreLights.glow_texture()) is StandardMaterial3D, "first person's materials are the plain ones")

	# ---- first person
	Game.fp.set_active(true)
	await _frames(3)
	check(_floor_mat(Game.fp) is StandardMaterial3D, "first person without ray tracing: plain materials")
	Settings.set_graphics(Settings.Graphics.RAY_TRACING)
	await _frames(4)
	check(rt.active and FpArt.rt_lightmap == rt.lightmap, "back on")
	check(_floor_mat(Game.fp) is ShaderMaterial, "first person's floor is rebuilt with the lightmap")
	var a_shelf: Array = Game.fp._mirrors.get(sh.get_instance_id(), [])
	check(not a_shelf.is_empty() and is_instance_valid(a_shelf[2]) and (a_shelf[2] as MeshInstance3D).get_surface_override_material(0) is ShaderMaterial, "and so are the shelves")
	check(Game.fp.screen.modulate == Color.WHITE, "the night is in the lightmap, not over the screen")
	Game.fp.set_active(false)
	_finish()


func _finish() -> void:
	print("RESULT: %d failed" % fails)
	get_tree().quit(1 if fails > 0 else 0)


## The lightmap at map spot `at`, read back from the graphics card.
func _sample(rt: RayTracer, at: Vector2) -> Color:
	if not gpu:
		return Color.BLACK
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := rt.view.get_texture().get_image()
	var px := Vector2i(((at + Vector2(0.5, 0.5)) * RayTracer.TEXELS).floor())
	return img.get_pixelv(px)


func _floor_mat(fp: FirstPerson) -> Material:
	for mmi in fp._floor.get_children():
		if mmi is MultiMeshInstance3D and (mmi as MultiMeshInstance3D).position.y == 0.0:
			return mmi.material_override
	return null


## A ceiling light with walkable, empty floor 1 to 3 cells east of it.
func _open_light(store: Store, lights: StoreLights) -> Vector2i:
	for l in lights.lights:
		var c := Iso.world_to_cell(l.position + Vector2(0, 8))
		var ok := true
		for dx in range(-1, 4):
			for dy in range(-1, 2):
				var k := c + Vector2i(dx, dy)
				if not store.is_walkable(k) or store.objects.has(k) or store.boxes.has(k):
					ok = false
		if ok:
			return c
	return Vector2i(-1, -1)


func _street_cell(store: Store) -> Vector2i:
	for y in range(store.height + 1, store.astar.region.size.y):
		var c := Vector2i(store.door_cell.x, y)
		if store.is_walkable(c):
			return c
	return Vector2i(store.door_cell.x, store.height + 2)


## [spot, height] of the street lamp nearest the store's door.
func _a_lamp(rt: RayTracer) -> Array:
	var best := []
	var d := INF
	for e: Array in rt.cpu_lights:
		if e[1] > 2.0:
			var k: float = (e[0] as Vector2).distance_to(Vector2(Game.store.door_cell))
			if k < d:
				d = k
				best = [e[0], e[1]]
	return best


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
