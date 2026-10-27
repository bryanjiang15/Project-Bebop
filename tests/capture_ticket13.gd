extends SceneTree

## Real-renderer shots for ticket 13. Not part of CI.
## Writes ticket13_preview_destroys_building.png, ticket13_after_water.png,
## ticket13_volcanic_warning.png, and ticket13_after_volcanic_turn.png.


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
	var placed: Dictionary = _place(setup)
	if not bool(placed["ok"]):
		print("FAIL fixture ", placed["reason"])
		quit(1)
		return
	game._refresh_board()
	var city := placed["city"] as MapCity
	var well_cell: Vector2i = placed["well"]
	var warrior := placed["warrior"] as PlayerState.UnitState
	_click(game, city.cell)
	if not (game.get_node("%CityPanel") as CanvasItem).visible:
		print("FAIL city panel closed")
		quit(1)
		return
	_aim(game, well_cell, Vector2(1180, 620), 1.2)
	for _frame in 2:
		await process_frame
	var rate_before := setup.mana_per_turn(setup.human_index)
	var mana_before := (game.get_node("%CityMana") as Label).text
	var food_before := (game.get_node("%CityFood") as Label).text
	(game.get_node("%SpellButtons").get_node("Spell_carve_river") as Button).pressed.emit()
	_hover_east(game, well_cell)
	for _frame in 2:
		await process_frame
	var tip := (game.get_node("%Tooltip") as Label).text
	if not tip.contains("1 building destroyed") or not tip.contains("Carve River"):
		print("FAIL preview tip '", tip, "'")
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket13_preview_destroys_building.png"):
		return
	print("PREVIEW ", tip.replace("\n", " | "), " ", mana_before, " ", food_before)
	_click(game, well_cell)
	(game.get_node("%TooltipPanel") as CanvasItem).visible = false
	for _frame in 3:
		await process_frame
	if setup.map.land_at(well_cell) != "water" or city.buildings.size() != 1:
		print("FAIL after water land ", setup.map.land_at(well_cell), " buildings ", city.buildings.size())
		quit(1)
		return
	var mana_after := (game.get_node("%CityMana") as Label).text
	var food_after := (game.get_node("%CityFood") as Label).text
	var bar := (game.get_node("%ManaLabel") as Label).text
	if mana_after == mana_before or setup.mana_per_turn(setup.human_index) != rate_before - setup.config.mana_well_mana:
		print("FAIL numbers mana ", mana_before, " -> ", mana_after, " bar ", bar)
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket13_after_water.png"):
		return
	print("AFTER ", food_before, " -> ", food_after, " ", mana_before, " -> ", mana_after, " ", bar)
	var stand: Vector2i = placed["stand"]
	setup.map.set_land(stand, "volcanic")
	warrior.cell = stand
	warrior.hp = warrior.max_hp
	warrior.acted = false
	warrior.order = ""
	setup._refresh_fog()
	game._refresh_board()
	_aim(game, stand, Vector2(520, 430), 1.45)
	_click(game, stand)
	(game.get_node("%TooltipPanel") as CanvasItem).visible = false
	for _frame in 3:
		await process_frame
	var detail := (game.get_node("%SelectionDetail") as Label).text
	var warning := (game.get_node("%VolcanicWarning") as Label).text
	var expected_warning := "Volcanic: -%d HP at end of turn" % setup.config.volcanic_damage
	if warning != expected_warning or detail.contains("Volcanic"):
		print("FAIL warning '", warning, "' detail '", detail, "'")
		quit(1)
		return
	if (game.get_node("%SelectionTitle") as Label).text != "Warrior":
		print("FAIL title ", (game.get_node("%SelectionTitle") as Label).text)
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket13_volcanic_warning.png"):
		return
	print("WARNING ", detail.replace("\n", " | "), " | ", warning)
	(game.get_node("%SkipButton") as Button).pressed.emit()
	var end := game.get_node("%EndTurnButton") as Button
	end.pressed.emit()
	if end.text == "End anyway (Enter)":
		end.pressed.emit()
	(game.get_node("%TooltipPanel") as CanvasItem).visible = false
	for _frame in 3:
		await process_frame
	detail = (game.get_node("%SelectionDetail") as Label).text
	warning = (game.get_node("%VolcanicWarning") as Label).text
	if warrior.hp != warrior.max_hp - setup.config.volcanic_damage or not detail.contains("HP %d / %d" % [warrior.hp, warrior.max_hp]) or warning != expected_warning:
		print("FAIL after turn hp ", warrior.hp, " '", detail, "' warning '", warning, "'")
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket13_after_volcanic_turn.png"):
		return
	print("TURN ", detail.replace("\n", " | "), " | ", warning)
	quit(0)


func _place(setup: GameSetup) -> Dictionary:
	var human := setup.human_index
	var settler: PlayerState.UnitState = null
	var warrior: PlayerState.UnitState = null
	for unit in setup.players[human].units:
		if unit.unit_type == "settler":
			settler = unit
		elif unit.unit_type == "warrior":
			warrior = unit
	if settler == null or warrior == null:
		return {"ok": false, "reason": "missing a starting unit"}
	var origin := Vector2i(10, 8)
	var well := _step(origin, Hex.NORTHEAST, 1)
	var granary_cell := _step(origin, Hex.NORTHWEST, 1)
	var stand := _step(origin, Hex.SOUTHWEST, 2)
	if not setup.map.in_bounds(stand) or not setup.map.in_bounds(_step(well, Hex.EAST, 3)):
		return {"ok": false, "reason": "fixture left the map"}
	for hex in Hex.disk(Hex.offset_to_axial(origin), 5):
		var cell := Hex.axial_to_offset(hex)
		if setup.map.in_bounds(cell):
			setup.map.set_land(cell, "plains")
	var reserved := {origin: true, well: true, granary_cell: true, stand: true}
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
	setup.map.set_land(well, "forest")
	var city := setup.found_city(settler)
	if city == null:
		return {"ok": false, "reason": "city did not found"}
	var well_building := MapCity.Building.new()
	well_building.kind = "mana_well"
	well_building.cell = well
	city.buildings.append(well_building)
	var granary := MapCity.Building.new()
	granary.kind = "granary"
	granary.cell = granary_cell
	city.buildings.append(granary)
	setup.players[human].mana = 80
	setup.players[human].casts_this_turn = 0
	setup.players[human].spell_cooldowns.clear()
	setup._refresh_fog()
	return {"ok": true, "reason": "", "city": city, "well": well, "warrior": warrior, "stand": stand}


func _hover_east(game: Node, cell: Vector2i) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var center: Vector2 = map.map_to_local(cell)
	var east: Vector2 = map.map_to_local(_step(cell, Hex.EAST, 1))
	var local := center + (east - center) * 0.42
	game.hover_at_local(local, Vector2(48, 300))


func _aim(game: Node, cell: Vector2i, screen_point: Vector2, zoom: float) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var camera := game.get_node("%Camera") as Camera2D
	var local: Vector2 = map.map_to_local(cell)
	camera.zoom = Vector2(zoom, zoom)
	camera.position = local - (screen_point - Vector2(1280, 720)) / zoom
	game._clamp_camera()


func _step(cell: Vector2i, direction: int, steps: int) -> Vector2i:
	var axial := Hex.offset_to_axial(cell)
	for _i in steps:
		axial = Hex.neighbor(axial, direction)
	return Hex.axial_to_offset(axial)


func _click(game: Node, cell: Vector2i) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var world: Vector2 = map.to_global(map.map_to_local(cell))
	var screen: Vector2 = game.get_viewport().get_canvas_transform() * world
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	press.global_position = screen
	game._unhandled_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
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
