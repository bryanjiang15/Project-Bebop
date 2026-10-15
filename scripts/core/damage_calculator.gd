## Calculates damage with all modifiers
class_name DamageCalculator
extends RefCounted

var config: ConfigManager

func _init(p_config: ConfigManager):
	config = p_config

func calculate_attack_damage(
	attacker_part: MechPart,
	attack_level: String,
	is_chain_completed: bool,
	target_is_stunned: bool,
	support_pilot: String,
	support_pilot_part_name: String,
	attacker_part_name: String
) -> Dictionary:
	
	var attack_stats = config.get_attack_stats(attack_level)
	var base_damage = attack_stats.get("damage", 0)
	var stun_value = attack_stats.get("stun", 0)
	
	var weapon_bonus = 0
	if attacker_part.weapon_type == MechPart.WeaponType.SWORD and attack_level == "heavy":
		weapon_bonus = attacker_part.stats.get("heavy_damage_bonus", 0)
	
	var gunner_bonus = 0
	if support_pilot == "gunner" and support_pilot_part_name == attacker_part_name:
		gunner_bonus = config.get_pilot_bonuses().get("gunner_damage_bonus", 0)
	
	var chain_multiplier = 1.0
	if is_chain_completed and attack_level == "heavy":
		chain_multiplier = config.get_chain_multiplier()
	
	var stun_multiplier = 1.0
	if target_is_stunned:
		stun_multiplier = config.get_stun_damage_multiplier()
	
	var damage_float = (base_damage + weapon_bonus + gunner_bonus) * chain_multiplier * stun_multiplier
	
	return {
		"base_damage": base_damage,
		"weapon_bonus": weapon_bonus,
		"gunner_bonus": gunner_bonus,
		"chain_multiplier": chain_multiplier,
		"stun_multiplier": stun_multiplier,
		"damage_before_block": int(damage_float),
		"stun": stun_value
	}

func calculate_enemy_damage(
	move: Dictionary,
	target_is_stunned: bool
) -> Dictionary:
	
	var base_damage = move.get("damage", 0)
	var stun_multiplier = 1.0
	
	if target_is_stunned:
		stun_multiplier = config.get_stun_damage_multiplier()
	
	var damage_float = base_damage * stun_multiplier
	
	return {
		"base_damage": base_damage,
		"stun_multiplier": stun_multiplier,
		"damage_before_block": int(damage_float),
		"stun": 0
	}

func apply_block_reduction(
	damage_before_block: int,
	block_reduction: float
) -> int:
	
	var damage_float = damage_before_block * (1.0 - block_reduction)
	return int(floor(damage_float))
