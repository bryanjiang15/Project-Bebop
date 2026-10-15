## Represents the player's mech state and available actions
class_name MechState
extends RefCounted

enum MovementState { STANDING, CROUCHING, AIRBORNE }

var parts: Dictionary = {}
var movement_state: MovementState = MovementState.STANDING
var stun_meter: float = 0.0
var is_stunned: bool = false
var stun_immunity_turns: int = 0
var time_budget: int = 0
var time_spent: int = 0
var focus_uses_remaining: int = 1
var has_changed_state_this_turn: bool = false
var config: ConfigManager

var commander_pilot: String = "default"
var support_pilot: String = ""
var support_pilot_part: String = ""

func _init(p_config: ConfigManager, build: Dictionary):
	config = p_config
	_initialize_parts(build)
	_calculate_time_budget()
	focus_uses_remaining = config.get_focus_stats().get("uses_per_fight", 1)

func _initialize_parts(build: Dictionary):
	if build.has("torso"):
		parts["torso"] = MechPart.new(MechPart.Slot.TORSO, build["torso"], config)
	if build.has("left_arm"):
		parts["left_arm"] = MechPart.new(MechPart.Slot.LEFT_ARM, build["left_arm"], config)
	if build.has("right_arm"):
		parts["right_arm"] = MechPart.new(MechPart.Slot.RIGHT_ARM, build["right_arm"], config)
	if build.has("legs"):
		parts["legs"] = MechPart.new(MechPart.Slot.LEGS, build["legs"], config)
	if build.has("head") and build["head"] != null:
		parts["head"] = MechPart.new(MechPart.Slot.HEAD, build["head"], config)

func _calculate_time_budget():
	var base = config.get_time_budget_base()
	var modifier = 0
	
	if parts.has("torso"):
		var torso: MechPart = parts["torso"]
		modifier = torso.stats.get("time_budget_modifier", 0)
	
	time_budget = base + modifier

func start_turn():
	time_spent = 0
	has_changed_state_this_turn = false
	
	if movement_state == MovementState.AIRBORNE:
		movement_state = MovementState.STANDING
	
	for part_name in parts:
		var part: MechPart = parts[part_name]
		part.is_blocking = false
		part.block_heights = []
	
	if is_stunned:
		var penalty = config.get_stun_player_penalty()
		time_budget = maxi(1, time_budget - penalty)
	
	if stun_immunity_turns > 0:
		stun_immunity_turns -= 1
		if stun_immunity_turns == 0:
			is_stunned = false
			stun_meter = 0.0

func get_remaining_time() -> int:
	return time_budget - time_spent

func can_afford_move(move: Dictionary) -> bool:
	var cost = move.get("cost", 0)
	
	if move.get("type") == "movement" and has_free_state_change():
		cost = 0
	
	return get_remaining_time() >= cost

func has_free_state_change() -> bool:
	if has_changed_state_this_turn:
		return false
	
	if not parts.has("legs"):
		return false
	
	var legs: MechPart = parts["legs"]
	return legs.has_first_change_free()

func execute_move(move: Dictionary) -> Dictionary:
	var result = {
		"success": false,
		"cost": 0,
		"blocks_dropped": []
	}
	
	if not can_afford_move(move):
		return result
	
	var cost = move.get("cost", 0)
	var move_type = move.get("type", "")
	
	match move_type:
		"attack":
			_execute_attack(move)
			var part: MechPart = move.get("part")
			if part.is_blocking:
				part.is_blocking = false
				part.block_heights = []
				result.blocks_dropped.append(part)
		
		"block":
			_execute_block(move)
		
		"movement":
			if has_free_state_change():
				cost = 0
			_execute_movement(move)
			if parts.has("legs"):
				var legs: MechPart = parts["legs"]
				if legs.is_blocking:
					legs.is_blocking = false
					legs.block_heights = []
					result.blocks_dropped.append(legs)
	
	time_spent += cost
	result.success = true
	result.cost = cost
	return result

func _execute_attack(move: Dictionary):
	pass

func _execute_block(move: Dictionary):
	var part: MechPart = move.get("part")
	var height = move.get("height", "")
	
	part.is_blocking = true
	part.block_heights = [height]

func _execute_movement(move: Dictionary):
	var new_state = move.get("state", "standing")
	
	match new_state:
		"jump":
			if parts.has("legs") and not parts["legs"].is_destroyed():
				var legs: MechPart = parts["legs"]
				if legs.can_jump():
					movement_state = MovementState.AIRBORNE
					has_changed_state_this_turn = true
		"crouch":
			if parts.has("legs") and not parts["legs"].is_destroyed():
				movement_state = MovementState.CROUCHING
				has_changed_state_this_turn = true
		"stand":
			movement_state = MovementState.STANDING
			has_changed_state_this_turn = true

func use_focus() -> bool:
	if focus_uses_remaining <= 0:
		return false
	
	var focus_bonus = config.get_focus_stats().get("time_bonus", 2)
	time_budget += focus_bonus
	focus_uses_remaining -= 1
	return true

func add_stun(amount: float):
	if stun_immunity_turns > 0:
		return
	
	stun_meter += amount
	
	var threshold = config.get_stun_threshold("mech")
	if stun_meter >= threshold:
		is_stunned = true
		stun_immunity_turns = config.get_stun_immunity_turns() + 1

func take_damage(target_part_name: String, amount: int) -> Dictionary:
	var result = {
		"part": target_part_name,
		"damage": 0,
		"destroyed": false,
		"redirected": false
	}
	
	if not parts.has(target_part_name):
		target_part_name = "torso"
		result.redirected = true
	
	var part: MechPart = parts.get(target_part_name)
	if part.is_destroyed():
		target_part_name = "torso"
		part = parts.get("torso")
		result.redirected = true
	
	result.part = target_part_name
	result.damage = part.take_damage(amount)
	result.destroyed = part.is_destroyed()
	
	return result

func is_defeated() -> bool:
	if not parts.has("torso"):
		return true
	return parts["torso"].is_destroyed()

func get_active_blocks() -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	
	for part_name in parts:
		var part: MechPart = parts[part_name]
		if part.is_blocking and not part.is_destroyed():
			for height in part.block_heights:
				blocks.append({
					"part": part,
					"part_name": part_name,
					"height": height,
					"reduction": part.get_block_reduction()
				})
	
	return blocks
