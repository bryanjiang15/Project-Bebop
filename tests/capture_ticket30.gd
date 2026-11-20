extends SceneTree

## Real-renderer shots for ticket 30. Not part of CI.
## Writes ticket30_seed_1327562250.png, ticket30_seed_71165890.png, and
## ticket30_after_end_turn.png at 2560×1440.
## The camera is zoomed to 1.4 and centered on the human settler and warrior.
## No tile is painted.


const LOG_DIR := "/tmp/bebop-ticket30-logs"
const CONFIG_PATH := "/tmp/bebop-ticket30-config.json"
const FRAME_BUDGET := 120
const ZOOM := 1.4


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	_size_window()
	for _frame in 3:
		await process_frame
	if not await _open_seed(1327562250):
		return
	var game := current_scene
	if not await _save("/opt/cursor/artifacts/ticket30_seed_1327562250.png"):
		return
	if not _end_turn(game):
		return
	for _frame in 20:
		await process_frame
	var setup := game.get("setup") as GameSetup
	if not _alive(setup, "after end turn"):
		return
	_frame_units(game)
	game._kill_pan()
	_frame_units(game)
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket30_after_end_turn.png"):
		return
	if not await _open_seed(71165890):
		return
	if not await _save("/opt/cursor/artifacts/ticket30_seed_71165890.png"):
		return
	print("CAPTURE OK")
	quit(0)


func _open_seed(seed_value: int) -> bool:
	if not _write_config(seed_value):
		return false
	GameLog.directory_override = LOG_DIR
	GameConfig.path_override = CONFIG_PATH
	change_scene_to_file("res://scenes/main_menu.tscn")
	var menu := await SceneDriver.wait_for(self, "res://scripts/view/main_menu.gd", FRAME_BUDGET, "main menu")
	if menu == null:
		return false
	(menu.get_node("%NewGameButton") as Button).pressed.emit()
	var game := await SceneDriver.wait_for(self, "res://scripts/view/game_view.gd", FRAME_BUDGET, "seed %d" % seed_value)
	if game == null:
		return false
	var setup := game.get("setup") as GameSetup
	if not _opening(setup, seed_value):
		return false
	_frame_units(game)
	for _frame in 3:
		await process_frame
	return true


func _opening(setup: GameSetup, seed_value: int) -> bool:
	if setup == null or setup.seed_used != seed_value or setup.turn != 1 or setup.result != null:
		var used := -1 if setup == null else setup.seed_used
		print("FAIL seed ", seed_value, " used ", used)
		quit(1)
		return false
	return _roster(setup, "opening %d" % seed_value)


func _alive(setup: GameSetup, label: String) -> bool:
	if setup == null or setup.turn != 2 or setup.result != null:
		var turn := -1 if setup == null else setup.turn
		print("FAIL ", label, " turn ", turn, " result ", setup.result if setup != null else null)
		quit(1)
		return false
	var human := setup.players[setup.human_index]
	if human.eliminated:
		print("FAIL ", label, " eliminated the human")
		quit(1)
		return false
	return _roster(setup, label)


func _roster(setup: GameSetup, label: String) -> bool:
	var settler := _unit(setup, setup.human_index, "settler")
	var warrior := _unit(setup, setup.human_index, "warrior")
	if settler == null or warrior == null:
		print("FAIL ", label, " missing a starting unit")
		quit(1)
		return false
	for unit in [settler, warrior]:
		var land := setup.map.land_at(unit.cell)
		if land == "volcanic" or not setup.map.is_passable(unit.cell, setup.config):
			print("FAIL ", label, " ", unit.unit_type, " on ", land, " ", unit.cell)
			quit(1)
			return false
	if not setup.players[setup.human_index].units.has(settler):
		print("FAIL ", label, " settler was removed")
		quit(1)
		return false
	print("OK ", label, " settler ", setup.map.land_at(settler.cell), settler.cell, " warrior ", setup.map.land_at(warrior.cell), warrior.cell, " neighbors ", _neighbor_lands(setup, settler.cell))
	return true


func _neighbor_lands(setup: GameSetup, cell: Vector2i) -> String:
	var parts: PackedStringArray = []
	for hex in Hex.disk(Hex.offset_to_axial(cell), 1):
		var neighbor := Hex.axial_to_offset(hex)
		if not setup.map.in_bounds(neighbor):
			continue
		parts.append("%s %s" % [setup.map.land_at(neighbor), neighbor])
	return " ".join(parts)


func _unit(setup: GameSetup, player: int, unit_type: String) -> PlayerState.UnitState:
	for unit in setup.players[player].units:
		if unit.unit_type == unit_type:
			return unit
	return null


func _end_turn(game: Node) -> bool:
	var button := game.get_node("%EndTurnButton") as Button
	var setup := game.get("setup") as GameSetup
	var before := setup.turn
	button.pressed.emit()
	setup = game.get("setup") as GameSetup
	if setup.result != null:
		print("FAIL end turn ended the match")
		quit(1)
		return false
	if setup.turn == before:
		button.pressed.emit()
	setup = game.get("setup") as GameSetup
	if setup.turn != before + 1 or setup.result != null:
		print("FAIL end turn stayed on ", setup.turn, " result ", setup.result)
		quit(1)
		return false
	return true


func _frame_units(game: Node) -> void:
	var setup := game.get("setup") as GameSetup
	var settler := _unit(setup, setup.human_index, "settler")
	var warrior := _unit(setup, setup.human_index, "warrior")
	var map := game.get_node("%Map") as TileMapLayer
	var camera := game.get_node("%Camera") as Camera2D
	var midpoint: Vector2 = (map.map_to_local(settler.cell) + map.map_to_local(warrior.cell)) * 0.5
	camera.zoom = Vector2(ZOOM, ZOOM)
	# Keep the pair below the top bar and above the ability bar.
	camera.position = midpoint - (Vector2(1280, 760) - Vector2(1280, 720)) / ZOOM
	game._clamp_camera()


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
