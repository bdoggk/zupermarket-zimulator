extends SceneTree
# Plays through the menus like a player would, across real scene changes:
# new game, save, quit to menu, continue, load, delete, overwrite, a save
# made between days, a damaged file, and settings.
#   godot --headless --path . -s res://tests/flow_test.gd
#   SHOT_DIR=/some/dir godot --path . -s res://tests/flow_test.gd   (screenshots)


func _initialize() -> void:
	var driver := Node.new()
	driver.set_script(load("res://tests/flow_driver.gd"))
	driver.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child.call_deferred(driver)
