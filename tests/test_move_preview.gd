## Test for move preview functionality
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

func test_preview_shows_correct_countdowns():
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
	
	assert_eq(preview.enemy_countdowns[0].current, 4, "Drone 1 starts at 4")
	assert_eq(preview.enemy_countdowns[0].after, 1, "Drone 1 after: 4-3=1")
	assert_false(preview.enemy_countdowns[0].would_interrupt, "Drone 1 won't interrupt")
	
	assert_eq(preview.enemy_countdowns[1].current, 5, "Drone 2 starts at 5")
	assert_eq(preview.enemy_countdowns[1].after, 2, "Drone 2 after: 5-3=2")
	assert_false(preview.enemy_countdowns[1].would_interrupt, "Drone 2 won't interrupt")

func test_preview_identifies_interrupts():
	combat.start_combat()
	
	var enemies = combat.get_living_enemies()
	var right_arm = combat.mech.parts["right_arm"]
	var heavy_attack = null
	for move in right_arm.get_available_moves(config):
		if move.type == "attack" and move.level == "heavy":
			heavy_attack = move
			break
	
	var preview = combat.preview_move(heavy_attack)
	
	assert_eq(preview.cost, 5, "Heavy attack costs 5")
	assert_gt(preview.would_interrupt.size(), 0, "At least one enemy should interrupt")
	
	var drone_2_will_interrupt = false
	for countdown_data in preview.enemy_countdowns:
		if countdown_data.enemy == enemies[1]:
			drone_2_will_interrupt = countdown_data.would_interrupt
	
	assert_true(drone_2_will_interrupt, "Drone 2 (countdown 5) should interrupt after heavy (cost 5)")

func test_preview_respects_already_acted():
	combat.start_combat()
	
	var enemies = combat.get_living_enemies()
	var right_arm = combat.mech.parts["right_arm"]
	var heavy_attack = null
	for move in right_arm.get_available_moves(config):
		if move.type == "attack" and move.level == "heavy":
			heavy_attack = move
			break
	
	combat.execute_player_move(heavy_attack, enemies[1])
	
	var acted_enemy = null
	for enemy in enemies:
		if enemy.has_acted_this_turn:
			acted_enemy = enemy
			break
	
	assert_not_null(acted_enemy, "At least one enemy should have acted")
	
	var preview = combat.preview_move(heavy_attack)
	var acted_enemy_in_preview = false
	for countdown_data in preview.enemy_countdowns:
		if countdown_data.enemy == acted_enemy:
			assert_false(countdown_data.would_interrupt, "Already-acted enemy should not be marked as would_interrupt")
			acted_enemy_in_preview = true
	
	assert_true(acted_enemy_in_preview, "Acted enemy should be in preview")

func test_preview_handles_free_movement():
	var sprinter_build = config.get_default_build()
	sprinter_build.legs = "sprinter"
	combat = CombatState.new(config, sprinter_build, "e1_swarm")
	combat.start_combat()
	
	var legs = combat.mech.parts["legs"]
	var jump_move = null
	for move in legs.get_available_moves(config):
		if move.type == "movement" and move.state == "jump":
			jump_move = move
			break
	
	var preview = combat.preview_move(jump_move)
	
	assert_eq(preview.cost, 0, "First state change should be free with sprinter legs")
	
	var enemies = combat.get_living_enemies()
	for countdown_data in preview.enemy_countdowns:
		assert_eq(countdown_data.current, countdown_data.after, "Countdowns should not change for free move")
