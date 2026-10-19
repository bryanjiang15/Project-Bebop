class_name GameConfig
extends RefCounted

## Typed load of config/game_config.json. A missing key or a wrong type
## prints an error and quits. There are no silent defaults.

const PATH := "res://config/game_config.json"

const LAND_IDS: PackedStringArray = ["plains", "forest", "hills", "water", "volcanic"]
const LAND_FIELDS: PackedStringArray = ["food", "production", "move_cost", "defense", "passable", "hazard_damage"]
const SPELL_IDS: PackedStringArray = ["grow_forest", "raise_hills", "carve_river", "ignite", "restore_plains"]
const SPELL_FIELDS: PackedStringArray = ["shape", "radius", "length", "mana", "range", "cooldown", "land"]
const UNIT_IDS: PackedStringArray = ["scout", "warrior", "archer", "settler"]
const UNIT_FIELDS: PackedStringArray = ["hp", "attack", "defense", "move", "cost", "range", "combatant", "population_cost", "min_city_size"]

var turn_limit: int
var player_count: int
var human_count: int
var ai_count: int
var starting_mana: int
var map_width: int
var map_height: int
var start_min_distance: int
var land_mix: Dictionary = {}
var lands: Dictionary = {}
var city_center_food: int
var city_center_production: int
var city_mana_base: int
var city_mana_per_population_divisor: int
var growth_base: int
var growth_per_population: int
var food_per_population: int
var border_start_radius: int
var border_turns_per_growth: int
var border_max_radius: int
var city_min_distance: int
var city_hp: int
var city_defense: int
var city_heal: int
var capture_population_loss: int
var capture_population_min: int
var capture_hp_fraction: float
var city_center_never_terraformed: bool
var city_heals_if_not_attacked: bool
var buildings_on_worked_tiles: bool
var one_building_per_tile: bool
var buildings_not_on_city_center: bool
var water_destroys_building: bool
var granary_food: int
var mana_well_mana: int
var lumber_mill_production_per_adjacent_forest: int
var granary_cost: int
var mana_well_cost: int
var lumber_mill_cost: int
var casts_per_turn: int
var spell_range_from: String
var line_length: int
var only_target_must_be_in_range: bool
var drop_off_map: bool
var spells_require_revealed_target: bool
var spells_change_tile_ownership: bool
var skip_water_if_land_unit_present: bool
var cooldown_uses_caster_turns: bool
var spells: Dictionary = {}
var one_military_and_one_civilian_per_tile: bool
var capture_lone_settler: bool
var spawn_on_city_center: bool
var spawn_nearest_free_if_blocked: bool
var unit_heal: int
var heal_only_if_idle: bool
var skip_enabled: bool
var fortify_enabled: bool
var fortify_defense_bonus: float
var end_turn_warns_if_unordered: bool
var units: Dictionary = {}
var combat_base_damage: int
var strength_exponent_base: float
var min_damage: int
var max_damage: int
var hp_reduces_strength: bool
var counter_uses_defender_strength: bool
var hills_defense_multiplier: float
var ranged_takes_no_counter: bool
var melee_captures_city: bool
var archers_can_zero_city_hp: bool
var unit_vision: int
var city_vision_beyond_border: int
var ai_obeys_fog: bool
var allow_enter_over_budget_if_mp_left: bool
var shortfall_drains_bar: bool
var starve_population_loss: int
var starve_population_min: int
var settler_population_taken_when_finished: bool
var volcanic_damage: int
var volcanic_flat: bool
var volcanic_can_kill: bool
var volcanic_timing: String
var score_per_tile: int
var score_per_city: int
var score_per_population: int
var tie_order: PackedStringArray = PackedStringArray()
var borders_can_claim_water: bool
var can_claim_owned_tiles: bool
var camera_min_zoom: float
var camera_max_zoom: float
var camera_zoom_step: float
var camera_pan_margin: float
var camera_key_pan_speed: float
var camera_default_zoom: float


class LandStats extends RefCounted:
	var food: int
	var production: int
	var move_cost: int
	var defense: float
	var passable: bool
	var hazard_damage: int

	func to_dict() -> Dictionary:
		return {
			"food": food,
			"production": production,
			"move_cost": move_cost,
			"defense": defense,
			"passable": passable,
			"hazard_damage": hazard_damage,
		}


class SpellStats extends RefCounted:
	var shape: String
	var radius: int
	var length: int
	var mana: int
	var range: int
	var cooldown: int
	var land: String

	func to_dict() -> Dictionary:
		return {
			"shape": shape,
			"radius": radius,
			"length": length,
			"mana": mana,
			"range": range,
			"cooldown": cooldown,
			"land": land,
		}


class UnitStats extends RefCounted:
	var hp: int
	var attack: int
	var defense: int
	var move: int
	var cost: int
	var range: int
	var combatant: bool
	var population_cost: int
	var min_city_size: int

	func to_dict() -> Dictionary:
		return {
			"hp": hp,
			"attack": attack,
			"defense": defense,
			"move": move,
			"cost": cost,
			"range": range,
			"combatant": combatant,
			"population_cost": population_cost,
			"min_city_size": min_city_size,
		}


static func load_file(path: String = PATH):
	return from_dict(read_json(path))


static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_fail("game_config.json missing file: %s" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		_fail("game_config.json is not a JSON object: %s" % path)
		return {}
	return parsed


static func from_dict(data: Dictionary):
	var missing := missing_paths(data)
	if not missing.is_empty():
		for path in missing:
			_fail("game_config.json missing key: %s" % path)
		_abort()
		return null
	var cfg = (load("res://scripts/core/game_config.gd") as GDScript).new()
	cfg._read(data)
	return cfg


static func missing_paths(data: Dictionary) -> PackedStringArray:
	var present := _leaf_paths(data)
	var missing := PackedStringArray()
	for path in required_paths():
		if not present.has(path):
			missing.append(path)
	return missing


static func required_paths() -> PackedStringArray:
	var paths := PackedStringArray([
		"turn_limit",
		"players.count",
		"players.human",
		"players.ai",
		"players.starting_mana",
		"map.width",
		"map.height",
		"map.start_min_distance",
	])
	for land_id in ["plains", "water", "forest", "hills", "volcanic"]:
		paths.append("map.land_mix." + land_id)
	for land_id in LAND_IDS:
		for field in LAND_FIELDS:
			paths.append("land.%s.%s" % [land_id, field])
	paths.append_array(PackedStringArray([
		"city.center_food",
		"city.center_production",
		"city.mana_base",
		"city.mana_per_population_divisor",
		"city.growth_base",
		"city.growth_per_population",
		"city.food_per_population",
		"city.border_start_radius",
		"city.border_turns_per_growth",
		"city.border_max_radius",
		"city.min_distance",
		"city.hp",
		"city.defense",
		"city.heal",
		"city.capture_population_loss",
		"city.capture_population_min",
		"city.capture_hp_fraction",
		"city.center_never_terraformed",
		"city.heals_if_not_attacked",
		"buildings.buildings_on_worked_tiles",
		"buildings.one_per_tile",
		"buildings.not_on_city_center",
		"buildings.water_destroys_building",
		"buildings.granary_food",
		"buildings.mana_well_mana",
		"buildings.lumber_mill_production_per_adjacent_forest",
		"buildings.costs.granary",
		"buildings.costs.mana_well",
		"buildings.costs.lumber_mill",
		"spells.casts_per_turn",
		"spells.range_from",
		"spells.line_length",
		"spells.only_target_must_be_in_range",
		"spells.drop_off_map",
		"spells.spells_require_revealed_target",
		"spells.spells_change_tile_ownership",
		"spells.skip_water_if_land_unit_present",
		"spells.cooldown_uses_caster_turns",
	]))
	for spell_id in SPELL_IDS:
		for field in SPELL_FIELDS:
			paths.append("spells.%s.%s" % [spell_id, field])
	paths.append_array(PackedStringArray([
		"units.one_military_and_one_civilian_per_tile",
		"units.capture_lone_settler",
		"units.spawn_on_city_center",
		"units.spawn_nearest_free_if_blocked",
		"units.heal",
		"units.heal_only_if_idle",
		"units.skip_enabled",
		"units.fortify_enabled",
		"units.fortify_defense_bonus",
		"units.end_turn_warns_if_unordered",
	]))
	for unit_id in UNIT_IDS:
		for field in UNIT_FIELDS:
			paths.append("units.%s.%s" % [unit_id, field])
	paths.append_array(PackedStringArray([
		"combat.base_damage",
		"combat.strength_exponent_base",
		"combat.min_damage",
		"combat.max_damage",
		"combat.hp_reduces_strength",
		"combat.counter_uses_defender_strength",
		"combat.hills_defense_multiplier",
		"combat.ranged_takes_no_counter",
		"combat.melee_captures_city",
		"combat.archers_can_zero_city_hp",
		"fog.unit_vision",
		"fog.city_vision_beyond_border",
		"fog.ai_obeys_fog",
		"movement.allow_enter_over_budget_if_mp_left",
		"growth.shortfall_drains_bar",
		"growth.starve_population_loss",
		"growth.starve_population_min",
		"growth.settler_population_taken_when_finished",
		"volcanic.damage",
		"volcanic.flat",
		"volcanic.can_kill",
		"volcanic.timing",
		"score.per_tile",
		"score.per_city",
		"score.per_population",
		"ties.order",
		"borders.can_claim_water",
		"borders.can_claim_owned_tiles",
		"camera.min_zoom",
		"camera.max_zoom",
		"camera.zoom_step",
		"camera.pan_margin",
		"camera.key_pan_speed",
		"camera.default_zoom",
	]))
	return paths


func land(id: String) -> LandStats:
	return lands[id]


func spell(id: String) -> SpellStats:
	return spells[id]


func unit(id: String) -> UnitStats:
	return units[id]


func to_dict() -> Dictionary:
	var mix := {}
	for land_id in ["plains", "water", "forest", "hills", "volcanic"]:
		mix[land_id] = land_mix[land_id]
	var land_out := {}
	for land_id in LAND_IDS:
		land_out[land_id] = (lands[land_id] as LandStats).to_dict()
	var spell_out := {
		"casts_per_turn": casts_per_turn,
		"range_from": spell_range_from,
		"line_length": line_length,
		"only_target_must_be_in_range": only_target_must_be_in_range,
		"drop_off_map": drop_off_map,
		"spells_require_revealed_target": spells_require_revealed_target,
		"spells_change_tile_ownership": spells_change_tile_ownership,
		"skip_water_if_land_unit_present": skip_water_if_land_unit_present,
		"cooldown_uses_caster_turns": cooldown_uses_caster_turns,
	}
	for spell_id in SPELL_IDS:
		spell_out[spell_id] = (spells[spell_id] as SpellStats).to_dict()
	var unit_out := {
		"one_military_and_one_civilian_per_tile": one_military_and_one_civilian_per_tile,
		"capture_lone_settler": capture_lone_settler,
		"spawn_on_city_center": spawn_on_city_center,
		"spawn_nearest_free_if_blocked": spawn_nearest_free_if_blocked,
		"heal": unit_heal,
		"heal_only_if_idle": heal_only_if_idle,
		"skip_enabled": skip_enabled,
		"fortify_enabled": fortify_enabled,
		"fortify_defense_bonus": fortify_defense_bonus,
		"end_turn_warns_if_unordered": end_turn_warns_if_unordered,
	}
	for unit_id in UNIT_IDS:
		unit_out[unit_id] = (units[unit_id] as UnitStats).to_dict()
	var order: Array = []
	for item in tie_order:
		order.append(item)
	return {
		"turn_limit": turn_limit,
		"players": {
			"count": player_count,
			"human": human_count,
			"ai": ai_count,
			"starting_mana": starting_mana,
		},
		"map": {
			"width": map_width,
			"height": map_height,
			"start_min_distance": start_min_distance,
			"land_mix": mix,
		},
		"land": land_out,
		"city": {
			"center_food": city_center_food,
			"center_production": city_center_production,
			"mana_base": city_mana_base,
			"mana_per_population_divisor": city_mana_per_population_divisor,
			"growth_base": growth_base,
			"growth_per_population": growth_per_population,
			"food_per_population": food_per_population,
			"border_start_radius": border_start_radius,
			"border_turns_per_growth": border_turns_per_growth,
			"border_max_radius": border_max_radius,
			"min_distance": city_min_distance,
			"hp": city_hp,
			"defense": city_defense,
			"heal": city_heal,
			"capture_population_loss": capture_population_loss,
			"capture_population_min": capture_population_min,
			"capture_hp_fraction": capture_hp_fraction,
			"center_never_terraformed": city_center_never_terraformed,
			"heals_if_not_attacked": city_heals_if_not_attacked,
		},
		"buildings": {
			"buildings_on_worked_tiles": buildings_on_worked_tiles,
			"one_per_tile": one_building_per_tile,
			"not_on_city_center": buildings_not_on_city_center,
			"water_destroys_building": water_destroys_building,
			"granary_food": granary_food,
			"mana_well_mana": mana_well_mana,
			"lumber_mill_production_per_adjacent_forest": lumber_mill_production_per_adjacent_forest,
			"costs": {
				"granary": granary_cost,
				"mana_well": mana_well_cost,
				"lumber_mill": lumber_mill_cost,
			},
		},
		"spells": spell_out,
		"units": unit_out,
		"combat": {
			"base_damage": combat_base_damage,
			"strength_exponent_base": strength_exponent_base,
			"min_damage": min_damage,
			"max_damage": max_damage,
			"hp_reduces_strength": hp_reduces_strength,
			"counter_uses_defender_strength": counter_uses_defender_strength,
			"hills_defense_multiplier": hills_defense_multiplier,
			"ranged_takes_no_counter": ranged_takes_no_counter,
			"melee_captures_city": melee_captures_city,
			"archers_can_zero_city_hp": archers_can_zero_city_hp,
		},
		"fog": {
			"unit_vision": unit_vision,
			"city_vision_beyond_border": city_vision_beyond_border,
			"ai_obeys_fog": ai_obeys_fog,
		},
		"movement": {
			"allow_enter_over_budget_if_mp_left": allow_enter_over_budget_if_mp_left,
		},
		"growth": {
			"shortfall_drains_bar": shortfall_drains_bar,
			"starve_population_loss": starve_population_loss,
			"starve_population_min": starve_population_min,
			"settler_population_taken_when_finished": settler_population_taken_when_finished,
		},
		"volcanic": {
			"damage": volcanic_damage,
			"flat": volcanic_flat,
			"can_kill": volcanic_can_kill,
			"timing": volcanic_timing,
		},
		"score": {
			"per_tile": score_per_tile,
			"per_city": score_per_city,
			"per_population": score_per_population,
		},
		"ties": {"order": order},
		"borders": {
			"can_claim_water": borders_can_claim_water,
			"can_claim_owned_tiles": can_claim_owned_tiles,
		},
		"camera": {
			"min_zoom": camera_min_zoom,
			"max_zoom": camera_max_zoom,
			"zoom_step": camera_zoom_step,
			"pan_margin": camera_pan_margin,
			"key_pan_speed": camera_key_pan_speed,
			"default_zoom": camera_default_zoom,
		},
	}


func _read(data: Dictionary) -> void:
	turn_limit = _int(data, "turn_limit")
	player_count = _int(data, "players.count")
	human_count = _int(data, "players.human")
	ai_count = _int(data, "players.ai")
	starting_mana = _int(data, "players.starting_mana")
	map_width = _int(data, "map.width")
	map_height = _int(data, "map.height")
	start_min_distance = _int(data, "map.start_min_distance")
	land_mix = {}
	for land_id in ["plains", "water", "forest", "hills", "volcanic"]:
		land_mix[land_id] = _float(data, "map.land_mix." + land_id)
	lands = {}
	for land_id in LAND_IDS:
		var stats := LandStats.new()
		var prefix := "land." + land_id
		stats.food = _int(data, prefix + ".food")
		stats.production = _int(data, prefix + ".production")
		stats.move_cost = _int(data, prefix + ".move_cost")
		stats.defense = _float(data, prefix + ".defense")
		stats.passable = _bool(data, prefix + ".passable")
		stats.hazard_damage = _int(data, prefix + ".hazard_damage")
		lands[land_id] = stats
	city_center_food = _int(data, "city.center_food")
	city_center_production = _int(data, "city.center_production")
	city_mana_base = _int(data, "city.mana_base")
	city_mana_per_population_divisor = _int(data, "city.mana_per_population_divisor")
	growth_base = _int(data, "city.growth_base")
	growth_per_population = _int(data, "city.growth_per_population")
	food_per_population = _int(data, "city.food_per_population")
	border_start_radius = _int(data, "city.border_start_radius")
	border_turns_per_growth = _int(data, "city.border_turns_per_growth")
	border_max_radius = _int(data, "city.border_max_radius")
	city_min_distance = _int(data, "city.min_distance")
	city_hp = _int(data, "city.hp")
	city_defense = _int(data, "city.defense")
	city_heal = _int(data, "city.heal")
	capture_population_loss = _int(data, "city.capture_population_loss")
	capture_population_min = _int(data, "city.capture_population_min")
	capture_hp_fraction = _float(data, "city.capture_hp_fraction")
	city_center_never_terraformed = _bool(data, "city.center_never_terraformed")
	city_heals_if_not_attacked = _bool(data, "city.heals_if_not_attacked")
	buildings_on_worked_tiles = _bool(data, "buildings.buildings_on_worked_tiles")
	one_building_per_tile = _bool(data, "buildings.one_per_tile")
	buildings_not_on_city_center = _bool(data, "buildings.not_on_city_center")
	water_destroys_building = _bool(data, "buildings.water_destroys_building")
	granary_food = _int(data, "buildings.granary_food")
	mana_well_mana = _int(data, "buildings.mana_well_mana")
	lumber_mill_production_per_adjacent_forest = _int(data, "buildings.lumber_mill_production_per_adjacent_forest")
	granary_cost = _int(data, "buildings.costs.granary")
	mana_well_cost = _int(data, "buildings.costs.mana_well")
	lumber_mill_cost = _int(data, "buildings.costs.lumber_mill")
	casts_per_turn = _int(data, "spells.casts_per_turn")
	spell_range_from = _string(data, "spells.range_from")
	line_length = _int(data, "spells.line_length")
	only_target_must_be_in_range = _bool(data, "spells.only_target_must_be_in_range")
	drop_off_map = _bool(data, "spells.drop_off_map")
	spells_require_revealed_target = _bool(data, "spells.spells_require_revealed_target")
	spells_change_tile_ownership = _bool(data, "spells.spells_change_tile_ownership")
	skip_water_if_land_unit_present = _bool(data, "spells.skip_water_if_land_unit_present")
	cooldown_uses_caster_turns = _bool(data, "spells.cooldown_uses_caster_turns")
	spells = {}
	for spell_id in SPELL_IDS:
		var spell_stats := SpellStats.new()
		var prefix := "spells." + spell_id
		spell_stats.shape = _string(data, prefix + ".shape")
		spell_stats.radius = _int(data, prefix + ".radius")
		spell_stats.length = _int(data, prefix + ".length")
		spell_stats.mana = _int(data, prefix + ".mana")
		spell_stats.range = _int(data, prefix + ".range")
		spell_stats.cooldown = _int(data, prefix + ".cooldown")
		spell_stats.land = _string(data, prefix + ".land")
		spells[spell_id] = spell_stats
	one_military_and_one_civilian_per_tile = _bool(data, "units.one_military_and_one_civilian_per_tile")
	capture_lone_settler = _bool(data, "units.capture_lone_settler")
	spawn_on_city_center = _bool(data, "units.spawn_on_city_center")
	spawn_nearest_free_if_blocked = _bool(data, "units.spawn_nearest_free_if_blocked")
	unit_heal = _int(data, "units.heal")
	heal_only_if_idle = _bool(data, "units.heal_only_if_idle")
	skip_enabled = _bool(data, "units.skip_enabled")
	fortify_enabled = _bool(data, "units.fortify_enabled")
	fortify_defense_bonus = _float(data, "units.fortify_defense_bonus")
	end_turn_warns_if_unordered = _bool(data, "units.end_turn_warns_if_unordered")
	units = {}
	for unit_id in UNIT_IDS:
		var unit_stats := UnitStats.new()
		var prefix := "units." + unit_id
		unit_stats.hp = _int(data, prefix + ".hp")
		unit_stats.attack = _int(data, prefix + ".attack")
		unit_stats.defense = _int(data, prefix + ".defense")
		unit_stats.move = _int(data, prefix + ".move")
		unit_stats.cost = _int(data, prefix + ".cost")
		unit_stats.range = _int(data, prefix + ".range")
		unit_stats.combatant = _bool(data, prefix + ".combatant")
		unit_stats.population_cost = _int(data, prefix + ".population_cost")
		unit_stats.min_city_size = _int(data, prefix + ".min_city_size")
		units[unit_id] = unit_stats
	combat_base_damage = _int(data, "combat.base_damage")
	strength_exponent_base = _float(data, "combat.strength_exponent_base")
	min_damage = _int(data, "combat.min_damage")
	max_damage = _int(data, "combat.max_damage")
	hp_reduces_strength = _bool(data, "combat.hp_reduces_strength")
	counter_uses_defender_strength = _bool(data, "combat.counter_uses_defender_strength")
	hills_defense_multiplier = _float(data, "combat.hills_defense_multiplier")
	ranged_takes_no_counter = _bool(data, "combat.ranged_takes_no_counter")
	melee_captures_city = _bool(data, "combat.melee_captures_city")
	archers_can_zero_city_hp = _bool(data, "combat.archers_can_zero_city_hp")
	unit_vision = _int(data, "fog.unit_vision")
	city_vision_beyond_border = _int(data, "fog.city_vision_beyond_border")
	ai_obeys_fog = _bool(data, "fog.ai_obeys_fog")
	allow_enter_over_budget_if_mp_left = _bool(data, "movement.allow_enter_over_budget_if_mp_left")
	shortfall_drains_bar = _bool(data, "growth.shortfall_drains_bar")
	starve_population_loss = _int(data, "growth.starve_population_loss")
	starve_population_min = _int(data, "growth.starve_population_min")
	settler_population_taken_when_finished = _bool(data, "growth.settler_population_taken_when_finished")
	volcanic_damage = _int(data, "volcanic.damage")
	volcanic_flat = _bool(data, "volcanic.flat")
	volcanic_can_kill = _bool(data, "volcanic.can_kill")
	volcanic_timing = _string(data, "volcanic.timing")
	score_per_tile = _int(data, "score.per_tile")
	score_per_city = _int(data, "score.per_city")
	score_per_population = _int(data, "score.per_population")
	tie_order = _strings(data, "ties.order")
	borders_can_claim_water = _bool(data, "borders.can_claim_water")
	can_claim_owned_tiles = _bool(data, "borders.can_claim_owned_tiles")
	camera_min_zoom = _float(data, "camera.min_zoom")
	camera_max_zoom = _float(data, "camera.max_zoom")
	camera_zoom_step = _float(data, "camera.zoom_step")
	camera_pan_margin = _float(data, "camera.pan_margin")
	camera_key_pan_speed = _float(data, "camera.key_pan_speed")
	camera_default_zoom = _float(data, "camera.default_zoom")


static func _leaf_paths(data: Dictionary, prefix: String = "") -> Dictionary:
	var found := {}
	var keys: Array = data.keys()
	for key in keys:
		var path := str(key) if prefix.is_empty() else "%s.%s" % [prefix, str(key)]
		var value: Variant = data[key]
		if value is Dictionary:
			var nested := _leaf_paths(value, path)
			for nested_path in nested.keys():
				found[nested_path] = true
		else:
			found[path] = true
	return found


static func _at(data: Dictionary, path: String) -> Variant:
	var current: Variant = data
	for part in path.split("."):
		if not (current is Dictionary) or not (current as Dictionary).has(part):
			_fail("game_config.json missing key: %s" % path)
			_abort()
			return null
		current = (current as Dictionary)[part]
	return current


static func _int(data: Dictionary, path: String) -> int:
	var value: Variant = _at(data, path)
	if value is int:
		return value
	if value is float and is_equal_approx(float(value), round(float(value))):
		return int(round(float(value)))
	_bad_type(path, "int", value)
	return 0


static func _float(data: Dictionary, path: String) -> float:
	var value: Variant = _at(data, path)
	if value is float or value is int:
		return float(value)
	_bad_type(path, "float", value)
	return 0.0


static func _bool(data: Dictionary, path: String) -> bool:
	var value: Variant = _at(data, path)
	if value is bool:
		return value
	_bad_type(path, "bool", value)
	return false


static func _string(data: Dictionary, path: String) -> String:
	var value: Variant = _at(data, path)
	if value is String:
		return value
	_bad_type(path, "string", value)
	return ""


static func _strings(data: Dictionary, path: String) -> PackedStringArray:
	var value: Variant = _at(data, path)
	var out := PackedStringArray()
	if not (value is Array):
		_bad_type(path, "string array", value)
		return out
	for item in value:
		if not (item is String):
			_bad_type(path, "string array", item)
			return PackedStringArray()
		out.append(item)
	return out


static func _bad_type(path: String, expected: String, value: Variant) -> void:
	_fail("game_config.json key %s expected %s, got %s" % [path, expected, type_string(typeof(value))])
	_abort()


static func _fail(message: String) -> void:
	push_error(message)


static func _abort() -> void:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		(loop as SceneTree).quit(1)
		return
	# --script SceneTree._init runs before the main loop is published, so quit
	# has to go through the process. A bad config must not keep running.
	OS.kill(OS.get_process_id())
