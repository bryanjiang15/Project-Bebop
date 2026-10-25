extends SceneTree

## Real-renderer shots for ticket 12. Not part of CI.
## Writes ticket12_rival_before.png, ticket12_rival_after.png,
## and ticket12_combat_preview_hills.png.

const _RivalFixture = preload("res://tests/rival_fixture.gd")


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
	var placed: Dictionary = _RivalFixture.place(setup)
	if not bool(placed["ok"]):
		print("FAIL fixture ", placed["reason"])
		quit(1)
		return
	game._refresh_board()
	var human_city := placed["human_city"] as MapCity
	var tiles: Array = [
		human_city.cell,
		placed["worked"],
		placed["target"],
		placed["near"],
		placed["far"],
		(placed["rival_city"] as MapCity).cell,
	]
	if not await _frame_tiles(game, tiles):
		return
	_click(game, human_city.cell)
	_click(game, (placed["warrior"] as PlayerState.UnitState).cell)
	if not (game.get_node("%CityPanel") as CanvasItem).visible:
		print("FAIL panel closed")
		quit(1)
		return
	_hover_target(game, placed["target"])
	for _frame in 3:
		await process_frame
	var before_hit := (game.get_node("%CombatPreview") as Label).text
	var before_food := (game.get_node("%CityFood") as Label).text
	var before_prod := (game.get_node("%CityProduction") as Label).text
	if before_hit.is_empty() or not before_hit.begins_with("Damage"):
		print("FAIL preview before '", before_hit, "'")
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket12_rival_before.png"):
		return
	print("BEFORE ", before_food, " ", before_prod, " ", before_hit)
	(game.get_node("%SpellButtons").get_node("Spell_raise_hills") as Button).pressed.emit()
	_click(game, placed["target"])
	(game.get_node("%TooltipPanel") as CanvasItem).visible = false
	for _frame in 3:
		await process_frame
	var after_hit := (game.get_node("%CombatPreview") as Label).text
	var after_food := (game.get_node("%CityFood") as Label).text
	var after_prod := (game.get_node("%CityProduction") as Label).text
	if setup.map.land_at(placed["target"]) != "hills" or after_food == before_food or after_prod == before_prod or after_hit == before_hit:
		print("FAIL after food ", after_food, " prod ", after_prod, " hit ", after_hit, " land ", setup.map.land_at(placed["target"]))
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket12_rival_after.png"):
		return
	print("AFTER ", after_food, " ", after_prod, " ", after_hit)
	if not _composite("/opt/cursor/artifacts/ticket12_rival_before.png", "/opt/cursor/artifacts/ticket12_rival_after.png", "/opt/cursor/artifacts/ticket12_combat_preview_hills.png"):
		return
	print("PREVIEW ", before_hit, " -> ", after_hit)
	quit(0)


func _hover_target(game: Node, cell: Vector2i) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var local: Vector2 = map.map_to_local(cell)
	game.hover_at_local(local, Vector2(980, 220))
	(game.get_node("%TooltipPanel") as CanvasItem).visible = false


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
	var pad := Vector2(160.0, 140.0)
	min_p -= pad
	max_p += pad
	var center := (min_p + max_p) * 0.5
	var view_center := Vector2(1280, 720)
	var safe := Rect2(Vector2(940, 280), Vector2(660, 700))
	for zoom in [1.35, 1.15, 1.0, 0.85]:
		var half: Vector2 = (max_p - min_p) * 0.5 * zoom
		var desired := Vector2(1280, 620)
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
		return true
	camera.zoom = Vector2(1.0, 1.0)
	camera.position = map.map_to_local(cells[2])
	game._clamp_camera()
	await process_frame
	return true


func _composite(before_path: String, after_path: String, out_path: String) -> bool:
	var before := Image.load_from_file(before_path)
	var after := Image.load_from_file(after_path)
	if before == null or after == null:
		print("FAIL composite load")
		quit(1)
		return false
	var panel := Rect2i(16, 740, 888, 684)
	var gap := 24
	var image := Image.create(panel.size.x * 2 + gap, panel.size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.05, 0.05, 0.07, 1))
	image.blit_rect(before, panel, Vector2i(0, 0))
	image.blit_rect(after, panel, Vector2i(panel.size.x + gap, 0))
	var err := image.save_png(out_path)
	if err != OK:
		print("FAIL composite save ", err)
		quit(1)
		return false
	print("WROTE ", out_path, " ", image.get_width(), "x", image.get_height())
	return true


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
