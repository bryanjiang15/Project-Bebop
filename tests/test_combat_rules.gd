## Test suite for combat core rules
extends GutTest

var config: ConfigManager
var combat: CombatState

func before_each():
	config = ConfigManager.new()
	var build = config.get_default_build()
	combat = CombatState.new(config, build, "e1_swarm")

func after_each():
	combat = null
	config = null

func test_interrupt_timing_and_ordering():
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
	assert_eq(enemies[1].countdown, 2, "Drone 2 countdown after move")
	assert_eq(enemies[2].countdown, 3, "Drone 3 countdown after move")
	
	result = combat.execute_player_move(medium_attack, enemies[1])
	
	assert_eq(enemies[0].countdown, 0, "Drone 1 at 0")
	assert_true(enemies[0].has_acted_this_turn, "Drone 1 should have interrupted")

func test_one_action_per_enemy_per_turn():
	combat.start_combat()
	
	var enemies = combat.get_living_enemies()
	var right_arm = combat.mech.parts["right_arm"]
	var heavy_attack = null
	for move in right_arm.get_available_moves(config):
		if move.type == "attack" and move.level == "heavy":
			heavy_attack = move
			break
	
	combat.execute_player_move(heavy_attack, enemies[0])
	
	assert_true(enemies[0].has_acted_this_turn, "Enemy should have acted")
	
	var second_result = combat.execute_player_move(heavy_attack, enemies[0])
	
	assert_false(enemies[0].should_interrupt(), "Enemy should not interrupt again")

func test_end_of_turn_reset():
	combat.start_combat()
	
	var enemies = combat.get_living_enemies()
	var initial_countdown_1 = enemies[0].countdown
	
	var right_arm = combat.mech.parts["right_arm"]
	var medium_attack = null
	for move in right_arm.get_available_moves(config):
		if move.type == "attack" and move.level == "medium":
			medium_attack = move
			break
	
	combat.execute_player_move(medium_attack, enemies[0])
	
	var result = combat.end_turn()
	
	for enemy in enemies:
		assert_false(enemy.has_acted_this_turn, "Enemy should be reset for new turn")
		assert_gt(enemy.countdown, 0, "Countdown should be reset")

func test_stun_delay_carryover():
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
	combat.execute_player_move(heavy_attack, drone)
	
	assert_true(drone.is_stunned, "Drone should be stunned")
	assert_gt(drone.countdown, drone.get_current_move().countdown, "Countdown should be delayed")

func test_block_best_block_calculation():
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
	assert_almost_eq(block_data.reduction, 0.6, 0.01, "Should use standard leg block")

func test_block_guard_bonus():
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
	assert_true(block_data.blocked, "Should be blocked")
	assert_true(block_data.guard_applied, "Guard should be applied")
	assert_almost_eq(block_data.reduction, 0.75, 0.01, "Should include Guard bonus")

func test_block_90_percent_cap():
	combat.start_combat()
	combat.mech.support_pilot = "guard"
	combat.mech.support_pilot_part = "right_arm"
	
	var shield_build = config.get_default_build()
	shield_build.right_arm = "shield"
	var shield_combat = CombatState.new(config, shield_build, "e1_swarm")
	shield_combat.start_combat()
	shield_combat.mech.support_pilot = "guard"
	shield_combat.mech.support_pilot_part = "right_arm"
	
	var right_arm = shield_combat.mech.parts["right_arm"]
	var block_move = null
	for move in right_arm.get_available_moves(config):
		if move.type == "block" and move.height == "mid":
			block_move = move
			break
	
	shield_combat.execute_player_move(block_move)
	
	var block_data = shield_combat.block_calc.calculate_block_reduction("mid", shield_combat.mech)
	assert_lte(block_data.reduction, 0.9, "Should cap at 90%")

func test_whiff_by_movement_state_crouch():
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

func test_whiff_by_movement_state_jump():
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

func test_damage_order_of_operations():
	combat.start_combat()
	combat.mech.support_pilot = "gunner"
	combat.mech.support_pilot_part = "right_arm"
	
	var enemies = combat.get_living_enemies()
	var drone = enemies[0]
	
	var right_arm = combat.mech.parts["right_arm"]
	
	var light_attack = null
	var medium_attack = null
	var heavy_attack = null
	
	for move in right_arm.get_available_moves(config):
		if move.type == "attack":
			if move.level == "light":
				light_attack = move
			elif move.level == "medium":
				medium_attack = move
			elif move.level == "heavy":
				heavy_attack = move
	
	combat.execute_player_move(light_attack, drone)
	combat.execute_player_move(medium_attack, drone)
	combat.execute_player_move(heavy_attack, drone)
	
	assert_true(drone.is_destroyed(), "Drone should be destroyed by chain")

func test_stun_threshold_and_effects():
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
	
	var immunity_turns = config.get_stun_immunity_turns()
	assert_gt(drone.stun_immunity_turns, 0, "Should have immunity")
	
	var initial_meter = drone.stun_meter
	combat.execute_player_move(heavy_attack, drone)
	assert_eq(drone.stun_meter, initial_meter, "Stun meter should not increase during immunity")

func test_part_destruction():
	combat.start_combat()
	
	var enemies = combat.get_living_enemies()
	var drone = enemies[0]
	
	var right_arm = combat.mech.parts["right_arm"]
	var heavy_attack = null
	for move in right_arm.get_available_moves(config):
		if move.type == "attack" and move.level == "heavy":
			heavy_attack = move
			break
	
	while not drone.is_destroyed():
		combat.execute_player_move(heavy_attack, drone)
	
	assert_true(drone.is_destroyed(), "Drone should be destroyed")
	assert_eq(drone.current_hp, 0, "HP should be 0")

func test_torso_destruction_ends_combat():
	combat.start_combat()
	
	combat.mech.parts["torso"].current_hp = 1
	
	var enemies = combat.get_living_enemies()
	
	combat.end_turn()
	
	assert_false(combat.is_combat_active, "Combat should end when torso destroyed")
