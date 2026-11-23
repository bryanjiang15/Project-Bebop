extends SceneTree

## Real-renderer shots for ticket 24. Not part of CI.
## Writes ticket24_new_game.png, ticket24_city_panel_costs.png,
## ticket24_spells_indicator.png, ticket24_spell_limit_reached.png,
## and ticket24_cap_raised.png at 2560×1440.
## Staging: found the start city, open the city panel, cast Grow Forest once,
## then found two more cities so the cap rises to 2. Costs and the cap formula
## are the live config; nothing is faked on the buttons.


const LOG_DIR := "/tmp/bebop-ticket24-logs"
const CONFIG_PATH := "/tmp/bebop-ticket24-config.json"
const FRAME_BUDGET := 120
const ARTIFACTS := "/opt/cursor/artifacts"
const SEED := 24024


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ARTIFACTS)
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	_size_window()
	for _frame in 3:
		await process_frame
	if not _write_config(SEED):
		return
	GameLog.directory_override = LOG_DIR
	GameConfig.path_override = CONFIG_PATH
	change_scene_to_file("res://scenes/main_menu.tscn")
	var menu := await SceneDriver.wait_for(self, "res://scripts/view/main_menu.gd", FRAME_BUDGET, "main menu")
	if menu == null:
		return
	(menu.get_node("%NewGameButton") as Button).pressed.emit()
	var game := await SceneDriver.wait_for(self, "res://scripts/view/game_view.gd", FRAME_BUDGET, "new game")
	if game == null:
		return
	var setup := game.get("setup") as GameSetup
	if setup == null or setup.seed_used != SEED:
		print("FAIL seed ", setup.seed_used if setup != null else -1)
		quit(1)
		return
	_frame_start(game)
	for _frame in 3:
		await process_frame
	if not await _save("%s/ticket24_new_game.png" % ARTIFACTS):
		return
	var settler := _unit(setup, setup.human_index, "settler")
	if settler == null:
		print("FAIL no settler")
		quit(1)
		return
	SceneDriver.click_cell(game, settler.cell)
	var found := game.get_node("%FoundCityButton") as Button
	if found.disabled:
		print("FAIL found ", found.tooltip_text)
		quit(1)
		return
	found.pressed.emit()
	if setup.city_count(setup.human_index) != 1:
		print("FAIL city count ", setup.city_count(setup.human_index))
		quit(1)
		return
	var city: MapCity = setup.cities[0]
	_aim(game, city.cell)
	if not _select_city(game, city.cell):
		return
	_present(game)
	for _frame in 3:
		await process_frame
	if not _costs_match(game, setup):
		return
	if not await _save("%s/ticket24_city_panel_costs.png" % ARTIFACTS):
		return
	setup.players[setup.human_index].mana = maxi(setup.players[setup.human_index].mana, setup.config.spell("grow_forest").mana)
	game._refresh_board()
	_aim_spells(game)
	_present(game)
	for _frame in 2:
		await process_frame
	var count := game.get_node("%SpellCount") as Label
	var grow := game.get_node("%SpellButtons").get_node("Spell_grow_forest") as Button
	if count.text != "Spells 0/1":
		print("FAIL indicator '", count.text, "'")
		quit(1)
		return
	var cost_label := (grow.get_node("Column/CostLabel") as Label).text
	var grow_cost := "%d mana" % setup.config.spell("grow_forest").mana
	if cost_label != grow_cost:
		print("FAIL grow forest cost '", cost_label, "' expected ", grow_cost)
		quit(1)
		return
	if not await _save("%s/ticket24_spells_indicator.png" % ARTIFACTS):
		return
	grow.pressed.emit()
	SceneDriver.click_cell(game, city.cell)
	game._refresh_board()
	_aim_spells(game)
	_present(game)
	for _frame in 2:
		await process_frame
	if count.text != "Spells 1/1":
		print("FAIL after cast '", count.text, "'")
		quit(1)
		return
	var state := (grow.get_node("Column/StateLabel") as Label).text
	if not state.begins_with("Spell limit reached"):
		print("FAIL limit state '", state, "'")
		quit(1)
		return
	if not grow.disabled:
		print("FAIL grow forest stayed ready")
		quit(1)
		return
	if not await _save("%s/ticket24_spell_limit_reached.png" % ARTIFACTS):
		return
	if not _raise_cap(setup):
		return
	game._refresh_board()
	_aim_spells(game)
	_present(game)
	for _frame in 3:
		await process_frame
	if count.text != "Spells 1/2":
		print("FAIL raised indicator '", count.text, "'")
		quit(1)
		return
	var notice := game.get_node("%SpellNotice") as Label
	if notice.text != "Spell limit is now 2 per turn":
		print("FAIL notice '", notice.text, "'")
		quit(1)
		return
	if not await _save("%s/ticket24_cap_raised.png" % ARTIFACTS):
		return
	print("CAPTURE OK")
	quit(0)


func _raise_cap(setup: GameSetup) -> bool:
	var human := setup.human_index
	var first := setup.cities[0].cell
	for i in 2:
		var site := _found_site(setup, first, (i + 1) * 4)
		if site == Vector2i(-999999, -999999):
			print("FAIL no site for city ", i + 2)
			quit(1)
			return false
		var settler := setup.spawn_unit(human, "settler", site)
		if settler == null:
			print("FAIL spawn settler at ", site)
			quit(1)
			return false
		settler.ap = maxi(settler.ap, 1)
		var city := setup.found_city(settler)
		if city == null:
			print("FAIL found at ", site, " ", setup.can_found(settler))
			quit(1)
			return false
	if setup.city_count(human) < 3 or setup.max_casts(human) != 2:
		print("FAIL cap ", setup.max_casts(human), " cities ", setup.city_count(human))
		quit(1)
		return false
	return true


func _found_site(setup: GameSetup, origin: Vector2i, steps: int) -> Vector2i:
	for direction in [Hex.EAST, Hex.WEST, Hex.NORTHEAST, Hex.SOUTHEAST, Hex.NORTHWEST, Hex.SOUTHWEST]:
		var axial := Hex.offset_to_axial(origin)
		for _i in steps:
			axial = Hex.neighbor(axial, direction)
		var cell := Hex.axial_to_offset(axial)
		if not setup.map.in_bounds(cell) or not setup.map.is_passable(cell, setup.config):
			continue
		if setup.map.land_at(cell) == "volcanic":
			continue
		var settler := PlayerState.UnitState.new()
		settler.unit_type = "settler"
		settler.owner = setup.human_index
		settler.cell = cell
		settler.ap = 1
		if setup.can_found(settler).is_empty():
			return cell
	return Vector2i(-999999, -999999)


func _costs_match(game: Node, setup: GameSetup) -> bool:
	var expected := {
		"%BuildSettler": "Settler %d" % setup.config.unit("settler").cost,
		"%BuildScout": "Scout %d" % setup.config.unit("scout").cost,
		"%BuildWarrior": "Warrior %d" % setup.config.unit("warrior").cost,
		"%BuildArcher": "Archer %d" % setup.config.unit("archer").cost,
		"%BuildGranary": "Granary %d" % setup.config.granary_cost,
		"%BuildManaWell": "Mana Well %d" % setup.config.mana_well_cost,
		"%BuildLumberMill": "Lumber Mill %d" % setup.config.lumber_mill_cost,
	}
	for path in expected.keys():
		var button := game.get_node(path) as Button
		if button.text != str(expected[path]):
			print("FAIL ", path, " '", button.text, "' expected ", expected[path])
			quit(1)
			return false
	return true


func _select_city(game: Node, cell: Vector2i) -> bool:
	var panel := game.get_node("%CityPanel") as CanvasItem
	SceneDriver.click_cell(game, cell)
	if not panel.visible:
		SceneDriver.click_cell(game, cell)
	if not panel.visible:
		print("FAIL city panel closed")
		quit(1)
		return false
	return true


func _unit(setup: GameSetup, player: int, unit_type: String) -> PlayerState.UnitState:
	for unit in setup.players[player].units:
		if unit.unit_type == unit_type:
			return unit
	return null


func _frame_start(game: Node) -> void:
	var setup := game.get("setup") as GameSetup
	var settler := _unit(setup, setup.human_index, "settler")
	if settler == null:
		return
	_aim(game, settler.cell)


func _aim(game: Node, cell: Vector2i) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var camera := game.get_node("%Camera") as Camera2D
	var local: Vector2 = map.map_to_local(cell)
	var zoom := 1.2
	camera.zoom = Vector2(zoom, zoom)
	camera.position = local - (Vector2(980, 620) - Vector2(1280, 720)) / zoom
	game._clamp_camera()


func _aim_spells(game: Node) -> void:
	var camera := game.get_node("%Camera") as Camera2D
	camera.zoom = Vector2(0.9, 0.9)
	game._clamp_camera()


func _present(game: Node) -> void:
	var menu := game.get_node("%InGameMenu") as CanvasItem
	if menu.visible:
		(game.get_node("%MenuButton") as Button).pressed.emit()
	if game.has_method("_clear_hover"):
		game._clear_hover()


func _write_config(seed_value: int) -> bool:
	var data := GameConfig.read_json(GameConfig.PATH)
	if data.is_empty():
		print("FAIL could not read the base config")
		quit(1)
		return false
	var map: Dictionary = data["map"]
	map["seed"] = seed_value
	data["map"] = map
	var log: Dictionary = data["log"]
	log["enabled"] = true
	log["directory"] = LOG_DIR
	data["log"] = log
	var err := SceneDriver.write_json(CONFIG_PATH, data)
	if not err.is_empty():
		print("FAIL ", err)
		quit(1)
		return false
	return true


func _size_window() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(2560, 1440))
	DisplayServer.window_set_position(Vector2i(0, 0))


func _save(path: String) -> bool:
	_size_window()
	for _frame in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.get_width() != 2560 or image.get_height() != 1440:
		var size := "empty" if image == null else "%dx%d" % [image.get_width(), image.get_height()]
		print("FAIL framebuffer ", size, " for ", path)
		quit(1)
		return false
	var err := image.save_png(path)
	if err != OK:
		print("FAIL save ", path, " ", err)
		quit(1)
		return false
	print("WROTE ", path, " ", image.get_width(), "x", image.get_height())
	return true
