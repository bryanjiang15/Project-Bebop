extends SceneTree

## Real-renderer shots for ticket 27. Not part of CI.
## Writes the six ticket27_*.png files under /opt/cursor/artifacts.


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
	_frame(game, warrior.cell)
	for _frame in 4:
		await process_frame
	if not _select_unit(game, warrior.cell, "Warrior"):
		return
	if not _bar_ready(game):
		return
	if not _panels_clear(game):
		return
	game._clear_hover()
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket27_bar_warrior.png"):
		return
	var lane := _bash_lane(setup, warrior.cell)
	if lane.is_empty():
		print("FAIL no bash lane")
		quit(1)
		return
	var foe_cell: Vector2i = lane[0]
	var dest: Vector2i = lane[1]
	setup.map.set_land(warrior.cell, "plains")
	setup.map.set_land(foe_cell, "plains")
	setup.map.set_land(dest, "plains")
	var foe := setup.spawn_unit(1, "warrior", foe_cell)
	if foe == null:
		print("FAIL could not spawn the enemy")
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
	_hover(game, foe_cell)
	var strike_preview: Dictionary = setup.ability_preview(warrior, "strike", foe_cell)
	var strike_line: String = game._preview_line(strike_preview)
	var shown := (game.get_node("%CombatPreview") as Label).text
	if int(strike_preview["counter"]) <= 0 or shown != strike_line or shown.contains("Push"):
		print("FAIL strike preview '", shown, "'")
		quit(1)
		return
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket27_strike_unchanged.png"):
		return
	var bash := SceneDriver.ability_button(game, "shield_bash")
	bash.pressed.emit()
	_hover(game, foe_cell)
	var preview: Dictionary = setup.ability_preview(warrior, "shield_bash", foe_cell)
	var push_line: String = game._preview_line(preview)
	shown = (game.get_node("%CombatPreview") as Label).text
	if shown != push_line or not shown.ends_with("   Push") or not shown.contains("Counter 0"):
		print("FAIL push preview '", shown, "' expected '", push_line, "'")
		quit(1)
		return
	if not _highlight_is(game, dest, Color(0.4, 0.85, 0.95, 0.95)):
		print("FAIL open dest highlight missing")
		quit(1)
		return
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket27_bash_preview_push.png"):
		return
	setup.map.set_land(dest, "water")
	game._refresh_board()
	_hover(game, foe_cell)
	preview = setup.ability_preview(warrior, "shield_bash", foe_cell)
	var blocked_line: String = game._preview_line(preview)
	shown = (game.get_node("%CombatPreview") as Label).text
	if shown != blocked_line or not shown.ends_with("No push") or not shown.contains("Counter 0"):
		print("FAIL blocked preview '", shown, "' expected '", blocked_line, "'")
		quit(1)
		return
	if not _highlight_is(game, dest, Color(0.95, 0.28, 0.24, 0.95)):
		print("FAIL blocked dest highlight missing")
		quit(1)
		return
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket27_bash_preview_blocked.png"):
		return
	var hp_before := foe.hp
	var warrior_hp := warrior.hp
	var stand := warrior.cell
	_click(game, foe_cell)
	if foe.cell != foe_cell or foe.hp >= hp_before or warrior.hp != warrior_hp or warrior.cell != stand:
		print("FAIL blocked resolve cell ", foe.cell, " hp ", foe.hp, " warrior ", warrior.hp)
		quit(1)
		return
	game._clear_hover()
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket27_after_bash_blocked.png"):
		return
	warrior.ap = setup.config.unit("warrior").ap
	warrior.acted = false
	warrior.used_ability = false
	warrior.order = ""
	warrior.fortified = false
	warrior.ability_cooldowns.clear()
	foe.hp = setup.config.unit("warrior").hp
	setup.map.set_land(dest, "plains")
	setup._refresh_fog()
	game._refresh_board()
	if not _select_unit(game, warrior.cell, "Warrior"):
		return
	bash = SceneDriver.ability_button(game, "shield_bash")
	bash.pressed.emit()
	_hover(game, foe_cell)
	_click(game, foe_cell)
	if foe.cell != dest or warrior.cell != stand or warrior.hp != warrior_hp:
		print("FAIL push resolve foe ", foe.cell, " dest ", dest, " warrior ", warrior.cell, " hp ", warrior.hp)
		quit(1)
		return
	game._clear_hover()
	_frame(game, dest)
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket27_after_bash_pushed.png"):
		return
	print("CAPTURE OK")
	quit(0)


func _bar_ready(game: Node) -> bool:
	var buttons := game.get_node("%AbilityButtons")
	var strike := buttons.get_node_or_null("Ability_strike") as Button
	var bash := buttons.get_node_or_null("Ability_shield_bash") as Button
	if strike == null or bash == null or strike.disabled or bash.disabled:
		print("FAIL warrior abilities missing")
		quit(1)
		return false
	if (strike.get_node("Column/NameLabel") as Label).text != "Strike":
		print("FAIL strike name")
		quit(1)
		return false
	if (bash.get_node("Column/NameLabel") as Label).text != "Shield Bash":
		print("FAIL shield bash name")
		quit(1)
		return false
	if (bash.get_node("Column/CooldownLabel") as Label).text != "2":
		print("FAIL shield bash cooldown label")
		quit(1)
		return false
	var names: PackedStringArray = []
	for child in buttons.get_children():
		names.append(str(child.name))
	if names != PackedStringArray(["Ability_strike", "Ability_shield_bash", "OrderGap", "Order_skip", "Order_fortify"]):
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


func _good_start(setup: GameSetup) -> bool:
	var warrior := _human_unit(setup, "warrior")
	var settler := _human_unit(setup, "settler")
	if warrior == null or settler == null:
		return false
	var cell := warrior.cell
	if cell.x < 4 or cell.y < 3 or cell.x >= setup.map.width - 4 or cell.y >= setup.map.height - 3:
		return false
	return not _bash_lane(setup, cell).is_empty()


func _frame(game: Node, cell: Vector2i) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var camera := game.get_node("%Camera") as Camera2D
	camera.zoom = Vector2(1.15, 1.15)
	# The push hex sits one tile past the target. A smaller offset keeps that
	# tile below the spell bar instead of sliding it under the top UI.
	camera.position = map.map_to_local(cell) + Vector2(20, 20)
	game._clamp_camera()


func _hover(game: Node, cell: Vector2i) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	# Right of the map, below the spell bar, so the tip does not cover either.
	game.hover_at_local(map.map_to_local(cell), Vector2(1780, 520))


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


func _bash_lane(setup: GameSetup, origin: Vector2i) -> Array:
	var axial := Hex.offset_to_axial(origin)
	var fallback: Array = []
	for dir in 6:
		var foe := Hex.axial_to_offset(Hex.neighbor(axial, dir))
		var dest := Hex.axial_to_offset(Hex.neighbor(Hex.neighbor(axial, dir), dir))
		if not setup.map.in_bounds(foe) or not setup.map.in_bounds(dest):
			continue
		if _occupied(setup, foe) or _occupied(setup, dest):
			continue
		if fallback.is_empty():
			fallback = [foe, dest]
		if dest.y < origin.y:
			return [foe, dest]
	return fallback


func _occupied(setup: GameSetup, cell: Vector2i) -> bool:
	for player in setup.players:
		for unit in player.units:
			if unit.cell == cell:
				return true
	return false


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
