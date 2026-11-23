extends RefCounted

## Typical-site pace and the same-seed before/after table for ticket 24.
## The site is plains, with the decided ring counts. Order "expand" trains a
## settler first. Order "granary" builds that first. Casts spend mana on tiles
## that actually change. No new numbers live here: costs and the cap come from
## the config passed in.


const CENTER := Vector2i(14, 9)
const NO_CELL := Vector2i(-999999, -999999)


static func apply_old(cfg: GameConfig) -> void:
	cfg.growth_base = 10
	cfg.growth_per_population = 6
	cfg.unit("settler").cost = 40
	cfg.unit("scout").cost = 20
	cfg.unit("warrior").cost = 30
	cfg.unit("archer").cost = 45
	cfg.granary_cost = 50
	cfg.mana_well_cost = 60
	cfg.lumber_mill_cost = 50
	cfg.spell("grow_forest").mana = 15
	cfg.spell("raise_hills").mana = 20
	cfg.spell("carve_river").mana = 25
	cfg.spell("ignite").mana = 35
	cfg.spell("restore_plains").mana = 10
	cfg.max_casts_base = 1
	cfg.max_casts_limit = 1
	cfg.max_casts_cities_per_step = 0


static func play_site(cfg: GameConfig, order: String) -> Dictionary:
	var game := _prepare(cfg)
	var stats := _blank_stats()
	stats["order"] = order
	stats["first_city"] = 1
	_run_site(game, order, cfg.turn_limit + 1, stats)
	_fill_army(game, stats)
	stats["ended"] = "" if game.result == null else str(game.result.ending)
	stats["end_turn"] = game.turn
	return stats


## Lose one city at the start of turn 25, then train a settler from an empty
## queue and walk it to a legal site. In-progress settlers are removed so the
## clock is that fresh train plus the walk.
static func rebuild(cfg: GameConfig) -> Dictionary:
	var game := _prepare(cfg)
	var stats := _blank_stats()
	_run_site(game, "expand", 25, stats)
	var out := {
		"loss_turn": game.turn,
		"found_turn": -1,
		"settler_turn": -1,
		"elapsed": -1,
		"within_7": false,
		"trainer_prod": 0,
		"cities_after_loss": 0,
		"note": "",
	}
	if game.result != null or game.turn != 25:
		out["note"] = "the expand game did not reach turn 25"
		return out
	var lost := _weakest_city(game, game.human_index)
	if lost == null or not _capture_city(game, lost):
		out["note"] = "could not capture a city"
		return out
	_remove_human_settlers(game)
	var trainer := _strongest_city(game, game.human_index)
	if trainer == null:
		out["note"] = "no city left to train from"
		return out
	_empty_queue(game, trainer)
	if not game.enqueue(trainer, "settler").is_empty():
		out["note"] = "the remaining city could not queue a settler"
		return out
	out["trainer_prod"] = int(game.city_yields(trainer)["production"])
	out["cities_after_loss"] = game.city_count(game.human_index)
	var known := _city_ids(game, game.human_index)
	var guard := 0
	while game.result == null and int(out["found_turn"]) < 0 and guard < 20:
		guard += 1
		var turn := game.turn
		_move_settlers(game, game.human_index)
		if _has_new_city(game, game.human_index, known):
			out["found_turn"] = turn
			break
		if game.players[game.human_index].units.is_empty() or _settlers_training(game, game.human_index) == 0:
			if trainer.queue.is_empty():
				game.enqueue(trainer, "settler")
		var before := _unit_ids(game, game.human_index)
		game.end_turn()
		if int(out["settler_turn"]) < 0 and _new_settler(game, game.human_index, before):
			out["settler_turn"] = turn
	if int(out["found_turn"]) < 0:
		out["note"] = "replacement was not founded within 20 turns"
		return out
	out["elapsed"] = int(out["found_turn"]) - int(out["loss_turn"])
	out["within_7"] = int(out["elapsed"]) <= 7
	out["note"] = "fresh settler from production %d" % int(out["trainer_prod"])
	return out


static func play_seed(cfg: GameConfig, seed_value: int) -> Dictionary:
	cfg.log_enabled = false
	var stats := _blank_stats()
	stats["seed"] = seed_value
	var game := GameSetup.start_with_seed(cfg, seed_value)
	if game == null:
		stats["ended"] = "no-start"
		stats["end_turn"] = 0
		return stats
	while game.result == null and game.turn <= cfg.turn_limit:
		var turn := game.turn
		for player in game.players:
			if game.result != null:
				break
			if player.eliminated:
				continue
			RivalAI.play(game, player.index)
		_note_city_count(stats, game, turn)
		if int(stats["first_forest"]) < 0 and game.cooldown_left(game.human_index, "grow_forest") > 0:
			stats["first_forest"] = turn
		var before := _unit_ids(game, game.human_index)
		_add_casts(stats, turn, game.players[game.human_index].casts_this_turn)
		if game.result == null:
			game.end_turn()
		_note_building(stats, game, turn)
		_note_city_count(stats, game, turn)
		if int(stats["first_settler"]) < 0 and _new_settler(game, game.human_index, before):
			stats["first_settler"] = turn
		if turn == 15 or turn == 25 or turn == 50:
			stats["t%d" % turn] = _snap(game)
		if game.result != null:
			stats["ended"] = str(game.result.ending)
			stats["end_turn"] = turn
	if str(stats["ended"]).is_empty():
		stats["ended"] = "open"
		stats["end_turn"] = game.turn
	_fill_army(game, stats)
	return stats


static func _run_site(game: GameSetup, order: String, stop_before: int, stats: Dictionary) -> void:
	var human := game.human_index
	while game.result == null and game.turn < stop_before and game.turn <= game.config.turn_limit:
		var turn := game.turn
		_move_settlers(game, human)
		_note_city_count(stats, game, turn)
		var cast := _cast_player(game, human, turn)
		if int(stats["first_forest"]) < 0 and cast.has("grow_forest"):
			stats["first_forest"] = turn
			stats["first_spell"] = "grow_forest"
		elif str(stats["first_spell"]).is_empty() and not cast.is_empty():
			stats["first_spell"] = cast[0]
		_add_casts(stats, turn, game.players[human].casts_this_turn)
		_queue(game, order, turn)
		if game.result != null:
			break
		game.end_turn()
		_note_building(stats, game, turn)
		_note_city_count(stats, game, turn)
		if int(stats["first_settler"]) < 0 and _count_type(game, human, "settler") > 0:
			stats["first_settler"] = turn
		if turn == 15 or turn == 25 or turn == 50:
			stats["t%d" % turn] = _snap(game)
		if game.result != null:
			stats["ended"] = str(game.result.ending)
			stats["end_turn"] = turn


static func _prepare(cfg: GameConfig) -> GameSetup:
	cfg.log_enabled = false
	var map := MapState.create(cfg.map_width, cfg.map_height)
	for row in map.height:
		for col in map.width:
			map.set_land(Vector2i(col, row), "plains")
	var game := GameSetup.new()
	game.config = cfg
	game.map = map
	game.turn = 1
	game.human_index = cfg.human_index
	game.fog = FogState.new()
	game.fog.resize(map.width, map.height, cfg.player_count)
	for index in cfg.player_count:
		var player := PlayerState.new()
		player.index = index
		player.human = index == cfg.human_index
		player.color = cfg.player_colors[index]
		player.mana = cfg.starting_mana
		game.players.append(player)
	_paint(game)
	var settler := game.spawn_unit(cfg.human_index, "settler", CENTER)
	game.found_city(settler)
	return game


static func _paint(game: GameSetup) -> void:
	var axial := Hex.offset_to_axial(CENTER)
	var dirs: Array[int] = [Hex.EAST, Hex.NORTHEAST, Hex.NORTHWEST, Hex.WEST, Hex.SOUTHWEST, Hex.SOUTHEAST]
	var ring1: PackedStringArray = ["forest", "plains", "plains", "hills", "water", "water"]
	for i in dirs.size():
		game.map.set_land(Hex.axial_to_offset(Hex.neighbor(axial, dirs[i])), ring1[i])
	var ring2 := Hex.ring(axial, 2)
	ring2.sort_custom(_axial_before)
	var lands: PackedStringArray = ["forest", "forest", "volcanic", "plains", "plains", "plains", "plains", "hills", "hills", "water", "water", "water"]
	for i in ring2.size():
		game.map.set_land(Hex.axial_to_offset(ring2[i]), lands[i])


static func _axial_before(a: Vector2i, b: Vector2i) -> bool:
	if a.x == b.x:
		return a.y < b.y
	return a.x < b.x


static func _queue(game: GameSetup, order: String, turn: int) -> void:
	var human := game.human_index
	for city in game.cities:
		if city.player != human or not city.queue.is_empty():
			continue
		var item := _next_item(game, city, order, turn)
		if item.is_empty():
			continue
		if CityRules.is_building(item):
			var cell := _place(game, city, item)
			if cell == NO_CELL:
				continue
			game.enqueue(city, item, cell)
		else:
			game.enqueue(city, item)


static func _next_item(game: GameSetup, city: MapCity, order: String, turn: int) -> String:
	var human := game.human_index
	var pipeline := game.city_count(human) + _settlers_training(game, human)
	if order == "granary" and pipeline == 1 and not _has_building(city, "granary"):
		return "granary"
	if pipeline < _city_goal(turn):
		return "settler"
	if not _has_building(city, "granary"):
		return "granary"
	if turn >= 16 and not _has_building(city, "mana_well"):
		return "mana_well"
	if not _has_building(city, "lumber_mill"):
		return "lumber_mill"
	return "warrior"


static func _city_goal(turn: int) -> int:
	if turn >= 42:
		return 6
	if turn >= 34:
		return 5
	if turn >= 26:
		return 4
	if turn >= 16:
		return 3
	return 2


static func _place(game: GameSetup, city: MapCity, item: String) -> Vector2i:
	var tiles := game.placement_tiles(city, item)
	if tiles.is_empty():
		return NO_CELL
	if item != "lumber_mill":
		return tiles[0]
	var best := tiles[0]
	var best_n := -1
	for cell in tiles:
		var forests := CityRules.adjacent_forests(game.map, cell)
		if forests > best_n:
			best = cell
			best_n = forests
	return best


static func _has_building(city: MapCity, kind: String) -> bool:
	for building in city.buildings:
		if building.kind == kind:
			return true
	for item in city.queue:
		if item.item_id == kind:
			return true
	return false


static func _settlers_training(game: GameSetup, player: int) -> int:
	var count := _count_type(game, player, "settler")
	for city in game.cities:
		if city.player != player:
			continue
		for item in city.queue:
			if item.item_id == "settler":
				count += 1
	return count


static func _cast_player(game: GameSetup, player: int, turn: int) -> PackedStringArray:
	var cast: PackedStringArray = []
	var guard := 0
	var spending := turn >= 26
	while guard < game.max_casts(player):
		guard += 1
		var used := game.players[player].casts_this_turn
		if used >= game.max_casts(player):
			break
		var spells: PackedStringArray = ["grow_forest", "raise_hills", "restore_plains"]
		if spending:
			spells.append("ignite")
			spells.append("carve_river")
		var options: Array[Dictionary] = []
		var guarded := _protected(game, player)
		for spell_id in spells:
			if not game.spell_block_reason(player, spell_id).is_empty():
				continue
			var stats := game.config.spell(spell_id)
			var directions: Array[int] = [Hex.EAST]
			if stats.shape == "line":
				directions = [Hex.EAST, Hex.NORTHEAST, Hex.NORTHWEST, Hex.WEST, Hex.SOUTHWEST, Hex.SOUTHEAST]
			var best_for_spell := {}
			for cell in _targets(game, player, stats.range):
				for direction in directions:
					var score := _cast_score(game, player, spell_id, cell, direction, stats.land, guarded, spending)
					if score <= 0:
						continue
					if best_for_spell.is_empty() or score > int(best_for_spell["score"]):
						best_for_spell = {"spell": spell_id, "cell": cell, "dir": direction, "cost": stats.mana, "score": score}
			if not best_for_spell.is_empty():
				options.append(best_for_spell)
		var picked := _pick_cast(options, game.players[player].mana, spending)
		if picked.is_empty():
			break
		if not game.cast_spell(player, str(picked["spell"]), picked["cell"], int(picked["dir"])).is_empty():
			break
		cast.append(str(picked["spell"]))
		if game.players[player].casts_this_turn == used:
			break
	return cast


## One option per spell. Owned improvements come first. While spending, pick a
## pair that both fit so the turn uses the cap, and among those pairs the one
## that spends the most mana.
static func _pick_cast(options: Array[Dictionary], mana: int, spending: bool) -> Dictionary:
	var owned: Dictionary = {}
	for option in options:
		if int(option["score"]) < 12:
			continue
		if owned.is_empty() or int(option["score"]) > int(owned["score"]):
			owned = option
	if not owned.is_empty():
		return owned
	if not spending:
		var best: Dictionary = {}
		for option in options:
			if best.is_empty() or int(option["score"]) > int(best["score"]):
				best = option
			elif int(option["score"]) == int(best["score"]) and int(option["cost"]) < int(best["cost"]):
				best = option
		return best
	var pair: Dictionary = {}
	var pair_cost := -1
	for first in options:
		for second in options:
			if str(first["spell"]) == str(second["spell"]):
				continue
			var together := int(first["cost"]) + int(second["cost"])
			if together > mana or together <= pair_cost:
				continue
			pair_cost = together
			pair = first if int(first["cost"]) >= int(second["cost"]) else second
	if not pair.is_empty():
		return pair
	var lone: Dictionary = {}
	for option in options:
		if int(option["cost"]) > mana:
			continue
		if lone.is_empty() or int(option["cost"]) > int(lone["cost"]):
			lone = option
	return lone


## Worked tiles, centers, and finished buildings stay forests. A lumber mill
## keeps the forests on its six neighbors. Other tiles may still change, and
## once mana is piled up a real change is worth casting so the surplus is spent.
static func _protected(game: GameSetup, player: int) -> Dictionary:
	var cells := {}
	for city in game.cities:
		if city.player != player:
			continue
		cells[city.cell] = true
		for worked in game.city_yields(city)["worked"]:
			cells[worked] = true
		for building in city.buildings:
			cells[building.cell] = true
			if building.kind != "lumber_mill":
				continue
			for hex in Hex.neighbors(Hex.offset_to_axial(building.cell)):
				var neighbor := Hex.axial_to_offset(hex)
				if game.map.in_bounds(neighbor):
					cells[neighbor] = true
	for unit in game.players[player].units:
		cells[unit.cell] = true
	return cells


static func _improves(land_id: String, new_land: String) -> bool:
	if new_land == "forest" and land_id != "forest":
		return true
	if new_land == "plains" and (land_id == "water" or land_id == "volcanic"):
		return true
	return false


static func _cast_score(game: GameSetup, player: int, spell_id: String, cell: Vector2i, direction: int, new_land: String, guarded: Dictionary, spending: bool) -> int:
	var preview := game.spell_preview(player, spell_id, cell, direction)
	if not str(preview["reason"]).is_empty():
		return -1
	var score := 0
	for changed in preview["changed"]:
		var here := changed as Vector2i
		var land_id := game.map.land_at(here)
		if land_id == new_land:
			continue
		var improvement := _improves(land_id, new_land)
		if guarded.has(here) or game.owner_at(here) == player:
			if not improvement:
				return -1
			score += 20 if guarded.has(here) else 12
		elif _claimable(game, player, here):
			if not improvement:
				if spending and new_land != "water" and new_land != "volcanic":
					score += 1
				else:
					return -1
			else:
				score += 4
		elif improvement:
			score += 4
		elif spending:
			score += 1
	return score


static func _claimable(game: GameSetup, player: int, cell: Vector2i) -> bool:
	for city in game.cities:
		if city.player != player:
			continue
		if _dist(city.cell, cell) <= game.config.border_max_radius:
			return true
	return false


static func _targets(game: GameSetup, player: int, reach: int) -> Array[Vector2i]:
	var seen := {}
	var out: Array[Vector2i] = []
	for city in game.cities:
		if city.player != player:
			continue
		for owned in game.territory_cells(city):
			for hex in Hex.disk(Hex.offset_to_axial(owned), reach):
				var cell := Hex.axial_to_offset(hex)
				if seen.has(cell) or not game.map.in_bounds(cell):
					continue
				seen[cell] = true
				out.append(cell)
	return out


static func _move_settlers(game: GameSetup, player: int) -> void:
	var reserved: Array[Vector2i] = []
	var units: Array = game.players[player].units.duplicate()
	for unit in units:
		var settler := unit as PlayerState.UnitState
		if settler == null or settler.unit_type != "settler" or settler.ap <= 0:
			continue
		var goal := _found_goal(game, settler, reserved)
		if goal == NO_CELL:
			continue
		reserved.append(goal)
		if settler.cell != goal:
			var best := settler.cell
			var best_d := _dist(settler.cell, goal)
			for key in game.reachable_tiles(settler).keys():
				var cell := key as Vector2i
				if game.map.land_at(cell) == "volcanic":
					continue
				var away := _dist(cell, goal)
				if away < best_d:
					best = cell
					best_d = away
			if best != settler.cell:
				game.move_unit(settler, best)
		if game.can_found(settler).is_empty():
			game.found_city(settler)


static func _found_goal(game: GameSetup, unit: PlayerState.UnitState, reserved: Array[Vector2i]) -> Vector2i:
	if _legal_found(game, unit, unit.cell, reserved):
		return unit.cell
	var best := NO_CELL
	var best_d := 999999
	for row in game.map.height:
		for col in game.map.width:
			var cell := Vector2i(col, row)
			if not _legal_found(game, unit, cell, reserved):
				continue
			var away := _dist(unit.cell, cell)
			if away < best_d or (away == best_d and (best == NO_CELL or _offset_before(cell, best))):
				best = cell
				best_d = away
	return best


static func _legal_found(game: GameSetup, unit: PlayerState.UnitState, cell: Vector2i, reserved: Array[Vector2i]) -> bool:
	if not game.map.is_passable(cell, game.config):
		return false
	var land := game.map.land_at(cell)
	if land == "water" or land == "volcanic":
		return false
	var owner := game.owner_at(cell)
	if owner != -1 and owner != unit.owner:
		return false
	if _occupied(game, cell, unit):
		return false
	var axial := Hex.offset_to_axial(cell)
	for city in game.cities:
		if Hex.distance(axial, Hex.offset_to_axial(city.cell)) < game.config.city_min_distance:
			return false
	for other in reserved:
		if Hex.distance(axial, Hex.offset_to_axial(other)) < game.config.city_min_distance:
			return false
	return true


static func _occupied(game: GameSetup, cell: Vector2i, ignore: PlayerState.UnitState) -> bool:
	for player in game.players:
		for unit in player.units:
			if unit != ignore and unit.cell == cell:
				return true
	return false


static func _capture_city(game: GameSetup, city: MapCity) -> bool:
	city.hp = 0
	var rival := 1 if game.human_index == 0 else 0
	var spawn_at := _empty_passable(game, city.cell)
	if spawn_at == NO_CELL:
		return false
	var warrior := game.spawn_unit(rival, "warrior", spawn_at)
	if warrior == null:
		return false
	return game.move_unit(warrior, city.cell)


static func _empty_passable(game: GameSetup, around: Vector2i) -> Vector2i:
	var best := NO_CELL
	var best_d := 999999
	for row in game.map.height:
		for col in game.map.width:
			var cell := Vector2i(col, row)
			if cell == around or not game.map.is_passable(cell, game.config):
				continue
			if game.map.land_at(cell) == "volcanic" or _occupied(game, cell, null):
				continue
			var away := _dist(cell, around)
			if away < best_d:
				best = cell
				best_d = away
	return best


static func _remove_human_settlers(game: GameSetup) -> void:
	var doomed: Array[PlayerState.UnitState] = []
	for unit in game.players[game.human_index].units:
		if unit.unit_type == "settler":
			doomed.append(unit)
	for unit in doomed:
		game._remove_unit(unit)
	game._refresh_fog()


static func _empty_queue(game: GameSetup, city: MapCity) -> void:
	while not city.queue.is_empty():
		game.cancel_queue(city, 0)


static func _weakest_city(game: GameSetup, player: int) -> MapCity:
	var best: MapCity = null
	var best_prod := 999999
	for city in game.cities:
		if city.player != player:
			continue
		var prod := int(game.city_yields(city)["production"])
		if prod < best_prod:
			best = city
			best_prod = prod
	return best


static func _strongest_city(game: GameSetup, player: int) -> MapCity:
	var best: MapCity = null
	var best_prod := -1
	for city in game.cities:
		if city.player != player:
			continue
		var prod := int(game.city_yields(city)["production"])
		if prod > best_prod:
			best = city
			best_prod = prod
	return best


static func _city_ids(game: GameSetup, player: int) -> Dictionary:
	var ids := {}
	for city in game.cities:
		if city.player == player:
			ids[city.id] = true
	return ids


static func _has_new_city(game: GameSetup, player: int, known: Dictionary) -> bool:
	for city in game.cities:
		if city.player == player and not known.has(city.id):
			return true
	return false


static func _unit_ids(game: GameSetup, player: int) -> Dictionary:
	var ids := {}
	for unit in game.players[player].units:
		ids[unit.id] = true
	return ids


static func _new_settler(game: GameSetup, player: int, before: Dictionary) -> bool:
	for unit in game.players[player].units:
		if unit.unit_type == "settler" and not before.has(unit.id):
			return true
	return false


static func _count_type(game: GameSetup, player: int, unit_type: String) -> int:
	var count := 0
	for unit in game.players[player].units:
		if unit.unit_type == unit_type:
			count += 1
	return count


static func _note_city_count(stats: Dictionary, game: GameSetup, turn: int) -> void:
	var count := game.city_count(game.human_index)
	if count >= 1 and int(stats["first_city"]) < 0:
		stats["first_city"] = turn
	if count >= 2 and int(stats["second_city"]) < 0:
		stats["second_city"] = turn


static func _note_building(stats: Dictionary, game: GameSetup, turn: int) -> void:
	if int(stats["first_building"]) >= 0:
		return
	for city in game.cities:
		if city.player == game.human_index and not city.buildings.is_empty():
			stats["first_building"] = turn
			return


static func _add_casts(stats: Dictionary, turn: int, used: int) -> void:
	stats["casts_t50"] = int(stats["casts_t50"]) + used
	if turn <= 15:
		stats["casts_t15"] = int(stats["casts_t15"]) + used
	if turn <= 25:
		stats["casts_t25"] = int(stats["casts_t25"]) + used
	if turn >= 26 and turn <= 35:
		stats["casts_26_35"] = int(stats["casts_26_35"]) + used


static func _snap(game: GameSetup) -> Dictionary:
	var human := game.human_index
	return {
		"cities": game.city_count(human),
		"pop": game.population_total(human),
		"income": game.mana_per_turn(human),
		"bank": game.players[human].mana,
	}


static func _fill_army(game: GameSetup, stats: Dictionary) -> void:
	var warriors := 0
	var units := 0
	for unit in game.players[game.human_index].units:
		units += 1
		if unit.unit_type == "warrior":
			warriors += 1
	stats["warriors"] = warriors
	stats["units"] = units


static func _dist(a: Vector2i, b: Vector2i) -> int:
	return Hex.distance(Hex.offset_to_axial(a), Hex.offset_to_axial(b))


static func _offset_before(a: Vector2i, b: Vector2i) -> bool:
	if a.x == b.x:
		return a.y < b.y
	return a.x < b.x


static func _blank_stats() -> Dictionary:
	return {
		"order": "",
		"seed": 0,
		"first_city": -1,
		"second_city": -1,
		"first_building": -1,
		"first_settler": -1,
		"first_forest": -1,
		"first_spell": "",
		"casts_t15": 0,
		"casts_t25": 0,
		"casts_t50": 0,
		"casts_26_35": 0,
		"warriors": 0,
		"units": 0,
		"ended": "",
		"end_turn": 0,
	}
