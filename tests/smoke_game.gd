extends SceneTree

## Drives the real button signals and the game scene's input handler.

var _pool_before_well := -1
var _income_before_well := -1

const _RivalFixture = preload("res://tests/rival_fixture.gd")

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
	# The suite must not write into the real user://logs folder.
	GameLog.directory_override = "/tmp/bebop-smoke-logs"
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
	if not _assert_mana_before_turns(game):
		return
	if not _cast_spell(game):
		return
	if not _end_turn_with_enter(game):
		return
	if not _assert_mana_paid(game):
		return
	if not _train_scout(game):
		return
	if not _finish_mana_well(game):
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
	if not _capture_city_and_settler(game):
		return
	print("PASS restart ", turn)
	(game.get_node("%MenuButton") as Button).pressed.emit()
	(game.get_node("%RestartButton") as Button).pressed.emit()
	game = await _wait_for("res://scripts/view/game_view.gd")
	if game == null:
		return
	turn = (game.get_node("%TurnLabel") as Label).text
	if turn != "1 / 50":
		print("FAIL fresh game before rival land: '", turn, "'")
		quit(1)
		return
	if not _rival_land_cast(game):
		return
	if not _land_effects(game):
		return
	if not await _win_loss(game):
		return
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
	if not _mana_matches(game):
		return false
	for player in setup.players:
		if player.mana != setup.config.starting_mana or setup.mana_per_turn(player.index) != 0:
			print("FAIL start mana player ", player.index, " pool ", player.mana, " gain ", setup.mana_per_turn(player.index))
			quit(1)
			return false
	print("PASS new game seed ", setup.seed_used, " sprites ", shown, " ", (game.get_node("%ManaLabel") as Label).text)
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


func _capture_city_and_settler(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var warrior := _human_unit(setup, "warrior")
	if warrior == null:
		print("FAIL capture has no warrior")
		quit(1)
		return false
	var city_cell := _open_neighbor(setup, warrior.cell)
	if city_cell.x < 0:
		print("FAIL no tile for the rival city")
		quit(1)
		return false
	setup.map.set_land(city_cell, "plains")
	setup.map.set_land(warrior.cell, "plains")
	var rival := 0 if setup.human_index != 0 else 1
	var founder: PlayerState.UnitState = null
	for unit in setup.players[rival].units:
		if unit.unit_type == "settler":
			founder = unit
			break
	if founder == null:
		print("FAIL no rival settler")
		quit(1)
		return false
	founder.cell = city_cell
	var city := setup.found_city(founder)
	if city == null:
		print("FAIL rival city did not found")
		quit(1)
		return false
	# The founder was this rival's only settler. A spare settler keeps them in the
	# game so the capture checks below are about capture, not elimination.
	var keeper := Vector2i(-1, -1)
	for corner in [Vector2i(0, 0), Vector2i(setup.map.width - 1, 0), Vector2i(0, setup.map.height - 1), Vector2i(setup.map.width - 1, setup.map.height - 1)]:
		if setup._unit_at(corner) != null or corner == city_cell or corner == warrior.cell:
			continue
		setup.map.set_land(corner, "plains")
		if setup.spawn_unit(rival, "settler", corner) != null:
			keeper = corner
			break
	if keeper.x < 0:
		print("FAIL keeper settler")
		quit(1)
		return false
	game._refresh_board()
	_click_cell(game, warrior.cell)
	if (game.get_node("%SelectionTitle") as Label).text != "Warrior":
		_click_cell(game, warrior.cell)
	if (game.get_node("%SelectionTitle") as Label).text != "Warrior":
		print("FAIL capture selection")
		quit(1)
		return false
	_hover_cell(game, city_cell)
	var preview := (game.get_node("%CombatPreview") as Label).text
	var tip := (game.get_node("%Tooltip") as Label).text
	if not preview.begins_with("Damage") or not preview.contains("Counter") or not tip.contains(preview):
		print("FAIL city preview '", preview, "' tip '", tip, "'")
		quit(1)
		return false
	var dealt := int(setup.preview_city(warrior, city)["damage"])
	if dealt <= 0 or not preview.contains(str(dealt)):
		print("FAIL city damage ", dealt, " preview ", preview)
		quit(1)
		return false
	print("PASS city attack preview ", preview)
	city.hp = dealt
	game._refresh_board()
	var home := warrior.cell
	_click_cell(game, city_cell, MOUSE_BUTTON_RIGHT)
	if city.hp != 0 or city.player != rival or warrior.cell != home or warrior.mp != 0:
		print("FAIL city attack hp ", city.hp, " owner ", city.player, " cell ", warrior.cell)
		quit(1)
		return false
	var marker_hp := ""
	for child in game.get_node("%Actors").get_children():
		if str(child.name) == "City_%d" % city.id:
			marker_hp = (child.get_node("Hp") as Label).text
	if marker_hp != "0 / %d" % city.max_hp:
		print("FAIL zero HP marker '", marker_hp, "'")
		quit(1)
		return false
	print("PASS city at 0 HP")
	(game.get_node("%EndTurnButton") as Button).pressed.emit()
	if not (game.get_node("%EndTurnWarning") as Label).text.is_empty():
		(game.get_node("%EndTurnButton") as Button).pressed.emit()
	if city.hp != 0:
		print("FAIL attacked city healed to ", city.hp)
		quit(1)
		return false
	_click_cell(game, warrior.cell)
	if (game.get_node("%SelectionTitle") as Label).text != "Warrior":
		_click_cell(game, warrior.cell)
	var pop_before := city.population
	var income_before := setup.mana_per_turn(setup.human_index)
	_click_cell(game, city_cell, MOUSE_BUTTON_RIGHT)
	if city.player != setup.human_index or warrior.cell != city_cell or warrior.mp != 0:
		print("FAIL capture owner ", city.player, " cell ", warrior.cell, " mp ", warrior.mp)
		quit(1)
		return false
	if city.population != maxi(setup.config.capture_population_min, pop_before - setup.config.capture_population_loss):
		print("FAIL capture pop ", city.population)
		quit(1)
		return false
	if city.hp != roundi(float(city.max_hp) * setup.config.capture_hp_fraction):
		print("FAIL capture hp ", city.hp)
		quit(1)
		return false
	for cell in setup.territory_cells(city):
		if setup.owner_at(cell) != setup.human_index:
			print("FAIL border owner ", cell)
			quit(1)
			return false
	if not _mana_matches(game):
		return false
	if setup.mana_per_turn(setup.human_index) <= income_before:
		print("FAIL income did not move")
		quit(1)
		return false
	var human_color := Color.html(setup.players[setup.human_index].color)
	var tinted := false
	for child in game.get_node("%Actors").get_children():
		if str(child.name) != "City_%d" % city.id:
			continue
		var sprite := child.get_node("Sprite") as Sprite2D
		var mat := sprite.material as ShaderMaterial
		tinted = (mat.get_shader_parameter("team_color") as Color).is_equal_approx(human_color)
	if not tinted:
		print("FAIL captured city color")
		quit(1)
		return false
	if not _select_city(game, city):
		return false
	var hp_line := (game.get_node("%CityHp") as Label).text
	if hp_line != "HP %d / %d" % [city.hp, city.max_hp] or (game.get_node("%CityName") as Label).text != city.city_name:
		print("FAIL captured panel '", hp_line, "'")
		quit(1)
		return false
	print("PASS captured city ", city.city_name, " ", (game.get_node("%ManaLabel") as Label).text, " ", hp_line)
	(game.get_node("%EndTurnButton") as Button).pressed.emit()
	if not (game.get_node("%EndTurnWarning") as Label).text.is_empty():
		(game.get_node("%EndTurnButton") as Button).pressed.emit()
	var settler_cell := _open_neighbor(setup, warrior.cell)
	if settler_cell.x < 0:
		print("FAIL no settler tile")
		quit(1)
		return false
	setup.map.set_land(settler_cell, "plains")
	var settler := setup.spawn_unit(rival, "settler", settler_cell)
	if settler == null:
		print("FAIL rival settler spawn")
		quit(1)
		return false
	game._refresh_board()
	_click_cell(game, warrior.cell)
	if (game.get_node("%SelectionTitle") as Label).text != "Warrior":
		_click_cell(game, warrior.cell)
	_click_cell(game, settler_cell, MOUSE_BUTTON_RIGHT)
	if settler.owner != setup.human_index or settler.cell != warrior.cell or warrior.mp != 0:
		print("FAIL settler capture owner ", settler.owner, " cell ", settler.cell, " mp ", warrior.mp)
		quit(1)
		return false
	if not setup.players[setup.human_index].units.has(settler):
		print("FAIL settler did not join the human")
		quit(1)
		return false
	print("PASS settler captured")
	if not _select_city(game, city):
		return false
	city.hp = 0
	var rival_warrior: PlayerState.UnitState = null
	for unit in setup.players[rival].units:
		if unit.unit_type == "warrior":
			rival_warrior = unit
			break
	if rival_warrior == null:
		print("FAIL no rival warrior")
		quit(1)
		return false
	var approach := _open_neighbor(setup, city.cell)
	if approach.x < 0:
		print("FAIL no approach")
		quit(1)
		return false
	setup.map.set_land(approach, "plains")
	setup.map.set_land(city.cell, "plains")
	rival_warrior.cell = approach
	rival_warrior.mp = setup.config.unit("warrior").move
	if not setup.move_unit(rival_warrior, city.cell):
		print("FAIL rival could not take the city back")
		quit(1)
		return false
	game._refresh_board()
	if (game.get_node("%CityPanel") as CanvasItem).visible:
		print("FAIL panel stayed open after the city changed owner")
		quit(1)
		return false
	if not _mana_matches(game):
		return false
	print("PASS city panel closed")
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
	if not mana_label.begins_with("Mana: %d" % mana_now):
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
	# This cast's End Turn already paid one city snapshot. The next check expects one more.
	_pool_before_well = setup.players[setup.human_index].mana
	_income_before_well = setup.mana_per_turn(setup.human_index)
	return true


func _rival_land_cast(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var placed: Dictionary = _RivalFixture.place(setup)
	if not bool(placed["ok"]):
		print("FAIL rival fixture ", placed["reason"])
		quit(1)
		return false
	game._refresh_board()
	var human_city := placed["human_city"] as MapCity
	var rival_city := placed["rival_city"] as MapCity
	var warrior := placed["warrior"] as PlayerState.UnitState
	var defender := placed["defender"] as PlayerState.UnitState
	var worked: Vector2i = placed["worked"]
	var target: Vector2i = placed["target"]
	var near: Vector2i = placed["near"]
	var far: Vector2i = placed["far"]
	var turn_before := setup.turn
	var owner_target := setup.owner_at(target)
	var owner_worked := setup.owner_at(worked)
	var human_before: Dictionary = setup.city_yields(human_city)
	var rival_before: Dictionary = setup.city_yields(rival_city)
	var rate_before := setup.mana_per_turn(setup.human_index)
	_click_cell(game, human_city.cell)
	var panel := game.get_node("%CityPanel") as CanvasItem
	if not panel.visible or not _panel_matches(game, human_city):
		print("FAIL city panel before the cast")
		quit(1)
		return false
	_click_cell(game, warrior.cell)
	if not panel.visible:
		print("FAIL city panel closed when the warrior was selected")
		quit(1)
		return false
	if (game.get_node("%SelectionTitle") as Label).text != "Warrior":
		print("FAIL warrior was not selected")
		quit(1)
		return false
	if not _highlight_has(game, far) or not _highlight_has(game, near):
		print("FAIL move highlights before the cast")
		quit(1)
		return false
	_hover_cell(game, target)
	var plain_hit: Dictionary = setup.preview_attack(warrior, defender)
	var preview := game.get_node("%CombatPreview") as Label
	var plain_text := "Damage %d   Counter %d" % [int(plain_hit["damage"]), int(plain_hit["counter"])]
	if not bool(plain_hit["ok"]) or preview.text != plain_text:
		print("FAIL combat preview before '", preview.text, "' expected ", plain_text)
		quit(1)
		return false
	var food_before := (game.get_node("%CityFood") as Label).text
	var prod_before := (game.get_node("%CityProduction") as Label).text
	(game.get_node("%SpellButtons").get_node("Spell_raise_hills") as Button).pressed.emit()
	_click_cell(game, target)
	if setup.turn != turn_before:
		print("FAIL cast advanced the turn")
		quit(1)
		return false
	if setup.map.land_at(target) != "hills" or setup.map.land_at(worked) != "hills" or setup.map.land_at(near) != "hills" or setup.map.land_at(far) != "plains":
		print("FAIL lands target ", setup.map.land_at(target), " worked ", setup.map.land_at(worked), " near ", setup.map.land_at(near), " far ", setup.map.land_at(far))
		quit(1)
		return false
	if setup.owner_at(target) != owner_target or setup.owner_at(worked) != owner_worked:
		print("FAIL ownership changed")
		quit(1)
		return false
	var map := game.get_node("%Map") as TileMapLayer
	if map.get_cell_atlas_coords(target) != Vector2i(_LAND_COLUMN["hills"], 0) or map.get_cell_atlas_coords(worked) != Vector2i(_LAND_COLUMN["hills"], 0):
		print("FAIL atlas did not follow the land")
		quit(1)
		return false
	var human_after: Dictionary = setup.city_yields(human_city)
	var rival_after: Dictionary = setup.city_yields(rival_city)
	if int(human_after["food"]) >= int(human_before["food"]) or int(human_after["production"]) <= int(human_before["production"]):
		print("FAIL human yields ", human_before, " -> ", human_after)
		quit(1)
		return false
	if int(rival_after["food"]) >= int(rival_before["food"]) or int(rival_after["production"]) <= int(rival_before["production"]):
		print("FAIL rival yields ", rival_before, " -> ", rival_after)
		quit(1)
		return false
	if int(human_after["mana"]) != int(human_before["mana"]) or setup.mana_per_turn(setup.human_index) != rate_before:
		print("FAIL mana rate changed ", setup.mana_per_turn(setup.human_index))
		quit(1)
		return false
	if not panel.visible or not _panel_matches(game, human_city):
		print("FAIL city panel after the cast food '", (game.get_node("%CityFood") as Label).text, "' prod '", (game.get_node("%CityProduction") as Label).text, "'")
		quit(1)
		return false
	if (game.get_node("%CityFood") as Label).text == food_before or (game.get_node("%CityProduction") as Label).text == prod_before:
		print("FAIL panel text did not change")
		quit(1)
		return false
	var hill_hit: Dictionary = setup.preview_attack(warrior, defender)
	var hill_text := "Damage %d   Counter %d" % [int(hill_hit["damage"]), int(hill_hit["counter"])]
	if int(hill_hit["damage"]) >= int(plain_hit["damage"]) or preview.text != hill_text:
		print("FAIL combat preview after '", preview.text, "' expected ", hill_text)
		quit(1)
		return false
	if _highlight_has(game, far) or not _highlight_has(game, near):
		print("FAIL move highlights after the cast")
		quit(1)
		return false
	var tip := (game.get_node("%Tooltip") as Label).text
	if not tip.contains("hills"):
		print("FAIL tooltip '", tip, "'")
		quit(1)
		return false
	var mana := (game.get_node("%ManaLabel") as Label).text
	var expected_mana := "Mana: %d (+%d/turn)" % [setup.players[setup.human_index].mana, rate_before]
	if mana != expected_mana:
		print("FAIL mana label '", mana, "' expected ", expected_mana)
		quit(1)
		return false
	print("PASS rival land ", (game.get_node("%CityFood") as Label).text, " ", (game.get_node("%CityProduction") as Label).text, " ", preview.text, " ", mana)
	return true


func _land_effects(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var city: MapCity = null
	for item in setup.cities:
		if item.player == setup.human_index:
			city = item
			break
	if city == null:
		print("FAIL land effects has no human city")
		quit(1)
		return false
	var well_cell := _offset_step(city.cell, Hex.NORTHEAST, 1)
	var granary_cell := _offset_step(city.cell, Hex.NORTHWEST, 1)
	if setup.owner_at(well_cell) != setup.human_index or setup.owner_at(granary_cell) != setup.human_index:
		print("FAIL building tiles are not in the city")
		quit(1)
		return false
	var reserved := {well_cell: true, granary_cell: true, city.cell: true}
	for player in setup.players:
		for unit in player.units:
			if not reserved.has(unit.cell):
				continue
			var park := _open_plains(setup, reserved)
			if park.x < 0:
				print("FAIL no tile to park a unit")
				quit(1)
				return false
			unit.cell = park
			reserved[park] = true
	setup.map.set_land(well_cell, "forest")
	setup.map.set_land(granary_cell, "plains")
	var well := MapCity.Building.new()
	well.kind = "mana_well"
	well.cell = well_cell
	city.buildings.append(well)
	var granary := MapCity.Building.new()
	granary.kind = "granary"
	granary.cell = granary_cell
	city.buildings.append(granary)
	var human := setup.players[setup.human_index]
	human.mana = 80
	human.casts_this_turn = 0
	human.spell_cooldowns.clear()
	setup._refresh_fog()
	game._refresh_board()
	_click_cell(game, city.cell)
	if not (game.get_node("%CityPanel") as CanvasItem).visible or not _panel_matches(game, city):
		print("FAIL city panel before the river")
		quit(1)
		return false
	var rate_before := setup.mana_per_turn(setup.human_index)
	var mana_before := int(setup.city_yields(city)["mana"])
	var food_before := (game.get_node("%CityFood") as Label).text
	var growth_before := (game.get_node("%GrowthLabel") as Label).text
	var button := game.get_node("%SpellButtons").get_node("Spell_carve_river") as Button
	if button.disabled:
		print("FAIL carve river greyed: ", button.tooltip_text)
		quit(1)
		return false
	button.pressed.emit()
	_hover_cell(game, well_cell)
	var tip := (game.get_node("%Tooltip") as Label).text
	if not tip.contains("1 building destroyed"):
		print("FAIL preview tip '", tip, "'")
		quit(1)
		return false
	var preview: Dictionary = setup.spell_preview(setup.human_index, "carve_river", well_cell, Hex.EAST)
	var marks := game.get_node("%MoveHighlights").get_child_count()
	var expected_marks := (preview["tiles"] as Array).size() + (preview["destroyed"] as Array).size()
	if str(preview["reason"]) != "" or marks != expected_marks or not (preview["destroyed"] as Array).has(well_cell):
		print("FAIL preview marks ", marks, " expected ", expected_marks, " reason '", preview["reason"], "'")
		quit(1)
		return false
	print("PASS preview ", tip.replace("\n", " | "))
	_click_cell(game, well_cell)
	if setup.map.land_at(well_cell) != "water" or city.buildings.size() != 1 or city.buildings[0].cell != granary_cell:
		print("FAIL after water land ", setup.map.land_at(well_cell), " buildings ", city.buildings.size())
		quit(1)
		return false
	if setup.mana_per_turn(setup.human_index) != rate_before - setup.config.mana_well_mana:
		print("FAIL mana rate ", setup.mana_per_turn(setup.human_index), " from ", rate_before)
		quit(1)
		return false
	if int(setup.city_yields(city)["mana"]) != mana_before - setup.config.mana_well_mana:
		print("FAIL city mana ", setup.city_yields(city)["mana"])
		quit(1)
		return false
	if not (game.get_node("%CityPanel") as CanvasItem).visible or not _panel_matches(game, city):
		print("FAIL panel after water food '", (game.get_node("%CityFood") as Label).text, "' mana '", (game.get_node("%CityMana") as Label).text, "'")
		quit(1)
		return false
	if (game.get_node("%CityFood") as Label).text == food_before and (game.get_node("%GrowthLabel") as Label).text == growth_before:
		print("FAIL yields did not change food ", food_before, " growth ", growth_before)
		quit(1)
		return false
	if not _mana_matches(game):
		return false
	var marker_name := "Building_%d_%d_%d" % [city.id, well_cell.x, well_cell.y]
	if game.get_node("%Actors").get_node_or_null(marker_name) != null:
		print("FAIL building marker stayed")
		quit(1)
		return false
	print("PASS water destroyed the well ", (game.get_node("%ManaLabel") as Label).text, " ", (game.get_node("%CityMana") as Label).text)
	var warrior := _human_unit(setup, "warrior")
	if warrior == null:
		print("FAIL volcanic smoke has no warrior")
		quit(1)
		return false
	setup.map.set_land(warrior.cell, "volcanic")
	warrior.hp = warrior.max_hp
	warrior.acted = false
	game._refresh_board()
	_click_cell(game, warrior.cell)
	var detail := (game.get_node("%SelectionDetail") as Label).text
	var warning := (game.get_node("%VolcanicWarning") as Label).text
	var expected_warning := "Volcanic: -%d HP at end of turn" % setup.config.volcanic_damage
	if warning != expected_warning or detail.contains("Volcanic"):
		print("FAIL volcanic warning '", warning, "' detail '", detail, "'")
		quit(1)
		return false
	print("PASS volcanic warning")
	(game.get_node("%SkipButton") as Button).pressed.emit()
	if not _press_end_turn(game):
		return false
	if warrior.hp != warrior.max_hp - setup.config.volcanic_damage:
		print("FAIL full HP idle volcanic ", warrior.hp, " max ", warrior.max_hp)
		quit(1)
		return false
	detail = (game.get_node("%SelectionDetail") as Label).text
	warning = (game.get_node("%VolcanicWarning") as Label).text
	if not detail.contains("HP %d / %d" % [warrior.hp, warrior.max_hp]) or warning != expected_warning or detail.contains("Volcanic"):
		print("FAIL hp line after volcanic '", detail, "' warning '", warning, "'")
		quit(1)
		return false
	print("PASS volcanic drop ", warrior.hp)
	warrior.hp = 40
	warrior.acted = false
	(game.get_node("%SkipButton") as Button).pressed.emit()
	if not _press_end_turn(game):
		return false
	if warrior.hp != 40 or not setup.players[setup.human_index].units.has(warrior):
		print("FAIL wounded idle net ", warrior.hp)
		quit(1)
		return false
	print("PASS volcanic net 0")
	var away := _offset_step(warrior.cell, Hex.EAST, 1)
	setup.map.set_land(away, "volcanic")
	for player in setup.players:
		for unit in player.units:
			if unit != warrior and unit.cell == away:
				unit.cell = _offset_step(away, Hex.WEST, 2)
	game._refresh_board()
	_click_cell(game, warrior.cell)
	_click_cell(game, away, MOUSE_BUTTON_RIGHT)
	if warrior.cell != away:
		print("FAIL warrior did not step onto volcanic ", warrior.cell, " -> ", away)
		quit(1)
		return false
	warrior.hp = 8
	if not _press_end_turn(game):
		return false
	if setup.players[setup.human_index].units.has(warrior):
		print("FAIL volcanic kill left the warrior at ", warrior.hp)
		quit(1)
		return false
	if (game.get_node("%SelectionTitle") as Label).text != "No unit selected":
		print("FAIL selection after kill '", (game.get_node("%SelectionTitle") as Label).text, "'")
		quit(1)
		return false
	if game.get_node("%Actors").get_node_or_null("Unit_%d" % warrior.id) != null:
		print("FAIL unit sprite stayed after the kill")
		quit(1)
		return false
	print("PASS volcanic kill")
	return true


func _press_end_turn(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var turn_before := setup.turn
	var end := game.get_node("%EndTurnButton") as Button
	end.pressed.emit()
	if end.text == "End anyway (Enter)":
		end.pressed.emit()
	if setup.turn != turn_before + 1:
		print("FAIL end turn stayed on ", setup.turn)
		quit(1)
		return false
	return true


func _open_plains(setup: GameSetup, reserved: Dictionary) -> Vector2i:
	for row in setup.map.height:
		for col in setup.map.width:
			var cell := Vector2i(col, row)
			if reserved.has(cell):
				continue
			var taken := false
			for player in setup.players:
				for unit in player.units:
					if unit.cell == cell:
						taken = true
			if taken:
				continue
			setup.map.set_land(cell, "plains")
			return cell
	return Vector2i(-1, -1)


func _offset_step(cell: Vector2i, direction: int, steps: int) -> Vector2i:
	var axial := Hex.offset_to_axial(cell)
	for _i in steps:
		axial = Hex.neighbor(axial, direction)
	return Hex.axial_to_offset(axial)


func _panel_matches(game: Node, city: MapCity) -> bool:
	var setup := game.get("setup") as GameSetup
	var yields: Dictionary = setup.city_yields(city)
	var food := (game.get_node("%CityFood") as Label).text
	var prod := (game.get_node("%CityProduction") as Label).text
	var mana := (game.get_node("%CityMana") as Label).text
	var growth := (game.get_node("%GrowthLabel") as Label).text
	var surplus := int(yields["surplus"])
	var sign := "+" if surplus >= 0 else ""
	var expected_growth := "Growth %d / %d (%s%d)" % [city.food_stored, int(yields["threshold"]), sign, surplus]
	return food == "Food %d" % int(yields["food"]) and prod == "Production %d" % int(yields["production"]) and mana == "Mana %d" % int(yields["mana"]) and growth == expected_growth


func _highlight_has(game: Node, cell: Vector2i) -> bool:
	var map := game.get_node("%Map") as TileMapLayer
	var want := map.map_to_local(cell)
	for child in game.get_node("%MoveHighlights").get_children():
		if (child as Node2D).position.is_equal_approx(want):
			return true
	return false


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


func _assert_mana_before_turns(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var city: MapCity = setup.cities[0]
	if not _select_city(game, city):
		return false
	var city_mana := int(setup.city_yields(city)["mana"])
	if setup.mana_per_turn(setup.human_index) != city_mana:
		print("FAIL income ", setup.mana_per_turn(setup.human_index), " city ", city_mana)
		quit(1)
		return false
	if setup.players[setup.human_index].mana != setup.config.starting_mana:
		print("FAIL pool changed before a city end turn ", setup.players[setup.human_index].mana)
		quit(1)
		return false
	if not _mana_matches(game):
		return false
	var panel_mana := (game.get_node("%CityMana") as Label).text
	if panel_mana != "Mana %d" % city_mana:
		print("FAIL panel mana '", panel_mana, "'")
		quit(1)
		return false
	_pool_before_well = setup.players[setup.human_index].mana
	_income_before_well = city_mana
	print("PASS mana before turns ", (game.get_node("%ManaLabel") as Label).text, " panel ", panel_mana)
	return true


func _assert_mana_paid(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var human := setup.players[setup.human_index]
	if human.mana != _pool_before_well + _income_before_well:
		print("FAIL pool ", human.mana, " expected ", _pool_before_well + _income_before_well)
		quit(1)
		return false
	if not _mana_matches(game):
		return false
	for player in setup.players:
		if player.index == setup.human_index:
			continue
		if player.mana != setup.config.starting_mana:
			print("FAIL rival mana ", player.index, " ", player.mana)
			quit(1)
			return false
	print("PASS mana paid ", (game.get_node("%ManaLabel") as Label).text)
	return true


func _finish_mana_well(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	if setup.cities.is_empty():
		print("FAIL no city for the mana well")
		quit(1)
		return false
	var city: MapCity = setup.cities[0]
	if not _mana_matches(game):
		return false
	if not _select_city(game, city):
		return false
	var divisor := setup.config.city_mana_per_population_divisor
	var pop_before := city.population
	var rate_before := setup.mana_per_turn(setup.human_index)
	var pool_before := setup.players[setup.human_index].mana
	setup.config.mana_well_cost = 2
	var plots: Array[Vector2i] = setup.placement_tiles(city, "mana_well")
	if plots.is_empty():
		print("FAIL no mana well tile")
		quit(1)
		return false
	(game.get_node("%BuildManaWell") as Button).pressed.emit()
	_click_cell(game, plots[0])
	var queued := false
	for item in city.queue:
		if item.item_id == "mana_well" and item.cell == plots[0]:
			queued = true
	if not queued:
		print("FAIL mana well not queued ", (game.get_node("%CityReason") as Label).text)
		quit(1)
		return false
	var turn_before := setup.turn
	if not _confirm_end_turn(game):
		return false
	if setup.turn != turn_before + 1:
		print("FAIL well turn ", setup.turn, " before ", turn_before)
		quit(1)
		return false
	var built := false
	for building in city.buildings:
		if building.kind == "mana_well" and building.cell == plots[0]:
			built = true
	if not built:
		print("FAIL mana well did not finish")
		quit(1)
		return false
	var human := setup.players[setup.human_index]
	if human.mana != pool_before + rate_before:
		print("FAIL well turn paid ", human.mana, " expected ", pool_before + rate_before)
		quit(1)
		return false
	var pop_delta := 0
	if divisor > 0:
		pop_delta = int(city.population / divisor) - int(pop_before / divisor)
	var gain := setup.mana_per_turn(setup.human_index)
	var expected := rate_before + setup.config.mana_well_mana + pop_delta
	if gain != expected:
		print("FAIL gain ", gain, " expected ", expected, " pop ", pop_before, " -> ", city.population)
		quit(1)
		return false
	if not _mana_matches(game):
		return false
	var panel_mana := (game.get_node("%CityMana") as Label).text
	var city_mana := int(setup.city_yields(city)["mana"])
	if panel_mana != "Mana %d" % city_mana or city_mana != gain:
		print("FAIL panel '", panel_mana, "' city ", city_mana, " gain ", gain)
		quit(1)
		return false
	print("PASS mana well +", setup.config.mana_well_mana, " ", (game.get_node("%ManaLabel") as Label).text, " panel ", panel_mana)
	return true


func _confirm_end_turn(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var before := setup.turn
	var button := game.get_node("%EndTurnButton") as Button
	button.pressed.emit()
	if setup.turn == before:
		button.pressed.emit()
	if setup.turn != before + 1:
		print("FAIL end turn stayed on ", setup.turn)
		quit(1)
		return false
	return true


func _select_city(game: Node, city: MapCity) -> bool:
	# The panel stays up while a unit is selected, so visibility is not enough.
	# A unit on the city tile takes the first click; the next click selects the city.
	var panel := game.get_node("%CityPanel") as CanvasItem
	var title := game.get_node("%SelectionTitle") as Label
	_click_cell(game, city.cell)
	if not panel.visible or title.text != "No unit selected":
		_click_cell(game, city.cell)
	if not panel.visible or title.text != "No unit selected":
		print("FAIL city panel hidden")
		quit(1)
		return false
	return true


func _mana_matches(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var human := setup.players[setup.human_index]
	var expected := "Mana: %d (+%d/turn)" % [human.mana, setup.mana_per_turn(human.index)]
	var label := (game.get_node("%ManaLabel") as Label).text
	var turn := (game.get_node("%TurnLabel") as Label).text
	if label != expected or turn != "%d / %d" % [setup.turn, setup.config.turn_limit]:
		print("FAIL top bar mana='", label, "' turn='", turn, "' expected ", expected, " turn ", setup.turn)
		quit(1)
		return false
	return _scores_match(game)


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


func _scores_match(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	for index in setup.players.size():
		var label := game.get_node("%%Score%d" % index) as Label
		var expected := setup.score_line(index)
		if label == null or not label.visible or label.text != expected:
			var shown := "" if label == null else label.text
			print("FAIL score ", index, " '", shown, "' expected ", expected)
			quit(1)
			return false
	return true


func _win_loss(game: Node) -> bool:
	(game.get_node("%MenuButton") as Button).pressed.emit()
	(game.get_node("%RestartButton") as Button).pressed.emit()
	game = await _wait_for("res://scripts/view/game_view.gd")
	if game == null:
		return false
	if not _fresh_turn(game, "in-game menu restart"):
		return false
	if not await _score_ending(game):
		return false
	game = await _restart_from_end("score")
	if game == null:
		return false
	if not await _conquest_ending(game):
		return false
	game = await _restart_from_end("conquest")
	if game == null:
		return false
	if not await _human_defeat(game):
		return false
	return true


func _fresh_turn(game: Node, source: String) -> bool:
	var setup := game.get("setup") as GameSetup
	var turn := (game.get_node("%TurnLabel") as Label).text
	if turn != "1 / 50" or setup.turn != 1 or setup.result != null or MatchResult.latest != null:
		print("FAIL ", source, " turn '", turn, "' core ", setup.turn, " result ", setup.result, " latest ", MatchResult.latest)
		quit(1)
		return false
	if not _scores_match(game):
		return false
	for player in setup.players:
		if player.eliminated or setup.score(player.index) != 0:
			print("FAIL ", source, " leftover score")
			quit(1)
			return false
	print("PASS ", source, " ", turn)
	return true


func _score_ending(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	if not _scores_match(game):
		return false
	setup.config.turn_limit = 1
	game._refresh_board()
	var shown := (game.get_node("%TurnLabel") as Label).text
	if shown != "1 / 1":
		print("FAIL tuned turn label '", shown, "'")
		quit(1)
		return false
	_confirm_end(game)
	var screen := await _wait_for("res://scripts/view/end_screen.gd")
	if screen == null:
		return false
	var result := MatchResult.latest
	if result == null or result.ending != MatchResult.REASON_SCORE or result.human_won or result.turn != 1:
		print("FAIL score ending ", result)
		quit(1)
		return false
	if (screen.get_node("%Title") as Label).text != "Defeat":
		print("FAIL score title")
		quit(1)
		return false
	if not _rows_match(screen, result):
		return false
	print("PASS turn-limit defeat")
	return true


func _conquest_ending(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var human := setup.human_index
	var others: Array[int] = []
	for index in setup.players.size():
		if index != human:
			others.append(index)
	if others.size() < 2:
		print("FAIL conquest needs two rivals")
		quit(1)
		return false
	var rival_a := others[0]
	var rival_b := others[1]
	var park := Vector2i(20, 14)
	for player in setup.players:
		for unit in player.units:
			_paint_plains(setup, park)
			unit.cell = park
			park.x += 1
	var warrior := _player_unit(setup, human, "warrior")
	var human_settler := _player_unit(setup, human, "settler")
	var settler_b := _player_unit(setup, rival_b, "settler")
	var warrior_a := _player_unit(setup, rival_a, "warrior")
	if warrior == null or human_settler == null or settler_b == null or warrior_a == null:
		print("FAIL conquest roster")
		quit(1)
		return false
	_paint_plains(setup, Vector2i(0, 0))
	_paint_plains(setup, Vector2i(1, 1))
	human_settler.cell = Vector2i(1, 1)
	warrior_a.cell = Vector2i(0, 0)
	var spot := Vector2i(8, 8)
	var beside := Hex.axial_to_offset(Hex.neighbor(Hex.offset_to_axial(spot), Hex.WEST))
	_paint_plains(setup, spot)
	_paint_plains(setup, beside)
	settler_b.cell = spot
	warrior.cell = beside
	warrior.mp = setup.config.unit("warrior").move
	setup._refresh_fog()
	if not setup.move_unit(warrior, spot) or not setup.players[rival_b].eliminated or setup.result != null:
		print("FAIL fixture did not remove the other rival")
		quit(1)
		return false
	var settler_a := _player_unit(setup, rival_a, "settler")
	if settler_a == null:
		print("FAIL no city founder")
		quit(1)
		return false
	var city_cell := Vector2i(12, 8)
	for hex in Hex.disk(Hex.offset_to_axial(city_cell), 1):
		_paint_plains(setup, Hex.axial_to_offset(hex))
	settler_a.cell = city_cell
	var city := setup.found_city(settler_a)
	if city == null:
		print("FAIL conquest city")
		quit(1)
		return false
	city.hp = 0
	var approach := Hex.axial_to_offset(Hex.neighbor(Hex.offset_to_axial(city_cell), Hex.EAST))
	_paint_plains(setup, approach)
	warrior.cell = approach
	warrior.mp = setup.config.unit("warrior").move
	setup._refresh_fog()
	game._refresh_board()
	if setup.result != null:
		print("FAIL game ended before the capture click")
		quit(1)
		return false
	_click_cell(game, approach)
	if (game.get_node("%SelectionTitle") as Label).text != "Warrior":
		_click_cell(game, approach)
	_click_cell(game, city_cell, MOUSE_BUTTON_RIGHT)
	var screen := await _wait_for("res://scripts/view/end_screen.gd")
	if screen == null:
		return false
	var result := MatchResult.latest
	if result == null or not result.human_won or result.ending != MatchResult.REASON_CONQUEST:
		print("FAIL conquest result ", result)
		quit(1)
		return false
	if (screen.get_node("%Title") as Label).text != "Victory":
		print("FAIL conquest title")
		quit(1)
		return false
	if not _rows_match(screen, result):
		return false
	print("PASS conquest victory")
	return true


func _human_defeat(game: Node) -> bool:
	var setup := game.get("setup") as GameSetup
	var settler := _player_unit(setup, setup.human_index, "settler")
	if settler == null:
		print("FAIL no human settler")
		quit(1)
		return false
	setup.map.set_land(settler.cell, "volcanic")
	game._refresh_board()
	_confirm_end(game)
	var screen := await _wait_for("res://scripts/view/end_screen.gd")
	if screen == null:
		return false
	var result := MatchResult.latest
	if result == null or result.human_won or result.ending != MatchResult.REASON_ELIMINATED:
		print("FAIL elimination result ", result)
		quit(1)
		return false
	if (screen.get_node("%Title") as Label).text != "Defeat":
		print("FAIL elimination title")
		quit(1)
		return false
	if not _rows_match(screen, result):
		return false
	var human_reason := ""
	for row in result.rows:
		if row.human:
			human_reason = row.reason
	if human_reason != MatchResult.REASON_ELIMINATED:
		print("FAIL human reason ", human_reason)
		quit(1)
		return false
	print("PASS human elimination")
	(screen.get_node("%MainMenuButton") as Button).pressed.emit()
	var menu := await _wait_for("res://scripts/view/main_menu.gd")
	if menu == null:
		return false
	if menu.get_node_or_null("%NewGameButton") == null:
		print("FAIL main menu")
		quit(1)
		return false
	print("PASS main menu")
	return true


func _restart_from_end(source: String) -> Node:
	var screen := current_scene
	(screen.get_node("%RestartButton") as Button).pressed.emit()
	var game := await _wait_for("res://scripts/view/game_view.gd")
	if game == null:
		return null
	if not _fresh_turn(game, source + " restart"):
		return null
	return game


func _confirm_end(game: Node) -> void:
	var button := game.get_node("%EndTurnButton") as Button
	button.pressed.emit()
	if not is_instance_valid(game):
		return
	var setup := game.get("setup") as GameSetup
	if setup == null or setup.result != null:
		return
	if not (game.get_node("%EndTurnWarning") as Label).text.is_empty():
		button.pressed.emit()


func _rows_match(screen: Node, result: MatchResult) -> bool:
	var table := screen.get_node("%ScoreTable")
	for row in result.rows:
		var line := table.get_node_or_null("ScoreLine%d" % row.player) as HBoxContainer
		if line == null:
			print("FAIL missing score row ", row.player)
			quit(1)
			return false
		var text := (line.get_node("Text") as Label).text
		if text != row.line():
			print("FAIL score row '", text, "' expected '", row.line(), "'")
			quit(1)
			return false
		var swatch := line.get_node("Swatch") as ColorRect
		if not swatch.color.is_equal_approx(Color.html(row.color)):
			print("FAIL score color ", row.player)
			quit(1)
			return false
		var weight := row.tiles * 1 + row.cities * 10 + row.population * 3
		if row.score != weight:
			print("FAIL row formula ", row.score, " ", weight)
			quit(1)
			return false
	print("PASS score rows")
	return true


func _player_unit(setup: GameSetup, player: int, unit_type: String) -> PlayerState.UnitState:
	for unit in setup.players[player].units:
		if unit.unit_type == unit_type:
			return unit
	return null


func _paint_plains(setup: GameSetup, cell: Vector2i) -> void:
	if setup.map.in_bounds(cell):
		setup.map.set_land(cell, "plains")


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
