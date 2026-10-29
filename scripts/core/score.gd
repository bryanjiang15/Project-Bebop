class_name ScoreRules
extends RefCounted

## Score and the turn-limit ranking. Weights come from config. A higher score
## ranks first. `ties.order` breaks the remaining ties: more tiles, then more
## cities, then the human loses.


static func total(config: GameConfig, tiles: int, city_count: int, population: int) -> int:
	return tiles * config.score_per_tile + city_count * config.score_per_city + population * config.score_per_population


## True when `a` ranks strictly above `b`. Each entry has player, score, tiles, cities.
static func ranks_above(a: Dictionary, b: Dictionary, tie_order: PackedStringArray, human_index: int) -> bool:
	var a_score := int(a["score"])
	var b_score := int(b["score"])
	if a_score != b_score:
		return a_score > b_score
	for key in tie_order:
		if key == "tiles":
			var a_tiles := int(a["tiles"])
			var b_tiles := int(b["tiles"])
			if a_tiles != b_tiles:
				return a_tiles > b_tiles
		elif key == "cities":
			var a_cities := int(a["cities"])
			var b_cities := int(b["cities"])
			if a_cities != b_cities:
				return a_cities > b_cities
		elif key == "human_loses":
			var a_human := int(a["player"]) == human_index
			var b_human := int(b["player"]) == human_index
			if a_human != b_human:
				return b_human
	return false


## The human wins a score ending only by ranking strictly above every rival.
static func human_is_first(standings: Array, tie_order: PackedStringArray, human_index: int) -> bool:
	var human: Dictionary = {}
	var found := false
	for entry in standings:
		var row: Dictionary = entry
		if int(row["player"]) == human_index:
			human = row
			found = true
			break
	if not found:
		return false
	for entry in standings:
		var row: Dictionary = entry
		if int(row["player"]) == human_index:
			continue
		if not ranks_above(human, row, tie_order, human_index):
			return false
	return true
