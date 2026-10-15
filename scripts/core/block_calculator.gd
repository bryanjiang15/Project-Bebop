## Calculates block reduction for incoming attacks
class_name BlockCalculator
extends RefCounted

var config: ConfigManager

func _init(p_config: ConfigManager):
	config = p_config

func calculate_block_reduction(
	attack_height: String,
	mech_state: MechState
) -> Dictionary:
	
	var active_blocks = mech_state.get_active_blocks()
	var matching_blocks: Array[Dictionary] = []
	
	for block_data in active_blocks:
		if block_data.height == attack_height:
			matching_blocks.append(block_data)
	
	if matching_blocks.is_empty():
		return {
			"blocked": false,
			"reduction": 0.0,
			"best_block_part": "",
			"guard_applied": false
		}
	
	var best_reduction = 0.0
	var best_block_part = ""
	
	for block_data in matching_blocks:
		var reduction = block_data.reduction
		if reduction > best_reduction:
			best_reduction = reduction
			best_block_part = block_data.part_name
	
	var guard_applied = false
	if mech_state.support_pilot == "guard":
		for block_data in matching_blocks:
			if block_data.part_name == mech_state.support_pilot_part:
				var guard_bonus = config.get_pilot_bonuses().get("guard_block_bonus", 0.0)
				best_reduction += guard_bonus
				guard_applied = true
				break
	
	var cap = config.get_block_stats().get("damage_reduction_cap", 0.9)
	best_reduction = minf(best_reduction, cap)
	
	return {
		"blocked": true,
		"reduction": best_reduction,
		"best_block_part": best_block_part,
		"guard_applied": guard_applied
	}

func check_attack_whiff(
	attack_height: String,
	mech_movement_state: int
) -> bool:
	
	match attack_height:
		"high":
			return mech_movement_state == MechState.MovementState.CROUCHING
		"low":
			return mech_movement_state == MechState.MovementState.AIRBORNE
		_:
			return false
