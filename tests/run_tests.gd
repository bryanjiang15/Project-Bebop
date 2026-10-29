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
	_test_mana_pool()
	_test_combat()
	_test_city_capture()
	_test_spells()
	_test_rival_land_updates()
	_test_land_effects()
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
	_ok(cfg.spell("grow_forest").spell_name == "Grow Forest" and cfg.spell("grow_forest").radius == 1 and cfg.spell("grow_forest").mana == 15 and cfg.spell("grow_forest").range == 3 and cfg.spell("grow_forest").cooldown == 2, "grow forest")
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
	_ok(cfg.starting_units.size() == 2 and cfg.starting_units[0] == "settler" and cfg.starting_units[1] == "warrior", "starting units are settler then warrior")
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
	_ok(is_equal_approx(cfg.capture_hp_fraction, 0.5) and cfg.capture_population_loss == 1 and cfg.capture_population_min == 1, "capture resets")
	_ok(cfg.city_heals_if_not_attacked, "a city heals only when it was not attacked")
	_ok(cfg.unit("warrior").can_capture and not cfg.unit("scout").can_capture and not cfg.unit("archer").can_capture and not cfg.unit("settler").can_capture, "only a warrior can capture a city")
	_ok(cfg.only_target_must_be_in_range and cfg.drop_off_map and cfg.city_center_never_terraformed, "line and terraforming limits")
	_ok(cfg.one_unit_per_tile and cfg.capture_lone_settler, "one unit per tile")
	_ok(cfg.spawn_on_city_center and cfg.spawn_nearest_free_if_blocked and cfg.heal_only_if_idle, "spawn and heal")
	_ok(cfg.settler_population_taken_when_finished, "settler pop cost timing")
	_ok(cfg.skip_water_if_land_unit_present and cfg.cooldown_uses_caster_turns, "water skip and cooldown")
	_ok(cfg.ranged_takes_no_counter and cfg.melee_captures_city and cfg.archers_can_zero_city_hp, "combat capture flags")
	_ok(is_equal_approx(cfg.camera_default_zoom, 0.72), "camera default zoom")
	var again: GameConfig = GameConfig.load_file()
	_ok(again != cfg and again.turn_limit == cfg.turn_limit and is_equal_approx(again.camera_default_zoom, cfg.camera_default_zoom), "load reads the file again")
	var broken: Dictionary = raw.duplicate(true)
	var spells: Dictionary = broken["spells"]
	spells.erase("casts_per_turn")
	broken["spells"] = spells
	var missing := GameConfig.missing_paths(broken)
	_ok(missing.has("spells.casts_per_turn"), "missing key is reported")
	var spell_broken: Dictionary = raw.duplicate(true)
	var grow: Dictionary = (spell_broken["spells"] as Dictionary)["grow_forest"]
	grow.erase("mana")
	_ok(GameConfig.missing_paths(spell_broken).has("spells.grow_forest.mana"), "missing spell cost is reported")
	var capture_broken: Dictionary = raw.duplicate(true)
	var warrior_stats: Dictionary = (capture_broken["units"] as Dictionary)["warrior"]
	warrior_stats.erase("can_capture")
	_ok(GameConfig.missing_paths(capture_broken).has("units.warrior.can_capture"), "missing can_capture is reported")


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
	_ok(first.players.size() == 3 and first.unit_total() == cfg.player_count * cfg.starting_units.size(), "3 players each spawn the starting roster")
	_ok(first.players[0].units[0].mp == cfg.unit(first.players[0].units[0].unit_type).move, "starting units begin with full movement")
	for player in first.players:
		_ok(player.units.size() == cfg.starting_units.size(), "player %d spawned the starting unit list" % player.index)
		var occupied := {}
		for i in player.units.size():
			var unit := player.units[i]
			_ok(unit.unit_type == cfg.starting_units[i], "player %d unit %d is %s" % [player.index, i, cfg.starting_units[i]])
			_ok(first.map.is_passable(unit.cell, cfg), "start %s is passable land" % unit.cell)
			_ok(not occupied.has(unit.cell), "player %d keeps one unit on %s" % [player.index, unit.cell])
			occupied[unit.cell] = true
		var anchor := player.units[0].cell
		var quality := first.map.passable_count(anchor, cfg.start_quality_radius, cfg)
		_ok(quality >= cfg.start_quality_min, "start %s quality %d" % [anchor, quality])
		_ok(player.units.size() >= 2 and player.units[0].cell != player.units[1].cell, "player %d warrior stands on its own tile" % player.index)
		_ok(_is_nearest_open(first, player.units[0].cell, player.units[1].cell), "player %d warrior takes the nearest free tile" % player.index)
		_ok(player.units[1].hp == cfg.unit("warrior").hp and player.units[1].max_hp == cfg.unit("warrior").hp, "player %d warrior starts at full HP" % player.index)
		if player.index == cfg.human_index:
			_ok(player.human, "human index is the human")
		else:
			_ok(not player.human, "player %d is a rival" % player.index)
	for a in first.players.size():
		for b in range(a + 1, first.players.size()):
			var dist := Hex.distance(Hex.offset_to_axial(first.players[a].units[0].cell), Hex.offset_to_axial(first.players[b].units[0].cell))
			_ok(dist >= cfg.start_min_distance, "starts %d and %d are %d apart" % [a, b, dist])
	for player in first.players:
		var origins: Array[Vector2i] = []
		for unit in player.units:
			origins.append(Hex.offset_to_axial(unit.cell))
		for row in first.map.height:
			for col in first.map.width:
				var cell := Vector2i(col, row)
				var dist := 999999
				var axial := Hex.offset_to_axial(cell)
				for origin in origins:
					dist = mini(dist, Hex.distance(origin, axial))
				var state := first.fog.sight(player.index, cell)
				if dist <= cfg.unit_vision:
					if state != FogState.Sight.VISIBLE:
						_ok(false, "player %d should see %s" % [player.index, cell])
						return
				elif state != FogState.Sight.UNREVEALED:
					_ok(false, "player %d should not have seen %s" % [player.index, cell])
					return
	_ok(true, "opening vision matches each starting unit")
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
		if game == null or game.players.size() != cfg.player_count or game.unit_total() != cfg.player_count * cfg.starting_units.size():
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
		player.mana = cfg.starting_mana
		game.players.append(player)
	return game


func _step(cell: Vector2i, direction: int, steps: int) -> Vector2i:
	var axial := Hex.offset_to_axial(cell)
	for _i in steps:
		axial = Hex.neighbor(axial, direction)
	return Hex.axial_to_offset(axial)


func _is_nearest_open(game: GameSetup, anchor: Vector2i, chosen: Vector2i) -> bool:
	if chosen == anchor or not game.map.is_passable(chosen, game.config):
		return false
	var taken := {}
	for player in game.players:
		for unit in player.units:
			if unit.cell != chosen:
				taken[unit.cell] = true
	for row in game.map.height:
		for col in game.map.width:
			var cell := Vector2i(col, row)
			if cell == chosen or taken.has(cell) or not game.map.is_passable(cell, game.config):
				continue
			if CityRules.prefer_near(cell, chosen, anchor):
				return false
	return true


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
	var civilian := game.spawn_unit(0, "settler", _step(origin, Hex.NORTHEAST, 1))
	var other := game.spawn_unit(0, "settler", neighbor)
	_ok(civilian != null and other != null, "two settlers on different tiles")
	_ok(not game.reachable_tiles(civilian).has(other.cell), "one unit per tile")
	_ok(game.spawn_unit(0, "settler", other.cell) == null, "spawn rejects a second unit")
	_ok(game.spawn_unit(0, "warrior", other.cell) == null, "a combatant cannot share a tile")
	_ok(game.spawn_unit(0, "scout", other.cell) == null, "a second combatant is rejected")
	var enemy := game.spawn_unit(1, "warrior", _step(origin, Hex.WEST, 1))
	_ok(enemy != null and not game.reachable_tiles(civilian).has(enemy.cell), "cannot enter another player's unit")
	game.config.one_unit_per_tile = false
	_ok(game.spawn_unit(0, "warrior", other.cell) != null, "friendly stacking follows the config flag")
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


func _test_mana_pool() -> void:
	print("[mana pool]")
	var fresh := _blank_setup()
	_ok(fresh.config.starting_mana == 10, "config starting mana is 10")
	for player in fresh.players:
		_ok(player.mana == 10, "player %d starts at 10 mana" % player.index)
		_ok(fresh.mana_per_turn(player.index) == 0, "player %d gains 0 with no cities" % player.index)
	for _i in 3:
		fresh.end_turn()
	for player in fresh.players:
		_ok(player.mana == 10, "player %d stays at 10 with no cities" % player.index)
	var tuned_start: GameConfig = GameConfig.load_file()
	tuned_start.starting_mana = 21
	var started := GameSetup.start_with_seed(tuned_start, 12345)
	_ok(started != null, "tuned starting mana still builds a game")
	if started != null:
		for player in started.players:
			_ok(player.mana == 21, "player %d uses the tuned starting mana" % player.index)
	var rates: Array[int] = [2, 3, 3, 4]
	var rated := _blank_setup()
	var rated_city := rated.found_city(rated.spawn_unit(0, "settler", Vector2i(8, 8)))
	for pop in [1, 2, 3, 4]:
		rated_city.population = pop
		var got := CityRules.city_mana(rated.config, rated_city)
		_ok(got == rates[pop - 1], "mana at population %d is %d" % [pop, rates[pop - 1]])
		_ok(int(rated.city_yields(rated_city)["mana"]) == got, "yields mana matches city_mana at pop %d" % pop)
		_ok(rated.mana_per_turn(0) == got, "one city is the whole per-turn gain at pop %d" % pop)
	var site := Vector2i(8, 8)
	var east := _step(site, Hex.EAST, 1)
	var west := _step(site, Hex.WEST, 1)
	_place_building(rated_city, "mana_well", east)
	_ok(CityRules.city_mana(rated.config, rated_city) == 6, "one mana well adds +2 at population 4")
	_place_building(rated_city, "mana_well", west)
	_ok(CityRules.city_mana(rated.config, rated_city) == 8, "two mana wells add +4")
	rated_city.buildings.pop_back()
	_ok(CityRules.city_mana(rated.config, rated_city) == 6, "removing a well drops the live rate")
	rated_city.buildings.clear()
	rated_city.population = 1
	var second := rated.found_city(rated.spawn_unit(0, "settler", _step(site, Hex.EAST, rated.config.city_min_distance)))
	_ok(second != null, "a second city founds for the sum")
	if second != null:
		second.population = 3
		_ok(rated.mana_per_turn(0) == 2 + 3, "two cities sum their mana")
		rated.config.growth_base = 1000
		var pooled := rated.players[0].mana
		rated.end_turn()
		_ok(rated.players[0].mana == pooled + 5, "one end turn adds the summed snapshot")
		_ok(rated.players[1].mana == 10 and rated.players[2].mana == 10, "rivals with no cities stay at 10")
	var banked := _blank_setup()
	banked.config.growth_base = 1000
	var home := banked.found_city(banked.spawn_unit(0, "settler", site))
	var away := banked.found_city(banked.spawn_unit(1, "settler", _step(site, Hex.EAST, banked.config.city_min_distance)))
	_ok(home != null and away != null, "human and rival cities founded")
	if home == null or away == null:
		return
	home.population = 4
	away.population = 2
	banked.end_turn()
	_ok(banked.players[0].mana == 10 + 4, "the human pool gains its own cities")
	_ok(banked.players[1].mana == 10 + 3, "a rival pool gains its own cities")
	_ok(banked.players[2].mana == 10, "a player with no city gains 0")
	_ok(banked.mana_per_turn(0) == 4 and banked.mana_per_turn(1) == 3, "live rates stay with the current population")
	for _i in 3:
		banked.end_turn()
	_ok(banked.players[0].mana == 10 + 4 * 4, "the pool accumulates over several end turns")
	_ok(banked.players[1].mana == 10 + 3 * 4, "the rival pool accumulates on the same clock")
	var wells := _blank_setup()
	wells.config.growth_base = 1000
	wells.config.mana_well_cost = 2
	var well_city := wells.found_city(wells.spawn_unit(0, "settler", site))
	var plot := _step(site, Hex.EAST, 1)
	_ok(wells.enqueue(well_city, "mana_well", plot).is_empty(), "mana well queues for the timing test")
	var paid := CityRules.city_mana(wells.config, well_city)
	wells.end_turn()
	_ok(well_city.buildings.size() == 1 and well_city.buildings[0].kind == "mana_well", "the well finishes this turn")
	_ok(wells.players[0].mana == 10 + paid, "a well finished this turn is not paid until the next end turn")
	_ok(wells.mana_per_turn(0) == paid + wells.config.mana_well_mana, "the live rate includes the new well immediately")
	wells.end_turn()
	_ok(wells.players[0].mana == 10 + paid + paid + wells.config.mana_well_mana, "the next end turn pays the well")
	var other := _step(site, Hex.WEST, 1)
	wells.enqueue(well_city, "mana_well", other)
	wells.end_turn()
	_ok(well_city.buildings.size() == 2, "a second well finishes")
	_ok(wells.mana_per_turn(0) == paid + wells.config.mana_well_mana * 2, "two finished wells add +4")
	var grown := _blank_setup()
	grown.config.growth_base = 1
	grown.config.growth_per_population = 0
	var growing := grown.found_city(grown.spawn_unit(0, "settler", site))
	var before_growth := CityRules.city_mana(grown.config, growing)
	grown.end_turn()
	_ok(growing.population > 1, "the city grows during the turn")
	_ok(grown.players[0].mana == 10 + before_growth, "mana paid this turn uses the pre-growth population")
	_ok(grown.mana_per_turn(0) == CityRules.city_mana(grown.config, growing), "the rate after the turn uses the new population")
	var custom := _blank_setup()
	custom.config.growth_base = 1000
	custom.config.city_mana_base = 9
	custom.config.city_mana_per_population_divisor = 3
	custom.config.mana_well_mana = 5
	var custom_city := custom.found_city(custom.spawn_unit(0, "settler", site))
	custom_city.population = 4
	_ok(CityRules.city_mana(custom.config, custom_city) == 10, "tuned base and divisor change the rate")
	_place_building(custom_city, "mana_well", _step(site, Hex.EAST, 1))
	_ok(custom.mana_per_turn(0) == 15, "tuned well bonus changes the rate")
	var saved := custom.players[0].mana
	custom.end_turn()
	_ok(custom.players[0].mana == saved + 15, "end turn pays the tuned rate")
	var raw: Dictionary = GameConfig.read_json(GameConfig.PATH)
	var missing_base: Dictionary = raw.duplicate(true)
	var city_block: Dictionary = missing_base["city"]
	city_block.erase("mana_base")
	_ok(GameConfig.missing_paths(missing_base).has("city.mana_base"), "missing city.mana_base is reported")
	var missing_div: Dictionary = raw.duplicate(true)
	(missing_div["city"] as Dictionary).erase("mana_per_population_divisor")
	_ok(GameConfig.missing_paths(missing_div).has("city.mana_per_population_divisor"), "missing mana divisor is reported")
	var missing_well: Dictionary = raw.duplicate(true)
	(missing_well["buildings"] as Dictionary).erase("mana_well_mana")
	_ok(GameConfig.missing_paths(missing_well).has("buildings.mana_well_mana"), "missing mana well bonus is reported")
	var missing_start: Dictionary = raw.duplicate(true)
	(missing_start["players"] as Dictionary).erase("starting_mana")
	_ok(GameConfig.missing_paths(missing_start).has("players.starting_mana"), "missing starting mana is reported")


func _place_building(city: MapCity, kind: String, cell: Vector2i) -> void:
	var building := MapCity.Building.new()
	building.kind = kind
	building.cell = cell
	city.buildings.append(building)


func _count_units(game: GameSetup, player: int, type: String) -> int:
	var count := 0
	for unit in game.players[player].units:
		if unit.unit_type == type:
			count += 1
	return count


func _test_combat() -> void:
	print("[combat]")
	var cfg: GameConfig = GameConfig.load_file()
	_ok(Combat.damage(cfg, 20.0, 20.0) == 30, "equal strength deals 30")
	_ok(Combat.damage(cfg, 0.0, 100.0) == 5, "damage clamps to 5")
	_ok(Combat.damage(cfg, 100.0, 0.0) == 60, "damage clamps to 60")
	_ok(Combat.damage(cfg, 5.0, 20.0) == 17, "scout strength into a warrior is 17")
	_ok(Combat.damage(cfg, 20.0, 5.0) == 54, "warrior strength into a scout is 54")
	var game := _blank_setup("plains")
	var origin := Vector2i(8, 8)
	var neighbor := _step(origin, Hex.EAST, 1)
	var attacker := game.spawn_unit(0, "warrior", origin)
	var defender := game.spawn_unit(1, "warrior", neighbor)
	var even := game.preview_attack(attacker, defender)
	_ok(bool(even["ok"]) and int(even["damage"]) == 30 and int(even["counter"]) == 30, "melee mirror is 30 and 30")
	attacker.hp = 10
	var wounded := game.preview_attack(attacker, defender)
	_ok(int(wounded["damage"]) == 30 and int(wounded["counter"]) == 30, "HP does not change strength")
	attacker.hp = 100
	game.map.set_land(neighbor, "hills")
	var hills := game.preview_attack(attacker, defender)
	_ok(int(hills["damage"]) == 25 and int(hills["counter"]) == 36, "hills multiply defender strength by 1.25")
	game.config.hills_defense_multiplier = 1.0
	var flat_hills := game.preview_attack(attacker, defender)
	_ok(int(flat_hills["damage"]) == 30 and int(flat_hills["counter"]) == 30, "hills bonus follows the config multiplier")
	game.config.hills_defense_multiplier = 1.25
	game.map.set_land(neighbor, "plains")
	defender.fortified = true
	var fort := game.preview_attack(attacker, defender)
	_ok(int(fort["damage"]) == 25 and int(fort["counter"]) == 36, "fortify adds 25 percent defense")
	game.map.set_land(neighbor, "hills")
	var both := game.preview_attack(attacker, defender)
	_ok(int(both["damage"]) == 19 and int(both["counter"]) == 47, "hills and fortify stack")
	game.config.fortify_defense_bonus = 0.0
	var no_fort := game.preview_attack(attacker, defender)
	_ok(int(no_fort["damage"]) == 25 and int(no_fort["counter"]) == 36, "fortify bonus follows the config")
	game.config.fortify_defense_bonus = 0.25
	defender.fortified = false
	game.map.set_land(neighbor, "plains")
	var archer := game.spawn_unit(0, "archer", _step(origin, Hex.WEST, 2))
	var shot := game.preview_attack(archer, defender)
	_ok(not bool(shot["ok"]) and str(shot["reason"]) == GameSetup.REASON_RANGE, "archer at distance 3 is out of range")
	var range_tile := _step(neighbor, Hex.EAST, 2)
	archer.cell = range_tile
	game._refresh_fog()
	shot = game.preview_attack(archer, defender)
	_ok(Hex.distance(Hex.offset_to_axial(archer.cell), Hex.offset_to_axial(defender.cell)) == 2, "archer stands at distance 2")
	_ok(bool(shot["ok"]) and int(shot["damage"]) == 36 and int(shot["counter"]) == 0, "archer at range 2 deals 36 and takes no counter")
	var beside := _step(neighbor, Hex.NORTHEAST, 1)
	archer.cell = beside
	game._refresh_fog()
	var adjacent_shot := game.preview_attack(archer, defender)
	_ok(Hex.distance(Hex.offset_to_axial(archer.cell), Hex.offset_to_axial(defender.cell)) == 1, "archer stands next to the defender")
	_ok(bool(adjacent_shot["ok"]) and int(adjacent_shot["counter"]) == 0, "an adjacent archer shot is still ranged")
	var before_archer := archer.hp
	_ok(game.attack_unit(archer, defender).is_empty(), "ranged attack resolves")
	_ok(archer.hp == before_archer and defender.hp == 100 - 36 and archer.mp == 0, "ranged attack spends movement and skips counter")
	_ok(archer.cell == beside, "a ranged attacker stays on its tile")
	_ok(game.attack_unit(archer, defender) == GameSetup.REASON_NO_MOVES, "a unit with no moves cannot attack")
	defender.hp = 100
	var foe := game.spawn_unit(1, "archer", _step(origin, Hex.NORTHWEST, 1))
	var melee_archer := game.preview_attack(attacker, foe)
	_ok(int(melee_archer["damage"]) == 41 and int(melee_archer["counter"]) == 22, "a melee hit uses the archer's defense of 12")
	var scout := game.spawn_unit(1, "scout", _step(origin, Hex.WEST, 2))
	var two := game.preview_attack(attacker, scout)
	_ok(not bool(two["ok"]), "a warrior cannot melee at distance 2")
	var own := game.spawn_unit(0, "scout", _step(origin, Hex.SOUTHEAST, 1))
	_ok(game.can_attack(attacker, own) == GameSetup.REASON_OWN_UNIT, "cannot attack your own unit")
	var hidden := game.spawn_unit(1, "warrior", _step(origin, Hex.SOUTHEAST, 8))
	_ok(game.can_attack(attacker, hidden) == GameSetup.REASON_UNSEEN, "cannot attack a unit outside vision")
	var settler := game.spawn_unit(1, "settler", _step(origin, Hex.NORTHEAST, 1))
	var settler_mp := attacker.mp
	_ok(game.can_attack(attacker, settler) == GameSetup.REASON_ATTACK_SETTLER, "cannot attack a settler")
	_ok(game.attack_unit(attacker, settler) == GameSetup.REASON_ATTACK_SETTLER and attacker.mp == settler_mp, "a rejected settler attack spends nothing")
	_ok(game.players[1].units.has(settler), "the settler stays on the map")
	defender.hp = 5
	var defender_cell := defender.cell
	var attacker_cell := attacker.cell
	_ok(game.attack_unit(attacker, defender).is_empty(), "a killing melee attack resolves")
	_ok(not game.players[1].units.has(defender), "a unit at 0 HP is removed")
	_ok(attacker.cell == attacker_cell and attacker.cell != defender_cell, "a melee attacker does not advance")
	_ok(attacker.hp == 70 and attacker.mp == 0 and attacker.acted, "counter damage lands and the attack spends the turn")
	attacker.hp = 5
	attacker.mp = 2
	var rival := game.spawn_unit(1, "warrior", defender_cell)
	rival.hp = 5
	_ok(game.attack_unit(attacker, rival).is_empty(), "mutual kill resolves")
	_ok(not game.players[0].units.has(attacker) and not game.players[1].units.has(rival), "both units at 0 HP are removed")
	game.config.ranged_takes_no_counter = false
	var shooter := game.spawn_unit(0, "archer", origin)
	var target := game.spawn_unit(1, "warrior", neighbor)
	var answered := game.preview_attack(shooter, target)
	_ok(int(answered["counter"]) == 25, "ranged counter follows the config flag")
	print("[orders and healing]")
	game = _blank_setup("plains")
	var idle := game.spawn_unit(0, "warrior", Vector2i(4, 4))
	idle.hp = 50
	game.end_turn()
	_ok(idle.hp == 60, "an idle unit heals 10")
	idle.hp = 95
	game.end_turn()
	_ok(idle.hp == 100, "healing stops at max HP")
	idle.hp = 40
	idle.acted = true
	game.end_turn()
	_ok(idle.hp == 40 and not idle.acted and idle.mp == cfg.unit("warrior").move, "a unit that acted does not heal, and movement refills")
	idle.hp = 40
	_ok(game.skip_unit(idle) and idle.order == GameSetup.ORDER_SKIP and not idle.acted, "skip is an order and does not count as acting")
	_ok(not game.has_unordered_moves(0), "skip satisfies the end-turn warning")
	game.end_turn()
	_ok(idle.hp == 50 and idle.order.is_empty(), "skip heals, then clears on the next turn")
	_ok(game.has_unordered_moves(0), "a cleared skip warns again while moves remain")
	idle.hp = 40
	_ok(game.fortify_unit(idle) and idle.fortified and idle.order == GameSetup.ORDER_FORTIFY, "fortify sets the defense order")
	_ok(not game.has_unordered_moves(0), "fortify satisfies the end-turn warning")
	game.end_turn()
	_ok(idle.hp == 50 and idle.fortified and idle.order == GameSetup.ORDER_FORTIFY, "fortify heals and persists")
	var stepped := _step(idle.cell, Hex.EAST, 1)
	_ok(game.move_unit(idle, stepped), "a fortified unit can still move")
	_ok(not idle.fortified and idle.order.is_empty() and idle.acted, "moving clears fortify")
	var hp_after_move := idle.hp
	game.end_turn()
	_ok(idle.hp == hp_after_move, "a unit that moved does not heal")
	idle.hp = 40
	idle.acted = true
	game.config.heal_only_if_idle = false
	game.end_turn()
	_ok(idle.hp == 50, "healing ignores the idle rule when the flag is off")
	game.config.heal_only_if_idle = true
	game.config.unit_heal = 3
	idle.hp = 40
	idle.acted = false
	game.end_turn()
	_ok(idle.hp == 43, "heal amount follows the config")
	game.config.end_turn_warns_if_unordered = false
	idle.order = ""
	_ok(not game.has_unordered_moves(0), "the warning flag can turn the check off")
	game.config.end_turn_warns_if_unordered = true
	var partial := game.spawn_unit(0, "settler", Vector2i(8, 8))
	idle.order = GameSetup.ORDER_FORTIFY
	idle.fortified = true
	_ok(game.move_unit(partial, _step(partial.cell, Hex.EAST, 1)), "settler steps once")
	_ok(partial.mp > 0 and game.has_unordered_moves(0), "moves left after a step still need an order")
	partial.mp = 0
	_ok(not game.has_unordered_moves(0), "a unit with no moves left does not warn")


func _test_city_capture() -> void:
	print("[city attack and capture]")
	var cfg: GameConfig = GameConfig.load_file()
	var game := _blank_setup("plains")
	var origin := Vector2i(10, 8)
	var beside := _step(origin, Hex.EAST, 1)
	var city := game.found_city(game.spawn_unit(1, "settler", origin))
	var warrior := game.spawn_unit(0, "warrior", beside)
	_ok(city != null and city.hp == cfg.city_hp and city.max_hp == cfg.city_hp and not city.attacked, "a new city starts at full HP")
	var defense := Combat.defender_strength(cfg, float(cfg.city_defense), false, false)
	var dealt := Combat.damage(cfg, float(cfg.unit("warrior").attack), defense)
	var counter := Combat.damage(cfg, defense, float(cfg.unit("warrior").attack))
	var preview := game.preview_city(warrior, city)
	_ok(bool(preview["ok"]) and int(preview["damage"]) == dealt and int(preview["counter"]) == counter, "warrior preview uses city defense")
	_ok(dealt > 0 and counter > 0, "melee takes counter-damage from a city")
	game.map.set_land(origin, "hills")
	var hill_defense := Combat.defender_strength(cfg, float(cfg.city_defense), true, false)
	var hill_hit := game.preview_city(warrior, city)
	_ok(int(hill_hit["damage"]) == Combat.damage(cfg, float(cfg.unit("warrior").attack), hill_defense), "hills modify the city like any defender")
	game.map.set_land(origin, "plains")
	var before_hp := warrior.hp
	_ok(game.attack_city(warrior, city).is_empty(), "warrior attack on a city resolves")
	_ok(city.hp == cfg.city_hp - dealt and city.attacked and warrior.hp == before_hp - counter, "city and warrior both lose HP")
	_ok(warrior.cell == beside and warrior.mp == 0, "a city attack does not advance the attacker")
	var archer := game.spawn_unit(0, "archer", _step(origin, Hex.EAST, 2))
	var shot := game.preview_city(archer, city)
	_ok(bool(shot["ok"]) and int(shot["counter"]) == 0, "an archer takes no counter from a city")
	var archer_hp := archer.hp
	var city_before := city.hp
	_ok(game.attack_city(archer, city).is_empty(), "archer attack on a city resolves")
	_ok(archer.hp == archer_hp and archer.cell == _step(origin, Hex.EAST, 2) and city.hp == city_before - int(shot["damage"]), "archer damage lands and the archer stays put")
	var scout := game.spawn_unit(0, "scout", _step(origin, Hex.NORTHEAST, 1))
	var scout_preview := game.preview_city(scout, city)
	_ok(bool(scout_preview["ok"]) and int(scout_preview["damage"]) > 0 and int(scout_preview["counter"]) > 0, "a scout attacks a city with the same formula")
	_ok(game.attack_city(scout, city).is_empty() and scout.hp < cfg.unit("scout").hp, "a scout takes the city's counter")
	warrior.mp = cfg.unit("warrior").move
	var guard := 0
	while city.hp > 0 and guard < 8:
		guard += 1
		warrior.mp = cfg.unit("warrior").move
		_ok(game.attack_city(warrior, city).is_empty(), "follow-up city attack resolves")
	_ok(city.hp == 0 and game.cities.has(city), "city HP floors at 0 and the city stays")
	warrior.mp = cfg.unit("warrior").move
	_ok(game.attack_city(warrior, city).is_empty() and city.hp == 0, "another hit does not destroy the city")
	game.config.archers_can_zero_city_hp = false
	city.hp = 10
	archer.mp = cfg.unit("archer").move
	_ok(game.attack_city(archer, city).is_empty() and city.hp == 1, "a ranged hit cannot zero a city when the flag is off")
	game.config.archers_can_zero_city_hp = true
	city.hp = 40
	city.attacked = false
	game.end_turn()
	_ok(city.hp == 50, "a city that was not attacked heals 10")
	city.hp = 95
	city.attacked = false
	game.end_turn()
	_ok(city.hp == 100, "city healing stops at max HP")
	city.hp = 40
	city.attacked = true
	game.end_turn()
	_ok(city.hp == 40 and not city.attacked, "an attacked city does not heal, and the flag clears")
	game.end_turn()
	_ok(city.hp == 50, "the next turn heals a city that was not attacked again")
	game.config.city_heal = 4
	city.hp = 40
	city.attacked = false
	game.end_turn()
	_ok(city.hp == 44, "city heal amount follows the config")
	game.config.city_heals_if_not_attacked = false
	city.hp = 40
	city.attacked = true
	game.end_turn()
	_ok(city.hp == 44, "cities heal after an attack when the flag is off")

	print("[capture]")
	game = _blank_setup("plains")
	origin = Vector2i(10, 8)
	beside = _step(origin, Hex.EAST, 1)
	city = game.found_city(game.spawn_unit(1, "settler", origin))
	warrior = game.spawn_unit(0, "warrior", beside)
	var rival_warrior := game.spawn_unit(1, "warrior", _step(origin, Hex.WEST, 6))
	var border := game.territory_cells(city).duplicate()
	var radius := city.radius
	var building := MapCity.Building.new()
	building.kind = "mana_well"
	building.cell = _step(origin, Hex.NORTHEAST, 1)
	city.buildings.append(building)
	_ok(game.enqueue(city, "warrior").is_empty(), "the city can queue a warrior")
	city.production_stored = 12
	city.population = 1
	var rate := CityRules.city_mana(game.config, city)
	_ok(game.mana_per_turn(1) == rate and game.mana_per_turn(0) == 0, "mana rate starts with the owner")
	_ok(not game.reachable_tiles(warrior).has(origin), "a healthy city blocks movement")
	city.hp = 0
	var scout_block := game.spawn_unit(0, "scout", _step(origin, Hex.SOUTHEAST, 1))
	var archer_block := game.spawn_unit(0, "archer", _step(origin, Hex.NORTHWEST, 1))
	_ok(not game.reachable_tiles(scout_block).has(origin) and not game.move_unit(scout_block, origin), "a scout cannot capture a city")
	_ok(not game.reachable_tiles(archer_block).has(origin) and not game.move_unit(archer_block, origin), "an archer cannot capture a city")
	game.config.melee_captures_city = false
	_ok(not game.capture_destination(warrior, origin) and not game.move_unit(warrior, origin), "the melee capture flag can turn capture off")
	game.config.melee_captures_city = true
	game.config.unit("warrior").can_capture = false
	_ok(not game.move_unit(warrior, origin), "can_capture false rejects the warrior")
	game.config.unit("warrior").can_capture = true
	var garrison := game.spawn_unit(1, "scout", _step(origin, Hex.WEST, 4))
	garrison.cell = origin
	_ok(game.can_attack_city(warrior, city) == GameSetup.REASON_CITY_HELD, "a military unit on the tile is the target")
	_ok(not game.move_unit(warrior, origin), "capture is blocked while a military unit stands on the city")
	garrison.hp = 5
	_ok(game.attack_unit(warrior, garrison).is_empty() and not game.players[1].units.has(garrison), "the garrison dies and the attacker does not step in")
	_ok(warrior.cell == beside and city.player == 1, "the city is still the rival's after the garrison dies")
	warrior.mp = game.config.unit("warrior").move
	var far := _step(origin, Hex.WEST, city.radius + game.config.city_vision_beyond_border)
	_ok(game.fog.sight(1, far) == FogState.Sight.VISIBLE, "the owner sees the city vision ring")
	_ok(game.fog.sight(0, far) != FogState.Sight.VISIBLE, "the attacker does not see that ring yet")
	var pop_before := city.population
	_ok(game.move_unit(warrior, origin), "the warrior moves in and captures")
	_ok(city.player == 0 and warrior.cell == origin and warrior.mp == 0, "the capturer owns the city and ends with no movement")
	_ok(city.population == maxi(game.config.capture_population_min, pop_before - game.config.capture_population_loss), "population drops by the config, not below the minimum")
	_ok(city.hp == roundi(float(city.max_hp) * game.config.capture_hp_fraction), "HP resets to the config fraction")
	_ok(city.queue.is_empty() and city.production_stored == 0 and city.buildings.size() == 1 and city.buildings[0].kind == "mana_well", "the queue clears and the buildings stay")
	_ok(city.radius == radius, "the border radius stays")
	var borders_ok := true
	for cell in border:
		if game.owner_at(cell) != 0:
			borders_ok = false
	_ok(borders_ok and game.owner_at(building.cell) == 0, "border tiles change owner with the city")
	_ok(game.mana_per_turn(0) == CityRules.city_mana(game.config, city) and game.mana_per_turn(1) == 0, "mana per turn moves to the new owner")
	_ok(game.fog.sight(0, far) == FogState.Sight.VISIBLE, "the capturer gains the city's vision")
	_ok(game.fog.sight(1, far) == FogState.Sight.REVEALED, "the previous owner keeps the tile as revealed")
	_ok(game.players[1].units.has(rival_warrior) and game.cities.has(city), "a player with no cities keeps their units")
	game.end_turn()
	_ok(game.players[1].units.has(rival_warrior), "the next turn does not eliminate that player")

	game.config.city_hp = 80
	game.config.capture_hp_fraction = 0.25
	game.config.capture_population_loss = 3
	var tuned_at := Vector2i(2, 2)
	var tuned := game.found_city(game.spawn_unit(1, "settler", tuned_at))
	_ok(tuned != null and tuned.hp == 80 and tuned.max_hp == 80, "founding reads the tuned city HP")
	tuned.population = 2
	tuned.hp = 0
	var taker := game.spawn_unit(0, "warrior", _step(tuned_at, Hex.EAST, 1))
	_ok(game.move_unit(taker, tuned_at), "tuned capture resolves")
	_ok(tuned.population == 1 and tuned.hp == 20, "pop loss and HP percent follow the config")
	game.config.unit("scout").can_capture = true
	var scout_city := game.found_city(game.spawn_unit(1, "settler", Vector2i(2, 8)))
	scout_city.hp = 0
	var capturing_scout := game.spawn_unit(0, "scout", _step(Vector2i(2, 8), Hex.EAST, 1))
	_ok(game.move_unit(capturing_scout, scout_city.cell) and scout_city.player == 0, "a scout captures when can_capture is turned on")

	print("[settler capture]")
	game = _blank_setup("plains")
	origin = Vector2i(8, 8)
	var captor := game.spawn_unit(0, "warrior", origin)
	var settler := game.spawn_unit(1, "settler", _step(origin, Hex.EAST, 1))
	var past := _step(origin, Hex.EAST, 2)
	captor.mp = 1
	var reach := game.reachable_tiles(captor)
	_ok(reach.has(settler.cell) and int(reach[settler.cell]) == 0 and not reach.has(past), "a capture tile ends the move")
	captor.mp = 2
	_ok(game.move_unit(captor, settler.cell), "a warrior moves onto a lone settler")
	_ok(settler.owner == 0 and settler.cell == captor.cell and captor.mp == 0, "the settler changes owner and the mover stops")
	_ok(game.players[0].units.has(settler) and not game.players[1].units.has(settler), "the settler joins the captor's roster")
	var scout_taker := game.spawn_unit(0, "scout", _step(origin, Hex.WEST, 2))
	var second := game.spawn_unit(1, "settler", _step(scout_taker.cell, Hex.WEST, 1))
	_ok(game.move_unit(scout_taker, second.cell) and second.owner == 0, "a scout captures a settler without can_capture")
	var shooter := game.spawn_unit(0, "archer", Vector2i(14, 8))
	var victim := game.spawn_unit(1, "settler", _step(shooter.cell, Hex.EAST, 2))
	shooter.mp = 1
	_ok(not game.reachable_tiles(shooter).has(victim.cell), "the archer cannot walk onto the settler")
	_ok(game.attack_unit(shooter, victim).is_empty() and not game.players[1].units.has(victim), "a ranged attack destroys a lone settler")
	_ok(shooter.cell == Vector2i(14, 8), "the ranged attacker does not step onto the settler")
	var shield := game.spawn_unit(1, "warrior", Vector2i(18, 8))
	var hidden_settler := game.spawn_unit(1, "settler", _step(shield.cell, Hex.EAST, 1))
	hidden_settler.cell = shield.cell
	var hunter := game.spawn_unit(0, "warrior", _step(shield.cell, Hex.WEST, 1))
	_ok(game.can_attack(hunter, hidden_settler) == GameSetup.REASON_ATTACK_SETTLER, "a settler stacked with a military unit is protected")
	_ok(not game.reachable_tiles(hunter).has(shield.cell), "the stacked tile cannot be entered")
	shield.hp = 5
	_ok(game.attack_unit(hunter, shield).is_empty() and game.players[1].units.has(hidden_settler), "killing the guard leaves the settler")
	hunter.mp = game.config.unit("warrior").move
	_ok(game.move_unit(hunter, hidden_settler.cell) and hidden_settler.owner == 0, "the settler can be captured once the guard is dead")
	game.config.capture_lone_settler = false
	var walker := game.spawn_unit(0, "warrior", Vector2i(4, 4))
	var refused := game.spawn_unit(1, "settler", _step(walker.cell, Hex.EAST, 1))
	_ok(refused != null and not game.move_unit(walker, refused.cell), "the lone-settler flag can turn capture off")


func _test_spells() -> void:
	print("[spells]")
	var cfg: GameConfig = GameConfig.load_file()
	var columns := cfg.map_width
	var rows := cfg.map_height
	var open := Vector2i(10, 8)
	var radius := SpellRules.affected_tiles(cfg, columns, rows, "grow_forest", open, Hex.EAST)
	_ok(radius.size() == 7, "radius 1 is 7 tiles in the open")
	_ok(radius.has(open), "radius includes the target")
	for neighbor in Hex.neighbors(Hex.offset_to_axial(open)):
		_ok(radius.has(Hex.axial_to_offset(neighbor)), "radius includes %s" % neighbor)
	var corner := SpellRules.affected_tiles(cfg, columns, rows, "grow_forest", Vector2i.ZERO, Hex.EAST)
	_ok(corner.size() == 3 and corner.has(Vector2i.ZERO), "radius drops off-map tiles at the corner")
	for dir in 6:
		var line := SpellRules.affected_tiles(cfg, columns, rows, "carve_river", open, dir)
		_ok(line.size() == 4 and line[0] == open and line[3] == _step(open, dir, 3), "line of 4 %s" % Hex.DIRECTION_NAMES[dir])
	var clipped := SpellRules.affected_tiles(cfg, columns, rows, "carve_river", Vector2i.ZERO, Hex.WEST)
	_ok(clipped.size() == 1 and clipped[0] == Vector2i.ZERO, "a line drops tiles off the map")
	var axes: Array[Vector2] = []
	var face := Vector2((load("res://assets/art/bebop_tileset.tres") as TileSet).tile_size)
	var origin_px := Hex.offset_to_pixel(open, face)
	for dir in 6:
		axes.append(Hex.offset_to_pixel(_step(open, dir, 1), face) - origin_px)
	for dir in 6:
		_ok(SpellRules.sector(axes[dir], axes) == dir, "cursor toward %s picks that direction" % Hex.DIRECTION_NAMES[dir])
	_ok(SpellRules.sector(Vector2.ZERO, axes) == Hex.EAST, "the tile center casts east")
	_ok(SpellRules.sector(axes[Hex.EAST].rotated(0.25), axes) == Hex.EAST, "the east sector has width")
	var game := _blank_setup("plains")
	var origin := Vector2i(10, 8)
	_ok(game.players[0].mana == cfg.starting_mana, "a new player starts with the config mana")
	var city := game.found_city(game.spawn_unit(0, "settler", origin))
	var income := int(game.city_yields(city)["mana"])
	game.end_turn()
	_ok(game.players[0].mana == cfg.starting_mana + income, "end turn pools each city's mana yield")
	game.players[0].mana = 100
	var owned := _owned_of(game, 0)
	var inside := _step(origin, Hex.EAST, 4)
	var outside := _step(origin, Hex.EAST, 5)
	_ok(SpellRules.nearest_owned_distance(inside, owned) == 3, "range is measured from the nearest owned tile")
	_ok(SpellRules.nearest_owned_distance(outside, owned) == 4, "one step past the ring is distance 4")
	game.config.spells_require_revealed_target = false
	_ok(game.cast_reason(0, "grow_forest", inside, Hex.EAST).is_empty(), "distance 3 is inside range 3")
	_ok(game.cast_reason(0, "grow_forest", outside, Hex.EAST) == SpellRules.REASON_RANGE, "distance 4 is outside range 3")
	_ok(game.cast_reason(0, "ignite", _step(origin, Hex.EAST, 3), Hex.EAST).is_empty(), "ignite range 2 reaches distance 2 from the ring")
	_ok(game.cast_reason(0, "ignite", inside, Hex.EAST) == SpellRules.REASON_RANGE, "ignite range 2 rejects distance 3")
	var bare := _blank_setup("plains")
	bare.players[0].mana = 100
	bare.config.spells_require_revealed_target = false
	_ok(bare.cast_reason(0, "restore_plains", Vector2i(4, 4), Hex.EAST) == SpellRules.REASON_RANGE, "no owned tile means out of range")
	game.config.spells_require_revealed_target = true
	_ok(game.fog.sight(0, inside) == FogState.Sight.UNREVEALED, "the in-range edge is still unrevealed")
	_ok(game.cast_reason(0, "grow_forest", inside, Hex.EAST) == SpellRules.REASON_HIDDEN, "an unrevealed target is rejected")
	game.config.spells_require_revealed_target = false
	_ok(game.cast_reason(0, "grow_forest", inside, Hex.EAST).is_empty(), "the revealed flag can be turned off")
	game.config.spells_require_revealed_target = true
	var worked: Vector2i = (game.city_yields(city)["worked"] as Array)[0]
	var before: Dictionary = game.city_yields(city)
	var preview: Dictionary = game.spell_preview(0, "grow_forest", worked, Hex.EAST)
	_ok((preview["tiles"] as Array).size() == 7, "preview lists the whole radius")
	_ok((preview["skipped"] as Array).has(city.cell), "the city center is marked skipped")
	_ok(not (preview["changed"] as Array).has(city.cell), "the city center is not counted as changed")
	game.map.set_land(worked, "forest")
	preview = game.spell_preview(0, "grow_forest", worked, Hex.EAST)
	_ok(not (preview["changed"] as Array).has(worked), "a tile already of the spell's land is not a change")
	game.map.set_land(worked, "plains")
	var spent := game.players[0].mana
	_ok(game.cast_spell(0, "grow_forest", worked, Hex.EAST).is_empty(), "grow forest casts")
	_ok(game.map.land_at(worked) == "forest", "the worked tile becomes forest")
	_ok(game.map.land_at(city.cell) == "plains", "the city center stays plains")
	_ok(game.owner_at(worked) == 0 and game.owner_at(city.cell) == 0, "a cast does not change ownership")
	_ok(game.players[0].mana == spent - cfg.spell("grow_forest").mana, "mana is spent")
	_ok(game.cooldown_left(0, "grow_forest") == 2 and game.players[0].casts_this_turn == 1, "cooldown 2 starts on the cast turn")
	var after: Dictionary = game.city_yields(city)
	_ok(int(after["production"]) == int(before["production"]) + cfg.land("forest").production, "production updates from the live land")
	_ok(int(after["food"]) == int(before["food"]) - 1, "food updates from the live land")
	var walker := game.spawn_unit(0, "settler", city.cell)
	walker.mp = 1
	_ok(int(game.reachable_tiles(walker)[worked]) == 0, "the new forest move cost applies immediately")
	_ok(game.cast_spell(0, "grow_forest", worked, Hex.EAST) == SpellRules.REASON_COOLDOWN, "cooldown blocks the next cast")
	var turn_cast: int = game.turn
	game.end_turn()
	_ok(game.turn == turn_cast + 1 and game.cooldown_left(0, "grow_forest") == 1, "one owner turn leaves cooldown 1")
	_ok(game.players[0].casts_this_turn == 0, "the one-cast limit resets next turn")
	_ok(game.cast_reason(0, "grow_forest", worked, Hex.EAST) == SpellRules.REASON_COOLDOWN, "cooldown 2 is not ready on turn N+1")
	game.end_turn()
	_ok(game.turn == turn_cast + 2 and game.cooldown_left(0, "grow_forest") == 0, "cooldown 2 is ready on turn N+2")
	_ok(game.cast_reason(0, "restore_plains", worked, Hex.EAST).is_empty(), "another spell is castable once the turn resets")
	var limited := _spell_game()
	limited.config.spell("restore_plains").cooldown = 0
	limited.players[0].mana = 30
	var spot: Vector2i = (limited.city_yields(limited.cities[0])["worked"] as Array)[0]
	_ok(limited.cast_spell(0, "restore_plains", spot, Hex.EAST).is_empty(), "a zero cooldown spell casts")
	_ok(limited.cast_spell(0, "grow_forest", spot, Hex.EAST) == SpellRules.REASON_TURN, "one cast per turn")
	limited.end_turn()
	_ok(limited.cast_reason(0, "grow_forest", spot, Hex.EAST).is_empty(), "the next turn allows another cast")
	var priced := _spell_game()
	priced.players[0].mana = 10
	priced.config.spell("restore_plains").mana = 100
	var priced_tile: Vector2i = priced.cities[0].cell
	_ok(priced.cast_spell(0, "restore_plains", priced_tile, Hex.EAST) == SpellRules.REASON_MANA, "a raised cost rejects the cast")
	_ok(priced.players[0].mana == 10 and priced.map.land_at(priced_tile) == "plains", "a rejected cast spends nothing and changes nothing")
	priced.config.spell("restore_plains").mana = 4
	_ok(priced.cast_spell(0, "restore_plains", _step(priced_tile, Hex.EAST, 1), Hex.EAST).is_empty(), "a lowered cost casts")
	_ok(priced.players[0].mana == 6, "the tuned cost is what gets spent")
	var river := _spell_game()
	var mouth: Vector2i = _step(river.cities[0].cell, Hex.EAST, 1)
	var soaked := _step(mouth, Hex.EAST, 1)
	var standing := river.spawn_unit(0, "warrior", soaked)
	river.players[0].mana = 100
	_ok(standing != null and river.cast_spell(0, "carve_river", mouth, Hex.EAST).is_empty(), "carve river casts through a unit")
	_ok(river.map.land_at(mouth) == "water", "the empty tile becomes water")
	_ok(river.map.land_at(soaked) == "plains", "a unit skips a water result")
	_ok(river.map.land_at(_step(mouth, Hex.EAST, 2)) == "water", "the rest of the line still changes")
	river.players[0].casts_this_turn = 0
	river.players[0].spell_cooldowns.clear()
	river.config.skip_water_if_land_unit_present = false
	_ok(river.cast_spell(0, "carve_river", soaked, Hex.EAST).is_empty(), "the water skip follows the flag")
	_ok(river.map.land_at(soaked) == "water", "with the flag off the unit's tile becomes water")
	var keep := _spell_game()
	keep.config.city_center_never_terraformed = false
	keep.players[0].mana = 50
	_ok(keep.cast_spell(0, "grow_forest", keep.cities[0].cell, Hex.EAST).is_empty(), "the center flag can allow a cast")
	_ok(keep.map.land_at(keep.cities[0].cell) == "forest", "the center changes when the flag is off")
	var wide := _spell_game()
	wide.config.spells_require_revealed_target = false
	wide.players[0].mana = 80
	var far := _step(wide.cities[0].cell, Hex.EAST, 4)
	_ok(wide.cast_reason(0, "carve_river", far, Hex.EAST).is_empty(), "only the target has to be in range")
	wide.config.only_target_must_be_in_range = false
	_ok(wide.cast_reason(0, "carve_river", far, Hex.EAST) == SpellRules.REASON_RANGE, "the whole line is checked when the flag is off")
	wide.config.spell("carve_river").length = 2
	wide.config.only_target_must_be_in_range = true
	_ok(SpellRules.affected_tiles(wide.config, columns, rows, "carve_river", far, Hex.EAST).size() == 2, "line length follows the spell entry")
	var rival_game := _spell_game()
	var rival_at := _step(rival_game.cities[0].cell, Hex.EAST, 3)
	var rival_city := rival_game.found_city(rival_game.spawn_unit(1, "settler", rival_at))
	var rival_tile := _step(rival_at, Hex.WEST, 1)
	_ok(rival_city != null and rival_game.owner_at(rival_tile) == 1, "the neighbor belongs to the rival")
	rival_game.players[0].mana = 40
	_ok(rival_game.cast_spell(0, "grow_forest", rival_tile, Hex.EAST).is_empty(), "a spell can target rival land")
	_ok(rival_game.map.land_at(rival_tile) == "forest", "rival land changes")
	_ok(rival_game.owner_at(rival_tile) == 1 and rival_game.map.land_at(rival_city.cell) == "plains", "ownership stays and the rival center is skipped")
	var explored := _spell_game()
	var home := explored.cities[0].cell
	var watcher := explored.spawn_unit(0, "warrior", _step(home, Hex.EAST, 2))
	var seen := _step(home, Hex.EAST, 4)
	_ok(explored.fog.sight(0, seen) == FogState.Sight.VISIBLE, "a unit reveals the in-range edge")
	_ok(explored.move_unit(watcher, home), "the watcher steps back to the city")
	_ok(explored.fog.sight(0, seen) == FogState.Sight.REVEALED, "leaving the tile keeps it explored")
	_ok(explored.cast_reason(0, "restore_plains", seen, Hex.EAST).is_empty(), "an explored tile is a legal target")
	var mill_game := _spell_game()
	var mill_tile := _step(mill_game.cities[0].cell, Hex.EAST, 1)
	var mill := MapCity.Building.new()
	mill.kind = "lumber_mill"
	mill.cell = mill_tile
	mill_game.cities[0].buildings.append(mill)
	var forests_before := CityRules.adjacent_forests(mill_game.map, mill_tile)
	mill_game.players[0].mana = 40
	var beside := _step(mill_tile, Hex.EAST, 1)
	_ok(mill_game.cast_spell(0, "grow_forest", beside, Hex.EAST).is_empty(), "forest grows beside the mill")
	_ok(CityRules.adjacent_forests(mill_game.map, mill_tile) > forests_before, "the mill counts the new forest immediately")
	_ok(mill_game.cities[0].buildings.size() == 1 and mill_game.cities[0].buildings[0].cell == mill_tile, "the cast does not remove the building")
	var hills := _spell_game()
	var defender_cell := _step(hills.cities[0].cell, Hex.EAST, 1)
	var attacker := hills.spawn_unit(0, "warrior", hills.cities[0].cell)
	var defender := hills.spawn_unit(1, "warrior", defender_cell)
	var plain_damage := int(hills.preview_attack(attacker, defender)["damage"])
	hills.players[0].mana = 40
	_ok(hills.cast_spell(0, "raise_hills", defender_cell, Hex.EAST).is_empty(), "raise hills casts under the defender")
	_ok(hills.map.land_at(defender_cell) == "hills", "the defender stands on hills")
	_ok(int(hills.preview_attack(attacker, defender)["damage"]) < plain_damage, "hills defense uses the live land")


func _test_rival_land_updates() -> void:
	print("[rival land]")
	var cfg: GameConfig = GameConfig.load_file()
	_ok(not cfg.spells_change_tile_ownership, "spells do not change ownership")
	_ok(cfg.land("plains").move_cost == 1 and cfg.land("forest").move_cost == 2 and cfg.land("hills").move_cost == 2, "plains 1, forest and hills 2")
	var game := _spell_game()
	# These cases are about the land write, not fog. The smoke covers a revealed target.
	game.config.spells_require_revealed_target = false
	var home: MapCity = game.cities[0]
	var rival_at := _step(home.cell, Hex.EAST, 3)
	var rival := game.found_city(game.spawn_unit(1, "settler", rival_at))
	_ok(rival != null and Hex.distance(Hex.offset_to_axial(home.cell), Hex.offset_to_axial(rival.cell)) == 3, "rival city is three tiles out")
	var owners_before := _owner_snapshot(game)
	var worked: Vector2i = (game.city_yields(rival)["worked"] as Array)[0]
	_ok(game.owner_at(worked) == 1 and game.map.land_at(worked) == "plains", "the rival works an owned plains tile")
	var before: Dictionary = game.city_yields(rival)
	var turn_before := game.turn
	var rate_before := game.mana_per_turn(1)
	var human_rate := game.mana_per_turn(0)
	game.players[0].mana = 100
	game.config.spell("grow_forest").radius = 0
	_ok(game.cast_spell(0, "grow_forest", worked, Hex.EAST).is_empty(), "grow forest on the rival worked tile")
	_ok(game.turn == turn_before, "the yield change does not wait for End Turn")
	_ok(game.map.land_at(worked) == "forest" and game.owner_at(worked) == 1, "rival land changes and the owner stays")
	_ok(_owners_match(game, owners_before), "no tile changes owner")
	var forested: Dictionary = game.city_yields(rival)
	var forest_gain := cfg.land("forest").production - cfg.land("plains").production
	var forest_food := cfg.land("forest").food - cfg.land("plains").food
	_ok(int(forested["production"]) == int(before["production"]) + forest_gain, "plains to forest raises rival production immediately")
	_ok(int(forested["food"]) == int(before["food"]) + forest_food, "plains to forest lowers rival food immediately")
	_ok((forested["worked"] as Array).has(worked), "the better forest stays worked")
	_ok(int(forested["mana"]) == int(before["mana"]) and game.mana_per_turn(1) == rate_before and game.mana_per_turn(0) == human_rate, "land does not change mana per turn")
	_allow_another_cast(game, 0)
	game.config.spell("restore_plains").radius = 0
	_ok(game.cast_spell(0, "restore_plains", worked, Hex.EAST).is_empty(), "restore plains on the same tile")
	_ok(game.turn == turn_before and game.map.land_at(worked) == "plains" and game.owner_at(worked) == 1, "forest to plains keeps the owner")
	var restored: Dictionary = game.city_yields(rival)
	_ok(int(restored["production"]) == int(before["production"]) and int(restored["food"]) == int(before["food"]), "forest to plains lowers production again")
	var other := _other_owned(game, rival, worked)
	_ok(other.x >= 0 and not (game.city_yields(rival)["worked"] as Array).has(other), "a second owned tile is not worked yet")
	_allow_another_cast(game, 0)
	_ok(game.cast_spell(0, "grow_forest", other, Hex.EAST).is_empty(), "forest grows on the tile the city was not working")
	var switched: Dictionary = game.city_yields(rival)
	_ok((switched["worked"] as Array).has(other) and not (switched["worked"] as Array).has(worked), "the rival city reworks the new forest immediately")
	_ok(game.turn == turn_before, "reassignment does not wait for End Turn")
	var mill_tile := _step(home.cell, Hex.EAST, 1)
	var outer := _step(mill_tile, Hex.NORTHEAST, 1)
	_ok(game.owner_at(outer) == -1 and game.map.land_at(outer) == "plains", "the mill's outer neighbor is unowned plains")
	var mill := MapCity.Building.new()
	mill.kind = "lumber_mill"
	mill.cell = mill_tile
	home.buildings.append(mill)
	var mill_before := int(game.city_yields(home)["production"])
	var forests_before := CityRules.adjacent_forests(game.map, mill_tile)
	var worked_home: Array = game.city_yields(home)["worked"]
	_allow_another_cast(game, 0)
	_ok(game.cast_spell(0, "grow_forest", outer, Hex.EAST).is_empty(), "forest grows beside the mill")
	_ok(CityRules.adjacent_forests(game.map, mill_tile) == forests_before + 1, "the mill sees the new forest")
	_ok(int(game.city_yields(home)["production"]) == mill_before + cfg.lumber_mill_production_per_adjacent_forest, "mill production rises immediately")
	_ok(_same_cells(game.city_yields(home)["worked"], worked_home), "an unowned forest does not change which tiles are worked")
	_allow_another_cast(game, 0)
	_ok(game.cast_spell(0, "restore_plains", outer, Hex.EAST).is_empty(), "restore plains removes the mill's forest")
	_ok(CityRules.adjacent_forests(game.map, mill_tile) == forests_before, "the mill loses that forest")
	_ok(int(game.city_yields(home)["production"]) == mill_before, "mill production falls immediately")
	var well := MapCity.Building.new()
	well.kind = "mana_well"
	well.cell = _step(rival.cell, Hex.WEST, 1)
	rival.buildings.append(well)
	var with_well := rate_before + cfg.mana_well_mana
	_ok(game.mana_per_turn(1) == with_well, "a mana well changes the rate")
	_allow_another_cast(game, 0)
	_ok(game.cast_spell(0, "grow_forest", worked, Hex.EAST).is_empty(), "another land change beside the well")
	_ok(game.mana_per_turn(1) == with_well and int(game.city_yields(rival)["mana"]) == with_well, "land still does not change the mana rate")
	var mover := _blank_setup("plains")
	var mover_city := mover.found_city(mover.spawn_unit(0, "settler", Vector2i(10, 8)))
	var walker := mover.spawn_unit(0, "warrior", mover_city.cell)
	var step_tile := _step(walker.cell, Hex.EAST, 1)
	var past := _step(walker.cell, Hex.EAST, 2)
	mover.players[0].mana = 50
	mover.config.spell("raise_hills").radius = 0
	var reach_before: Dictionary = mover.reachable_tiles(walker)
	_ok(reach_before.has(step_tile) and reach_before.has(past), "both plains steps are reachable")
	_ok(mover.cast_spell(0, "raise_hills", step_tile, Hex.EAST).is_empty(), "raise hills on the first step")
	_ok(mover.map.land_at(step_tile) == "hills" and mover.turn == 1, "the step is hills before End Turn")
	var reach_after: Dictionary = mover.reachable_tiles(walker)
	_ok(reach_after.has(step_tile) and int(reach_after[step_tile]) == 0, "the hill still costs the warrior's two moves")
	_ok(not reach_after.has(past), "the tile beyond the hill drops out of the reachable set")
	game.players[0].mana = 100
	var attacker := game.spawn_unit(0, "warrior", home.cell)
	var defender := game.spawn_unit(1, "warrior", _step(home.cell, Hex.WEST, 1))
	_ok(attacker != null and defender != null, "combatants stand on plains")
	var plain_hit: Dictionary = game.preview_attack(attacker, defender)
	_ok(bool(plain_hit["ok"]) and game.map.land_at(defender.cell) == "plains", "the preview is legal on plains")
	_allow_another_cast(game, 0)
	game.config.spell("raise_hills").radius = 0
	var defender_owner := game.owner_at(defender.cell)
	_ok(game.cast_spell(0, "raise_hills", defender.cell, Hex.EAST).is_empty(), "raise hills under the defender")
	_ok(game.map.land_at(defender.cell) == "hills" and game.owner_at(defender.cell) == defender_owner and game.turn == turn_before, "hills land is live and ownership stays")
	var hill_hit: Dictionary = game.preview_attack(attacker, defender)
	_ok(int(hill_hit["damage"]) < int(plain_hit["damage"]), "hills defense lowers damage immediately")
	_ok(int(hill_hit["counter"]) > int(plain_hit["counter"]), "hills defense raises the counter immediately")
	_allow_another_cast(game, 0)
	_ok(game.cast_spell(0, "restore_plains", defender.cell, Hex.EAST).is_empty(), "restore plains under the defender")
	var back: Dictionary = game.preview_attack(attacker, defender)
	_ok(game.map.land_at(defender.cell) == "plains", "the hill is gone")
	_ok(int(back["damage"]) == int(plain_hit["damage"]) and int(back["counter"]) == int(plain_hit["counter"]), "removing the hill restores both damage numbers")


func _allow_another_cast(game: GameSetup, player: int) -> void:
	# The one-cast limit is not an End Turn. Clearing it keeps growth, healing, and mana unpaid.
	game.players[player].casts_this_turn = 0
	game.players[player].spell_cooldowns.clear()


func _other_owned(game: GameSetup, city: MapCity, skip: Vector2i) -> Vector2i:
	for cell in game.territory_cells(city):
		if cell != city.cell and cell != skip and game.map.land_at(cell) == "plains":
			return cell
	return Vector2i(-1, -1)


func _owner_snapshot(game: GameSetup) -> Dictionary:
	var owners := {}
	for row in game.map.height:
		for col in game.map.width:
			var cell := Vector2i(col, row)
			owners[cell] = game.owner_at(cell)
	return owners


func _owners_match(game: GameSetup, owners: Dictionary) -> bool:
	for cell in owners.keys():
		if game.owner_at(cell) != int(owners[cell]):
			return false
	return true


func _same_cells(left: Variant, right: Variant) -> bool:
	var a: Array = left
	var b: Array = right
	if a.size() != b.size():
		return false
	for cell in a:
		if not b.has(cell):
			return false
	return true


func _spell_game() -> GameSetup:
	var game := _blank_setup("plains")
	game.found_city(game.spawn_unit(0, "settler", Vector2i(10, 8)))
	game.players[0].mana = 100
	return game


func _owned_of(game: GameSetup, player: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in game.owned_cells():
		if game.owner_at(cell) == player:
			out.append(cell)
	return out


func _test_end_turn_key() -> void:
	print("[end turn key]")
	_ok(InputMap.has_action("end_turn"), "end_turn action exists")
	var bound := false
	for event in InputMap.action_get_events("end_turn"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ENTER:
			bound = true
	_ok(bound, "Enter is bound to end_turn")
	_ok(_key_bound("skip_unit", KEY_S), "S is bound to skip_unit")
	_ok(_key_bound("fortify_unit", KEY_F), "F is bound to fortify_unit")


func _key_bound(action: String, keycode: int) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return true
	return false


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


func _test_land_effects() -> void:
	print("[land effects]")
	var types: Array[String] = ["settler", "scout", "warrior", "archer"]
	for type in types:
		var blocked := _blank_setup("plains")
		var origin := Vector2i(8, 8)
		var unit := blocked.spawn_unit(0, type, origin)
		var water := _step(origin, Hex.EAST, 1)
		blocked.map.set_land(water, "water")
		var reach := blocked.reachable_tiles(unit)
		_ok(unit != null and not reach.has(water), "%s reachable set excludes water" % type)
		_ok(not blocked.move_unit(unit, water) and unit.cell == origin, "%s cannot enter water" % type)
		for dir in 6:
			blocked.map.set_land(_step(origin, dir, 1), "water")
		blocked.map.set_land(_step(origin, Hex.EAST, 2), "plains")
		_ok(blocked.reachable_tiles(unit).is_empty(), "%s cannot path through a ring of water" % type)
		_ok(blocked.spawn_unit(1, type, water) == null, "%s cannot spawn on water" % type)
	var kept := _spell_game()
	kept.config.spells_require_revealed_target = false
	var home := kept.cities[0].cell
	var stood := _step(home, Hex.EAST, 2)
	var walker := kept.spawn_unit(0, "warrior", stood)
	_ok(kept.cast_spell(0, "carve_river", stood, Hex.EAST).is_empty(), "carve river still casts when a unit stands in the line")
	_ok(walker.cell == stood and kept.map.land_at(stood) == "plains", "water does not replace the tile under a unit")
	var spells: Array[String] = ["grow_forest", "raise_hills", "ignite", "restore_plains"]
	for spell_id in spells:
		var shifted := _spell_game()
		shifted.config.spells_require_revealed_target = false
		var tile := _step(shifted.cities[0].cell, Hex.EAST, 2)
		if spell_id == "restore_plains":
			shifted.map.set_land(tile, "forest")
		var standing := shifted.spawn_unit(0, "scout", tile)
		_ok(shifted.cast_spell(0, spell_id, tile, Hex.EAST).is_empty(), "%s casts under a unit" % spell_id)
		_ok(standing.cell == tile and shifted.map.land_at(tile) == shifted.config.spell(spell_id).land, "%s changes the tile and leaves the unit" % spell_id)
	_test_building_destruction()
	_test_volcanic_damage()


func _test_building_destruction() -> void:
	var data := GameConfig.read_json(GameConfig.PATH)
	var volcanic: Dictionary = (data["volcanic"] as Dictionary).duplicate()
	volcanic.erase("damage")
	data["volcanic"] = volcanic
	_ok(GameConfig.missing_paths(data).has("volcanic.damage"), "missing volcanic.damage is reported")
	var kinds: Array[String] = ["granary", "mana_well", "lumber_mill"]
	for kind in kinds:
		var game := _spell_game()
		game.config.spells_require_revealed_target = false
		game.config.spell("carve_river").length = 1
		var city: MapCity = game.cities[0]
		var plot := _step(city.cell, Hex.EAST, 1)
		var beside := _step(city.cell, Hex.WEST, 1)
		if kind == "lumber_mill":
			for direction in [Hex.EAST, Hex.NORTHEAST, Hex.SOUTHEAST]:
				game.map.set_land(_step(plot, direction, 1), "forest")
		var building := MapCity.Building.new()
		building.kind = kind
		building.cell = plot
		city.buildings.append(building)
		var neighbor := MapCity.Building.new()
		neighbor.kind = "granary"
		neighbor.cell = beside
		city.buildings.append(neighbor)
		var before: Dictionary = game.city_yields(city)
		var rate := game.mana_per_turn(0)
		var preview: Dictionary = game.spell_preview(0, "carve_river", plot, Hex.EAST)
		_ok((preview["destroyed"] as Array).size() == 1 and (preview["destroyed"] as Array).has(plot), "%s preview names the drowned tile" % kind)
		_ok(not (preview["destroyed"] as Array).has(beside), "%s preview leaves the neighbor" % kind)
		_ok(game.cast_spell(0, "carve_river", plot, Hex.EAST).is_empty(), "%s tile becomes water" % kind)
		_ok(game.map.land_at(plot) == "water" and game.map.land_at(beside) == "plains", "%s water stops at that tile" % kind)
		_ok(city.buildings.size() == 1 and city.buildings[0].cell == beside, "%s is removed and the neighbor stays" % kind)
		_ok(game.owner_at(plot) == 0, "%s water keeps its owner" % kind)
		var after: Dictionary = game.city_yields(city)
		if kind == "granary":
			_ok(int(after["food"]) == int(before["food"]) - game.config.granary_food, "granary food is gone immediately")
			_ok(int(after["surplus"]) == int(before["surplus"]) - game.config.granary_food, "growth surplus drops with the granary")
		elif kind == "mana_well":
			_ok(int(after["mana"]) == int(before["mana"]) - game.config.mana_well_mana, "mana well city mana drops immediately")
			_ok(game.mana_per_turn(0) == rate - game.config.mana_well_mana, "destroying a mana well lowers mana per turn by 2")
		else:
			var bonus := game.config.lumber_mill_production_per_adjacent_forest * 3
			_ok(int(after["production"]) == int(before["production"]) - bonus, "lumber mill production is gone immediately")
		_ok(game.placement_reason(city, kind, plot) == GameSetup.REASON_WATER_BUILD, "%s tile is free and cannot be built on" % kind)
		_ok(not game.placement_tiles(city, kind).has(plot), "%s water is not a placement tile" % kind)
	var queued := _spell_game()
	queued.config.spells_require_revealed_target = false
	queued.config.spell("carve_river").length = 1
	var town: MapCity = queued.cities[0]
	var reserved := _step(town.cell, Hex.EAST, 1)
	_ok(queued.enqueue(town, "scout").is_empty() and queued.enqueue(town, "granary", reserved).is_empty(), "a building queues behind a unit")
	town.production_stored = 7
	_ok(queued.cast_spell(0, "carve_river", reserved, Hex.EAST).is_empty(), "water covers a queued building tile")
	_ok(town.queue.size() == 1 and town.queue[0].item_id == "scout" and town.production_stored == 7, "a later queued building is dropped and the head keeps its progress")
	var head := _spell_game()
	head.config.spells_require_revealed_target = false
	head.config.spell("carve_river").length = 1
	var camp: MapCity = head.cities[0]
	var chosen := _step(camp.cell, Hex.EAST, 1)
	_ok(head.enqueue(camp, "granary", chosen).is_empty() and head.enqueue(camp, "warrior").is_empty(), "a building can lead the queue")
	camp.production_stored = 12
	_ok(head.cast_spell(0, "carve_river", chosen, Hex.EAST).is_empty(), "water covers the head building")
	_ok(camp.queue.size() == 1 and camp.queue[0].item_id == "warrior" and camp.production_stored == 0, "a drowned head item is dropped and nothing is refunded")
	var shore := _step(camp.cell, Hex.NORTHEAST, 1)
	head.map.set_land(shore, "water")
	_ok(head.placement_reason(camp, "granary", shore) == GameSetup.REASON_WATER_BUILD, "an empty water tile rejects a building")
	var spared := _spell_game()
	spared.config.spells_require_revealed_target = false
	spared.config.water_destroys_building = false
	spared.config.spell("carve_river").length = 1
	var kept_city: MapCity = spared.cities[0]
	var kept_plot := _step(kept_city.cell, Hex.EAST, 1)
	var kept_building := MapCity.Building.new()
	kept_building.kind = "granary"
	kept_building.cell = kept_plot
	kept_city.buildings.append(kept_building)
	_ok((spared.spell_preview(0, "carve_river", kept_plot, Hex.EAST)["destroyed"] as Array).is_empty(), "the destroy flag gates the preview")
	_ok(spared.cast_spell(0, "carve_river", kept_plot, Hex.EAST).is_empty(), "water still changes when the flag is off")
	_ok(kept_city.buildings.size() == 1 and spared.map.land_at(kept_plot) == "water", "the flag off leaves the building")
	_ok(spared.placement_reason(kept_city, "granary", kept_plot) == GameSetup.REASON_OCCUPIED, "a building left on water still occupies the tile")
	var stuck := _spell_game()
	stuck.config.spells_require_revealed_target = false
	stuck.config.water_destroys_building = false
	stuck.config.spell("carve_river").length = 1
	var stuck_city: MapCity = stuck.cities[0]
	var stuck_plot := _step(stuck_city.cell, Hex.EAST, 1)
	_ok(stuck.enqueue(stuck_city, "granary", stuck_plot).is_empty() and stuck.enqueue(stuck_city, "warrior").is_empty(), "a granary can lead the queue with the destroy flag off")
	stuck_city.production_stored = 40
	_ok(stuck.cast_spell(0, "carve_river", stuck_plot, Hex.EAST).is_empty(), "water covers a queued tile while the flag is off")
	_ok(stuck_city.queue.size() == 1 and stuck_city.queue[0].item_id == "warrior" and stuck_city.production_stored == 0, "the queued building is dropped and the head's production is discarded")
	var before_units := stuck.players[0].units.size()
	stuck_city.production_stored = stuck.config.unit("warrior").cost
	stuck.end_turn()
	_ok(stuck_city.queue.is_empty(), "End Turn finishes the unit behind the drowned building")
	_ok(stuck.players[0].units.size() == before_units + 1, "that unit completes instead of leaving the granary stuck")
	var drowned := _spell_game()
	drowned.config.spells_require_revealed_target = false
	drowned.config.spell("carve_river").length = 1
	var wet: MapCity = drowned.cities[0]
	var wet_plot := _step(wet.cell, Hex.EAST, 1)
	var occupied := drowned.spawn_unit(0, "warrior", wet_plot)
	var wet_building := MapCity.Building.new()
	wet_building.kind = "mana_well"
	wet_building.cell = wet_plot
	wet.buildings.append(wet_building)
	var wet_rate := drowned.mana_per_turn(0)
	_ok(drowned.cast_spell(0, "carve_river", wet_plot, Hex.EAST).is_empty(), "a unit shields its tile from water")
	_ok(occupied.cell == wet_plot and drowned.map.land_at(wet_plot) == "plains" and wet.buildings.size() == 1, "the shielded building stays")
	_ok(drowned.mana_per_turn(0) == wet_rate, "a skipped tile does not change mana per turn")
	var rival_game := _spell_game()
	rival_game.config.spells_require_revealed_target = false
	rival_game.config.spell("carve_river").length = 1
	var rival_at := _step(rival_game.cities[0].cell, Hex.EAST, 3)
	var rival := rival_game.found_city(rival_game.spawn_unit(1, "settler", rival_at))
	var rival_plot := _step(rival_at, Hex.WEST, 1)
	var rival_well := MapCity.Building.new()
	rival_well.kind = "mana_well"
	rival_well.cell = rival_plot
	rival.buildings.append(rival_well)
	var rival_rate := rival_game.mana_per_turn(1)
	_ok(rival_game.cast_spell(0, "carve_river", rival_plot, Hex.EAST).is_empty(), "a spell can drown a rival building")
	_ok(rival.buildings.is_empty() and rival_game.owner_at(rival_plot) == 1, "the rival building is gone and the owner stays")
	_ok(rival_game.mana_per_turn(1) == rival_rate - rival_game.config.mana_well_mana, "the rival mana rate drops immediately")


func _test_volcanic_damage() -> void:
	var game := _blank_setup("plains")
	var origin := Vector2i(6, 6)
	var warrior := game.spawn_unit(0, "warrior", origin)
	game.map.set_land(origin, "volcanic")
	game.end_turn()
	_ok(warrior.hp == warrior.max_hp - game.config.volcanic_damage, "idle full HP on volcanic ground loses the hazard after the capped heal")
	warrior.hp = 40
	game.end_turn()
	_ok(warrior.hp == 40 and game.players[0].units.has(warrior), "a wounded idle unit nets 0")
	warrior.hp = 5
	game.end_turn()
	_ok(warrior.hp == 5 and game.players[0].units.has(warrior), "healing runs before volcanic damage")
	warrior.hp = 40
	warrior.acted = true
	game.end_turn()
	_ok(warrior.hp == 30, "a unit that acted skips healing and takes the hazard")
	warrior.hp = 10
	warrior.acted = true
	game.end_turn()
	_ok(not game.players[0].units.has(warrior), "10 HP with no heal removes the unit")
	var mover := game.spawn_unit(0, "scout", origin)
	var plains := _step(origin, Hex.EAST, 1)
	var mover_hp := mover.hp
	_ok(game.move_unit(mover, plains), "the scout steps off volcanic ground")
	game.end_turn()
	_ok(mover.hp == mover_hp and mover.cell == plains, "a unit that leaves before End Turn takes no volcanic damage")
	var safe := game.spawn_unit(0, "archer", _step(plains, Hex.EAST, 1))
	var safe_hp := safe.hp
	game.end_turn()
	_ok(safe.hp == safe_hp, "a unit on plains takes no volcanic damage")
	var roster: Array[String] = ["scout", "warrior", "archer"]
	for type in roster:
		var typed := _blank_setup("volcanic")
		var unit := typed.spawn_unit(0, type, Vector2i(4, 4))
		unit.acted = true
		var before := unit.hp
		typed.end_turn()
		_ok(unit.hp == before - typed.config.volcanic_damage, "%s takes volcanic damage" % type)
	var settlers := _blank_setup("volcanic")
	var settler := settlers.spawn_unit(0, "settler", Vector2i(4, 4))
	settlers.end_turn()
	_ok(settler != null and not settlers.players[0].units.has(settler), "a settler on volcanic ground is removed")
	var rivals := _blank_setup("plains")
	var rival := rivals.spawn_unit(1, "warrior", Vector2i(5, 5))
	rivals.map.set_land(rival.cell, "volcanic")
	rival.acted = true
	var rival_hp := rival.hp
	rivals.end_turn()
	_ok(rival.hp == rival_hp - rivals.config.volcanic_damage, "a rival on volcanic ground takes the damage")
	var city_game := _blank_setup("plains")
	var city := city_game.found_city(city_game.spawn_unit(0, "settler", Vector2i(8, 8)))
	city_game.map.set_land(city.cell, "volcanic")
	var guard := city_game.spawn_unit(0, "warrior", city.cell)
	guard.acted = true
	var guard_hp := guard.hp
	city_game.end_turn()
	_ok(guard.hp == guard_hp - city_game.config.volcanic_damage and city_game.cities.has(city), "a unit on a volcanic city tile takes damage and the city stays")
	var born := _blank_setup("plains")
	var born_city := born.found_city(born.spawn_unit(0, "settler", Vector2i(8, 8)))
	born.map.set_land(born_city.cell, "volcanic")
	born_city.population = born.config.unit("settler").min_city_size
	_ok(born.enqueue(born_city, "settler").is_empty(), "a settler can be queued onto a volcanic city center")
	born_city.production_stored = born.config.unit("settler").cost
	var born_before := born.players[0].units.size()
	born.end_turn()
	_ok(born_city.queue.is_empty() and born.cities.has(born_city), "cities finish the settler before volcanic damage")
	var born_settlers := 0
	for unit in born.players[0].units:
		if unit.unit_type == "settler":
			born_settlers += 1
	_ok(born.players[0].units.size() == born_before and born_settlers == 0, "the settler completed onto the volcanic center dies in that same End Turn")
	var founder_game := _blank_setup("volcanic")
	var founder := founder_game.spawn_unit(0, "settler", Vector2i(8, 8))
	_ok(founder_game.can_found(founder).is_empty(), "founding is allowed on volcanic ground")
	var tuned := _blank_setup("volcanic")
	tuned.config.volcanic_damage = 3
	var tuned_unit := tuned.spawn_unit(0, "warrior", Vector2i(3, 3))
	tuned_unit.acted = true
	var tuned_hp := tuned_unit.hp
	tuned.end_turn()
	_ok(tuned_unit.hp == tuned_hp - 3, "volcanic damage follows volcanic.damage")
	var spared := _blank_setup("volcanic")
	spared.config.volcanic_can_kill = false
	var low := spared.spawn_unit(0, "scout", Vector2i(3, 3))
	low.hp = 4
	low.acted = true
	spared.end_turn()
	_ok(low.hp == 1 and spared.players[0].units.has(low), "volcanic.can_kill false leaves the unit at 1 HP")
	var civilian := spared.spawn_unit(0, "settler", Vector2i(5, 5))
	spared.end_turn()
	_ok(spared.players[0].units.has(civilian), "a settler stays when volcanic kills are off")
	var quiet := _blank_setup("volcanic")
	quiet.config.volcanic_flat = false
	var quiet_unit := quiet.spawn_unit(0, "warrior", Vector2i(3, 3))
	quiet_unit.acted = true
	var quiet_hp := quiet_unit.hp
	quiet.end_turn()
	_ok(quiet_unit.hp == quiet_hp, "volcanic.flat false deals no damage")
	var later := _blank_setup("volcanic")
	later.config.volcanic_timing = "never"
	var later_unit := later.spawn_unit(0, "warrior", Vector2i(3, 3))
	later_unit.acted = true
	var later_hp := later_unit.hp
	later.end_turn()
	_ok(later_unit.hp == later_hp, "only end_of_owner_turn volcanic damage is applied")
	var ignited := _spell_game()
	ignited.config.spells_require_revealed_target = false
	var spot := _step(ignited.cities[0].cell, Hex.EAST, 2)
	var ignited_unit := ignited.spawn_unit(0, "warrior", spot)
	ignited_unit.acted = true
	var ignited_hp := ignited_unit.hp
	_ok(ignited.cast_spell(0, "ignite", spot, Hex.EAST).is_empty(), "ignite casts under a unit")
	_ok(ignited.map.land_at(spot) == "volcanic" and ignited_unit.cell == spot and ignited_unit.hp == ignited_hp, "ignite leaves the unit unhurt until End Turn")
	ignited.end_turn()
	_ok(ignited_unit.hp == ignited_hp - ignited.config.volcanic_damage, "the next End Turn damages the unit on the new volcanic tile")
