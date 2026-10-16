## Smoke test: Load combat scene and simulate a complete turn
extends Node

func _ready():
	print("\n=== COMBAT SCENE SMOKE TEST ===")
	run_test()

func run_test():
	# Load scene
	var scene_resource = load("res://scenes/combat/combat_scene.tscn")
	if not scene_resource:
		fail("Failed to load combat_scene.tscn")
		return
	
	# Instantiate
	var combat_scene = scene_resource.instantiate()
	if not combat_scene:
		fail("Failed to instantiate combat_scene")
		return
	
	add_child(combat_scene)
	print("  ✓ Scene loaded and added to tree")
	
	# Wait for _ready() to complete
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Get controller
	var controller = combat_scene
	var combat = controller.combat
	
	# Verify initial state
	if not controller or not controller.has_method("select_part"):
		fail("Controller not properly initialized")
		return
	
	if not combat or not combat.mech or combat.enemies.size() == 0:
		fail("Combat state not properly initialized")
		return
	
	if combat.turn_count != 0:
		fail("Turn count should start at 0")
		return
	
	if combat.time_budget != 10:
		fail("Time budget should start at 10")
		return
	
	print("  ✓ Initial state verified")
	
	# Select torso part
	controller.select_part(0)
	await get_tree().process_frame
	
	if controller.selected_part_index != 0:
		fail("Part selection failed")
		return
	
	print("  ✓ Part selected (torso)")
	
	# Get and select light attack
	var moves = combat.get_available_moves(0)
	if moves.size() == 0:
		fail("No moves available")
		return
	
	var light_attack = null
	for move in moves:
		if move.type == "attack" and move.level == "light":
			light_attack = move
			break
	
	if not light_attack:
		fail("Light attack not found")
		return
	
	controller.select_move(light_attack)
	await get_tree().process_frame
	
	if controller.selected_move.is_empty():
		fail("Move selection failed")
		return
	
	print("  ✓ Move selected (light attack, cost 2)")
	
	# Select target
	controller.select_target(0)
	await get_tree().process_frame
	
	if controller.selected_target_index != 0:
		fail("Target selection failed")
		return
	
	print("  ✓ Target selected (enemy 0)")
	
	# Record state before move
	var time_before = combat.time_budget
	
	# Execute move
	controller._on_confirm_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Verify time was spent
	if combat.time_budget >= time_before:
		fail("Time budget not reduced (was " + str(time_before) + ", now " + str(combat.time_budget) + ")")
		return
	
	print("  ✓ Time spent (budget now: " + str(combat.time_budget) + ")")
	
	# End turn
	controller._on_end_turn_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Verify turn advanced
	if combat.turn_count != 1:
		fail("Turn did not advance (expected 1, got " + str(combat.turn_count) + ")")
		return
	
	print("  ✓ Turn advanced to turn 1")
	
	# Verify time budget reset
	if combat.time_budget != 10:
		fail("Time budget not reset (expected 10, got " + str(combat.time_budget) + ")")
		return
	
	print("  ✓ Time budget reset to 10")
	
	# Success
	print("\n[PASS] Combat scene smoke test - Full turn simulated successfully")
	get_tree().quit(0)

func fail(message: String):
	print("\n[FAIL] Combat scene smoke test: " + message)
	get_tree().quit(1)
