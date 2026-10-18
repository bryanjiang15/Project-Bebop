extends SceneTree

## Renders the in-game scene with a hovered tile and writes a PNG.
## User argument after `--` is the output path.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path := "/tmp/bebop_ingame.png" if args.is_empty() else args[0]
	change_scene_to_file("res://scenes/game.tscn")
	var game: Node = null
	for _i in 30:
		await process_frame
		var scene := current_scene
		if scene != null and scene.get_script() != null and scene.get_script().resource_path == "res://scripts/view/game_view.gd":
			game = scene
			break
	if game == null:
		print("FAIL game scene")
		quit(1)
		return
	for _frame in 5:
		await process_frame
	var cell := Vector2i(8, 4)
	var map := game.get_node("%Map") as TileMapLayer
	var local: Vector2 = map.map_to_local(cell)
	var camera := game.get_node("%Camera") as Camera2D
	camera.zoom = Vector2(0.38, 0.38)
	camera.position = map.map_to_local(Vector2i(13, 8))
	var world: Vector2 = map.to_global(local)
	var screen: Vector2 = game.get_viewport().get_canvas_transform() * world
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	game._unhandled_input(motion)
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
	print("TOOLTIP ", (game.get_node("%Tooltip") as Label).text)
	quit(0)
