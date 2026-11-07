extends SceneTree

## Real-renderer shots for ticket 26. Not part of CI.
## Writes the six ticket26_*.png files under /opt/cursor/artifacts.


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
	_frame(game, warrior.cell)
	for _frame in 4:
		await process_frame
	if not _select_unit(game, warrior.cell, "Warrior"):
		return
	if not _bar_ready(game, "strike", false):
		return
	if not _panels_clear(game, "warrior bar"):
		return
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket26_bar_warrior.png"):
		return

	_frame(game, settler.cell)
	for _frame in 2:
		await process_frame
	if not _select_unit(game, settler.cell, "Settler"):
		return
	if not _bar_ready(game, "", true):
		return
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket26_bar_settler.png"):
		return

	var foe_cell := _open_neighbor(setup, warrior.cell)
	if foe_cell.x < 0:
		print("FAIL no neighbor for the enemy")
		quit(1)
		return
	setup.map.set_land(warrior.cell, "plains")
	setup.map.set_land(foe_cell, "plains")
	var foe := setup.spawn_unit(1, "warrior", foe_cell)
	if foe == null:
		print("FAIL could not spawn the enemy")
		quit(1)
		return
	var far := _ranged_out(setup, warrior.cell, foe_cell)
	if far.x < 0:
		print("FAIL no out-of-range tile")
		quit(1)
		return
	game._refresh_board()
	_frame(game, warrior.cell)
	for _frame in 2:
		await process_frame
	if not _select_unit(game, warrior.cell, "Warrior"):
		return
	var strike := SceneDriver.ability_button(game, "strike")
	strike.pressed.emit()
	strike = SceneDriver.ability_button(game, "strike")
	if str(game.get("_ability_id")) != "strike" or (strike.get_node("Column/StateLabel") as Label).text != "Targeting":
		print("FAIL strike did not arm")
		quit(1)
		return
	_hover(game, foe_cell, Vector2(360, 360))
	var preview := (game.get_node("%CombatPreview") as Label).text
	var expected: String = game._preview_line(setup.ability_preview(warrior, "strike", foe_cell))
	if preview != expected or not preview.begins_with("Damage "):
		print("FAIL valid preview '", preview, "' expected '", expected, "'")
		quit(1)
		return
	if not _highlight_is(game, foe_cell, Color(0.95, 0.32, 0.28, 0.95)):
		print("FAIL valid highlight missing")
		quit(1)
		return
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket26_targeting_valid.png"):
		return

	_hover(game, far, Vector2(360, 360))
	preview = (game.get_node("%CombatPreview") as Label).text
	if preview != GameSetup.REASON_RANGE:
		print("FAIL invalid preview '", preview, "'")
		quit(1)
		return
	if not _highlight_is(game, far, Color(0.95, 0.28, 0.24, 0.95)):
		print("FAIL invalid highlight missing")
		quit(1)
		return
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket26_targeting_invalid.png"):
		return

	var hp_before := foe.hp
	_click(game, foe_cell)
	if foe.hp >= hp_before or warrior.ap != 0 or str(game.get("_ability_id")) != "":
		print("FAIL strike hp ", foe.hp, " ap ", warrior.ap, " ability ", game.get("_ability_id"))
		quit(1)
		return
	game._clear_hover()
	strike = SceneDriver.ability_button(game, "strike")
	var fortify := SceneDriver.order_button(game, "fortify")
	if not strike.disabled or strike.tooltip_text != GameSetup.REASON_AP:
		print("FAIL strike not greyed '", strike.tooltip_text, "'")
		quit(1)
		return
	if not fortify.disabled or fortify.tooltip_text != GameSetup.REASON_AP:
		print("FAIL fortify not greyed")
		quit(1)
		return
	if SceneDriver.order_button(game, "skip").disabled:
		print("FAIL skip greyed at 0 AP")
		quit(1)
		return
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket26_after_strike.png"):
		return

	if setup.map.land_at(settler.cell) == "water":
		setup.map.set_land(settler.cell, "plains")
		game._refresh_board()
	_frame(game, settler.cell)
	if not _select_unit(game, settler.cell, "Settler"):
		return
	var found := SceneDriver.order_button(game, "found")
	if found.disabled:
		print("FAIL cannot found: ", found.tooltip_text)
		quit(1)
		return
	var city_cell := settler.cell
	found.pressed.emit()
	_click(game, city_cell)
	if not (game.get_node("%CityPanel") as CanvasItem).visible:
		print("FAIL city panel stayed closed")
		quit(1)
		return
	warrior.ap = setup.config.unit("warrior").ap
	warrior.acted = false
	warrior.used_ability = false
	warrior.order = ""
	warrior.fortified = false
	_frame(game, warrior.cell)
	game._refresh_board()
	if not _select_unit(game, warrior.cell, "Warrior"):
		return
	if not _bar_ready(game, "strike", false):
		return
	if not (game.get_node("%CityPanel") as CanvasItem).visible:
		print("FAIL city panel closed when the warrior was selected")
		quit(1)
		return
	if not _panels_clear(game, "spell and bar"):
		return
	game._clear_hover()
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket26_spell_and_bar.png"):
		return
	print("CAPTURE OK")
	quit(0)


func _bar_ready(game: Node, ability_id: String, want_found: bool) -> bool:
	var bar := game.get_node("%AbilityBar") as CanvasItem
	if not bar.visible:
		print("FAIL ability bar hidden")
		quit(1)
		return false
	var ap := (game.get_node("%AbilityApLabel") as Label).text
	if not ap.begins_with("AP "):
		print("FAIL ap label '", ap, "'")
		quit(1)
		return false
	var buttons := game.get_node("%AbilityButtons")
	var strike := buttons.get_node_or_null("Ability_strike") as Button
	if ability_id == "strike":
		if strike == null or strike.disabled:
			print("FAIL strike missing")
			quit(1)
			return false
		if (strike.get_node("Column/NameLabel") as Label).text != "Strike":
			print("FAIL strike name")
			quit(1)
			return false
		if (strike.get_node("Column/CostLabel") as Label).text != "1 AP":
			print("FAIL strike cost")
			quit(1)
			return false
	elif strike != null:
		print("FAIL settler shows Strike")
		quit(1)
		return false
	if buttons.get_node_or_null("Order_skip") == null or buttons.get_node_or_null("Order_fortify") == null:
		print("FAIL orders missing")
		quit(1)
		return false
	var found := buttons.get_node_or_null("Order_found") as Button
	if want_found:
		if found == null or found.disabled or (found.get_node("Column/NameLabel") as Label).text != "Found":
			print("FAIL Found missing")
			quit(1)
			return false
	elif found != null:
		print("FAIL warrior shows Found")
		quit(1)
		return false
	return true


func _panels_clear(game: Node, label: String) -> bool:
	var bar := game.get_node("%AbilityBar") as Control
	var spell := game.get_node("%SpellBar") as Control
	var selection := game.get_node("%SelectionPanel") as Control
	var city := game.get_node("%CityPanel") as Control
	print(label, " ability ", bar.get_global_rect(), " spell ", spell.get_global_rect(), " selection ", selection.get_global_rect(), " city ", city.get_global_rect())
	if _overlaps(bar, spell) or _overlaps(bar, selection) or _overlaps(bar, city):
		print("FAIL ", label, " overlaps another panel")
		quit(1)
		return false
	return true


func _overlaps(a: Control, b: Control) -> bool:
	if not a.visible or not b.visible:
		return false
	return a.get_global_rect().intersects(b.get_global_rect())


func _select_unit(game: Node, cell: Vector2i, title: String) -> bool:
	_click(game, cell)
	if (game.get_node("%SelectionTitle") as Label).text != title:
		_click(game, cell)
	if (game.get_node("%SelectionTitle") as Label).text != title:
		print("FAIL selected ", (game.get_node("%SelectionTitle") as Label).text, " wanted ", title)
		quit(1)
		return false
	return true


func _good_start(setup: GameSetup) -> bool:
	var warrior := _human_unit(setup, "warrior")
	var settler := _human_unit(setup, "settler")
	if warrior == null or settler == null:
		return false
	var cell := warrior.cell
	if cell.x < 4 or cell.y < 3 or cell.x >= setup.map.width - 4 or cell.y >= setup.map.height - 3:
		return false
	return _open_neighbor(setup, cell).x >= 0 and _ranged_out(setup, cell, Vector2i(-1, -1)).x >= 0


func _frame(game: Node, cell: Vector2i) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var camera := game.get_node("%Camera") as Camera2D
	camera.zoom = Vector2(1.15, 1.15)
	camera.position = map.map_to_local(cell) + Vector2(40, 220)
	game._clamp_camera()


func _hover(game: Node, cell: Vector2i, tip_screen: Vector2) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	game.hover_at_local(map.map_to_local(cell), tip_screen)


func _highlight_is(game: Node, cell: Vector2i, tint: Color) -> bool:
	var map := game.get_node("%Map") as TileMapLayer
	var at := map.map_to_local(cell)
	for child in game.get_node("%MoveHighlights").get_children():
		var marker := child as Node2D
		if marker.position.distance_to(at) > 1.0:
			continue
		if (marker as CanvasItem).modulate.is_equal_approx(tint):
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


func _ranged_out(setup: GameSetup, origin: Vector2i, avoid: Vector2i) -> Vector2i:
	var axial := Hex.offset_to_axial(origin)
	for dir in 6:
		var far := Hex.neighbor(Hex.neighbor(axial, dir), dir)
		var cell := Hex.axial_to_offset(far)
		if cell == avoid or not setup.map.in_bounds(cell):
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
