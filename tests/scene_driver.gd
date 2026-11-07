class_name SceneDriver
extends RefCounted

## Clicks, keys, scene waits, and log reads shared by the smoke scripts and the soak.
## Neither script builds UI. These call the same handlers the player does.


static func click_cell(game: Node, cell: Vector2i, button_index: int = MOUSE_BUTTON_LEFT) -> void:
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


static func ability_button(game: Node, ability_id: String) -> Button:
	return game.get_node("%AbilityButtons").get_node("Ability_%s" % ability_id) as Button


static func order_button(game: Node, order_id: String) -> Button:
	return game.get_node("%AbilityButtons").get_node("Order_%s" % order_id) as Button


static func press_action(game: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	game._unhandled_input(event)


static func hover_cell(game: Node, cell: Vector2i) -> void:
	var map := game.get_node("%Map") as TileMapLayer
	var local: Vector2 = map.map_to_local(cell)
	var world: Vector2 = map.to_global(local)
	var screen: Vector2 = game.get_viewport().get_canvas_transform() * world
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	game._unhandled_input(motion)


static func wait_for(tree: SceneTree, script_path: String, frames: int = 80, context: String = "") -> Node:
	for _i in frames:
		await tree.process_frame
		var scene := tree.current_scene
		if scene != null and scene.get_script() != null and scene.get_script().resource_path == script_path:
			await tree.process_frame
			return scene
	var extra := "" if context.is_empty() else " (%s)" % context
	print("FAIL scene did not load: ", script_path, extra)
	tree.quit(1)
	return null


static func log_events(path: String) -> Array:
	var events: Array = []
	if path.is_empty() or not FileAccess.file_exists(path):
		return events
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


static func count_kind(events: Array, kind: String) -> int:
	var count := 0
	for event in events:
		if str((event as Dictionary).get("event", "")) == kind:
			count += 1
	return count


static func remove_tree(path: String) -> void:
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
				remove_tree(child)
			else:
				dir.remove(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


static func write_json(path: String, data: Dictionary) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "cannot write %s" % path
	file.store_string(JSON.stringify(data))
	file.close()
	return ""


## Ticket 30: a settler can spawn on volcanic ground and die at the first End
## Turn, eliminating a player who has not founded. Painting plains under that
## settler is a harness sidestep, not a rule change. Remove it when ticket 30
## lands. `only_without_city` limits the paint to players who have no city yet,
## which is the case the bug actually ends the game on.
static func spare_settlers(setup: GameSetup, only_without_city: bool = false) -> int:
	var painted := 0
	if setup == null or setup.map == null:
		return 0
	for player in setup.players:
		if only_without_city and setup.city_count(player.index) > 0:
			continue
		for unit in player.units:
			if unit.unit_type != "settler":
				continue
			if setup.map.land_at(unit.cell) != "volcanic":
				continue
			setup.map.set_land(unit.cell, "plains")
			painted += 1
	return painted
