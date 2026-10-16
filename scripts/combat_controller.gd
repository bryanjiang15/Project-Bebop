## Main combat scene controller
extends Node
class_name CombatController

var camera
var mech_visual
var enemies_container
var ui

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

var callout_label: Label

func _ready():
	_setup_camera()
	_initialize_combat()
	_setup_ui()

func _setup_camera():
	if not camera:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)
	
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.0
	camera.position = Vector3(-5, 3, 8)
	camera.rotation_degrees = Vector3(-15, 0, 0)

func _initialize_combat():
	config = ConfigManager.new()
	var build = config.get_default_build()
	combat = CombatState.new(config, build, "e1_swarm")
	
	_setup_mech_visual()
	_setup_enemy_visuals()
	
	combat.start_combat()

func _setup_mech_visual():
	if not mech_visual:
		var mech_scene = load("res://scenes/mech/mech.tscn")
		mech_visual = mech_scene.instantiate()
		mech_visual.name = "Mech"
		add_child(mech_visual)
	
	mech_visual.position = Vector3(-2, 0, 0)
	mech_visual.initialize_from_state(combat.mech)

func _setup_enemy_visuals():
	if not enemies_container:
		enemies_container = Node3D.new()
		enemies_container.name = "Enemies"
		add_child(enemies_container)
	
	var x_offset = 3.0
	var y_pos = 1.0
	var spacing = 2.0
	
	for i in combat.enemies.size():
		var enemy_scene = load("res://scenes/enemies/enemy.tscn")
		var enemy_visual: EnemyVisual = enemy_scene.instantiate()
		enemy_visual.position = Vector3(x_offset, y_pos, i * spacing - 2.0)
		enemy_visual.initialize_from_state(combat.enemies[i])
		enemies_container.add_child(enemy_visual)
		enemy_visuals.append(enemy_visual)
		
		var area = Area3D.new()
		area.name = "ClickArea"
		var collision_shape = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(0.8, 1.0, 0.6)
		collision_shape.shape = shape
		area.add_child(collision_shape)
		enemy_visual.add_child(area)
		area.input_event.connect(_on_enemy_clicked.bind(i))

func _setup_ui():
	if not ui:
		ui = CanvasLayer.new()
		ui.name = "UI"
		add_child(ui)
	
	_create_time_budget_display()
	_create_mech_panel()
	_create_enemy_cards()
	_create_action_panel()
	_create_turn_log_display()
	_create_result_screen()
	_create_callout_label()

func _create_time_budget_display():
	var time_panel = PanelContainer.new()
	time_panel.name = "TimePanel"
	time_panel.position = Vector2(10, 10)
	time_panel.size = Vector2(250, 80)
	ui.add_child(time_panel)
	
	var vbox = VBoxContainer.new()
	time_panel.add_child(vbox)
	
	var time_label = Label.new()
	time_label.name = "TimeLabel"
	time_label.text = "Time: 10/10"
	vbox.add_child(time_label)
	
	var bar_container = Control.new()
	bar_container.custom_minimum_size = Vector2(230, 30)
	vbox.add_child(bar_container)
	
	var time_bar = ProgressBar.new()
	time_bar.name = "TimeBar"
	time_bar.max_value = 10
	time_bar.value = 10
	time_bar.show_percentage = false
	time_bar.size = Vector2(230, 30)
	bar_container.add_child(time_bar)
	
	var preview_bar = ProgressBar.new()
	preview_bar.name = "PreviewBar"
	preview_bar.max_value = 10
	preview_bar.value = 10
	preview_bar.show_percentage = false
	preview_bar.size = Vector2(230, 30)
	preview_bar.position = Vector2(0, 0)
	preview_bar.modulate = Color(1, 1, 1, 0.4)
	bar_container.add_child(preview_bar)

func _create_mech_panel():
	var mech_panel = PanelContainer.new()
	mech_panel.name = "MechPanel"
	mech_panel.position = Vector2(10, 110)
	mech_panel.size = Vector2(250, 480)
	ui.add_child(mech_panel)
	
	var vbox = VBoxContainer.new()
	mech_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "MECH STATUS"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	
	var movement_label = Label.new()
	movement_label.name = "MovementLabel"
	movement_label.text = "Movement: Standing"
	vbox.add_child(movement_label)
	
	var stun_label = Label.new()
	stun_label.name = "StunLabel"
	stun_label.text = "Stun: 0/60"
	vbox.add_child(stun_label)
	
	var stun_bar = ProgressBar.new()
	stun_bar.name = "StunBar"
	stun_bar.max_value = 60
	stun_bar.value = 0
	stun_bar.show_percentage = false
	vbox.add_child(stun_bar)
	
	vbox.add_child(HSeparator.new())
	
	var parts_title = Label.new()
	parts_title.text = "PARTS"
	parts_title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(parts_title)
	
	var parts_container = VBoxContainer.new()
	parts_container.name = "PartsContainer"
	vbox.add_child(parts_container)

func _create_enemy_cards():
	var cards_container = VBoxContainer.new()
	cards_container.position = Vector2(1000, 10)
	cards_container.size = Vector2(260, 600)
	ui.add_child(cards_container)
	
	for enemy in combat.enemies:
		var card_scene = preload("res://scripts/utils/enemy_card.gd")
		var card = PanelContainer.new()
		card.set_script(card_scene)
		card.custom_minimum_size = Vector2(250, 120)
		card.initialize(enemy, config)
		cards_container.add_child(card)
		enemy_cards.append(card)

func _create_action_panel():
	var action_panel = PanelContainer.new()
	action_panel.name = "ActionPanel"
	action_panel.position = Vector2(10, 600)
	action_panel.size = Vector2(980, 110)
	ui.add_child(action_panel)
	
	var vbox = VBoxContainer.new()
	action_panel.add_child(vbox)
	
	var status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Select a part"
	vbox.add_child(status_label)
	
	var moves_container = HBoxContainer.new()
	moves_container.name = "MovesContainer"
	vbox.add_child(moves_container)
	
	var parts_container = HBoxContainer.new()
	parts_container.name = "PartsContainer"
	vbox.add_child(parts_container)
	
	var buttons_container = HBoxContainer.new()
	vbox.add_child(buttons_container)
	
	var confirm_btn = Button.new()
	confirm_btn.name = "ConfirmButton"
	confirm_btn.text = "Confirm"
	confirm_btn.disabled = true
	confirm_btn.pressed.connect(_on_confirm_pressed)
	buttons_container.add_child(confirm_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.name = "CancelButton"
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_on_cancel_pressed)
	buttons_container.add_child(cancel_btn)
	
	var end_turn_btn = Button.new()
	end_turn_btn.name = "EndTurnButton"
	end_turn_btn.text = "End Turn (E)"
	end_turn_btn.pressed.connect(_on_end_turn_pressed)
	buttons_container.add_child(end_turn_btn)
	
	var restart_btn = Button.new()
	restart_btn.name = "RestartButton"
	restart_btn.text = "Restart (R)"
	restart_btn.pressed.connect(_on_restart_pressed)
	buttons_container.add_child(restart_btn)
	
	_update_part_buttons()
	_update_action_panel()

func _create_turn_log_display():
	var log_panel = PanelContainer.new()
	log_panel.position = Vector2(420, 400)
	log_panel.size = Vector2(560, 300)
	log_panel.visible = true
	ui.add_child(log_panel)
	
	var vbox = VBoxContainer.new()
	log_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Turn Log"
	vbox.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 260)
	vbox.add_child(scroll)
	
	var log_text = RichTextLabel.new()
	log_text.name = "LogText"
	log_text.bbcode_enabled = true
	log_text.fit_content = true
	scroll.add_child(log_text)

func _create_result_screen():
	var result_screen = PanelContainer.new()
	result_screen.name = "ResultScreen"
	result_screen.visible = false
	result_screen.position = Vector2(340, 200)
	result_screen.size = Vector2(600, 320)
	ui.add_child(result_screen)
	
	var vbox = VBoxContainer.new()
	result_screen.add_child(vbox)
	
	var title = Label.new()
	title.name = "ResultTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)
	
	var summary = RichTextLabel.new()
	summary.name = "ResultSummary"
	summary.custom_minimum_size = Vector2(580, 200)
	summary.bbcode_enabled = true
	vbox.add_child(summary)
	
	var retry_btn = Button.new()
	retry_btn.text = "Retry"
	retry_btn.pressed.connect(_on_restart_pressed)
	vbox.add_child(retry_btn)

func _create_callout_label():
	callout_label = Label.new()
	callout_label.name = "CalloutLabel"
	callout_label.position = Vector2(540, 350)
	callout_label.size = Vector2(200, 50)
	callout_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	callout_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	callout_label.add_theme_font_size_override("font_size", 24)
	callout_label.visible = false
	ui.add_child(callout_label)

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
	var parts_container = ui.get_node_or_null("ActionPanel/VBoxContainer/PartsContainer")
	if not parts_container:
		return
	
	for child in parts_container.get_children():
		child.queue_free()
	
	available_parts.clear()
	
	for part_name in ["torso", "left_arm", "right_arm", "legs", "head"]:
		if not combat.mech.parts.has(part_name):
			continue
		
		var part: MechPart = combat.mech.parts[part_name]
		if part.is_destroyed():
			continue
		
		available_parts.append(part_name)
		
		var btn = Button.new()
		btn.text = part_name.capitalize()
		btn.pressed.connect(_on_part_selected.bind(part_name))
		parts_container.add_child(btn)

func _update_move_buttons():
	var moves_container = ui.get_node_or_null("ActionPanel/VBoxContainer/MovesContainer")
	if not moves_container:
		return
	
	for child in moves_container.get_children():
		child.queue_free()
	
	if not selected_part:
		return
	
	available_moves = selected_part.get_available_moves(config)
	
	for move in available_moves:
		var btn = Button.new()
		var cost = move.get("cost", 0)
		var move_type = move.get("type", "")
		
		if move_type == "movement" and combat.mech.has_free_state_change():
			cost = 0
		
		btn.text = "%s (Cost: %d)" % [move.get("name", ""), cost]
		btn.disabled = not combat.mech.can_afford_move(move)
		btn.pressed.connect(_on_move_selected.bind(move))
		moves_container.add_child(btn)

func _update_action_panel():
	var status_label = ui.get_node_or_null("ActionPanel/VBoxContainer/StatusLabel")
	var confirm_btn = ui.get_node_or_null("ActionPanel/VBoxContainer/HBoxContainer/ConfirmButton")
	
	if not status_label or not confirm_btn:
		return
	
	match ui_state:
		UIState.SELECT_PART:
			status_label.text = "Select a part"
			confirm_btn.disabled = true
		UIState.SELECT_MOVE:
			status_label.text = "Selected: %s - Choose a move" % selected_part_name.capitalize()
			confirm_btn.disabled = true
		UIState.SELECT_TARGET:
			status_label.text = "Selected: %s > %s - Choose target" % [selected_part_name.capitalize(), selected_move.get("name", "")]
			confirm_btn.disabled = selected_target == null
		UIState.EXECUTE:
			var target_text = ""
			if selected_target:
				target_text = " > %s" % selected_target.enemy_id
			status_label.text = "Ready: %s > %s%s" % [selected_part_name.capitalize(), selected_move.get("name", ""), target_text]
			confirm_btn.disabled = false

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
	if callout_label:
		callout_label.text = text
		callout_label.add_theme_color_override("font_color", color)
		callout_label.visible = true
		
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
	var time_label = ui.get_node_or_null("TimePanel/VBoxContainer/TimeLabel")
	var time_bar = ui.get_node_or_null("TimePanel/VBoxContainer/Control/TimeBar")
	var preview_bar = ui.get_node_or_null("TimePanel/VBoxContainer/Control/PreviewBar")
	
	if time_label:
		time_label.text = "Time: %d/%d" % [combat.mech.get_remaining_time(), combat.mech.time_budget]
	if time_bar:
		time_bar.max_value = combat.mech.time_budget
		time_bar.value = combat.mech.get_remaining_time()
	
	if preview_bar and not selected_move.is_empty():
		var preview = combat.preview_move(selected_move)
		var remaining_after = combat.mech.get_remaining_time() - preview.cost
		preview_bar.max_value = combat.mech.time_budget
		preview_bar.value = remaining_after
	elif preview_bar:
		preview_bar.value = combat.mech.get_remaining_time()

func _update_mech_panel():
	var movement_label = ui.get_node_or_null("MechPanel/VBoxContainer/MovementLabel")
	var stun_label = ui.get_node_or_null("MechPanel/VBoxContainer/StunLabel")
	var stun_bar = ui.get_node_or_null("MechPanel/VBoxContainer/StunBar")
	var parts_container = ui.get_node_or_null("MechPanel/VBoxContainer/PartsContainer")
	
	if movement_label:
		var state_name = "Standing"
		match combat.mech.movement_state:
			MechState.MovementState.CROUCHING:
				state_name = "Crouching"
			MechState.MovementState.AIRBORNE:
				state_name = "Airborne"
		movement_label.text = "Movement: " + state_name
	
	var threshold = config.get_stun_threshold("mech")
	if stun_label:
		stun_label.text = "Stun: %d/%d" % [int(combat.mech.stun_meter), threshold]
		if combat.mech.is_stunned:
			stun_label.add_theme_color_override("font_color", Color.RED)
		elif combat.mech.stun_immunity_turns > 0:
			stun_label.add_theme_color_override("font_color", Color.CYAN)
		else:
			stun_label.remove_theme_color_override("font_color")
	
	if stun_bar:
		stun_bar.max_value = threshold
		stun_bar.value = combat.mech.stun_meter
	
	if parts_container:
		for child in parts_container.get_children():
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
			
			parts_container.add_child(part_vbox)

func _update_enemy_cards():
	for card in enemy_cards:
		card.update_display()

func _log_message(message: String):
	var log_text = ui.get_node_or_null("PanelContainer3/VBoxContainer/ScrollContainer/LogText")
	if log_text:
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
	var result_screen = ui.get_node("ResultScreen")
	var title = result_screen.get_node("VBoxContainer/ResultTitle")
	var summary = result_screen.get_node("VBoxContainer/ResultSummary")
	
	var victory = not combat.mech.is_defeated()
	
	if victory:
		title.text = "VICTORY!"
		title.add_theme_color_override("font_color", Color.GREEN)
	else:
		title.text = "DEFEAT"
		title.add_theme_color_override("font_color", Color.RED)
	
	var summary_text = "[center]Turns: %d[/center]\n\n" % combat.current_turn
	summary_text += "[b]Mech Status:[/b]\n"
	for part_name in combat.mech.parts:
		var part: MechPart = combat.mech.parts[part_name]
		summary_text += "  %s: %d/%d HP\n" % [part_name, part.current_hp, part.max_hp]
	
	summary.text = summary_text
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
