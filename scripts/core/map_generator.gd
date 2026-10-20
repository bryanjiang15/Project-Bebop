class_name MapGenerator
extends RefCounted

## Integer value noise, then exact land counts along the sorted noise.
## Low noise becomes water, then plains, forest, hills, and volcanic.
## Counts use the largest remainder so the mix tracks map.land_mix.
## The noise is integer arithmetic so a seed replays on macOS and Linux.

const BANDS: PackedStringArray = ["water", "plains", "forest", "hills", "volcanic"]


static func generate(cfg: GameConfig, seed_value: int) -> MapState:
	var map := MapState.create(cfg.map_width, cfg.map_height)
	var total := cfg.map_width * cfg.map_height
	var cells: Array[Vector2i] = []
	var noise_at := {}
	for row in cfg.map_height:
		for col in cfg.map_width:
			var cell := Vector2i(col, row)
			cells.append(cell)
			noise_at[cell] = _sample(col, row, seed_value)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var na := int(noise_at[a])
		var nb := int(noise_at[b])
		if na != nb:
			return na < nb
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
	var counts := _band_counts(cfg, total)
	var cursor := 0
	for land_id in BANDS:
		var count := int(counts[land_id])
		for _i in count:
			map.set_land(cells[cursor], land_id)
			cursor += 1
	if cursor != total:
		push_error("map generator filled %d of %d tiles" % [cursor, total])
	return map


static func _band_counts(cfg: GameConfig, total: int) -> Dictionary:
	var exact := {}
	var counts := {}
	var used := 0
	for land_id in GameConfig.LAND_IDS:
		var want := float(cfg.land_mix[land_id]) * float(total)
		var base := int(floor(want))
		exact[land_id] = want
		counts[land_id] = base
		used += base
	var order: Array[String] = []
	for land_id in GameConfig.LAND_IDS:
		order.append(land_id)
	order.sort_custom(func(a: String, b: String) -> bool:
		var fa := float(exact[a]) - float(counts[a])
		var fb := float(exact[b]) - float(counts[b])
		if fa != fb:
			return fa > fb
		return GameConfig.LAND_IDS.find(a) < GameConfig.LAND_IDS.find(b)
	)
	var remain := total - used
	var step := 0
	while remain > 0:
		var land_id: String = order[step % order.size()]
		counts[land_id] = int(counts[land_id]) + 1
		remain -= 1
		step += 1
	return counts


static func _sample(x: int, y: int, seed_value: int) -> int:
	return _smooth(x, y, seed_value, 6) * 2 + _smooth(x, y, seed_value + 17, 3)


static func _smooth(x: int, y: int, seed_value: int, scale: int) -> int:
	var x0 := int(x / scale)
	var y0 := int(y / scale)
	var tx := x % scale
	var ty := y % scale
	var v00 := _hash(x0, y0, seed_value)
	var v10 := _hash(x0 + 1, y0, seed_value)
	var v01 := _hash(x0, y0 + 1, seed_value)
	var v11 := _hash(x0 + 1, y0 + 1, seed_value)
	var a := v00 * (scale - tx) + v10 * tx
	var b := v01 * (scale - tx) + v11 * tx
	return a * (scale - ty) + b * ty


static func _hash(x: int, y: int, seed_value: int) -> int:
	var n: int = (x * 374761393) ^ (y * 668265263) ^ (seed_value * 1442695041)
	n = n & 0x7fffffff
	n = (n ^ (n >> 13)) * 1274126177
	n = n & 0x7fffffff
	n = n ^ (n >> 16)
	return n & 0x7fffffff
