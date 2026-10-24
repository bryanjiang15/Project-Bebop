extends SceneTree

## Real-renderer shots for ticket 9. Not part of CI.
## Writes /opt/cursor/artifacts/ticket9_city_panel.png and ticket9_border_or_build.png.


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
		print("FAIL no inset city site")
		quit(1)
		return
	var cell := setup.human_settler_cell()
	_click(game, cell)
	var found := game.get_node("%FoundCityButton") as Button
	if found.disabled:
		print("FAIL cannot found")
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
	if city.queue.is_empty() or city.queue[0].item_id != "scout":
		print("FAIL scout not queued ", (game.get_node("%CityReason") as Label).text)
		quit(1)
		return
	for _turn in 2:
		(game.get_node("%EndTurnButton") as Button).pressed.emit()
	if not _labels_match(game, city):
		return
	_frame(game, city.cell)
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	if not await _save("/opt/cursor/artifacts/ticket9_city_panel.png"):
		return
	print("PANEL ", (game.get_node("%CityFood") as Label).text, " ", (game.get_node("%CityProduction") as Label).text, " ", (game.get_node("%CityMana") as Label).text)
	print("GROWTH ", (game.get_node("%GrowthLabel") as Label).text, " ", (game.get_node("%BorderLabel") as Label).text)
	print("QUEUE ", (game.get_node("%QueueList").get_child(0).get_node("ItemLabel") as Label).text)
	var plots: Array[Vector2i] = setup.placement_tiles(city, "granary")
	if plots.is_empty():
		print("FAIL no granary tile")
		quit(1)
		return
	var plot := plots[0]
	(game.get_node("%BuildGranary") as Button).pressed.emit()
	_click(game, plot)
	var queued := false
	for item in city.queue:
		if item.item_id == "granary" and item.cell == plot and plot != city.cell:
			queued = true
	if not queued:
		print("FAIL granary not placed ", (game.get_node("%CityReason") as Label).text)
		quit(1)
		return
	var built := false
	for _turn in 80:
		for building in city.buildings:
			if building.kind == "granary" and building.cell == plot:
				built = true
		if built:
			break
		(game.get_node("%EndTurnButton") as Button).pressed.emit()
	if not built:
		print("FAIL granary never finished")
		quit(1)
		return
	var marker := false
	for child in game.get_node("%Actors").get_children():
		if str(child.name).begins_with("Building_"):
			marker = true
	if not marker:
		print("FAIL building marker missing")
		quit(1)
		return
	_frame(game, plot)
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	if not await _save("/opt/cursor/artifacts/ticket9_border_or_build.png"):
		return
	print("BUILT granary at ", plot, " radius ", city.radius, " tiles ", setup.territory_cells(city).size(), " seed ", setup.seed_used)
	quit(0)


func _labels_match(game: Node, city: MapCity) -> bool:
	var setup := game.get("setup") as GameSetup
	var yields: Dictionary = setup.city_yields(city)
	var food := (game.get_node("%CityFood") as Label).text
	var prod := (game.get_node("%CityProduction") as Label).text
	var mana := (game.get_node("%CityMana") as Label).text
	var growth := (game.get_node("%GrowthLabel") as Label).text
	var bar := game.get_node("%GrowthBar") as ProgressBar
	if food != "Food %d" % int(yields["food"]) or prod != "Production %d" % int(yields["production"]) or mana != "Mana %d" % int(yields["mana"]):
		print("FAIL labels ", food, prod, mana, yields)
		quit(1)
		return false
	if not growth.contains("%d / %d" % [city.food_stored, int(yields["threshold"])]):
		print("FAIL growth ", growth)
		quit(1)
		return false
	if int(bar.value) != city.food_stored:
		print("FAIL bar ", bar.value, " stored ", city.food_stored)
		quit(1)
		return false
	if game.get_node("%QueueList").get_child_count() < 1:
		print("FAIL empty queue")
		quit(1)
		return false
	return true


func _good_start(setup: GameSetup) -> bool:
	var cell := setup.human_settler_cell()
	if cell.x < 6 or cell.y < 6 or cell.x >= setup.map.width - 6 or cell.y >= setup.map.height - 6:
		return false
	for candidate in setup.players[setup.human_index].units:
		if candidate.unit_type == "settler":
			return setup.can_found(candidate).is_empty()
	return false


func _frame(game: Node, cell: Vector2i) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var camera := game.get_node("%Camera") as Camera2D
	camera.zoom = Vector2(0.85, 0.85)
	camera.position = map.map_to_local(cell) + Vector2(220, 30)


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
