class_name SoakInvariants
extends RefCounted

## Pure checks over a GameSetup. The soak calls this after every action.
## Nothing here belongs in scripts/core.


static func check(setup: GameSetup) -> String:
	if setup == null or setup.map == null or setup.config == null or setup.fog == null:
		return "setup is missing"
	if setup.turn < 1 or setup.turn > setup.config.turn_limit:
		return "turn %d is outside 1..%d" % [setup.turn, setup.config.turn_limit]
	var seen := {}
	var military := {}
	var civilian := {}
	for player in setup.players:
		if player.mana < 0:
			return "player %d mana is %d" % [player.index, player.mana]
		if player.eliminated:
			if not player.units.is_empty():
				return "eliminated player %d still has units" % player.index
			if setup.city_count(player.index) > 0:
				return "eliminated player %d still has a city" % player.index
		for unit in player.units:
			if seen.has(unit):
				return "unit %d is in two player lists" % unit.id
			seen[unit] = player.index
			if unit.owner != player.index:
				return "unit %d owner %d sits in player %d's list" % [unit.id, unit.owner, player.index]
			if not setup.map.in_bounds(unit.cell):
				return "unit %d is off the map at %s" % [unit.id, unit.cell]
			if setup.map.land_at(unit.cell) == "water":
				return "land unit %d (%s) is on water at %s" % [unit.id, unit.unit_type, unit.cell]
			var combatant := setup.config.unit(unit.unit_type).combatant
			var bag: Dictionary = military if combatant else civilian
			if bag.has(unit.cell):
				var kind := "military" if combatant else "civilian"
				return "two %s units on %s" % [kind, unit.cell]
			bag[unit.cell] = unit.id
			if unit.max_hp > 0 and (unit.hp < 0 or unit.hp > unit.max_hp):
				return "unit %d hp %d / %d" % [unit.id, unit.hp, unit.max_hp]
			var max_ap := setup.config.unit(unit.unit_type).ap
			if unit.ap < 0 or unit.ap > max_ap:
				return "unit %d ap %d is outside 0..%d" % [unit.id, unit.ap, max_ap]
			if unit.used_ability and unit.ap != 0:
				return "unit %d used an ability and still has %d AP" % [unit.id, unit.ap]
	for city in setup.cities:
		if city.player < 0 or city.player >= setup.players.size():
			return "city %d has player %d" % [city.id, city.player]
		if setup.players[city.player].eliminated:
			return "city %d belongs to eliminated player %d" % [city.id, city.player]
		if city.hp < 0 or city.hp > city.max_hp:
			return "city %d hp %d / %d" % [city.id, city.hp, city.max_hp]
		if city.population < 1:
			return "city %d population %d" % [city.id, city.population]
		if not setup.map.in_bounds(city.cell):
			return "city %d is off the map" % city.id
	return _territory(setup)


static func fingerprint(setup: GameSetup) -> Dictionary:
	var units: Array = []
	for player in setup.players:
		for unit in player.units:
			units.append({
				"id": unit.id,
				"owner": unit.owner,
				"type": unit.unit_type,
				"cell": unit.cell,
				"hp": unit.hp,
				"ap": unit.ap,
				"order": unit.order,
			})
	units.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["id"]) < int(b["id"])
	)
	var cities: Array = []
	for city in setup.cities:
		cities.append({
			"id": city.id,
			"player": city.player,
			"cell": city.cell,
			"hp": city.hp,
			"pop": city.population,
			"queue": city.queue.size(),
			"buildings": city.buildings.size(),
		})
	cities.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["id"]) < int(b["id"])
	)
	var mana: Array[int] = []
	for player in setup.players:
		mana.append(player.mana)
	var land := 0
	for row in setup.map.height:
		for col in setup.map.width:
			land = (land * 33 + setup.map.land_at(Vector2i(col, row)).hash()) & 0x7fffffff
	var ending := ""
	if setup.result != null:
		ending = setup.result.ending
	return {
		"turn": setup.turn,
		"ending": ending,
		"units": units,
		"cities": cities,
		"mana": mana,
		"land": land,
	}


static func _territory(setup: GameSetup) -> String:
	var claimed := {}
	for city in setup.cities:
		for cell in setup.territory_cells(city):
			if not setup.map.in_bounds(cell):
				return "city %d territory %s is off the map" % [city.id, cell]
			if setup.owner_at(cell) != city.player:
				return "city %d owns %s in its territory but owner_at is %d" % [city.id, cell, setup.owner_at(cell)]
			if claimed.has(cell) and int(claimed[cell]) != city.id:
				return "tile %s is in city %d and city %d" % [cell, int(claimed[cell]), city.id]
			claimed[cell] = city.id
	for cell in setup.owned_cells():
		if not claimed.has(cell):
			return "owner %d on %s has no city territory" % [setup.owner_at(cell), cell]
		var city := setup.city_by_id(int(claimed[cell]))
		if city == null or setup.owner_at(cell) != city.player:
			return "owner %d on %s does not match city %d" % [setup.owner_at(cell), cell, int(claimed[cell])]
	return ""
