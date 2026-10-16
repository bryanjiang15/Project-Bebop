## Smoke test: Load combat scene and drive one turn through controller API
# Run: godot --headless --quit-after 80 res://tests/test_combat_scene_smoke.tscn
extends Node

var controller = null
var combat = null
var frame = 0
var state = "loading"
var spent_before = 0
var turn_before = 0

func _ready():
	print("\n=== COMBAT SCENE SMOKE TEST ===")
	var scene_resource = load("res://scenes/combat/combat_scene.tscn")
	var combat_scene = scene_resource.instantiate()
	add_child(combat_scene)
	controller = combat_scene
	state = "wait_combat"

func _process(_delta):
	frame += 1
	
	if frame > 80:
		print("[FAIL] Timeout in state: " + state)
		get_tree().quit(1)
		return
	
	if state == "wait_combat":
		if controller.combat:
			combat = controller.combat
			if combat.mech and combat.enemies.size() > 0:
				print("  ✓ Combat initialized")
				spent_before = combat.mech.time_spent
				turn_before = combat.current_turn
				state = "select_part"
	
	elif state == "select_part":
		controller._on_part_selected("torso")
		print("  ✓ Part selected")
		state = "select_move"
	
	elif state == "select_move":
		var part = combat.mech.parts["torso"]
		var moves = part.get_available_moves(controller.config)
		if moves.size() > 0:
			controller._on_move_selected(moves[0])
			print("  ✓ Move selected (cost: " + str(moves[0].cost) + ")")
			state = "select_target"
		elif frame > 10:
			print("[FAIL] No moves found")
			get_tree().quit(1)
	
	elif state == "select_target":
		controller.selected_target = combat.enemies[0]
		controller.ui_state = controller.UIState.EXECUTE
		print("  ✓ Target selected")
		state = "confirm"
	
	elif state == "confirm":
		var result = combat.execute_player_move(controller.selected_move, controller.selected_target)
		if result.success:
			print("  ✓ Move executed (spent: " + str(combat.mech.time_spent) + ")")
			state = "end_turn"
		else:
			print("[FAIL] Move execution failed: " + str(result.get("reason", "unknown")))
			get_tree().quit(1)
	
	elif state == "end_turn":
		controller._on_end_turn_pressed()
		state = "verify"
	
	elif state == "verify":
		if combat.current_turn == turn_before + 1 and combat.mech.time_spent == 0:
			print("  ✓ Turn advanced to " + str(combat.current_turn))
			print("  ✓ Time reset (spent: 0)")
			print("\n[PASS] Smoke test - Full turn simulated successfully")
			get_tree().quit(0)
		else:
			print("[FAIL] turn=" + str(combat.current_turn) + " (expected " + str(turn_before + 1) + ") spent=" + str(combat.mech.time_spent) + " (expected 0)")
			get_tree().quit(1)
