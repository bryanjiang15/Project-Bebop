extends SceneTree

## Real-renderer shots for ticket 31. Not part of CI.
## Writes the five ticket31_*.png files under /opt/cursor/artifacts.
## Stages a plains disk and spawns a warrior and a scout so the dim reads clearly.
## Does not change HP. AP changes only through move, Sprint, and End Turn.
## Also paints volcanic settlers to plains before End Turn (ticket 30).


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
	for hex in Hex.disk(Hex.offset_to_axial(home), 6):
		var cell := Hex.axial_to_offset(hex)
		if setup.map.in_bounds(cell):
			setup.map.set_land(cell, "plains")
	var step := _step(home, Hex.EAST, 1)
	var last := _step(home, Hex.EAST, 2)
	var warrior := setup.spawn_unit(0, "warrior", home)
	if warrior == null:
		print("FAIL warrior did not spawn")
		quit(1)
		return
	game._refresh_board()
	_frame(game, step, 0.85)
	for _frame in 4:
		await process_frame
	if not _select_unit(game, home, "Warrior"):
		return
	_click(game, step, MOUSE_BUTTON_RIGHT)
	var detail := (game.get_node("%SelectionDetail") as Label).text
	if warrior.cell != step or warrior.ap != 1 or setup.unit_turn_done(warrior) or int(game.get("_selected_id")) != warrior.id or detail.contains("Done") or not _mark_is(game, warrior, 1.0):
		print("FAIL ap left ", warrior.ap, " '", detail, "' alpha ", _alpha(game, warrior))
		quit(1)
		return
	game._clear_hover()
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket31_ap_left.png"):
		return
	var camera := game.get_node("%Camera") as Camera2D
	var cam := camera.position
	var selected := int(game.get("_selected_id"))
	_click(game, last, MOUSE_BUTTON_RIGHT)
	detail = (game.get_node("%SelectionDetail") as Label).text
	if warrior.cell != last or warrior.ap != 0 or not setup.unit_turn_done(warrior) or int(game.get("_selected_id")) != selected or not camera.position.is_equal_approx(cam):
		print("FAIL zero ap move ", warrior.ap, " selected ", game.get("_selected_id"))
		quit(1)
		return
	if not detail.contains("Order Done") or not detail.contains("AP 0 /") or not _mark_is(game, warrior, 0.55) or not _hp_opaque(game, warrior):
		print("FAIL done shot '", detail, "' alpha ", _alpha(game, warrior))
		quit(1)
		return
	game._clear_hover()
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket31_after_zero_ap.png"):
		return
	var scout_home := _step(home, Hex.NORTH, 3)
	var scout := setup.spawn_unit(0, "scout", scout_home)
	if scout == null:
		print("FAIL scout did not spawn")
		quit(1)
		return
	game._refresh_board()
	_frame(game, scout_home, 0.85)
	if not _select_unit(game, scout_home, "Scout"):
		return
	var sprint := SceneDriver.ability_button(game, "sprint")
	sprint.pressed.emit()
	sprint = SceneDriver.ability_button(game, "sprint")
	sprint.pressed.emit()
	detail = (game.get_node("%SelectionDetail") as Label).text
	var ap_text := (game.get_node("%AbilityApLabel") as Label).text
	if scout.ap != 5 or not scout.movement_only or setup.unit_turn_done(scout) or ap_text != "AP 5 / 3" or detail.contains("Done") or not _mark_is(game, scout, 1.0):
		print("FAIL sprint leftover ", ap_text, " '", detail, "' alpha ", _alpha(game, scout))
		quit(1)
		return
	game._clear_hover()
	_frame(game, scout_home, 0.85)
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket31_sprint_leftover.png"):
		return
	var cursor := scout_home
	for _i in 5:
		cursor = _step(cursor, Hex.EAST, 1)
		_click(game, cursor, MOUSE_BUTTON_RIGHT)
		if scout.cell != cursor:
			print("FAIL sprint walk stopped at ", scout.cell, " wanted ", cursor, " ap ", scout.ap)
			quit(1)
			return
	detail = (game.get_node("%SelectionDetail") as Label).text
	if scout.ap != 0 or not scout.movement_only or not setup.unit_turn_done(scout) or int(game.get("_selected_id")) != scout.id or not detail.contains("Order Done") or not _mark_is(game, scout, 0.55):
		print("FAIL sprint spent ap ", scout.ap, " '", detail, "' alpha ", _alpha(game, scout))
		quit(1)
		return
	game._clear_hover()
	_frame(game, cursor, 0.85)
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket31_sprint_spent.png"):
		return
	SceneDriver.spare_settlers(setup, false)
	game._refresh_board()
	var end := game.get_node("%EndTurnButton") as Button
	end.pressed.emit()
	if end.text == "End anyway (Enter)":
		end.pressed.emit()
	if setup.result != null or warrior.ap != 2 or setup.unit_turn_done(warrior) or scout.movement_only or scout.ap != 3:
		print("FAIL next turn warrior ", warrior.ap, " scout ", scout.ap, " only ", scout.movement_only, " result ", setup.result)
		quit(1)
		return
	if not _select_unit(game, last, "Warrior"):
		return
	detail = (game.get_node("%SelectionDetail") as Label).text
	if detail.contains("Done") or not detail.contains("AP 2 / 2") or not _mark_is(game, warrior, 1.0) or not _mark_is(game, scout, 1.0):
		print("FAIL refilled '", detail, "' warrior ", _alpha(game, warrior), " scout ", _alpha(game, scout))
		quit(1)
		return
	game._clear_hover()
	_frame(game, last, 0.85)
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket31_next_turn.png"):
		return
	print("CAPTURE OK")
	quit(0)


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
			for hex in Hex.disk(Hex.offset_to_axial(center), 6):
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


func _hp_opaque(game: Node, unit: PlayerState.UnitState) -> bool:
	var sprite := game.get_node("%Actors").get_node_or_null("Unit_%d" % unit.id) as Node
	if sprite == null:
		return false
	var bar := sprite.get_node_or_null("HpBar") as CanvasItem
	return bar != null and bar.visible and is_equal_approx(bar.modulate.a, 1.0)


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
