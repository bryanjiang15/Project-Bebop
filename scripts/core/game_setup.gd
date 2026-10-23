class_name GameSetup
extends RefCounted

## One new game: map, players, starting units, and the opening fog.
## map.seed 0 rolls a non-zero seed. The seed that built the map is printed
## as "map seed: N". Writing N back into map.seed replays that map and those starts.
## A failed placement retries with a derived seed, up to generation_attempts.

const REASON_SETTLER := "Select a settler"
const REASON_WATER := "Cannot found on water"
const REASON_OWNED := "Cannot found on another player's tile"
const REASON_DISTANCE := "Too close to another city"
const REASON_OFF_MAP := "Cannot found off the map"
const REASON_CITY := "Select a city"
const REASON_UNKNOWN := "Unknown item"
const REASON_CENTER := "Cannot build on the city center"
const REASON_BORDERS := "Not in city borders"
const REASON_OCCUPIED := "Tile already has a building"
const REASON_BUILD_OFF_MAP := "Cannot build off the map"
const NO_CELL := Vector2i(-999999, -999999)

var config: GameConfig
var seed_used: int
var turn: int = 1
var map: MapState
var players: Array[PlayerState] = []
var cities: Array[MapCity] = []
var fog: FogState
var human_index: int
var _owners: Dictionary = {}
var _city_tiles: Dictionary = {}
var _next_unit_id: int = 1
var _next_city_id: int = 1
var _moving: PlayerState.UnitState


static func start(cfg: GameConfig) -> GameSetup:
	return start_with_seed(cfg, cfg.map_seed)


static func start_with_seed(cfg: GameConfig, seed_value: int) -> GameSetup:
	var base := seed_value
	if base == 0:
		base = _random_seed()
	var setup: GameSetup = null
	for attempt in cfg.generation_attempts:
		var candidate := _derived_seed(base, attempt)
		var map := MapGenerator.generate(cfg, candidate)
		var starts := _place_starts(cfg, map, candidate)
		if starts.size() != cfg.player_count:
			continue
		setup = _assemble(cfg, map, starts, candidate)
		break
	if setup == null:
		push_error("no fair starts after %d maps from seed %d" % [cfg.generation_attempts, base])
		return null
	print("map seed: %d" % setup.seed_used)
	return setup


static func _assemble(cfg: GameConfig, map: MapState, starts: Array[Vector2i], seed_value: int) -> GameSetup:
	var setup := GameSetup.new()
	setup.config = cfg
	setup.seed_used = seed_value
	setup.turn = 1
	setup.map = map
	setup.human_index = cfg.human_index
	for index in cfg.player_count:
		var player := PlayerState.new()
		player.index = index
		player.human = index == cfg.human_index
		player.color = cfg.player_colors[index]
		setup.players.append(player)
	setup.fog = FogState.new()
	setup.fog.resize(map.width, map.height, cfg.player_count)
	for index in cfg.player_count:
		for unit_type in cfg.starting_units:
			if setup.spawn_unit(index, unit_type, starts[index]) == null:
				push_error("starting %s could not be placed for player %d" % [unit_type, index])
				return null
	return setup


static func _place_starts(cfg: GameConfig, map: MapState, seed_value: int) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for row in map.height:
		for col in map.width:
			var cell := Vector2i(col, row)
			if map.passable_count(cell, cfg.start_quality_radius, cfg) >= cfg.start_quality_min:
				candidates.append(cell)
	if candidates.size() < cfg.player_count:
		return []
	for attempt in cfg.start_attempts:
		var order: Array[Vector2i] = candidates.duplicate()
		var rng := RandomNumberGenerator.new()
		rng.seed = _derived_seed(seed_value, attempt)
		_shuffle(order, rng)
		var picked: Array[Vector2i] = []
		for cell in order:
			var far_enough := true
			var axial := Hex.offset_to_axial(cell)
			for previous in picked:
				if Hex.distance(axial, Hex.offset_to_axial(previous)) < cfg.start_min_distance:
					far_enough = false
					break
			if not far_enough:
				continue
			picked.append(cell)
			if picked.size() == cfg.player_count:
				return picked
	return []


static func _shuffle(items: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := items[i]
		items[i] = items[j]
		items[j] = swap


## attempt 0 keeps the seed, so the printed seed replays without a second derivation.
static func _derived_seed(seed_value: int, attempt: int) -> int:
	if attempt == 0:
		return seed_value
	var mixed := (seed_value + attempt * 2654435761) & 0x7fffffff
	if mixed == 0:
		mixed = attempt
	return mixed


static func _random_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var picked := rng.randi() & 0x7fffffff
	if picked == 0:
		picked = 1
	return picked


func human_settler_cell() -> Vector2i:
	for unit in players[human_index].units:
		if unit.unit_type == "settler":
			return unit.cell
	return players[human_index].units[0].cell


func unit_total() -> int:
	var count := 0
	for player in players:
		count += player.units.size()
	return count


## The only way to create a unit. `pos` is an odd-r offset cell, same as UnitState.cell.
func spawn_unit(player: int, type: String, pos: Vector2i) -> PlayerState.UnitState:
	if config == null or not config.units.has(type):
		return null
	if player < 0 or player >= players.size():
		return null
	if map == null or not map.is_passable(pos, config):
		return null
	var unit := PlayerState.UnitState.new()
	unit.unit_type = type
	unit.cell = pos
	unit.owner = player
	unit.mp = config.unit(type).move
	if not _can_enter(unit, pos):
		return null
	unit.id = _next_unit_id
	_next_unit_id += 1
	players[player].units.append(unit)
	_refresh_fog()
	return unit


func reachable_tiles(unit: PlayerState.UnitState) -> Dictionary:
	if unit == null or unit.mp <= 0 or config == null:
		return {}
	_moving = unit
	var axial_tiles := Pathfinder.reachable(
		Hex.offset_to_axial(unit.cell),
		unit.mp,
		map.width,
		map.height,
		Callable(self, "_enter_cost_axial"),
		Callable(self, "_blocked_axial"),
		config.allow_enter_over_budget_if_mp_left,
	)
	_moving = null
	var cells := {}
	for key in axial_tiles.keys():
		cells[Hex.axial_to_offset(key as Vector2i)] = axial_tiles[key]
	return cells


func move_unit(unit: PlayerState.UnitState, dest: Vector2i) -> bool:
	var tiles := reachable_tiles(unit)
	if not tiles.has(dest):
		return false
	unit.cell = dest
	unit.mp = int(tiles[dest])
	_refresh_fog()
	return true


func end_turn() -> void:
	# One global clock: every city resolves here. Rivals have no turn of their own yet.
	# Growth uses this turn's yields, then production (a settler sees the post-growth pop),
	# then the border clock. The turn counter advances after that.
	for city in cities.duplicate():
		_resolve_city(city)
	turn += 1
	for player in players:
		for unit in player.units:
			unit.mp = config.unit(unit.unit_type).move
	_refresh_fog()


func can_found(unit: PlayerState.UnitState) -> String:
	if unit == null or unit.unit_type != "settler":
		return REASON_SETTLER
	if map == null or not map.in_bounds(unit.cell):
		return REASON_OFF_MAP
	if map.land_at(unit.cell) == "water":
		return REASON_WATER
	var owner := owner_at(unit.cell)
	if owner != -1 and owner != unit.owner:
		return REASON_OWNED
	var axial := Hex.offset_to_axial(unit.cell)
	for city in cities:
		if Hex.distance(axial, Hex.offset_to_axial(city.cell)) < config.city_min_distance:
			return REASON_DISTANCE
	return ""


func found_city(unit: PlayerState.UnitState) -> MapCity:
	if not can_found(unit).is_empty():
		return null
	var city := MapCity.new()
	city.id = _next_city_id
	_next_city_id += 1
	city.player = unit.owner
	city.cell = unit.cell
	city.population = 1
	city.radius = config.border_start_radius
	city.city_name = _next_city_name(unit.owner)
	cities.append(city)
	_claim(city)
	players[unit.owner].units.erase(unit)
	_refresh_fog()
	return city


func owner_at(cell: Vector2i) -> int:
	if not _owners.has(cell):
		return -1
	return int(_owners[cell])


func owned_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for key in _owners.keys():
		out.append(key as Vector2i)
	return out


func territory_cells(city: MapCity) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if city == null:
		return out
	for key in _city_tiles.keys():
		if int(_city_tiles[key]) == city.id:
			out.append(key as Vector2i)
	return out


func city_at_cell(cell: Vector2i) -> MapCity:
	for city in cities:
		if city.cell == cell:
			return city
	return null


func city_by_id(city_id: int) -> MapCity:
	for city in cities:
		if city.id == city_id:
			return city
	return null


func city_yields(city: MapCity) -> Dictionary:
	return CityRules.yields(config, map, city, territory_cells(city))


func turns_until_border(city: MapCity) -> int:
	if city == null or _border_choices(city).is_empty():
		return -1
	return config.border_turns_per_growth - city.border_turns


func placement_tiles(city: MapCity, item_id: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if city == null:
		return out
	for cell in territory_cells(city):
		if placement_reason(city, item_id, cell).is_empty():
			out.append(cell)
	return out


func placement_reason(city: MapCity, item_id: String, cell: Vector2i, ignore: MapCity.Item = null) -> String:
	if city == null:
		return REASON_CITY
	if not CityRules.is_building(item_id):
		return REASON_UNKNOWN
	if map == null or not map.in_bounds(cell):
		return REASON_BUILD_OFF_MAP
	if config.buildings_not_on_city_center and cell == city.cell:
		return REASON_CENTER
	if int(_city_tiles.get(cell, -1)) != city.id:
		return REASON_BORDERS
	if config.one_building_per_tile and _tile_reserved(cell, ignore):
		return REASON_OCCUPIED
	return ""


func enqueue(city: MapCity, item_id: String, cell: Vector2i = NO_CELL) -> String:
	if city == null:
		return REASON_CITY
	var reason := _enqueue_reason(city, item_id, cell)
	if not reason.is_empty():
		return reason
	var item := MapCity.Item.new()
	item.item_id = item_id
	item.is_building = CityRules.is_building(item_id)
	if item.is_building:
		item.cell = cell
	city.queue.append(item)
	return ""


func cancel_queue(city: MapCity, index: int) -> void:
	if city == null or index < 0 or index >= city.queue.size():
		return
	if index == 0:
		city.production_stored = 0
	city.queue.remove_at(index)


func move_queue(city: MapCity, index: int, delta: int) -> void:
	if city == null:
		return
	var next := index + delta
	if index < 0 or next < 0 or index >= city.queue.size() or next >= city.queue.size():
		return
	var item: MapCity.Item = city.queue[index]
	city.queue.remove_at(index)
	city.queue.insert(next, item)


func _refresh_fog() -> void:
	if fog == null or config == null:
		return
	fog.recompute(_vision_sources())


func _vision_sources() -> Array:
	var sources: Array = []
	for player in players:
		for unit in player.units:
			sources.append({
				"player": player.index,
				"cell": unit.cell,
				"radius": config.unit_vision,
			})
	for city in cities:
		sources.append({
			"player": city.player,
			"cell": city.cell,
			"radius": city.radius + config.city_vision_beyond_border,
		})
	return sources


func _enter_cost_axial(axial: Vector2i) -> int:
	var cell := Hex.axial_to_offset(axial)
	if not map.in_bounds(cell):
		return -1
	var stats := config.land(map.land_at(cell))
	if not stats.passable or stats.move_cost < 0:
		return -1
	return stats.move_cost


func _blocked_axial(axial: Vector2i) -> bool:
	return not _can_enter(_moving, Hex.axial_to_offset(axial))


func _can_enter(unit: PlayerState.UnitState, cell: Vector2i) -> bool:
	for player in players:
		for other in player.units:
			if other == unit or other.cell != cell:
				continue
			if other.owner != unit.owner:
				return false
			if config.one_military_and_one_civilian_per_tile:
				var moving_civilian := not config.unit(unit.unit_type).combatant
				var other_civilian := not config.unit(other.unit_type).combatant
				if moving_civilian == other_civilian:
					return false
	return true


func _claim(city: MapCity) -> void:
	for hex in Hex.disk(Hex.offset_to_axial(city.cell), city.radius):
		_claim_cell(city, Hex.axial_to_offset(hex))


func _claim_cell(city: MapCity, cell: Vector2i) -> void:
	if map == null or not map.in_bounds(cell):
		return
	if _owners.has(cell) and not config.can_claim_owned_tiles:
		return
	if map.land_at(cell) == "water" and not config.borders_can_claim_water:
		return
	_owners[cell] = city.player
	_city_tiles[cell] = city.id


func _resolve_city(city: MapCity) -> void:
	var snapshot: Dictionary = city_yields(city)
	CityRules.apply_growth(config, city, int(snapshot["food"]))
	_apply_production(city, int(snapshot["production"]))
	_expand_borders(city)


func _apply_production(city: MapCity, production: int) -> void:
	if city.queue.is_empty():
		city.production_stored = 0
		return
	city.production_stored += production
	var guard := 0
	while not city.queue.is_empty() and guard < 32:
		guard += 1
		var item: MapCity.Item = city.queue[0]
		var cost := CityRules.item_cost(config, item.item_id)
		if cost < 0:
			city.queue.pop_front()
			continue
		if not _can_finish(city, item):
			if cost > 0:
				city.production_stored = mini(city.production_stored, cost)
			return
		if cost > 0 and city.production_stored < cost:
			return
		if cost > 0:
			city.production_stored -= cost
		if not _finish_item(city, item):
			city.production_stored += cost
			if cost > 0:
				city.production_stored = mini(city.production_stored, cost)
			return
		city.queue.pop_front()


func _can_finish(city: MapCity, item: MapCity.Item) -> bool:
	if item.is_building:
		return placement_reason(city, item.item_id, item.cell, item).is_empty()
	if not config.units.has(item.item_id):
		return false
	var stats := config.unit(item.item_id)
	if stats.min_city_size > 0 and city.population < stats.min_city_size:
		return false
	if config.settler_population_taken_when_finished and stats.population_cost > 0:
		if city.population - stats.population_cost < config.starve_population_min:
			return false
	return _spawn_cell(city, item.item_id) != NO_CELL


func _finish_item(city: MapCity, item: MapCity.Item) -> bool:
	if item.is_building:
		if not placement_reason(city, item.item_id, item.cell, item).is_empty():
			return false
		var building := MapCity.Building.new()
		building.kind = item.item_id
		building.cell = item.cell
		city.buildings.append(building)
		return true
	var dest := _spawn_cell(city, item.item_id)
	if dest == NO_CELL:
		return false
	var stats := config.unit(item.item_id)
	var spent := 0
	if config.settler_population_taken_when_finished and stats.population_cost > 0:
		spent = stats.population_cost
		city.population -= spent
	var unit := spawn_unit(city.player, item.item_id, dest)
	if unit == null:
		city.population += spent
		return false
	return true


func _spawn_cell(city: MapCity, type: String) -> Vector2i:
	if config.spawn_on_city_center and _can_spawn_at(city.player, type, city.cell):
		return city.cell
	if not config.spawn_nearest_free_if_blocked:
		return NO_CELL
	var tiles := territory_cells(city)
	var center := city.cell
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return CityRules.prefer_near(a, b, center)
	)
	for cell in tiles:
		if cell == center:
			continue
		if _can_spawn_at(city.player, type, cell):
			return cell
	return NO_CELL


func _can_spawn_at(player: int, type: String, cell: Vector2i) -> bool:
	if config == null or map == null or not config.units.has(type):
		return false
	if not map.is_passable(cell, config):
		return false
	var ghost := PlayerState.UnitState.new()
	ghost.unit_type = type
	ghost.owner = player
	ghost.cell = cell
	return _can_enter(ghost, cell)


func _expand_borders(city: MapCity) -> void:
	city.border_turns += 1
	if city.border_turns < config.border_turns_per_growth:
		return
	city.border_turns = 0
	var picks := _border_choices(city)
	if picks.is_empty():
		return
	var cell := picks[0]
	_claim_cell(city, cell)
	var dist := Hex.distance(Hex.offset_to_axial(city.cell), Hex.offset_to_axial(cell))
	if dist > city.radius:
		city.radius = mini(dist, config.border_max_radius)


func _border_choices(city: MapCity) -> Array[Vector2i]:
	return CityRules.border_candidates(config, map, city, territory_cells(city), Callable(self, "owner_at"))


func _enqueue_reason(city: MapCity, item_id: String, cell: Vector2i) -> String:
	if CityRules.is_building(item_id):
		return placement_reason(city, item_id, cell)
	if not config.units.has(item_id):
		return REASON_UNKNOWN
	var stats := config.unit(item_id)
	if stats.min_city_size > 0 and city.population < stats.min_city_size:
		return "City must be size %d+" % stats.min_city_size
	return ""


func _tile_reserved(cell: Vector2i, ignore: MapCity.Item = null) -> bool:
	for city in cities:
		for building in city.buildings:
			if building.cell == cell:
				return true
		for item in city.queue:
			if item == ignore:
				continue
			if item.is_building and item.cell == cell:
				return true
	return false


func _next_city_name(player: int) -> String:
	var index := 0
	for city in cities:
		if city.player == player:
			index += 1
	if player < 0 or player >= config.city_names.size():
		return "City %d" % [index + 1]
	var names := config.city_names[player] as PackedStringArray
	if names.is_empty():
		return "City %d" % [index + 1]
	if index < names.size():
		return names[index]
	return "%s %d" % [names[names.size() - 1], index + 1]
