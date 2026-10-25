extends SceneTree

## Real-renderer shots for ticket 11. Not part of CI.
## Writes ticket11_spell_bar.png, ticket11_radius_preview.png,
## ticket11_line_preview.png, and ticket11_after_cast.png.


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
	if not _overlaps_ok(game):
		return
	var settler := _human_unit(setup, "settler")
	var warrior := _human_unit(setup, "warrior")
	_click(game, settler.cell)
	(game.get_node("%FoundCityButton") as Button).pressed.emit()
	if setup.cities.is_empty():
		print("FAIL city was not founded")
		quit(1)
		return
	var city: MapCity = setup.cities[0]
	setup.players[setup.human_index].mana = 30
	game._refresh_board()
	_frame(game, city.cell, 1.0)
	for _frame in 4:
		await process_frame
	var greyed := _greyed_spells(game)
	if greyed.size() != 1 or greyed[0] != "ignite":
		print("FAIL greyed spells ", greyed)
		quit(1)
		return
	var mana := (game.get_node("%ManaLabel") as Label).text
	var turn := (game.get_node("%TurnLabel") as Label).text
	var caption := (game.get_node("UI/TopBar/Row/TurnCaption") as Label).text
	if mana != "Mana: 30 (+2/turn)" or caption != "Turn" or turn != "1 / 50":
		print("FAIL top bar mana='", mana, "' caption='", caption, "' turn='", turn, "'")
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket11_spell_bar.png"):
		return
	print("BAR ", mana, " greyed ", greyed)
	var radius_at := _radius_target(setup, city.cell, warrior.cell)
	if radius_at.x < 0:
		print("FAIL no radius target")
		quit(1)
		return
	for cell in setup.affected_tiles("grow_forest", radius_at, Hex.EAST):
		setup.map.set_land(cell, "plains")
	game._refresh_board()
	_press_spell(game, "grow_forest")
	var radius_tiles: Array = setup.affected_tiles("grow_forest", radius_at, Hex.EAST)
	if not await _frame_tiles(game, radius_tiles):
		return
	var radius_tip := _hover_offset(game, radius_at, Vector2.ZERO, _tooltip_screen(game, radius_tiles))
	for _frame in 3:
		await process_frame
	if not _tiles_clear(game, radius_tiles):
		print("FAIL radius preview overlaps the panels")
		quit(1)
		return
	if game.get_node("%MoveHighlights").get_child_count() != 7:
		print("FAIL radius marks ", game.get_node("%MoveHighlights").get_child_count())
		quit(1)
		return
	if not radius_tip.contains("Grow Forest") or not radius_tip.contains("7 tiles change"):
		print("FAIL radius tip '", radius_tip, "'")
		quit(1)
		return
	if not _highlights_match(game, Color(0.28, 0.62, 0.32)):
		print("FAIL radius tint")
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket11_radius_preview.png"):
		return
	print("RADIUS ", radius_tip.replace("\n", " | "))
	var line_pick := _line_target(setup, city.cell)
	if line_pick.is_empty():
		print("FAIL no line target")
		quit(1)
		return
	var line_at: Vector2i = line_pick["cell"]
	var line_dir := int(line_pick["direction"])
	var line_tiles: Array = setup.affected_tiles("carve_river", line_at, line_dir)
	for cell in line_tiles:
		setup.map.set_land(cell as Vector2i, "plains")
	if not _reveal_tiles(setup, game, line_tiles):
		print("FAIL line tiles stayed unrevealed")
		quit(1)
		return
	game._refresh_board()
	_press_spell(game, "carve_river")
	if not await _frame_tiles(game, line_tiles):
		return
	var aim := _direction_offset(game, line_at, line_dir)
	var line_tip := _hover_offset(game, line_at, aim, _tooltip_screen(game, line_tiles))
	for _frame in 3:
		await process_frame
	if not _tiles_clear(game, line_tiles):
		print("FAIL line preview overlaps the panels")
		quit(1)
		return
	if game.get_node("%MoveHighlights").get_child_count() != 4:
		print("FAIL line marks ", game.get_node("%MoveHighlights").get_child_count())
		quit(1)
		return
	if not line_tip.contains("Carve River") or not line_tip.contains(Hex.DIRECTION_NAMES[line_dir]) or not line_tip.contains("4 tiles change"):
		print("FAIL line tip '", line_tip, "' dir ", Hex.DIRECTION_NAMES[line_dir])
		quit(1)
		return
	if not _highlights_match(game, Color(0.38, 0.62, 0.86)):
		print("FAIL line tint")
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket11_line_preview.png"):
		return
	print("LINE ", line_tip.replace("\n", " | "))
	for cell in setup.affected_tiles("grow_forest", radius_at, Hex.EAST):
		setup.map.set_land(cell, "plains")
	game._refresh_board()
	_press_spell(game, "grow_forest")
	_hover_offset(game, radius_at, Vector2.ZERO)
	_click(game, radius_at)
	if setup.players[setup.human_index].mana != 15:
		print("FAIL mana after ", setup.players[setup.human_index].mana)
		quit(1)
		return
	for cell in setup.affected_tiles("grow_forest", radius_at, Hex.EAST):
		if setup.map.land_at(cell) != "forest":
			print("FAIL land ", cell, " ", setup.map.land_at(cell))
			quit(1)
			return
	game._clear_hover()
	var forest_tiles: Array = setup.affected_tiles("grow_forest", radius_at, Hex.EAST)
	if not await _frame_tiles(game, forest_tiles):
		return
	for _frame in 3:
		await process_frame
	if not _tiles_clear(game, forest_tiles):
		print("FAIL changed tiles overlap the panels")
		quit(1)
		return
	mana = (game.get_node("%ManaLabel") as Label).text
	var forest_button := game.get_node("%SpellButtons").get_node("Spell_grow_forest") as Button
	var state := (forest_button.get_node("Column/StateLabel") as Label).text
	if mana != "Mana: 15 (+2/turn)" or not forest_button.disabled or not state.begins_with("Cooldown"):
		print("FAIL after mana='", mana, "' state='", state, "' disabled=", forest_button.disabled)
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket11_after_cast.png"):
		return
	print("AFTER ", mana, " ", state)
	quit(0)


func _good_start(setup: GameSetup) -> bool:
	var cell := setup.human_settler_cell()
	return cell.x >= 6 and cell.y >= 5 and cell.x < setup.map.width - 6 and cell.y < setup.map.height - 5


func _overlaps_ok(game: Node) -> bool:
	var bar := (game.get_node("%SpellBar") as Control).get_global_rect()
	var top := (game.get_node("UI/TopBar") as Control).get_global_rect()
	var selection := (game.get_node("%SelectionPanel") as Control).get_global_rect()
	var city := (game.get_node("%CityPanel") as Control).get_global_rect()
	if bar.intersects(top) or bar.intersects(selection) or bar.intersects(city):
		print("FAIL spell bar overlap ", bar, " top ", top, " selection ", selection, " city ", city)
		quit(1)
		return false
	if bar.position.y < top.end.y:
		print("FAIL spell bar above the top bar ", bar, " ", top)
		quit(1)
		return false
	return true


func _radius_target(setup: GameSetup, origin: Vector2i, avoid: Vector2i) -> Vector2i:
	var axial := Hex.offset_to_axial(origin)
	for dir in 6:
		var cursor := axial
		for _step_i in 2:
			cursor = Hex.neighbor(cursor, dir)
		var cell := Hex.axial_to_offset(cursor)
		var tiles := setup.affected_tiles("grow_forest", cell, Hex.EAST)
		if tiles.size() != 7 or tiles.has(avoid) or tiles.has(origin):
			continue
		if setup.cast_reason(setup.human_index, "grow_forest", cell, Hex.EAST).is_empty():
			return cell
	return Vector2i(-1, -1)


func _line_target(setup: GameSetup, origin: Vector2i) -> Dictionary:
	var axial := Hex.offset_to_axial(origin)
	for dir in 6:
		var cursor := axial
		for _step_i in 2:
			cursor = Hex.neighbor(cursor, dir)
		var cell := Hex.axial_to_offset(cursor)
		var tiles := setup.affected_tiles("carve_river", cell, dir)
		if tiles.size() == 4 and not tiles.has(origin):
			if setup.cast_reason(setup.human_index, "carve_river", cell, dir).is_empty():
				return {"cell": cell, "direction": dir}
	return {}


func _direction_offset(game: Node, cell: Vector2i, direction: int) -> Vector2:
	var map := game.get_node("%Map") as TileMapLayer
	var center := map.map_to_local(cell)
	var neighbor := Hex.axial_to_offset(Hex.neighbor(Hex.offset_to_axial(cell), direction))
	var delta := map.map_to_local(neighbor) - center
	return delta.normalized() * 46.0


func _frame(game: Node, cell: Vector2i, zoom: float) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var camera := game.get_node("%Camera") as Camera2D
	camera.zoom = Vector2(zoom, zoom)
	camera.position = map.map_to_local(cell)
	game._clamp_camera()


## Puts the affected tiles in the open map, right of the selection panel and below the spell bar.
func _frame_tiles(game: Node, cells: Array) -> bool:
	var map := game.get_node("%Map") as TileMapLayer
	var camera := game.get_node("%Camera") as Camera2D
	var min_p := Vector2(1.0e9, 1.0e9)
	var max_p := Vector2(-1.0e9, -1.0e9)
	for cell in cells:
		var point := map.map_to_local(cell as Vector2i)
		min_p.x = minf(min_p.x, point.x)
		min_p.y = minf(min_p.y, point.y)
		max_p.x = maxf(max_p.x, point.x)
		max_p.y = maxf(max_p.y, point.y)
	var pad := Vector2(84.0, 74.0)
	min_p -= pad
	max_p += pad
	var center := (min_p + max_p) * 0.5
	var view_center := Vector2(1280, 720)
	var safe := Rect2(Vector2(940, 320), Vector2(1560, 1080))
	var zooms: Array[float] = [1.35, 1.15, 1.0]
	for zoom in zooms:
		var half: Vector2 = (max_p - min_p) * 0.5 * zoom
		var desired := Vector2(1560, 860)
		var min_x: float = safe.position.x + half.x
		var max_x: float = safe.end.x - half.x
		var min_y: float = safe.position.y + half.y
		var max_y: float = safe.end.y - half.y
		if min_x > max_x or min_y > max_y:
			continue
		desired.x = clampf(desired.x, min_x, max_x)
		desired.y = clampf(desired.y, min_y, max_y)
		camera.zoom = Vector2(zoom, zoom)
		camera.position = center - (desired - view_center) / zoom
		game._clamp_camera()
		await process_frame
		if _tiles_clear(game, cells):
			return true
	print("FAIL could not frame tiles clear of the panels")
	quit(1)
	return false


func _tiles_clear(game: Node, cells: Array) -> bool:
	var selection := (game.get_node("%SelectionPanel") as Control).get_global_rect()
	var bar := (game.get_node("%SpellBar") as Control).get_global_rect()
	var top := (game.get_node("UI/TopBar") as Control).get_global_rect()
	for rect in _screen_rects(game, cells):
		if rect.position.x < 4.0 or rect.position.y < 4.0 or rect.end.x > 2556.0 or rect.end.y > 1436.0:
			return false
		if rect.intersects(selection) or rect.intersects(bar) or rect.intersects(top):
			return false
	return true


func _screen_rects(game: Node, cells: Array) -> Array[Rect2]:
	var map := game.get_node("%Map") as TileMapLayer
	var zoom := (game.get_node("%Camera") as Camera2D).zoom.x
	var canvas := game.get_viewport().get_canvas_transform()
	var rects: Array[Rect2] = []
	var half := Vector2(72.0, 64.0) * zoom
	for cell in cells:
		var world: Vector2 = map.to_global(map.map_to_local(cell as Vector2i))
		var screen: Vector2 = canvas * world
		rects.append(Rect2(screen - half, half * 2.0))
	return rects


func _tooltip_screen(game: Node, cells: Array) -> Vector2:
	var occupied := _screen_rects(game, cells)
	var bar := (game.get_node("%SpellBar") as Control).get_global_rect()
	var selection := (game.get_node("%SelectionPanel") as Control).get_global_rect()
	var tip_size := Vector2(560, 200)
	var candidates: Array[Vector2] = [
		Vector2(1920, 1120),
		Vector2(1920, 340),
		Vector2(960, 1120),
		Vector2(24, 340),
	]
	for origin in candidates:
		var box := Rect2(origin, tip_size)
		if box.end.x > 2552.0 or box.end.y > 1432.0:
			continue
		var hit := box.intersects(bar) or box.intersects(selection)
		if not hit:
			for rect in occupied:
				if box.intersects(rect):
					hit = true
					break
		if not hit:
			return origin
	return Vector2(1920, 1120)


## Parks the warrior beside the farthest tile so a long line is explored before the shot.
func _reveal_tiles(setup: GameSetup, game: Node, tiles: Array) -> bool:
	var warrior := _human_unit(setup, "warrior")
	if warrior == null:
		return false
	var blocked := {warrior.cell: false}
	for cell in tiles:
		blocked[cell as Vector2i] = true
	for city in setup.cities:
		blocked[city.cell] = true
	for player in setup.players:
		for unit in player.units:
			if unit != warrior:
				blocked[unit.cell] = true
	var spots: Array[Vector2i] = []
	for i in range(tiles.size() - 1, -1, -1):
		var axial := Hex.offset_to_axial(tiles[i] as Vector2i)
		for dir in 6:
			spots.append(Hex.axial_to_offset(Hex.neighbor(axial, dir)))
	for spot in spots:
		if blocked.has(spot) and blocked[spot]:
			continue
		if not setup.map.is_passable(spot, setup.config):
			continue
		warrior.cell = spot
		setup._refresh_fog()
		var seen := true
		for cell in tiles:
			if setup.fog.sight(setup.human_index, cell) == FogState.Sight.UNREVEALED:
				seen = false
				break
		if seen:
			game._refresh_board()
			return true
	return false


func _press_spell(game: Node, spell_id: String) -> void:
	var button := game.get_node("%SpellButtons").get_node("Spell_%s" % spell_id) as Button
	button.pressed.emit()


func _hover_offset(game: Node, cell: Vector2i, offset: Vector2, tip_screen: Vector2 = Vector2.INF) -> String:
	var map := game.get_node("%Map") as TileMapLayer
	var local := map.map_to_local(cell) + offset
	var world: Vector2 = map.to_global(local)
	var screen: Vector2 = game.get_viewport().get_canvas_transform() * world
	var tip := screen + Vector2(28, 28) if tip_screen == Vector2.INF else tip_screen
	game.hover_at_local(local, tip)
	return (game.get_node("%Tooltip") as Label).text


func _highlights_match(game: Node, tint: Color) -> bool:
	var found := false
	for child in game.get_node("%MoveHighlights").get_children():
		var color := (child as CanvasItem).modulate
		if color.r > tint.r - 0.05 and color.g > tint.g - 0.05 and color.b > tint.b - 0.05:
			found = true
		else:
			return false
	return found


func _greyed_spells(game: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for spell_id in GameConfig.SPELL_IDS:
		var button := game.get_node("%SpellButtons").get_node("Spell_%s" % spell_id) as Button
		if button.disabled:
			out.append(spell_id)
	return out


func _human_unit(setup: GameSetup, unit_type: String) -> PlayerState.UnitState:
	for unit in setup.players[setup.human_index].units:
		if unit.unit_type == unit_type:
			return unit
	return null


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
