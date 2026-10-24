class_name FpModels
## Simple 3D models for first person (scripts/first_person.gd), for the
## things a flat billboard doesn't do justice: counters with what stands on
## them (registers, self-checkouts, the computer, Bone Mart's counter),
## wrecked cars and chain-link fences. The counters' sides and the fences
## come from the game's own art (see FpArt); the rest is little shaded
## boxes in the art's colors. One unit is a cell; origins are on the floor.

const PX_UP := 32.0
const DARK := Color(0.2, 0.2, 0.22)
const SCREEN := Color(0.4, 0.86, 0.44)  # the green of the screens in the art
const GLASS := Color(0.21, 0.25, 0.29)
const TIRE := Color(0.12, 0.12, 0.13)


## A shaded box of one color, `size` big, its bottom middle at `at`.
static func box(parent: Node3D, size: Vector3, at: Vector3, color: Color, bottom := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = FpArt.color_box_mesh(size, color, bottom)
	mi.material_override = FpArt.flat_material()
	mi.position = at
	parent.add_child(mi)
	return mi


## A screen or a light: a box that glows (the same day or night, ray
## tracing or not).
static func glow_box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mi := box(parent, size, at, color, true)
	mi.material_override = FpArt.glow_material()
	return mi


## A flat picture `size` big facing +z, its middle at `at` (a screen).
static func panel(parent: Node3D, size: Vector2, at: Vector3, tex: Texture2D, glow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var w := size.x / 2.0
	var h := size.y / 2.0
	mi.mesh = FpArt.quad_mesh([Vector3(-w, h, 0), Vector3(w, h, 0), Vector3(w, -h, 0), Vector3(-w, -h, 0)])
	mi.material_override = FpArt.glow_material(tex) if glow else FpArt.material(tex, true)
	mi.position = at
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- counters

## The counter part of sprite `tex` (its box, see FpArt.counter_box) as a
## 3D box: the sides from the art, a plain top in its color. `back`: the
## sprite seen from behind, for the back side. Its height is in meta "top".
static func counter(tex: Texture2D, back: Texture2D = null) -> MeshInstance3D:
	var b := FpArt.counter_box(tex)
	var mi := MeshInstance3D.new()
	if b.is_empty():
		return mi
	var w := (int(b.x1) - int(b.x0) + 1) / 64.0
	var h := (int(b.bottom) - int(b.top) + 1) / PX_UP
	mi.mesh = FpArt.sized_box_mesh(Vector3(w, h, w))
	var front := FpArt.material(FpArt.counter_face(tex, true), true)
	mi.set_surface_override_material(0, front)
	var back_ok := back != null and not FpArt.counter_box(back).is_empty()
	mi.set_surface_override_material(1, FpArt.material(FpArt.counter_face(back, true), true) if back_ok else front)
	mi.set_surface_override_material(2, FpArt.material(FpArt.counter_face(tex, false), true))
	mi.set_surface_override_material(3, FpArt.material(null, true, FpArt.counter_top_color(tex)))
	mi.set_meta("top", h)
	mi.set_meta("width", w)
	return mi


## A cash register on a counter `h` tall: the till (its keys toward the
## cashier, behind) and the price display on a post (toward the shopper).
static func register_machine(parent: Node3D, h: float) -> void:
	var body := Color(0.26, 0.27, 0.3)
	box(parent, Vector3(0.44, 0.15, 0.36), Vector3(0, h, -0.04), body)
	box(parent, Vector3(0.4, 0.07, 0.2), Vector3(0, h + 0.15, -0.1), body.lightened(0.15))
	for i in 3:  # rows of keys
		box(parent, Vector3(0.3, 0.015, 0.03), Vector3(0, h + 0.22, -0.16 + i * 0.05), DARK)
	box(parent, Vector3(0.36, 0.05, 0.015), Vector3(0, h + 0.04, 0.145), DARK)  # the drawer
	box(parent, Vector3(0.05, 0.16, 0.05), Vector3(0.13, h + 0.15, 0.07), DARK)
	glow_box(parent, Vector3(0.22, 0.1, 0.05), Vector3(0.13, h + 0.3, 0.07), SCREEN)


## The store computer on its desk `h` tall: a monitor (its screen toward
## you, in front) and a keyboard.
static func computer_parts(parent: Node3D, h: float) -> void:
	var beige := Color(0.78, 0.76, 0.66)
	box(parent, Vector3(0.12, 0.08, 0.12), Vector3(0, h, -0.1), beige.darkened(0.25))
	box(parent, Vector3(0.44, 0.34, 0.2), Vector3(0, h + 0.08, -0.12), beige)
	panel(parent, Vector2(0.34, 0.24), Vector3(0, h + 0.25, -0.015), FpArt.screen_texture())
	box(parent, Vector3(0.38, 0.03, 0.13), Vector3(0, h, 0.2), beige.darkened(0.12))


## A self-checkout's top, on its body `h` tall: the scanner glass, the
## screen, the bagging stand and the pole with its light (green, or red
## when it's jammed).
static func self_checkout_parts(parent: Node3D, h: float, jammed: bool) -> void:
	box(parent, Vector3(0.38, 0.02, 0.3), Vector3(-0.04, h, 0.06), Color(0.15, 0.18, 0.2))
	box(parent, Vector3(0.06, 0.2, 0.06), Vector3(-0.16, h, -0.18), DARK)
	box(parent, Vector3(0.32, 0.26, 0.07), Vector3(-0.16, h + 0.2, -0.18), Color(0.24, 0.25, 0.27))
	panel(parent, Vector2(0.26, 0.19), Vector3(-0.16, h + 0.33, -0.142), FpArt.screen_texture())
	box(parent, Vector3(0.03, 0.72, 0.03), Vector3(0.27, h, -0.24), DARK)
	glow_box(parent, Vector3(0.09, 0.09, 0.09), Vector3(0.27, h + 0.72, -0.24), Color(1.0, 0.3, 0.25) if jammed else SCREEN)
	box(parent, Vector3(0.2, 0.18, 0.2), Vector3(0.24, h, 0.2), Color(0.86, 0.86, 0.82))


## Bone Mart's till: a gold cash box on the counter.
static func cash_box(parent: Node3D, h: float) -> void:
	var gold := Color(0.66, 0.56, 0.22)
	box(parent, Vector3(0.3, 0.15, 0.24), Vector3(-0.1, h, -0.08), gold)
	box(parent, Vector3(0.24, 0.02, 0.18), Vector3(-0.1, h + 0.15, -0.08), gold.lightened(0.2))


# ---------------------------------------------------------------- the street

## A wrecked car two cells long (along x, its front at +x), in the colors
## of its sprite `tex`, sitting a little crooked.
static func car(tex: Texture2D) -> Node3D:
	var root := Node3D.new()
	var paint := FpArt.main_color(tex)
	var tilt := float((tex.get_rid().get_id() % 5) - 2) * 0.012
	root.rotation = Vector3(tilt, 0.0, -tilt * 0.6)
	var chassis := MeshInstance3D.new()
	chassis.mesh = FpArt.sized_box_mesh(Vector3(1.9, 0.36, 0.9))
	chassis.material_override = FpArt.material(FpArt.rust_texture(paint), true)
	chassis.position = Vector3(0, 0.13, 0)
	root.add_child(chassis)
	box(root, Vector3(1.86, 0.03, 0.86), Vector3(0, 0.1, 0), paint.darkened(0.45))  # the dark gap under it
	box(root, Vector3(0.98, 0.25, 0.8), Vector3(-0.12, 0.49, 0), GLASS)
	for z in [-0.4, 0.4]:  # door pillars
		box(root, Vector3(0.06, 0.25, 0.04), Vector3(0.36, 0.49, z), paint)
		box(root, Vector3(0.06, 0.25, 0.04), Vector3(-0.6, 0.49, z), paint)
	box(root, Vector3(1.02, 0.05, 0.84), Vector3(-0.12, 0.74, 0), paint.lightened(0.06))  # the roof
	for x in [-0.6, 0.6]:
		for z in [-0.42, 0.42]:
			box(root, Vector3(0.34, 0.3, 0.12), Vector3(x, 0.0, z), TIRE)
	for z in [-0.3, 0.3]:
		box(root, Vector3(0.03, 0.08, 0.15), Vector3(0.96, 0.33, z), Color(0.62, 0.62, 0.5))  # headlights (dead)
		box(root, Vector3(0.03, 0.08, 0.15), Vector3(-0.96, 0.33, z), Color(0.5, 0.12, 0.1))
	return root


## A chain-link fence panel along one edge of a cell (see the fence
## sprites): `along_x` on the cell's +y edge (the fence_x sprite), else
## its +x edge (fence_y). See-through where the art is.
static func fence_panel(tex: Texture2D, along_x: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var h := FpArt.box_height(tex) / PX_UP
	if along_x:
		mi.mesh = FpArt.quad_mesh([Vector3(-0.5, h, 0.5), Vector3(0.5, h, 0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5)])
	else:
		mi.mesh = FpArt.quad_mesh([Vector3(0.5, h, 0.5), Vector3(0.5, h, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5)])
	mi.material_override = FpArt.material(FpArt.face(tex, along_x), true)
	return mi
