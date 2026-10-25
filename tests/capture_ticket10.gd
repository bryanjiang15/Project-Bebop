extends SceneTree

## Real-renderer shots for ticket 10. Not part of CI.
## Writes the three ticket10_topbar_*.png files under /opt/cursor/artifacts.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
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
	if not _bar_text(game, 10, 0, 1):
		return
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _bar_fits(game, "start"):
		return
	if not await _save("/opt/cursor/artifacts/ticket10_topbar_start.png"):
		return
	print("START ", _bar_line(game))
	(game.get_node("%EndTurnButton") as Button).pressed.emit()
	if not _bar_fits(game, "warning"):
		return
	_click(game, setup.human_settler_cell())
	if setup.turn != 1:
		print("FAIL warning press ended the turn")
		quit(1)
		return
	var cell := setup.human_settler_cell()
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
	for _turn in 2:
		if not _end_one(game):
			return
	if city.population != 1:
		print("FAIL population changed before the after-turns shot ", city.population)
		quit(1)
		return
	if not _bar_text(game, 14, 2, 3):
		return
	_click(game, city.cell)
	if not (game.get_node("%CityPanel") as CanvasItem).visible:
		_click(game, city.cell)
	_frame(game, city.cell)
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _bar_fits(game, "after turns"):
		return
	if not await _save("/opt/cursor/artifacts/ticket10_topbar_after_turns.png"):
		return
	print("AFTER ", _bar_line(game), " panel ", (game.get_node("%CityMana") as Label).text)
	var income_before := setup.mana_per_turn(setup.human_index)
	var pool_before := setup.players[setup.human_index].mana
	var real_cost := setup.config.mana_well_cost
	setup.config.mana_well_cost = 2
	var plots: Array[Vector2i] = setup.placement_tiles(city, "mana_well")
	if plots.is_empty():
		print("FAIL no mana well tile")
		quit(1)
		return
	(game.get_node("%BuildManaWell") as Button).pressed.emit()
	_click(game, plots[0])
	var queued := false
	for item in city.queue:
		if item.item_id == "mana_well" and item.cell == plots[0]:
			queued = true
	if not queued:
		print("FAIL mana well not queued ", (game.get_node("%CityReason") as Label).text)
		quit(1)
		return
	if not _end_one(game):
		return
	var built := false
	for building in city.buildings:
		if building.kind == "mana_well" and building.cell == plots[0]:
			built = true
	if not built:
		print("FAIL mana well did not finish")
		quit(1)
		return
	if city.population != 1:
		print("FAIL population changed when the well finished ", city.population)
		quit(1)
		return
	if setup.players[setup.human_index].mana != pool_before + income_before:
		print("FAIL pool ", setup.players[setup.human_index].mana)
		quit(1)
		return
	if setup.mana_per_turn(setup.human_index) != income_before + 2:
		print("FAIL gain ", setup.mana_per_turn(setup.human_index))
		quit(1)
		return
	if not _bar_text(game, pool_before + income_before, income_before + 2, 4):
		return
	var panel := (game.get_node("%CityMana") as Label).text
	if panel != "Mana %d" % (income_before + 2):
		print("FAIL panel ", panel)
		quit(1)
		return
	setup.config.mana_well_cost = real_cost
	game._refresh_board()
	_frame(game, plots[0])
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	if not _bar_fits(game, "mana well"):
		return
	if not await _save("/opt/cursor/artifacts/ticket10_topbar_mana_well.png"):
		return
	print("WELL ", _bar_line(game), " panel ", panel, " at ", plots[0])
	quit(0)


func _end_one(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var before := setup.turn
	var button := game.get_node("%EndTurnButton") as Button
	button.pressed.emit()
	if setup.turn == before:
		button.pressed.emit()
	if setup.turn != before + 1:
		print("FAIL turn stayed ", setup.turn)
		quit(1)
		return false
	return true


func _bar_text(game: Node, pool: int, gain: int, turn: int) -> bool:
	var mana := (game.get_node("%ManaLabel") as Label).text
	var shown := (game.get_node("%TurnLabel") as Label).text
	var caption := (game.get_node("UI/TopBar/Row/TurnCaption") as Label).text
	if mana != "Mana: %d (+%d/turn)" % [pool, gain] or shown != "%d / 50" % turn or caption != "Turn":
		print("FAIL bar mana='", mana, "' turn='", caption, " ", shown, "' expected ", pool, " ", gain, " turn ", turn)
		quit(1)
		return false
	return true


func _bar_line(game: Node) -> String:
	var caption := (game.get_node("UI/TopBar/Row/TurnCaption") as Label).text
	var turn := (game.get_node("%TurnLabel") as Label).text
	var mana := (game.get_node("%ManaLabel") as Label).text
	return caption + " " + turn + " | " + mana


func _bar_fits(game: Node, label: String) -> bool:
	var row := game.get_node("UI/TopBar/Row") as Control
	var prev := -1.0
	for child in row.get_children():
		var rect := (child as Control).get_global_rect()
		if rect.position.x < prev - 1.0:
			print("FAIL ", label, " overlap ", child.name, " ", rect)
			quit(1)
			return false
		if rect.end.x > 2560.5:
			print("FAIL ", label, " past edge ", child.name, " ", rect)
			quit(1)
			return false
		prev = rect.end.x
	var bar := (game.get_node("UI/TopBar") as Control).get_global_rect()
	if bar.position.y > 1.0 or bar.end.y > 140.0:
		print("FAIL ", label, " top bar ", bar)
		quit(1)
		return false
	return true


func _frame(game: Node, cell: Vector2i) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var camera := game.get_node("%Camera") as Camera2D
	camera.zoom = Vector2(0.85, 0.85)
	camera.position = map.map_to_local(cell) + Vector2(220, -80)


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
