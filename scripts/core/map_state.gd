class_name MapState
extends RefCounted

## Odd-r rectangle of land ids. Cells are offset coordinates, matching TileMapLayer.

var width: int
var height: int
var lands := PackedStringArray()


static func create(columns: int, rows: int) -> MapState:
	var map := MapState.new()
	map.width = columns
	map.height = rows
	map.lands.resize(columns * rows)
	map.lands.fill("plains")
	return map


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func land_at(cell: Vector2i) -> String:
	return lands[_index(cell)]


func set_land(cell: Vector2i, land_id: String) -> void:
	lands[_index(cell)] = land_id


func is_passable(cell: Vector2i, cfg: GameConfig) -> bool:
	if not in_bounds(cell):
		return false
	return cfg.land(land_at(cell)).passable


## Passable tiles inside the disk, including the center. Zero when the center itself is impassable.
func passable_count(cell: Vector2i, radius: int, cfg: GameConfig) -> int:
	if not is_passable(cell, cfg):
		return 0
	var count := 0
	for hex in Hex.disk(Hex.offset_to_axial(cell), radius):
		if is_passable(Hex.axial_to_offset(hex), cfg):
			count += 1
	return count


func _index(cell: Vector2i) -> int:
	return cell.y * width + cell.x
