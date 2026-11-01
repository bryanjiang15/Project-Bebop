extends SceneTree

## Headless smoke for the game log. Not a unit test.
## New Game loads a temp config, casts two spells through the spell bar,
## ends on the score screen, then Restart opens a second file.


const LOG_DIR := "/tmp/bebop-ticket19-smoke"
const CONFIG_PATH := "/tmp/bebop-ticket19-smoke-config.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _write_config():
		return
	_remove_tree(LOG_DIR)
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	GameConfig.path_override = CONFIG_PATH
	change_scene_to_file("res://scenes/main_menu.tscn")
	var menu := await _wait_for("res://scripts/view/main_menu.gd")
	if menu == null:
		return
	(menu.get_node("%NewGameButton") as Button).pressed.emit()
	var game := await _wait_for("res://scripts/view/game_view.gd")
	if game == null:
		return
	var setup := game.get("setup") as GameSetup
	if setup == null or setup.log == null or not setup.log.active:
		print("FAIL log did not open")
		quit(1)
		return
	var log_path := setup.log.absolute_path
	if not log_path.begins_with(LOG_DIR) or not FileAccess.file_exists(log_path):
		print("FAIL log path ", log_path)
		quit(1)
		return
	var settler := setup.human_settler_cell()
	_click_cell(game, settler)
	var found := game.get_node("%FoundCityButton") as Button
	if found.disabled:
		print("FAIL found city ", (game.get_node("%FoundCityReason") as Label).text)
		quit(1)
		return
	found.pressed.emit()
	if setup.city_count(setup.human_index) != 1:
		print("FAIL no city")
		quit(1)
		return
	var city: MapCity = setup.cities[0]
	if not _cast_through_bar(game, "grow_forest", city.cell):
		return
	var mouth := Hex.axial_to_offset(Hex.neighbor(Hex.offset_to_axial(city.cell), Hex.EAST))
	if not _cast_through_bar(game, "carve_river", mouth):
		return
	if _count_kind(_log_events(log_path), "cast") != 2:
		print("FAIL cast count")
		quit(1)
		return
	var end := game.get_node("%EndTurnButton") as Button
	end.pressed.emit()
	if is_instance_valid(game):
		var still := game.get("setup") as GameSetup
		if still != null and still.result == null and end.text == "End anyway (Enter)":
			end.pressed.emit()
	var screen := await _wait_for("res://scripts/view/end_screen.gd")
	if screen == null:
		return
	var result := MatchResult.latest
	if result == null or result.rows.is_empty():
		print("FAIL no match result")
		quit(1)
		return
	var shown := (screen.get_node("%LogPath") as Label).text
	if shown != log_path or shown != result.log_path:
		print("FAIL log label '", shown, "' expected ", log_path)
		quit(1)
		return
	var events := _log_events(log_path)
	if _count_kind(events, "start") != 1 or _count_kind(events, "cast") != 2 or _count_kind(events, "end") != 1:
		print("FAIL events ", events.size())
		quit(1)
		return
	var end_event: Dictionary = events[events.size() - 1]
	if str(end_event["ending"]) != result.ending or bool(end_event["human_won"]) != result.human_won:
		print("FAIL end event ", end_event.get("ending"), " ", result.ending)
		quit(1)
		return
	var logged_rows: Array = end_event["rows"]
	if logged_rows.size() != result.rows.size():
		print("FAIL row count")
		quit(1)
		return
	for i in result.rows.size():
		var row: Dictionary = logged_rows[i]
		var want := result.rows[i]
		var line := screen.get_node("%ScoreTable").get_node("ScoreLine%d" % want.player) as HBoxContainer
		var text := "" if line == null else (line.get_node("Text") as Label).text
		if text != want.line() or int(row["score"]) != want.score or int(row["tiles"]) != want.tiles or int(row["cities"]) != want.cities or int(row["population"]) != want.population or bool(row["eliminated"]) != want.eliminated or str(row["reason"]) != want.reason:
			print("FAIL row ", i, " '", text, "'")
			quit(1)
			return
	print("PASS log ", log_path, " ", result.ending)
	(screen.get_node("%RestartButton") as Button).pressed.emit()
	var restarted := await _wait_for("res://scripts/view/game_view.gd")
	if restarted == null:
		return
	var second := restarted.get("setup") as GameSetup
	if second == null or second.log == null or not second.log.active:
		print("FAIL restart did not open a log")
		quit(1)
		return
	if second.log.absolute_path == log_path or not FileAccess.file_exists(second.log.absolute_path):
		print("FAIL second log ", second.log.absolute_path)
		quit(1)
		return
	var second_events := _log_events(second.log.absolute_path)
	var first_events := _log_events(log_path)
	if _count_kind(second_events, "start") != 1 or _count_kind(second_events, "end") != 0:
		print("FAIL second file is not a fresh start")
		quit(1)
		return
	if _count_kind(first_events, "end") != 1:
		print("FAIL the finished game lost its end line")
		quit(1)
		return
	if _jsonl_files(LOG_DIR).size() != 2:
		print("FAIL file count ", _jsonl_files(LOG_DIR).size())
		quit(1)
		return
	print("PASS restart ", second.log.absolute_path)
	print("SMOKE LOG OK")
	quit(0)


func _write_config() -> bool:
	var data := GameConfig.read_json(GameConfig.PATH)
	data["turn_limit"] = 1
	(data["players"] as Dictionary)["starting_mana"] = 200
	(data["spells"] as Dictionary)["casts_per_turn"] = 2
	var log: Dictionary = data["log"]
	log["enabled"] = true
	log["directory"] = LOG_DIR
	data["log"] = log
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file == null:
		print("FAIL cannot write ", CONFIG_PATH)
		quit(1)
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	GameConfig.path_override = CONFIG_PATH
	if GameConfig.load_file() == null:
		print("FAIL temp config did not load")
		quit(1)
		return false
	GameConfig.path_override = ""
	return true


func _cast_through_bar(game: Node, spell_id: String, cell: Vector2i) -> bool:
	var setup := game.get("setup") as GameSetup
	var before := setup.players[setup.human_index].casts_this_turn
	var button := game.get_node("%SpellButtons").get_node("Spell_%s" % spell_id) as Button
	if button.disabled:
		print("FAIL ", spell_id, " greyed: ", button.tooltip_text)
		quit(1)
		return false
	button.pressed.emit()
	_click_cell(game, cell)
	if setup.players[setup.human_index].casts_this_turn != before + 1:
		print("FAIL ", spell_id, " did not cast")
		quit(1)
		return false
	print("PASS cast ", spell_id, " at ", cell)
	return true


func _click_cell(game: Node, cell: Vector2i) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var world: Vector2 = map.to_global(map.map_to_local(cell))
	var screen: Vector2 = game.get_viewport().get_canvas_transform() * world
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen
	press.global_position = screen
	game._unhandled_input(press)
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	game._unhandled_input(release)


func _log_events(path: String) -> Array:
	var events: Array = []
	var text := FileAccess.get_file_as_string(path)
	for line in text.split("\n", false):
		if line.strip_edges().is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed == null or not (parsed is Dictionary):
			events.append({"event": ""})
		else:
			events.append(parsed)
	return events


func _count_kind(events: Array, kind: String) -> int:
	var count := 0
	for event in events:
		if str((event as Dictionary).get("event", "")) == kind:
			count += 1
	return count


func _jsonl_files(path: String) -> PackedStringArray:
	var out := PackedStringArray()
	for file_name in DirAccess.get_files_at(path):
		if file_name.ends_with(".jsonl"):
			out.append(file_name)
	return out


func _remove_tree(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		return
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var child := path.path_join(entry)
			if dir.current_is_dir():
				_remove_tree(child)
			else:
				dir.remove(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _wait_for(script_path: String) -> Node:
	for _i in 80:
		await process_frame
		var scene := current_scene
		if scene != null and scene.get_script() != null and scene.get_script().resource_path == script_path:
			await process_frame
			return scene
	print("FAIL scene did not load: ", script_path)
	quit(1)
	return null
