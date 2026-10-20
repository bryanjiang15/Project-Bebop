extends SceneTree

## Drives the real button signals and the game scene's input handler.

const _LAND_COLUMN := {
	"plains": 0,
	"forest": 1,
	"hills": 2,
	"water": 3,
	"volcanic": 4,
}


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
	if not _assert_new_game(game):
		return
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
	if not _assert_new_game(game):
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


func _assert_new_game(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	if setup == null or setup.map == null or setup.fog == null:
		print("FAIL game has no generated setup")
		quit(1)
		return false
	if setup.map.width != 28 or setup.map.height != 18:
		print("FAIL map size")
		quit(1)
		return false
	if setup.players.size() != 3 or setup.unit_total() != 3:
		print("FAIL players ", setup.players.size(), " units ", setup.unit_total())
		quit(1)
		return false
	var lands := {}
	for land_id in setup.map.lands:
		lands[land_id] = true
	if lands.size() != 5:
		print("FAIL land types ", lands.keys())
		quit(1)
		return false
	var human_cell := setup.human_settler_cell()
	if setup.fog.sight(setup.human_index, human_cell) != FogState.Sight.VISIBLE:
		print("FAIL human settler tile is not visible")
		quit(1)
		return false
	var hidden := Vector2i(-1, -1)
	var shown := 0
	for player in setup.players:
		for unit in player.units:
			if unit.unit_type != "settler":
				print("FAIL unexpected unit ", unit.unit_type)
				quit(1)
				return false
			if setup.fog.unit_visible(setup.human_index, unit.cell):
				shown += 1
	for row in setup.map.height:
		for col in setup.map.width:
			var cell := Vector2i(col, row)
			if setup.fog.sight(setup.human_index, cell) == FogState.Sight.UNREVEALED:
				hidden = cell
				break
		if hidden.x >= 0:
			break
	if hidden.x < 0:
		print("FAIL no unrevealed tile")
		quit(1)
		return false
	if not _assert_unrevealed_atlas(game, setup):
		return false
	var actors := game.get_node("%Actors")
	if actors.get_child_count() != shown:
		print("FAIL visible sprites ", actors.get_child_count(), " expected ", shown)
		quit(1)
		return false
	if not _hover(game, hidden, false):
		return false
	if not _hover(game, human_cell, true):
		return false
	print("PASS new game seed ", setup.seed_used, " sprites ", shown)
	return true


func _assert_unrevealed_atlas(game: Node, setup: GameSetup) -> bool:
	var map := game.get_node("%Map") as TileMapLayer
	var lands := {}
	var shared_source := 0
	var shared_atlas := Vector2i.ZERO
	var have := false
	for row in setup.map.height:
		for col in setup.map.width:
			var cell := Vector2i(col, row)
			if setup.fog.sight(setup.human_index, cell) != FogState.Sight.UNREVEALED:
				continue
			var land := setup.map.land_at(cell)
			lands[land] = true
			var source := map.get_cell_source_id(cell)
			var atlas := map.get_cell_atlas_coords(cell)
			if not have:
				shared_source = source
				shared_atlas = atlas
				have = true
			elif source != shared_source or atlas != shared_atlas:
				print("FAIL unrevealed atlas depends on land ", land, " cell ", cell, " source ", source, " atlas ", atlas)
				quit(1)
				return false
			if source == 0 and atlas == Vector2i(int(_LAND_COLUMN[land]), 0):
				print("FAIL unrevealed ", land, " still uses its land atlas at ", cell)
				quit(1)
				return false
	if lands.size() < 2:
		print("FAIL unrevealed tiles did not include two land types")
		quit(1)
		return false
	var visible: Vector2i = setup.human_settler_cell()
	var visible_land := setup.map.land_at(visible)
	var expected := Vector2i(int(_LAND_COLUMN[visible_land]), 0)
	if map.get_cell_source_id(visible) != 0 or map.get_cell_atlas_coords(visible) != expected:
		print("FAIL visible tile atlas ", map.get_cell_atlas_coords(visible), " land ", visible_land)
		quit(1)
		return false
	print("PASS unrevealed atlas ignores land type")
	return true


func _hover(game: Node, cell: Vector2i, expect_land: bool) -> bool:
	var map := game.get_node("%Map") as TileMapLayer
	var local: Vector2 = map.map_to_local(cell)
	var world: Vector2 = map.to_global(local)
	var screen: Vector2 = game.get_viewport().get_canvas_transform() * world
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	game._unhandled_input(motion)
	var tip := (game.get_node("%Tooltip") as Label).text
	var land := str((game.get("setup") as GameSetup).map.land_at(cell))
	if expect_land:
		if not tip.contains(land) or tip.contains("Unexplored"):
			print("FAIL visible tooltip: '", tip, "' land ", land)
			quit(1)
			return false
	else:
		if tip.contains(land) or not tip.contains("Unexplored"):
			print("FAIL hidden tooltip: '", tip, "' land ", land)
			quit(1)
			return false
	print("PASS tooltip ", tip)
	return true


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
