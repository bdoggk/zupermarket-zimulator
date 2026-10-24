extends SceneTree
# Save, load, save again: the second save must match the first. Builds up a
# store with a bit of everything in it first (furniture of every kind, racks
# with boxes, the war with land, a gang and weapons, a loan, brews, staff,
# expansions, a bigger delivery zone, paint, prices...), so anything that
# isn't saved or isn't loaded back shows up as a difference.
#   godot --headless --path . -s res://tests/roundtrip_test.gd


func _initialize() -> void:
	var driver := Node.new()
	driver.set_script(load("res://tests/roundtrip_driver.gd"))
	driver.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child.call_deferred(driver)
