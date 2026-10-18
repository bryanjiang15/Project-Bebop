class_name TestMap
extends RefCounted

## Hardcoded stripe map for the art view. This is not map generation.
## Columns: 6 plains, 6 forest, 5 hills, 6 water, 5 volcanic (28).

const LANDS: PackedStringArray = ["plains", "forest", "hills", "water", "volcanic"]
const STRIPE_ENDS: PackedInt32Array = [6, 12, 17, 23, 28]


static func land_at(column: int) -> String:
	for i in STRIPE_ENDS.size():
		if column < STRIPE_ENDS[i]:
			return LANDS[i]
	return LANDS[LANDS.size() - 1]


static func index_of(land_id: String) -> int:
	return LANDS.find(land_id)
