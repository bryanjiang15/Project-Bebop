class_name GameLog
extends RefCounted

## Per-game log events. The dictionaries are pure: no files, no scenes.
## GameLog.Writer is the only piece that touches the disk.
## A missing `end` line means the game was left before it finished.

const START := "start"
const CAST := "cast"
const END := "end"

## Tests set this to a directory before GameSetup.start. Empty uses config.
static var directory_override: String = ""


static func timestamp() -> String:
	return Time.get_datetime_string_from_system(false, false)


static func start_event(seed_value: int, width: int, height: int, turn_limit: int, players: Array, per_tile: int, per_city: int, per_population: int, when: String) -> Dictionary:
	return {
		"event": START,
		"timestamp": when,
		"seed": seed_value,
		"map": {"width": width, "height": height},
		"turn_limit": turn_limit,
		"players": players,
		"score": {
			"per_tile": per_tile,
			"per_city": per_city,
			"per_population": per_population,
		},
	}


static func cast_event(turn_number: int, player_index: int, player_name: String, spell_id: String, spell_name: String, shape: String, target: Vector2i, direction: int, mana: int, tiles: Array) -> Dictionary:
	var direction_value: Variant = null
	if shape == "line":
		direction_value = Hex.DIRECTION_NAMES[posmod(direction, 6)]
	return {
		"event": CAST,
		"turn": turn_number,
		"player": player_index,
		"player_name": player_name,
		"spell": spell_id,
		"spell_name": spell_name,
		"shape": shape,
		"target": {"col": target.x, "row": target.y},
		"direction": direction_value,
		"mana": mana,
		"tiles": tiles,
	}


static func tile_record(cell: Vector2i, from_land: String, to_land: String, owner: int, skip: String, building: String, queue_dropped: String) -> Dictionary:
	return {
		"col": cell.x,
		"row": cell.y,
		"from": from_land,
		"to": to_land,
		"owner": owner,
		"skip": skip,
		"building": building,
		"queue_dropped": queue_dropped,
	}


static func end_event(result: MatchResult) -> Dictionary:
	var rows: Array = []
	for row in result.rows:
		rows.append({
			"player": row.player,
			"name": row.player_name,
			"color": row.color,
			"human": row.human,
			"score": row.score,
			"tiles": row.tiles,
			"cities": row.cities,
			"population": row.population,
			"eliminated": row.eliminated,
			"reason": row.reason,
		})
	return {
		"event": END,
		"turn": result.turn,
		"ending": result.ending,
		"human_won": result.human_won,
		"rows": rows,
	}


class Writer extends RefCounted:
	var path: String = ""
	var absolute_path: String = ""
	var active: bool = false
	var _ended: bool = false
	var _file: FileAccess

	static func open(cfg: GameConfig, seed_value: int) -> Writer:
		var writer := Writer.new()
		if cfg == null or not cfg.log_enabled:
			return writer
		var directory := cfg.log_directory
		if not GameLog.directory_override.is_empty():
			directory = GameLog.directory_override
		if directory.is_empty():
			push_warning("game log: directory is empty")
			return writer
		var absolute_dir := directory
		if directory.contains("://"):
			absolute_dir = ProjectSettings.globalize_path(directory)
		if _directory_blocked(absolute_dir):
			push_warning("game log: cannot create directory %s (parent is not a directory)" % absolute_dir)
			return writer
		var made := DirAccess.make_dir_recursive_absolute(absolute_dir)
		if made != OK:
			push_warning("game log: cannot create directory %s (%s)" % [absolute_dir, error_string(made)])
			return writer
		var stamp := _file_stamp()
		var file_name := "game_%s_%d.jsonl" % [stamp, seed_value]
		var chosen := directory.path_join(file_name)
		var suffix := 2
		while FileAccess.file_exists(chosen):
			file_name = "game_%s_%d_%d.jsonl" % [stamp, seed_value, suffix]
			chosen = directory.path_join(file_name)
			suffix += 1
		var file := FileAccess.open(chosen, FileAccess.WRITE)
		if file == null:
			push_warning("game log: cannot open %s (%s)" % [chosen, error_string(FileAccess.get_open_error())])
			return writer
		writer._file = file
		writer.path = chosen
		writer.absolute_path = ProjectSettings.globalize_path(chosen)
		writer.active = true
		print("game log: %s" % writer.absolute_path)
		return writer

	func append(event: Dictionary) -> void:
		if not active or _ended or _file == null:
			return
		_file.store_line(JSON.stringify(event))
		if _file.get_error() != OK:
			push_warning("game log: write failed for %s (%s)" % [absolute_path, error_string(_file.get_error())])
			active = false
			_file.close()
			_file = null
			return
		_file.flush()
		if str(event.get("event", "")) == GameLog.END:
			_ended = true
			_file.close()
			_file = null

	## True when some ancestor is a file, so make_dir would fail and print an engine error.
	static func _directory_blocked(absolute_dir: String) -> bool:
		if DirAccess.dir_exists_absolute(absolute_dir):
			return false
		var parent := absolute_dir.get_base_dir()
		var guard := 0
		while not parent.is_empty() and parent != "/" and guard < 64:
			guard += 1
			if FileAccess.file_exists(parent):
				return true
			if DirAccess.dir_exists_absolute(parent):
				return false
			var next := parent.get_base_dir()
			if next == parent:
				return false
			parent = next
		return false

	static func _file_stamp() -> String:
		var now := Time.get_datetime_dict_from_system()
		return "%04d%02d%02d-%02d%02d%02d" % [int(now["year"]), int(now["month"]), int(now["day"]), int(now["hour"]), int(now["minute"]), int(now["second"])]
