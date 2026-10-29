extends SceneTree

## Real-renderer shots for ticket 17. Not part of CI.
## Writes ticket17_*.png under /opt/cursor/artifacts.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	_size_window()
	change_scene_to_file("res://scenes/main_menu.tscn")
	var menu := await _wait("res://scripts/view/main_menu.gd")
	if menu == null:
		return
	(menu.get_node("%NewGameButton") as Button).pressed.emit()
	var game := await _wait("res://scripts/view/game_view.gd")
	if game == null:
		return
	if not await _top_bar(game):
		return
	game = await _menu_restart(game)
	if game == null:
		return
	if not await _conquest(game):
		return
	game = await _end_restart()
	if game == null:
		return
	if not await _score_win(game):
		return
	game = await _end_restart()
	if game == null:
		return
	if not await _defeat(game):
		return
	game = await _end_restart()
	if game == null:
		return
	for _frame in 4:
		await process_frame
	var turn := (game.get_node("%TurnLabel") as Label).text
	var score := (game.get_node("%Score0") as Label).text
	if turn != "1 / 50" or score != "You 0":
		print("FAIL after restart '", turn, "' '", score, "'")
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket17_after_restart.png"):
		return
	print("CAPTURE OK")
	quit(0)


func _top_bar(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var settler := _unit(setup, setup.human_index, "settler")
	if settler == null:
		print("FAIL no human settler")
		quit(1)
		return false
	_click(game, settler.cell)
	(game.get_node("%FoundCityButton") as Button).pressed.emit()
	if setup.city_count(setup.human_index) != 1:
		print("FAIL human city")
		quit(1)
		return false
	var rival := 1 if setup.human_index != 1 else 0
	var founder := _unit(setup, rival, "settler")
	var spot := _far(setup, settler.cell)
	if founder == null or spot.x < 0:
		print("FAIL rival founding spot")
		quit(1)
		return false
	for hex in Hex.disk(Hex.offset_to_axial(spot), 1):
		var cell := Hex.axial_to_offset(hex)
		if setup.map.in_bounds(cell):
			setup.map.set_land(cell, "plains")
	founder.cell = spot
	if setup.found_city(founder) == null:
		print("FAIL rival city")
		quit(1)
		return false
	game._refresh_board()
	for _frame in 4:
		await process_frame
	print("SCORES ", (game.get_node("%Score0") as Label).text, " | ", (game.get_node("%Score1") as Label).text, " | ", (game.get_node("%Score2") as Label).text)
	return await _save("/opt/cursor/artifacts/ticket17_topbar_scores.png")


func _conquest(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var human := setup.human_index
	var others: Array[int] = []
	for index in setup.players.size():
		if index != human:
			others.append(index)
	var rival_a := others[0]
	var rival_b := others[1]
	var park := Vector2i(20, 14)
	for player in setup.players:
		for unit in player.units:
			if setup.map.in_bounds(park):
				setup.map.set_land(park, "plains")
			unit.cell = park
			park.x += 1
	var warrior := _unit(setup, human, "warrior")
	var human_settler := _unit(setup, human, "settler")
	var settler_b := _unit(setup, rival_b, "settler")
	var warrior_a := _unit(setup, rival_a, "warrior")
	human_settler.cell = Vector2i(1, 1)
	warrior_a.cell = Vector2i(0, 0)
	setup.map.set_land(Vector2i(1, 1), "plains")
	setup.map.set_land(Vector2i(0, 0), "plains")
	var spot := Vector2i(8, 8)
	var beside := Hex.axial_to_offset(Hex.neighbor(Hex.offset_to_axial(spot), Hex.WEST))
	setup.map.set_land(spot, "plains")
	setup.map.set_land(beside, "plains")
	settler_b.cell = spot
	warrior.cell = beside
	warrior.mp = setup.config.unit("warrior").move
	setup._refresh_fog()
	if not setup.move_unit(warrior, spot) or setup.result != null:
		print("FAIL conquest fixture")
		quit(1)
		return false
	var settler_a := _unit(setup, rival_a, "settler")
	var city_cell := Vector2i(12, 8)
	for hex in Hex.disk(Hex.offset_to_axial(city_cell), 1):
		var cell := Hex.axial_to_offset(hex)
		if setup.map.in_bounds(cell):
			setup.map.set_land(cell, "plains")
	settler_a.cell = city_cell
	var city := setup.found_city(settler_a)
	if city == null:
		print("FAIL conquest city")
		quit(1)
		return false
	city.hp = 0
	var approach := Hex.axial_to_offset(Hex.neighbor(Hex.offset_to_axial(city_cell), Hex.EAST))
	setup.map.set_land(approach, "plains")
	warrior.cell = approach
	warrior.mp = setup.config.unit("warrior").move
	setup._refresh_fog()
	game._refresh_board()
	_click(game, approach)
	if (game.get_node("%SelectionTitle") as Label).text != "Warrior":
		_click(game, approach)
	_click(game, city_cell, MOUSE_BUTTON_RIGHT)
	var screen := await _wait("res://scripts/view/end_screen.gd")
	if screen == null:
		return false
	if (screen.get_node("%Title") as Label).text != "Victory":
		print("FAIL conquest title")
		quit(1)
		return false
	for _frame in 4:
		await process_frame
	return await _save("/opt/cursor/artifacts/ticket17_victory_conquest.png")


func _score_win(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var settler := _unit(setup, setup.human_index, "settler")
	_click(game, settler.cell)
	(game.get_node("%FoundCityButton") as Button).pressed.emit()
	if setup.city_count(setup.human_index) != 1:
		print("FAIL score city")
		quit(1)
		return false
	setup.config.turn_limit = 1
	game._refresh_board()
	_confirm_end(game)
	var screen := await _wait("res://scripts/view/end_screen.gd")
	if screen == null:
		return false
	var result := MatchResult.latest
	if result == null or not result.human_won or result.ending != MatchResult.REASON_SCORE:
		print("FAIL score win ", result)
		quit(1)
		return false
	if (screen.get_node("%Title") as Label).text != "Victory":
		print("FAIL score title")
		quit(1)
		return false
	for _frame in 4:
		await process_frame
	return await _save("/opt/cursor/artifacts/ticket17_victory_score.png")


func _defeat(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var settler := _unit(setup, setup.human_index, "settler")
	setup.map.set_land(settler.cell, "volcanic")
	game._refresh_board()
	_confirm_end(game)
	var screen := await _wait("res://scripts/view/end_screen.gd")
	if screen == null:
		return false
	var result := MatchResult.latest
	if result == null or result.human_won or result.ending != MatchResult.REASON_ELIMINATED:
		print("FAIL defeat ", result)
		quit(1)
		return false
	for _frame in 4:
		await process_frame
	return await _save("/opt/cursor/artifacts/ticket17_defeat.png")


func _menu_restart(game: Node) -> Node:
	(game.get_node("%MenuButton") as Button).pressed.emit()
	(game.get_node("%RestartButton") as Button).pressed.emit()
	return await _wait("res://scripts/view/game_view.gd")


func _end_restart() -> Node:
	var screen := current_scene
	(screen.get_node("%RestartButton") as Button).pressed.emit()
	return await _wait("res://scripts/view/game_view.gd")


func _confirm_end(game: Node) -> void:
	var button := game.get_node("%EndTurnButton") as Button
	button.pressed.emit()
	if not is_instance_valid(game):
		return
	var setup := game.get("setup") as GameSetup
	if setup == null or setup.result != null:
		return
	if not (game.get_node("%EndTurnWarning") as Label).text.is_empty():
		button.pressed.emit()


func _unit(setup: GameSetup, player: int, unit_type: String) -> PlayerState.UnitState:
	for unit in setup.players[player].units:
		if unit.unit_type == unit_type:
			return unit
	return null


func _far(setup: GameSetup, origin: Vector2i) -> Vector2i:
	var from := Hex.offset_to_axial(origin)
	for row in setup.map.height:
		for col in setup.map.width:
			var cell := Vector2i(col, row)
			if Hex.distance(from, Hex.offset_to_axial(cell)) >= 8:
				return cell
	return Vector2i(-1, -1)


func _click(game: Node, cell: Vector2i, button_index: int = MOUSE_BUTTON_LEFT) -> void:
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


func _wait(script_path: String) -> Node:
	for _i in 40:
		await process_frame
		var scene := current_scene
		if scene != null and scene.get_script() != null and scene.get_script().resource_path == script_path:
			await process_frame
			return scene
	print("FAIL scene did not load: ", script_path)
	quit(1)
	return null
