extends SceneTree

## Opens the main menu, presses New Game, and writes a PNG of the fogged map.
## User argument after `--` is the output path.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path := "/tmp/bebop_ingame.png" if args.is_empty() else args[0]
	change_scene_to_file("res://scenes/main_menu.tscn")
	var menu: Node = null
	for _i in 30:
		await process_frame
		var scene := current_scene
		if scene != null and scene.get_script() != null and scene.get_script().resource_path == "res://scripts/view/main_menu.gd":
			menu = scene
			break
	if menu == null:
		print("FAIL main menu")
		quit(1)
		return
	(menu.get_node("%NewGameButton") as Button).pressed.emit()
	var game: Node = null
	for _i in 30:
		await process_frame
		var scene := current_scene
		if scene != null and scene.get_script() != null and scene.get_script().resource_path == "res://scripts/view/game_view.gd":
			game = scene
			break
	var setup: GameSetup = null
	if game != null:
		setup = game.get("setup") as GameSetup
	if game == null or setup == null:
		print("FAIL game scene")
		quit(1)
		return
	# Seed 0 rolls a new map each Restart. Prefer a start inset from the border
	# so the shot shows fog around the whole visible disk, not the map edge.
	for _try in 24:
		if _inset(setup):
			break
		var previous_seed := setup.seed_used
		(game.get_node("%MenuButton") as Button).pressed.emit()
		(game.get_node("%RestartButton") as Button).pressed.emit()
		game = await _wait_game(previous_seed)
		if game == null:
			return
		setup = game.get("setup") as GameSetup
		if setup == null:
			print("FAIL restart setup")
			quit(1)
			return
	for _frame in 5:
		await process_frame
	var map := game.get_node("%Map") as TileMapLayer
	var camera := game.get_node("%Camera") as Camera2D
	var cell: Vector2i = setup.human_settler_cell()
	_frame_visible_and_fog(map, camera, setup)
	for _frame in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.get_width() == 0:
		print("FAIL empty framebuffer")
		quit(1)
		return
	image.save_png(out_path)
	print("WROTE ", out_path, " ", image.get_width(), "x", image.get_height())
	print("SEED ", setup.seed_used)
	print("SETTLER ", cell)
	print("ZOOM ", camera.zoom)
	quit(0)


func _inset(setup: GameSetup) -> bool:
	var cell := setup.human_settler_cell()
	return cell.x >= 6 and cell.y >= 6 and cell.x < setup.map.width - 6 and cell.y < setup.map.height - 6


func _wait_game(previous_seed: int) -> Node:
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
	print("FAIL game scene")
	quit(1)
	return null


## Fit every visible tile, plus a ring of fog, inside the window under the top bar.
func _frame_visible_and_fog(map: TileMapLayer, camera: Camera2D, setup: GameSetup) -> void:
	var tile := Vector2(map.tile_set.tile_size)
	var bounds := Rect2()
	var started := false
	for row in setup.map.height:
		for col in setup.map.width:
			var cell := Vector2i(col, row)
			if setup.fog.sight(setup.human_index, cell) != FogState.Sight.VISIBLE:
				continue
			var center: Vector2 = map.map_to_local(cell)
			var rect := Rect2(center - tile * 0.6, tile * 1.2)
			if not started:
				bounds = rect
				started = true
			else:
				bounds = bounds.merge(rect)
	bounds = bounds.grow(tile.x * 1.35)
	var usable := Vector2(1200.0, 600.0)
	var zoom := minf(usable.x / bounds.size.x, usable.y / bounds.size.y)
	zoom = clampf(zoom, 0.4, 1.6)
	camera.zoom = Vector2(zoom, zoom)
	camera.position = bounds.get_center()
	camera.position.y -= 24.0 / zoom
