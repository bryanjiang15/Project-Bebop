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

var config: GameConfig
var seed_used: int
var turn: int = 1
var map: MapState
var players: Array[PlayerState] = []
var cities: Array[MapCity] = []
var fog: FogState
var human_index: int
var _owners: Dictionary = {}
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
	turn += 1
	for player in players:
		for unit in player.units:
			unit.mp = config.unit(unit.unit_type).move


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
	for hex in Hex.disk(Hex.offset_to_axial(city.cell), city.radius):
		var cell := Hex.axial_to_offset(hex)
		if owner_at(cell) == city.player:
			out.append(cell)
	return out


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
		var cell := Hex.axial_to_offset(hex)
		if not map.in_bounds(cell):
			continue
		if _owners.has(cell) and not config.can_claim_owned_tiles:
			continue
		if map.land_at(cell) == "water" and not config.borders_can_claim_water:
			continue
		_owners[cell] = city.player


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
