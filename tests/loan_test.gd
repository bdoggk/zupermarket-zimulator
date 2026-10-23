extends SceneTree
# Loans from Count Vlad: the interest going up with the amount, the limit
# going up with your store level, the payments taken every morning, paying
# early, the Loans app, and the last night: paid (he's gone), or not (the
# cutscene: he takes your head, and the game starts over from day 1, in
# the save slot too). Runs across real scene changes, like flow_test.
#   godot --headless --path . -s res://tests/loan_test.gd
#   SHOT_DIR=/some/dir godot --path . -s res://tests/loan_test.gd   (screenshots of the cutscene)


func _initialize() -> void:
	var driver := Node.new()
	driver.set_script(load("res://tests/loan_driver.gd"))
	driver.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child.call_deferred(driver)
