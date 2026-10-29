extends SceneTree

## Real-renderer shots for ticket 15. Not part of CI.
## Writes the four ticket15_*.png files under /opt/cursor/artifacts.


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
	print("WINDOW ", DisplayServer.window_get_size(), " SCREEN ", DisplayServer.screen_get_size())
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
		print("FAIL no framed start")
		quit(1)
		return
	var warrior := _human_unit(setup, "warrior")
	if warrior == null:
		print("FAIL no warrior")
		quit(1)
		return
	var city_cell := _open_neighbor(setup, warrior.cell)
	setup.map.set_land(city_cell, "plains")
	setup.map.set_land(warrior.cell, "plains")
	var rival := 0 if setup.human_index != 0 else 1
	var founder: PlayerState.UnitState = null
	for unit in setup.players[rival].units:
		if unit.unit_type == "settler":
			founder = unit
			break
	if founder == null:
		print("FAIL no rival settler")
		quit(1)
		return
	founder.cell = city_cell
	var city := setup.found_city(founder)
	if city == null or city.hp != city.max_hp:
		print("FAIL rival city")
		quit(1)
		return
	game._refresh_board()
	_frame(game, city.cell)
	for _frame in 4:
		await process_frame
	_click(game, warrior.cell)
	if (game.get_node("%SelectionTitle") as Label).text != "Warrior":
		_click(game, warrior.cell)
	if (game.get_node("%SelectionTitle") as Label).text != "Warrior":
		print("FAIL selection")
		quit(1)
		return
	_hover(game, city.cell, Vector2(1680, 420))
	var preview := (game.get_node("%CombatPreview") as Label).text
	var tip := (game.get_node("%Tooltip") as Label).text
	var dealt := int(setup.preview_city(warrior, city)["damage"])
	var counter := int(setup.preview_city(warrior, city)["counter"])
	var line := "Damage %d   Counter %d" % [dealt, counter]
	if preview != line or not tip.contains(line) or not _has_attack_highlight(game):
		print("FAIL preview '", preview, "' tip '", tip, "'")
		quit(1)
		return
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket15_city_attack_preview.png"):
		return
	print("PREVIEW ", preview, " marker ", city.hp, "/", city.max_hp)
	var home := warrior.cell
	city.hp = dealt
	game._refresh_board()
	_click(game, city.cell, MOUSE_BUTTON_RIGHT)
	if city.hp != 0 or city.player != rival or warrior.cell != home:
		print("FAIL zero hp ", city.hp, " owner ", city.player, " cell ", warrior.cell)
		quit(1)
		return
	game._clear_hover()
	_frame(game, city.cell)
	for _frame in 4:
		await process_frame
	if not _marker_hp(game, city).begins_with("0 / "):
		print("FAIL marker ", _marker_hp(game, city))
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket15_city_zero_hp.png"):
		return
	print("ZERO ", _marker_hp(game, city))
	_end_turn(game)
	if city.hp != 0:
		print("FAIL healed to ", city.hp)
		quit(1)
		return
	_click(game, warrior.cell)
	if (game.get_node("%SelectionTitle") as Label).text != "Warrior":
		_click(game, warrior.cell)
	_click(game, city.cell, MOUSE_BUTTON_RIGHT)
	if city.player != setup.human_index or warrior.cell != city.cell or warrior.mp != 0:
		print("FAIL capture ", city.player, " ", warrior.cell, " mp ", warrior.mp)
		quit(1)
		return
	game._clear_hover()
	_frame(game, city.cell)
	for _frame in 4:
		await process_frame
	var mana := (game.get_node("%ManaLabel") as Label).text
	var expect := "Mana: %d (+%d/turn)" % [setup.players[setup.human_index].mana, setup.mana_per_turn(setup.human_index)]
	if mana != expect or city.hp != roundi(float(city.max_hp) * setup.config.capture_hp_fraction):
		print("FAIL after capture mana '", mana, "' hp ", city.hp)
		quit(1)
		return
	if (game.get_node("%CityPanel") as CanvasItem).visible:
		print("FAIL city panel open")
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket15_after_capture.png"):
		return
	print("CAPTURED ", city.city_name, " ", mana, " ", _marker_hp(game, city))
	_end_turn(game)
	var bystander := _human_unit(setup, "settler")
	if bystander != null:
		var parked := _far_tile(setup, city.cell)
		if parked.x < 0:
			print("FAIL no tile for the starting settler")
			quit(1)
			return
		bystander.cell = parked
	var settler_cell := _open_neighbor(setup, warrior.cell)
	if settler_cell.x < 0:
		print("FAIL no settler tile")
		quit(1)
		return
	setup.map.set_land(settler_cell, "plains")
	var settler := setup.spawn_unit(rival, "settler", settler_cell)
	if settler == null:
		print("FAIL settler spawn")
		quit(1)
		return
	game._refresh_board()
	if (game.get_node("%SelectionTitle") as Label).text != "Warrior":
		_click(game, warrior.cell)
	if (game.get_node("%SelectionTitle") as Label).text != "Warrior":
		print("FAIL warrior not selected for the settler")
		quit(1)
		return
	if (game.get_node("%CityPanel") as CanvasItem).visible:
		print("FAIL city panel open before the settler capture")
		quit(1)
		return
	_click(game, settler_cell, MOUSE_BUTTON_RIGHT)
	if settler.owner != setup.human_index or settler.cell != warrior.cell or warrior.mp != 0:
		print("FAIL settler ", settler.owner, " ", settler.cell, " mp ", warrior.mp)
		quit(1)
		return
	game._clear_hover()
	_frame(game, warrior.cell, 1.7)
	for _frame in 4:
		await process_frame
	if (game.get_node("%CityPanel") as CanvasItem).visible:
		print("FAIL city panel covered the settler")
		quit(1)
		return
	if _units_on_cell(game, setup, warrior.cell) != 2:
		print("FAIL stack draw ", _units_on_cell(game, setup, warrior.cell))
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket15_settler_captured.png"):
		return
	print("SETTLER stacked on ", warrior.cell)
	quit(0)


func _end_turn(game: Node) -> void:
	(game.get_node("%EndTurnButton") as Button).pressed.emit()
	if not (game.get_node("%EndTurnWarning") as Label).text.is_empty():
		(game.get_node("%EndTurnButton") as Button).pressed.emit()


func _far_tile(setup: GameSetup, origin: Vector2i) -> Vector2i:
	var origin_axial := Hex.offset_to_axial(origin)
	var best := Vector2i(-1, -1)
	var best_dist := -1
	for y in setup.map.height:
		for x in setup.map.width:
			var cell := Vector2i(x, y)
			if setup.map.land_at(cell) == "water":
				continue
			if setup.city_at_cell(cell) != null:
				continue
			var occupied := false
			for player in setup.players:
				for unit in player.units:
					if unit.cell == cell:
						occupied = true
			if occupied:
				continue
			var dist := Hex.distance(origin_axial, Hex.offset_to_axial(cell))
			if dist > best_dist:
				best_dist = dist
				best = cell
	return best


func _units_on_cell(game: Node, setup: GameSetup, cell: Vector2i) -> int:
	var ids := {}
	for player in setup.players:
		for unit in player.units:
			if unit.cell == cell:
				ids[unit.id] = true
	var drawn := 0
	for child in game.get_node("%Actors").get_children():
		var name := str(child.name)
		if not name.begins_with("Unit_"):
			continue
		var id := int(name.trim_prefix("Unit_"))
		if ids.has(id):
			drawn += 1
	return drawn


func _marker_hp(game: Node, city: MapCity) -> String:
	for child in game.get_node("%Actors").get_children():
		if str(child.name) == "City_%d" % city.id:
			return (child.get_node("Hp") as Label).text
	return ""


func _good_start(setup: GameSetup) -> bool:
	var cell := setup.human_settler_cell()
	if cell.x < 4 or cell.y < 3 or cell.x >= setup.map.width - 4 or cell.y >= setup.map.height - 3:
		return false
	return _open_neighbor(setup, _human_unit(setup, "warrior").cell).x >= 0


func _frame(game: Node, cell: Vector2i, zoom: float = 1.15) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var camera := game.get_node("%Camera") as Camera2D
	camera.zoom = Vector2(zoom, zoom)
	camera.position = map.map_to_local(cell) + Vector2(0, 70.0 if zoom > 1.4 else 160.0)
	game._clamp_camera()


func _hover(game: Node, cell: Vector2i, tip_screen: Vector2) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	game.hover_at_local(map.map_to_local(cell), tip_screen)


func _has_attack_highlight(game: Node) -> bool:
	for child in game.get_node("%MoveHighlights").get_children():
		var tint := (child as CanvasItem).modulate
		if tint.r > tint.g and tint.r > tint.b:
			return true
	return false


func _human_unit(setup: GameSetup, unit_type: String) -> PlayerState.UnitState:
	if setup == null:
		return null
	for unit in setup.players[setup.human_index].units:
		if unit.unit_type == unit_type:
			return unit
	return null


func _open_neighbor(setup: GameSetup, origin: Vector2i) -> Vector2i:
	var axial := Hex.offset_to_axial(origin)
	for dir in 6:
		var cell := Hex.axial_to_offset(Hex.neighbor(axial, dir))
		if not setup.map.in_bounds(cell):
			continue
		var occupied := false
		for player in setup.players:
			for unit in player.units:
				if unit.cell == cell:
					occupied = true
		if occupied:
			continue
		if setup.city_at_cell(cell) != null:
			continue
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
