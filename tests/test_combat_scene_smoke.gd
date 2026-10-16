## Smoke test: Load combat scene and drive one turn through controller API
# Run: godot --headless --quit-after 80 res://tests/test_combat_scene_smoke.tscn
extends Node

var controller = null
var combat = null
var frame = 0
var state = "loading"
var spent_before = 0
var turn_before = 0
var countdowns_before: Array[int] = []
var move_cost = 0

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
		fail("Timeout in state: " + state)
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
			move_cost = moves[0].cost
			print("  ✓ Move selected (cost: " + str(move_cost) + ")")
			state = "record_countdowns"
		elif frame > 10:
			fail("No moves found")
	
	elif state == "record_countdowns":
		# Record all enemy countdowns before the move
		for enemy in combat.enemies:
			countdowns_before.append(enemy.countdown)
		print("  ✓ Recorded countdowns: " + str(countdowns_before))
		state = "select_target"
	
	elif state == "select_target":
		controller._select_target(0)
		print("  ✓ Target selected")
		state = "confirm"
	
	elif state == "confirm":
		controller._on_confirm_pressed()
		print("  ✓ Move confirmed")
		state = "wait_execute"
	
	elif state == "wait_execute":
		# Wait a frame for execution to complete
		state = "verify_countdowns"
	
	elif state == "verify_countdowns":
		# Verify each enemy countdown dropped by move cost
		for i in combat.enemies.size():
			var expected = countdowns_before[i] - move_cost
			var actual = combat.enemies[i].countdown
			if actual != expected:
				fail("Enemy " + str(i) + " countdown wrong: expected " + str(expected) + ", got " + str(actual))
				return
		print("  ✓ All countdowns reduced by " + str(move_cost))
		state = "verify_time"
	
	elif state == "verify_time":
		if combat.mech.time_spent <= spent_before:
			fail("Time not spent (was " + str(spent_before) + ", now " + str(combat.mech.time_spent) + ")")
			return
		print("  ✓ Time spent (spent: " + str(combat.mech.time_spent) + ")")
		state = "end_turn"
	
	elif state == "end_turn":
		controller._on_end_turn_pressed()
		print("  ✓ Turn ended")
		state = "verify_turn"
	
	elif state == "verify_turn":
		# Verify turn advanced
		if combat.current_turn != turn_before + 1:
			fail("Turn did not advance (expected " + str(turn_before + 1) + ", got " + str(combat.current_turn) + ")")
			return
		print("  ✓ Turn advanced to " + str(combat.current_turn))
		
		# Verify time reset
		if combat.mech.time_spent != 0:
			fail("Time not reset (expected 0, got " + str(combat.mech.time_spent) + ")")
			return
		print("  ✓ Time reset (spent: 0)")
		
		# Verify enemy countdowns were reset or interrupted
		for i in combat.enemies.size():
			var enemy = combat.enemies[i]
			if not enemy.is_destroyed():
				# After end turn, enemy either acted (countdown reached 0) or countdown was reset
				# If acted, has_acted_this_turn will be true
				# If not acted, countdown should be > 0 (reset for next turn)
				if enemy.has_acted_this_turn:
					# Enemy acted, countdown was at or below 0 and should now be reset
					pass  # This is valid
				elif enemy.countdown > 0:
					# Enemy didn't act, countdown is positive
					pass  # This is valid
				else:
					fail("Enemy " + str(i) + " invalid state: countdown=" + str(enemy.countdown) + " acted=" + str(enemy.has_acted_this_turn))
					return
		print("  ✓ Enemy countdowns reset/interrupted")
		
		print("\n[PASS] Smoke test - Full turn simulated successfully")
		get_tree().quit(0)

func fail(message: String):
	print("\n[FAIL] " + message)
	get_tree().quit(1)
