class_name RivalAI
extends RefCounted

## One player's turn. Calls GameSetup only. No search, no personality.
## The same board and config always pick the same actions. Scores are integers.
## A negative score is not taken. Ties keep the earlier candidate: ability order,
## then axial q, then axial r.

const NO_CELL := Vector2i(-999999, -999999)
const _STEPS := 8
const _FOUND_RADIUS := 5
const _IMPROVE: PackedStringArray = ["forest", "hills", "plains"]
const _WORSEN: PackedStringArray = ["water", "volcanic"]
const _MILITARY: PackedStringArray = ["warrior", "archer", "scout"]
const _BUILDINGS: PackedStringArray = ["granary", "lumber_mill", "mana_well"]


static func play(setup: GameSetup, player: int) -> void:
	if setup == null or setup.result != null or setup.config == null or not setup.config.ai_enabled:
		return
	if player < 0 or player >= setup.players.size():
		return
	if setup.players[player].eliminated:
		return
	_act_units(setup, player)
	if setup.result != null:
		return
	_produce(setup, player)
	if setup.result != null:
		return
	_cast(setup, player)


static func _act_units(setup: GameSetup, player: int) -> void:
	var ids: Array[int] = []
	for unit in setup.players[player].units:
		ids.append(unit.id)
	ids.sort()
	for id in ids:
		if setup.result != null:
			return
		var unit := _unit_by_id(setup, player, id)
		if unit == null:
			continue
		_act_unit(setup, unit)


static func _act_unit(setup: GameSetup, unit: PlayerState.UnitState) -> void:
	var guard := 0
	while guard < _STEPS and setup.result == null and setup.players[unit.owner].units.has(unit):
		guard += 1
		# Fortify survives the refill on purpose: it is a stance, and the human
		# can still walk it off. AP is what ends the unit's turn. Leaving the
		# order in place made a rival fortify once and then never move again.
		if unit.ap <= 0:
			return
		var action := _best_action(setup, unit)
		if int(action["score"]) <= 0:
			if setup.fortify_unit(unit):
				return
			if setup.skip_unit(unit):
				return
			# A sprinted scout with nowhere to walk still ends the player turn.
			return
		if not _apply(setup, unit, action):
			return


static func _best_action(setup: GameSetup, unit: PlayerState.UnitState) -> Dictionary:
	var best := {"score": 0, "kind": "", "ability": "", "cell": unit.cell}
	if unit.movement_only:
		_consider_moves(setup, unit, best)
		return best
	for ability_id in setup.unit_abilities(unit):
		if not setup.ability_block_reason(unit, ability_id).is_empty():
			continue
		var ability := setup.config.ability(ability_id)
		if ability.effect == "move":
			_consider(best, _sprint_score(setup, unit, ability_id), "ability", ability_id, unit.cell)
			continue
		if ability.effect != "damage":
			continue
		var targets: Array[Vector2i] = setup.ability_targets(unit, ability_id)
		_sort_cells(targets)
		for cell in targets:
			var preview := setup.ability_preview(unit, ability_id, cell)
			if not bool(preview["ok"]):
				continue
			_consider(best, _attack_score(setup, preview), "ability", ability_id, cell)
	if unit.unit_type == "settler" and setup.can_found(unit).is_empty() and _good_found(setup, unit, unit.cell):
		_consider(best, setup.config.ai_weight_found, "found", "", unit.cell)
	_consider_moves(setup, unit, best)
	return best


static func _consider(best: Dictionary, score: int, kind: String, ability_id: String, cell: Vector2i) -> void:
	if score <= int(best["score"]):
		return
	best["score"] = score
	best["kind"] = kind
	best["ability"] = ability_id
	best["cell"] = cell


static func _consider_moves(setup: GameSetup, unit: PlayerState.UnitState, best: Dictionary) -> void:
	var goal := _goal(setup, unit)
	var origin := Hex.offset_to_axial(unit.cell)
	var origin_dist := 999999
	if goal != NO_CELL:
		origin_dist = Hex.distance(origin, Hex.offset_to_axial(goal))
	var cells: Array[Vector2i] = []
	for key in setup.reachable_tiles(unit).keys():
		cells.append(key as Vector2i)
	_sort_cells(cells)
	for cell in cells:
		if _step_kills(setup, unit, cell):
			continue
		var score := 0
		if setup.capture_destination(unit, cell):
			score = setup.config.ai_weight_capture
		elif goal != NO_CELL:
			var gain := origin_dist - Hex.distance(Hex.offset_to_axial(cell), Hex.offset_to_axial(goal))
			if gain > 0:
				score = setup.config.ai_weight_closer * gain
		if setup.map.land_at(cell) == "volcanic":
			score -= setup.config.ai_weight_volcanic
		_consider(best, score, "move", "", cell)


static func _apply(setup: GameSetup, unit: PlayerState.UnitState, action: Dictionary) -> bool:
	var kind := str(action["kind"])
	var cell: Vector2i = action["cell"]
	if kind == "found":
		return setup.found_city(unit) != null
	if kind == "move":
		return setup.move_unit(unit, cell)
	if kind == "ability":
		return setup.use_ability(unit, str(action["ability"]), cell).is_empty()
	return false


static func _attack_score(setup: GameSetup, preview: Dictionary) -> int:
	var score := 0
	var hits: Array = preview["hits"]
	for hit in hits:
		var cell: Vector2i = hit["cell"]
		var damage := int(hit["damage"])
		var counter := int(hit["counter"])
		var unit := setup._unit_at(cell)
		if unit != null:
			score += damage * setup.config.ai_weight_damage
			if unit.max_hp <= 0 or damage >= unit.hp:
				score += setup.config.ai_weight_kill
		else:
			var city := setup.city_at_cell(cell)
			if city != null:
				score += damage * setup.config.ai_weight_city_damage
				if damage >= city.hp:
					score += setup.config.ai_weight_kill
		score -= counter * setup.config.ai_weight_counter
	if bool(preview["push"]) and bool(preview["push_open"]):
		score += setup.config.ai_weight_open_push
	return score


static func _sprint_score(setup: GameSetup, unit: PlayerState.UnitState, ability_id: String) -> int:
	var goal := _goal(setup, unit)
	if goal == NO_CELL:
		return 0
	var now := setup.reachable_tiles(unit)
	var later := setup.move_reach_preview(unit, ability_id)
	if later.is_empty():
		return 0
	var now_cell := _closest(now, goal, unit.cell)
	var later_cell := _closest(later, goal, unit.cell)
	var now_dist := Hex.distance(Hex.offset_to_axial(now_cell), Hex.offset_to_axial(goal))
	var later_dist := Hex.distance(Hex.offset_to_axial(later_cell), Hex.offset_to_axial(goal))
	if later_dist >= now_dist or now.has(later_cell):
		return 0
	return setup.config.ai_weight_sprint + setup.config.ai_weight_closer * (now_dist - later_dist)


static func _closest(tiles: Dictionary, goal: Vector2i, fallback: Vector2i) -> Vector2i:
	var best := fallback
	var best_dist := Hex.distance(Hex.offset_to_axial(fallback), Hex.offset_to_axial(goal))
	var found := false
	for key in tiles.keys():
		var cell := key as Vector2i
		var dist := Hex.distance(Hex.offset_to_axial(cell), Hex.offset_to_axial(goal))
		if not found or dist < best_dist or (dist == best_dist and _cell_before(cell, best)):
			best = cell
			best_dist = dist
			found = true
	return best


static func _goal(setup: GameSetup, unit: PlayerState.UnitState) -> Vector2i:
	if unit.unit_type == "settler":
		var spot := _found_goal(setup, unit)
		if spot != NO_CELL and spot != unit.cell:
			return spot
		if setup.config.ai_obeys_fog:
			return _explore_goal(setup, unit)
		return NO_CELL
	var victim := _enemy_goal(setup, unit)
	if victim != NO_CELL:
		return victim
	if setup.config.unit(unit.unit_type).can_capture:
		var city := _city_goal(setup, unit, true)
		if city != NO_CELL:
			return city
	var siege := _city_goal(setup, unit, false)
	if siege != NO_CELL:
		return siege
	if setup.config.ai_obeys_fog:
		return _explore_goal(setup, unit)
	return NO_CELL


static func _enemy_goal(setup: GameSetup, unit: PlayerState.UnitState) -> Vector2i:
	var best := NO_CELL
	var best_dist := 999999
	var best_hp := 999999
	for player in setup.players:
		if player.index == unit.owner or player.eliminated:
			continue
		for other in player.units:
			if not _sees_unit(setup, unit.owner, other):
				continue
			var dist := Hex.distance(Hex.offset_to_axial(unit.cell), Hex.offset_to_axial(other.cell))
			var hp := other.hp if other.max_hp > 0 else 0
			var better := dist < best_dist or (dist == best_dist and hp < best_hp) or (dist == best_dist and hp == best_hp and (best == NO_CELL or _cell_before(other.cell, best)))
			if better:
				best = other.cell
				best_dist = dist
				best_hp = hp
	return best


static func _city_goal(setup: GameSetup, unit: PlayerState.UnitState, zero_only: bool) -> Vector2i:
	var best := NO_CELL
	var best_dist := 999999
	for city in setup.cities:
		if city.player == unit.owner:
			continue
		if zero_only and city.hp > 0:
			continue
		if not _knows(setup, unit.owner, city.cell):
			continue
		var dist := Hex.distance(Hex.offset_to_axial(unit.cell), Hex.offset_to_axial(city.cell))
		if dist < best_dist or (dist == best_dist and (best == NO_CELL or _cell_before(city.cell, best))):
			best = city.cell
			best_dist = dist
	return best


static func _found_goal(setup: GameSetup, unit: PlayerState.UnitState) -> Vector2i:
	var best := NO_CELL
	var best_dist := 999999
	var origin := Hex.offset_to_axial(unit.cell)
	for hex in Hex.disk(origin, _FOUND_RADIUS):
		var cell := Hex.axial_to_offset(hex)
		if not _good_found(setup, unit, cell):
			continue
		var dist := Hex.distance(origin, hex)
		if dist < best_dist or (dist == best_dist and (best == NO_CELL or _cell_before(cell, best))):
			best = cell
			best_dist = dist
	return best


static func _explore_goal(setup: GameSetup, unit: PlayerState.UnitState) -> Vector2i:
	var best := NO_CELL
	var best_dist := 999999
	var best_ahead := 999999
	var origin := Hex.offset_to_axial(unit.cell)
	# Equal-distance unseen tiles used to keep the westernmost axial cell, so
	# every warrior walked to the west edge and sat there. The heading is a
	# compass direction from the nearest city, so it does not flip after the
	# unit passes the middle of the map.
	var ahead := origin
	var heading := _explore_heading(setup, unit)
	var radius: int = setup.config.ai_explore_radius
	for _step in radius:
		ahead = Hex.neighbor(ahead, heading)
	for hex in Hex.disk(origin, radius):
		var cell := Hex.axial_to_offset(hex)
		if not setup.map.in_bounds(cell):
			continue
		if setup.fog.sight(unit.owner, cell) != FogState.Sight.UNREVEALED:
			continue
		var dist := Hex.distance(origin, hex)
		var ahead_dist := Hex.distance(hex, ahead)
		var closer := dist < best_dist
		var ahead_tie := dist == best_dist and ahead_dist < best_ahead
		var axial_tie := dist == best_dist and ahead_dist == best_ahead and (best == NO_CELL or _cell_before(cell, best))
		if closer or ahead_tie or axial_tie:
			best = cell
			best_dist = dist
			best_ahead = ahead_dist
	return best


static func _explore_heading(setup: GameSetup, unit: PlayerState.UnitState) -> int:
	var origin := _nearest_city_axial(setup, unit)
	if origin == NO_CELL:
		return posmod(unit.id, 6)
	var middle := Hex.offset_to_axial(Vector2i(setup.map.width / 2, setup.map.height / 2))
	var best := 0
	var best_dist := 999999
	for dir in 6:
		var dist := Hex.distance(Hex.neighbor(origin, dir), middle)
		if dist < best_dist:
			best = dir
			best_dist = dist
	return best


static func _nearest_city_axial(setup: GameSetup, unit: PlayerState.UnitState) -> Vector2i:
	var best := NO_CELL
	var best_dist := 999999
	var origin := Hex.offset_to_axial(unit.cell)
	for city in setup.cities:
		if city.player != unit.owner:
			continue
		var dist := Hex.distance(origin, Hex.offset_to_axial(city.cell))
		if dist < best_dist or (dist == best_dist and (best == NO_CELL or _cell_before(city.cell, best))):
			best = city.cell
			best_dist = dist
	if best == NO_CELL:
		return NO_CELL
	return Hex.offset_to_axial(best)


static func _good_found(setup: GameSetup, unit: PlayerState.UnitState, cell: Vector2i) -> bool:
	if not setup.map.in_bounds(cell) or not setup.map.is_passable(cell, setup.config):
		return false
	var land := setup.map.land_at(cell)
	if land == "water" or land == "volcanic":
		return false
	var owner := setup.owner_at(cell)
	if owner != -1 and owner != unit.owner:
		return false
	var other := setup._unit_at(cell)
	if other != null and other != unit:
		return false
	var axial := Hex.offset_to_axial(cell)
	for city in setup.cities:
		if Hex.distance(axial, Hex.offset_to_axial(city.cell)) < setup.config.city_min_distance:
			return false
	return not _threatened(setup, unit.owner, cell)


static func _threatened(setup: GameSetup, player: int, cell: Vector2i) -> bool:
	var radius: int = setup.config.ai_settle_threat
	if radius < 0:
		return false
	var axial := Hex.offset_to_axial(cell)
	for other in setup.players:
		if other.index == player or other.eliminated:
			continue
		for unit in other.units:
			if not setup.config.unit(unit.unit_type).combatant:
				continue
			if not _sees_unit(setup, player, unit):
				continue
			if Hex.distance(axial, Hex.offset_to_axial(unit.cell)) <= radius:
				return true
	return false


static func _produce(setup: GameSetup, player: int) -> void:
	var military := _military_count(setup, player)
	var settler_busy := _settler_pending(setup, player)
	var cities := 0
	for city in setup.cities:
		if city.player == player:
			cities += 1
	for city in setup.cities:
		if city.player != player or not city.queue.is_empty():
			continue
		var item := ""
		if military < setup.config.ai_military_target:
			item = _next_military(setup, player)
			military += 1
		elif cities == 1 and not settler_busy and city.population >= setup.config.unit("settler").min_city_size:
			item = "settler"
			settler_busy = true
		else:
			item = _building_choice(setup, city)
			if item.is_empty():
				item = _next_military(setup, player)
				military += 1
		if item.is_empty():
			continue
		if CityRules.is_building(item):
			var plot := _building_plot(setup, city, item)
			if plot == NO_CELL:
				continue
			setup.enqueue(city, item, plot)
		else:
			setup.enqueue(city, item)


static func _military_count(setup: GameSetup, player: int) -> int:
	var count := 0
	for unit in setup.players[player].units:
		if setup.config.unit(unit.unit_type).combatant:
			count += 1
	for city in setup.cities:
		if city.player != player:
			continue
		for item in city.queue:
			if not item.is_building and setup.config.units.has(item.item_id) and setup.config.unit(item.item_id).combatant:
				count += 1
	return count


static func _settler_pending(setup: GameSetup, player: int) -> bool:
	for unit in setup.players[player].units:
		if unit.unit_type == "settler":
			return true
	for city in setup.cities:
		if city.player != player:
			continue
		for item in city.queue:
			if item.item_id == "settler":
				return true
	return false


static func _next_military(setup: GameSetup, player: int) -> String:
	var have := {"warrior": 0, "archer": 0, "scout": 0}
	for unit in setup.players[player].units:
		if have.has(unit.unit_type):
			have[unit.unit_type] = int(have[unit.unit_type]) + 1
	for city in setup.cities:
		if city.player != player:
			continue
		for item in city.queue:
			if have.has(item.item_id):
				have[item.item_id] = int(have[item.item_id]) + 1
	for type in _MILITARY:
		if int(have[type]) == 0:
			return type
	return "warrior"


static func _building_choice(setup: GameSetup, city: MapCity) -> String:
	for item_id in _BUILDINGS:
		if item_id == "lumber_mill":
			if _mill_plot(setup, city) == NO_CELL:
				continue
		elif setup.placement_tiles(city, item_id).is_empty():
			continue
		return item_id
	return ""


static func _building_plot(setup: GameSetup, city: MapCity, item_id: String) -> Vector2i:
	if item_id == "lumber_mill":
		var forested := _mill_plot(setup, city)
		if forested != NO_CELL:
			return forested
	var tiles: Array[Vector2i] = setup.placement_tiles(city, item_id)
	if tiles.is_empty():
		return NO_CELL
	_sort_cells(tiles)
	return tiles[0]


static func _mill_plot(setup: GameSetup, city: MapCity) -> Vector2i:
	var tiles: Array[Vector2i] = setup.placement_tiles(city, "lumber_mill")
	_sort_cells(tiles)
	var best := NO_CELL
	var best_forests := 0
	for cell in tiles:
		var forests := _forest_neighbors(setup, cell)
		if forests > best_forests:
			best = cell
			best_forests = forests
	return best


static func _forest_neighbors(setup: GameSetup, cell: Vector2i) -> int:
	var count := 0
	for hex in Hex.neighbors(Hex.offset_to_axial(cell)):
		var other := Hex.axial_to_offset(hex)
		if setup.map.in_bounds(other) and setup.map.land_at(other) == "forest":
			count += 1
	return count


static func _cast(setup: GameSetup, player: int) -> void:
	var best_score := 0
	var best_spell := ""
	var best_cell := NO_CELL
	var best_dir := 0
	for spell_id in GameConfig.SPELL_IDS:
		if not setup.spell_block_reason(player, spell_id).is_empty():
			continue
		var stats := setup.config.spell(spell_id)
		var dirs := 1
		if stats.shape == "line":
			dirs = 6
		for cell in _spell_cells(setup, player, stats.range):
			for dir in dirs:
				var preview := setup.spell_preview(player, spell_id, cell, dir)
				if not str(preview["reason"]).is_empty():
					continue
				var score := _spell_score(setup, player, stats.land, preview)
				if score > best_score:
					best_score = score
					best_spell = spell_id
					best_cell = cell
					best_dir = dir
	if best_spell.is_empty() or best_score < setup.config.ai_min_spell_score:
		return
	setup.cast_spell(player, best_spell, best_cell, best_dir)


static func _spell_cells(setup: GameSetup, player: int, spell_range: int) -> Array[Vector2i]:
	var seen := {}
	var cells: Array[Vector2i] = []
	for owned in setup.owned_cells():
		if setup.owner_at(owned) != player:
			continue
		for hex in Hex.disk(Hex.offset_to_axial(owned), spell_range):
			var cell := Hex.axial_to_offset(hex)
			if not setup.map.in_bounds(cell) or seen.has(cell):
				continue
			if setup.config.ai_obeys_fog and setup.fog.sight(player, cell) == FogState.Sight.UNREVEALED:
				continue
			seen[cell] = true
			cells.append(cell)
	_sort_cells(cells)
	return cells


static func _spell_score(setup: GameSetup, player: int, land_id: String, preview: Dictionary) -> int:
	var tiles: Array = preview["tiles"]
	var changed: Array = preview["changed"]
	if changed.is_empty() or _suicidal(setup, player, land_id, tiles, changed):
		return 0
	var improve := _IMPROVE.has(land_id)
	var worsen := _WORSEN.has(land_id)
	var score := 0
	for cell in changed:
		var here: Vector2i = cell
		var owner := setup.owner_at(here)
		if improve and (owner == player or (owner == -1 and _near_own_city(setup, player, here))):
			score += setup.config.ai_weight_improve
		elif improve and owner != player and owner != -1:
			score -= setup.config.ai_weight_improve
		elif worsen and owner != player and owner != -1:
			score += setup.config.ai_weight_worsen
		elif worsen and owner == player:
			score -= setup.config.ai_weight_worsen
	return score


static func _suicidal(setup: GameSetup, player: int, land_id: String, tiles: Array, changed: Array) -> bool:
	if land_id == "water":
		for cell in tiles:
			var here: Vector2i = cell
			var unit := setup._unit_at(here)
			if unit != null and unit.owner == player:
				return true
			var city := setup.city_at_cell(here)
			if city != null and city.player == player:
				return true
	if land_id == "volcanic":
		for cell in changed:
			var here: Vector2i = cell
			var unit := setup._unit_at(here)
			if unit != null and unit.owner == player and _volcanic_kills(setup, unit):
				return true
	return false


static func _near_own_city(setup: GameSetup, player: int, cell: Vector2i) -> bool:
	var axial := Hex.offset_to_axial(cell)
	for city in setup.cities:
		if city.player != player:
			continue
		if Hex.distance(axial, Hex.offset_to_axial(city.cell)) <= setup.config.border_max_radius + 1:
			return true
	return false


static func _step_kills(setup: GameSetup, unit: PlayerState.UnitState, cell: Vector2i) -> bool:
	if setup.map.land_at(cell) != "volcanic":
		return false
	if not setup.config.volcanic_can_kill or setup.config.volcanic_damage <= 0:
		return false
	if unit.max_hp <= 0:
		return true
	# The step sets acted, so End Turn does not heal before the hit.
	return unit.hp - setup.config.volcanic_damage <= 0


static func _volcanic_kills(setup: GameSetup, unit: PlayerState.UnitState) -> bool:
	if not setup.config.volcanic_can_kill or setup.config.volcanic_damage <= 0:
		return false
	if unit.max_hp <= 0:
		return true
	var hp := unit.hp
	if not unit.acted and setup.config.heal_only_if_idle:
		hp = mini(unit.max_hp, hp + setup.config.unit_heal)
	return hp - setup.config.volcanic_damage <= 0


static func _sees_unit(setup: GameSetup, player: int, unit: PlayerState.UnitState) -> bool:
	if not setup.config.ai_obeys_fog:
		return true
	return setup.fog.unit_visible(player, unit.cell)


static func _knows(setup: GameSetup, player: int, cell: Vector2i) -> bool:
	if not setup.config.ai_obeys_fog:
		return true
	return setup.fog.sight(player, cell) != FogState.Sight.UNREVEALED


static func _unit_by_id(setup: GameSetup, player: int, id: int) -> PlayerState.UnitState:
	for unit in setup.players[player].units:
		if unit.id == id:
			return unit
	return null


static func _sort_cells(cells: Array[Vector2i]) -> void:
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _cell_before(a, b))


static func _cell_before(a: Vector2i, b: Vector2i) -> bool:
	var aa := Hex.offset_to_axial(a)
	var bb := Hex.offset_to_axial(b)
	if aa.x != bb.x:
		return aa.x < bb.x
	return aa.y < bb.y
