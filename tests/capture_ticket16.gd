extends SceneTree

## Real-renderer shots for ticket 16. Not part of CI.
## Writes ticket16_*.png under /opt/cursor/artifacts at 2560×1440.
## The board is staged so one End Turn shows a move, a hit, a founding, and
## a finished unit. See the STAGED line for every change.


const CENTER := Vector2i(14, 9)
const ZOOM := 1.15


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	DirAccess.make_dir_recursive_absolute("/tmp/bebop-capture-logs")
	if not _pin_config():
		return
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
	var plan := _stage(setup)
	if plan.is_empty():
		return
	game._refresh_board()
	_frame(game, CENTER, ZOOM)
	for _frame in 3:
		await process_frame
	_click(game, _step(CENTER, Hex.NORTHEAST, 1))
	var end := game.get_node("%EndTurnButton") as Button
	if end.text != "End Turn (Enter)":
		print("FAIL end button before the turn '", end.text, "'")
		quit(1)
		return
	game._clear_hover()
	if not await _save("/opt/cursor/artifacts/ticket16_before_end_turn.png"):
		return
	var turn := setup.turn
	var victim_hp: int = plan["victim_hp"]
	var attacker_cell: Vector2i = plan["attacker_cell"]
	var ids_before := {}
	for player in setup.players:
		for unit in player.units:
			ids_before[unit.id] = true
	end.pressed.emit()
	if setup.turn != turn + 1 or setup.result != null:
		print("FAIL end turn ", setup.turn, " result ", setup.result)
		quit(1)
		return
	var attacker: PlayerState.UnitState = plan["attacker"]
	var victim: PlayerState.UnitState = plan["victim"]
	var found_cell: Vector2i = plan["found_cell"]
	var factory: MapCity = plan["factory"]
	var founded := setup.city_at_cell(found_cell)
	if attacker.cell == attacker_cell or victim.hp >= victim_hp or founded == null or founded.player != 1:
		print("FAIL after rivals attacker ", attacker.cell, " from ", attacker_cell, " victim ", victim.cell, " hp ", victim.hp, " city ", founded)
		quit(1)
		return
	var spawned := false
	for player in setup.players:
		for unit in player.units:
			if not ids_before.has(unit.id):
				spawned = true
	if not spawned:
		print("FAIL no produced unit queue ", factory.queue.size(), " stored ", factory.production_stored)
		quit(1)
		return
	print("STAGED seed ", setup.seed_used, " disk r5 at ", CENTER, " painted water except the city centers, the settler, the warrior's one step, the target, and the push hex (those are plains). Human settler moved to ", CENTER, " and founded for vision. Human warrior parked at (2, 2), fortified. Rivals moved onto the ring. Victim hp ", victim_hp, " ap 0. Factory production_stored 30 so the queued warrior finishes this End Turn. Camera zoom ", ZOOM)
	print("RESULT attacker ", attacker_cell, " -> ", attacker.cell, " victim hp ", victim_hp, " -> ", victim.hp, " at ", victim.cell, " city ", found_cell, " units ", setup.unit_total())
	game._refresh_board()
	var map := game.get_node("%Map") as TileMapLayer
	var between: Vector2 = (map.map_to_local(attacker_cell) + map.map_to_local(attacker.cell)) * 0.5
	_frame_at(game, between, 1.7)
	for _frame in 3:
		await process_frame
	game._clear_hover()
	if not await _save("/opt/cursor/artifacts/ticket16_rival_moved.png"):
		return
	_frame(game, victim.cell, 2.4)
	for _frame in 3:
		await process_frame
	game._clear_hover()
	if not await _save("/opt/cursor/artifacts/ticket16_rival_ability.png"):
		return
	_frame(game, found_cell, 1.35)
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket16_rival_founded.png"):
		return
	_frame(game, factory.cell, 1.35)
	for _frame in 3:
		await process_frame
	if not await _save("/opt/cursor/artifacts/ticket16_rival_produced.png"):
		return
	print("CAPTURE OK")
	quit(0)


func _pin_config() -> bool:
	var data := GameConfig.read_json(GameConfig.PATH)
	if data.is_empty():
		print("FAIL could not read config")
		quit(1)
		return false
	var map: Dictionary = data["map"]
	map["seed"] = 12345
	data["map"] = map
	var log: Dictionary = data["log"]
	log["enabled"] = true
	log["directory"] = "/tmp/bebop-capture-logs"
	data["log"] = log
	var err := SceneDriver.write_json("/tmp/bebop-capture-config.json", data)
	if not err.is_empty():
		print("FAIL ", err)
		quit(1)
		return false
	GameConfig.path_override = "/tmp/bebop-capture-config.json"
	GameLog.directory_override = "/tmp/bebop-capture-logs"
	return true


## Returns the staged actors. Empty when the layout cannot be built.
func _stage(setup: GameSetup) -> Dictionary:
	var settler := _unit(setup, 0, "settler")
	var human_warrior := _unit(setup, 0, "warrior")
	var rival_settler := _unit(setup, 1, "settler")
	var attacker := _unit(setup, 1, "warrior")
	var builder := _unit(setup, 2, "settler")
	var victim := _unit(setup, 2, "warrior")
	if settler == null or human_warrior == null or rival_settler == null or attacker == null or builder == null or victim == null:
		print("FAIL roster")
		quit(1)
		return {}
	_paint_disk(setup, CENTER, 5)
	var slot := 0
	for player in setup.players:
		for unit in player.units:
			var park := Vector2i(slot, 0)
			_paint_plains(setup, park)
			unit.cell = park
			slot += 1
	setup._refresh_fog()
	settler.cell = CENTER
	setup._refresh_fog()
	if not setup.can_found(settler).is_empty():
		print("FAIL human cannot found at ", CENTER, " ", setup.can_found(settler))
		quit(1)
		return {}
	var home := setup.found_city(settler)
	if home == null:
		print("FAIL human city")
		quit(1)
		return {}
	var layout := _layout(setup, home)
	if layout.is_empty():
		print("FAIL no readable layout")
		quit(1)
		return {}
	var found_cell: Vector2i = layout["found"]
	var factory_cell: Vector2i = layout["factory"]
	var attacker_cell: Vector2i = layout["attacker"]
	var victim_cell: Vector2i = layout["victim"]
	var step_cell: Vector2i = layout["step"]
	var away_cell: Vector2i = layout["away"]
	# One plains step. Every other route is water, so the warrior cannot spend
	# both AP walking and still has a point left to strike.
	_paint_disk_land(setup, CENTER, 5, "water")
	for cell in [CENTER, found_cell, factory_cell, attacker_cell, victim_cell, step_cell, away_cell]:
		_paint_plains(setup, cell)
	human_warrior.cell = Vector2i(2, 2)
	_paint_plains(setup, human_warrior.cell)
	human_warrior.ap = 0
	human_warrior.order = GameSetup.ORDER_FORTIFY
	human_warrior.fortified = true
	human_warrior.acted = false
	builder.cell = factory_cell
	setup._refresh_fog()
	if not setup.can_found(builder).is_empty():
		print("FAIL factory site ", setup.can_found(builder))
		quit(1)
		return {}
	var factory := setup.found_city(builder)
	if factory == null:
		print("FAIL factory city")
		quit(1)
		return {}
	if not setup.enqueue(factory, "warrior").is_empty():
		print("FAIL enqueue")
		quit(1)
		return {}
	factory.production_stored = 30
	rival_settler.cell = found_cell
	rival_settler.ap = 2
	rival_settler.order = ""
	rival_settler.acted = false
	attacker.cell = attacker_cell
	attacker.ap = 2
	attacker.order = ""
	attacker.acted = false
	attacker.hp = attacker.max_hp
	victim.cell = victim_cell
	victim.ap = 0
	victim.order = ""
	victim.acted = false
	victim.hp = 40
	setup._refresh_fog()
	if not setup.can_found(rival_settler).is_empty() or not RivalAI._good_found(setup, rival_settler, found_cell):
		print("FAIL rival will not found ", setup.can_found(rival_settler))
		quit(1)
		return {}
	if not setup.fog.unit_visible(0, found_cell) or not setup.fog.unit_visible(0, attacker_cell) or not setup.fog.unit_visible(0, victim_cell) or not setup.fog.unit_visible(0, factory_cell):
		print("FAIL cluster is not visible")
		quit(1)
		return {}
	return {
		"attacker": attacker,
		"victim": victim,
		"factory": factory,
		"found_cell": found_cell,
		"attacker_cell": attacker_cell,
		"victim_hp": victim.hp,
	}


func _layout(setup: GameSetup, home: MapCity) -> Dictionary:
	var center := Hex.offset_to_axial(CENTER)
	var ring2 := Hex.ring(center, 2)
	var ring3 := Hex.ring(center, 3)
	for victim_hex in ring2:
		var victim := Hex.axial_to_offset(victim_hex)
		if not setup.map.in_bounds(victim):
			continue
		for attacker_hex in ring3:
			var attacker := Hex.axial_to_offset(attacker_hex)
			if not setup.map.in_bounds(attacker):
				continue
			if Hex.distance(attacker_hex, victim_hex) != 2:
				continue
			var step := _only_step(setup, attacker, victim, home)
			if step.x < 0:
				continue
			var away := _beyond(step, victim)
			if not setup.map.in_bounds(away) or away == CENTER or away == attacker or away == victim:
				continue
			for found_hex in ring3:
				var found := Hex.axial_to_offset(found_hex)
				if found == attacker or found == step or found == away:
					continue
				if not setup.map.in_bounds(found):
					continue
				if Hex.distance(found_hex, victim_hex) < 3 or Hex.distance(found_hex, attacker_hex) < 3:
					continue
				for factory_hex in ring3:
					var factory := Hex.axial_to_offset(factory_hex)
					if factory == found or factory == attacker or factory == step or factory == victim or factory == away:
						continue
					if not setup.map.in_bounds(factory):
						continue
					if Hex.distance(factory_hex, found_hex) < 4:
						continue
					if Hex.distance(factory_hex, attacker_hex) < 3 or Hex.distance(factory_hex, victim_hex) < 3:
						continue
					return {"found": found, "factory": factory, "attacker": attacker, "victim": victim, "step": step, "away": away}
	return {}


func _only_step(setup: GameSetup, attacker: Vector2i, victim: Vector2i, home: MapCity) -> Vector2i:
	var closer: Array[Vector2i] = []
	var from := Hex.offset_to_axial(attacker)
	var goal := Hex.distance(from, Hex.offset_to_axial(victim))
	for hex in Hex.neighbors(from):
		var cell := Hex.axial_to_offset(hex)
		if not setup.map.in_bounds(cell) or setup.map.land_at(cell) == "water":
			continue
		if cell == home.cell or cell == CENTER:
			continue
		if Hex.distance(hex, Hex.offset_to_axial(victim)) < goal:
			closer.append(cell)
	if closer.size() != 1:
		return Vector2i(-1, -1)
	return closer[0]


func _beyond(step: Vector2i, victim: Vector2i) -> Vector2i:
	var from := Hex.offset_to_axial(step)
	var at := Hex.offset_to_axial(victim)
	return Hex.axial_to_offset(at + (at - from))


func _paint_disk(setup: GameSetup, center: Vector2i, radius: int) -> void:
	_paint_disk_land(setup, center, radius, "plains")


func _paint_disk_land(setup: GameSetup, center: Vector2i, radius: int, land_id: String) -> void:
	for hex in Hex.disk(Hex.offset_to_axial(center), radius):
		var cell := Hex.axial_to_offset(hex)
		if setup.map.in_bounds(cell):
			setup.map.set_land(cell, land_id)


func _paint_plains(setup: GameSetup, cell: Vector2i) -> void:
	if setup.map.in_bounds(cell):
		setup.map.set_land(cell, "plains")


func _unit(setup: GameSetup, player: int, unit_type: String) -> PlayerState.UnitState:
	for unit in setup.players[player].units:
		if unit.unit_type == unit_type:
			return unit
	return null


func _frame(game: Node, cell: Vector2i, zoom: float) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	_frame_at(game, map.map_to_local(cell), zoom)


func _frame_at(game: Node, local: Vector2, zoom: float) -> void:
	var camera := game.get_node("%Camera") as Camera2D
	camera.zoom = Vector2(zoom, zoom)
	camera.position = local
	game._clamp_camera()


func _step(cell: Vector2i, direction: int, steps: int) -> Vector2i:
	var axial := Hex.offset_to_axial(cell)
	for _i in steps:
		axial = Hex.neighbor(axial, direction)
	return Hex.axial_to_offset(axial)


func _click(game: Node, cell: Vector2i) -> void:
	SceneDriver.click_cell(game, cell)


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
