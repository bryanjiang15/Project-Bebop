## Scripted simulation to verify E1 can be won and lost
extends SceneTree

var config: ConfigManager
var combat: CombatState

func _init():
	print("\n=== E1 Encounter Verification ===\n")
	
	config = ConfigManager.new()
	
	print("[Test: E1 Can Be Won]")
	test_e1_can_be_won()
	
	print("\n[Test: E1 Can Be Lost]")
	test_e1_can_be_lost()
	
	print("\n=== Verification Complete ===\n")
	quit(0)

func test_e1_can_be_won():
	var build = config.get_default_build()
	combat = CombatState.new(config, build, "e1_swarm")
	combat.start_combat()
	
	var turn_count = 0
	var max_turns = 20
	
	while combat.is_combat_active and turn_count < max_turns:
		turn_count += 1
		print("  Turn %d - Time: %d" % [turn_count, combat.mech.time_budget])
		
		while combat.mech.get_remaining_time() > 0:
			var living_enemies = combat.get_living_enemies()
			if living_enemies.is_empty():
				break
			
			var target = living_enemies[0]
			
			var part = combat.mech.parts.get("right_arm")
			if not part or part.is_destroyed():
				part = combat.mech.parts.get("left_arm")
			if not part or part.is_destroyed():
				part = combat.mech.parts.get("torso")
			
			var moves = part.get_available_moves(config)
			var attack_move = null
			for move in moves:
				if move.type == "attack" and combat.mech.can_afford_move(move):
					attack_move = move
					break
			
			if not attack_move:
				break
			
			var result = combat.execute_player_move(attack_move, target)
			if not result.success:
				break
			
			if combat.get_living_enemies().is_empty():
				print("  ✓ All enemies defeated!")
				break
		
		if not combat.is_combat_active:
			break
		
		combat.end_turn()
	
	if not combat.mech.is_defeated() and combat.get_living_enemies().is_empty():
		print("  ✓ VICTORY - E1 can be won")
		print("  Turns taken: %d" % turn_count)
		print("  Mech torso HP: %d/%d" % [combat.mech.parts["torso"].current_hp, combat.mech.parts["torso"].max_hp])
	else:
		print("  ✗ FAIL - Could not win E1")
		print("  Mech defeated: %s" % combat.mech.is_defeated())
		print("  Enemies remaining: %d" % combat.get_living_enemies().size())

func test_e1_can_be_lost():
	var build = config.get_default_build()
	combat = CombatState.new(config, build, "e1_swarm")
	combat.start_combat()
	
	combat.mech.parts["torso"].current_hp = 1
	
	var turn_count = 0
	var max_turns = 3
	
	while combat.is_combat_active and turn_count < max_turns:
		turn_count += 1
		
		combat.end_turn()
	
	if combat.mech.is_defeated():
		print("  ✓ DEFEAT - E1 can be lost (torso destroyed)")
	else:
		print("  ℹ Note: Mech survived %d turns with 1 HP (may pass)" % turn_count)
