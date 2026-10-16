## UI component for displaying enemy status
extends PanelContainer
class_name EnemyCard

var enemy_name_label: Label
var hp_label: Label
var countdown_label: Label
var move_label: Label
var stun_bar: ProgressBar

var enemy_state: EnemyState
var config: ConfigManager

func _ready():
	if not enemy_name_label:
		_create_ui()

func _create_ui():
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	add_child(vbox)
	
	enemy_name_label = Label.new()
	enemy_name_label.name = "NameLabel"
	vbox.add_child(enemy_name_label)
	
	hp_label = Label.new()
	hp_label.name = "HPLabel"
	vbox.add_child(hp_label)
	
	countdown_label = Label.new()
	countdown_label.name = "CountdownLabel"
	vbox.add_child(countdown_label)
	
	move_label = Label.new()
	move_label.name = "MoveLabel"
	vbox.add_child(move_label)
	
	stun_bar = ProgressBar.new()
	stun_bar.name = "StunBar"
	stun_bar.show_percentage = false
	vbox.add_child(stun_bar)

func initialize(state: EnemyState, p_config: ConfigManager):
	if not enemy_name_label:
		_create_ui()
	
	enemy_state = state
	config = p_config
	update_display()

func update_display():
	if not enemy_state:
		return
	
	enemy_name_label.text = enemy_state.enemy_id
	hp_label.text = "HP: %d/%d" % [enemy_state.current_hp, enemy_state.max_hp]
	countdown_label.text = "Countdown: %d" % enemy_state.countdown
	
	var move = enemy_state.get_current_move()
	move_label.text = "%s (%s, %d dmg)" % [move.get("name", ""), move.get("height", ""), move.get("damage", 0)]
	
	var unit_type = "drone" if enemy_state.max_hp <= 20 else "miniboss"
	var threshold = config.get_stun_threshold(unit_type)
	stun_bar.max_value = threshold
	stun_bar.value = enemy_state.stun_meter
	
	if enemy_state.countdown <= 0 and not enemy_state.has_acted_this_turn:
		countdown_label.add_theme_color_override("font_color", Color.RED)
	else:
		countdown_label.remove_theme_color_override("font_color")

func set_would_interrupt(will_interrupt: bool):
	if will_interrupt:
		add_theme_stylebox_override("panel", _create_red_panel())
	else:
		remove_theme_stylebox_override("panel")

func _create_red_panel() -> StyleBox:
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.8, 0.2, 0.2, 0.3)
	stylebox.border_color = Color.RED
	stylebox.border_width_left = 2
	stylebox.border_width_right = 2
	stylebox.border_width_top = 2
	stylebox.border_width_bottom = 2
	return stylebox
