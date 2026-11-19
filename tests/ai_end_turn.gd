extends SceneTree

## Fresh default game. No painted map and no pinned seed.
## Ends turns through the button and through Enter, including End anyway,
## and checks that a rival unit moves and that sprites follow the board.


const _TURNS := 8


func _init() -> void:
	GameLog.directory_override = "/tmp/bebop-ai-end-turn-logs"
	call_deferred("_run")


func _run() -> void:
	# A rolled seed can put the human settler on volcanic ground. That ends
	# the match on the first End Turn, before a sprite can be checked. Start
	# another default game. Nothing on the board is edited.
	for attempt in 4:
		var outcome := await _play_fresh_game(attempt)
		if outcome == "fail":
			return
		if outcome == "ok":
			print("AI END TURN OK")
			print("AI SPRITE OK")
			quit(0)
			return
		print("AI END TURN match ended before the sprite check, starting another game")
	_fail("every fresh game ended before a sprite could follow a move")


func _play_fresh_game(attempt: int) -> String:
	change_scene_to_file("res://scenes/main_menu.tscn")
	var menu := await SceneDriver.wait_for(self, "res://scripts/view/main_menu.gd", 80, "menu %d" % attempt)
	if menu == null:
		return "fail"
	(menu.get_node("%NewGameButton") as Button).pressed.emit()
	var game := await SceneDriver.wait_for(self, "res://scripts/view/game_view.gd", 80, "new game %d" % attempt)
	if game == null:
		return "fail"
	var setup := game.get("setup") as GameSetup
	if setup == null or setup.config == null:
		_fail("new game has no setup")
		return "fail"
	if setup.config.map_seed != 0 or not setup.config.ai_enabled:
		_fail("expected the default config, seed %d ai %s" % [setup.config.map_seed, setup.config.ai_enabled])
		return "fail"
	print("AI END TURN seed ", setup.seed_used, " fog ", setup.config.ai_obeys_fog)
	_log_units(setup, "start")
	var moved := false
	var saw_rival_sprite_move := false
	for turn_i in _TURNS:
		if setup.result != null or bool(game.get("_leaving")):
			break
		if not _sprites_match(game, setup):
			return "fail"
		var before := _cells(setup)
		var sprites_before := _sprite_positions(game)
		if not _end_real_turn(game, turn_i == 4):
			return "fail"
		if _any_rival_moved(setup, before):
			moved = true
		_log_units(setup, "after %d" % (turn_i + 1))
		if setup.result != null or bool(game.get("_leaving")):
			if setup.result != null:
				print("AI END TURN result ", setup.result.ending)
			break
		if not _sprites_match(game, setup):
			return "fail"
		if not _rival_sprites_followed(game, setup, before, sprites_before):
			return "fail"
		if _rival_sprite_moved(setup, before, sprites_before):
			saw_rival_sprite_move = true
	if not moved:
		_fail("no rival unit changed cell within %d end turns" % _TURNS)
		return "fail"
	if setup.result != null or bool(game.get("_leaving")):
		return "ended"
	if not _human_sprite_follows(game, setup):
		return "fail"
	if saw_rival_sprite_move:
		print("AI SPRITE rival sprite followed a move")
	return "ok"


func _end_real_turn(game: Node, use_enter: bool) -> bool:
	var setup := game.get("setup") as GameSetup
	var turn_before := setup.turn
	var button := game.get_node("%EndTurnButton") as Button
	_press_end(game, button, use_enter)
	if setup.result != null or bool(game.get("_leaving")):
		return true
	if setup.turn != turn_before:
		return true
	if not bool(game.get("_end_confirm")):
		_fail("End Turn did not advance or ask to confirm")
		return false
	if button.text != "End anyway (Enter)":
		_fail("End anyway text was '%s'" % button.text)
		return false
	_press_end(game, button, use_enter)
	if setup.turn == turn_before and setup.result == null and not bool(game.get("_leaving")):
		_fail("second End Turn press did not advance")
		return false
	return true


func _press_end(game: Node, button: Button, use_enter: bool) -> void:
	if use_enter:
		SceneDriver.press_action(game, "end_turn")
	else:
		button.pressed.emit()


func _human_sprite_follows(game: Node, setup: GameSetup) -> bool:
	var unit := _movable_human(setup)
	if unit == null:
		print("AI SPRITE human had no legal step; rival sprite check still ran")
		return true
	var dest := _one_step(setup, unit)
	var actors := game.get_node("%Actors") as Node2D
	var before := actors.get_node_or_null("Unit_%d" % unit.id) as Node2D
	if before == null:
		_fail("human unit %d had no sprite before the step" % unit.id)
		return false
	var old_position := before.position
	SceneDriver.click_cell(game, unit.cell, MOUSE_BUTTON_LEFT)
	SceneDriver.click_cell(game, dest, MOUSE_BUTTON_RIGHT)
	if unit.cell != dest:
		_fail("human unit did not take the legal step")
		return false
	var sprite := actors.get_node_or_null("Unit_%d" % unit.id) as Node2D
	if sprite == null:
		_fail("human sprite disappeared after a legal step")
		return false
	var expected := _expected_position(game, setup, unit)
	if not sprite.position.is_equal_approx(expected):
		_fail("human sprite %s did not follow the cell %s" % [sprite.position, expected])
		return false
	if sprite.position.is_equal_approx(old_position):
		_fail("human sprite stayed at the old cell")
		return false
	return true


func _sprites_match(game: Node, setup: GameSetup) -> bool:
	var actors := game.get_node("%Actors") as Node2D
	var drawn := {}
	for child in actors.get_children():
		var node_name := str(child.name)
		if not node_name.begins_with("Unit_"):
			continue
		var id := int(node_name.trim_prefix("Unit_"))
		var unit := _unit_by_id(setup, id)
		if unit == null:
			_fail("sprite %s has no unit" % node_name)
			return false
		if not setup.fog.unit_visible(setup.human_index, unit.cell):
			_fail("hidden unit %d still has a sprite" % id)
			return false
		var expected := _expected_position(game, setup, unit)
		if not (child as Node2D).position.is_equal_approx(expected):
			_fail("unit %d sprite %s is not the cell %s" % [id, (child as Node2D).position, expected])
			return false
		drawn[id] = true
	for player in setup.players:
		for unit in player.units:
			var visible := setup.fog.unit_visible(setup.human_index, unit.cell)
			var has := drawn.has(unit.id)
			if visible and not has:
				_fail("visible unit %d has no sprite" % unit.id)
				return false
			if not visible and has:
				_fail("hidden unit %d still has a sprite" % unit.id)
				return false
	return true


func _rival_sprites_followed(game: Node, setup: GameSetup, before: Dictionary, sprites_before: Dictionary) -> bool:
	for player in setup.players:
		if player.human:
			continue
		for unit in player.units:
			if not before.has(unit.id):
				continue
			var old_cell: Vector2i = before[unit.id]
			if old_cell == unit.cell:
				continue
			if not setup.fog.unit_visible(setup.human_index, unit.cell):
				var leftover := (game.get_node("%Actors") as Node2D).get_node_or_null("Unit_%d" % unit.id)
				if leftover != null:
					_fail("rival %d left a sprite behind after leaving vision" % unit.id)
					return false
				continue
			var sprite := (game.get_node("%Actors") as Node2D).get_node_or_null("Unit_%d" % unit.id) as Node2D
			if sprite == null:
				_fail("visible rival %d has no sprite after moving" % unit.id)
				return false
			var expected := _expected_position(game, setup, unit)
			if not sprite.position.is_equal_approx(expected):
				_fail("rival %d sprite did not follow the move" % unit.id)
				return false
			if sprites_before.has(unit.id) and sprite.position.is_equal_approx(sprites_before[unit.id]):
				_fail("rival %d sprite stayed at the old position" % unit.id)
				return false
	return true


func _rival_sprite_moved(setup: GameSetup, before: Dictionary, sprites_before: Dictionary) -> bool:
	for player in setup.players:
		if player.human:
			continue
		for unit in player.units:
			if not before.has(unit.id) or not sprites_before.has(unit.id):
				continue
			if (before[unit.id] as Vector2i) != unit.cell and setup.fog.unit_visible(setup.human_index, unit.cell):
				return true
	return false


func _expected_position(game: Node, setup: GameSetup, unit: PlayerState.UnitState) -> Vector2:
	var map := game.get_node("%Map") as TileMapLayer
	var group: Array[PlayerState.UnitState] = []
	for player in setup.players:
		for other in player.units:
			if other.cell != unit.cell:
				continue
			if not setup.fog.unit_visible(setup.human_index, other.cell):
				continue
			group.append(other)
	var index := group.find(unit)
	var shift := Vector2.ZERO
	if group.size() > 1 and index >= 0:
		var along := float(index) / float(group.size() - 1)
		shift = Vector2(lerpf(-36.0, 36.0, along), 0.0)
	return map.map_to_local(unit.cell) + shift


func _movable_human(setup: GameSetup) -> PlayerState.UnitState:
	for unit in setup.players[setup.human_index].units:
		if unit.ap > 0 and _one_step(setup, unit) != unit.cell:
			return unit
	return null


func _one_step(setup: GameSetup, unit: PlayerState.UnitState) -> Vector2i:
	var best := unit.cell
	for key in setup.reachable_tiles(unit).keys():
		var cell := key as Vector2i
		if best == unit.cell or _cell_before(cell, best):
			best = cell
	return best


func _cell_before(a: Vector2i, b: Vector2i) -> bool:
	var aa := Hex.offset_to_axial(a)
	var bb := Hex.offset_to_axial(b)
	if aa.x != bb.x:
		return aa.x < bb.x
	return aa.y < bb.y


func _cells(setup: GameSetup) -> Dictionary:
	var out := {}
	for player in setup.players:
		if player.human:
			continue
		for unit in player.units:
			out[unit.id] = unit.cell
	return out


func _any_rival_moved(setup: GameSetup, before: Dictionary) -> bool:
	for player in setup.players:
		if player.human:
			continue
		for unit in player.units:
			if before.has(unit.id) and (before[unit.id] as Vector2i) != unit.cell:
				return true
	for id in before.keys():
		if _unit_by_id(setup, int(id)) == null:
			return true
	return false


func _sprite_positions(game: Node) -> Dictionary:
	var out := {}
	var actors := game.get_node("%Actors") as Node2D
	for child in actors.get_children():
		var node_name := str(child.name)
		if node_name.begins_with("Unit_"):
			out[int(node_name.trim_prefix("Unit_"))] = (child as Node2D).position
	return out


func _unit_by_id(setup: GameSetup, id: int) -> PlayerState.UnitState:
	for player in setup.players:
		for unit in player.units:
			if unit.id == id:
				return unit
	return null


func _log_units(setup: GameSetup, label: String) -> void:
	for player in setup.players:
		if player.human:
			continue
		var bits: PackedStringArray = []
		for unit in player.units:
			var seen := setup.fog.unit_visible(setup.human_index, unit.cell)
			bits.append("%d:%s@%s %s" % [unit.id, unit.unit_type, unit.cell, "seen" if seen else "hidden"])
		print("AI END TURN ", label, " p", player.index, " ", " ".join(bits))


func _fail(message: String) -> void:
	print("FAIL ", message)
	quit(1)
