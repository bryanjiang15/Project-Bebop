class_name Pathfinder
extends RefCounted

## Tiles a land unit can reach this move, mapped to movement points left on
## arrival. The origin is not included. cost_of returns a negative number
## when the tile cannot be entered (water). blocked is true when this unit
## may not enter the tile. When allow_over is set, a tile that costs more
## than the points left is still entered if any points remain, and that
## entry ends the move.


static func reachable(
	origin: Vector2i,
	mp: int,
	columns: int,
	rows: int,
	cost_of: Callable,
	blocked: Callable,
	allow_over: bool,
) -> Dictionary:
	var best: Dictionary = {origin: mp}
	var queue: Array[Vector2i] = [origin]
	var result: Dictionary = {}
	while not queue.is_empty():
		var pick := 0
		for i in range(1, queue.size()):
			if int(best[queue[i]]) > int(best[queue[pick]]):
				pick = i
		var current: Vector2i = queue[pick]
		queue.remove_at(pick)
		var remaining: int = int(best[current])
		if current != origin:
			result[current] = remaining
		if remaining <= 0:
			continue
		for next in Hex.neighbors(current):
			if not Hex.in_map(next, columns, rows):
				continue
			if bool(blocked.call(next)):
				continue
			var cost: int = int(cost_of.call(next))
			if cost < 0:
				continue
			var next_remaining := -1
			if cost <= remaining:
				next_remaining = remaining - cost
			elif allow_over:
				next_remaining = 0
			else:
				continue
			if best.has(next) and int(best[next]) >= next_remaining:
				continue
			best[next] = next_remaining
			queue.append(next)
	return result
