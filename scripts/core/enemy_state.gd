## Represents an enemy in combat
class_name EnemyState
extends RefCounted

var enemy_id: String
var max_hp: int
var current_hp: int
var moves: Array[Dictionary] = []
var current_move_index: int = 0
var countdown: int = 0
var has_acted_this_turn: bool = false
var stun_meter: float = 0.0
var is_stunned: bool = false
var stun_immunity_turns: int = 0
var stun_delay: int = 0
var config: ConfigManager
var is_first_turn: bool = true

func _init(p_config: ConfigManager, enemy_data: Dictionary):
	config = p_config
	enemy_id = enemy_data.get("id", "enemy")
	max_hp = enemy_data.get("hp", 20)
	current_hp = max_hp
	
	var moves_data = enemy_data.get("moves", [])
	for move_data in moves_data:
		moves.append(move_data.duplicate())
	
	if moves.size() > 0:
		var initial_countdown = enemy_data.get("initial_countdown_turn_1", -1)
		if initial_countdown > 0:
			countdown = initial_countdown
		else:
			countdown = moves[0].get("countdown", 5)

func get_current_move() -> Dictionary:
	if moves.is_empty():
		return {}
	return moves[current_move_index]

func get_next_move() -> Dictionary:
	if moves.is_empty():
		return {}
	var next_index = (current_move_index + 1) % moves.size()
	return moves[next_index]

func tick_countdown(amount: int):
	if has_acted_this_turn:
		return
	
	countdown = maxi(0, countdown - amount)

func should_interrupt() -> bool:
	return countdown <= 0 and not has_acted_this_turn

func execute_move() -> Dictionary:
	var move = get_current_move()
	has_acted_this_turn = true
	
	return move

func advance_to_next_move():
	current_move_index = (current_move_index + 1) % moves.size()
	var next_move = get_current_move()
	countdown = next_move.get("countdown", 5)
	
	if stun_delay > 0:
		countdown += stun_delay
		stun_delay = 0

func reset_for_new_turn():
	has_acted_this_turn = false
	is_first_turn = false
	
	if stun_immunity_turns > 0:
		stun_immunity_turns -= 1
		if stun_immunity_turns == 0:
			is_stunned = false
			stun_meter = 0.0

func reset_countdown():
	if not has_acted_this_turn:
		var move = get_current_move()
		countdown = move.get("countdown", 5)
		
		if stun_delay > 0:
			countdown += stun_delay
			stun_delay = 0

func add_stun(amount: float):
	if stun_immunity_turns > 0:
		return
	
	stun_meter += amount
	
	var unit_type = "drone" if max_hp <= 20 else "miniboss"
	var threshold = config.get_stun_threshold(unit_type)
	
	if stun_meter >= threshold:
		is_stunned = true
		stun_immunity_turns = config.get_stun_immunity_turns() + 1
		
		var delay = config.get_stun_enemy_delay()
		if has_acted_this_turn:
			stun_delay += delay
		else:
			countdown += delay

func take_damage(amount: int) -> int:
	if is_destroyed():
		return 0
	
	var actual_damage = mini(amount, current_hp)
	current_hp -= actual_damage
	return actual_damage

func is_destroyed() -> bool:
	return current_hp <= 0
