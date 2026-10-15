extends SceneTree

func _init():
	var gut = load("res://addons/gut/gut.gd").new()
	
	gut.add_directory("res://tests/")
	gut.set_log_level(gut.LOG_LEVEL_ALL_ASSERTS)
	
	root.add_child(gut)
	gut.test_scripts()
	
	await gut.tests_finished
	
	var passed = gut.get_pass_count()
	var failed = gut.get_fail_count()
	
	print("\n=== Test Results ===")
	print("Passed: ", passed)
	print("Failed: ", failed)
	print("===================\n")
	
	if failed > 0:
		quit(1)
	else:
		quit(0)
