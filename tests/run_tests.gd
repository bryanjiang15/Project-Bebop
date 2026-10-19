extends SceneTree

var _passed := 0
var _failed := 0


func _init() -> void:
	print("\n=== Project Bebop unit tests ===\n")
	_test_config()
	_test_hex_neighbors()
	_test_hex_distance()
	_test_hex_disk_and_ring()
	_test_hex_line()
	_test_axial_offset()
	_test_pixels()
	_test_stripes()
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


func _test_stripes() -> void:
	print("[test map]")
	var counts := {"plains": 0, "forest": 0, "hills": 0, "water": 0, "volcanic": 0}
	for col in 28:
		counts[TestMap.land_at(col)] += 1
	_ok(counts["plains"] == 6 and counts["forest"] == 6 and counts["hills"] == 5 and counts["water"] == 6 and counts["volcanic"] == 5, "stripe widths")
	_ok(TestMap.land_at(0) == "plains" and TestMap.land_at(8) == "forest" and TestMap.land_at(14) == "hills", "stripe samples")
	_ok(TestMap.land_at(20) == "water" and TestMap.land_at(27) == "volcanic", "water and volcanic stripes")


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
