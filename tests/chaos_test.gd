extends SceneTree
# Chaos play-tester: plays the game for a long time doing random things
# through the same code a player uses (walking, using things, the computer,
# build mode, the market stalls, saving and loading, settings, days going by)
# and checks after every few frames that the game still makes sense: nothing
# stuck, nothing lost or duplicated, no script errors. See chaos_driver.gd.
#
#   SEED=1 MINUTES=60 SPEED=4 godot --headless --path . -s res://tests/chaos_test.gd
#
#   SEED     random seed (default 1)
#   MINUTES  game minutes to play (default 60; a day is 6 minutes)
#   SPEED    how fast the game runs (default 4)
#   SAVELOAD 0 to never save and reload (default 1)


func _initialize() -> void:
	var driver := Node.new()
	driver.set_script(load("res://tests/chaos_driver.gd"))
	driver.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child.call_deferred(driver)
