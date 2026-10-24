class_name CityRules
extends RefCounted

## City yields, growth, and border choice. GameSetup owns the queue and applies
## these results. city_mana is the only mana-per-turn formula. Worked tiles and
## border claims share one ordering:
## higher food + production, then higher food, then nearer the city center,
## then smaller axial q, then smaller axial r.
## The center is always counted on its own and is not one of the worked tiles.
## A lumber mill counts forests on the six neighbors of its tile.

const BUILDING_IDS: PackedStringArray = ["granary", "mana_well", "lumber_mill"]


static func is_building(item_id: String) -> bool:
	return BUILDING_IDS.has(item_id)


static func item_cost(cfg: GameConfig, item_id: String) -> int:
	if cfg.units.has(item_id):
		return cfg.unit(item_id).cost
	if item_id == "granary":
		return cfg.granary_cost
	if item_id == "mana_well":
		return cfg.mana_well_cost
	if item_id == "lumber_mill":
		return cfg.lumber_mill_cost
	return -1


static func growth_threshold(cfg: GameConfig, population: int) -> int:
	return cfg.growth_base + cfg.growth_per_population * population


static func work_tiles(cfg: GameConfig, map: MapState, city: MapCity, owned: Array[Vector2i]) -> Array[Vector2i]:
	var pool: Array[Vector2i] = []
	for cell in owned:
		if cell != city.cell:
			pool.append(cell)
	var center := city.cell
	pool.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return prefer_yield(a, b, cfg, map, center)
	)
	var worked: Array[Vector2i] = []
	var count := mini(city.population, pool.size())
	for i in count:
		worked.append(pool[i])
	return worked


## One city's mana this turn: city.mana_base + floor(population / divisor),
## plus buildings.mana_well_mana for each Mana Well on the live building list.
static func city_mana(cfg: GameConfig, city: MapCity) -> int:
	var mana := cfg.city_mana_base
	if cfg.city_mana_per_population_divisor > 0:
		mana += int(city.population / cfg.city_mana_per_population_divisor)
	for building in city.buildings:
		var placed := building as MapCity.Building
		if placed.kind == "mana_well":
			mana += cfg.mana_well_mana
	return mana


static func yields(cfg: GameConfig, map: MapState, city: MapCity, owned: Array[Vector2i]) -> Dictionary:
	var worked := work_tiles(cfg, map, city, owned)
	var center := cfg.land(map.land_at(city.cell))
	var food := center.food + cfg.city_center_food
	var production := center.production + cfg.city_center_production
	for cell in worked:
		var stats := cfg.land(map.land_at(cell))
		food += stats.food
		production += stats.production
	var mana := city_mana(cfg, city)
	for building in city.buildings:
		var placed := building as MapCity.Building
		if placed.kind == "granary":
			food += cfg.granary_food
		elif placed.kind == "lumber_mill":
			production += cfg.lumber_mill_production_per_adjacent_forest * adjacent_forests(map, placed.cell)
	return {
		"food": food,
		"production": production,
		"mana": mana,
		"worked": worked,
		"surplus": food - cfg.food_per_population * city.population,
		"threshold": growth_threshold(cfg, city.population),
	}


static func apply_growth(cfg: GameConfig, city: MapCity, food: int) -> void:
	var surplus := food - cfg.food_per_population * city.population
	if surplus >= 0:
		city.food_stored += surplus
		var guard := 0
		while guard < 64:
			guard += 1
			var threshold := growth_threshold(cfg, city.population)
			if threshold <= 0 or city.food_stored < threshold:
				break
			city.food_stored -= threshold
			city.population += 1
		return
	if not cfg.shortfall_drains_bar:
		return
	city.food_stored += surplus
	if city.food_stored >= 0:
		return
	city.population = maxi(cfg.starve_population_min, city.population - cfg.starve_population_loss)
	city.food_stored = 0


static func adjacent_forests(map: MapState, cell: Vector2i) -> int:
	var count := 0
	for axial in Hex.neighbors(Hex.offset_to_axial(cell)):
		var neighbor := Hex.axial_to_offset(axial)
		if map.in_bounds(neighbor) and map.land_at(neighbor) == "forest":
			count += 1
	return count


static func border_candidates(cfg: GameConfig, map: MapState, city: MapCity, owned: Array[Vector2i], owner_of: Callable) -> Array[Vector2i]:
	var have := {}
	for cell in owned:
		have[cell] = true
	var found := {}
	var center := Hex.offset_to_axial(city.cell)
	for cell in owned:
		for axial in Hex.neighbors(Hex.offset_to_axial(cell)):
			var offset := Hex.axial_to_offset(axial)
			if not map.in_bounds(offset) or have.has(offset) or found.has(offset):
				continue
			var dist := Hex.distance(center, axial)
			if dist < 1 or dist > cfg.border_max_radius:
				continue
			if int(owner_of.call(offset)) != -1 and not cfg.can_claim_owned_tiles:
				continue
			if map.land_at(offset) == "water" and not cfg.borders_can_claim_water:
				continue
			found[offset] = true
	var out: Array[Vector2i] = []
	for key in found.keys():
		out.append(key as Vector2i)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return prefer_yield(a, b, cfg, map, city.cell)
	)
	return out


static func prefer_yield(a: Vector2i, b: Vector2i, cfg: GameConfig, map: MapState, center: Vector2i) -> bool:
	var ak := _yield_key(cfg, map.land_at(a))
	var bk := _yield_key(cfg, map.land_at(b))
	if ak.x != bk.x:
		return ak.x > bk.x
	if ak.y != bk.y:
		return ak.y > bk.y
	return prefer_near(a, b, center)


static func prefer_near(a: Vector2i, b: Vector2i, center: Vector2i) -> bool:
	var da := Hex.distance(Hex.offset_to_axial(center), Hex.offset_to_axial(a))
	var db := Hex.distance(Hex.offset_to_axial(center), Hex.offset_to_axial(b))
	if da != db:
		return da < db
	var aa := Hex.offset_to_axial(a)
	var ba := Hex.offset_to_axial(b)
	if aa.x != ba.x:
		return aa.x < ba.x
	return aa.y < ba.y


static func _yield_key(cfg: GameConfig, land_id: String) -> Vector2i:
	var stats := cfg.land(land_id)
	return Vector2i(stats.food + stats.production, stats.food)
