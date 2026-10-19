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
	for _frame in 5:
		await process_frame
	var map := game.get_node("%Map") as TileMapLayer
	var camera := game.get_node("%Camera") as Camera2D
	var cell: Vector2i = setup.human_settler_cell()
	camera.zoom = Vector2(0.9, 0.9)
	camera.position = map.map_to_local(cell)
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
	quit(0)
