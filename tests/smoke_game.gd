extends SceneTree

## Drives the real button signals and the game scene's input handler.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file("res://scenes/main_menu.tscn")
	var menu := await _wait_for("res://scripts/view/main_menu.gd")
	if menu == null:
		return
	(menu.get_node("%NewGameButton") as Button).pressed.emit()
	var game := await _wait_for("res://scripts/view/game_view.gd")
	if game == null:
		return
	var cell := Vector2i(8, 4)
	var map := game.get_node("%Map") as TileMapLayer
	var local: Vector2 = map.map_to_local(cell)
	var world: Vector2 = map.to_global(local)
	var screen: Vector2 = game.get_viewport().get_canvas_transform() * world
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	game._unhandled_input(motion)
	var tip := (game.get_node("%Tooltip") as Label).text
	if tip != "6, 4 forest":
		print("FAIL tooltip: '", tip, "'")
		quit(1)
		return
	print("PASS tooltip ", tip)
	(game.get_node("%EndTurnButton") as Button).pressed.emit()
	var turn := (game.get_node("%TurnLabel") as Label).text
	if turn != "2 / 50":
		print("FAIL turn: '", turn, "'")
		quit(1)
		return
	print("PASS turn ", turn)
	(game.get_node("%MenuButton") as Button).pressed.emit()
	(game.get_node("%RestartButton") as Button).pressed.emit()
	game = await _wait_for("res://scripts/view/game_view.gd")
	if game == null:
		return
	turn = (game.get_node("%TurnLabel") as Label).text
	if turn != "1 / 50":
		print("FAIL restart turn: '", turn, "'")
		quit(1)
		return
	print("PASS restart ", turn)
	var victory_event := InputEventAction.new()
	victory_event.action = "debug_victory"
	victory_event.pressed = true
	game._unhandled_input(victory_event)
	var victory := await _wait_for("res://scripts/view/end_screen.gd")
	if victory == null:
		return
	if (victory.get_node("%Title") as Label).text != "Victory":
		print("FAIL victory title")
		quit(1)
		return
	if victory.get_node_or_null("%RestartButton") == null or victory.get_node_or_null("%MainMenuButton") == null:
		print("FAIL victory buttons")
		quit(1)
		return
	print("PASS victory")
	(victory.get_node("%MainMenuButton") as Button).pressed.emit()
	var back := await _wait_for("res://scripts/view/main_menu.gd")
	if back == null:
		return
	(back.get_node("%NewGameButton") as Button).pressed.emit()
	game = await _wait_for("res://scripts/view/game_view.gd")
	if game == null:
		return
	var defeat_event := InputEventAction.new()
	defeat_event.action = "debug_defeat"
	defeat_event.pressed = true
	game._unhandled_input(defeat_event)
	var defeat := await _wait_for("res://scripts/view/end_screen.gd")
	if defeat == null:
		return
	if (defeat.get_node("%Title") as Label).text != "Defeat":
		print("FAIL defeat title")
		quit(1)
		return
	print("PASS defeat")
	print("SMOKE OK")
	quit(0)


func _wait_for(script_path: String) -> Node:
	for _i in 30:
		await process_frame
		var scene := current_scene
		if scene != null and scene.get_script() != null and scene.get_script().resource_path == script_path:
			await process_frame
			return scene
	print("FAIL scene did not load: ", script_path)
	quit(1)
	return null
