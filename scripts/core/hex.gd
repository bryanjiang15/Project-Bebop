class_name Hex
extends RefCounted

## Axial hex math for a pointy-top grid.
## +q is east, +r is southeast. The TileMapLayer uses odd-r offset coordinates
## (column, row), which axial_to_offset / offset_to_axial convert.
## Pixel conversion matches Godot's TILE_SHAPE_HEXAGON + TILE_LAYOUT_STACKED
## + TILE_OFFSET_AXIS_HORIZONTAL layout for whatever tile_size the caller
## passes. The art TileSet is already isometric; nothing here squashes it.
## Tile size and texture origin live on that TileSet, not in this file.

const EAST := 0
const NORTHEAST := 1
const NORTHWEST := 2
const WEST := 3
const SOUTHWEST := 4
const SOUTHEAST := 5

const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]

const DIRECTION_NAMES: PackedStringArray = [
	"east", "northeast", "northwest", "west", "southwest", "southeast",
]


static func neighbor(axial: Vector2i, direction: int) -> Vector2i:
	return axial + DIRECTIONS[posmod(direction, 6)]


static func neighbors(axial: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for direction in DIRECTIONS:
		out.append(axial + direction)
	return out


static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	var ds := (-a.x - a.y) - (-b.x - b.y)
	return (absi(dq) + absi(dr) + absi(ds)) / 2


static func ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if radius < 0:
		return out
	if radius == 0:
		out.append(center)
		return out
	var current := center + DIRECTIONS[SOUTHWEST] * radius
	for side in 6:
		for _step in radius:
			out.append(current)
			current = neighbor(current, side)
	return out


static func disk(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if radius < 0:
		return out
	for q in range(-radius, radius + 1):
		var r1 := maxi(-radius, -q - radius)
		var r2 := mini(radius, -q + radius)
		for r in range(r1, r2 + 1):
			out.append(center + Vector2i(q, r))
	return out


## length tiles starting at origin, walking one hex direction.
## Tiles outside the odd-r rectangle are dropped; the walk still continues.
static func line(origin: Vector2i, direction: int, length: int, columns: int, rows: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if length <= 0:
		return out
	var current := origin
	for _i in length:
		if in_map(current, columns, rows):
			out.append(current)
		current = neighbor(current, direction)
	return out


static func in_map(axial: Vector2i, columns: int, rows: int) -> bool:
	var cell := axial_to_offset(axial)
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows


static func axial_to_offset(axial: Vector2i) -> Vector2i:
	var parity := axial.y & 1
	return Vector2i(axial.x + (axial.y - parity) / 2, axial.y)


static func offset_to_axial(cell: Vector2i) -> Vector2i:
	var parity := cell.y & 1
	return Vector2i(cell.x - (cell.y - parity) / 2, cell.y)


static func offset_to_pixel(cell: Vector2i, tile_size: Vector2) -> Vector2:
	var shifted_x := float(cell.x) + (0.5 if posmod(cell.y, 2) == 0 else 1.0)
	var y := float(cell.y) * 0.75 + 0.5
	return Vector2(shifted_x * tile_size.x, y * tile_size.y)


static func pixel_to_offset(pixel: Vector2, tile_size: Vector2) -> Vector2i:
	var overlapping_ratio := 0.75
	var ret := Vector2(pixel.x / tile_size.x, pixel.y / tile_size.y)
	ret.y /= overlapping_ratio
	var raw_pos := ret
	if posmod(int(floor(ret.y)), 2) != 0:
		ret = Vector2(floor(ret.x + 0.5) - 0.5, floor(ret.y))
	else:
		ret = ret.floor()
	var in_tile_pos := raw_pos - ret
	var slope := 1.0 / overlapping_ratio - 1.0
	var from_top := in_tile_pos - Vector2(0.5, 0.0)
	var in_top_left := from_top.cross(Vector2(-0.5, slope)) <= 0.0
	var in_top_right := from_top.cross(Vector2(0.5, slope)) > 0.0
	ret = ret.floor()
	var cell := Vector2i(int(ret.x), int(ret.y))
	if in_top_left:
		if posmod(cell.y, 2) != 0:
			cell += Vector2i(0, -1)
		else:
			cell += Vector2i(-1, -1)
	elif in_top_right:
		if posmod(cell.y, 2) != 0:
			cell += Vector2i(1, -1)
		else:
			cell += Vector2i(0, -1)
	return cell


static func hex_to_pixel(axial: Vector2i, tile_size: Vector2) -> Vector2:
	return offset_to_pixel(axial_to_offset(axial), tile_size)


static func pixel_to_hex(pixel: Vector2, tile_size: Vector2) -> Vector2i:
	return offset_to_axial(pixel_to_offset(pixel, tile_size))
