extends SceneTree

## One full score game through SoakPolicy, with the real renderer at 2560×1440.
## Not part of CI. Writes the ticket 20 shots under /opt/cursor/artifacts.


const LOG_DIR := "/tmp/bebop-ticket20-capture-logs"
const CONFIG_PATH := "/tmp/bebop-ticket20-capture-config.json"
const SEED := 12345
const FRAME_BUDGET := 120


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	_size_window()
	if not _write_config():
		return
	GameLog.directory_override = ""
	GameConfig.path_override = CONFIG_PATH
	SceneDriver.remove_tree(LOG_DIR)
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	change_scene_to_file("res://scenes/main_menu.tscn")
	var menu := await SceneDriver.wait_for(self, "res://scripts/view/main_menu.gd", FRAME_BUDGET, "main menu")
	if menu == null:
		return
	(menu.get_node("%NewGameButton") as Button).pressed.emit()
	var game := await SceneDriver.wait_for(self, "res://scripts/view/game_view.gd", FRAME_BUDGET, "new game")
	if game == null:
		return
	var policy := SoakPolicy.new()
	policy.mode = SoakPolicy.MODE_SCORE
	var setup := game.get("setup") as GameSetup
	if setup == null or setup.seed_used != SEED:
		print("FAIL capture seed")
		quit(1)
		return
	var guard := 0
	while guard < 80:
		guard += 1
		setup = game.get("setup") as GameSetup
		if setup.result != null:
			break
		if setup.turn == 1 or setup.turn == 25 or setup.turn == 50:
			_present(game)
			var shot := "/opt/cursor/artifacts/ticket20_turn1.png"
			if setup.turn == 25:
				shot = "/opt/cursor/artifacts/ticket20_turn25.png"
			elif setup.turn == 50:
				shot = "/opt/cursor/artifacts/ticket20_turn50_board.png"
			if not await _save(shot):
				return
		var before := setup.turn
		var status := policy.play_turn(game)
		if status.begins_with("FAIL"):
			print(status)
			quit(1)
			return
		setup = game.get("setup") as GameSetup
		if setup.result != null or status == SoakPolicy.ENDED:
			break
		if setup.turn != before + 1:
			print("FAIL capture turn did not advance from ", before)
			quit(1)
			return
		await process_frame
	var screen := await SceneDriver.wait_for(self, "res://scripts/view/end_screen.gd", FRAME_BUDGET, "end screen")
	if screen == null:
		return
	var result := MatchResult.latest
	if result == null or result.ending != MatchResult.REASON_SCORE or result.turn != 50:
		print("FAIL capture ending ", result)
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket20_end_screen.png"):
		return
	if not _write_config():
		return
	(screen.get_node("%RestartButton") as Button).pressed.emit()
	game = await SceneDriver.wait_for(self, "res://scripts/view/game_view.gd", FRAME_BUDGET, "restart")
	if game == null:
		return
	setup = game.get("setup") as GameSetup
	var turn := (game.get_node("%TurnLabel") as Label).text
	if setup == null or turn != "1 / 50" or setup.turn != 1 or setup.result != null:
		print("FAIL capture restart '", turn, "'")
		quit(1)
		return
	if not await _save("/opt/cursor/artifacts/ticket20_after_restart.png"):
		return
	print("CAPTURE OK")
	quit(0)


func _write_config() -> bool:
	var data := GameConfig.read_json(GameConfig.PATH)
	if data.is_empty():
		print("FAIL could not read the base config")
		quit(1)
		return false
	var map: Dictionary = data["map"]
	map["seed"] = SEED
	data["map"] = map
	var log: Dictionary = data["log"]
	log["enabled"] = true
	log["directory"] = LOG_DIR
	data["log"] = log
	var err := SceneDriver.write_json(CONFIG_PATH, data)
	if not err.is_empty():
		print("FAIL ", err)
		quit(1)
		return false
	return true


## The previous turn ends with the menu open, on purpose, to prove End Turn
## still works. Close it, and drop a tooltip left by an off-camera click, so
## the shot shows the board.
func _present(game: Node) -> void:
	var menu := game.get_node("%InGameMenu") as CanvasItem
	if menu.visible:
		(game.get_node("%MenuButton") as Button).pressed.emit()
	if game.has_method("_clear_hover"):
		game._clear_hover()


func _size_window() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(2560, 1440))
	DisplayServer.window_set_position(Vector2i(0, 0))


func _save(path: String) -> bool:
	_size_window()
	for _frame in 2:
		await process_frame
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
	print("WROTE ", path)
	return true
