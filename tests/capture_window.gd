extends SceneTree

## Real-renderer shots at the 2560×1440 project window. Not part of CI.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	change_scene_to_file("res://scenes/main_menu.tscn")
	var menu := await _wait("res://scripts/view/main_menu.gd")
	if menu == null:
		return
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	if not await _save("/opt/cursor/artifacts/window_main_menu.png"):
		return
	(menu.get_node("%NewGameButton") as Button).pressed.emit()
	var game := await _wait("res://scripts/view/game_view.gd")
	if game == null:
		return
	for _try in 40:
		var current := game.get("setup") as GameSetup
		if current != null and _good_start(current):
			break
		var previous := current.seed_used if current != null else -1
		(game.get_node("%MenuButton") as Button).pressed.emit()
		(game.get_node("%RestartButton") as Button).pressed.emit()
		game = await _wait_new_seed(previous)
		if game == null:
			return
	var setup := game.get("setup") as GameSetup
	if setup == null or not _good_start(setup):
		print("FAIL no inset city site")
		quit(1)
		return
	var cell := setup.human_settler_cell()
	_click(game, cell)
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	if not await _save("/opt/cursor/artifacts/window_settler_selected.png"):
		return
	print("SETTLER ", (game.get_node("%SelectionTitle") as Label).text, " cell ", cell)
	var found := game.get_node("%FoundCityButton") as Button
	if found.disabled:
		print("FAIL cannot found ", (game.get_node("%FoundCityReason") as Label).text)
		quit(1)
		return
	found.pressed.emit()
	if setup.cities.is_empty():
		print("FAIL city missing")
		quit(1)
		return
	var city: MapCity = setup.cities[0]
	_click(game, city.cell)
	if not (game.get_node("%CityPanel") as CanvasItem).visible:
		print("FAIL panel hidden")
		quit(1)
		return
	(game.get_node("%BuildScout") as Button).pressed.emit()
	(game.get_node("%BuildWarrior") as Button).pressed.emit()
	if city.queue.size() < 2:
		print("FAIL queue ", city.queue.size(), " ", (game.get_node("%CityReason") as Label).text)
		quit(1)
		return
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	if not await _save("/opt/cursor/artifacts/window_city_panel.png"):
		return
	print("CITY ", (game.get_node("%CityName") as Label).text, " ", (game.get_node("%CityFood") as Label).text)
	print("QUEUE ", city.queue.size())
	(game.get_node("%MenuButton") as Button).pressed.emit()
	for _frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	if not await _save("/opt/cursor/artifacts/window_ingame_menu.png"):
		return
	change_scene_to_file("res://scenes/victory.tscn")
	if await _wait("res://scripts/view/end_screen.gd") == null:
		return
	for _frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	if not await _save("/opt/cursor/artifacts/window_victory.png"):
		return
	change_scene_to_file("res://scenes/defeat.tscn")
	if await _wait("res://scripts/view/end_screen.gd") == null:
		return
	for _frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	if not await _save("/opt/cursor/artifacts/window_defeat.png"):
		return
	quit(0)


func _good_start(setup: GameSetup) -> bool:
	var cell := setup.human_settler_cell()
	# Keep the start near the middle so the doubled window shows the map, not the void past an edge.
	if cell.x < 10 or cell.y < 5 or cell.x > setup.map.width - 11 or cell.y > setup.map.height - 6:
		return false
	for candidate in setup.players[setup.human_index].units:
		if candidate.unit_type == "settler":
			return setup.can_found(candidate).is_empty()
	return false


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


func _save(path: String) -> bool:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.get_width() == 0:
		print("FAIL empty framebuffer")
		quit(1)
		return false
	var err := image.save_png(path)
	if err != OK:
		print("FAIL save ", path, " ", err)
		quit(1)
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
	print("FAIL scene did not load: ", script_path)
	quit(1)
	return null


func _wait_new_seed(previous_seed: int) -> Node:
	for _i in 40:
		await process_frame
		var scene := current_scene
		if scene == null or scene.get_script() == null:
			continue
		if scene.get_script().resource_path != "res://scripts/view/game_view.gd":
			continue
		var setup := scene.get("setup") as GameSetup
		if setup == null or setup.seed_used == previous_seed:
			continue
		await process_frame
		return scene
	print("FAIL restart")
	quit(1)
	return null
