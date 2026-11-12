extends SceneTree

## Real-renderer shots for ticket 29. Not part of CI.
## Writes the five ticket29_*.png files under /opt/cursor/artifacts.
## Stages a plains disk and a spawned scout so the reach reads clearly.
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
	for hex in Hex.disk(Hex.offset_to_axial(home), 5):
		var cell := Hex.axial_to_offset(hex)
		if setup.map.in_bounds(cell):
			setup.map.set_land(cell, "plains")
	var step := _step(home, Hex.EAST, 1)
	var far := _step(home, Hex.EAST, 4)
	var scout := setup.spawn_unit(0, "scout", home)
	if scout == null:
		print("FAIL scout did not spawn")
		quit(1)
		return
	game._refresh_board()
	_frame(game, home, 0.85)
	for _frame in 4:
		await process_frame
	if not _select_unit(game, home, "Scout"):
		return
	if not _bar_ready(game):
		return
	if not _panels_clear(game):
		return
	game._clear_hover()
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket29_bar_scout.png"):
		return
	var before := setup.reachable_tiles(scout)
	var sprint := SceneDriver.ability_button(game, "sprint")
	sprint.pressed.emit()
	sprint = SceneDriver.ability_button(game, "sprint")
	var ap_text := (game.get_node("%AbilityApLabel") as Label).text
	var preview := setup.move_reach_preview(scout, "sprint")
	if ap_text != "AP 3 / 3" or scout.ap != 3 or before.has(far) or not preview.has(far):
		print("FAIL preview ", ap_text, " ap ", scout.ap)
		quit(1)
		return
	if not _highlight_is(game, far, Color(0.45, 0.95, 0.55, 0.95)):
		print("FAIL expanded tile is not the move tint")
		quit(1)
		return
	if sprint == null or (sprint.get_node("Column/StateLabel") as Label).text != "Targeting":
		print("FAIL sprint was not targeting")
		quit(1)
		return
	game._clear_hover()
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket29_sprint_preview.png"):
		return
	_click(game, home)
	ap_text = (game.get_node("%AbilityApLabel") as Label).text
	sprint = SceneDriver.ability_button(game, "sprint")
	var strike := SceneDriver.ability_button(game, "strike")
	var skip := SceneDriver.order_button(game, "skip")
	var fortify := SceneDriver.order_button(game, "fortify")
	if scout.ap != 5 or not scout.movement_only or ap_text != "AP 5 / 3":
		print("FAIL after sprint ", ap_text, " ap ", scout.ap)
		quit(1)
		return
	if not strike.disabled or strike.tooltip_text != GameSetup.REASON_MOVE_ONLY or not skip.disabled or skip.tooltip_text != GameSetup.REASON_MOVE_ONLY or not fortify.disabled or fortify.tooltip_text != GameSetup.REASON_MOVE_ONLY or not sprint.disabled or sprint.tooltip_text != GameSetup.REASON_MOVE_ONLY:
		print("FAIL grey bar strike ", strike.tooltip_text, " skip ", skip.tooltip_text)
		quit(1)
		return
	if not setup.reachable_tiles(scout).has(far):
		print("FAIL reach did not grow")
		quit(1)
		return
	game._clear_hover()
	_frame(game, home, 0.85)
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket29_after_sprint.png"):
		return
	_click(game, step, MOUSE_BUTTON_RIGHT)
	ap_text = (game.get_node("%AbilityApLabel") as Label).text
	if scout.cell != step or scout.ap != 4 or ap_text != "AP 4 / 3" or not scout.movement_only:
		print("FAIL after move ", ap_text, " cell ", scout.cell, " ap ", scout.ap)
		quit(1)
		return
	game._clear_hover()
	_frame(game, step, 0.85)
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket29_after_move.png"):
		return
	SceneDriver.spare_settlers(setup, false)
	game._refresh_board()
	var end := game.get_node("%EndTurnButton") as Button
	end.pressed.emit()
	if end.text == "End anyway (Enter)":
		end.pressed.emit()
	if setup.result != null or scout.movement_only or scout.ap != 3:
		print("FAIL end turn ap ", scout.ap, " only ", scout.movement_only, " result ", setup.result)
		quit(1)
		return
	if not _select_unit(game, step, "Scout"):
		return
	game._clear_hover()
	sprint = SceneDriver.ability_button(game, "sprint")
	strike = SceneDriver.ability_button(game, "strike")
	var cooldown := (sprint.get_node("Column/CooldownLabel") as Label).text
	if cooldown != "Cooldown 2" or not sprint.disabled or sprint.tooltip_text != GameSetup.REASON_COOLDOWN or strike.disabled:
		print("FAIL cooldown '", cooldown, "' tip ", sprint.tooltip_text, " strike ", strike.disabled)
		quit(1)
		return
	_frame(game, step, 0.85)
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket29_cooldown.png"):
		return
	print("CAPTURE OK")
	quit(0)


func _bar_ready(game: Node) -> bool:
	var buttons := game.get_node("%AbilityButtons")
	var strike := buttons.get_node_or_null("Ability_strike") as Button
	var sprint := buttons.get_node_or_null("Ability_sprint") as Button
	if strike == null or sprint == null or strike.disabled or sprint.disabled:
		print("FAIL scout abilities missing")
		quit(1)
		return false
	if (strike.get_node("Column/NameLabel") as Label).text != "Strike":
		print("FAIL strike name")
		quit(1)
		return false
	if (sprint.get_node("Column/NameLabel") as Label).text != "Sprint":
		print("FAIL sprint name")
		quit(1)
		return false
	if (sprint.get_node("Column/CooldownLabel") as Label).text != "3":
		print("FAIL sprint cooldown label")
		quit(1)
		return false
	var names: PackedStringArray = []
	for child in buttons.get_children():
		names.append(str(child.name))
	if names != PackedStringArray(["Ability_strike", "Ability_sprint", "OrderGap", "Order_skip", "Order_fortify"]):
		print("FAIL bar order ", names)
		quit(1)
		return false
	return true


func _panels_clear(game: Node) -> bool:
	var bar := game.get_node("%AbilityBar") as Control
	var spell := game.get_node("%SpellBar") as Control
	var selection := game.get_node("%SelectionPanel") as Control
	if not bar.visible:
		print("FAIL ability bar hidden")
		quit(1)
		return false
	if bar.get_global_rect().intersects(spell.get_global_rect()) or bar.get_global_rect().intersects(selection.get_global_rect()):
		print("FAIL ability bar overlaps another panel ", bar.get_global_rect())
		quit(1)
		return false
	return true


func _select_unit(game: Node, cell: Vector2i, title: String) -> bool:
	_click(game, cell)
	if (game.get_node("%SelectionTitle") as Label).text != title:
		_click(game, cell)
	if (game.get_node("%SelectionTitle") as Label).text != title:
		print("FAIL selected ", (game.get_node("%SelectionTitle") as Label).text, " wanted ", title)
		quit(1)
		return false
	return true


func _open_home(setup: GameSetup) -> Vector2i:
	for row in range(6, setup.map.height - 6):
		for col in range(6, setup.map.width - 6):
			var center := Vector2i(col, row)
			var open := true
			for hex in Hex.disk(Hex.offset_to_axial(center), 5):
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


func _step(cell: Vector2i, direction: int, steps: int) -> Vector2i:
	var axial := Hex.offset_to_axial(cell)
	for _i in steps:
		axial = Hex.neighbor(axial, direction)
	return Hex.axial_to_offset(axial)


func _click(game: Node, cell: Vector2i, button_index: int = MOUSE_BUTTON_LEFT) -> void:
	SceneDriver.click_cell(game, cell, button_index)


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
