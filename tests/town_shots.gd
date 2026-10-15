extends Node
# Screenshots of the town around the store (zombie game): the street out
# front, the lots for sale, Bone Mart, the ruins, at day and at night.
#   SHOT_DIR=/some/dir godot --path . --rendering-driver opengl3 res://tests/town_shots.tscn

var shot_dir := OS.get_environment("SHOT_DIR")


func _ready() -> void:
	seed(3)
	var main: Node = preload("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(3)
	var store: Store = Game.store
	var p: Player = Game.player
	Game.money = 4000.0
	Game.open_store()
	for i in 6:
		store._new_shopper()
	await _seconds(6.0)
	for spot in [["street", Vector2i(10, 15), 1.0], ["lots", Vector2i(21, 13), 1.0], ["bonemart", Vector2i(36, 9), 1.0],
			["ruins", Vector2i(12, 24), 0.8], ["wide", Vector2i(22, 14), 0.5]]:
		p.position = Iso.cell_to_world(spot[1])
		p.camera.zoom = Vector2(2.5, 2.5) * spot[2]
		p.camera.reset_smoothing()
		await _seconds(1.0)
		await _shot("town_" + spot[0])
	# after buying two lots and the rival
	Game.add_xp(5000.0)
	Game.buy_expansion()
	Game.buy_expansion()
	Game.money += 3000.0
	Game.buy_out_rival()
	await _seconds(2.0)
	p.position = Iso.cell_to_world(Vector2i(16, 9))
	p.camera.zoom = Vector2(1.5, 1.5)
	p.camera.reset_smoothing()
	await _seconds(1.0)
	await _shot("town_expanded")
	p.position = Iso.cell_to_world(Vector2i(37, 13))
	p.camera.zoom = Vector2(2.0, 2.0)
	p.camera.reset_smoothing()
	await _seconds(3.0)
	await _shot("town_bonemart_sold")
	Game.minute = 19 * 60 + 30
	p.position = Iso.cell_to_world(Vector2i(20, 14))
	p.camera.zoom = Vector2(1.6, 1.6)
	p.camera.reset_smoothing()
	await _seconds(1.0)
	await _shot("town_night")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _seconds(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(name: String) -> void:
	if shot_dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shot_dir.path_join(name + ".png"))
	print("saved ", name)
