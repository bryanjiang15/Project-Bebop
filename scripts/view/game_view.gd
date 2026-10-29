extends Node2D

const _TERRAIN_SOURCE := 0
const _HIGHLIGHT_SOURCE := 1
const _CLICK_SLOP := 8.0
const _REACHABLE := Color(0.45, 0.95, 0.55, 0.95)
const _SELECTED := Color(1, 1, 1, 0.95)
const _WORKED := Color(0.95, 0.82, 0.35, 0.92)
const _PLACE := Color(0.4, 0.85, 0.95, 0.95)
const _ATTACK := Color(0.95, 0.32, 0.28, 0.95)
const _SKIPPED := Color(0.78, 0.78, 0.82, 0.75)
const _INVALID := Color(0.95, 0.28, 0.24, 0.95)
const _SINK := Color(1.0, 0.78, 0.16, 0.98)
const _LAND_TINT := {
	"plains": Color(0.93, 0.9, 0.55, 0.95),
	"forest": Color(0.28, 0.62, 0.32, 0.95),
	"hills": Color(0.78, 0.64, 0.4, 0.95),
	"water": Color(0.38, 0.62, 0.86, 0.95),
	"volcanic": Color(0.92, 0.42, 0.28, 0.95),
}
const _HP_FULL := 48.0
const _HP_LEFT := -24.0
const _HP_TOP := -52.0
const _HP_BOTTOM := -44.0
const _LAND_COLUMN := {
	"plains": 0,
	"forest": 1,
	"hills": 2,
	"water": 3,
	"volcanic": 4,
}
## Pointy-top edges in Hex direction order. Corner 0 is the top vertex.
const _EDGE: Array = [
	[1, 2],
	[0, 1],
	[5, 0],
	[4, 5],
	[3, 4],
	[2, 3],
]

const _UNIT_SCENE: PackedScene = preload("res://scenes/actors/unit.tscn")
const _CITY_SCENE: PackedScene = preload("res://scenes/view/city_marker.tscn")
const _HIGHLIGHT_SCENE: PackedScene = preload("res://scenes/view/move_highlight.tscn")
const _BORDER_SCENE: PackedScene = preload("res://scenes/view/border_segment.tscn")
const _QUEUE_SCENE: PackedScene = preload("res://scenes/ui/queue_row.tscn")
const _SPELL_SCENE: PackedScene = preload("res://scenes/ui/spell_button.tscn")
const _BUILDING_SCENE: PackedScene = preload("res://scenes/view/building_marker.tscn")
const _UNIT_ART := {
	"settler": ["res://assets/art/unit_settler.png", "res://assets/art/unit_settler_mask.png"],
	"scout": ["res://assets/art/unit_scout.png", "res://assets/art/unit_scout_mask.png"],
	"warrior": ["res://assets/art/unit_warrior.png", "res://assets/art/unit_warrior_mask.png"],
	"archer": ["res://assets/art/unit_archer.png", "res://assets/art/unit_archer_mask.png"],
}

var _config: GameConfig
var setup: GameSetup
var _tile_size: Vector2i = Vector2i.ZERO
var _highlight_origin: Vector2 = Vector2.ZERO
var _hovered: Vector2i = Vector2i(-999999, -999999)
var _dragging: bool = false
var _left_down: bool = false
var _right_down: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _right_press: Vector2 = Vector2.ZERO
var _selected_id: int = -1
var _selected_city_id: int = -1
## The city panel stays on the last human city while a unit is selected, so a
## cast can refresh its yields in the same frame as the move highlights.
var _panel_city_id: int = -1
var _placing: String = ""
var _end_confirm: bool = false
var _spell_id: String = ""
var _spell_direction: int = Hex.EAST
var _hover_local: Vector2 = Vector2.ZERO
var _spell_buttons: Dictionary = {}
var _leaving: bool = false

@onready var _camera: Camera2D = %Camera
@onready var _map: TileMapLayer = %Map
@onready var _highlight: TileMapLayer = %Highlight
@onready var _fog: FogOverlay = %Fog
@onready var _moves: Node2D = %MoveHighlights
@onready var _borders: Node2D = %Borders
@onready var _actors: Node2D = %Actors
@onready var _turn_label: Label = %TurnLabel
@onready var _mana_label: Label = %ManaLabel
@onready var _score_0: Label = %Score0
@onready var _score_1: Label = %Score1
@onready var _score_2: Label = %Score2
@onready var _spell_row: HBoxContainer = %SpellButtons
@onready var _tooltip: Label = %Tooltip
@onready var _tooltip_panel: PanelContainer = %TooltipPanel
@onready var _menu: PanelContainer = %InGameMenu
@onready var _selection_title: Label = %SelectionTitle
@onready var _selection_detail: Label = %SelectionDetail
@onready var _volcanic_label: Label = %VolcanicWarning
@onready var _found_button: Button = %FoundCityButton
@onready var _found_reason: Label = %FoundCityReason
@onready var _combat_preview: Label = %CombatPreview
@onready var _skip_button: Button = %SkipButton
@onready var _fortify_button: Button = %FortifyButton
@onready var _end_button: Button = %EndTurnButton
@onready var _end_warning: Label = %EndTurnWarning
@onready var _city_panel: PanelContainer = %CityPanel
@onready var _city_name: Label = %CityName
@onready var _city_hp: Label = %CityHp
@onready var _city_food: Label = %CityFood
@onready var _city_production: Label = %CityProduction
@onready var _city_mana: Label = %CityMana
@onready var _growth_bar: ProgressBar = %GrowthBar
@onready var _growth_label: Label = %GrowthLabel
@onready var _border_label: Label = %BorderLabel
@onready var _queue_list: VBoxContainer = %QueueList
@onready var _city_reason: Label = %CityReason
@onready var _cancel_place: Button = %CancelPlaceButton
@onready var _build_settler: Button = %BuildSettler
@onready var _build_scout: Button = %BuildScout
@onready var _build_warrior: Button = %BuildWarrior
@onready var _build_archer: Button = %BuildArcher
@onready var _build_granary: Button = %BuildGranary
@onready var _build_mana_well: Button = %BuildManaWell
@onready var _build_lumber_mill: Button = %BuildLumberMill


func _ready() -> void:
	_config = GameConfig.load_file()
	if _config == null:
		return
	if _map.tile_set == null:
		push_error("Map is missing its TileSet")
		return
	_tile_size = _map.tile_set.tile_size
	_highlight_origin = _read_texture_origin()
	setup = GameSetup.start(_config)
	if setup == null:
		return
	_frame_on_human()
	_tooltip_panel.visible = false
	_menu.visible = false
	_build_spell_bar()
	_refresh_board()


func _unhandled_input(event: InputEvent) -> void:
	if _config == null or setup == null or _leaving or setup.result != null:
		return
	if event.is_action_pressed("toggle_menu"):
		if not _spell_id.is_empty():
			_cancel_targeting()
			return
		_menu.visible = not _menu.visible
		return
	if event.is_action_pressed("found_city"):
		_on_found_city_pressed()
		return
	if event.is_action_pressed("skip_unit") and not event.is_echo():
		_on_skip_pressed()
		return
	if event.is_action_pressed("fortify_unit") and not event.is_echo():
		_on_fortify_pressed()
		return
	if event.is_action_pressed("end_turn"):
		if not event.is_echo() and not _menu.visible:
			_on_end_turn_pressed()
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_zoom(1)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_zoom(-1)
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_left_down = true
				_press_pos = button.position
				_dragging = false
			else:
				var clicked := _left_down and not _dragging and _press_pos.distance_to(button.position) <= _CLICK_SLOP
				_left_down = false
				_dragging = false
				if clicked:
					if _spell_id.is_empty():
						_select_at_screen(button.position)
					else:
						_cast_at_screen(button.position)
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			if button.pressed:
				_right_down = true
				_right_press = button.position
			else:
				var clicked := _right_down and _right_press.distance_to(button.position) <= _CLICK_SLOP
				_right_down = false
				if clicked:
					if _spell_id.is_empty():
						_move_at_screen(button.position)
					else:
						_cancel_targeting()
		elif button.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = button.pressed
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _left_down and _press_pos.distance_to(motion.position) > _CLICK_SLOP:
			_dragging = true
		if _dragging:
			_camera.position -= motion.relative / _camera.zoom
			_clamp_camera()
		_hover_screen(motion.position)


func _process(delta: float) -> void:
	if _config == null or setup == null:
		return
	var dir := Vector2.ZERO
	if Input.is_action_pressed("pan_left"):
		dir.x -= 1.0
	if Input.is_action_pressed("pan_right"):
		dir.x += 1.0
	if Input.is_action_pressed("pan_up"):
		dir.y -= 1.0
	if Input.is_action_pressed("pan_down"):
		dir.y += 1.0
	if dir != Vector2.ZERO:
		_camera.position += dir.normalized() * _config.camera_key_pan_speed * delta
		_clamp_camera()


func _on_end_turn_pressed() -> void:
	if setup == null or _leaving or setup.result != null:
		return
	if _config.end_turn_warns_if_unordered and setup.has_unordered_moves(setup.human_index) and not _end_confirm:
		_end_confirm = true
		_refresh_end_warning()
		return
	_end_confirm = false
	_spell_id = ""
	setup.end_turn()
	_refresh_board()


func _on_skip_pressed() -> void:
	if setup == null or _menu.visible or _leaving or setup.result != null:
		return
	var unit := _selected_unit()
	if unit == null or not setup.skip_unit(unit):
		return
	_cancel_end_confirm()
	_refresh_selection()


func _on_fortify_pressed() -> void:
	if setup == null or _menu.visible or _leaving or setup.result != null:
		return
	var unit := _selected_unit()
	if unit == null or not setup.fortify_unit(unit):
		return
	_cancel_end_confirm()
	_refresh_selection()


func _on_found_city_pressed() -> void:
	if setup == null or _menu.visible or _leaving or setup.result != null:
		return
	var unit := _selected_unit()
	if unit == null or not setup.can_found(unit).is_empty():
		_refresh_selection()
		return
	setup.found_city(unit)
	_selected_id = -1
	_selected_city_id = -1
	_panel_city_id = -1
	_placing = ""
	_spell_id = ""
	_cancel_end_confirm()
	_refresh_board()


func _on_menu_pressed() -> void:
	_menu.visible = not _menu.visible
	if _menu.visible:
		_cancel_targeting()


func _on_restart_pressed() -> void:
	if GameConfig.load_file() == null:
		return
	get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _select_at_screen(screen: Vector2) -> void:
	if _menu.visible:
		return
	var cell := _cell_at_screen(screen)
	var axial := Hex.offset_to_axial(cell)
	if not Hex.in_map(axial, _config.map_width, _config.map_height):
		if not _placing.is_empty():
			_cancel_end_confirm()
			_refresh_city_panel(GameSetup.REASON_BUILD_OFF_MAP)
			return
		_selected_id = -1
		_selected_city_id = -1
		_panel_city_id = -1
		_placing = ""
		_cancel_end_confirm()
		_refresh_selection()
		_refresh_city_panel()
		return
	if not _placing.is_empty():
		_cancel_end_confirm()
		_try_place(cell)
		return
	var units := _own_units_at(cell)
	var city := setup.city_at_cell(cell)
	var own_city := city != null and city.player == setup.human_index
	_choose_on_tile(units, city if own_city else null)
	if _selected_city() != null:
		_panel_city_id = _selected_city_id
	elif units.is_empty():
		_panel_city_id = -1
	_placing = ""
	_cancel_end_confirm()
	_refresh_selection()
	_refresh_city_panel()


func _move_at_screen(screen: Vector2) -> void:
	if _menu.visible:
		return
	var unit := _selected_unit()
	if unit == null:
		return
	var cell := _cell_at_screen(screen)
	if not Hex.in_map(Hex.offset_to_axial(cell), _config.map_width, _config.map_height):
		return
	if setup.fog.unit_visible(unit.owner, cell) and _engage(unit, cell):
		return
	if not setup.reachable_tiles(unit).has(cell):
		return
	setup.move_unit(unit, cell)
	_cancel_end_confirm()
	_refresh_board()


## Capture-move first, then a military unit, then the city, then a lone settler.
## Returns true when the click was an attack or a capture, so it does not also move.
func _engage(unit: PlayerState.UnitState, cell: Vector2i) -> bool:
	if setup.capture_destination(unit, cell) and setup.reachable_tiles(unit).has(cell):
		setup.move_unit(unit, cell)
		_cancel_end_confirm()
		_refresh_board()
		return true
	var enemy := setup.enemy_at(unit, cell)
	if enemy != null and _config.unit(enemy.unit_type).combatant and setup.can_attack(unit, enemy).is_empty():
		return _resolve_strike(setup.attack_unit(unit, enemy))
	var city := setup.city_at_cell(cell)
	if city != null and city.player != unit.owner and setup.can_attack_city(unit, city).is_empty():
		return _resolve_strike(setup.attack_city(unit, city))
	if enemy != null and setup.can_attack(unit, enemy).is_empty():
		return _resolve_strike(setup.attack_unit(unit, enemy))
	if enemy != null or (city != null and city.player != unit.owner):
		_cancel_end_confirm()
		_refresh_selection()
		return true
	return false


func _resolve_strike(reason: String) -> bool:
	_cancel_end_confirm()
	if reason.is_empty():
		_refresh_board()
	else:
		_refresh_selection()
	return true


func _refresh_board() -> void:
	if setup != null and setup.result != null:
		_show_result()
		return
	_drop_lost_city_selection()
	_paint_map()
	_fog.show_fog(setup, _config, _map)
	_refresh_actors()
	_refresh_borders()
	_refresh_turn()
	_refresh_selection()
	_refresh_city_panel()


func _drop_lost_city_selection() -> void:
	if setup == null:
		return
	if _selected_city_id >= 0:
		var selected := setup.city_by_id(_selected_city_id)
		if selected == null or selected.player != setup.human_index:
			_selected_city_id = -1
	if _panel_city_id >= 0:
		var shown := setup.city_by_id(_panel_city_id)
		if shown == null or shown.player != setup.human_index:
			_panel_city_id = -1


func _refresh_turn() -> void:
	_turn_label.text = "%d / %d" % [setup.turn, _config.turn_limit]
	var human := setup.players[setup.human_index]
	_mana_label.text = "Mana: %d (+%d/turn)" % [human.mana, setup.mana_per_turn(human.index)]
	_refresh_scores()
	_refresh_spells()


func _refresh_scores() -> void:
	var labels: Array[Label] = [_score_0, _score_1, _score_2]
	for index in labels.size():
		var label := labels[index]
		var shown := index < setup.players.size()
		label.visible = shown
		if not shown:
			continue
		label.text = setup.score_line(index)
		label.add_theme_color_override("font_color", Color.html(setup.players[index].color))


func _show_result() -> void:
	if _leaving or setup == null or setup.result == null:
		return
	_leaving = true
	var path := "res://scenes/victory.tscn" if setup.result.human_won else "res://scenes/defeat.tscn"
	get_tree().change_scene_to_file(path)


func _refresh_selection() -> void:
	var unit := _selected_unit()
	if unit == null:
		_selection_title.text = "No unit selected"
		_selection_detail.text = ""
		_set_volcanic_warning("")
		_found_button.disabled = true
		_found_reason.text = GameSetup.REASON_SETTLER
		_skip_button.disabled = true
		_fortify_button.disabled = true
	else:
		var stats := _config.unit(unit.unit_type)
		_selection_title.text = unit.unit_type.capitalize()
		_selection_detail.text = _unit_summary(unit, stats)
		_set_volcanic_warning(_volcanic_warning(unit))
		var reason := setup.can_found(unit)
		_found_button.disabled = not reason.is_empty()
		_found_reason.text = reason
		_skip_button.disabled = not _config.skip_enabled
		_fortify_button.disabled = not _config.fortify_enabled
	_apply_combat_preview()
	_refresh_end_warning()
	_rebuild_move_highlights()
	if Hex.in_map(Hex.offset_to_axial(_hovered), _config.map_width, _config.map_height):
		var axial := Hex.offset_to_axial(_hovered)
		_tooltip.text = _tip_for(_hovered, axial)


func _selected_unit() -> PlayerState.UnitState:
	var human := setup.players[_config.human_index]
	for unit in human.units:
		if unit.id == _selected_id:
			return unit
	return null


func _own_units_at(cell: Vector2i) -> Array[PlayerState.UnitState]:
	var civilians: Array[PlayerState.UnitState] = []
	var fighters: Array[PlayerState.UnitState] = []
	for unit in setup.players[_config.human_index].units:
		if unit.cell != cell:
			continue
		if _config.unit(unit.unit_type).combatant:
			fighters.append(unit)
		else:
			civilians.append(unit)
	civilians.append_array(fighters)
	return civilians


## Civilian first, then other units on the tile, then the human city.
func _choose_on_tile(units: Array[PlayerState.UnitState], city: MapCity) -> void:
	var index := -1
	if _selected_city_id < 0:
		for i in units.size():
			if units[i].id == _selected_id:
				index = i
				break
	if index >= 0 and index + 1 < units.size():
		_selected_id = units[index + 1].id
		_selected_city_id = -1
		return
	if index >= 0 and city != null:
		_selected_id = -1
		_selected_city_id = city.id
		return
	if index >= 0:
		_selected_id = units[(index + 1) % units.size()].id
		_selected_city_id = -1
		return
	if not units.is_empty():
		_selected_id = units[0].id
		_selected_city_id = -1
		return
	_selected_id = -1
	_selected_city_id = city.id if city != null else -1


func _unit_summary(unit: PlayerState.UnitState, stats: GameConfig.UnitStats) -> String:
	var hp_line := "HP —"
	if unit.max_hp > 0:
		hp_line = "HP %d / %d" % [unit.hp, unit.max_hp]
	var strength := "Non-combat"
	if stats.combatant:
		if stats.attack == stats.defense:
			strength = "Strength %d" % stats.attack
		else:
			strength = "Ranged %d    Defense %d" % [stats.attack, stats.defense]
	return "%s\n%s\nMoves %d / %d\nOrder %s" % [hp_line, strength, unit.mp, stats.move, _order_label(unit)]


func _volcanic_warning(unit: PlayerState.UnitState) -> String:
	if setup == null or setup.map == null or setup.config == null:
		return ""
	if setup.map.land_at(unit.cell) != "volcanic":
		return ""
	if not setup.config.volcanic_flat or setup.config.volcanic_timing != "end_of_owner_turn":
		return ""
	if setup.config.volcanic_damage <= 0:
		return ""
	return "Volcanic: -%d HP at end of turn" % setup.config.volcanic_damage


func _set_volcanic_warning(text: String) -> void:
	_volcanic_label.text = text
	_volcanic_label.visible = not text.is_empty()


func _order_label(unit: PlayerState.UnitState) -> String:
	if unit.order == GameSetup.ORDER_SKIP and unit.fortified:
		return "Skip, fortified"
	if unit.order == GameSetup.ORDER_FORTIFY or unit.fortified:
		return "Fortify"
	if unit.order == GameSetup.ORDER_SKIP:
		return "Skip"
	return "None"


func _refresh_end_warning() -> void:
	if _end_confirm:
		_end_button.text = "End anyway (Enter)"
		_end_warning.text = "Units still have moves. End Turn again to continue."
	else:
		_end_button.text = "End Turn (Enter)"
		_end_warning.text = ""


func _cancel_end_confirm() -> void:
	if not _end_confirm:
		return
	_end_confirm = false
	_refresh_end_warning()


func _paint_map() -> void:
	_map.clear()
	_highlight.clear()
	var viewer := _config.human_index
	for row in setup.map.height:
		for col in setup.map.width:
			var cell := Vector2i(col, row)
			# Unrevealed cells are erased. A land atlas here would show through the
			# tile's side even under a dark overlay. Revealed cells keep their land.
			if setup.fog.sight(viewer, cell) == FogState.Sight.UNREVEALED:
				continue
			var land_id := setup.map.land_at(cell)
			var atlas := Vector2i(int(_LAND_COLUMN[land_id]), 0)
			_map.set_cell(cell, _TERRAIN_SOURCE, atlas)


func _refresh_actors() -> void:
	_clear(_actors)
	var viewer := _config.human_index
	for city in setup.cities:
		if city.player != viewer and setup.fog.sight(viewer, city.cell) == FogState.Sight.UNREVEALED:
			continue
		var marker := _CITY_SCENE.instantiate() as Node2D
		marker.name = "City_%d" % city.id
		marker.position = _map.map_to_local(city.cell)
		var sprite := marker.get_node("Sprite") as Sprite2D
		var mat := (sprite.material as ShaderMaterial).duplicate() as ShaderMaterial
		mat.set_shader_parameter("team_color", Color.html(setup.players[city.player].color))
		sprite.material = mat
		(marker.get_node("Name") as Label).text = city.city_name
		var hp_label := marker.get_node("Hp") as Label
		hp_label.text = "%d / %d" % [city.hp, city.max_hp]
		var hp_color := Color(0.96, 0.95, 0.9, 1)
		if city.hp <= 0:
			hp_color = Color(0.95, 0.35, 0.28, 1)
		hp_label.add_theme_color_override("font_color", hp_color)
		_actors.add_child(marker)
		for building in city.buildings:
			var placed := building as MapCity.Building
			if setup.fog.sight(viewer, placed.cell) == FogState.Sight.UNREVEALED:
				continue
			var mark := _BUILDING_SCENE.instantiate() as Node2D
			mark.name = "Building_%d_%d_%d" % [city.id, placed.cell.x, placed.cell.y]
			mark.position = _map.map_to_local(placed.cell)
			var poly := mark.get_node("Mark") as Polygon2D
			var tint := Color.html(setup.players[city.player].color)
			tint.a = 0.95
			poly.color = tint
			(mark.get_node("Name") as Label).text = placed.kind.capitalize()
			_actors.add_child(mark)
	var stacked := {}
	for player in setup.players:
		for unit in player.units:
			if not setup.fog.unit_visible(viewer, unit.cell):
				continue
			if not stacked.has(unit.cell):
				stacked[unit.cell] = []
			(stacked[unit.cell] as Array).append({"player": player, "unit": unit})
	for cell in stacked.keys():
		var group: Array = stacked[cell]
		for i in group.size():
			var entry: Dictionary = group[i]
			var unit := entry["unit"] as PlayerState.UnitState
			var player := entry["player"] as PlayerState
			var art: Array = _UNIT_ART[unit.unit_type]
			var sprite := _UNIT_SCENE.instantiate() as Sprite2D
			sprite.name = "Unit_%d" % unit.id
			sprite.texture = load(str(art[0]))
			var mat := (sprite.material as ShaderMaterial).duplicate() as ShaderMaterial
			mat.set_shader_parameter("team_mask", load(str(art[1])))
			mat.set_shader_parameter("team_color", Color.html(player.color))
			sprite.material = mat
			var shift := Vector2.ZERO
			if group.size() > 1:
				var along := float(i) / float(group.size() - 1)
				shift = Vector2(lerpf(-36.0, 36.0, along), 0.0)
			sprite.position = _map.map_to_local(cell) + shift
			_paint_hp(sprite, unit)
			_actors.add_child(sprite)


func _rebuild_move_highlights() -> void:
	_clear(_moves)
	if not _spell_id.is_empty():
		_rebuild_spell_highlights()
		return
	var unit := _selected_unit()
	if unit != null:
		_add_highlight(unit.cell, _SELECTED)
		for cell in setup.reachable_tiles(unit).keys():
			_add_highlight(cell as Vector2i, _REACHABLE)
		for cell in setup.attackable_cells(unit):
			_add_highlight(cell, _ATTACK)
		return
	var city := _selected_city()
	if city == null:
		return
	if not _placing.is_empty():
		for cell in setup.placement_tiles(city, _placing):
			_add_highlight(cell, _PLACE)
		return
	_add_highlight(city.cell, _SELECTED)
	var yields: Dictionary = setup.city_yields(city)
	for cell in yields["worked"]:
		_add_highlight(cell as Vector2i, _WORKED)


func _add_highlight(cell: Vector2i, tint: Color, scale: float = 1.0) -> void:
	var marker := _HIGHLIGHT_SCENE.instantiate() as Sprite2D
	marker.position = _map.map_to_local(cell)
	marker.offset = _highlight_origin
	marker.modulate = tint
	marker.scale = Vector2(scale, scale)
	if scale < 1.0:
		marker.z_index = 1
	_moves.add_child(marker)


func _refresh_borders() -> void:
	_clear(_borders)
	var corners := _face_corners()
	var viewer := _config.human_index
	for cell in setup.owned_cells():
		if setup.fog.sight(viewer, cell) == FogState.Sight.UNREVEALED:
			continue
		var owner := setup.owner_at(cell)
		var color := Color.html(setup.players[owner].color)
		var center := _map.map_to_local(cell)
		var axial := Hex.offset_to_axial(cell)
		for dir in 6:
			var neighbor := Hex.axial_to_offset(Hex.neighbor(axial, dir))
			var neighbor_owner := -1
			if setup.map.in_bounds(neighbor):
				neighbor_owner = setup.owner_at(neighbor)
			if neighbor_owner == owner:
				continue
			var segment := _BORDER_SCENE.instantiate() as Line2D
			var pair: Array = _EDGE[dir]
			segment.points = PackedVector2Array([
				center + corners[int(pair[0])],
				center + corners[int(pair[1])],
			])
			segment.default_color = color
			_borders.add_child(segment)


func _face_corners() -> PackedVector2Array:
	var w := float(_tile_size.x) * 0.5
	var h := float(_tile_size.y) * 0.5
	return PackedVector2Array([
		Vector2(0, -h),
		Vector2(w, -h * 0.5),
		Vector2(w, h * 0.5),
		Vector2(0, h),
		Vector2(-w, h * 0.5),
		Vector2(-w, -h * 0.5),
	])


func _read_texture_origin() -> Vector2:
	var source := _map.tile_set.get_source(_TERRAIN_SOURCE) as TileSetAtlasSource
	var data := source.get_tile_data(Vector2i.ZERO, 0)
	return Vector2(data.texture_origin)


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.free()


func _frame_on_human() -> void:
	_camera.zoom = Vector2.ONE * _config.camera_default_zoom
	_camera.position = _map.map_to_local(setup.human_settler_cell())
	_clamp_camera()


func _map_rect() -> Rect2:
	var size := Vector2(_tile_size)
	var rect := Rect2(Hex.offset_to_pixel(Vector2i.ZERO, size), Vector2.ZERO)
	var corners: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(_config.map_width - 1, 0),
		Vector2i(0, _config.map_height - 1),
		Vector2i(_config.map_width - 1, _config.map_height - 1),
		Vector2i(_config.map_width - 1, 1),
	]
	for cell in corners:
		var center := Hex.offset_to_pixel(cell, size)
		rect = rect.expand(center - size * 0.5)
		rect = rect.expand(center + size * 0.5)
	return rect


func _clamp_camera() -> void:
	var rect := _map_rect().grow(_config.camera_pan_margin)
	var pos := _camera.position
	pos.x = clampf(pos.x, rect.position.x, rect.end.x)
	pos.y = clampf(pos.y, rect.position.y, rect.end.y)
	_camera.position = pos


func _zoom(direction: int) -> void:
	var z := _camera.zoom.x + _config.camera_zoom_step * float(direction)
	z = clampf(z, _config.camera_min_zoom, _config.camera_max_zoom)
	_camera.zoom = Vector2(z, z)
	_clamp_camera()


func _hover_screen(screen: Vector2) -> void:
	var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen
	hover_at_local(_map.to_local(world), screen)


func hover_at_local(local: Vector2, screen: Vector2 = Vector2.INF) -> void:
	var cell := _map.local_to_map(local)
	var axial := Hex.offset_to_axial(cell)
	if not Hex.in_map(axial, _config.map_width, _config.map_height):
		_clear_hover()
		return
	_hover_local = local
	var direction := _spell_direction
	if not _spell_id.is_empty():
		direction = _sector(cell, local)
	var moved := cell != _hovered or direction != _spell_direction
	_hovered = cell
	_spell_direction = direction
	if moved:
		_highlight.clear()
		if _spell_id.is_empty():
			_highlight.set_cell(cell, _HIGHLIGHT_SOURCE, Vector2i.ZERO)
		else:
			_rebuild_spell_highlights()
	_tooltip.text = _tip_for(cell, axial)
	_tooltip_panel.visible = true
	_apply_combat_preview()
	if screen != Vector2.INF:
		_place_tooltip(screen)


func _tip_for(cell: Vector2i, axial: Vector2i) -> String:
	var base := "%d, %d Unexplored" % [axial.x, axial.y]
	if setup.fog.sight(_config.human_index, cell) != FogState.Sight.UNREVEALED:
		base = "%d, %d %s" % [axial.x, axial.y, setup.map.land_at(cell)]
	var spell := _spell_tip()
	if not spell.is_empty():
		return "%s\n%s" % [base, spell]
	var extra := _combat_hover_text()
	if extra.is_empty():
		return base
	return "%s\n%s" % [base, extra]


func _combat_hover_text() -> String:
	var unit := _selected_unit()
	if unit == null or setup == null or setup.map == null or not setup.map.in_bounds(_hovered):
		return ""
	if not setup.fog.unit_visible(unit.owner, _hovered):
		return ""
	if setup.capture_destination(unit, _hovered) and setup.reachable_tiles(unit).has(_hovered):
		return "Capture"
	var enemy := setup.enemy_at(unit, _hovered)
	if enemy != null and _config.unit(enemy.unit_type).combatant:
		return _preview_line(setup.preview_attack(unit, enemy))
	var city := setup.city_at_cell(_hovered)
	if city != null and city.player != unit.owner:
		return _preview_line(setup.preview_city(unit, city))
	if enemy != null:
		return _preview_line(setup.preview_attack(unit, enemy))
	return ""


func _preview_line(preview: Dictionary) -> String:
	if bool(preview["ok"]):
		return "Damage %d   Counter %d" % [int(preview["damage"]), int(preview["counter"])]
	return str(preview["reason"])


func _apply_combat_preview() -> void:
	var text := _combat_hover_text()
	_combat_preview.text = text
	var color := Color(0.96, 0.95, 0.9, 1)
	if not text.is_empty() and not text.begins_with("Damage") and text != "Capture":
		color = Color(0.95, 0.62, 0.48, 1)
	_combat_preview.add_theme_color_override("font_color", color)


func _paint_hp(sprite: Sprite2D, unit: PlayerState.UnitState) -> void:
	var bar := sprite.get_node("HpBar") as Node2D
	if unit.max_hp <= 0:
		bar.visible = false
		return
	bar.visible = true
	var ratio := clampf(float(unit.hp) / float(unit.max_hp), 0.0, 1.0)
	var fill := bar.get_node("Fill") as Polygon2D
	var right := _HP_LEFT + _HP_FULL * ratio
	fill.polygon = PackedVector2Array([
		Vector2(_HP_LEFT, _HP_TOP),
		Vector2(right, _HP_TOP),
		Vector2(right, _HP_BOTTOM),
		Vector2(_HP_LEFT, _HP_BOTTOM),
	])
	if ratio > 0.55:
		fill.color = Color(0.45, 0.82, 0.38, 1)
	elif ratio > 0.3:
		fill.color = Color(0.92, 0.76, 0.28, 1)
	else:
		fill.color = Color(0.9, 0.32, 0.28, 1)


func _clear_hover() -> void:
	_hovered = Vector2i(-999999, -999999)
	_highlight.clear()
	_tooltip.text = ""
	_tooltip_panel.visible = false
	if _combat_preview != null:
		_combat_preview.text = ""
	if not _spell_id.is_empty():
		_clear(_moves)


func _cell_at_screen(screen: Vector2) -> Vector2i:
	var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen
	return _map.local_to_map(_map.to_local(world))


func _selected_city() -> MapCity:
	if setup == null or _selected_city_id < 0:
		return null
	var city := setup.city_by_id(_selected_city_id)
	if city == null or city.player != setup.human_index:
		return null
	return city


## Yields stay on screen after the player selects a unit. Build actions still
## follow `_selected_city`, because placement highlights yield to move highlights.
func _panel_city() -> MapCity:
	if setup == null or _panel_city_id < 0:
		return null
	var city := setup.city_by_id(_panel_city_id)
	if city == null or city.player != setup.human_index:
		return null
	return city


func _on_build_settler_pressed() -> void:
	_choose_build("settler")


func _on_build_scout_pressed() -> void:
	_choose_build("scout")


func _on_build_warrior_pressed() -> void:
	_choose_build("warrior")


func _on_build_archer_pressed() -> void:
	_choose_build("archer")


func _on_build_granary_pressed() -> void:
	_choose_build("granary")


func _on_build_mana_well_pressed() -> void:
	_choose_build("mana_well")


func _on_build_lumber_mill_pressed() -> void:
	_choose_build("lumber_mill")


func _on_cancel_place_pressed() -> void:
	if _menu.visible:
		return
	_placing = ""
	_refresh_city_panel()
	_rebuild_move_highlights()


func _choose_build(item_id: String) -> void:
	if setup == null or _menu.visible:
		return
	_cancel_targeting()
	var city := _selected_city()
	if city == null:
		return
	if CityRules.is_building(item_id):
		_placing = item_id
		_refresh_city_panel("Click a tile for %s" % item_id.capitalize())
		_rebuild_move_highlights()
		return
	var reason := setup.enqueue(city, item_id)
	_placing = ""
	_refresh_selection()
	_refresh_city_panel(reason)


func _try_place(cell: Vector2i) -> void:
	var city := _selected_city()
	if city == null:
		_placing = ""
		_refresh_city_panel()
		_rebuild_move_highlights()
		return
	var reason := setup.enqueue(city, _placing, cell)
	if reason.is_empty():
		_placing = ""
		_refresh_selection()
		_refresh_city_panel()
		return
	_refresh_city_panel(reason)


func _on_queue_move(index: int, delta: int) -> void:
	if setup == null or _menu.visible:
		return
	setup.move_queue(_panel_city(), index, delta)
	call_deferred("_refresh_after_queue")


func _on_queue_cancel(index: int) -> void:
	if setup == null or _menu.visible:
		return
	setup.cancel_queue(_panel_city(), index)
	call_deferred("_refresh_after_queue")


func _refresh_after_queue() -> void:
	_refresh_city_panel()
	_rebuild_move_highlights()


func _refresh_city_panel(notice: String = "") -> void:
	var city := _panel_city()
	if city == null:
		_city_panel.visible = false
		_cancel_place.visible = false
		_clear_queue_rows()
		return
	_city_panel.visible = true
	var city_selected := _selected_city() != null
	_cancel_place.visible = city_selected and not _placing.is_empty()
	var builds: Array[Button] = [
		_build_settler, _build_scout, _build_warrior, _build_archer,
		_build_granary, _build_mana_well, _build_lumber_mill,
	]
	for button in builds:
		button.disabled = not city_selected
	var snapshot: Dictionary = setup.city_yields(city)
	_city_name.text = city.city_name
	_city_hp.text = "HP %d / %d" % [city.hp, city.max_hp]
	_city_food.text = "Food %d" % int(snapshot["food"])
	_city_production.text = "Production %d" % int(snapshot["production"])
	_city_mana.text = "Mana %d" % int(snapshot["mana"])
	var threshold := int(snapshot["threshold"])
	var surplus := int(snapshot["surplus"])
	_growth_bar.max_value = maxi(threshold, 1)
	_growth_bar.value = city.food_stored
	var sign := "+" if surplus >= 0 else ""
	_growth_label.text = "Growth %d / %d (%s%d)" % [city.food_stored, threshold, sign, surplus]
	var turns := setup.turns_until_border(city)
	if turns < 0:
		_border_label.text = "Radius %d · borders full" % city.radius
	else:
		_border_label.text = "Radius %d · next tile in %d" % [city.radius, turns]
	_build_settler.text = "Settler %d" % _config.unit("settler").cost
	_build_scout.text = "Scout %d" % _config.unit("scout").cost
	_build_warrior.text = "Warrior %d" % _config.unit("warrior").cost
	_build_archer.text = "Archer %d" % _config.unit("archer").cost
	_build_granary.text = "Granary %d" % _config.granary_cost
	_build_mana_well.text = "Mana Well %d" % _config.mana_well_cost
	_build_lumber_mill.text = "Lumber Mill %d" % _config.lumber_mill_cost
	_rebuild_queue(city)
	if not notice.is_empty():
		_city_reason.text = notice
	elif not _placing.is_empty():
		_city_reason.text = "Click a tile for %s" % _placing.capitalize()
	else:
		_city_reason.text = ""


func _rebuild_queue(city: MapCity) -> void:
	_clear_queue_rows()
	for i in city.queue.size():
		var item: MapCity.Item = city.queue[i]
		var row := _QUEUE_SCENE.instantiate() as HBoxContainer
		var cost := CityRules.item_cost(_config, item.item_id)
		var label := row.get_node("ItemLabel") as Label
		if i == 0:
			label.text = "%s  %d / %d" % [item.item_id.capitalize(), city.production_stored, cost]
		else:
			label.text = "%s  %d" % [item.item_id.capitalize(), cost]
		var up := row.get_node("UpButton") as Button
		var down := row.get_node("DownButton") as Button
		up.disabled = i == 0
		down.disabled = i == city.queue.size() - 1
		up.pressed.connect(_on_queue_move.bind(i, -1))
		down.pressed.connect(_on_queue_move.bind(i, 1))
		(row.get_node("CancelButton") as Button).pressed.connect(_on_queue_cancel.bind(i))
		_queue_list.add_child(row)


func _clear_queue_rows() -> void:
	for child in _queue_list.get_children():
		_queue_list.remove_child(child)
		child.queue_free()


func _build_spell_bar() -> void:
	for spell_id in GameConfig.SPELL_IDS:
		var button := _SPELL_SCENE.instantiate() as Button
		button.name = "Spell_%s" % spell_id
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_spell_pressed.bind(spell_id))
		_spell_row.add_child(button)
		_spell_buttons[spell_id] = button


func _refresh_spells() -> void:
	if setup == null:
		return
	for spell_id in _spell_buttons.keys():
		_paint_spell_button(_spell_buttons[spell_id] as Button, str(spell_id))


func _paint_spell_button(button: Button, spell_id: String) -> void:
	var stats := _config.spell(spell_id)
	var reason := setup.spell_block_reason(setup.human_index, spell_id)
	var left := setup.cooldown_left(setup.human_index, spell_id)
	(button.get_node("Column/NameLabel") as Label).text = stats.spell_name
	(button.get_node("Column/CostLabel") as Label).text = "%d mana" % stats.mana
	var shape := "Radius %d" % stats.radius
	if stats.shape == "line":
		shape = "Line %d" % stats.length
	(button.get_node("Column/ShapeLabel") as Label).text = shape
	var state := "Ready"
	if _spell_id == spell_id and reason.is_empty():
		state = "Targeting"
	elif reason == SpellRules.REASON_COOLDOWN:
		state = "Cooldown %d" % left
	elif not reason.is_empty():
		state = reason
	var state_label := button.get_node("Column/StateLabel") as Label
	state_label.text = state
	button.disabled = not reason.is_empty()
	button.tooltip_text = reason
	var muted := button.disabled
	var name_color := Color(0.78, 0.78, 0.8) if muted else Color(0.97, 0.96, 0.92)
	var cost_color := Color(0.62, 0.8, 0.96) if muted else Color(0.72, 0.88, 1.0)
	var shape_color := Color(0.74, 0.74, 0.7) if muted else Color(0.9, 0.9, 0.84)
	(button.get_node("Column/NameLabel") as Label).add_theme_color_override("font_color", name_color)
	(button.get_node("Column/CostLabel") as Label).add_theme_color_override("font_color", cost_color)
	(button.get_node("Column/ShapeLabel") as Label).add_theme_color_override("font_color", shape_color)
	var state_color := Color(0.95, 0.62, 0.48) if muted else Color(0.9, 0.9, 0.84)
	state_label.add_theme_color_override("font_color", state_color)
	if muted:
		button.modulate = Color(0.92, 0.92, 0.94)
	elif _spell_id == spell_id:
		button.modulate = Color(0.88, 0.95, 1.0)
	else:
		button.modulate = Color.WHITE


func _on_spell_pressed(spell_id: String) -> void:
	if setup == null or _menu.visible:
		return
	if not setup.spell_block_reason(setup.human_index, spell_id).is_empty():
		return
	_placing = ""
	if _spell_id == spell_id:
		_spell_id = ""
	else:
		_spell_id = spell_id
		if setup.map.in_bounds(_hovered):
			_spell_direction = _sector(_hovered, _hover_local)
	_refresh_spells()
	_rebuild_move_highlights()
	_refresh_city_panel()
	if setup.map.in_bounds(_hovered):
		_tooltip.text = _tip_for(_hovered, Hex.offset_to_axial(_hovered))
		_tooltip_panel.visible = true


func _cancel_targeting() -> void:
	if _spell_id.is_empty():
		return
	_spell_id = ""
	_refresh_spells()
	_rebuild_move_highlights()
	if setup != null and setup.map.in_bounds(_hovered):
		_highlight.clear()
		_highlight.set_cell(_hovered, _HIGHLIGHT_SOURCE, Vector2i.ZERO)
		_tooltip.text = _tip_for(_hovered, Hex.offset_to_axial(_hovered))


func _cast_at_screen(screen: Vector2) -> void:
	if setup == null or _spell_id.is_empty():
		return
	var cell := _cell_at_screen(screen)
	var world: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * screen
	var local := _map.to_local(world)
	var direction := _sector(cell, local)
	var reason := setup.cast_spell(setup.human_index, _spell_id, cell, direction)
	if reason.is_empty():
		_spell_id = ""
		_cancel_end_confirm()
		# The click is the tile that just changed. Refresh reads it for the
		# tooltip, combat preview, move highlights, and the open city panel.
		if setup.map.in_bounds(cell):
			_hovered = cell
			_hover_local = local
		_refresh_board()
		if setup.map.in_bounds(cell):
			_highlight.clear()
			_highlight.set_cell(cell, _HIGHLIGHT_SOURCE, Vector2i.ZERO)
		return
	_hovered = cell
	_hover_local = local
	_spell_direction = direction
	_highlight.clear()
	_rebuild_spell_highlights()
	if setup.map.in_bounds(cell):
		_tooltip.text = _tip_for(cell, Hex.offset_to_axial(cell))
	else:
		var stats := _config.spell(_spell_id)
		_tooltip.text = "%s · %d mana\n%s" % [stats.spell_name, stats.mana, reason]
	_tooltip_panel.visible = true
	_place_tooltip(screen)


func _place_tooltip(screen: Vector2) -> void:
	var needed := _tooltip.get_minimum_size() + Vector2(24, 16)
	_tooltip_panel.size = needed
	var pos := screen + Vector2(16, 16)
	var view := get_viewport_rect().size
	if pos.x + needed.x > view.x - 8.0:
		pos.x = maxf(8.0, screen.x - needed.x - 16.0)
	if pos.y + needed.y > view.y - 8.0:
		pos.y = maxf(8.0, screen.y - needed.y - 16.0)
	_tooltip_panel.position = pos


func _rebuild_spell_highlights() -> void:
	_clear(_moves)
	if _spell_id.is_empty() or setup == null or not setup.map.in_bounds(_hovered):
		return
	var preview := setup.spell_preview(setup.human_index, _spell_id, _hovered, _spell_direction)
	var land_id := str(preview["land"])
	var tint: Color = _LAND_TINT.get(land_id, _REACHABLE)
	var skipped := {}
	for cell in preview["skipped"]:
		skipped[cell] = true
	var destroyed := {}
	for cell in preview["destroyed"]:
		destroyed[cell] = true
	var reason := str(preview["reason"])
	for cell in preview["tiles"]:
		var here := cell as Vector2i
		var color := tint
		if not reason.is_empty() and here == _hovered:
			color = _INVALID
		elif skipped.has(here):
			color = _SKIPPED
		_add_highlight(here, color)
		if reason.is_empty() and destroyed.has(here):
			_add_highlight(here, _SINK, 0.74)


func _sector(cell: Vector2i, local: Vector2) -> int:
	var center := _map.map_to_local(cell)
	var axes: Array[Vector2] = []
	var axial := Hex.offset_to_axial(cell)
	for dir in 6:
		var neighbor := Hex.axial_to_offset(Hex.neighbor(axial, dir))
		axes.append(_map.map_to_local(neighbor) - center)
	return SpellRules.sector(local - center, axes)


func _spell_tip() -> String:
	if _spell_id.is_empty() or setup == null or not setup.map.in_bounds(_hovered):
		return ""
	var preview := setup.spell_preview(setup.human_index, _spell_id, _hovered, _spell_direction)
	var header := "%s · %d mana" % [str(preview["name"]), int(preview["cost"])]
	var reason := str(preview["reason"])
	if not reason.is_empty():
		return "%s\n%s" % [header, reason]
	var count := (preview["changed"] as Array).size()
	var line := "1 tile changes" if count == 1 else "%d tiles change" % count
	if str(preview["shape"]) == "line":
		line = "%s %s" % [line, Hex.DIRECTION_NAMES[_spell_direction]]
	var lost := (preview["destroyed"] as Array).size()
	if lost == 1:
		line = "%s, 1 building destroyed" % line
	elif lost > 1:
		line = "%s, %d buildings destroyed" % [line, lost]
	var skipped := (preview["skipped"] as Array).size()
	if skipped > 0:
		line = "%s\n%d skipped" % [line, skipped]
	return "%s\n%s" % [header, line]
