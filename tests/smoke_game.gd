extends SceneTree

## Drives the real button signals and the game scene's input handler.

const _LAND_COLUMN := {
	"plains": 0,
	"forest": 1,
	"hills": 2,
	"water": 3,
	"volcanic": 4,
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file("res://scenes/main_menu.tscn")
	var menu := await _wait_for("res://scripts/view/main_menu.gd")
	if menu == null:
		return
	(menu.get_node("%NewGameButton") as Button).pressed.emit()
	var game := await _wait_for("res://scripts/view/game_view.gd")
	if game == null:
		return
	if not _assert_new_game(game):
		return
	if not _move_settler(game):
		return
	if not _found_city(game):
		return
	if not _end_turn_with_enter(game):
		return
	if not _train_scout(game):
		return
	(game.get_node("%MenuButton") as Button).pressed.emit()
	(game.get_node("%RestartButton") as Button).pressed.emit()
	game = await _wait_for("res://scripts/view/game_view.gd")
	if game == null:
		return
	var turn := (game.get_node("%TurnLabel") as Label).text
	if turn != "1 / 50":
		print("FAIL restart turn: '", turn, "'")
		quit(1)
		return
	if not _assert_new_game(game):
		return
	print("PASS restart ", turn)
	var victory_event := InputEventAction.new()
	victory_event.action = "debug_victory"
	victory_event.pressed = true
	game._unhandled_input(victory_event)
	var victory := await _wait_for("res://scripts/view/end_screen.gd")
	if victory == null:
		return
	if (victory.get_node("%Title") as Label).text != "Victory":
		print("FAIL victory title")
		quit(1)
		return
	if victory.get_node_or_null("%RestartButton") == null or victory.get_node_or_null("%MainMenuButton") == null:
		print("FAIL victory buttons")
		quit(1)
		return
	print("PASS victory")
	(victory.get_node("%MainMenuButton") as Button).pressed.emit()
	var back := await _wait_for("res://scripts/view/main_menu.gd")
	if back == null:
		return
	(back.get_node("%NewGameButton") as Button).pressed.emit()
	game = await _wait_for("res://scripts/view/game_view.gd")
	if game == null:
		return
	var defeat_event := InputEventAction.new()
	defeat_event.action = "debug_defeat"
	defeat_event.pressed = true
	game._unhandled_input(defeat_event)
	var defeat := await _wait_for("res://scripts/view/end_screen.gd")
	if defeat == null:
		return
	if (defeat.get_node("%Title") as Label).text != "Defeat":
		print("FAIL defeat title")
		quit(1)
		return
	print("PASS defeat")
	print("SMOKE OK")
	quit(0)


func _assert_new_game(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	if setup == null or setup.map == null or setup.fog == null:
		print("FAIL game has no generated setup")
		quit(1)
		return false
	if setup.map.width != 28 or setup.map.height != 18:
		print("FAIL map size")
		quit(1)
		return false
	if setup.players.size() != 3 or setup.unit_total() != 3:
		print("FAIL players ", setup.players.size(), " units ", setup.unit_total())
		quit(1)
		return false
	var lands := {}
	for land_id in setup.map.lands:
		lands[land_id] = true
	if lands.size() != 5:
		print("FAIL land types ", lands.keys())
		quit(1)
		return false
	var human_cell := setup.human_settler_cell()
	if setup.fog.sight(setup.human_index, human_cell) != FogState.Sight.VISIBLE:
		print("FAIL human settler tile is not visible")
		quit(1)
		return false
	var hidden := Vector2i(-1, -1)
	var shown := 0
	for player in setup.players:
		for unit in player.units:
			if unit.unit_type != "settler":
				print("FAIL unexpected unit ", unit.unit_type)
				quit(1)
				return false
			if setup.fog.unit_visible(setup.human_index, unit.cell):
				shown += 1
	for row in setup.map.height:
		for col in setup.map.width:
			var cell := Vector2i(col, row)
			if setup.fog.sight(setup.human_index, cell) == FogState.Sight.UNREVEALED:
				hidden = cell
				break
		if hidden.x >= 0:
			break
	if hidden.x < 0:
		print("FAIL no unrevealed tile")
		quit(1)
		return false
	if not _assert_unrevealed_atlas(game, setup):
		return false
	var actors := game.get_node("%Actors")
	if actors.get_child_count() != shown:
		print("FAIL visible sprites ", actors.get_child_count(), " expected ", shown)
		quit(1)
		return false
	if not _hover(game, hidden, false):
		return false
	if not _hover(game, human_cell, true):
		return false
	print("PASS new game seed ", setup.seed_used, " sprites ", shown)
	return true


func _move_settler(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var origin := setup.human_settler_cell()
	_click_cell(game, origin, MOUSE_BUTTON_LEFT)
	if game.get_node("%MoveHighlights").get_child_count() < 2:
		print("FAIL highlights ", game.get_node("%MoveHighlights").get_child_count())
		quit(1)
		return false
	var unit: PlayerState.UnitState = null
	for candidate in setup.players[setup.human_index].units:
		if candidate.unit_type == "settler":
			unit = candidate
			break
	var tiles: Dictionary = setup.reachable_tiles(unit)
	if tiles.is_empty():
		print("FAIL no reachable tile")
		quit(1)
		return false
	var dest: Vector2i = tiles.keys()[0]
	_click_cell(game, dest, MOUSE_BUTTON_LEFT)
	if setup.human_settler_cell() != origin:
		print("FAIL left click moved the settler to ", setup.human_settler_cell())
		quit(1)
		return false
	print("PASS left click does not move")
	_click_cell(game, origin, MOUSE_BUTTON_LEFT)
	_click_cell(game, dest, MOUSE_BUTTON_RIGHT)
	if setup.human_settler_cell() != dest:
		print("FAIL right click did not move, still ", setup.human_settler_cell())
		quit(1)
		return false
	print("PASS right click moved to ", dest)
	return true


func _end_turn_with_enter(game: Node) -> bool:
	(game.get_node("%MenuButton") as Button).pressed.emit()
	_press_action(game, "end_turn")
	var turn := (game.get_node("%TurnLabel") as Label).text
	if turn != "1 / 50":
		print("FAIL enter during menu: '", turn, "'")
		quit(1)
		return false
	print("PASS enter ignored while menu is open")
	(game.get_node("%MenuButton") as Button).pressed.emit()
	_press_action(game, "end_turn")
	turn = (game.get_node("%TurnLabel") as Label).text
	if turn != "2 / 50":
		print("FAIL enter turn: '", turn, "'")
		quit(1)
		return false
	print("PASS enter ends turn ", turn)
	return true


func _train_scout(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	if setup.cities.is_empty():
		print("FAIL no city to open")
		quit(1)
		return false
	var city: MapCity = setup.cities[0]
	_click_cell(game, city.cell)
	var panel := game.get_node("%CityPanel") as PanelContainer
	if not panel.visible:
		print("FAIL city panel hidden")
		quit(1)
		return false
	var food := (game.get_node("%CityFood") as Label).text
	var prod := (game.get_node("%CityProduction") as Label).text
	var mana := (game.get_node("%CityMana") as Label).text
	var growth := (game.get_node("%GrowthLabel") as Label).text
	var border := (game.get_node("%BorderLabel") as Label).text
	var yields: Dictionary = setup.city_yields(city)
	if food != "Food %d" % int(yields["food"]) or prod != "Production %d" % int(yields["production"]) or mana != "Mana %d" % int(yields["mana"]):
		print("FAIL panel ", food, " ", prod, " ", mana, " core ", yields)
		quit(1)
		return false
	if not growth.contains("/") or not border.begins_with("Radius"):
		print("FAIL growth or border '", growth, "' '", border, "'")
		quit(1)
		return false
	print("PASS city panel ", food, " ", prod, " ", mana, " ", growth, " ", border)
	var tiles_before := setup.territory_cells(city).size()
	var pop_before := city.population
	var stored_before := city.food_stored
	(game.get_node("%BuildScout") as Button).pressed.emit()
	if city.queue.size() != 1 or city.queue[0].item_id != "scout":
		print("FAIL scout queue ", city.queue.size())
		quit(1)
		return false
	if game.get_node("%QueueList").get_child_count() != 1:
		print("FAIL queue row missing")
		quit(1)
		return false
	print("PASS enqueued scout")
	var trained := 0
	for _turn in 40:
		trained = 0
		for unit in setup.players[setup.human_index].units:
			if unit.unit_type == "scout":
				trained += 1
		if trained == 1:
			break
		(game.get_node("%EndTurnButton") as Button).pressed.emit()
	if trained != 1:
		print("FAIL scout was not trained by turn ", setup.turn)
		quit(1)
		return false
	var grew := city.population != pop_before or city.food_stored != stored_before
	var expanded := setup.territory_cells(city).size() > tiles_before
	if not grew and not expanded:
		print("FAIL no growth or border change seed ", setup.seed_used)
		quit(1)
		return false
	var scout_sprite := false
	for child in game.get_node("%Actors").get_children():
		if str(child.name).begins_with("Unit_"):
			scout_sprite = true
	if not scout_sprite:
		print("FAIL trained scout has no sprite")
		quit(1)
		return false
	print("PASS trained scout pop ", city.population, " food ", city.food_stored, " tiles ", setup.territory_cells(city).size())
	return true


func _press_action(game: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	game._unhandled_input(event)


func _found_city(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var cell := setup.human_settler_cell()
	_click_cell(game, cell)
	var found := game.get_node("%FoundCityButton") as Button
	var reason := (game.get_node("%FoundCityReason") as Label).text
	if found.disabled or reason != "":
		print("FAIL found city available: disabled=", found.disabled, " reason='", reason, "'")
		quit(1)
		return false
	print("PASS settler selected")
	found.pressed.emit()
	var human_settlers := 0
	for unit in setup.players[setup.human_index].units:
		if unit.unit_type == "settler":
			human_settlers += 1
	if human_settlers != 0 or setup.cities.size() != 1 or setup.unit_total() != 2:
		print("FAIL founded city settlers=", human_settlers, " cities=", setup.cities.size(), " units=", setup.unit_total())
		quit(1)
		return false
	var city_nodes := 0
	var unit_nodes := 0
	var city_name := ""
	for child in game.get_node("%Actors").get_children():
		var node_name := str(child.name)
		if node_name.begins_with("City_"):
			city_nodes += 1
			city_name = (child.get_node("Name") as Label).text
		elif node_name.begins_with("Unit_"):
			unit_nodes += 1
	if city_nodes != 1 or unit_nodes != 0 or city_name == "":
		print("FAIL city view cities=", city_nodes, " units=", unit_nodes, " name='", city_name, "'")
		quit(1)
		return false
	if setup.cities[0].population != 1:
		print("FAIL city population")
		quit(1)
		return false
	print("PASS founded ", city_name)
	return true


func _click_cell(game: Node, cell: Vector2i, button_index: int = MOUSE_BUTTON_LEFT) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var world: Vector2 = map.to_global(map.map_to_local(cell))
	var screen: Vector2 = game.get_viewport().get_canvas_transform() * world
	var press := InputEventMouseButton.new()
	press.button_index = button_index
	press.pressed = true
	press.position = screen
	press.global_position = screen
	game._unhandled_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = button_index
	release.pressed = false
	release.position = screen
	release.global_position = screen
	game._unhandled_input(release)


func _assert_unrevealed_atlas(game: Node, setup: GameSetup) -> bool:
	var map := game.get_node("%Map") as TileMapLayer
	var lands := {}
	var shared_source := 0
	var shared_atlas := Vector2i.ZERO
	var have := false
	for row in setup.map.height:
		for col in setup.map.width:
			var cell := Vector2i(col, row)
			if setup.fog.sight(setup.human_index, cell) != FogState.Sight.UNREVEALED:
				continue
			var land := setup.map.land_at(cell)
			lands[land] = true
			var source := map.get_cell_source_id(cell)
			var atlas := map.get_cell_atlas_coords(cell)
			if not have:
				shared_source = source
				shared_atlas = atlas
				have = true
			elif source != shared_source or atlas != shared_atlas:
				print("FAIL unrevealed atlas depends on land ", land, " cell ", cell, " source ", source, " atlas ", atlas)
				quit(1)
				return false
			if source == 0 and atlas == Vector2i(int(_LAND_COLUMN[land]), 0):
				print("FAIL unrevealed ", land, " still uses its land atlas at ", cell)
				quit(1)
				return false
	if lands.size() < 2:
		print("FAIL unrevealed tiles did not include two land types")
		quit(1)
		return false
	var visible: Vector2i = setup.human_settler_cell()
	var visible_land := setup.map.land_at(visible)
	var expected := Vector2i(int(_LAND_COLUMN[visible_land]), 0)
	if map.get_cell_source_id(visible) != 0 or map.get_cell_atlas_coords(visible) != expected:
		print("FAIL visible tile atlas ", map.get_cell_atlas_coords(visible), " land ", visible_land)
		quit(1)
		return false
	print("PASS unrevealed atlas ignores land type")
	return true


func _hover(game: Node, cell: Vector2i, expect_land: bool) -> bool:
	var map := game.get_node("%Map") as TileMapLayer
	var local: Vector2 = map.map_to_local(cell)
	var world: Vector2 = map.to_global(local)
	var screen: Vector2 = game.get_viewport().get_canvas_transform() * world
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	game._unhandled_input(motion)
	var tip := (game.get_node("%Tooltip") as Label).text
	var land := str((game.get("setup") as GameSetup).map.land_at(cell))
	if expect_land:
		if not tip.contains(land) or tip.contains("Unexplored"):
			print("FAIL visible tooltip: '", tip, "' land ", land)
			quit(1)
			return false
	else:
		if tip.contains(land) or not tip.contains("Unexplored"):
			print("FAIL hidden tooltip: '", tip, "' land ", land)
			quit(1)
			return false
	print("PASS tooltip ", tip)
	return true


func _wait_for(script_path: String) -> Node:
	for _i in 30:
		await process_frame
		var scene := current_scene
		if scene != null and scene.get_script() != null and scene.get_script().resource_path == script_path:
			await process_frame
			return scene
	print("FAIL scene did not load: ", script_path)
	quit(1)
	return null
