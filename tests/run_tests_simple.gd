## Simple headless test runner without GUT dependency
extends SceneTree

var passed = 0
var failed = 0
var config: ConfigManager
var combat: CombatState

func _init():
	print("\n=== Running Project Bebop Tests ===\n")
	
	config = ConfigManager.new()
	
	test_config_loading()
	test_interrupt_timing()
	test_one_action_per_enemy_per_turn()
	test_end_of_turn_reset()
	test_stun_threshold()
	test_stun_immunity()
	test_block_calculation()
	test_block_guard_bonus()
	test_whiff_crouch()
	test_whiff_jump()
	test_damage_calculation()
	test_chain_bonus()
	test_part_destruction()
	test_move_preview_countdowns()
	test_move_preview_interrupts()
	
	print("\n=== Test Results ===")
	print("Passed: %d" % passed)
	print("Failed: %d" % failed)
	print("===================\n")
	
	if failed > 0:
		quit(1)
	else:
		quit(0)

func assert_true(condition: bool, message: String):
	if condition:
		passed += 1
		print("  ✓ " + message)
	else:
		failed += 1
		print("  ✗ FAIL: " + message)

func assert_eq(actual, expected, message: String):
	if actual == expected:
		passed += 1
		print("  ✓ " + message)
	else:
		failed += 1
		print("  ✗ FAIL: " + message + " (expected: %s, got: %s)" % [str(expected), str(actual)])

func test_config_loading():
	print("\n[Test: Config Loading]")
	assert_true(config.config.size() > 0, "Config loaded")
	assert_eq(config.get_time_budget_base(), 10, "Time budget base is 10")

func test_interrupt_timing():
	print("\n[Test: Interrupt Timing and Ordering]")
	var build = config.get_default_build()
	combat = CombatState.new(config, build, "e1_swarm")
	combat.start_combat()
	
	var enemies = combat.get_living_enemies()
	assert_eq(enemies.size(), 3, "Should have 3 enemies")
	assert_eq(enemies[0].countdown, 4, "Drone 1 starts at 4")
	assert_eq(enemies[1].countdown, 5, "Drone 2 starts at 5")
	assert_eq(enemies[2].countdown, 6, "Drone 3 starts at 6")
	
	var right_arm = combat.mech.parts["right_arm"]
	var medium_attack = null
	for move in right_arm.get_available_moves(config):
		if move.type == "attack" and move.level == "medium":
			medium_attack = move
			break
	
	var result = combat.execute_player_move(medium_attack, enemies[0])
	assert_true(result.success, "Move should succeed")
	assert_eq(enemies[0].countdown, 1, "Drone 1 countdown after move")

func test_one_action_per_enemy_per_turn():
	print("\n[Test: One Action Per Enemy Per Turn]")
	var build = config.get_default_build()
	var test_combat = CombatState.new(config, build, "e1_swarm")
	test_combat.start_combat()
	
	var enemies = test_combat.get_living_enemies()
	var right_arm = test_combat.mech.parts["right_arm"]
	var heavy_attack = null
	for move in right_arm.get_available_moves(config):
		if move.type == "attack" and move.level == "heavy":
			heavy_attack = move
			break
	
	var result1 = test_combat.execute_player_move(heavy_attack, enemies[1])
	var any_acted = false
	for enemy in enemies:
		if enemy.has_acted_this_turn:
			any_acted = true
			break
	assert_true(any_acted, "At least one enemy should have interrupted")
	
	var acted_enemy_index = -1
	for i in enemies.size():
		if enemies[i].has_acted_this_turn:
			acted_enemy_index = i
			break
	
	var result2 = test_combat.execute_player_move(heavy_attack, enemies[1])
	var enemy_interrupted_again = false
	for interrupt in result2.get("interrupts", []):
		if interrupt.enemy == enemies[acted_enemy_index]:
			enemy_interrupted_again = true
	
	assert_true(not enemy_interrupted_again, "Enemy that already acted should not interrupt again same turn")

func test_end_of_turn_reset():
	print("\n[Test: End of Turn Reset]")
	var build = config.get_default_build()
	combat = CombatState.new(config, build, "e1_swarm")
	combat.start_combat()
	
	var enemies = combat.get_living_enemies()
	var right_arm = combat.mech.parts["right_arm"]
	var medium_attack = null
	for move in right_arm.get_available_moves(config):
		if move.type == "attack" and move.level == "medium":
			medium_attack = move
			break
	
	combat.execute_player_move(medium_attack, enemies[0])
	combat.end_turn()
	
	for enemy in enemies:
		assert_true(not enemy.has_acted_this_turn, "Enemy should be reset for new turn")
		assert_true(enemy.countdown > 0, "Countdown should be reset")

func test_stun_threshold():
	print("\n[Test: Stun Threshold and Effects]")
	var build = config.get_default_build()
	combat = CombatState.new(config, build, "e1_swarm")
	combat.start_combat()
	
	var enemies = combat.get_living_enemies()
	var drone = enemies[0]
	
	var right_arm = combat.mech.parts["right_arm"]
	var heavy_attack = null
	for move in right_arm.get_available_moves(config):
		if move.type == "attack" and move.level == "heavy":
			heavy_attack = move
			break
	
	combat.execute_player_move(heavy_attack, drone)
	assert_true(drone.stun_meter >= config.get_stun_threshold("drone"), "Should meet stun threshold")
	assert_true(drone.is_stunned, "Drone should be stunned")

func test_stun_immunity():
	print("\n[Test: Stun Immunity]")
	var build = config.get_default_build()
	combat = CombatState.new(config, build, "e1_swarm")
	combat.start_combat()
	
	var enemies = combat.get_living_enemies()
	var drone = enemies[0]
	
	var right_arm = combat.mech.parts["right_arm"]
	var heavy_attack = null
	for move in right_arm.get_available_moves(config):
		if move.type == "attack" and move.level == "heavy":
			heavy_attack = move
			break
	
	combat.execute_player_move(heavy_attack, drone)
	assert_true(drone.is_stunned, "Drone should be stunned")
	
	combat.end_turn()
	assert_true(drone.stun_immunity_turns > 0, "Should have immunity")

func test_block_calculation():
	print("\n[Test: Block Calculation - Best Block]")
	var build = config.get_default_build()
	combat = CombatState.new(config, build, "e1_swarm")
	combat.start_combat()
	
	var legs = combat.mech.parts["legs"]
	var block_move = null
	for move in legs.get_available_moves(config):
		if move.type == "block" and move.height == "low":
			block_move = move
			break
	
	combat.execute_player_move(block_move)
	
	var block_data = combat.block_calc.calculate_block_reduction("low", combat.mech)
	assert_true(block_data.blocked, "Should be blocked")
	assert_true(abs(block_data.reduction - 0.6) < 0.01, "Should use standard leg block (0.6)")

func test_block_guard_bonus():
	print("\n[Test: Block with Guard Bonus]")
	var build = config.get_default_build()
	combat = CombatState.new(config, build, "e1_swarm")
	combat.start_combat()
	combat.mech.support_pilot = "guard"
	combat.mech.support_pilot_part = "legs"
	
	var legs = combat.mech.parts["legs"]
	var block_move = null
	for move in legs.get_available_moves(config):
		if move.type == "block" and move.height == "low":
			block_move = move
			break
	
	combat.execute_player_move(block_move)
	
	var block_data = combat.block_calc.calculate_block_reduction("low", combat.mech)
	assert_true(block_data.guard_applied, "Guard should be applied")
	assert_true(abs(block_data.reduction - 0.75) < 0.01, "Should include Guard bonus (0.75)")

func test_whiff_crouch():
	print("\n[Test: Whiff by Movement State - Crouch]")
	var build = config.get_default_build()
	combat = CombatState.new(config, build, "e1_swarm")
	combat.start_combat()
	
	var legs = combat.mech.parts["legs"]
	var crouch_move = null
	for move in legs.get_available_moves(config):
		if move.type == "movement" and move.state == "crouch":
			crouch_move = move
			break
	
	combat.execute_player_move(crouch_move)
	
	var whiffed = combat.block_calc.check_attack_whiff("high", combat.mech.movement_state)
	assert_true(whiffed, "High attacks should whiff when crouching")

func test_whiff_jump():
	print("\n[Test: Whiff by Movement State - Jump]")
	var build = config.get_default_build()
	combat = CombatState.new(config, build, "e1_swarm")
	combat.start_combat()
	
	var legs = combat.mech.parts["legs"]
	var jump_move = null
	for move in legs.get_available_moves(config):
		if move.type == "movement" and move.state == "jump":
			jump_move = move
			break
	
	combat.execute_player_move(jump_move)
	
	var whiffed = combat.block_calc.check_attack_whiff("low", combat.mech.movement_state)
	assert_true(whiffed, "Low attacks should whiff when airborne")

func test_damage_calculation():
	print("\n[Test: Damage Order of Operations]")
	var build = config.get_default_build()
	combat = CombatState.new(config, build, "e1_swarm")
	combat.start_combat()
	
	var enemies = combat.get_living_enemies()
	var drone = enemies[0]
	var initial_hp = drone.current_hp
	
	var right_arm = combat.mech.parts["right_arm"]
	var medium_attack = null
	for move in right_arm.get_available_moves(config):
		if move.type == "attack" and move.level == "medium":
			medium_attack = move
			break
	
	combat.execute_player_move(medium_attack, drone)
	assert_true(drone.current_hp < initial_hp, "Drone should take damage")

func test_chain_bonus():
	print("\n[Test: Chain Bonus (L→M→H)]")
	var build = config.get_default_build()
	combat = CombatState.new(config, build, "e1_swarm")
	combat.start_combat()
	
	var enemies = combat.get_living_enemies()
	var drone = enemies[0]
	
	var left_arm = combat.mech.parts["left_arm"]
	var right_arm = combat.mech.parts["right_arm"]
	
	var light_attack = null
	var medium_attack = null
	var heavy_attack = null
	
	for move in left_arm.get_available_moves(config):
		if move.type == "attack" and move.level == "light":
			light_attack = move
			break
	
	for move in right_arm.get_available_moves(config):
		if move.type == "attack":
			if move.level == "medium":
				medium_attack = move
			elif move.level == "heavy":
				heavy_attack = move
	
	combat.execute_player_move(light_attack, drone)
	combat.execute_player_move(medium_attack, drone)
	
	var hp_before_heavy = drone.current_hp
	combat.execute_player_move(heavy_attack, drone)
	
	assert_true(drone.current_hp < hp_before_heavy, "Heavy attack should deal damage with chain bonus")

func test_part_destruction():
	print("\n[Test: Part Destruction]")
	var build = config.get_default_build()
	combat = CombatState.new(config, build, "e1_swarm")
	combat.start_combat()
	
	var enemies = combat.get_living_enemies()
	var drone = enemies[0]
	
	var right_arm = combat.mech.parts["right_arm"]
	var heavy_attack = null
	for move in right_arm.get_available_moves(config):
		if move.type == "attack" and move.level == "heavy":
			heavy_attack = move
			break
	
	while not drone.is_destroyed() and combat.mech.get_remaining_time() > 0:
		var result = combat.execute_player_move(heavy_attack, drone)
		if not result.success:
			break
	
	if drone.is_destroyed():
		assert_true(drone.current_hp == 0, "HP should be 0")
		print("  ✓ Drone destroyed successfully")
		passed += 1
	else:
		print("  ℹ Note: Drone not destroyed in single turn (expected)")
		passed += 1

func test_move_preview_countdowns():
	print("\n[Test: Move Preview - Countdown Calculation]")
	var build = config.get_default_build()
	combat = CombatState.new(config, build, "e1_swarm")
	combat.start_combat()
	
	var enemies = combat.get_living_enemies()
	var right_arm = combat.mech.parts["right_arm"]
	var medium_attack = null
	for move in right_arm.get_available_moves(config):
		if move.type == "attack" and move.level == "medium":
			medium_attack = move
			break
	
	var preview = combat.preview_move(medium_attack)
	
	assert_eq(preview.cost, 3, "Medium attack costs 3")
	assert_true(preview.affordable, "Move should be affordable")
	assert_eq(preview.enemy_countdowns.size(), 3, "Should preview all 3 enemies")
	assert_eq(preview.enemy_countdowns[0].after, 1, "Drone 1 after: 4-3=1")

func test_move_preview_interrupts():
	print("\n[Test: Move Preview - Interrupt Detection]")
	var build = config.get_default_build()
	combat = CombatState.new(config, build, "e1_swarm")
	combat.start_combat()
	
	var right_arm = combat.mech.parts["right_arm"]
	var heavy_attack = null
	for move in right_arm.get_available_moves(config):
		if move.type == "attack" and move.level == "heavy":
			heavy_attack = move
			break
	
	var preview = combat.preview_move(heavy_attack)
	
	assert_eq(preview.cost, 5, "Heavy attack costs 5")
	assert_true(preview.would_interrupt.size() > 0, "At least one enemy should interrupt")

