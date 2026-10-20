class_name FogState
extends RefCounted

## Per-player sight. The AI will read this same state. The view only draws the human's copy.
## UNREVEALED has never been seen. REVEALED was seen and is not currently in vision.
## VISIBLE is inside a unit disk (or, later, a city disk) right now.

enum Sight { UNREVEALED, REVEALED, VISIBLE }

var width: int
var height: int
var player_count: int
var _sight := PackedInt32Array()


func resize(columns: int, rows: int, players: int) -> void:
	width = columns
	height = rows
	player_count = players
	_sight.resize(columns * rows * players)
	_sight.fill(Sight.UNREVEALED)


func sight(player: int, cell: Vector2i) -> int:
	if not _in_bounds(cell) or player < 0 or player >= player_count:
		return Sight.UNREVEALED
	return _sight[_index(player, cell)]


func unit_visible(viewer: int, cell: Vector2i) -> bool:
	return sight(viewer, cell) == Sight.VISIBLE


## First look: everything starts unrevealed, then source disks become visible.
func compute_initial(sources: Array) -> void:
	_sight.fill(Sight.UNREVEALED)
	_mark_sources(sources)


## Drop current vision to revealed, then mark the new source disks visible.
func recompute(sources: Array) -> void:
	for player in player_count:
		for row in height:
			for col in width:
				var cell := Vector2i(col, row)
				if sight(player, cell) == Sight.VISIBLE:
					_sight[_index(player, cell)] = Sight.REVEALED
	_mark_sources(sources)


func _mark_sources(sources: Array) -> void:
	for source in sources:
		var player := int(source["player"])
		var cell: Vector2i = source["cell"]
		var radius := int(source["radius"])
		var axial := Hex.offset_to_axial(cell)
		for hex in Hex.disk(axial, radius):
			var other := Hex.axial_to_offset(hex)
			if not _in_bounds(other):
				continue
			_sight[_index(player, other)] = Sight.VISIBLE


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func _index(player: int, cell: Vector2i) -> int:
	return (player * height + cell.y) * width + cell.x
