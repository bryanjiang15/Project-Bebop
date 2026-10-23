extends SceneTree

## Real-renderer shots for ticket 8. Not part of CI.
## Writes /opt/cursor/artifacts/ticket8_move_highlight.png and ticket8_city_founded.png.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	change_scene_to_file("res://scenes/main_menu.tscn")
	var menu := await _wait("res://scripts/view/main_menu.gd")
	if menu == null:
		return
	(menu.get_node("%NewGameButton") as Button).pressed.emit()
	var game := await _wait("res://scripts/view/game_view.gd")
	if game == null:
		return
	for _try in 24:
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
		print("FAIL no inset start with a legal move")
		quit(1)
		return
	var cell := setup.human_settler_cell()
	_click(game, cell)
	_frame(game, cell)
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var highlights := game.get_node("%MoveHighlights").get_child_count()
	if highlights < 2:
		print("FAIL highlights ", highlights)
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket8_move_highlight.png"):
		return
	print("HIGHLIGHTS ", highlights, " SEED ", setup.seed_used, " CELL ", cell)
	var mover: PlayerState.UnitState = null
	for candidate in setup.players[setup.human_index].units:
		if candidate.unit_type == "settler":
			mover = candidate
			break
	var dest: Vector2i = setup.reachable_tiles(mover).keys()[0]
	_click(game, dest, MOUSE_BUTTON_RIGHT)
	if setup.human_settler_cell() != dest:
		print("FAIL right click move, still ", setup.human_settler_cell())
		quit(1)
		return
	cell = dest
	_frame(game, cell)
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	if not await _save("/opt/cursor/artifacts/ticket8_after_move.png"):
		return
	print("MOVED ", cell)
	var found := game.get_node("%FoundCityButton") as Button
	if found.disabled:
		print("FAIL Found City disabled: ", (game.get_node("%FoundCityReason") as Label).text)
		quit(1)
		return
	found.pressed.emit()
	_frame(game, cell)
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var cities := 0
	for child in game.get_node("%Actors").get_children():
		if str(child.name).begins_with("City_"):
			cities += 1
	var borders := game.get_node("%Borders").get_child_count()
	if cities < 1 or borders < 1:
		print("FAIL city nodes ", cities, " borders ", borders)
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket8_city_founded.png"):
		return
	print("BORDERS ", borders, " CITIES ", cities)
	quit(0)


func _good_start(setup: GameSetup) -> bool:
	var cell := setup.human_settler_cell()
	if cell.x < 5 or cell.y < 5 or cell.x >= setup.map.width - 5 or cell.y >= setup.map.height - 5:
		return false
	var unit: PlayerState.UnitState = null
	for candidate in setup.players[setup.human_index].units:
		if candidate.unit_type == "settler":
			unit = candidate
			break
	if unit == null:
		return false
	return setup.reachable_tiles(unit).size() >= 1 and setup.can_found(unit).is_empty()


func _frame(game: Node, cell: Vector2i) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var camera := game.get_node("%Camera") as Camera2D
	camera.zoom = Vector2(0.9, 0.9)
	camera.position = map.map_to_local(cell) + Vector2(0, 70)


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
