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
	if not _move_settler(game):
		return
	if not _warrior_orders(game):
		return
	if not _scripted_combat(game):
		return
	if not _found_city(game):
		return
	if not _cast_spell(game):
		return
	if not _end_turn_with_enter(game):
		return
	if not _train_scout(game):
		return
	(game.get_node("%MenuButton") as Button).pressed.emit()
	(game.get_node("%RestartButton") as Button).pressed.emit()
	game = await _wait_for("res://scripts/view/game_view.gd")
	if game == null:
		return
	var turn := (game.get_node("%TurnLabel") as Label).text
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
	var roster := setup.players.size() * setup.config.starting_units.size()
	if setup.players.size() != 3 or setup.unit_total() != roster:
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
		if player.units.size() != setup.config.starting_units.size():
			print("FAIL roster size ", player.units.size())
			quit(1)
			return false
		var occupied := {}
		for i in player.units.size():
			var unit := player.units[i]
			if unit.unit_type != setup.config.starting_units[i] or occupied.has(unit.cell):
				print("FAIL start unit ", unit.unit_type, " ", unit.cell)
				quit(1)
				return false
			occupied[unit.cell] = true
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


func _move_settler(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var origin := setup.human_settler_cell()
	_click_cell(game, origin, MOUSE_BUTTON_LEFT)
	if game.get_node("%MoveHighlights").get_child_count() < 2:
		print("FAIL highlights ", game.get_node("%MoveHighlights").get_child_count())
		quit(1)
		return false
	var unit: PlayerState.UnitState = null
	for candidate in setup.players[setup.human_index].units:
		if candidate.unit_type == "settler":
			unit = candidate
			break
	var tiles: Dictionary = setup.reachable_tiles(unit)
	if tiles.is_empty():
		print("FAIL no reachable tile")
		quit(1)
		return false
	var dest: Vector2i = tiles.keys()[0]
	_click_cell(game, dest, MOUSE_BUTTON_LEFT)
	if setup.human_settler_cell() != origin:
		print("FAIL left click moved the settler to ", setup.human_settler_cell())
		quit(1)
		return false
	print("PASS left click does not move")
	_click_cell(game, origin, MOUSE_BUTTON_LEFT)
	_click_cell(game, dest, MOUSE_BUTTON_RIGHT)
	if setup.human_settler_cell() != dest:
		print("FAIL right click did not move, still ", setup.human_settler_cell())
		quit(1)
		return false
	print("PASS right click moved to ", dest)
	return true


func _end_turn_with_enter(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var during := "%d / 50" % setup.turn
	(game.get_node("%MenuButton") as Button).pressed.emit()
	_press_action(game, "end_turn")
	var turn := (game.get_node("%TurnLabel") as Label).text
	if turn != during:
		print("FAIL enter during menu: '", turn, "'")
		quit(1)
		return false
	print("PASS enter ignored while menu is open")
	var before := setup.turn
	(game.get_node("%MenuButton") as Button).pressed.emit()
	_press_action(game, "end_turn")
	turn = (game.get_node("%TurnLabel") as Label).text
	if setup.turn != before + 1 or turn != "%d / 50" % setup.turn:
		print("FAIL enter turn: '", turn, "' core ", setup.turn, " before ", before)
		quit(1)
		return false
	print("PASS enter ends turn ", turn)
	return true


func _warrior_orders(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var warrior := _human_unit(setup, "warrior")
	if warrior == null:
		print("FAIL no warrior")
		quit(1)
		return false
	_click_cell(game, warrior.cell)
	if (game.get_node("%SelectionTitle") as Label).text != "Warrior":
		print("FAIL selected ", (game.get_node("%SelectionTitle") as Label).text)
		quit(1)
		return false
	var dest := _other_reachable(setup, warrior, setup.human_settler_cell())
	if dest.x < 0:
		var anywhere: Dictionary = setup.reachable_tiles(warrior)
		if anywhere.is_empty():
			print("FAIL warrior has no move")
			quit(1)
			return false
		dest = anywhere.keys()[0]
	_click_cell(game, dest, MOUSE_BUTTON_RIGHT)
	if warrior.cell != dest:
		print("FAIL warrior did not move ", warrior.cell)
		quit(1)
		return false
	(game.get_node("%SkipButton") as Button).pressed.emit()
	var detail := (game.get_node("%SelectionDetail") as Label).text
	if not detail.contains("Order Skip") or not detail.contains("HP %d / %d" % [warrior.hp, warrior.max_hp]):
		print("FAIL skip panel '", detail, "'")
		quit(1)
		return false
	_press_action(game, "fortify_unit")
	detail = (game.get_node("%SelectionDetail") as Label).text
	if not detail.contains("Order Fortify") or not warrior.fortified:
		print("FAIL fortify panel '", detail, "'")
		quit(1)
		return false
	print("PASS skip and fortify")
	var settler := _human_unit(setup, "settler")
	if settler != null and settler.mp <= 0 and not setup.has_unordered_moves(setup.human_index):
		settler.mp = 1
		settler.order = ""
	(game.get_node("%EndTurnButton") as Button).pressed.emit()
	var turn := (game.get_node("%TurnLabel") as Label).text
	var warning := (game.get_node("%EndTurnWarning") as Label).text
	var button := (game.get_node("%EndTurnButton") as Button).text
	if turn != "1 / 50" or warning.is_empty() or button != "End anyway (Enter)":
		print("FAIL warning turn='", turn, "' warning='", warning, "' button='", button, "'")
		quit(1)
		return false
	print("PASS end turn warning")
	(game.get_node("%EndTurnButton") as Button).pressed.emit()
	turn = (game.get_node("%TurnLabel") as Label).text
	warning = (game.get_node("%EndTurnWarning") as Label).text
	button = (game.get_node("%EndTurnButton") as Button).text
	if turn != "2 / 50" or not warning.is_empty() or button != "End Turn (Enter)":
		print("FAIL confirm turn='", turn, "' warning='", warning, "' button='", button, "'")
		quit(1)
		return false
	if not warrior.fortified or warrior.mp != setup.config.unit("warrior").move:
		print("FAIL fortify did not persist mp ", warrior.mp)
		quit(1)
		return false
	print("PASS end turn confirmed")
	return true


func _scripted_combat(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var warrior := _human_unit(setup, "warrior")
	if warrior == null or warrior.mp <= 0:
		print("FAIL warrior cannot attack")
		quit(1)
		return false
	var dest := _open_neighbor(setup, warrior.cell)
	if dest.x < 0:
		print("FAIL no adjacent tile")
		quit(1)
		return false
	setup.map.set_land(dest, "plains")
	var rival := setup.spawn_unit(1, "warrior", dest)
	if rival == null:
		print("FAIL rival did not spawn at ", dest)
		quit(1)
		return false
	game._refresh_board()
	_click_cell(game, warrior.cell)
	if (game.get_node("%SelectionTitle") as Label).text != "Warrior":
		_click_cell(game, warrior.cell)
	if (game.get_node("%SelectionTitle") as Label).text != "Warrior":
		print("FAIL combat selection ", (game.get_node("%SelectionTitle") as Label).text)
		quit(1)
		return false
	if not _hover(game, dest, true):
		return false
	var preview := (game.get_node("%CombatPreview") as Label).text
	var tip := (game.get_node("%Tooltip") as Label).text
	if not preview.contains("Damage") or not preview.contains("Counter") or not tip.contains("Damage") or not tip.contains("Counter"):
		print("FAIL preview '", preview, "' tip '", tip, "'")
		quit(1)
		return false
	var attack_mark := false
	for child in game.get_node("%MoveHighlights").get_children():
		var tint := (child as CanvasItem).modulate
		if tint.r > tint.g and tint.r > tint.b:
			attack_mark = true
	if not attack_mark:
		print("FAIL no attack highlight")
		quit(1)
		return false
	print("PASS combat preview ", preview)
	var attacker_hp := warrior.hp
	var defender_hp := rival.hp
	var attacker_cell := warrior.cell
	_click_cell(game, dest, MOUSE_BUTTON_RIGHT)
	if warrior.cell != attacker_cell:
		print("FAIL attacker advanced to ", warrior.cell)
		quit(1)
		return false
	if warrior.hp >= attacker_hp or rival.hp >= defender_hp or warrior.mp != 0:
		print("FAIL hp ", warrior.hp, " ", rival.hp, " mp ", warrior.mp)
		quit(1)
		return false
	if not setup.players[1].units.has(rival):
		print("FAIL rival was removed")
		quit(1)
		return false
	print("PASS attack ", attacker_hp, "->", warrior.hp, " ", defender_hp, "->", rival.hp)
	return true


func _human_unit(setup: GameSetup, unit_type: String) -> PlayerState.UnitState:
	for unit in setup.players[setup.human_index].units:
		if unit.unit_type == unit_type:
			return unit
	return null


func _other_reachable(setup: GameSetup, unit: PlayerState.UnitState, avoid: Vector2i) -> Vector2i:
	for key in setup.reachable_tiles(unit).keys():
		var cell := key as Vector2i
		if cell != avoid:
			return cell
	return Vector2i(-1, -1)


func _open_neighbor(setup: GameSetup, origin: Vector2i) -> Vector2i:
	var axial := Hex.offset_to_axial(origin)
	for dir in 6:
		var cell := Hex.axial_to_offset(Hex.neighbor(axial, dir))
		if not setup.map.in_bounds(cell):
			continue
		var occupied := false
		for player in setup.players:
			for unit in player.units:
				if unit.cell == cell:
					occupied = true
		if not occupied:
			return cell
	return Vector2i(-1, -1)


func _train_scout(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	if setup.cities.is_empty():
		print("FAIL no city to open")
		quit(1)
		return false
	var city: MapCity = setup.cities[0]
	_click_cell(game, city.cell)
	var panel := game.get_node("%CityPanel") as PanelContainer
	if not panel.visible:
		print("FAIL city panel hidden")
		quit(1)
		return false
	var food := (game.get_node("%CityFood") as Label).text
	var prod := (game.get_node("%CityProduction") as Label).text
	var mana := (game.get_node("%CityMana") as Label).text
	var growth := (game.get_node("%GrowthLabel") as Label).text
	var border := (game.get_node("%BorderLabel") as Label).text
	var yields: Dictionary = setup.city_yields(city)
	if food != "Food %d" % int(yields["food"]) or prod != "Production %d" % int(yields["production"]) or mana != "Mana %d" % int(yields["mana"]):
		print("FAIL panel ", food, " ", prod, " ", mana, " core ", yields)
		quit(1)
		return false
	if not growth.contains("/") or not border.begins_with("Radius"):
		print("FAIL growth or border '", growth, "' '", border, "'")
		quit(1)
		return false
	print("PASS city panel ", food, " ", prod, " ", mana, " ", growth, " ", border)
	var tiles_before := setup.territory_cells(city).size()
	var pop_before := city.population
	var stored_before := city.food_stored
	(game.get_node("%BuildScout") as Button).pressed.emit()
	if city.queue.size() != 1 or city.queue[0].item_id != "scout":
		print("FAIL scout queue ", city.queue.size())
		quit(1)
		return false
	if game.get_node("%QueueList").get_child_count() != 1:
		print("FAIL queue row missing")
		quit(1)
		return false
	print("PASS enqueued scout")
	var trained := 0
	for _turn in 40:
		trained = 0
		for unit in setup.players[setup.human_index].units:
			if unit.unit_type == "scout":
				trained += 1
		if trained == 1:
			break
		(game.get_node("%EndTurnButton") as Button).pressed.emit()
	if trained != 1:
		print("FAIL scout was not trained by turn ", setup.turn)
		quit(1)
		return false
	var grew := city.population != pop_before or city.food_stored != stored_before
	var expanded := setup.territory_cells(city).size() > tiles_before
	if not grew and not expanded:
		print("FAIL no growth or border change seed ", setup.seed_used)
		quit(1)
		return false
	var scout_sprite := false
	for child in game.get_node("%Actors").get_children():
		if str(child.name).begins_with("Unit_"):
			scout_sprite = true
	if not scout_sprite:
		print("FAIL trained scout has no sprite")
		quit(1)
		return false
	print("PASS trained scout pop ", city.population, " food ", city.food_stored, " tiles ", setup.territory_cells(city).size())
	return true


func _cast_spell(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	if setup.cities.is_empty():
		print("FAIL spell cast has no city")
		quit(1)
		return false
	var city: MapCity = setup.cities[0]
	if setup.players[setup.human_index].mana < setup.config.spell("restore_plains").mana:
		print("FAIL starting mana ", setup.players[setup.human_index].mana)
		quit(1)
		return false
	# Leave enough mana after the cast that cooldown, not the cost, greys the button.
	setup.players[setup.human_index].mana = setup.config.spell("restore_plains").mana * 2
	var mana_before := setup.players[setup.human_index].mana
	var target := _spell_target(setup, city.cell)
	if target.x < 0:
		print("FAIL no spell target")
		quit(1)
		return false
	var sample := Vector2i(-1, -1)
	for cell in setup.affected_tiles("restore_plains", target, Hex.EAST):
		if cell != city.cell:
			sample = cell
			break
	if sample.x < 0:
		print("FAIL spell area is empty")
		quit(1)
		return false
	setup.map.set_land(sample, "forest")
	game._refresh_board()
	var warrior := _human_unit(setup, "warrior")
	if warrior == null:
		print("FAIL spell cast has no warrior")
		quit(1)
		return false
	var warrior_cell := warrior.cell
	_click_cell(game, warrior.cell)
	var button := game.get_node("%SpellButtons").get_node("Spell_restore_plains") as Button
	if button.disabled:
		print("FAIL restore plains greyed before the cast: ", button.tooltip_text)
		quit(1)
		return false
	button.pressed.emit()
	_hover_cell(game, target)
	var expected := setup.affected_tiles("restore_plains", target, Hex.EAST).size()
	var marks := game.get_node("%MoveHighlights").get_child_count()
	if marks != expected:
		print("FAIL preview marks ", marks, " expected ", expected)
		quit(1)
		return false
	var tip := (game.get_node("%Tooltip") as Label).text
	if not tip.contains("Restore Plains") or not tip.contains("10 mana") or not tip.contains("change"):
		print("FAIL spell tip '", tip, "'")
		quit(1)
		return false
	print("PASS spell preview ", marks, " ", tip.replace("\n", " | "))
	_click_cell(game, target, MOUSE_BUTTON_RIGHT)
	if warrior.cell != warrior_cell:
		print("FAIL right click moved the warrior during targeting")
		quit(1)
		return false
	_hover_cell(game, target)
	tip = (game.get_node("%Tooltip") as Label).text
	if tip.contains("Restore Plains"):
		print("FAIL right click left targeting '", tip, "'")
		quit(1)
		return false
	print("PASS right click cancels targeting")
	button.pressed.emit()
	_hover_cell(game, target)
	_press_action(game, "toggle_menu")
	if (game.get_node("%InGameMenu") as CanvasItem).visible:
		print("FAIL esc opened the menu during targeting")
		quit(1)
		return false
	_hover_cell(game, target)
	tip = (game.get_node("%Tooltip") as Label).text
	if tip.contains("Restore Plains"):
		print("FAIL esc left targeting '", tip, "'")
		quit(1)
		return false
	print("PASS esc cancels targeting")
	button.pressed.emit()
	_hover_cell(game, target)
	var preview: Dictionary = setup.spell_preview(setup.human_index, "restore_plains", target, Hex.EAST)
	if not (preview["changed"] as Array).has(sample):
		print("FAIL forest tile is not in the change set")
		quit(1)
		return false
	_click_cell(game, target)
	if setup.map.land_at(sample) != "plains":
		print("FAIL tile stayed ", setup.map.land_at(sample))
		quit(1)
		return false
	var mana_now := setup.players[setup.human_index].mana
	if mana_now != mana_before - setup.config.spell("restore_plains").mana:
		print("FAIL mana ", mana_now, " from ", mana_before)
		quit(1)
		return false
	var mana_label := (game.get_node("%ManaLabel") as Label).text
	if not mana_label.begins_with("Mana %d" % mana_now):
		print("FAIL mana label '", mana_label, "'")
		quit(1)
		return false
	var state := (button.get_node("Column/StateLabel") as Label).text
	if not button.disabled or button.tooltip_text != SpellRules.REASON_COOLDOWN or not state.begins_with("Cooldown"):
		print("FAIL greyed disabled=", button.disabled, " tip='", button.tooltip_text, "' state='", state, "'")
		quit(1)
		return false
	print("PASS cast ", mana_label, " ", state)
	var turn_before := setup.turn
	var end := game.get_node("%EndTurnButton") as Button
	end.pressed.emit()
	if end.text == "End anyway (Enter)":
		end.pressed.emit()
	if setup.turn != turn_before + 1 or setup.cooldown_left(setup.human_index, "restore_plains") != 1 or not button.disabled:
		print("FAIL after end turn ", setup.turn, " cooldown ", setup.cooldown_left(setup.human_index, "restore_plains"), " ", (button.get_node("Column/StateLabel") as Label).text)
		quit(1)
		return false
	print("PASS cooldown after end turn ", (button.get_node("Column/StateLabel") as Label).text)
	return true


func _spell_target(setup: GameSetup, origin: Vector2i) -> Vector2i:
	var axial := Hex.offset_to_axial(origin)
	var fallback := Vector2i(-1, -1)
	for dist in [2, 1, 3]:
		for dir in 6:
			var cursor := axial
			for _step_i in dist:
				cursor = Hex.neighbor(cursor, dir)
			var cell := Hex.axial_to_offset(cursor)
			if not setup.map.in_bounds(cell):
				continue
			if not setup.cast_reason(setup.human_index, "restore_plains", cell, Hex.EAST).is_empty():
				continue
			if setup.affected_tiles("restore_plains", cell, Hex.EAST).size() == 7:
				return cell
			if fallback.x < 0:
				fallback = cell
	return fallback


func _hover_cell(game: Node, cell: Vector2i) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var local: Vector2 = map.map_to_local(cell)
	var world: Vector2 = map.to_global(local)
	var screen: Vector2 = game.get_viewport().get_canvas_transform() * world
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	game._unhandled_input(motion)


func _press_action(game: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	game._unhandled_input(event)


func _found_city(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var cell := setup.human_settler_cell()
	_click_cell(game, cell)
	var found := game.get_node("%FoundCityButton") as Button
	var reason := (game.get_node("%FoundCityReason") as Label).text
	if found.disabled or reason != "":
		print("FAIL found city available: disabled=", found.disabled, " reason='", reason, "'")
		quit(1)
		return false
	print("PASS settler selected")
	found.pressed.emit()
	var human_settlers := 0
	for unit in setup.players[setup.human_index].units:
		if unit.unit_type == "settler":
			human_settlers += 1
	var human_warriors := 0
	for unit in setup.players[setup.human_index].units:
		if unit.unit_type == "warrior":
			human_warriors += 1
	if human_settlers != 0 or human_warriors != 1 or setup.cities.size() != 1:
		print("FAIL founded city settlers=", human_settlers, " warriors=", human_warriors, " cities=", setup.cities.size(), " units=", setup.unit_total())
		quit(1)
		return false
	var city_nodes := 0
	var unit_nodes := 0
	var city_name := ""
	for child in game.get_node("%Actors").get_children():
		var node_name := str(child.name)
		if node_name.begins_with("City_"):
			city_nodes += 1
			city_name = (child.get_node("Name") as Label).text
		elif node_name.begins_with("Unit_"):
			unit_nodes += 1
	if city_nodes != 1 or unit_nodes < 1 or city_name == "":
		print("FAIL city view cities=", city_nodes, " units=", unit_nodes, " name='", city_name, "'")
		quit(1)
		return false
	if setup.cities[0].population != 1:
		print("FAIL city population")
		quit(1)
		return false
	print("PASS founded ", city_name)
	return true


func _click_cell(game: Node, cell: Vector2i, button_index: int = MOUSE_BUTTON_LEFT) -> void:
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
