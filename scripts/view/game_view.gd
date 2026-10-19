extends Node2D

const _TERRAIN_SOURCE := 0
const _HIGHLIGHT_SOURCE := 1
const _LAND_COLUMN := {
	"plains": 0,
	"forest": 1,
	"hills": 2,
	"water": 3,
	"volcanic": 4,
}
const _UNIT_SCENE: PackedScene = preload("res://scenes/actors/unit.tscn")
const _UNIT_ART := {
	"settler": ["res://assets/art/unit_settler.png", "res://assets/art/unit_settler_mask.png"],
	"scout": ["res://assets/art/unit_scout.png", "res://assets/art/unit_scout_mask.png"],
	"warrior": ["res://assets/art/unit_warrior.png", "res://assets/art/unit_warrior_mask.png"],
	"archer": ["res://assets/art/unit_archer.png", "res://assets/art/unit_archer_mask.png"],
}

var _config: GameConfig
var setup: GameSetup
var _turn: int = 1
var _tile_size: Vector2i = Vector2i.ZERO
var _hovered: Vector2i = Vector2i(-999999, -999999)
var _dragging: bool = false

@onready var _camera: Camera2D = %Camera
@onready var _map: TileMapLayer = %Map
@onready var _highlight: TileMapLayer = %Highlight
@onready var _fog: FogOverlay = %Fog
@onready var _actors: Node2D = %Actors
@onready var _turn_label: Label = %TurnLabel
@onready var _tooltip: Label = %Tooltip
@onready var _tooltip_panel: PanelContainer = %TooltipPanel
@onready var _menu: PanelContainer = %InGameMenu


func _ready() -> void:
	_config = GameConfig.load_file()
	if _config == null:
		return
	if _map.tile_set == null:
		push_error("Map is missing its TileSet")
		return
	_tile_size = _map.tile_set.tile_size
	setup = GameSetup.start(_config)
	if setup == null:
		return
	_paint_map()
	_spawn_units()
	_fog.show_fog(setup, _config, _map)
	_refresh_turn()
	_frame_on_human()
	_tooltip_panel.visible = false
	_menu.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _config == null or setup == null:
		return
	if event.is_action_pressed("debug_victory"):
		get_tree().change_scene_to_file("res://scenes/victory.tscn")
		return
	if event.is_action_pressed("debug_defeat"):
		get_tree().change_scene_to_file("res://scenes/defeat.tscn")
		return
	if event.is_action_pressed("toggle_menu"):
		_menu.visible = not _menu.visible
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(1)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(-1)
		elif button.button_index == MOUSE_BUTTON_LEFT or button.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = button.pressed
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
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
	_turn += 1
	_refresh_turn()


func _on_menu_pressed() -> void:
	_menu.visible = not _menu.visible


func _on_restart_pressed() -> void:
	if GameConfig.load_file() == null:
		return
	get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _paint_map() -> void:
	_map.clear()
	_highlight.clear()
	for row in setup.map.height:
		for col in setup.map.width:
			var cell := Vector2i(col, row)
			var land_id := setup.map.land_at(cell)
			var atlas := Vector2i(int(_LAND_COLUMN[land_id]), 0)
			_map.set_cell(cell, _TERRAIN_SOURCE, atlas)


func _spawn_units() -> void:
	for child in _actors.get_children():
		_actors.remove_child(child)
		child.free()
	var viewer := _config.human_index
	for player in setup.players:
		var stack := 0
		for unit in player.units:
			if not setup.fog.unit_visible(viewer, unit.cell):
				continue
			var art: Array = _UNIT_ART[unit.unit_type]
			var sprite := _UNIT_SCENE.instantiate() as Sprite2D
			sprite.texture = load(str(art[0]))
			var mat := (sprite.material as ShaderMaterial).duplicate() as ShaderMaterial
			mat.set_shader_parameter("team_mask", load(str(art[1])))
			mat.set_shader_parameter("team_color", Color.html(player.color))
			sprite.material = mat
			sprite.position = _map.map_to_local(unit.cell) + Vector2(16, 10) * float(stack)
			_actors.add_child(sprite)
			stack += 1


func _refresh_turn() -> void:
	_turn_label.text = "%d / %d" % [_turn, _config.turn_limit]


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
	if cell != _hovered:
		_hovered = cell
		_highlight.clear()
		_highlight.set_cell(cell, _HIGHLIGHT_SOURCE, Vector2i.ZERO)
		_tooltip.text = _tip_for(cell, axial)
		_tooltip_panel.visible = true
	if screen != Vector2.INF:
		_tooltip_panel.position = screen + Vector2(16, 16)


func _tip_for(cell: Vector2i, axial: Vector2i) -> String:
	if setup.fog.sight(_config.human_index, cell) == FogState.Sight.UNREVEALED:
		return "%d, %d Unexplored" % [axial.x, axial.y]
	return "%d, %d %s" % [axial.x, axial.y, setup.map.land_at(cell)]


func _clear_hover() -> void:
	_hovered = Vector2i(-999999, -999999)
	_highlight.clear()
	_tooltip.text = ""
	_tooltip_panel.visible = false
