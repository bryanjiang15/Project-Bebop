## Main combat state manager - orchestrates all combat logic
class_name CombatState
extends RefCounted

signal move_executed(move_data: Dictionary)
signal enemy_interrupted(enemy: EnemyState)
signal turn_ended()
signal combat_ended(victory: bool)

var config: ConfigManager
var mech: MechState
var enemies: Array[EnemyState] = []
var turn_log: TurnLog
var damage_calc: DamageCalculator
var block_calc: BlockCalculator

var current_turn: int = 0
var player_chain: Array[String] = []
var is_combat_active: bool = false

func _init(p_config: ConfigManager, build: Dictionary, encounter_id: String):
	config = p_config
	mech = MechState.new(config, build)
	turn_log = TurnLog.new()
	damage_calc = DamageCalculator.new(config)
	block_calc = BlockCalculator.new(config)
	
	_initialize_enemies(encounter_id)

func _initialize_enemies(encounter_id: String):
	var encounter_data = config.get_encounter_data(encounter_id)
	var enemies_data = encounter_data.get("enemies", [])
	
	for enemy_data in enemies_data:
		var enemy = EnemyState.new(config, enemy_data)
		enemies.append(enemy)

func start_combat():
	is_combat_active = true
	current_turn = 0
	start_new_turn()

func start_new_turn():
	current_turn += 1
	mech.start_turn()
	player_chain.clear()
	
	for enemy in enemies:
		enemy.reset_for_new_turn()
	
	turn_log.start_new_turn(current_turn)

func execute_player_move(move: Dictionary, target_enemy: EnemyState = null) -> Dictionary:
	if not is_combat_active:
		return {"success": false, "reason": "Combat not active"}
	
	if not mech.can_afford_move(move):
		return {"success": false, "reason": "Cannot afford move"}
	
	var result = mech.execute_move(move)
	if not result.success:
		return result
	
	var move_type = move.get("type", "")
	var part: MechPart = move.get("part")
	var part_name = _get_part_name(part)
	
	turn_log.log_player_move(part_name, move.get("name", ""), result.cost, mech.get_remaining_time())
	
	if move_type == "attack":
		_execute_player_attack(part, move, target_enemy, part_name)
		
		var level = move.get("level", "")
		if level in ["light", "medium", "heavy"]:
			_update_chain(level)
	else:
		player_chain.clear()
	
	tick_all_enemy_countdowns(result.cost)
	
	var interrupts = _check_and_execute_interrupts()
	result.interrupts = interrupts
	
	if _check_combat_end():
		result.combat_ended = true
	
	return result

func _execute_player_attack(attacker_part: MechPart, move: Dictionary, target: EnemyState, part_name: String):
	if target == null or target.is_destroyed():
		return
	
	var attack_level = move.get("level", "")
	var is_chain_completed = _is_chain_completed(attack_level)
	
	var damage_data = damage_calc.calculate_attack_damage(
		attacker_part,
		attack_level,
		is_chain_completed,
		target.is_stunned,
		mech.support_pilot,
		mech.support_pilot_part,
		part_name
	)
	
	var final_damage = damage_data.damage_before_block
	target.take_damage(final_damage)
	
	var stun_amount = damage_data.stun
	target.add_stun(stun_amount)
	
	turn_log.log_player_attack(part_name, target.enemy_id, attack_level, final_damage, stun_amount)
	
	if target.is_stunned and stun_amount > 0:
		turn_log.log_stun_triggered(target.enemy_id, false)
	
	if target.is_destroyed():
		turn_log.log_enemy_destroyed(target.enemy_id)

func _update_chain(level: String):
	if not config.get_chain_enabled():
		player_chain.clear()
		return
	
	if player_chain.is_empty() and level == "light":
		player_chain.append("light")
	elif player_chain == ["light"] and level == "medium":
		player_chain.append("medium")
	elif player_chain == ["light", "medium"] and level == "heavy":
		player_chain.append("heavy")
	else:
		player_chain.clear()
		if level == "light":
			player_chain.append("light")

func _is_chain_completed(current_level: String) -> bool:
	return player_chain == ["light", "medium"] and current_level == "heavy"

func tick_all_enemy_countdowns(amount: int):
	for enemy in enemies:
		if not enemy.is_destroyed():
			enemy.tick_countdown(amount)

func _check_and_execute_interrupts() -> Array[Dictionary]:
	var interrupts: Array[Dictionary] = []
	
	for enemy in enemies:
		if enemy.should_interrupt():
			var interrupt_result = _execute_enemy_action(enemy, true)
			interrupts.append(interrupt_result)
			enemy.advance_to_next_move()
			
			if _check_combat_end():
				break
	
	return interrupts

func end_turn() -> Dictionary:
	player_chain.clear()
	
	var end_of_turn_actions: Array[Dictionary] = []
	
	for enemy in enemies:
		if not enemy.is_destroyed() and not enemy.has_acted_this_turn:
			var action_result = _execute_enemy_action(enemy, false)
			end_of_turn_actions.append(action_result)
	
	for enemy in enemies:
		if not enemy.is_destroyed():
			enemy.reset_countdown()
	
	turn_log.log_turn_end()
	
	var result = {
		"end_of_turn_actions": end_of_turn_actions,
		"combat_ended": false
	}
	
	if _check_combat_end():
		result.combat_ended = true
	else:
		start_new_turn()
	
	return result

func _execute_enemy_action(enemy: EnemyState, is_interrupt: bool) -> Dictionary:
	var move = enemy.execute_move()
	var move_name = move.get("name", "Unknown")
	
	if is_interrupt:
		turn_log.log_enemy_interrupt(enemy.enemy_id, move_name)
	
	var attack_height = move.get("height", "mid")
	var target_part_name = move.get("target_part", "torso")
	
	if target_part_name == "head_or_torso":
		target_part_name = "head" if mech.parts.has("head") and not mech.parts["head"].is_destroyed() else "torso"
	
	var whiffed = block_calc.check_attack_whiff(attack_height, mech.movement_state)
	
	var damage = 0
	var blocked = false
	var block_reduction = 0.0
	var stun_amount = 0.0
	
	if not whiffed:
		var damage_data = damage_calc.calculate_enemy_damage(move, mech.is_stunned)
		var damage_before_block = damage_data.damage_before_block
		
		var block_data = block_calc.calculate_block_reduction(attack_height, mech)
		blocked = block_data.blocked
		block_reduction = block_data.reduction
		
		if blocked:
			damage = damage_calc.apply_block_reduction(damage_before_block, block_reduction)
			stun_amount = damage_before_block * config.get_value("stun.blocked_hit_stun_multiplier", 0.5)
		else:
			damage = damage_before_block
			stun_amount = damage_before_block
		
		var damage_result = mech.take_damage(target_part_name, damage)
		mech.add_stun(stun_amount)
		
		if damage_result.destroyed:
			turn_log.log_part_destroyed(damage_result.part)
		
		if mech.is_stunned and stun_amount > 0:
			turn_log.log_stun_triggered("mech", true)
	
	turn_log.log_enemy_attack(enemy.enemy_id, move_name, target_part_name, damage, blocked, whiffed, stun_amount)
	
	return {
		"enemy": enemy,
		"move": move,
		"damage": damage,
		"whiffed": whiffed,
		"blocked": blocked,
		"block_reduction": block_reduction,
		"is_interrupt": is_interrupt
	}

func use_focus() -> bool:
	var success = mech.use_focus()
	if success:
		turn_log.log_focus_used()
	return success

func _check_combat_end() -> bool:
	if mech.is_defeated():
		_end_combat(false)
		return true
	
	var all_enemies_dead = true
	for enemy in enemies:
		if not enemy.is_destroyed():
			all_enemies_dead = false
			break
	
	if all_enemies_dead:
		_end_combat(true)
		return true
	
	return false

func _end_combat(victory: bool):
	is_combat_active = false
	turn_log.log_combat_end(victory, current_turn)
	combat_ended.emit(victory)

func _get_part_name(part: MechPart) -> String:
	for part_name in mech.parts:
		if mech.parts[part_name] == part:
			return part_name
	return "unknown"

func get_living_enemies() -> Array[EnemyState]:
	var living: Array[EnemyState] = []
	for enemy in enemies:
		if not enemy.is_destroyed():
			living.append(enemy)
	return living

func export_turn_log() -> String:
	return turn_log.export_to_json()
