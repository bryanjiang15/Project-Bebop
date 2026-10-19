class_name FogOverlay
extends Node2D

## Draws the human player's fog over the terrain faces.
## Unrevealed tiles use the opaque hidden color. Revealed tiles use the dim color.
## Visible tiles are left uncovered. Units are a later layer, so they sit above this.

const _OUTSET := 1.5

var _setup: GameSetup
var _config: GameConfig
var _map: TileMapLayer


func show_fog(setup: GameSetup, config: GameConfig, map: TileMapLayer) -> void:
	_setup = setup
	_config = config
	_map = map
	queue_redraw()


func _draw() -> void:
	if _setup == null or _config == null or _map == null or _map.tile_set == null:
		return
	var tile := Vector2(_map.tile_set.tile_size)
	var source := _map.tile_set.get_source(0) as TileSetAtlasSource
	var side := 0.0
	if source != null:
		side = float(source.texture_region_size.y - _map.tile_set.tile_size.y)
	var hidden := _config.fog_hidden_color()
	var dim := _config.fog_dim_color()
	var viewer := _config.human_index
	for row in _setup.map.height:
		for col in _setup.map.width:
			var cell := Vector2i(col, row)
			var state := _setup.fog.sight(viewer, cell)
			if state == FogState.Sight.VISIBLE:
				continue
			var color := hidden if state == FogState.Sight.UNREVEALED else dim
			var center := _map.map_to_local(cell)
			draw_colored_polygon(_face_points(center, tile), color)
			if row == _setup.map.height - 1 and side > 0.0:
				draw_colored_polygon(_side_points(center, tile, side), color)


func _face_points(center: Vector2, tile: Vector2) -> PackedVector2Array:
	var hw := tile.x * 0.5
	var hh := tile.y * 0.5
	var qh := tile.y * 0.25
	var raw := PackedVector2Array([
		Vector2(0, -hh),
		Vector2(hw, -qh),
		Vector2(hw, qh),
		Vector2(0, hh),
		Vector2(-hw, qh),
		Vector2(-hw, -qh),
	])
	var points := PackedVector2Array()
	for point in raw:
		var length := point.length()
		var scaled := point
		if length > 0.0:
			scaled = point + point / length * _OUTSET
		points.append(center + scaled)
	return points


func _side_points(center: Vector2, tile: Vector2, side: float) -> PackedVector2Array:
	var hw := tile.x * 0.5
	var hh := tile.y * 0.5
	var qh := tile.y * 0.25
	return PackedVector2Array([
		center + Vector2(hw, qh),
		center + Vector2(0, hh),
		center + Vector2(-hw, qh),
		center + Vector2(-hw, qh + side + 1.0),
		center + Vector2(0, hh + side + 1.0),
		center + Vector2(hw, qh + side + 1.0),
	])
