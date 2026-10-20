class_name GameSetup
extends RefCounted

## One new game: map, players, starting units, and the opening fog.
## map.seed 0 rolls a non-zero seed. The seed that built the map is printed
## as "map seed: N". Writing N back into map.seed replays that map and those starts.
## A failed placement retries with a derived seed, up to generation_attempts.

var seed_used: int
var map: MapState
var players: Array[PlayerState] = []
var fog: FogState
var human_index: int


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
	setup.seed_used = seed_value
	setup.map = map
	setup.human_index = cfg.human_index
	for index in cfg.player_count:
		var player := PlayerState.new()
		player.index = index
		player.human = index == cfg.human_index
		player.color = cfg.player_colors[index]
		for unit_type in cfg.starting_units:
			var unit := PlayerState.UnitState.new()
			unit.unit_type = unit_type
			unit.cell = starts[index]
			unit.owner = index
			player.units.append(unit)
		setup.players.append(player)
	setup.fog = FogState.new()
	setup.fog.resize(map.width, map.height, cfg.player_count)
	# No cities yet. A later ticket adds a source per city with radius
	# border_radius + city_vision_beyond_border.
	setup.fog.compute_initial(_unit_sources(setup, cfg.unit_vision))
	return setup


static func _unit_sources(setup: GameSetup, radius: int) -> Array:
	var sources: Array = []
	for player in setup.players:
		for unit in player.units:
			sources.append({
				"player": player.index,
				"cell": unit.cell,
				"radius": radius,
			})
	return sources


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
