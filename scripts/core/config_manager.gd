## ConfigManager - Loads and validates game configuration from JSON
class_name ConfigManager
extends RefCounted

var config: Dictionary = {}
var config_path: String = "res://config/game_config.json"

func _init():
	load_config()

func load_config() -> bool:
	var file = FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		push_error("Failed to load config file: " + config_path)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse config JSON: " + json.get_error_message())
		return false
	
	config = json.data
	return true

func reload_config() -> bool:
	return load_config()

func get_value(path: String, default = null):
	var keys = path.split(".")
	var current = config
	
	for key in keys:
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			return default
	
	return current

func get_time_budget_base() -> int:
	return get_value("combat.time_budget_base", 10)

func get_attack_stats(level: String) -> Dictionary:
	return get_value("attacks." + level, {})

func get_block_stats() -> Dictionary:
	return get_value("blocking", {})

func get_movement_cost() -> int:
	return get_value("movement.state_change_cost", 1)

func get_chain_enabled() -> bool:
	return get_value("chain.enabled", true)

func get_chain_multiplier() -> float:
	return get_value("chain.heavy_multiplier", 1.5)

func get_stun_threshold(unit_type: String) -> int:
	return get_value("stun." + unit_type + "_threshold", 60)

func get_stun_damage_multiplier() -> float:
	return get_value("stun.damage_multiplier", 1.5)

func get_stun_player_penalty() -> int:
	return get_value("stun.player_time_penalty", 4)

func get_stun_enemy_delay() -> int:
	return get_value("stun.enemy_countdown_delay", 4)

func get_stun_immunity_turns() -> int:
	return get_value("stun.immunity_duration_turns", 1)

func get_part_stats(slot: String, variant: String) -> Dictionary:
	return get_value("parts." + slot + "." + variant, {})

func get_encounter_data(encounter_id: String) -> Dictionary:
	return get_value("encounters." + encounter_id, {})

func get_default_build() -> Dictionary:
	return get_value("default_build", {})

func get_pilot_bonuses() -> Dictionary:
	return get_value("pilots", {})

func get_focus_stats() -> Dictionary:
	return get_value("focus", {})
