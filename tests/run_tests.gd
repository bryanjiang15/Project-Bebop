extends SceneTree

var _passed := 0
var _failed := 0

const LAND_MIX_TOLERANCE := 0.02


func _init() -> void:
	print("\n=== Project Bebop unit tests ===\n")
	_test_config()
	_test_hex_neighbors()
	_test_hex_distance()
	_test_hex_disk_and_ring()
	_test_hex_line()
	_test_axial_offset()
	_test_pixels()
	_test_map_and_fog()
	_test_pathfinding()
	_test_movement_and_fog()
	_test_found_city()
	_test_city_economy()
	_test_end_turn_key()
	print("\nPassed: %d  Failed: %d" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _ok(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  PASS ", message)
	else:
		_failed += 1
		print("  FAIL ", message)


func _test_config() -> void:
	print("[config]")
	var raw: Dictionary = GameConfig.read_json(GameConfig.PATH)
	var cfg: GameConfig = GameConfig.load_file()
	_ok(cfg != null, "config loads")
	if cfg == null:
		return
	var expected := _leaf_list(raw)
	var required := GameConfig.required_paths()
	_ok(_same_set(expected, required), "every config key is required by the loader (%d keys)" % expected.size())
	_ok(_values_match(cfg.to_dict(), raw), "every key round-trips through typed fields")
	_ok(cfg.turn_limit == 50, "turn limit 50")
	_ok(cfg.player_count == 3 and cfg.human_count == 1 and cfg.ai_count == 2, "3 players, 1 human, 2 AI")
	_ok(cfg.map_width == 28 and cfg.map_height == 18, "map 28x18")
	_ok(cfg.start_min_distance == 8, "starts at least 8 apart")
	_ok(is_equal_approx(float(cfg.land_mix["plains"]), 0.35), "plains mix 0.35")
	_ok(is_equal_approx(float(cfg.land_mix["water"]), 0.25), "water mix 0.25")
	_ok(is_equal_approx(float(cfg.land_mix["forest"]), 0.20), "forest mix 0.20")
	_ok(is_equal_approx(float(cfg.land_mix["hills"]), 0.15), "hills mix 0.15")
	_ok(is_equal_approx(float(cfg.land_mix["volcanic"]), 0.05), "volcanic mix 0.05")
	_ok(cfg.land("plains").food == 2 and cfg.land("plains").production == 0 and cfg.land("plains").move_cost == 1, "plains yields")
	_ok(cfg.land("forest").food == 1 and cfg.land("forest").production == 2 and cfg.land("forest").move_cost == 2, "forest yields")
	_ok(cfg.land("hills").move_cost == 2 and is_equal_approx(cfg.land("hills").defense, 0.25), "hills move and defense")
	_ok(not cfg.land("water").passable and cfg.land("water").move_cost == -1, "water impassable")
	_ok(cfg.land("volcanic").production == 3 and cfg.land("volcanic").hazard_damage == 10, "volcanic yield and hazard")
	_ok(cfg.city_center_food == 2 and cfg.city_center_production == 2, "city center yield")
	_ok(cfg.city_mana_base == 2 and cfg.city_mana_per_population_divisor == 2, "mana 2 + floor(pop/2)")
	_ok(cfg.starting_mana == 10, "starting mana 10")
	_ok(cfg.growth_base == 10 and cfg.growth_per_population == 6 and cfg.food_per_population == 2, "growth")
	_ok(cfg.border_start_radius == 1 and cfg.border_turns_per_growth == 4 and cfg.border_max_radius == 3, "borders")
	_ok(cfg.city_min_distance == 3, "city distance 3")
	_ok(cfg.unit("settler").cost == 40 and cfg.unit("scout").cost == 20 and cfg.unit("warrior").cost == 30 and cfg.unit("archer").cost == 45, "unit costs")
	_ok(cfg.granary_cost == 50 and cfg.mana_well_cost == 60 and cfg.lumber_mill_cost == 50, "building costs")
	_ok(cfg.granary_food == 2 and cfg.mana_well_mana == 2 and cfg.lumber_mill_production_per_adjacent_forest == 1, "building effects")
	_ok(cfg.spell("grow_forest").radius == 1 and cfg.spell("grow_forest").mana == 15 and cfg.spell("grow_forest").range == 3 and cfg.spell("grow_forest").cooldown == 2, "grow forest")
	_ok(cfg.spell("raise_hills").mana == 20 and cfg.spell("raise_hills").cooldown == 3, "raise hills")
	_ok(cfg.spell("carve_river").length == 4 and cfg.spell("carve_river").mana == 25 and cfg.line_length == 4, "carve river line of 4")
	_ok(cfg.spell("ignite").mana == 35 and cfg.spell("ignite").range == 2 and cfg.spell("ignite").cooldown == 5, "ignite")
	_ok(cfg.spell("restore_plains").mana == 10 and cfg.spell("restore_plains").land == "plains", "restore plains")
	_ok(cfg.casts_per_turn == 1 and cfg.spell_range_from == "owned_tile", "one cast from owned tiles")
	_ok(cfg.unit("scout").hp == 50 and cfg.unit("scout").attack == 5 and cfg.unit("scout").move == 3, "scout")
	_ok(cfg.unit("warrior").hp == 100 and cfg.unit("warrior").attack == 20 and cfg.unit("warrior").defense == 20, "warrior")
	_ok(cfg.unit("archer").attack == 25 and cfg.unit("archer").defense == 12 and cfg.unit("archer").range == 2, "archer")
	_ok(not cfg.unit("settler").combatant and cfg.unit("settler").population_cost == 1 and cfg.unit("settler").min_city_size == 2, "settler")
	_ok(cfg.combat_base_damage == 30 and is_equal_approx(cfg.strength_exponent_base, 1.04), "damage formula")
	_ok(cfg.min_damage == 5 and cfg.max_damage == 60, "damage clamp")
	_ok(not cfg.hp_reduces_strength and cfg.counter_uses_defender_strength, "strength rules")
	_ok(is_equal_approx(cfg.hills_defense_multiplier, 1.25), "hills multiply defense by 1.25")
	_ok(cfg.unit_heal == 10 and cfg.city_hp == 100 and cfg.city_defense == 15 and cfg.city_heal == 10, "healing and city combat")
	_ok(cfg.score_per_tile == 1 and cfg.score_per_city == 10 and cfg.score_per_population == 3, "score weights")
	_ok(cfg.buildings_on_worked_tiles and cfg.one_building_per_tile and cfg.buildings_not_on_city_center and cfg.water_destroys_building, "building flags")
	_ok(cfg.spells_require_revealed_target and not cfg.spells_change_tile_ownership, "spell flags")
	_ok(cfg.ai_obeys_fog and cfg.unit_vision == 2 and cfg.city_vision_beyond_border == 2, "fog")
	_ok(cfg.map_seed == 0, "seed 0 rolls a seed at new game")
	_ok(cfg.human_index == 0, "human index 0")
	_ok(cfg.starting_units.size() == 1 and cfg.starting_units[0] == "settler", "starting units are a settler")
	_ok(cfg.player_colors.size() == cfg.player_count, "one color per player")
	_ok(cfg.city_names.size() == cfg.player_count and not (cfg.city_names[0] as PackedStringArray).is_empty(), "one city-name list per player")
	_ok(cfg.start_quality_radius == 2 and cfg.start_quality_min == 10, "start land quality")
	_ok(cfg.fog_hidden.size() == 4 and cfg.fog_dim.size() == 4, "fog colors")
	_ok(cfg.allow_enter_over_budget_if_mp_left, "over-budget move")
	_ok(cfg.shortfall_drains_bar and cfg.starve_population_min == 1, "starvation")
	_ok(cfg.volcanic_flat and cfg.volcanic_damage == 10 and cfg.volcanic_can_kill and cfg.volcanic_timing == "end_of_owner_turn", "flat volcanic damage")
	_ok(cfg.borders_can_claim_water and not cfg.can_claim_owned_tiles, "border claim flags")
	_ok(cfg.skip_enabled and cfg.fortify_enabled and is_equal_approx(cfg.fortify_defense_bonus, 0.25), "skip and fortify")
	_ok(cfg.end_turn_warns_if_unordered, "end turn warning flag")
	_ok(cfg.tie_order.size() == 3 and cfg.tie_order[0] == "tiles" and cfg.tie_order[1] == "cities" and cfg.tie_order[2] == "human_loses", "tie break")
	_ok(is_equal_approx(cfg.capture_hp_fraction, 0.5) and cfg.capture_population_loss == 1, "capture resets")
	_ok(cfg.only_target_must_be_in_range and cfg.drop_off_map and cfg.city_center_never_terraformed, "line and terraforming limits")
	_ok(cfg.one_military_and_one_civilian_per_tile and cfg.capture_lone_settler, "stacking")
	_ok(cfg.spawn_on_city_center and cfg.spawn_nearest_free_if_blocked and cfg.heal_only_if_idle, "spawn and heal")
	_ok(cfg.settler_population_taken_when_finished, "settler pop cost timing")
	_ok(cfg.skip_water_if_land_unit_present and cfg.cooldown_uses_caster_turns, "water skip and cooldown")
	_ok(cfg.ranged_takes_no_counter and cfg.melee_captures_city and cfg.archers_can_zero_city_hp, "combat capture flags")
	_ok(is_equal_approx(cfg.camera_default_zoom, 0.36), "camera default zoom")
	var again: GameConfig = GameConfig.load_file()
	_ok(again != cfg and again.turn_limit == cfg.turn_limit and is_equal_approx(again.camera_default_zoom, cfg.camera_default_zoom), "load reads the file again")
	var broken: Dictionary = raw.duplicate(true)
	var spells: Dictionary = broken["spells"]
	spells.erase("casts_per_turn")
	broken["spells"] = spells
	var missing := GameConfig.missing_paths(broken)
	_ok(missing.has("spells.casts_per_turn"), "missing key is reported")


func _test_hex_neighbors() -> void:
	print("[neighbors]")
	_ok(Hex.DIRECTIONS.size() == 6, "six directions")
	var origin := Vector2i.ZERO
	var around := Hex.neighbors(origin)
	_ok(around.size() == 6, "six neighbors")
	var seen := {}
	for n in around:
		seen[n] = true
		_ok(Hex.distance(origin, n) == 1, "neighbor %s is distance 1" % n)
	_ok(seen.size() == 6, "neighbors are unique")
	_ok(Hex.neighbor(origin, Hex.EAST) == Vector2i(1, 0), "east")
	_ok(Hex.neighbor(origin, Hex.NORTHEAST) == Vector2i(1, -1), "northeast")
	_ok(Hex.neighbor(origin, Hex.NORTHWEST) == Vector2i(0, -1), "northwest")
	_ok(Hex.neighbor(origin, Hex.WEST) == Vector2i(-1, 0), "west")
	_ok(Hex.neighbor(origin, Hex.SOUTHWEST) == Vector2i(-1, 1), "southwest")
	_ok(Hex.neighbor(origin, Hex.SOUTHEAST) == Vector2i(0, 1), "southeast")
	_ok(Hex.neighbor(Hex.neighbor(origin, Hex.EAST), Hex.WEST) == origin, "east then west")


func _test_hex_distance() -> void:
	print("[distance]")
	_ok(Hex.distance(Vector2i.ZERO, Vector2i.ZERO) == 0, "distance to self")
	_ok(Hex.distance(Vector2i.ZERO, Vector2i(3, -1)) == 3, "distance 3")
	_ok(Hex.distance(Vector2i(2, 2), Vector2i(-1, 4)) == Hex.distance(Vector2i(-1, 4), Vector2i(2, 2)), "symmetric")
	_ok(Hex.distance(Vector2i(1, -2), Vector2i(1, -2)) == 0, "same hex")


func _test_hex_disk_and_ring() -> void:
	print("[disk and ring]")
	var center := Vector2i(4, -2)
	_ok(Hex.disk(center, 0).size() == 1, "radius 0 is the center")
	var one := Hex.disk(center, 1)
	_ok(one.size() == 7, "radius 1 is 7 tiles")
	_ok(one.has(center), "disk contains center")
	for n in Hex.neighbors(center):
		_ok(one.has(n), "disk contains neighbor %s" % n)
	_ok(Hex.disk(center, 2).size() == 19, "radius 2 is 19")
	_ok(Hex.ring(center, 0).size() == 1 and Hex.ring(center, 0)[0] == center, "ring 0")
	var ring1 := Hex.ring(center, 1)
	_ok(ring1.size() == 6, "ring 1 has 6")
	for hex in ring1:
		_ok(Hex.distance(center, hex) == 1, "ring 1 tile at distance 1")
	var ring2 := Hex.ring(center, 2)
	_ok(ring2.size() == 12, "ring 2 has 12")
	for hex in ring2:
		_ok(Hex.distance(center, hex) == 2, "ring 2 tile at distance 2")
	for radius in [0, 1, 2, 3]:
		for hex in Hex.disk(center, radius):
			if Hex.distance(center, hex) > radius:
				_ok(false, "disk leaked %s" % hex)
				return
	_ok(true, "disk radii stay inside the radius")


func _test_hex_line() -> void:
	print("[line]")
	var columns := 28
	var rows := 18
	var east := Hex.line(Vector2i.ZERO, Hex.EAST, 4, columns, rows)
	_ok(east.size() == 4, "line of 4 on the map")
	_ok(east[0] == Vector2i.ZERO and east[3] == Vector2i(3, 0), "line walks east from the target")
	_ok(Hex.line(Vector2i.ZERO, Hex.EAST, 1, columns, rows).size() == 1, "length 1 is the target")
	_ok(Hex.line(Vector2i.ZERO, Hex.EAST, 0, columns, rows).is_empty(), "length 0 is empty")
	var edge := Hex.offset_to_axial(Vector2i(26, 0))
	var clipped := Hex.line(edge, Hex.EAST, 4, columns, rows)
	_ok(clipped.size() == 2, "off-map tiles are dropped")
	_ok(clipped[0] == edge, "clipped line still starts at the target")
	var west_edge := Hex.line(Hex.offset_to_axial(Vector2i(0, 0)), Hex.WEST, 4, columns, rows)
	_ok(west_edge.size() == 1, "west off the map drops the rest")


func _test_axial_offset() -> void:
	print("[axial offset]")
	for row in range(-3, 21):
		for col in range(-3, 31):
			var cell := Vector2i(col, row)
			if Hex.axial_to_offset(Hex.offset_to_axial(cell)) != cell:
				_ok(false, "offset round trip %s" % cell)
				return
	_ok(true, "offset round trip across the map and a margin")
	_ok(Hex.in_map(Hex.offset_to_axial(Vector2i(0, 0)), 28, 18), "origin in map")
	_ok(Hex.in_map(Hex.offset_to_axial(Vector2i(27, 17)), 28, 18), "far corner in map")
	_ok(not Hex.in_map(Hex.offset_to_axial(Vector2i(-1, 0)), 28, 18), "outside column")
	_ok(not Hex.in_map(Hex.offset_to_axial(Vector2i(0, 18)), 28, 18), "outside row")


func _test_pixels() -> void:
	print("[pixels]")
	var tileset: TileSet = load("res://assets/art/bebop_tileset.tres")
	_ok(tileset != null, "art tileset loads")
	if tileset == null:
		return
	_ok(tileset.tile_shape == TileSet.TILE_SHAPE_HEXAGON, "hexagon shape")
	_ok(tileset.tile_layout == TileSet.TILE_LAYOUT_STACKED, "stacked layout")
	_ok(tileset.tile_offset_axis == TileSet.TILE_OFFSET_AXIS_HORIZONTAL, "pointy-top axis")
	_ok(tileset.tile_size == Vector2i(128, 108), "face size is 128x108")
	var terrain := tileset.get_source(0) as TileSetAtlasSource
	var highlight := tileset.get_source(1) as TileSetAtlasSource
	_ok(terrain != null and highlight != null, "terrain and highlight sources")
	if terrain == null or highlight == null:
		return
	_ok(terrain.texture.resource_path == "res://assets/art/tile_sheet.png", "terrain atlas is tile_sheet.png")
	_ok(terrain.texture.get_size() == Vector2(768, 116), "sheet is 768x116")
	_ok(terrain.texture_region_size == Vector2i(128, 116), "region is 128x116")
	_ok(terrain.margins == Vector2i.ZERO and terrain.separation == Vector2i.ZERO, "no margin or separation")
	var origin := Vector2i(0, -4)
	for i in 5:
		var data := terrain.get_tile_data(Vector2i(i, 0), 0)
		if data == null or data.texture_origin != origin:
			_ok(false, "terrain tile %d origin" % i)
			return
	_ok(true, "terrain texture_origin is (0, -4)")
	_ok(highlight.texture.resource_path == "res://assets/art/tile_highlight.png", "highlight is tile_highlight.png")
	_ok(highlight.texture_region_size == Vector2i(128, 116), "highlight region is 128x116")
	var highlight_data := highlight.get_tile_data(Vector2i.ZERO, 0)
	_ok(highlight_data != null and highlight_data.texture_origin == origin, "highlight texture_origin is (0, -4)")
	var size := Vector2(tileset.tile_size)
	var layer := TileMapLayer.new()
	layer.tile_set = tileset
	var centers_ok := true
	for row in 18:
		for col in 28:
			var cell := Vector2i(col, row)
			var center: Vector2 = layer.map_to_local(cell)
			if layer.local_to_map(center) != cell or Hex.pixel_to_offset(center, size) != cell:
				print("    center mismatch ", cell, " local_to_map ", layer.local_to_map(center), " hex ", Hex.pixel_to_offset(center, size))
				centers_ok = false
				break
			if Hex.offset_to_pixel(cell, size).distance_to(center) > 0.01:
				print("    hex_to_pixel mismatch ", cell)
				centers_ok = false
				break
			var axial := Hex.offset_to_axial(cell)
			if Hex.pixel_to_hex(Hex.hex_to_pixel(axial, size), size) != axial:
				print("    axial pixel round trip ", axial)
				centers_ok = false
				break
		if not centers_ok:
			break
	_ok(centers_ok, "every map center matches local_to_map")
	var grid_ok := true
	var max_x := tileset.tile_size.x * 30
	var max_y := int(float(tileset.tile_size.y) * 0.75 * 20.0) + tileset.tile_size.y
	for y in range(-16, max_y, 7):
		for x in range(-16, max_x, 7):
			var pixel := Vector2(float(x) + 0.5, float(y) + 0.5)
			var expected: Vector2i = layer.local_to_map(pixel)
			var got := Hex.pixel_to_offset(pixel, size)
			if got != expected:
				print("    grid mismatch ", pixel, " local_to_map ", expected, " hex ", got)
				grid_ok = false
				break
		if not grid_ok:
			break
	layer.free()
	_ok(grid_ok, "pixel_to_hex matches local_to_map on the art TileSet")


func _test_map_and_fog() -> void:
	print("[map and fog]")
	var cfg: GameConfig = GameConfig.load_file()
	var first := GameSetup.start_with_seed(cfg, 12345)
	var again := GameSetup.start_with_seed(cfg, 12345)
	var other := GameSetup.start_with_seed(cfg, 99991)
	_ok(first != null and again != null and other != null, "seeds build a game")
	if first == null or again == null or other == null:
		return
	_ok(_same_setup(first, again), "same seed -> identical map and starts")
	_ok(first.map.lands != other.map.lands, "different seed -> different map")
	_ok(first.seed_used == 12345, "seed 12345 places starts on the first map (%d)" % first.seed_used)
	var counts := {"plains": 0, "forest": 0, "hills": 0, "water": 0, "volcanic": 0}
	for land_id in first.map.lands:
		counts[land_id] = int(counts[land_id]) + 1
	var total := float(cfg.map_width * cfg.map_height)
	for land_id in GameConfig.LAND_IDS:
		_ok(int(counts[land_id]) > 0, "default config contains %s" % land_id)
		var share := float(counts[land_id]) / total
		var target := float(cfg.land_mix[land_id])
		_ok(absf(share - target) <= LAND_MIX_TOLERANCE, "%s mix %.3f within %.2f of %.2f" % [land_id, share, LAND_MIX_TOLERANCE, target])
	_ok(first.players.size() == 3 and first.unit_total() == 3, "exactly 3 players and 3 settlers")
	_ok(first.players[0].units[0].mp == cfg.unit(first.players[0].units[0].unit_type).move, "starting units begin with full movement")
	for player in first.players:
		_ok(player.units.size() == cfg.starting_units.size(), "player %d spawned the starting unit list" % player.index)
		for i in player.units.size():
			var unit := player.units[i]
			_ok(unit.unit_type == cfg.starting_units[i], "player %d unit %d is %s" % [player.index, i, cfg.starting_units[i]])
			_ok(first.map.is_passable(unit.cell, cfg), "start %s is passable land" % unit.cell)
			var quality := first.map.passable_count(unit.cell, cfg.start_quality_radius, cfg)
			_ok(quality >= cfg.start_quality_min, "start %s quality %d" % [unit.cell, quality])
		if player.index == cfg.human_index:
			_ok(player.human, "human index is the human")
		else:
			_ok(not player.human, "player %d is a rival" % player.index)
	for a in first.players.size():
		for b in range(a + 1, first.players.size()):
			var dist := Hex.distance(Hex.offset_to_axial(first.players[a].units[0].cell), Hex.offset_to_axial(first.players[b].units[0].cell))
			_ok(dist >= cfg.start_min_distance, "starts %d and %d are %d apart" % [a, b, dist])
	for player in first.players:
		var origin := Hex.offset_to_axial(player.units[0].cell)
		for row in first.map.height:
			for col in first.map.width:
				var cell := Vector2i(col, row)
				var dist := Hex.distance(origin, Hex.offset_to_axial(cell))
				var state := first.fog.sight(player.index, cell)
				if dist <= cfg.unit_vision:
					if state != FogState.Sight.VISIBLE:
						_ok(false, "player %d should see %s" % [player.index, cell])
						return
				elif state != FogState.Sight.UNREVEALED:
					_ok(false, "player %d should not have seen %s" % [player.index, cell])
					return
	_ok(true, "opening vision matches each settler disk")
	for player in first.players:
		if player.index == first.human_index:
			continue
		var rival_cell := player.units[0].cell
		var dist := Hex.distance(Hex.offset_to_axial(first.human_settler_cell()), Hex.offset_to_axial(rival_cell))
		var visible := first.fog.unit_visible(first.human_index, rival_cell)
		_ok(visible == (dist <= cfg.unit_vision), "rival settler visibility follows vision (dist %d)" % dist)
	_test_fog_memory()
	var all_seeds := true
	for seed_value in range(1, 31):
		var game := GameSetup.start_with_seed(cfg, seed_value)
		if game == null or game.players.size() != cfg.player_count or game.unit_total() != cfg.player_count:
			print("    seed failed ", seed_value)
			all_seeds = false
			break
	_ok(all_seeds, "seeds 1..30 all find fair starts")


func _test_fog_memory() -> void:
	var fog := FogState.new()
	fog.resize(10, 8, 2)
	var origin := Vector2i(4, 4)
	var near := Vector2i(5, 4)
	var far := Vector2i(9, 4)
	fog.compute_initial([{"player": 0, "cell": origin, "radius": 2}])
	_ok(fog.sight(0, near) == FogState.Sight.VISIBLE, "tile in radius is visible")
	_ok(fog.sight(0, far) == FogState.Sight.UNREVEALED, "tile outside radius is unrevealed")
	_ok(fog.unit_visible(0, near) and not fog.unit_visible(0, far), "a unit is hidden unless its tile is visible")
	_ok(fog.sight(1, origin) == FogState.Sight.UNREVEALED, "the other player's fog stays unrevealed")
	fog.recompute([{"player": 0, "cell": far, "radius": 2}])
	_ok(fog.sight(0, origin) == FogState.Sight.REVEALED, "leaving a tile keeps it revealed")
	_ok(fog.sight(0, far) == FogState.Sight.VISIBLE, "the new tile is visible")
	_ok(fog.unit_visible(0, far) and not fog.unit_visible(0, origin), "a rival is visible only while in vision")


func _blank_setup(fill: String = "plains") -> GameSetup:
	var cfg: GameConfig = GameConfig.load_file()
	var map := MapState.create(cfg.map_width, cfg.map_height)
	for row in map.height:
		for col in map.width:
			map.set_land(Vector2i(col, row), fill)
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
		game.players.append(player)
	return game


func _step(cell: Vector2i, direction: int, steps: int) -> Vector2i:
	var axial := Hex.offset_to_axial(cell)
	for _i in steps:
		axial = Hex.neighbor(axial, direction)
	return Hex.axial_to_offset(axial)


func _test_pathfinding() -> void:
	print("[pathfinding]")
	var origin := Vector2i(8, 8)
	var neighbor := _step(origin, Hex.EAST, 1)
	var two := _step(origin, Hex.EAST, 2)
	var three := _step(origin, Hex.EAST, 3)
	var game := _blank_setup("forest")
	var settler := game.spawn_unit(0, "settler", origin)
	var reach := game.reachable_tiles(settler)
	_ok(game.config.land("forest").move_cost * 2 > settler.mp, "two forests exceed settler movement")
	_ok(reach.has(neighbor) and int(reach[neighbor]) == settler.mp - game.config.land("forest").move_cost, "forest spends its move cost")
	_ok(not reach.has(two), "cannot walk two forests when no points remain")
	game = _blank_setup("plains")
	settler = game.spawn_unit(0, "settler", origin)
	reach = game.reachable_tiles(settler)
	_ok(reach.has(two) and int(reach[two]) == settler.mp - game.config.land("plains").move_cost * 2, "two plains fit in settler movement")
	_ok(not reach.has(three), "three plains do not fit in settler movement")
	game.map.set_land(neighbor, "water")
	reach = game.reachable_tiles(settler)
	_ok(not reach.has(neighbor), "water is impassable")
	_ok(not game.move_unit(settler, neighbor), "move rejects water")
	game = _blank_setup("forest")
	game.map.set_land(origin, "plains")
	settler = game.spawn_unit(0, "settler", origin)
	_ok(game.config.land("forest").move_cost > 1, "forest costs more than one point")
	settler.mp = 1
	reach = game.reachable_tiles(settler)
	_ok(reach.has(neighbor) and int(reach[neighbor]) == 0, "over-budget forest entry ends the move")
	_ok(not reach.has(two), "no step after an over-budget entry")
	game.config.allow_enter_over_budget_if_mp_left = false
	reach = game.reachable_tiles(settler)
	_ok(not reach.has(neighbor), "over-budget entry follows the config flag")
	game = _blank_setup()
	var scout := game.spawn_unit(0, "scout", origin)
	var far := _step(origin, Hex.EAST, game.config.unit("scout").move)
	var too_far := _step(origin, Hex.EAST, game.config.unit("scout").move + 1)
	reach = game.reachable_tiles(scout)
	_ok(reach.has(far) and not reach.has(too_far), "scout walks its own movement points")
	var civilian := game.spawn_unit(0, "settler", origin)
	var other := game.spawn_unit(0, "settler", neighbor)
	_ok(civilian != null and other != null, "two settlers on different tiles")
	_ok(not game.reachable_tiles(civilian).has(other.cell), "one civilian per tile")
	_ok(game.spawn_unit(0, "settler", other.cell) == null, "spawn rejects a second civilian")
	_ok(game.spawn_unit(0, "warrior", other.cell) != null, "one military unit may share a civilian's tile")
	_ok(game.spawn_unit(0, "scout", other.cell) == null, "one military unit per tile")
	var enemy := game.spawn_unit(1, "warrior", _step(origin, Hex.WEST, 1))
	_ok(enemy != null and not game.reachable_tiles(civilian).has(enemy.cell), "cannot enter another player's unit")
	_ok(game.spawn_unit(0, "boat", origin) == null, "unknown unit type is rejected")


func _test_movement_and_fog() -> void:
	print("[movement and fog]")
	var game := _blank_setup()
	var origin := Vector2i(6, 6)
	var unit := game.spawn_unit(0, "settler", origin)
	var seen := _step(origin, Hex.WEST, game.config.unit_vision)
	_ok(game.fog.sight(0, seen) == FogState.Sight.VISIBLE, "unit vision reaches its radius")
	_ok(game.fog.sight(0, _step(origin, Hex.WEST, game.config.unit_vision + 1)) == FogState.Sight.UNREVEALED, "unit vision stops at its radius")
	var dest := _step(origin, Hex.EAST, 1)
	_ok(game.move_unit(unit, dest), "moves east")
	_ok(unit.cell == dest, "unit arrives")
	_ok(unit.mp == game.config.unit("settler").move - game.config.land("plains").move_cost, "plains cost is spent")
	_ok(game.fog.sight(0, seen) == FogState.Sight.REVEALED, "left-behind tiles stay revealed and leave vision")
	var ahead := _step(dest, Hex.EAST, game.config.unit_vision)
	_ok(game.fog.sight(0, ahead) == FogState.Sight.VISIBLE, "the move reveals new tiles")
	game.end_turn()
	_ok(game.turn == 2, "end turn advances the turn")
	_ok(unit.mp == game.config.unit("settler").move, "end turn resets movement")


func _test_found_city() -> void:
	print("[found city]")
	var game := _blank_setup()
	var origin := Vector2i(10, 8)
	var unit := game.spawn_unit(0, "settler", origin)
	var edge_distance := game.config.border_start_radius + game.config.city_vision_beyond_border
	var edge := _step(origin, Hex.EAST, edge_distance)
	var beyond := _step(origin, Hex.EAST, edge_distance + 1)
	_ok(game.fog.sight(0, edge) == FogState.Sight.UNREVEALED, "the settler does not see the future city ring")
	var city := game.found_city(unit)
	_ok(city != null and game.players[0].units.is_empty(), "founding consumes the settler")
	_ok(city.player == 0 and city.population == 1 and city.cell == origin, "city owner, population, and tile")
	_ok(city.radius == game.config.border_start_radius, "territory radius is the founding radius")
	_ok(city.city_name == str((game.config.city_names[0] as PackedStringArray)[0]), "name comes from the player's list")
	_ok(game.territory_cells(city).size() == Hex.disk(Hex.offset_to_axial(origin), city.radius).size(), "claims the whole founding disk")
	_ok(game.owner_at(_step(origin, Hex.EAST, city.radius + 1)) == -1, "territory stops at the founding radius")
	_ok(game.fog.sight(0, edge) == FogState.Sight.VISIBLE, "city vision reveals territory plus the extra radius")
	_ok(game.fog.sight(0, beyond) == FogState.Sight.UNREVEALED, "city vision stops at territory plus radius")
	game = _blank_setup()
	game.config.unit_vision = 1
	origin = Vector2i(8, 8)
	var rival := game.spawn_unit(1, "settler", origin)
	var rival_city := game.found_city(rival)
	var hidden := _step(origin, Hex.EAST, 2)
	_ok(rival_city != null and Hex.distance(Hex.offset_to_axial(origin), Hex.offset_to_axial(hidden)) == 2, "rival city sits two tiles away")
	var human := game.spawn_unit(0, "settler", hidden)
	_ok(game.fog.sight(0, origin) == FogState.Sight.UNREVEALED, "rival city is under fog")
	_ok(game.can_found(human) == GameSetup.REASON_DISTANCE, "distance rejects a fogged city inside 3")
	_ok(game.found_city(human) == null and game.players[0].units.size() == 1, "rejected founding keeps the settler")
	game = _blank_setup()
	origin = Vector2i(8, 8)
	game.found_city(game.spawn_unit(1, "settler", origin))
	var spot := _step(origin, Hex.EAST, game.config.city_min_distance)
	_ok(Hex.distance(Hex.offset_to_axial(origin), Hex.offset_to_axial(spot)) == 3, "spot is exactly the minimum distance")
	human = game.spawn_unit(0, "settler", spot)
	_ok(game.can_found(human).is_empty(), "distance 3 is allowed")
	var second := game.found_city(human)
	_ok(second != null and second.city_name == str((game.config.city_names[0] as PackedStringArray)[0]), "a first city uses the player's first name")
	game = _blank_setup()
	var water_at := Vector2i(4, 4)
	game.map.set_land(water_at, "water")
	human = game.spawn_unit(0, "settler", Vector2i(5, 4))
	human.cell = water_at
	_ok(game.can_found(human) == GameSetup.REASON_WATER, "cannot found on water")
	_ok(game.spawn_unit(0, "settler", water_at) == null, "cannot spawn a settler on water")
	game = _blank_setup()
	game.config.city_min_distance = 1
	origin = Vector2i(8, 8)
	game.found_city(game.spawn_unit(1, "settler", origin))
	var owned := _step(origin, Hex.EAST, 1)
	_ok(game.owner_at(owned) == 1, "rival founding claims the neighbor")
	human = game.spawn_unit(0, "settler", owned)
	_ok(game.can_found(human) == GameSetup.REASON_OWNED, "cannot found on a rival-owned tile")
	game = _blank_setup()
	game.config.borders_can_claim_water = false
	origin = Vector2i(8, 8)
	var shore := _step(origin, Hex.EAST, 1)
	game.map.set_land(shore, "water")
	city = game.found_city(game.spawn_unit(0, "settler", origin))
	_ok(city != null and game.owner_at(shore) == -1 and game.owner_at(origin) == 0, "water claim follows the config flag")
	game = _blank_setup()
	game.config.city_names[0] = PackedStringArray(["Only"])
	var first := game.found_city(game.spawn_unit(0, "settler", Vector2i(2, 2)))
	var later := game.found_city(game.spawn_unit(0, "settler", _step(Vector2i(2, 2), Hex.EAST, game.config.city_min_distance)))
	_ok(first.city_name == "Only" and later.city_name == "Only 2", "names past the list stay unique")


func _test_city_economy() -> void:
	print("[city economy]")
	var cfg: GameConfig = GameConfig.load_file()
	for land_id in GameConfig.LAND_IDS:
		if land_id == "water":
			continue
		var game := _blank_setup(land_id)
		var city := game.found_city(game.spawn_unit(0, "settler", Vector2i(8, 8)))
		var land: GameConfig.LandStats = cfg.land(land_id)
		var y: Dictionary = game.city_yields(city)
		var worked: Array = y["worked"]
		_ok(worked.size() == 1 and not worked.has(city.cell), "%s works one tile besides the center" % land_id)
		_ok(int(y["food"]) == land.food * 2 + cfg.city_center_food, "%s food includes the center and one tile" % land_id)
		_ok(int(y["production"]) == land.production * 2 + cfg.city_center_production, "%s production includes the center and one tile" % land_id)
		city.population = 0
		y = game.city_yields(city)
		_ok((y["worked"] as Array).is_empty(), "%s center is not a worked citizen tile" % land_id)
		_ok(int(y["food"]) == land.food + cfg.city_center_food, "%s center food" % land_id)
		_ok(int(y["production"]) == land.production + cfg.city_center_production, "%s center production" % land_id)
	var water_game := _blank_setup("plains")
	var water_city := water_game.found_city(water_game.spawn_unit(0, "settler", Vector2i(8, 8)))
	for axial in Hex.neighbors(Hex.offset_to_axial(water_city.cell)):
		water_game.map.set_land(Hex.axial_to_offset(axial), "water")
	var water_yield: Dictionary = water_game.city_yields(water_city)
	_ok((water_yield["worked"] as Array)[0] == Vector2i(7, 8), "tied tiles break toward smaller q, then smaller r")
	_ok(int(water_yield["food"]) == cfg.land("plains").food + cfg.city_center_food + cfg.land("water").food, "water yield is worked")
	_ok(int(water_yield["production"]) == cfg.city_center_production, "water adds no production")
	var tie := _blank_setup("hills")
	var tie_city := tie.found_city(tie.spawn_unit(0, "settler", Vector2i(8, 8)))
	tie.map.set_land(Vector2i(9, 8), "volcanic")
	tie.map.set_land(Vector2i(7, 8), "forest")
	var tie_yield: Dictionary = tie.city_yields(tie_city)
	_ok((tie_yield["worked"] as Array)[0] == Vector2i(7, 8), "equal food+production prefers the higher food")
	tie_city.population = 2
	tie_yield = tie.city_yields(tie_city)
	var both: Array = tie_yield["worked"]
	_ok(both.size() == 2 and both[0] == Vector2i(7, 8) and both.has(Vector2i(9, 8)), "the next citizen takes the next tile")
	tie_city.population = 9
	_ok((tie.city_yields(tie_city)["worked"] as Array).size() == 6, "worked tiles stop at the owned ring")
	tie_city.population = 1
	_ok(int(tie.city_yields(tie_city)["mana"]) == cfg.city_mana_base, "mana at population 1")
	tie_city.population = 2
	_ok(int(tie.city_yields(tie_city)["mana"]) == cfg.city_mana_base + 1, "mana gains floor(pop/2)")
	tie_city.population = 5
	_ok(int(tie.city_yields(tie_city)["mana"]) == cfg.city_mana_base + 2, "mana at population 5")
	var growth := _blank_setup("plains")
	var growing := growth.found_city(growth.spawn_unit(0, "settler", Vector2i(8, 8)))
	for _i in 3:
		growth.end_turn()
	_ok(growing.population == 1 and growing.food_stored == 12, "surplus fills the growth bar")
	growth.end_turn()
	_ok(growing.population == 2 and growing.food_stored == 0, "a full bar grows and keeps the remainder")
	var chain := _blank_setup("plains")
	var chained := chain.found_city(chain.spawn_unit(0, "settler", Vector2i(8, 8)))
	chain.config.growth_base = 2
	chain.config.growth_per_population = 0
	chain.end_turn()
	_ok(chained.population == 3 and chained.food_stored == 0, "leftover food fills the next threshold")
	var starve := _blank_setup("volcanic")
	var hungry := starve.found_city(starve.spawn_unit(0, "settler", Vector2i(8, 8)))
	hungry.population = 3
	hungry.food_stored = 5
	starve.end_turn()
	_ok(hungry.population == 3 and hungry.food_stored == 1, "a shortfall that stays non-negative keeps the population")
	hungry.food_stored = 0
	starve.end_turn()
	_ok(hungry.population == 2 and hungry.food_stored == 0, "an empty bar loses one population")
	hungry.population = 1
	hungry.food_stored = 0
	starve.config.food_per_population = 10
	starve.end_turn()
	_ok(hungry.population == 1 and hungry.food_stored == 0, "starvation stops at the minimum")
	starve.config.shortfall_drains_bar = false
	hungry.population = 3
	hungry.food_stored = 4
	starve.end_turn()
	_ok(hungry.population == 3 and hungry.food_stored == 4, "the shortfall flag can leave the bar alone")
	var borders := _blank_setup("plains")
	var origin := Vector2i(10, 8)
	var home := borders.found_city(borders.spawn_unit(0, "settler", origin))
	var best := _step(origin, Hex.EAST, 2)
	borders.map.set_land(best, "volcanic")
	var owned_before := borders.territory_cells(home).size()
	for _i in 3:
		borders.end_turn()
	_ok(borders.owner_at(best) == -1 and borders.turns_until_border(home) == 1, "the border clock waits out the interval")
	borders.end_turn()
	_ok(borders.territory_cells(home).has(best) and home.radius == 2, "the best yield is claimed and the radius grows")
	_ok(borders.territory_cells(home).size() == owned_before + 1, "one tile is claimed")
	_ok(borders.owner_at(_step(origin, Hex.WEST, 2)) == -1, "a weaker tile waits")
	var seen := _step(origin, Hex.EAST, home.radius + borders.config.city_vision_beyond_border)
	_ok(borders.fog.sight(0, seen) == FogState.Sight.VISIBLE, "city vision follows the new radius")
	var capped := _blank_setup("plains")
	capped.config.border_max_radius = 1
	var capped_city := capped.found_city(capped.spawn_unit(0, "settler", origin))
	var capped_size := capped.territory_cells(capped_city).size()
	for _i in 8:
		capped.end_turn()
	_ok(capped.territory_cells(capped_city).size() == capped_size and capped.turns_until_border(capped_city) == -1, "max radius claims nothing further")
	var crowded := _blank_setup("plains")
	var human_city := crowded.found_city(crowded.spawn_unit(0, "settler", origin))
	var wanted := _step(origin, Hex.EAST, 2)
	crowded.map.set_land(wanted, "volcanic")
	var rival_city := crowded.found_city(crowded.spawn_unit(1, "settler", _step(origin, Hex.EAST, 3)))
	_ok(rival_city != null and crowded.owner_at(wanted) == 1, "a rival already owns the best tile")
	var human_before := crowded.territory_cells(human_city).size()
	for _i in 4:
		crowded.end_turn()
	_ok(crowded.owner_at(wanted) == 1, "borders do not take an owned tile")
	_ok(crowded.territory_cells(human_city).size() == human_before + 1, "the next best free tile is claimed")
	var shore_game := _blank_setup("plains")
	shore_game.config.borders_can_claim_water = false
	shore_game.config.border_max_radius = 1
	shore_game.config.border_turns_per_growth = 1
	var shore_origin := Vector2i(8, 8)
	var shore := _step(shore_origin, Hex.EAST, 1)
	shore_game.map.set_land(shore, "water")
	var shore_city := shore_game.found_city(shore_game.spawn_unit(0, "settler", shore_origin))
	_ok(shore_game.owner_at(shore) == -1, "founding left the water unclaimed")
	shore_game.end_turn()
	_ok(shore_game.owner_at(shore) == -1, "water is skipped while claiming it is off")
	shore_game.config.borders_can_claim_water = true
	shore_game.end_turn()
	_ok(shore_game.territory_cells(shore_city).has(shore), "water is claimed when the flag allows it")
	var queue := _blank_setup("plains")
	var producer := queue.found_city(queue.spawn_unit(0, "settler", Vector2i(8, 8)))
	queue.config.unit("scout").cost = 4
	queue.config.unit("warrior").cost = 30
	_ok(queue.enqueue(producer, "nope") == GameSetup.REASON_UNKNOWN, "unknown items are rejected")
	_ok(queue.enqueue(producer, "scout").is_empty() and queue.enqueue(producer, "warrior").is_empty(), "units enqueue")
	queue.end_turn()
	_ok(producer.queue.size() == 2 and producer.queue[0].item_id == "scout" and producer.production_stored == 2, "production stays on the first item")
	queue.move_queue(producer, 1, -1)
	_ok(producer.queue[0].item_id == "warrior" and producer.production_stored == 2, "reorder keeps stored production on the new head")
	queue.move_queue(producer, 0, 1)
	_ok(producer.queue[0].item_id == "scout", "reorder puts the scout back at the head")
	queue.end_turn()
	_ok(producer.queue.size() == 1 and producer.queue[0].item_id == "warrior" and producer.production_stored == 0, "a finished item advances the queue")
	_ok(_count_units(queue, 0, "scout") == 1 and queue.players[0].units[0].cell == producer.cell, "the scout spawns on the city center")
	queue.end_turn()
	_ok(producer.production_stored == 2, "the next item receives the next turn's production")
	queue.cancel_queue(producer, 0)
	_ok(producer.queue.is_empty() and producer.production_stored == 0, "cancelling the head drops its progress")
	queue.end_turn()
	_ok(producer.production_stored == 0, "an empty queue banks nothing")
	var burst := _blank_setup("volcanic")
	var factory := burst.found_city(burst.spawn_unit(0, "settler", Vector2i(8, 8)))
	burst.config.unit("scout").cost = 4
	burst.config.unit("warrior").cost = 4
	burst.enqueue(factory, "scout")
	burst.enqueue(factory, "warrior")
	burst.end_turn()
	_ok(factory.queue.is_empty() and factory.production_stored == 0, "overflow finishes the next item in the same turn")
	_ok(_count_units(burst, 0, "scout") == 1 and _count_units(burst, 0, "warrior") == 1, "both units spawn")
	var settler_game := _blank_setup("plains")
	var nursery := settler_game.found_city(settler_game.spawn_unit(0, "settler", Vector2i(8, 8)))
	var too_small := settler_game.enqueue(nursery, "settler")
	_ok(too_small == "City must be size %d+" % settler_game.config.unit("settler").min_city_size and nursery.queue.is_empty(), "a size 1 city cannot train a settler")
	nursery.population = 2
	settler_game.config.unit("settler").cost = 2
	_ok(settler_game.enqueue(nursery, "settler").is_empty(), "size 2 can train a settler")
	settler_game.end_turn()
	_ok(nursery.population == 1 and _count_units(settler_game, 0, "settler") == 1, "finishing a settler spends one population and spawns")
	_ok(settler_game.players[0].units[0].cell == nursery.cell, "the new settler uses the open center")
	var blocked := _blank_setup("plains")
	var camp := blocked.found_city(blocked.spawn_unit(0, "settler", Vector2i(8, 8)))
	camp.population = 2
	blocked.spawn_unit(0, "settler", camp.cell)
	blocked.config.unit("settler").cost = 2
	blocked.enqueue(camp, "settler")
	blocked.end_turn()
	_ok(camp.population == 1 and _count_units(blocked, 0, "settler") == 2, "a blocked center still trains the settler")
	var arrived := Vector2i.ZERO
	for unit in blocked.players[0].units:
		if unit.cell != camp.cell:
			arrived = unit.cell
	_ok(arrived == Vector2i(7, 8), "the settler takes the nearest free border tile")
	blocked.config.spawn_nearest_free_if_blocked = false
	camp.population = 2
	blocked.config.unit("settler").cost = 2
	blocked.enqueue(camp, "settler")
	blocked.end_turn()
	_ok(camp.queue.size() == 1 and camp.population == 2 and _count_units(blocked, 0, "settler") == 2, "with no free-tile fallback the settler waits")
	var built := _blank_setup("plains")
	var site := Vector2i(8, 8)
	var town := built.found_city(built.spawn_unit(0, "settler", site))
	var plot := _step(site, Hex.EAST, 1)
	var far := _step(site, Hex.EAST, 3)
	_ok(built.placement_reason(town, "granary", town.cell) == GameSetup.REASON_CENTER, "cannot build on the city center")
	_ok(built.placement_reason(town, "granary", far) == GameSetup.REASON_BORDERS, "cannot build outside the borders")
	_ok(built.placement_reason(town, "granary", Vector2i(-1, -1)) == GameSetup.REASON_BUILD_OFF_MAP, "cannot build off the map")
	_ok(built.enqueue(town, "granary", plot).is_empty(), "granary enqueues on a border tile")
	_ok(built.enqueue(town, "mana_well", plot) == GameSetup.REASON_OCCUPIED, "a queued building reserves its tile")
	built.config.granary_cost = 2
	var food_before := int(built.city_yields(town)["food"])
	built.end_turn()
	_ok(town.buildings.size() == 1 and town.buildings[0].kind == "granary" and town.buildings[0].cell == plot, "granary finishes on that tile")
	_ok(int(built.city_yields(town)["food"]) == food_before + built.config.granary_food, "granary adds its food to the city")
	_ok(built.placement_reason(town, "granary", plot) == GameSetup.REASON_OCCUPIED, "a finished building keeps the tile")
	var second := _step(site, Hex.WEST, 1)
	built.enqueue(town, "granary", second)
	built.end_turn()
	_ok(town.buildings.size() == 2 and int(built.city_yields(town)["food"]) == food_before + built.config.granary_food * 2, "a second granary stacks")
	var wells := _blank_setup("plains")
	var well_city := wells.found_city(wells.spawn_unit(0, "settler", site))
	var mana_before := int(wells.city_yields(well_city)["mana"])
	wells.config.mana_well_cost = 2
	wells.enqueue(well_city, "mana_well", _step(site, Hex.EAST, 1))
	wells.end_turn()
	_ok(int(wells.city_yields(well_city)["mana"]) == mana_before + wells.config.mana_well_mana, "mana well adds city mana")
	var mills := _blank_setup("plains")
	var mill_city := mills.found_city(mills.spawn_unit(0, "settler", site))
	var mill_at := _step(site, Hex.EAST, 1)
	mills.map.set_land(mill_at, "forest")
	var quiet := int(mills.city_yields(mill_city)["production"])
	mills.config.lumber_mill_cost = 2
	mills.enqueue(mill_city, "lumber_mill", mill_at)
	mills.end_turn()
	_ok(int(mills.city_yields(mill_city)["production"]) == quiet, "a mill ignores forest on its own tile")
	var bare := _blank_setup("plains")
	var bare_city := bare.found_city(bare.spawn_unit(0, "settler", site))
	var bare_mill := _step(site, Hex.EAST, 1)
	for direction in [Hex.EAST, Hex.NORTHEAST, Hex.SOUTHEAST]:
		bare.map.set_land(_step(bare_mill, direction, 1), "forest")
	var bare_prod := int(bare.city_yields(bare_city)["production"])
	bare.config.lumber_mill_cost = 2
	bare.enqueue(bare_city, "lumber_mill", bare_mill)
	bare.end_turn()
	var bonus := bare.config.lumber_mill_production_per_adjacent_forest * 3
	_ok(int(bare.city_yields(bare_city)["production"]) == bare_prod + bonus, "lumber mill adds one production per adjacent forest")


func _count_units(game: GameSetup, player: int, type: String) -> int:
	var count := 0
	for unit in game.players[player].units:
		if unit.unit_type == type:
			count += 1
	return count


func _test_end_turn_key() -> void:
	print("[end turn key]")
	_ok(InputMap.has_action("end_turn"), "end_turn action exists")
	var bound := false
	for event in InputMap.action_get_events("end_turn"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ENTER:
			bound = true
	_ok(bound, "Enter is bound to end_turn")


func _same_setup(a: GameSetup, b: GameSetup) -> bool:
	if a.seed_used != b.seed_used or a.map.lands != b.map.lands or a.players.size() != b.players.size():
		return false
	for i in a.players.size():
		var left: Array = a.players[i].units
		var right: Array = b.players[i].units
		if left.size() != right.size():
			return false
		for j in left.size():
			if left[j].cell != right[j].cell or left[j].unit_type != right[j].unit_type:
				return false
		for row in a.map.height:
			for col in a.map.width:
				var cell := Vector2i(col, row)
				if a.fog.sight(i, cell) != b.fog.sight(i, cell):
					return false
	return true


func _leaf_list(data: Dictionary, prefix: String = "") -> PackedStringArray:
	var out := PackedStringArray()
	for key in data.keys():
		var path := str(key) if prefix.is_empty() else "%s.%s" % [prefix, str(key)]
		var value: Variant = data[key]
		if value is Dictionary:
			out.append_array(_leaf_list(value, path))
		else:
			out.append(path)
	return out


func _same_set(a: PackedStringArray, b: PackedStringArray) -> bool:
	if a.size() != b.size():
		print("    path count ", a.size(), " vs ", b.size())
		return false
	var have := {}
	for path in a:
		have[path] = true
	for path in b:
		if not have.has(path):
			print("    missing from json or extra required: ", path)
			return false
	return true


func _values_match(actual: Variant, expected: Variant) -> bool:
	if actual is Dictionary and expected is Dictionary:
		if actual.size() != expected.size():
			print("    dict size ", actual.keys(), " vs ", expected.keys())
			return false
		for key in expected.keys():
			if not actual.has(key) or not _values_match(actual[key], expected[key]):
				print("    mismatch at ", key)
				return false
		return true
	if actual is Array and expected is Array:
		if actual.size() != expected.size():
			return false
		for i in actual.size():
			if not _values_match(actual[i], expected[i]):
				return false
		return true
	if (actual is int or actual is float) and (expected is int or expected is float):
		return is_equal_approx(float(actual), float(expected))
	return actual == expected
