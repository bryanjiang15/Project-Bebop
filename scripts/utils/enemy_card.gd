## UI component for displaying enemy status. Layout lives in scenes/ui/enemy_card.tscn.
extends PanelContainer
class_name EnemyCard

@onready var enemy_name_label: Label = %NameLabel
@onready var hp_label: Label = %HPLabel
@onready var countdown_label: Label = %CountdownLabel
@onready var move_label: Label = %MoveLabel
@onready var stun_bar: ProgressBar = %StunBar

var enemy_state: EnemyState
var config: ConfigManager

func initialize(state: EnemyState, p_config: ConfigManager):
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
