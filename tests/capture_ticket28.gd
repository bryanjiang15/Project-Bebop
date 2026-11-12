extends SceneTree

## Real-renderer shots for ticket 28. Not part of CI.
## Writes the six ticket28_*.png files under /opt/cursor/artifacts.


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
	var center := _open_center(setup)
	if center.x < 0:
		print("FAIL no open disk")
		quit(1)
		return
	var axial := Hex.offset_to_axial(center)
	var stand := Hex.axial_to_offset(Hex.neighbor(axial, Hex.WEST))
	var east := Hex.axial_to_offset(Hex.neighbor(axial, Hex.EAST))
	var north := Hex.axial_to_offset(Hex.neighbor(axial, Hex.NORTHEAST))
	var south := Hex.axial_to_offset(Hex.neighbor(axial, Hex.SOUTHEAST))
	var city_cell := Hex.axial_to_offset(Hex.neighbor(axial, Hex.NORTHWEST))
	for hex in Hex.disk(axial, 1):
		setup.map.set_land(Hex.axial_to_offset(hex), "plains")
	var archer := setup.spawn_unit(0, "archer", stand)
	if archer == null:
		print("FAIL archer did not spawn")
		quit(1)
		return
	game._refresh_board()
	_frame(game, center)
	for _frame in 4:
		await process_frame
	if not _select_unit(game, stand, "Archer"):
		return
	if not _bar_ready(game):
		return
	if not _panels_clear(game):
		return
	game._clear_hover()
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket28_bar_archer.png"):
		return
	var east_unit := setup.spawn_unit(1, "warrior", east)
	var north_unit := setup.spawn_unit(1, "warrior", north)
	var founded := setup.found_city(setup.spawn_unit(1, "settler", city_cell))
	if east_unit == null or north_unit == null or founded == null:
		print("FAIL enemies did not spawn")
		quit(1)
		return
	game._refresh_board()
	_frame(game, center)
	if not _select_unit(game, stand, "Archer"):
		return
	var volley := SceneDriver.ability_button(game, "volley")
	volley.pressed.emit()
	_hover(game, center)
	var preview: Dictionary = setup.ability_preview(archer, "volley", center)
	var shown := (game.get_node("%CombatPreview") as Label).text
	var line: String = game._preview_line(preview)
	var city_hit: Dictionary = {}
	for hit in preview["hits"]:
		if (hit as Dictionary)["cell"] == city_cell:
			city_hit = hit
	if not bool(preview["ok"]) or (preview["hits"] as Array).size() != 3 or city_hit.is_empty() or int(city_hit["counter"]) != 0 or shown != line or not shown.contains(", ") or not shown.contains(str(int(city_hit["damage"]))) or not shown.ends_with("Counter 0"):
		print("FAIL volley preview '", shown, "' expected '", line, "'")
		quit(1)
		return
	if not _highlight_is(game, city_cell, Color(0.95, 0.32, 0.28, 0.95)):
		print("FAIL enemy city is not a hit highlight")
		quit(1)
		return
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket28_volley_preview.png"):
		return
	var friend := setup.spawn_unit(0, "scout", south)
	if friend == null:
		print("FAIL skip fixtures")
		quit(1)
		return
	game._refresh_board()
	_hover(game, center)
	preview = setup.ability_preview(archer, "volley", center)
	shown = (game.get_node("%CombatPreview") as Label).text
	line = game._preview_line(preview)
	if shown != line or str(preview["skipped"].get(south, "")) != "friendly" or preview["skipped"].has(city_cell):
		print("FAIL skipped preview '", shown, "'")
		quit(1)
		return
	if not _highlight_is(game, south, Color(0.78, 0.78, 0.82, 0.75)) or not _highlight_is(game, city_cell, Color(0.95, 0.32, 0.28, 0.95)):
		print("FAIL skipped tint")
		quit(1)
		return
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket28_volley_preview_skipped.png"):
		return
	# Full bars hide a 22-point hit. Leave both enemies low enough that the
	# same shot turns the bars red, without changing the preview numbers.
	east_unit.hp = 36
	north_unit.hp = 36
	founded.hp = 40
	var east_before := east_unit.hp
	var north_before := north_unit.hp
	var city_hp := founded.hp
	var city_where := founded.cell
	var friend_hp := friend.hp
	_click(game, center)
	if east_unit.hp >= east_before or north_unit.hp >= north_before or friend.hp != friend_hp or founded.hp >= city_hp or founded.cell != city_where or archer.ap != 0 or archer.cell != stand:
		print("FAIL volley result")
		quit(1)
		return
	game._clear_hover()
	_frame(game, center)
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket28_after_volley.png"):
		return
	if not _select_unit(game, stand, "Archer"):
		return
	game._clear_hover()
	volley = SceneDriver.ability_button(game, "volley")
	var ap_text := (game.get_node("%AbilityApLabel") as Label).text
	var cooldown := (volley.get_node("Column/CooldownLabel") as Label).text
	if ap_text != "AP 0 / 2" or cooldown != "Cooldown 3" or not volley.disabled:
		print("FAIL cooldown '", cooldown, "' ", ap_text)
		quit(1)
		return
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket28_cooldown.png"):
		return
	var pair := _distant_pair(setup, center)
	if pair.is_empty():
		print("FAIL no distant shoot pair")
		quit(1)
		return
	var bow: Vector2i = pair[0]
	var foe_cell: Vector2i = pair[1]
	setup.map.set_land(bow, "plains")
	setup.map.set_land(foe_cell, "plains")
	var shooter := setup.spawn_unit(0, "archer", bow)
	var target := setup.spawn_unit(1, "warrior", foe_cell)
	if shooter == null or target == null:
		print("FAIL shoot pair")
		quit(1)
		return
	game._refresh_board()
	_frame(game, bow, 1.45)
	if not _select_unit(game, bow, "Archer"):
		return
	var shoot := SceneDriver.ability_button(game, "shoot")
	shoot.pressed.emit()
	_hover(game, foe_cell)
	var shot: Dictionary = setup.ability_preview(shooter, "shoot", foe_cell)
	shown = (game.get_node("%CombatPreview") as Label).text
	line = game._preview_line(shot)
	if not bool(shot["ok"]) or int(shot["counter"]) != 0 or shown != line or shown.contains(",") or not shown.begins_with("Damage "):
		print("FAIL shoot preview '", shown, "'")
		quit(1)
		return
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket28_shoot_unchanged.png"):
		return
	print("CAPTURE OK")
	quit(0)


func _bar_ready(game: Node) -> bool:
	var buttons := game.get_node("%AbilityButtons")
	var shoot := buttons.get_node_or_null("Ability_shoot") as Button
	var volley := buttons.get_node_or_null("Ability_volley") as Button
	if shoot == null or volley == null or shoot.disabled or volley.disabled:
		print("FAIL archer abilities missing")
		quit(1)
		return false
	if (shoot.get_node("Column/NameLabel") as Label).text != "Shoot":
		print("FAIL shoot name")
		quit(1)
		return false
	if (volley.get_node("Column/NameLabel") as Label).text != "Volley":
		print("FAIL volley name")
		quit(1)
		return false
	if (volley.get_node("Column/CooldownLabel") as Label).text != "3":
		print("FAIL volley cooldown label")
		quit(1)
		return false
	var names: PackedStringArray = []
	for child in buttons.get_children():
		names.append(str(child.name))
	if names != PackedStringArray(["Ability_shoot", "Ability_volley", "OrderGap", "Order_skip", "Order_fortify"]):
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


func _open_center(setup: GameSetup) -> Vector2i:
	for row in range(4, setup.map.height - 4):
		for col in range(4, setup.map.width - 4):
			var center := Vector2i(col, row)
			var open := true
			for hex in Hex.disk(Hex.offset_to_axial(center), 2):
				var cell := Hex.axial_to_offset(hex)
				if not setup.map.in_bounds(cell) or _occupied(setup, cell) or setup.city_at_cell(cell) != null:
					open = false
					break
			if open:
				return center
	return Vector2i(-1, -1)


func _distant_pair(setup: GameSetup, away: Vector2i) -> Array:
	var away_axial := Hex.offset_to_axial(away)
	for row in range(setup.map.height - 4, 3, -1):
		for col in range(setup.map.width - 4, 3, -1):
			var bow := Vector2i(col, row)
			if Hex.distance(Hex.offset_to_axial(bow), away_axial) < 14:
				continue
			var foe := _step(bow, Hex.EAST, 1)
			if not setup.map.in_bounds(foe):
				continue
			if _occupied(setup, bow) or _occupied(setup, foe):
				continue
			if setup.city_at_cell(bow) != null or setup.city_at_cell(foe) != null:
				continue
			return [bow, foe]
	return []


func _occupied(setup: GameSetup, cell: Vector2i) -> bool:
	for player in setup.players:
		for unit in player.units:
			if unit.cell == cell:
				return true
	return false


func _frame(game: Node, cell: Vector2i, zoom: float = 1.05) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var camera := game.get_node("%Camera") as Camera2D
	camera.zoom = Vector2(zoom, zoom)
	camera.position = map.map_to_local(cell) + Vector2(0, 40)
	game._clamp_camera()


func _hover(game: Node, cell: Vector2i) -> void:
	var map := game.get_node("%Map") as TileMapLayer
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
