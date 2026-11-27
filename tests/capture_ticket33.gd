extends SceneTree

## Real-renderer shots for ticket 33. Not part of CI.
## Writes ticket33_*.png under /opt/cursor/artifacts.
## Stages: park starting units at 0 AP, found a city with an empty queue, then
## walk Next Unit / queue a warrior. Zooms the camera so the city and panel read.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	DirAccess.make_dir_recursive_absolute("/tmp/bebop-capture-logs")
	GameLog.directory_override = "/tmp/bebop-capture-logs"
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
		print("FAIL no setup")
		quit(1)
		return
	for unit in setup.players[setup.human_index].units:
		unit.ap = 0
		unit.order = GameSetup.ORDER_SKIP
	var settler := _human_settler(setup)
	if settler == null:
		print("FAIL no settler")
		quit(1)
		return
	for hex in Hex.disk(Hex.offset_to_axial(settler.cell), 2):
		var cell := Hex.axial_to_offset(hex)
		if setup.map.in_bounds(cell):
			setup.map.set_land(cell, "plains")
	settler.ap = 1
	settler.order = ""
	game._refresh_board()
	if not _select_unit(game, settler.cell, "Settler"):
		return
	SceneDriver.order_button(game, "found").pressed.emit()
	var city: MapCity = null
	for candidate in setup.cities:
		if candidate.player == setup.human_index:
			city = candidate
			break
	if city == null or not setup.city_needs_orders(city):
		print("FAIL founded city missing or not idle")
		quit(1)
		return
	for unit in setup.players[setup.human_index].units:
		unit.ap = 0
		unit.order = GameSetup.ORDER_SKIP
	game._selected_id = -1
	game._selected_city_id = -1
	game._refresh_board()
	var end := game.get_node("%EndTurnButton") as Button
	if end.text != "1 needs orders (Enter)":
		print("FAIL idle city count '", end.text, "'")
		quit(1)
		return
	_frame(game, city.cell, 0.9)
	for _frame in 3:
		await process_frame
	game._clear_hover()
	if not await _save("/opt/cursor/artifacts/ticket33_idle_city_count.png"):
		return
	(game.get_node("%NextUnitButton") as Button).pressed.emit()
	if int(game.get("_selected_city_id")) != city.id or not (game.get_node("%CityPanel") as PanelContainer).visible:
		print("FAIL Next Unit did not open the city panel")
		quit(1)
		return
	_frame(game, city.cell, 0.9)
	for _frame in 3:
		await process_frame
	game._clear_hover()
	if not await _save("/opt/cursor/artifacts/ticket33_city_in_queue.png"):
		return
	(game.get_node("%BuildWarrior") as Button).pressed.emit()
	if setup.city_needs_orders(city) or city.queue.is_empty():
		print("FAIL queueing left the city idle")
		quit(1)
		return
	game._refresh_board()
	_frame(game, city.cell, 0.9)
	for _frame in 3:
		await process_frame
	game._clear_hover()
	if not await _save("/opt/cursor/artifacts/ticket33_after_queue.png"):
		return
	print("CAPTURE OK")
	quit(0)


func _human_settler(setup: GameSetup) -> PlayerState.UnitState:
	for unit in setup.players[setup.human_index].units:
		if unit.unit_type == "settler":
			return unit
	return null


func _select_unit(game: Node, cell: Vector2i, title: String) -> bool:
	_click(game, cell)
	if (game.get_node("%SelectionTitle") as Label).text != title:
		_click(game, cell)
	if (game.get_node("%SelectionTitle") as Label).text != title or int(game.get("_selected_id")) < 0:
		print("FAIL selected ", (game.get_node("%SelectionTitle") as Label).text, " wanted ", title)
		quit(1)
		return false
	return true


func _frame(game: Node, cell: Vector2i, zoom: float) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var camera := game.get_node("%Camera") as Camera2D
	camera.zoom = Vector2(zoom, zoom)
	camera.position = map.map_to_local(cell) + Vector2(0, 40)
	game._clamp_camera()


func _click(game: Node, cell: Vector2i, button_index: int = MOUSE_BUTTON_LEFT) -> void:
	SceneDriver.click_cell(game, cell, button_index)


func _save(path: String) -> bool:
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
