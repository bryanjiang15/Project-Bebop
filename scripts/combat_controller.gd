## Main combat scene controller. Static layout lives in scenes/combat/combat_scene.tscn.
extends Node
class_name CombatController

const PART_BUTTON_SCENE := preload("res://scenes/ui/part_button.tscn")
const MOVE_BUTTON_SCENE := preload("res://scenes/ui/move_button.tscn")
const ENEMY_CARD_SCENE := preload("res://scenes/ui/enemy_card.tscn")
const ENEMY_SCENE := preload("res://scenes/enemies/enemy.tscn")

@onready var mech_visual: MechVisual = %Mech
@onready var enemy_anchor: Node3D = %EnemyAnchor
@onready var time_label: Label = %TimeLabel
@onready var time_bar: ProgressBar = %TimeBar
@onready var preview_bar: ProgressBar = %PreviewBar
@onready var movement_label: Label = %MovementLabel
@onready var stun_label: Label = %StunLabel
@onready var stun_bar: ProgressBar = %StunBar
@onready var mech_parts_list: VBoxContainer = %MechPartsList
@onready var enemy_card_row: VBoxContainer = %EnemyCardRow
@onready var status_label: Label = %StatusLabel
@onready var move_list: HBoxContainer = %MoveList
@onready var part_list: HBoxContainer = %PartList
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton
@onready var end_turn_button: Button = %EndTurnButton
@onready var restart_button: Button = %RestartButton
@onready var log_text: RichTextLabel = %LogText
@onready var result_screen: PanelContainer = %ResultScreen
@onready var result_title: Label = %ResultTitle
@onready var result_summary: RichTextLabel = %ResultSummary
@onready var retry_button: Button = %RetryButton
@onready var callout_label: Label = %CalloutLabel

var config: ConfigManager
var combat: CombatState
var enemy_visuals: Array[EnemyVisual] = []
var enemy_cards: Array[EnemyCard] = []

var selected_part: MechPart = null
var selected_part_name: String = ""
var selected_move: Dictionary = {}
var selected_target: EnemyState = null
var move_preview: Dictionary = {}

enum UIState { SELECT_PART, SELECT_MOVE, SELECT_TARGET, EXECUTE }
var ui_state: UIState = UIState.SELECT_PART

var available_parts: Array[String] = []
var available_moves: Array[Dictionary] = []

func _ready():
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	retry_button.pressed.connect(_on_restart_pressed)
	_initialize_combat()

func _initialize_combat():
	config = ConfigManager.new()
	var build = config.get_default_build()
	combat = CombatState.new(config, build, "e1_swarm")
	
	mech_visual.initialize_from_state(combat.mech)
	_setup_enemy_visuals()
	combat.start_combat()
	_create_enemy_cards()
	
	_update_part_buttons()
	_update_action_panel()
	_update_all_displays()

func _setup_enemy_visuals():
	var spacing := 2.0
	for i in combat.enemies.size():
		var enemy_visual: EnemyVisual = ENEMY_SCENE.instantiate()
		enemy_visual.position = Vector3(0, 0, i * spacing - 2.0)
		enemy_anchor.add_child(enemy_visual)
		enemy_visual.initialize_from_state(combat.enemies[i])
		enemy_visual.click_area.input_event.connect(_on_enemy_clicked.bind(i))
		enemy_visuals.append(enemy_visual)

func _create_enemy_cards():
	for enemy in combat.enemies:
		var card: EnemyCard = ENEMY_CARD_SCENE.instantiate()
		enemy_card_row.add_child(card)
		card.initialize(enemy, config)
		enemy_cards.append(card)

func _input(event):
	if event.is_action_pressed("restart"):
		_on_restart_pressed()
	elif event.is_action_pressed("end_turn"):
		_on_end_turn_pressed()
	elif event.is_action_pressed("cancel"):
		_on_cancel_pressed()
	elif event.is_action_pressed("confirm"):
		if ui_state == UIState.EXECUTE:
			_on_confirm_pressed()

func _update_part_buttons():
	for child in part_list.get_children():
		child.queue_free()
	
	available_parts.clear()
	
	for part_name in ["torso", "left_arm", "right_arm", "legs", "head"]:
		if not combat.mech.parts.has(part_name):
			continue
		
		var part: MechPart = combat.mech.parts[part_name]
		if part.is_destroyed():
			continue
		
		available_parts.append(part_name)
		
		var btn: Button = PART_BUTTON_SCENE.instantiate()
		btn.text = part_name.capitalize()
		btn.pressed.connect(_on_part_selected.bind(part_name))
		part_list.add_child(btn)

func _update_move_buttons():
	for child in move_list.get_children():
		child.queue_free()
	
	if not selected_part:
		return
	
	available_moves = selected_part.get_available_moves(config)
	
	for move in available_moves:
		var btn: Button = MOVE_BUTTON_SCENE.instantiate()
		var cost = move.get("cost", 0)
		var move_type = move.get("type", "")
		
		if move_type == "movement" and combat.mech.has_free_state_change():
			cost = 0
		
		btn.text = "%s (Cost: %d)" % [move.get("name", ""), cost]
		btn.disabled = not combat.mech.can_afford_move(move)
		btn.pressed.connect(_on_move_selected.bind(move))
		move_list.add_child(btn)

func _update_action_panel():
	match ui_state:
		UIState.SELECT_PART:
			status_label.text = "Select a part"
			confirm_button.disabled = true
		UIState.SELECT_MOVE:
			status_label.text = "Selected: %s - Choose a move" % selected_part_name.capitalize()
			confirm_button.disabled = true
		UIState.SELECT_TARGET:
			status_label.text = "Selected: %s > %s - Choose target" % [selected_part_name.capitalize(), selected_move.get("name", "")]
			confirm_button.disabled = selected_target == null
		UIState.EXECUTE:
			var target_text = ""
			if selected_target:
				target_text = " > %s" % selected_target.enemy_id
			status_label.text = "Ready: %s > %s%s" % [selected_part_name.capitalize(), selected_move.get("name", ""), target_text]
			confirm_button.disabled = false

func _on_part_selected(part_name: String):
	selected_part_name = part_name
	selected_part = combat.mech.parts[part_name]
	selected_move = {}
	selected_target = null
	
	ui_state = UIState.SELECT_MOVE
	_update_move_buttons()
	_update_action_panel()
	
	for pname in combat.mech.parts:
		mech_visual.highlight_part(pname, pname == part_name)

func _on_move_selected(move: Dictionary):
	selected_move = move
	move_preview = combat.preview_move(move)
	
	var move_type = move.get("type", "")
	if move_type == "attack":
		ui_state = UIState.SELECT_TARGET
		_update_enemy_target_preview()
	else:
		selected_target = null
		ui_state = UIState.EXECUTE
	
	_update_action_panel()
	_update_time_display()

func _update_enemy_target_preview():
	if move_preview.is_empty():
		return
	
	for i in enemy_cards.size():
		var enemy = combat.enemies[i]
		var card = enemy_cards[i]
		
		if enemy.is_destroyed():
			continue
		
		var would_interrupt = false
		for countdown_data in move_preview.enemy_countdowns:
			if countdown_data.enemy == enemy:
				would_interrupt = countdown_data.would_interrupt
				break
		
		card.set_would_interrupt(would_interrupt)
		enemy_visuals[i].set_targeted(false)

func _on_enemy_clicked(_camera, event, _position, _normal, _shape_idx, enemy_index):
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	
	if ui_state != UIState.SELECT_TARGET:
		return
	
	var enemy = combat.enemies[enemy_index]
	if enemy.is_destroyed():
		return
	
	_select_target(enemy_index)

func _select_target(enemy_index: int):
	var enemy = combat.enemies[enemy_index]
	selected_target = enemy
	
	for i in enemy_visuals.size():
		enemy_visuals[i].set_targeted(i == enemy_index)
	
	ui_state = UIState.EXECUTE
	_update_action_panel()

func _on_cancel_pressed():
	match ui_state:
		UIState.SELECT_MOVE:
			selected_part = null
			selected_part_name = ""
			ui_state = UIState.SELECT_PART
			for part_name in combat.mech.parts:
				mech_visual.highlight_part(part_name, false)
		UIState.SELECT_TARGET, UIState.EXECUTE:
			selected_move = {}
			selected_target = null
			ui_state = UIState.SELECT_MOVE
			for i in enemy_visuals.size():
				enemy_visuals[i].set_targeted(false)
	
	_update_move_buttons()
	_update_action_panel()

func _on_confirm_pressed():
	if ui_state != UIState.EXECUTE:
		return
	
	if not combat.is_combat_active:
		return
	
	var move_type = selected_move.get("type", "")
	var move_name = selected_move.get("name", "")
	
	_log_message("[color=green]%s[/color] uses [b]%s[/b]" % [selected_part_name.capitalize(), move_name])
	
	var result = combat.execute_player_move(selected_move, selected_target)
	
	if result.success:
		if move_type == "attack" and selected_target:
			_show_callout("HIT!", Color.ORANGE)
			_log_message("  -> Hit %s for damage" % selected_target.enemy_id)
		elif move_type == "block":
			_show_callout("BLOCK UP!", Color.CYAN)
		elif move_type == "movement":
			_show_callout(move_name.to_upper() + "!", Color.YELLOW)
		
		mech_visual.update_movement_state()
		
		for interrupt in result.get("interrupts", []):
			_process_enemy_action(interrupt)
		
		_update_all_displays()
		
		if result.get("combat_ended", false):
			_show_result_screen()
			return
		
		selected_part = null
		selected_part_name = ""
		selected_move = {}
		selected_target = null
		move_preview = {}
		ui_state = UIState.SELECT_PART
		
		for part_name in combat.mech.parts:
			mech_visual.highlight_part(part_name, false)
		for i in enemy_visuals.size():
			enemy_visuals[i].set_targeted(false)
		for card in enemy_cards:
			card.set_would_interrupt(false)
		
		_update_part_buttons()
		_update_action_panel()

func _show_callout(text: String, color: Color):
	callout_label.text = text
	callout_label.add_theme_color_override("font_color", color)
	callout_label.visible = true
	callout_label.modulate.a = 1.0
	
	var tween = create_tween()
	tween.tween_property(callout_label, "modulate:a", 1.0, 0.1)
	tween.tween_interval(1.0)
	tween.tween_property(callout_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): callout_label.visible = false)

func _on_end_turn_pressed():
	if not combat.is_combat_active:
		return
	
	_log_message("=== END TURN ===")
	var result = combat.end_turn()
	
	for action in result.end_of_turn_actions:
		_process_enemy_action(action)
	
	_update_all_displays()
	
	if result.combat_ended:
		_show_result_screen()

func _on_restart_pressed():
	config.reload_config()
	get_tree().reload_current_scene()

func _update_all_displays():
	_update_time_display()
	_update_enemy_cards()
	_update_mech_panel()
	mech_visual.update_part_health()
	mech_visual.update_movement_state()
	
	for i in enemy_visuals.size():
		enemy_visuals[i].update_health()

func _update_time_display():
	time_label.text = "Time: %d/%d" % [combat.mech.get_remaining_time(), combat.mech.time_budget]
	time_bar.max_value = combat.mech.time_budget
	time_bar.value = combat.mech.get_remaining_time()
	
	if not selected_move.is_empty():
		var preview = combat.preview_move(selected_move)
		var remaining_after = combat.mech.get_remaining_time() - preview.cost
		preview_bar.max_value = combat.mech.time_budget
		preview_bar.value = remaining_after
	else:
		preview_bar.max_value = combat.mech.time_budget
		preview_bar.value = combat.mech.get_remaining_time()

func _update_mech_panel():
	var state_name = "Standing"
	match combat.mech.movement_state:
		MechState.MovementState.CROUCHING:
			state_name = "Crouching"
		MechState.MovementState.AIRBORNE:
			state_name = "Airborne"
	movement_label.text = "Movement: " + state_name
	
	var threshold = config.get_stun_threshold("mech")
	stun_label.text = "Stun: %d/%d" % [int(combat.mech.stun_meter), threshold]
	if combat.mech.is_stunned:
		stun_label.add_theme_color_override("font_color", Color.RED)
	elif combat.mech.stun_immunity_turns > 0:
		stun_label.add_theme_color_override("font_color", Color.CYAN)
	else:
		stun_label.remove_theme_color_override("font_color")
	
	stun_bar.max_value = threshold
	stun_bar.value = combat.mech.stun_meter
	
	for child in mech_parts_list.get_children():
		child.queue_free()
	
	for part_name in ["torso", "left_arm", "right_arm", "legs", "head"]:
		if not combat.mech.parts.has(part_name):
			continue
		
		var part: MechPart = combat.mech.parts[part_name]
		var part_vbox = VBoxContainer.new()
		
		var part_label = Label.new()
		part_label.text = part_name.capitalize()
		if part.is_destroyed():
			part_label.add_theme_color_override("font_color", Color.DIM_GRAY)
		part_vbox.add_child(part_label)
		
		var hp_label = Label.new()
		hp_label.text = "  HP: %d/%d" % [part.current_hp, part.max_hp]
		if part.is_destroyed():
			hp_label.add_theme_color_override("font_color", Color.DIM_GRAY)
		part_vbox.add_child(hp_label)
		
		if part.is_blocking:
			var block_label = Label.new()
			var heights = ", ".join(part.block_heights)
			block_label.text = "  Blocking: " + heights
			block_label.add_theme_color_override("font_color", Color.CYAN)
			part_vbox.add_child(block_label)
		
		mech_parts_list.add_child(part_vbox)

func _update_enemy_cards():
	for card in enemy_cards:
		card.update_display()

func _log_message(message: String):
	log_text.append_text(message + "\n")

func _process_enemy_action(action: Dictionary):
	var enemy: EnemyState = action.enemy
	var move: Dictionary = action.move
	
	var message = "[color=red]%s[/color] uses %s" % [enemy.enemy_id, move.get("name", "")]
	
	if action.whiffed:
		message += " - [color=yellow]WHIFF![/color]"
		_show_callout("WHIFF!", Color.YELLOW)
	elif action.blocked:
		message += " - [color=cyan]BLOCKED[/color] (%d dmg)" % action.damage
		_show_callout("BLOCKED!", Color.CYAN)
	else:
		message += " - [color=red]HIT![/color] (%d dmg)" % action.damage
		_show_callout("HIT!", Color.RED)
	
	if combat.mech.is_stunned:
		_show_callout("STUNNED!", Color.PURPLE)
	
	_log_message(message)

func _show_result_screen():
	var victory = not combat.mech.is_defeated()
	
	if victory:
		result_title.text = "VICTORY!"
		result_title.add_theme_color_override("font_color", Color.GREEN)
	else:
		result_title.text = "DEFEAT"
		result_title.add_theme_color_override("font_color", Color.RED)
	
	var summary_text = "[center]Turns: %d[/center]\n\n" % combat.current_turn
	summary_text += "[b]Mech Status:[/b]\n"
	for part_name in combat.mech.parts:
		var part: MechPart = combat.mech.parts[part_name]
		summary_text += "  %s: %d/%d HP\n" % [part_name, part.current_hp, part.max_hp]
	
	result_summary.text = summary_text
	result_screen.visible = true
	
	_export_turn_log()

func _export_turn_log():
	var log_json = combat.export_turn_log()
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var log_path = "user://combat_log_%s.json" % timestamp
	
	var file = FileAccess.open(log_path, FileAccess.WRITE)
	if file:
		file.store_string(log_json)
		file.close()
		print("Turn log exported to: ", log_path)
		print("Absolute path: ", ProjectSettings.globalize_path(log_path))
