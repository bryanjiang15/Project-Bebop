extends SceneTree

## Real-renderer shots for ticket 32. Not part of CI.
## Writes the six ticket32_*.png files under /opt/cursor/artifacts.
## Stages a plains disk, parks the starting units at 0 AP, then fortifies them
## so the queue is three spawned warriors. AP on those warriors changes only
## through move, Fortify, Skip, and End Turn. Paints volcanic settlers to
## plains before the last End Turn (ticket 30). Zooms the camera to 0.9 so the
## three warriors fit; the top bar stays on the screen.


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
	var home := _open_home(setup)
	if home.x < 0:
		print("FAIL no open disk")
		quit(1)
		return
	for hex in Hex.disk(Hex.offset_to_axial(home), 4):
		var cell := Hex.axial_to_offset(hex)
		if setup.map.in_bounds(cell):
			setup.map.set_land(cell, "plains")
	if not _fortify_existing(game, setup):
		return
	var east := _step(home, Hex.EAST, 3)
	var west := _step(home, Hex.WEST, 3)
	var south := _step(home, Hex.SOUTHEAST, 1)
	var last := _step(south, Hex.SOUTHEAST, 1)
	var first := setup.spawn_unit(0, "warrior", home)
	var second := setup.spawn_unit(0, "warrior", east)
	var third := setup.spawn_unit(0, "warrior", west)
	if first == null or second == null or third == null:
		print("FAIL warriors did not spawn")
		quit(1)
		return
	game._refresh_board()
	if not _select_unit(game, home, "Warrior"):
		return
	_frame(game, home, 0.9)
	for _frame in 3:
		await process_frame
	var end := game.get_node("%EndTurnButton") as Button
	if end.text != "3 units need orders (Enter)" or int(game.get("_selected_id")) != first.id:
		print("FAIL queue start '", end.text, "' selected ", game.get("_selected_id"))
		quit(1)
		return
	game._clear_hover()
	if not await _save("/opt/cursor/artifacts/ticket32_queue_start.png"):
		return
	_click(game, south, MOUSE_BUTTON_RIGHT)
	_click(game, last, MOUSE_BUTTON_RIGHT)
	if first.ap != 0 or int(game.get("_selected_id")) != second.id or not _mark_is(game, first, 0.55):
		print("FAIL after finish ap ", first.ap, " selected ", game.get("_selected_id"), " alpha ", _alpha(game, first))
		quit(1)
		return
	game._clear_hover()
	_frame(game, second.cell, 0.9)
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket32_after_finish.png"):
		return
	(game.get_node("%NextUnitButton") as Button).pressed.emit()
	if int(game.get("_selected_id")) != third.id or setup.turn != 1:
		print("FAIL next unit selected ", game.get("_selected_id"), " turn ", setup.turn)
		quit(1)
		return
	game._clear_hover()
	_frame(game, third.cell, 0.9)
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket32_next_unit.png"):
		return
	var turn := setup.turn
	var needing := setup.units_needing_orders(setup.human_index).size()
	end.pressed.emit()
	if setup.turn != turn or end.text != "End anyway (Enter)" or int(game.get("_selected_id")) != second.id or setup.units_needing_orders(setup.human_index).size() != needing:
		print("FAIL enter jump turn ", setup.turn, " '", end.text, "' selected ", game.get("_selected_id"))
		quit(1)
		return
	game._clear_hover()
	_frame(game, second.cell, 0.9)
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket32_enter_jumps.png"):
		return
	_click(game, second.cell)
	if not _select_unit(game, west, "Warrior"):
		return
	SceneDriver.order_button(game, "fortify").pressed.emit()
	if not third.fortified or setup.unit_needs_orders(third) or int(game.get("_selected_id")) == third.id:
		print("FAIL fortify selected ", game.get("_selected_id"))
		quit(1)
		return
	game._clear_hover()
	_frame(game, home, 0.9)
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket32_fortify_out.png"):
		return
	if not _select_unit(game, second.cell, "Warrior"):
		return
	SceneDriver.order_button(game, "skip").pressed.emit()
	end = game.get_node("%EndTurnButton") as Button
	if end.text != "End Turn (Enter)" or not (game.get_node("%EndTurnWarning") as Label).text.is_empty():
		print("FAIL empty queue '", end.text, "'")
		quit(1)
		return
	SceneDriver.spare_settlers(setup, false)
	game._refresh_board()
	end.pressed.emit()
	if setup.turn != turn + 1 or setup.result != null:
		print("FAIL enter did not end turn ", setup.turn, " result ", setup.result)
		quit(1)
		return
	var opening := setup.units_needing_orders(setup.human_index)
	if opening.is_empty() or int(game.get("_selected_id")) != opening[0].id or setup.unit_needs_orders(third):
		print("FAIL opening selected ", game.get("_selected_id"), " fortified still in ", setup.unit_needs_orders(third))
		quit(1)
		return
	game._clear_hover()
	_frame(game, opening[0].cell, 0.9)
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket32_enter_ends.png"):
		return
	print("CAPTURE OK")
	quit(0)


func _fortify_existing(game: Node, setup: GameSetup) -> bool:
	var pending: Array[PlayerState.UnitState] = []
	for unit in setup.players[setup.human_index].units:
		pending.append(unit)
	for unit in pending:
		unit.ap = 1
		unit.order = ""
		unit.fortified = false
		game._refresh_board()
		if not _select_unit(game, unit.cell, unit.unit_type.capitalize()):
			return false
		var fortify := SceneDriver.order_button(game, "fortify")
		if fortify == null:
			print("FAIL no fortify for ", unit.unit_type)
			quit(1)
			return false
		fortify.pressed.emit()
		if not unit.fortified:
			print("FAIL could not fortify ", unit.unit_type)
			quit(1)
			return false
	return true


func _select_unit(game: Node, cell: Vector2i, title: String) -> bool:
	_click(game, cell)
	if (game.get_node("%SelectionTitle") as Label).text != title:
		_click(game, cell)
	if (game.get_node("%SelectionTitle") as Label).text != title or int(game.get("_selected_id")) < 0:
		print("FAIL selected ", (game.get_node("%SelectionTitle") as Label).text, " wanted ", title)
		quit(1)
		return false
	return true


func _open_home(setup: GameSetup) -> Vector2i:
	for row in range(6, setup.map.height - 6):
		for col in range(6, setup.map.width - 6):
			var center := Vector2i(col, row)
			var open := true
			for hex in Hex.disk(Hex.offset_to_axial(center), 4):
				var cell := Hex.axial_to_offset(hex)
				if not setup.map.in_bounds(cell) or _occupied(setup, cell) or setup.city_at_cell(cell) != null:
					open = false
					break
			if open:
				return center
	return Vector2i(-1, -1)


func _occupied(setup: GameSetup, cell: Vector2i) -> bool:
	for player in setup.players:
		for unit in player.units:
			if unit.cell == cell:
				return true
	return false


func _frame(game: Node, cell: Vector2i, zoom: float) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var camera := game.get_node("%Camera") as Camera2D
	camera.zoom = Vector2(zoom, zoom)
	camera.position = map.map_to_local(cell) + Vector2(0, 40)
	game._clamp_camera()


func _step(cell: Vector2i, direction: int, steps: int) -> Vector2i:
	var axial := Hex.offset_to_axial(cell)
	for _i in steps:
		axial = Hex.neighbor(axial, direction)
	return Hex.axial_to_offset(axial)


func _click(game: Node, cell: Vector2i, button_index: int = MOUSE_BUTTON_LEFT) -> void:
	SceneDriver.click_cell(game, cell, button_index)


func _alpha(game: Node, unit: PlayerState.UnitState) -> float:
	var sprite := game.get_node("%Actors").get_node_or_null("Unit_%d" % unit.id) as CanvasItem
	if sprite == null:
		return -1.0
	return sprite.self_modulate.a


func _mark_is(game: Node, unit: PlayerState.UnitState, alpha: float) -> bool:
	return is_equal_approx(_alpha(game, unit), alpha)


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
