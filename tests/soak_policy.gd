class_name SoakPolicy
extends RefCounted

## One scripted human for the stability soak.
##
## View handlers (the same ones smoke drives): left and right click, the spell
## buttons, Found City, Skip, Fortify, the build buttons, queue cancel and
## reorder, Cancel Place, End Turn, the menu button, and Restart.
##
## Core calls, because no handler exists for them:
## - The conquest fixture repositions units. Rivals have no turn of their own,
##   and a warrior cannot walk the start-distance gap inside a short game.
## - One rival city is founded so a spell can target rival-owned land. The
##   human cannot found a city for someone else.
## - Ticket 30 paints plains under a settler who has no city. See spare_settlers.

const MODE_SCORE := "score"
const MODE_CONQUEST := "conquest"
const ENDED := "ended"

const _NO_CELL := Vector2i(-999999, -999999)
const _BUILD_BUTTONS := {
	"settler": "BuildSettler",
	"scout": "BuildScout",
	"warrior": "BuildWarrior",
	"archer": "BuildArcher",
	"granary": "BuildGranary",
	"mana_well": "BuildManaWell",
	"lumber_mill": "BuildLumberMill",
}
const _UNIT_CYCLE: Array[String] = ["warrior", "scout", "archer", "settler"]
const _BUILD_CYCLE: Array[String] = ["granary", "lumber_mill", "mana_well"]
const _CAST_CYCLE: Array[String] = ["restore_plains", "grow_forest", "raise_hills", "ignite"]

var mode := MODE_SCORE
var last_action := ""
var spared_tiles := 0
var did_sink := false
var did_rival_cast := false
var founds := 0
var attacks := 0
var captures := 0

var _hunter_id := -1
var _rival_city_id := -1


func prepare(game: Node) -> String:
	var setup := game.get("setup") as GameSetup
	if mode != MODE_CONQUEST:
		return ""
	return _arrange_conquest(game, setup)


func play_turn(game: Node) -> String:
	var setup := game.get("setup") as GameSetup
	if setup == null:
		return _fail(null, "the game has no setup")
	if setup.result != null:
		return ENDED
	var reset := _reset_modes(game)
	if not reset.is_empty():
		return reset
	var acted := _act_units(game, setup)
	if acted == ENDED or acted.begins_with("FAIL"):
		return acted
	setup = game.get("setup") as GameSetup
	if setup.result != null:
		return _finish_ended(game, setup)
	if mode == MODE_SCORE:
		var planted := _ensure_rival_city(game, setup)
		if planted.begins_with("FAIL"):
			return planted
	var queued := _queue_work(game, setup)
	if queued.begins_with("FAIL"):
		return queued
	var cast := _handle_spell(game, setup)
	if cast == ENDED or cast.begins_with("FAIL"):
		return cast
	# Targeting and placement stay armed on their probe turns so End Turn has
	# to be accepted while they are up. The menu probe opens the menu and then
	# ends the turn with the button, which is the path that must keep working.
	var probing_spell := str(game.get("_spell_id")) != ""
	var probing_place := str(game.get("_placing")) != ""
	if not probing_spell and not probing_place:
		var menu := _open_menu(game, setup)
		if menu.begins_with("FAIL"):
			return menu
	return _end_turn(game, setup)


func summary() -> String:
	return "founds %d attacks %d captures %d sink %s rival_cast %s spared %d" % [
		founds, attacks, captures, did_sink, did_rival_cast, spared_tiles,
	]


func _act_units(game: Node, setup: GameSetup) -> String:
	var ids: Array[int] = []
	for unit in setup.players[setup.human_index].units:
		ids.append(unit.id)
	ids.sort()
	for id in ids:
		setup = game.get("setup") as GameSetup
		if setup.result != null:
			return _finish_ended(game, setup)
		var unit := _unit_by_id(setup, id)
		if unit == null or unit.owner != setup.human_index:
			continue
		var status := _act(game, setup, unit)
		if status == ENDED or status.begins_with("FAIL"):
			return status
	return ""


func _act(game: Node, setup: GameSetup, unit: PlayerState.UnitState) -> String:
	if mode == MODE_CONQUEST:
		if unit.unit_type == "settler" and setup.city_count(setup.human_index) == 0:
			return _try_found(game, setup, unit)
		if unit.id == _hunter_id:
			return _hunt(game, setup, unit)
		return _order_if_idle(game, setup, unit, true)
	if unit.unit_type == "settler" and setup.city_count(setup.human_index) < 2:
		var founded := _try_found(game, setup, unit)
		if founded == ENDED or founded.begins_with("FAIL") or _unit_by_id(setup, unit.id) == null:
			return founded
	if setup.config.unit(unit.unit_type).combatant:
		var attack := _attack_cell(setup, unit)
		if attack != _NO_CELL:
			attacks += 1
			return _use_ability(game, setup, unit, attack)
		var step := _step_toward(setup, unit, false)
		if step != _NO_CELL:
			return _right_click(game, setup, unit, step, "move")
	elif unit.unit_type == "settler" and unit.ap > 0:
		var step := _step_toward(setup, unit, false)
		if step != _NO_CELL and setup.turn % 5 == 0:
			return _right_click(game, setup, unit, step, "move")
	# Leave one idle unit so End Turn takes the warn-then-confirm path.
	var ordered := setup.turn % 2 == 0
	return _order_if_idle(game, setup, unit, ordered)


func _hunt(game: Node, setup: GameSetup, unit: PlayerState.UnitState) -> String:
	var capture := _capture_cell(setup, unit)
	if capture != _NO_CELL:
		captures += 1
		return _right_click(game, setup, unit, capture, "capture")
	var step := _step_toward(setup, unit, true)
	if step != _NO_CELL:
		return _right_click(game, setup, unit, step, "move")
	return _order_if_idle(game, setup, unit, true)


func _try_found(game: Node, setup: GameSetup, unit: PlayerState.UnitState) -> String:
	if unit.unit_type != "settler" or not setup.can_found(unit).is_empty():
		return ""
	if not _select_unit(game, unit):
		return _fail(setup, "could not select the settler")
	var button := SceneDriver.order_button(game, "found")
	if button.disabled:
		return ""
	last_action = "found city"
	var cities_before := setup.cities.size()
	button.pressed.emit()
	if setup.cities.size() != cities_before + 1:
		return _fail(setup, "Found City did not found")
	founds += 1
	var problem := _after_action(game, setup)
	if not problem.is_empty():
		return problem
	if setup.result != null:
		return _finish_ended(game, setup)
	return ""


func _right_click(game: Node, setup: GameSetup, unit: PlayerState.UnitState, cell: Vector2i, label: String) -> String:
	if not _select_unit(game, unit):
		return _fail(setup, "could not select %s %d" % [unit.unit_type, unit.id])
	last_action = "%s %s %d -> %s" % [label, unit.unit_type, unit.id, cell]
	SceneDriver.click_cell(game, cell, MOUSE_BUTTON_RIGHT)
	var problem := _after_action(game, setup)
	if not problem.is_empty():
		return problem
	if setup.result != null:
		return _finish_ended(game, setup)
	return ""


func _order_if_idle(game: Node, setup: GameSetup, unit: PlayerState.UnitState, do_order: bool) -> String:
	if not do_order or unit.ap <= 0 or not unit.order.is_empty():
		return ""
	if not _select_unit(game, unit):
		return ""
	if unit.id % 2 == 0:
		last_action = "fortify %d" % unit.id
		SceneDriver.press_action(game, "fortify_unit")
	else:
		last_action = "skip %d" % unit.id
		SceneDriver.order_button(game, "skip").pressed.emit()
	return _after_action(game, setup)


func _queue_work(game: Node, setup: GameSetup) -> String:
	if mode != MODE_SCORE:
		return ""
	if setup.turn % 10 == 3:
		return _arm_placement(game, setup)
	var city := _primary_city(setup)
	if city == null:
		return ""
	if not _select_city(game, city):
		return _fail(setup, "could not select the city")
	if did_sink and setup.turn % 17 == 0 and not city.queue.is_empty():
		last_action = "cancel queue"
		var row := game.get_node("%QueueList").get_child(0)
		(row.get_node("CancelButton") as Button).pressed.emit()
		var cancelled := _after_action(game, setup)
		if not cancelled.is_empty():
			return cancelled
	if did_sink and setup.turn % 13 == 0 and city.queue.size() >= 2:
		last_action = "reorder queue"
		var first := game.get_node("%QueueList").get_child(0)
		var down := first.get_node("DownButton") as Button
		if not down.disabled:
			down.pressed.emit()
			var moved := _after_action(game, setup)
			if not moved.is_empty():
				return moved
	if city.queue.size() >= 2:
		return ""
	if not did_sink or not _has_sink_target(setup):
		return _enqueue_building(game, setup, city)
	var unit_id := _next_unit(setup, city)
	if unit_id.is_empty():
		return ""
	last_action = "queue %s" % unit_id
	var before := city.queue.size()
	_build_button(game, unit_id).pressed.emit()
	if city.queue.size() != before + 1:
		var reason := (game.get_node("%CityReason") as Label).text
		return _fail(setup, "queue %s did not stick (%s)" % [unit_id, reason])
	return _after_action(game, setup)


func _arm_placement(game: Node, setup: GameSetup) -> String:
	var city := _primary_city(setup)
	if city == null:
		return ""
	if not _select_city(game, city):
		return _fail(setup, "could not select the city to place")
	last_action = "arm placement"
	(game.get_node("%BuildGranary") as Button).pressed.emit()
	if str(game.get("_placing")).is_empty():
		return _fail(setup, "placement did not arm")
	return _after_action(game, setup)


func _enqueue_building(game: Node, setup: GameSetup, city: MapCity) -> String:
	var item_id := _BUILD_CYCLE[setup.turn % _BUILD_CYCLE.size()]
	var plots := _placement_cells(setup, city, item_id)
	if plots.is_empty():
		return ""
	if not _select_city(game, city):
		return _fail(setup, "could not select the city to build")
	last_action = "queue %s" % item_id
	_build_button(game, item_id).pressed.emit()
	if str(game.get("_placing")) != item_id:
		return _fail(setup, "placement did not arm for %s" % item_id)
	SceneDriver.click_cell(game, plots[0])
	var queued := false
	for item in city.queue:
		if item.item_id == item_id and item.cell == plots[0]:
			queued = true
	if not queued:
		var reason := (game.get_node("%CityReason") as Label).text
		return _fail(setup, "building %s was not queued (%s)" % [item_id, reason])
	return _after_action(game, setup)


func _handle_spell(game: Node, setup: GameSetup) -> String:
	if mode != MODE_SCORE:
		return ""
	if not did_sink:
		var sunk := _try_sink(game, setup)
		if sunk == ENDED or sunk.begins_with("FAIL") or sunk == "cast":
			return "" if sunk == "cast" else sunk
	if not did_rival_cast or setup.turn % 4 == 0:
		var cast := _try_cast(game, setup, not did_rival_cast)
		if cast == ENDED or cast.begins_with("FAIL") or cast == "cast":
			return "" if cast == "cast" else cast
	if setup.turn % 10 == 6 and setup.players[setup.human_index].casts_this_turn == 0:
		return _arm_spell(game, setup)
	return ""


func _try_sink(game: Node, setup: GameSetup) -> String:
	var cell := _sink_cell(setup)
	if cell == _NO_CELL:
		return ""
	if not setup.spell_block_reason(setup.human_index, "carve_river").is_empty():
		return ""
	return _cast_at(game, setup, "carve_river", cell, true, false)


func _try_cast(game: Node, setup: GameSetup, prefer_rival: bool) -> String:
	var human := setup.players[setup.human_index]
	if human.casts_this_turn > 0:
		return ""
	# Hold mana for the river until a building has been sunk.
	if not did_sink and human.mana < setup.config.spell("carve_river").mana + setup.config.spell("restore_plains").mana:
		return ""
	var spell_id := _CAST_CYCLE[setup.turn % _CAST_CYCLE.size()]
	if not setup.spell_block_reason(setup.human_index, spell_id).is_empty():
		spell_id = _ready_spell(setup)
	if spell_id.is_empty():
		return ""
	var target := _spell_target(setup, spell_id, prefer_rival)
	if target == _NO_CELL:
		return ""
	var rival := _owner_is_rival(setup, target)
	return _cast_at(game, setup, spell_id, target, false, rival)


func _arm_spell(game: Node, setup: GameSetup) -> String:
	var spell_id := _ready_spell(setup)
	if spell_id.is_empty():
		return ""
	last_action = "arm %s" % spell_id
	var button := game.get_node("%SpellButtons").get_node("Spell_%s" % spell_id) as Button
	button.pressed.emit()
	if str(game.get("_spell_id")) != spell_id:
		return _fail(setup, "spell %s did not arm" % spell_id)
	return _after_action(game, setup)


func _cast_at(game: Node, setup: GameSetup, spell_id: String, cell: Vector2i, sinking: bool, rival: bool) -> String:
	var human := setup.players[setup.human_index]
	var before := human.casts_this_turn
	last_action = "cast %s at %s" % [spell_id, cell]
	var button := game.get_node("%SpellButtons").get_node("Spell_%s" % spell_id) as Button
	if button.disabled:
		return ""
	button.pressed.emit()
	SceneDriver.click_cell(game, cell)
	if human.casts_this_turn != before + 1:
		var tip := (game.get_node("%Tooltip") as Label).text
		return _fail(setup, "cast %s did not spend the cast (%s)" % [spell_id, tip])
	if sinking:
		did_sink = true
	if rival:
		did_rival_cast = true
	var problem := _after_action(game, setup)
	if not problem.is_empty():
		return problem
	if setup.result != null:
		return _finish_ended(game, setup)
	return "cast"


func _open_menu(game: Node, setup: GameSetup) -> String:
	last_action = "open menu"
	var turn_before := setup.turn
	(game.get_node("%MenuButton") as Button).pressed.emit()
	var menu := game.get_node("%InGameMenu") as CanvasItem
	if not menu.visible:
		return _fail(setup, "the menu did not open")
	SceneDriver.press_action(game, "end_turn")
	if setup.turn != turn_before or setup.result != null:
		return _fail(setup, "SOFT-LOCK Enter ended the turn while the menu was open")
	return _after_action(game, setup)


func _end_turn(game: Node, setup: GameSetup) -> String:
	# Ticket 30: a starting settler on volcanic ground dies at End Turn and
	# eliminates a player who has not founded. Paint plains only in that case.
	# Remove this call when ticket 30 lands.
	spared_tiles += SceneDriver.spare_settlers(setup, true)
	var spared := _after_core(setup)
	if not spared.is_empty():
		return spared
	var before := setup.turn
	last_action = "end turn"
	var button := game.get_node("%EndTurnButton") as Button
	button.pressed.emit()
	if setup.result != null:
		return _finish_ended(game, setup)
	if not (game.get_node("%EndTurnWarning") as Label).text.is_empty():
		last_action = "confirm end turn"
		button.pressed.emit()
	if setup.result != null:
		return _finish_ended(game, setup)
	if setup.turn != before + 1:
		return _fail(setup, "SOFT-LOCK confirmed End Turn did not advance or end the game")
	if setup.turn > setup.config.turn_limit:
		return _fail(setup, "SOFT-LOCK the turn went past the limit")
	var problem := _after_action(game, setup)
	if not problem.is_empty():
		return problem
	return ""


func _finish_ended(game: Node, setup: GameSetup) -> String:
	if setup.turn > setup.config.turn_limit:
		return _fail(setup, "the turn went past the limit as the game ended")
	var problem := _after_core(setup)
	if not problem.is_empty():
		return problem
	var before := SoakInvariants.fingerprint(setup)
	var view_before := _view_fingerprint(game)
	last_action = "input after result"
	# Ending the game queues a scene change. From this harness that flush can
	# leave the board before this function runs, so a viewport click would have
	# no canvas. The handlers still have to ignore the key and the button.
	if is_instance_valid(game) and game.is_inside_tree():
		SceneDriver.click_cell(game, Vector2i(1, 1))
	SceneDriver.press_action(game, "end_turn")
	if is_instance_valid(game) and game.has_method("_on_end_turn_pressed"):
		game._on_end_turn_pressed()
	var after := SoakInvariants.fingerprint(setup)
	if before != after or view_before != _view_fingerprint(game):
		return _fail(setup, "input changed state after the result was set")
	return ENDED


func _reset_modes(game: Node) -> String:
	var setup := game.get("setup") as GameSetup
	var menu := game.get_node("%InGameMenu") as CanvasItem
	if menu.visible:
		last_action = "close menu"
		(game.get_node("%MenuButton") as Button).pressed.emit()
		if menu.visible:
			return _fail(setup, "SOFT-LOCK the menu stayed open")
	if str(game.get("_placing")) != "":
		last_action = "cancel placement"
		var cancel := game.get_node("%CancelPlaceButton") as Button
		if cancel.visible:
			cancel.pressed.emit()
		else:
			game._on_cancel_place_pressed()
		if str(game.get("_placing")) != "":
			return _fail(setup, "SOFT-LOCK placement stayed armed")
	if str(game.get("_spell_id")) != "" or str(game.get("_ability_id")) != "":
		last_action = "cancel targeting"
		SceneDriver.press_action(game, "toggle_menu")
		if str(game.get("_spell_id")) != "" or str(game.get("_ability_id")) != "":
			return _fail(setup, "SOFT-LOCK targeting stayed armed")
		if menu.visible:
			return _fail(setup, "SOFT-LOCK canceling targeting opened the menu")
	return ""


func _after_action(game: Node, setup: GameSetup) -> String:
	var problem := _after_core(setup)
	if not problem.is_empty():
		return problem
	if setup.result != null:
		return ""
	return _view_ok(game, setup)


func _after_core(setup: GameSetup) -> String:
	var problem := SoakInvariants.check(setup)
	if problem.is_empty():
		return ""
	return _fail(setup, problem)


func _view_ok(game: Node, setup: GameSetup) -> String:
	var turn := (game.get_node("%TurnLabel") as Label).text
	var expected_turn := "%d / %d" % [setup.turn, setup.config.turn_limit]
	if turn != expected_turn:
		return _fail(setup, "turn label '%s' expected %s" % [turn, expected_turn])
	var human := setup.players[setup.human_index]
	var expected_mana := "Mana: %d (+%d/turn)" % [human.mana, setup.mana_per_turn(human.index)]
	var mana := (game.get_node("%ManaLabel") as Label).text
	if mana != expected_mana:
		return _fail(setup, "mana label '%s' expected %s" % [mana, expected_mana])
	for index in setup.players.size():
		var label := game.get_node("%%Score%d" % index) as Label
		var expected := setup.score_line(index)
		if label == null or not label.visible or label.text != expected:
			var shown := "" if label == null else label.text
			return _fail(setup, "score %d '%s' expected %s" % [index, shown, expected])
	return ""


func _view_fingerprint(game: Node) -> Dictionary:
	return {
		"selected": int(game.get("_selected_id")),
		"city": int(game.get("_selected_city_id")),
		"placing": str(game.get("_placing")),
		"spell": str(game.get("_spell_id")),
		"confirm": bool(game.get("_end_confirm")),
	}


func _select_unit(game: Node, unit: PlayerState.UnitState) -> bool:
	last_action = "select %s %d" % [unit.unit_type, unit.id]
	for _i in 6:
		var selected := game._selected_unit() as PlayerState.UnitState
		if selected != null and selected.id == unit.id:
			return true
		SceneDriver.click_cell(game, unit.cell)
	return false


func _select_city(game: Node, city: MapCity) -> bool:
	last_action = "select city %d" % city.id
	var panel := game.get_node("%CityPanel") as CanvasItem
	var title := game.get_node("%SelectionTitle") as Label
	for _i in 6:
		var selected := game._selected_city() as MapCity
		if panel.visible and title.text == "No unit selected" and selected != null and selected.id == city.id:
			return true
		SceneDriver.click_cell(game, city.cell)
	return false


func _ensure_rival_city(game: Node, setup: GameSetup) -> String:
	if _rival_city_id >= 0:
		return ""
	var home := _primary_city(setup)
	if home == null:
		return ""
	var founder: PlayerState.UnitState = null
	for player in setup.players:
		if player.index == setup.human_index or player.eliminated:
			continue
		if setup.city_count(player.index) > 0:
			continue
		founder = _unit_of(setup, player.index, "settler")
		if founder != null:
			break
	if founder == null:
		return ""
	var spot := _founding_spot(setup, home.cell)
	if spot == _NO_CELL:
		return _fail(setup, "no tile for a rival city")
	# No handler founds a city for a rival. The human casts need rival-owned land.
	last_action = "fixture rival city"
	for player in setup.players:
		for unit in player.units:
			if unit.cell == spot and unit != founder:
				unit.cell = _park_cell(setup, spot)
	setup.map.set_land(spot, "plains")
	founder.cell = spot
	var city := setup.found_city(founder)
	if city == null:
		return _fail(setup, "the rival city did not found")
	_rival_city_id = city.id
	setup._refresh_fog()
	game._refresh_board()
	return _after_action(game, setup)


func _arrange_conquest(game: Node, setup: GameSetup) -> String:
	# No handler walks a rival. Place both rival settlers on plains next to the
	# human warrior so the scripted right-clicks can capture them. The captures
	# themselves go through the view.
	var human := setup.human_index
	var warrior := _unit_of(setup, human, "warrior")
	var settler := _unit_of(setup, human, "settler")
	if warrior == null or settler == null:
		return _fail(setup, "conquest is missing a starting unit")
	var rivals: Array[PlayerState.UnitState] = []
	for player in setup.players:
		if player.index == human:
			continue
		var rival := _unit_of(setup, player.index, "settler")
		if rival == null:
			return _fail(setup, "conquest is missing a rival settler")
		rivals.append(rival)
	if rivals.size() < 2:
		return _fail(setup, "conquest needs two rivals")
	var center := Vector2i(8, 8)
	var east := Hex.axial_to_offset(Hex.neighbor(Hex.offset_to_axial(center), Hex.EAST))
	var west := Hex.axial_to_offset(Hex.neighbor(Hex.offset_to_axial(center), Hex.WEST))
	var home := Vector2i(8, 10)
	if not setup.map.in_bounds(center) or not setup.map.in_bounds(east) or not setup.map.in_bounds(west) or not setup.map.in_bounds(home):
		return _fail(setup, "conquest fixture left the map")
	var reserved := {center: true, east: true, west: true, home: true}
	for cell in reserved.keys():
		setup.map.set_land(cell as Vector2i, "plains")
	var keep := {warrior: true, settler: true}
	for rival in rivals:
		keep[rival] = true
	for player in setup.players:
		for unit in player.units:
			if keep.has(unit):
				continue
			var park := _park_cell(setup, center)
			while reserved.has(park):
				park = _next_cell(setup, park)
			setup.map.set_land(park, "plains")
			unit.cell = park
			reserved[park] = true
	warrior.cell = center
	settler.cell = home
	rivals[0].cell = east
	rivals[1].cell = west
	_hunter_id = warrior.id
	setup._refresh_fog()
	game._refresh_board()
	last_action = "fixture conquest"
	return _after_action(game, setup)


func _use_ability(game: Node, setup: GameSetup, unit: PlayerState.UnitState, cell: Vector2i) -> String:
	if not _select_unit(game, unit):
		return _fail(setup, "could not select %s %d" % [unit.unit_type, unit.id])
	var ids := setup.unit_abilities(unit)
	if ids.is_empty():
		return _fail(setup, "%s has no ability" % unit.unit_type)
	var ability_id := ids[0]
	var button := SceneDriver.ability_button(game, ability_id)
	if button == null or button.disabled:
		return _fail(setup, "ability %s is not ready" % ability_id)
	last_action = "ability %s %s %d -> %s" % [ability_id, unit.unit_type, unit.id, cell]
	button.pressed.emit()
	SceneDriver.click_cell(game, cell, MOUSE_BUTTON_LEFT)
	if setup.result == null and unit.ap != 0:
		return _fail(setup, "ability %s did not resolve" % ability_id)
	var problem := _after_action(game, setup)
	if not problem.is_empty():
		return problem
	if setup.result != null:
		return _finish_ended(game, setup)
	return ""


func _attack_cell(setup: GameSetup, unit: PlayerState.UnitState) -> Vector2i:
	if unit.ap <= 0:
		return _NO_CELL
	var ids := setup.unit_abilities(unit)
	if ids.is_empty():
		return _NO_CELL
	var cells: Array[Vector2i] = setup.ability_targets(unit, ids[0])
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _axial_less(a, b))
	for cell in cells:
		if setup.capture_destination(unit, cell):
			continue
		var enemy := setup.enemy_at(unit, cell)
		if enemy != null and not setup.config.unit(enemy.unit_type).combatant:
			continue
		if enemy == null and setup.city_at_cell(cell) == null:
			continue
		return cell
	return _NO_CELL


func _capture_cell(setup: GameSetup, unit: PlayerState.UnitState) -> Vector2i:
	var best := _NO_CELL
	for key in setup.reachable_tiles(unit).keys():
		var cell := key as Vector2i
		if not setup.capture_destination(unit, cell):
			continue
		var settler := setup.enemy_at(unit, cell)
		if settler == null or setup.config.unit(settler.unit_type).combatant:
			continue
		if best == _NO_CELL or _axial_less(cell, best):
			best = cell
	return best


func _step_toward(setup: GameSetup, unit: PlayerState.UnitState, allow_capture: bool) -> Vector2i:
	if unit.ap <= 0:
		return _NO_CELL
	var goal := _nearest_goal(setup, unit.cell, allow_capture)
	if goal == _NO_CELL:
		return _NO_CELL
	var origin := Hex.distance(Hex.offset_to_axial(unit.cell), Hex.offset_to_axial(goal))
	var best := _NO_CELL
	var best_dist := origin
	var cells: Array[Vector2i] = []
	for key in setup.reachable_tiles(unit).keys():
		cells.append(key as Vector2i)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _axial_less(a, b))
	for cell in cells:
		if not allow_capture and setup.capture_destination(unit, cell):
			continue
		if unit.unit_type == "settler" and setup.map.land_at(cell) == "volcanic":
			continue
		var dist := Hex.distance(Hex.offset_to_axial(cell), Hex.offset_to_axial(goal))
		if dist < best_dist or (dist == best_dist and best != _NO_CELL and _axial_less(cell, best) and dist < origin):
			if dist < origin:
				best = cell
				best_dist = dist
	return best


func _nearest_goal(setup: GameSetup, origin: Vector2i, settlers_only: bool) -> Vector2i:
	var best := _NO_CELL
	var best_dist := 999999
	for player in setup.players:
		if player.index == setup.human_index or player.eliminated:
			continue
		for unit in player.units:
			if settlers_only and unit.unit_type != "settler":
				continue
			var dist := Hex.distance(Hex.offset_to_axial(origin), Hex.offset_to_axial(unit.cell))
			if dist < best_dist or (dist == best_dist and (best == _NO_CELL or _axial_less(unit.cell, best))):
				best = unit.cell
				best_dist = dist
		if settlers_only:
			continue
		for city in setup.cities:
			if city.player != player.index:
				continue
			var dist := Hex.distance(Hex.offset_to_axial(origin), Hex.offset_to_axial(city.cell))
			if dist < best_dist or (dist == best_dist and (best == _NO_CELL or _axial_less(city.cell, best))):
				best = city.cell
				best_dist = dist
	return best


func _sink_cell(setup: GameSetup) -> Vector2i:
	var found := _NO_CELL
	for city in setup.cities:
		if city.player != setup.human_index:
			continue
		for building in city.buildings:
			if _river_ok(setup, building.cell) and (found == _NO_CELL or _axial_less(building.cell, found)):
				found = building.cell
		for item in city.queue:
			if item.is_building and _river_ok(setup, item.cell) and (found == _NO_CELL or _axial_less(item.cell, found)):
				found = item.cell
	return found


func _river_ok(setup: GameSetup, cell: Vector2i) -> bool:
	if not setup.map.in_bounds(cell) or setup.map.land_at(cell) == "water":
		return false
	if not setup.spell_skip("water", cell).is_empty():
		return false
	return setup.cast_reason(setup.human_index, "carve_river", cell, Hex.EAST).is_empty()


func _has_sink_target(setup: GameSetup) -> bool:
	return _sink_cell(setup) != _NO_CELL


func _placement_cells(setup: GameSetup, city: MapCity, item_id: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = setup.placement_tiles(city, item_id)
	var open: Array[Vector2i] = []
	for cell in cells:
		if setup.spell_skip("water", cell).is_empty():
			open.append(cell)
	open.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _axial_less(a, b))
	return open


func _spell_target(setup: GameSetup, spell_id: String, prefer_rival: bool) -> Vector2i:
	var rival := _NO_CELL
	var any := _NO_CELL
	for row in setup.map.height:
		for col in setup.map.width:
			var cell := Vector2i(col, row)
			if not setup.cast_reason(setup.human_index, spell_id, cell, Hex.EAST).is_empty():
				continue
			if _owner_is_rival(setup, cell):
				if rival == _NO_CELL or _axial_less(cell, rival):
					rival = cell
			elif any == _NO_CELL or _axial_less(cell, any):
				any = cell
	if prefer_rival and rival != _NO_CELL:
		return rival
	if any != _NO_CELL:
		return any
	return rival


func _ready_spell(setup: GameSetup) -> String:
	for spell_id in _CAST_CYCLE:
		if setup.spell_block_reason(setup.human_index, spell_id).is_empty():
			return spell_id
	return ""


func _owner_is_rival(setup: GameSetup, cell: Vector2i) -> bool:
	var owner := setup.owner_at(cell)
	return owner >= 0 and owner != setup.human_index


func _next_unit(setup: GameSetup, city: MapCity) -> String:
	for offset in _UNIT_CYCLE.size():
		var item_id := _UNIT_CYCLE[(setup.turn + offset) % _UNIT_CYCLE.size()]
		var stats := setup.config.unit(item_id)
		if stats.min_city_size > 0 and city.population < stats.min_city_size:
			continue
		if stats.population_cost > 0 and city.population - stats.population_cost < setup.config.starve_population_min:
			continue
		return item_id
	return ""


func _build_button(game: Node, item_id: String) -> Button:
	return game.get_node("%" + str(_BUILD_BUTTONS[item_id])) as Button


func _primary_city(setup: GameSetup) -> MapCity:
	var found: MapCity = null
	for city in setup.cities:
		if city.player != setup.human_index:
			continue
		if found == null or city.id < found.id:
			found = city
	return found


func _founding_spot(setup: GameSetup, origin: Vector2i) -> Vector2i:
	var taken := {}
	for player in setup.players:
		for unit in player.units:
			taken[unit.cell] = true
	var cells: Array[Vector2i] = []
	for hex in Hex.ring(Hex.offset_to_axial(origin), setup.config.city_min_distance):
		cells.append(Hex.axial_to_offset(hex))
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _axial_less(a, b))
	for cell in cells:
		if not setup.map.in_bounds(cell) or taken.has(cell):
			continue
		var axial := Hex.offset_to_axial(cell)
		var clear := true
		for city in setup.cities:
			if Hex.distance(axial, Hex.offset_to_axial(city.cell)) < setup.config.city_min_distance:
				clear = false
				break
		if clear:
			return cell
	return _NO_CELL


func _park_cell(setup: GameSetup, avoid: Vector2i) -> Vector2i:
	var taken := {}
	for player in setup.players:
		for unit in player.units:
			taken[unit.cell] = true
	taken[avoid] = true
	for row in setup.map.height:
		for col in setup.map.width:
			var cell := Vector2i(col, row)
			if not taken.has(cell):
				return cell
	return Vector2i.ZERO


func _next_cell(setup: GameSetup, cell: Vector2i) -> Vector2i:
	var next := Vector2i(cell.x + 1, cell.y)
	if next.x >= setup.map.width:
		next = Vector2i(0, cell.y + 1)
	if next.y >= setup.map.height:
		next = Vector2i.ZERO
	return next


func _unit_of(setup: GameSetup, player: int, unit_type: String) -> PlayerState.UnitState:
	for unit in setup.players[player].units:
		if unit.unit_type == unit_type:
			return unit
	return null


func _unit_by_id(setup: GameSetup, id: int) -> PlayerState.UnitState:
	for player in setup.players:
		for unit in player.units:
			if unit.id == id:
				return unit
	return null


func _axial_less(a: Vector2i, b: Vector2i) -> bool:
	var aa := Hex.offset_to_axial(a)
	var bb := Hex.offset_to_axial(b)
	if aa.x == bb.x:
		return aa.y < bb.y
	return aa.x < bb.x


func _fail(setup: GameSetup, message: String) -> String:
	var seed := -1 if setup == null else setup.seed_used
	var turn := -1 if setup == null else setup.turn
	return "FAIL %s | seed %d turn %d action %s" % [message, seed, turn, last_action]
