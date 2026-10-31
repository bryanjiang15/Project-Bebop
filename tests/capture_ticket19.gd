extends SceneTree

## Real-renderer shots for ticket 19. Not part of CI.
## Writes ticket19_victory_log_path.png, ticket19_defeat_log_path.png,
## and ticket19_sample.jsonl under /opt/cursor/artifacts.


const CONFIG_PATH := "/tmp/bebop-ticket19-capture-config.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	if not _write_config():
		return
	GameConfig.path_override = CONFIG_PATH
	_size_window()
	change_scene_to_file("res://scenes/main_menu.tscn")
	var menu := await _wait("res://scripts/view/main_menu.gd")
	if menu == null:
		return
	(menu.get_node("%NewGameButton") as Button).pressed.emit()
	var game := await _wait("res://scripts/view/game_view.gd")
	if game == null:
		return
	if not await _victory(game):
		return
	game = await _restart_from_end()
	if game == null:
		return
	if not await _defeat(game):
		return
	print("CAPTURE OK")
	quit(0)


func _victory(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var log_path := setup.log.absolute_path
	var settler := _unit(setup, setup.human_index, "settler")
	if settler == null:
		print("FAIL no settler")
		quit(1)
		return false
	_click(game, settler.cell)
	var found := game.get_node("%FoundCityButton") as Button
	if found.disabled:
		print("FAIL found ", (game.get_node("%FoundCityReason") as Label).text)
		quit(1)
		return false
	found.pressed.emit()
	if setup.city_count(setup.human_index) != 1:
		print("FAIL city")
		quit(1)
		return false
	var city: MapCity = setup.cities[0]
	if not _cast(game, "grow_forest", city.cell):
		return false
	var mouth := Hex.axial_to_offset(Hex.neighbor(Hex.offset_to_axial(city.cell), Hex.EAST))
	if not _cast(game, "carve_river", mouth):
		return false
	var end := game.get_node("%EndTurnButton") as Button
	end.pressed.emit()
	if is_instance_valid(game):
		var still := game.get("setup") as GameSetup
		if still != null and still.result == null and end.text == "End anyway (Enter)":
			end.pressed.emit()
	var screen := await _wait("res://scripts/view/end_screen.gd")
	if screen == null:
		return false
	var result := MatchResult.latest
	if result == null or not result.human_won or (screen.get_node("%LogPath") as Label).text != log_path:
		print("FAIL victory path ", (screen.get_node("%LogPath") as Label).text if screen != null else "")
		quit(1)
		return false
	var events := _events(log_path)
	var casts := 0
	var ends := 0
	for event in events:
		var kind := str((event as Dictionary).get("event", ""))
		if kind == "cast":
			casts += 1
		elif kind == "end":
			ends += 1
	if casts < 2 or ends != 1:
		print("FAIL sample events casts ", casts, " ends ", ends)
		quit(1)
		return false
	var sample := "/opt/cursor/artifacts/ticket19_sample.jsonl"
	var text := FileAccess.get_file_as_string(log_path)
	var out := FileAccess.open(sample, FileAccess.WRITE)
	if out == null:
		print("FAIL sample write")
		quit(1)
		return false
	out.store_string(text)
	out.close()
	print("WROTE ", sample)
	print("LOG ", log_path)
	for _frame in 4:
		await process_frame
	return await _save("/opt/cursor/artifacts/ticket19_victory_log_path.png")


func _defeat(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var log_path := setup.log.absolute_path
	var human_settler := _unit(setup, setup.human_index, "settler")
	var rival := 1 if setup.human_index != 1 else 0
	var rival_warrior := _unit(setup, rival, "warrior")
	if human_settler == null or rival_warrior == null:
		print("FAIL defeat units")
		quit(1)
		return false
	var spot := Vector2i(8, 8)
	var beside := Hex.axial_to_offset(Hex.neighbor(Hex.offset_to_axial(spot), Hex.EAST))
	setup.map.set_land(spot, "plains")
	setup.map.set_land(beside, "plains")
	human_settler.cell = spot
	rival_warrior.cell = beside
	rival_warrior.mp = setup.config.unit("warrior").move
	setup._refresh_fog()
	if not setup.move_unit(rival_warrior, spot) or setup.result == null or setup.result.human_won:
		print("FAIL defeat fixture")
		quit(1)
		return false
	game._refresh_board()
	var screen := await _wait("res://scripts/view/end_screen.gd")
	if screen == null:
		return false
	var shown := (screen.get_node("%LogPath") as Label).text
	if shown != log_path or shown.is_empty() or MatchResult.latest == null or MatchResult.latest.human_won:
		print("FAIL defeat path '", shown, "'")
		quit(1)
		return false
	for _frame in 4:
		await process_frame
	return await _save("/opt/cursor/artifacts/ticket19_defeat_log_path.png")


func _cast(game: Node, spell_id: String, cell: Vector2i) -> bool:
	var setup := game.get("setup") as GameSetup
	var before := setup.players[setup.human_index].casts_this_turn
	var button := game.get_node("%SpellButtons").get_node("Spell_%s" % spell_id) as Button
	if button.disabled:
		print("FAIL ", spell_id, " ", button.tooltip_text)
		quit(1)
		return false
	button.pressed.emit()
	_click(game, cell)
	if setup.players[setup.human_index].casts_this_turn != before + 1:
		print("FAIL cast ", spell_id)
		quit(1)
		return false
	return true


func _restart_from_end() -> Node:
	var screen := current_scene
	(screen.get_node("%RestartButton") as Button).pressed.emit()
	return await _wait("res://scripts/view/game_view.gd")


func _write_config() -> bool:
	var data := GameConfig.read_json(GameConfig.PATH)
	data["turn_limit"] = 1
	(data["players"] as Dictionary)["starting_mana"] = 200
	(data["spells"] as Dictionary)["casts_per_turn"] = 2
	var log: Dictionary = data["log"]
	log["enabled"] = true
	log["directory"] = "user://logs"
	data["log"] = log
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		print("FAIL config")
		quit(1)
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true


func _unit(setup: GameSetup, player: int, unit_type: String) -> PlayerState.UnitState:
	for unit in setup.players[player].units:
		if unit.unit_type == unit_type:
			return unit
	return null


func _click(game: Node, cell: Vector2i) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var world: Vector2 = map.to_global(map.map_to_local(cell))
	var screen: Vector2 = game.get_viewport().get_canvas_transform() * world
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	press.global_position = screen
	game._unhandled_input(press)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	game._unhandled_input(release)


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
	print("WROTE ", path)
	return true


func _events(path: String) -> Array:
	var events: Array = []
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		if line.strip_edges().is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			events.append(parsed)
	return events


func _wait(script_path: String) -> Node:
	for _i in 80:
		await process_frame
		var scene := current_scene
		if scene != null and scene.get_script() != null and scene.get_script().resource_path == script_path:
			await process_frame
			return scene
	print("FAIL scene did not load: ", script_path)
	quit(1)
	return null
