## Records all combat events for review and export
class_name TurnLog
extends RefCounted

var events: Array[Dictionary] = []
var current_turn: int = 0

func start_new_turn(turn_number: int):
	current_turn = turn_number
	events.append({
		"type": "turn_start",
		"turn": current_turn,
		"timestamp": Time.get_ticks_msec()
	})

func log_player_move(part_name: String, move_name: String, cost: int, time_remaining: int):
	events.append({
		"type": "player_move",
		"turn": current_turn,
		"part": part_name,
		"move": move_name,
		"cost": cost,
		"time_remaining": time_remaining,
		"timestamp": Time.get_ticks_msec()
	})

func log_player_attack(attacker_part: String, target_enemy: String, attack_level: String, damage: int, stun: float):
	events.append({
		"type": "player_attack",
		"turn": current_turn,
		"attacker": attacker_part,
		"target": target_enemy,
		"level": attack_level,
		"damage": damage,
		"stun": stun,
		"timestamp": Time.get_ticks_msec()
	})

func log_enemy_interrupt(enemy_id: String, move_name: String):
	events.append({
		"type": "enemy_interrupt",
		"turn": current_turn,
		"enemy": enemy_id,
		"move": move_name,
		"timestamp": Time.get_ticks_msec()
	})

func log_enemy_attack(enemy_id: String, move_name: String, target_part: String, damage: int, blocked: bool, whiffed: bool, stun: float):
	events.append({
		"type": "enemy_attack",
		"turn": current_turn,
		"enemy": enemy_id,
		"move": move_name,
		"target": target_part,
		"damage": damage,
		"blocked": blocked,
		"whiffed": whiffed,
		"stun": stun,
		"timestamp": Time.get_ticks_msec()
	})

func log_part_destroyed(part_name: String):
	events.append({
		"type": "part_destroyed",
		"turn": current_turn,
		"part": part_name,
		"timestamp": Time.get_ticks_msec()
	})

func log_enemy_destroyed(enemy_id: String):
	events.append({
		"type": "enemy_destroyed",
		"turn": current_turn,
		"enemy": enemy_id,
		"timestamp": Time.get_ticks_msec()
	})

func log_stun_triggered(unit_id: String, is_player: bool):
	events.append({
		"type": "stun_triggered",
		"turn": current_turn,
		"unit": unit_id,
		"is_player": is_player,
		"timestamp": Time.get_ticks_msec()
	})

func log_focus_used():
	events.append({
		"type": "focus_used",
		"turn": current_turn,
		"timestamp": Time.get_ticks_msec()
	})

func log_turn_end():
	events.append({
		"type": "turn_end",
		"turn": current_turn,
		"timestamp": Time.get_ticks_msec()
	})

func log_combat_end(victory: bool, turns_taken: int):
	events.append({
		"type": "combat_end",
		"victory": victory,
		"turns_taken": turns_taken,
		"timestamp": Time.get_ticks_msec()
	})

func get_events() -> Array[Dictionary]:
	return events.duplicate()

func export_to_json() -> String:
	var export_data = {
		"events": events,
		"total_turns": current_turn,
		"export_time": Time.get_datetime_string_from_system()
	}
	return JSON.stringify(export_data, "\t")

func clear():
	events.clear()
	current_turn = 0
