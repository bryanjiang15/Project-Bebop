extends SceneTree

## Real-renderer shots for ticket 14. Not part of CI.
## Writes the three ticket14_*.png files under /opt/cursor/artifacts.


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
	var settler := _human_unit(setup, "settler")
	if warrior == null or settler == null or warrior.cell == settler.cell:
		print("FAIL units share a tile")
		quit(1)
		return
	_frame(game, warrior.cell)
	for _frame in 4:
		await process_frame
	_click(game, warrior.cell)
	_click(game, warrior.cell)
	if (game.get_node("%SelectionTitle") as Label).text != "Warrior":
		print("FAIL selected ", (game.get_node("%SelectionTitle") as Label).text)
		quit(1)
		return
	var detail := (game.get_node("%SelectionDetail") as Label).text
	if not detail.contains("HP 100 / 100"):
		print("FAIL start panel '", detail, "'")
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket14_start_units.png"):
		return
	print("START ", detail.replace("\n", " | "), " seed ", setup.seed_used)
	var dest := _open_neighbor(setup, warrior.cell)
	setup.map.set_land(dest, "plains")
	var rival := setup.spawn_unit(1, "warrior", dest)
	if rival == null:
		print("FAIL rival spawn ", dest)
		quit(1)
		return
	game._refresh_board()
	_frame(game, warrior.cell)
	for _frame in 3:
		await process_frame
	if (game.get_node("%SelectionTitle") as Label).text != "Warrior":
		_click(game, warrior.cell)
		_click(game, warrior.cell)
	_hover(game, dest, Vector2(1480, 180))
	var preview := (game.get_node("%CombatPreview") as Label).text
	var tip := (game.get_node("%Tooltip") as Label).text
	if preview != "Damage 30   Counter 30" or not tip.contains("Damage 30   Counter 30"):
		print("FAIL preview '", preview, "' tip '", tip, "'")
		quit(1)
		return
	if not _has_attack_highlight(game):
		print("FAIL no red highlight")
		quit(1)
		return
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket14_combat_preview.png"):
		return
	print("PREVIEW ", preview)
	_click(game, dest, MOUSE_BUTTON_RIGHT)
	if warrior.hp != 70 or rival.hp != 70 or warrior.cell == settler.cell:
		print("FAIL after ", warrior.hp, " ", rival.hp, " cell ", warrior.cell)
		quit(1)
		return
	game._clear_hover()
	_frame(game, warrior.cell)
	for _frame in 4:
		await process_frame
	detail = (game.get_node("%SelectionDetail") as Label).text
	if not detail.contains("HP 70 / 100"):
		print("FAIL after panel '", detail, "'")
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket14_after_attack.png"):
		return
	print("AFTER ", detail.replace("\n", " | "))
	quit(0)


func _good_start(setup: GameSetup) -> bool:
	var cell := setup.human_settler_cell()
	if cell.x < 4 or cell.y < 3 or cell.x >= setup.map.width - 4 or cell.y >= setup.map.height - 3:
		return false
	return _open_neighbor(setup, cell).x >= 0


func _frame(game: Node, cell: Vector2i) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var camera := game.get_node("%Camera") as Camera2D
	camera.zoom = Vector2(1.15, 1.15)
	camera.position = map.map_to_local(cell) + Vector2(40, 260)
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
		if not occupied:
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
