extends SceneTree

## Real-renderer shots for ticket 18. Not part of CI.
## Writes ticket18_*.png under /opt/cursor/artifacts at 2560×1440.
## Plays a New Game from the shipped config. The only override is the log
## folder, so the capture does not write user://logs. No painted land, no
## moved units, no edited HP or mana.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	DirAccess.make_dir_recursive_absolute("/tmp/bebop-capture-logs")
	if not _pin_log():
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(2560, 1440))
	DisplayServer.window_set_position(Vector2i(0, 0))
	for _frame in 3:
		await process_frame
	change_scene_to_file("res://scenes/main_menu.tscn")
	var menu := await _wait("res://scripts/view/main_menu.gd")
	if menu == null:
		return
	(menu.get_node("%NewGameButton") as Button).pressed.emit()
	var game := await _wait("res://scripts/view/game_view.gd")
	if game == null:
		return
	var setup := game.get("setup") as GameSetup
	if setup == null:
		_fail("no setup")
		return
	var settler := _unit(setup, 0, "settler")
	var warrior := _unit(setup, 0, "warrior")
	if settler == null or warrior == null:
		_fail("missing starting units")
		return
	_click(game, settler.cell)
	for _frame in 4:
		await process_frame
	var mana := (game.get_node("%ManaLabel") as Label).text
	var turn := (game.get_node("%TurnLabel") as Label).text
	var ap := (game.get_node("%AbilityApLabel") as Label).text
	if mana != "Mana: 10 (+0/turn)" or turn != "1 / 50" or not ap.begins_with("AP "):
		_fail("opening readout mana '%s' turn '%s' ap '%s'" % [mana, turn, ap])
		return
	if not (game.get_node("%AbilityBar") as CanvasItem).visible:
		_fail("ability bar hidden on the opening settler")
		return
	_hold_camera(game, settler.cell)
	game._clear_hover()
	if not await _save("/opt/cursor/artifacts/ticket18_new_game.png"):
		return
	var found := SceneDriver.order_button(game, "found")
	if found == null or found.disabled:
		_fail("cannot found: %s" % setup.can_found(settler))
		return
	var rivals_before := _rival_snapshot(setup)
	found.pressed.emit()
	for _frame in 6:
		await process_frame
	var city := _human_city(setup)
	if city == null:
		_fail("found did not place a city")
		return
	_click(game, city.cell)
	for _frame in 3:
		await process_frame
	_click(game, warrior.cell)
	for _frame in 4:
		await process_frame
	var panel := game.get_node("%CityPanel") as CanvasItem
	var bar := game.get_node("%AbilityBar") as CanvasItem
	var warrior_cost := (game.get_node("%BuildWarrior") as Button).text
	var ap_after := (game.get_node("%AbilityApLabel") as Label).text
	if not panel.visible or not bar.visible or warrior_cost != "Warrior 30" or ap_after != "AP 2 / 2":
		_fail("city and bar panel %s bar %s cost '%s' ap '%s'" % [panel.visible, bar.visible, warrior_cost, ap_after])
		return
	_hold_camera(game, city.cell)
	game._clear_hover()
	if not await _save("/opt/cursor/artifacts/ticket18_city_and_bar.png"):
		return
	var skip := SceneDriver.order_button(game, "skip")
	if skip == null or skip.disabled:
		_fail("skip is not ready")
		return
	skip.pressed.emit()
	for _frame in 3:
		await process_frame
	var turn_before := setup.turn
	(game.get_node("%EndTurnButton") as Button).pressed.emit()
	for _frame in 8:
		await process_frame
	var turn_after := (game.get_node("%TurnLabel") as Label).text
	if setup.turn != turn_before + 1 or turn_after != "2 / 50" or setup.result != null:
		_fail("end turn left turn %d label '%s' result %s" % [setup.turn, turn_after, setup.result])
		return
	if _rival_snapshot(setup) == rivals_before:
		_fail("rivals did not act")
		return
	_hold_camera(game, city.cell)
	game._clear_hover()
	if not await _save("/opt/cursor/artifacts/ticket18_after_end_turn.png"):
		return
	print("STAGED none. Shipped config, rolled seed ", setup.seed_used, ". Log folder redirected to /tmp/bebop-capture-logs.")
	print("CAPTURE OK")
	quit(0)


func _pin_log() -> bool:
	var data := GameConfig.read_json(GameConfig.PATH)
	if data.is_empty():
		_fail("could not read config")
		return false
	var log: Dictionary = data["log"]
	log["enabled"] = true
	log["directory"] = "/tmp/bebop-capture-logs"
	data["log"] = log
	var err := SceneDriver.write_json("/tmp/bebop-capture-config.json", data)
	if not err.is_empty():
		_fail(err)
		return false
	GameConfig.path_override = "/tmp/bebop-capture-config.json"
	GameLog.directory_override = "/tmp/bebop-capture-logs"
	return true


func _human_city(setup: GameSetup) -> MapCity:
	for city in setup.cities:
		if city.player == setup.human_index:
			return city
	return null


func _rival_snapshot(setup: GameSetup) -> String:
	var parts: PackedStringArray = []
	for player in setup.players:
		if player.human:
			continue
		parts.append("cities %d" % setup.city_count(player.index))
		for unit in player.units:
			parts.append("%d:%s@%s" % [unit.id, unit.unit_type, unit.cell])
	return ",".join(parts)


func _unit(setup: GameSetup, player: int, unit_type: String) -> PlayerState.UnitState:
	for unit in setup.players[player].units:
		if unit.unit_type == unit_type:
			return unit
	return null


func _hold_camera(game: Node, cell: Vector2i) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var camera := game.get_node("%Camera") as Camera2D
	var zoom: float = (game.get("_config") as GameConfig).camera_default_zoom
	camera.zoom = Vector2(zoom, zoom)
	camera.position = map.map_to_local(cell)
	game._clamp_camera()


func _click(game: Node, cell: Vector2i) -> void:
	SceneDriver.click_cell(game, cell)


func _save(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.get_width() != 2560 or image.get_height() != 1440:
		var size := "empty" if image == null else "%dx%d" % [image.get_width(), image.get_height()]
		_fail("framebuffer %s for %s" % [size, path])
		return false
	var err := image.save_png(path)
	if err != OK:
		_fail("save %s %s" % [path, err])
		return false
	print("WROTE ", path, " ", image.get_width(), "x", image.get_height())
	return true


func _wait(script_path: String) -> Node:
	for _i in 40:
		await process_frame
		var scene := current_scene
		if scene != null and scene.get_script() != null and scene.get_script().resource_path == script_path:
			await process_frame
			return scene
	_fail("scene did not load: %s" % script_path)
	return null


func _fail(message: String) -> void:
	print("FAIL ", message)
	quit(1)
