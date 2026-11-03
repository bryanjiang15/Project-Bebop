extends SceneTree

## Real-renderer shots for the in-progress building marker. Not part of CI.
## Writes ticket23_queued.png, ticket23_finished.png, ticket23_cancelled.png,
## and ticket23_flooded.png at 2560×1440.


const LOG_DIR := "/tmp/bebop-ticket23-logs"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	GameLog.directory_override = LOG_DIR
	_size_window()
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
	var placed: Dictionary = _place(setup)
	if not bool(placed["ok"]):
		print("FAIL fixture ", placed["reason"])
		quit(1)
		return
	game._refresh_board()
	var city := placed["city"] as MapCity
	var story: Vector2i = placed["story"]
	var contrast: Vector2i = placed["contrast"]
	var flood: Vector2i = placed["flood"]
	_aim(game, city.cell)
	if not _select_city(game, city.cell):
		return
	# A finished building sits beside the story tile so the outline reads against it.
	setup.config.granary_cost = 1
	if not _queue(game, city, "granary", contrast):
		return
	if not _end_turn(game):
		return
	if not _has_building(city, "granary", contrast):
		print("FAIL contrast granary did not finish")
		quit(1)
		return
	if not _queue(game, city, "lumber_mill", story):
		return
	_aim(game, city.cell)
	_present(game)
	for _frame in 2:
		await process_frame
	if not _expect_construction(game, city.id, story, "lumber_mill"):
		return
	var row := (game.get_node("%QueueList").get_child(0).get_node("ItemLabel") as Label).text
	if not row.begins_with("Lumber") or not (game.get_node("%CityPanel") as CanvasItem).visible:
		print("FAIL queue row '", row, "'")
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket23_queued.png"):
		return
	(game.get_node("%QueueList").get_child(0).get_node("CancelButton") as Button).pressed.emit()
	await process_frame
	_aim(game, city.cell)
	_present(game)
	for _frame in 2:
		await process_frame
	if game.get_node("%QueueList").get_child_count() != 0 or _actors_has(game, _marker("Construction", city.id, story)):
		print("FAIL cancel left the marker or the row")
		quit(1)
		return
	if not _actors_has(game, _marker("Building", city.id, contrast)):
		print("FAIL contrast building disappeared on cancel")
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket23_cancelled.png"):
		return
	setup.config.lumber_mill_cost = 1
	if not _queue(game, city, "lumber_mill", story):
		return
	if not _end_turn(game):
		return
	_aim(game, city.cell)
	_present(game)
	for _frame in 2:
		await process_frame
	if not _has_building(city, "lumber_mill", story) or _actors_has(game, _marker("Construction", city.id, story)):
		print("FAIL lumber mill did not replace the construction marker")
		quit(1)
		return
	if not _actors_has(game, _marker("Building", city.id, story)):
		print("FAIL finished lumber mill has no marker")
		quit(1)
		return
	var finished := game.get_node("%Actors").get_node(_marker("Building", city.id, story))
	if (finished.get_node("Name") as Label).text != "Lumber Mill":
		print("FAIL finished label ", (finished.get_node("Name") as Label).text)
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket23_finished.png"):
		return
	if not _queue(game, city, "granary", flood):
		return
	var human := setup.players[setup.human_index]
	human.mana = 80
	human.casts_this_turn = 0
	human.spell_cooldowns.clear()
	(game.get_node("%SpellButtons").get_node("Spell_carve_river") as Button).pressed.emit()
	SceneDriver.click_cell(game, flood)
	_aim(game, city.cell)
	_present(game)
	for _frame in 2:
		await process_frame
	if setup.map.land_at(flood) != "water" or _queue_has(city, "granary", flood):
		print("FAIL flood land ", setup.map.land_at(flood), " still queued ", _queue_has(city, "granary", flood))
		quit(1)
		return
	if _actors_has(game, _marker("Construction", city.id, flood)):
		print("FAIL flood left the construction marker")
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket23_flooded.png"):
		return
	print("CAPTURE OK")
	quit(0)


func _place(setup: GameSetup) -> Dictionary:
	var settler: PlayerState.UnitState = null
	var warrior: PlayerState.UnitState = null
	for unit in setup.players[setup.human_index].units:
		if unit.unit_type == "settler":
			settler = unit
		elif unit.unit_type == "warrior":
			warrior = unit
	if settler == null or warrior == null:
		return {"ok": false, "reason": "missing a starting unit"}
	var origin := Vector2i(10, 8)
	var story := _step(origin, Hex.NORTHEAST, 1)
	var contrast := _step(origin, Hex.NORTHWEST, 1)
	var flood := _step(origin, Hex.EAST, 1)
	var stand := _step(origin, Hex.WEST, 1)
	if not setup.map.in_bounds(stand) or not setup.map.in_bounds(flood):
		return {"ok": false, "reason": "fixture left the map"}
	for hex in Hex.disk(Hex.offset_to_axial(origin), 3):
		var cell := Hex.axial_to_offset(hex as Vector2i)
		if setup.map.in_bounds(cell):
			setup.map.set_land(cell, "plains")
	var reserved := {origin: true, story: true, contrast: true, flood: true, stand: true}
	var park := Vector2i.ZERO
	for player in setup.players:
		for unit in player.units:
			while reserved.has(park) or not setup.map.in_bounds(park):
				park.x += 1
				if park.x >= setup.map.width:
					park = Vector2i(0, park.y + 1)
				if park.y >= setup.map.height:
					return {"ok": false, "reason": "no park tile"}
			unit.cell = park
			reserved[park] = true
			park.x += 1
	settler.cell = origin
	warrior.cell = stand
	var why := setup.can_found(settler)
	if not why.is_empty():
		return {"ok": false, "reason": why}
	var city := setup.found_city(settler)
	if city == null:
		return {"ok": false, "reason": "city did not found"}
	setup._refresh_fog()
	return {
		"ok": true,
		"reason": "",
		"city": city,
		"story": story,
		"contrast": contrast,
		"flood": flood,
		"stand": stand,
	}


func _select_city(game: Node, cell: Vector2i) -> bool:
	var panel := game.get_node("%CityPanel") as CanvasItem
	var title := game.get_node("%SelectionTitle") as Label
	SceneDriver.click_cell(game, cell)
	if not panel.visible or title.text != "No unit selected":
		SceneDriver.click_cell(game, cell)
	if not panel.visible or title.text != "No unit selected":
		print("FAIL city was not selected")
		quit(1)
		return false
	return true


func _queue(game: Node, city: MapCity, item_id: String, cell: Vector2i) -> bool:
	if not _select_city(game, city.cell):
		return false
	var button := "%BuildGranary"
	if item_id == "lumber_mill":
		button = "%BuildLumberMill"
	(game.get_node(button) as Button).pressed.emit()
	SceneDriver.click_cell(game, cell)
	if not _queue_has(city, item_id, cell):
		print("FAIL ", item_id, " not queued '", (game.get_node("%CityReason") as Label).text, "'")
		quit(1)
		return false
	return true


func _end_turn(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	SceneDriver.spare_settlers(setup, false)
	var before := setup.turn
	var button := game.get_node("%EndTurnButton") as Button
	button.pressed.emit()
	if setup.turn == before:
		button.pressed.emit()
	if setup.turn != before + 1 or setup.result != null:
		print("FAIL end turn stayed on ", setup.turn, " result ", setup.result)
		quit(1)
		return false
	return true


func _present(game: Node) -> void:
	var menu := game.get_node("%InGameMenu") as CanvasItem
	if menu.visible:
		(game.get_node("%MenuButton") as Button).pressed.emit()
	if game.has_method("_clear_hover"):
		game._clear_hover()


func _aim(game: Node, cell: Vector2i) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var camera := game.get_node("%Camera") as Camera2D
	var local: Vector2 = map.map_to_local(cell)
	var zoom := 1.45
	var screen_point := Vector2(980, 580)
	camera.zoom = Vector2(zoom, zoom)
	camera.position = local - (screen_point - Vector2(1280, 720)) / zoom
	game._clamp_camera()


func _step(cell: Vector2i, direction: int, steps: int) -> Vector2i:
	var axial := Hex.offset_to_axial(cell)
	for _i in steps:
		axial = Hex.neighbor(axial, direction)
	return Hex.axial_to_offset(axial)


func _has_building(city: MapCity, kind: String, cell: Vector2i) -> bool:
	for building in city.buildings:
		if building.kind == kind and building.cell == cell:
			return true
	return false


func _queue_has(city: MapCity, item_id: String, cell: Vector2i) -> bool:
	for item in city.queue:
		if item.item_id == item_id and item.is_building and item.cell == cell:
			return true
	return false


func _expect_construction(game: Node, city_id: int, cell: Vector2i, item_id: String) -> bool:
	var node := game.get_node("%Actors").get_node_or_null(_marker("Construction", city_id, cell))
	if node == null:
		print("FAIL missing construction marker on ", cell)
		quit(1)
		return false
	var label := (node.get_node("Name") as Label).text
	var expected := "%s (building)" % item_id.capitalize()
	if label != expected:
		print("FAIL label '", label, "' expected ", expected)
		quit(1)
		return false
	return true


func _actors_has(game: Node, node_name: String) -> bool:
	return game.get_node("%Actors").get_node_or_null(node_name) != null


func _marker(prefix: String, city_id: int, cell: Vector2i) -> String:
	return "%s_%d_%d_%d" % [prefix, city_id, cell.x, cell.y]


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
	return await SceneDriver.wait_for(self, script_path, 80)
