## Represents a single part of the mech (torso, arm, leg, head)
class_name MechPart
extends RefCounted

enum Slot { TORSO, LEFT_ARM, RIGHT_ARM, LEGS, HEAD }
enum WeaponType { BARE_HAND, SWORD, SHIELD, BODY, LEGS_WEAPON, NONE }

var slot: Slot
var variant: String
var max_hp: int
var current_hp: int
var weapon_type: WeaponType
var stats: Dictionary
var is_blocking: bool = false
var block_heights: Array[String] = []

func _init(p_slot: Slot, p_variant: String, config: ConfigManager):
	slot = p_slot
	variant = p_variant
	
	var slot_name = _slot_to_string(slot)
	stats = config.get_part_stats(slot_name, variant)
	max_hp = stats.get("hp", 20)
	current_hp = max_hp
	
	weapon_type = _determine_weapon_type(slot, variant)

func _slot_to_string(p_slot: Slot) -> String:
	match p_slot:
		Slot.TORSO: return "torso"
		Slot.LEFT_ARM: return "arm"
		Slot.RIGHT_ARM: return "arm"
		Slot.LEGS: return "legs"
		Slot.HEAD: return "head"
		_: return ""

func _determine_weapon_type(p_slot: Slot, p_variant: String) -> WeaponType:
	if p_slot == Slot.LEFT_ARM or p_slot == Slot.RIGHT_ARM:
		match p_variant:
			"bare_hand": return WeaponType.BARE_HAND
			"sword": return WeaponType.SWORD
			"shield": return WeaponType.SHIELD
	elif p_slot == Slot.TORSO:
		return WeaponType.BODY
	elif p_slot == Slot.LEGS:
		return WeaponType.LEGS_WEAPON
	
	return WeaponType.NONE

func is_destroyed() -> bool:
	return current_hp <= 0

func take_damage(amount: int) -> int:
	if is_destroyed():
		return 0
	
	var actual_damage = mini(amount, current_hp)
	current_hp -= actual_damage
	return actual_damage

func get_available_moves(config: ConfigManager) -> Array[Dictionary]:
	if is_destroyed():
		return []
	
	var moves: Array[Dictionary] = []
	
	match weapon_type:
		WeaponType.BARE_HAND:
			moves.append(_create_attack_move("Light", "light", config))
			moves.append(_create_attack_move("Medium", "medium", config))
			moves.append(_create_block_move("mid", config))
			moves.append(_create_block_move("high", config))
		
		WeaponType.SWORD:
			moves.append(_create_attack_move("Medium", "medium", config))
			moves.append(_create_attack_move("Heavy", "heavy", config))
			moves.append(_create_block_move("mid", config))
			moves.append(_create_block_move("high", config))
		
		WeaponType.SHIELD:
			moves.append(_create_attack_move("Light", "light", config))
			moves.append(_create_block_move("mid", config))
			moves.append(_create_block_move("high", config))
		
		WeaponType.BODY:
			moves.append(_create_attack_move("Medium", "medium", config))
			moves.append(_create_block_move("mid", config))
			moves.append(_create_block_move("high", config))
		
		WeaponType.LEGS_WEAPON:
			moves.append(_create_attack_move("Light", "light", config))
			moves.append(_create_movement_move("Jump", config))
			moves.append(_create_movement_move("Crouch", config))
			moves.append(_create_movement_move("Stand", config))
			moves.append(_create_block_move("low", config))
	
	return moves

func _create_attack_move(name: String, level: String, config: ConfigManager) -> Dictionary:
	var attack_stats = config.get_attack_stats(level)
	var cost = attack_stats.get("cost", 2)
	
	if weapon_type == WeaponType.BARE_HAND and level == "light":
		cost = maxi(1, cost + stats.get("light_cost_modifier", 0))
	
	return {
		"name": name,
		"type": "attack",
		"level": level,
		"cost": cost,
		"part": self
	}

func _create_block_move(height: String, config: ConfigManager) -> Dictionary:
	var block_stats = config.get_block_stats()
	return {
		"name": "Block " + height.capitalize(),
		"type": "block",
		"height": height,
		"cost": block_stats.get("cost", 1),
		"part": self
	}

func _create_movement_move(name: String, config: ConfigManager) -> Dictionary:
	return {
		"name": name,
		"type": "movement",
		"state": name.to_lower(),
		"cost": config.get_movement_cost(),
		"part": self
	}

func get_block_reduction() -> float:
	return stats.get("block_reduction", 0.6)

func can_jump() -> bool:
	if slot != Slot.LEGS:
		return false
	return stats.get("can_jump", true)

func has_first_change_free() -> bool:
	if slot != Slot.LEGS:
		return false
	return stats.get("first_change_free", false)
