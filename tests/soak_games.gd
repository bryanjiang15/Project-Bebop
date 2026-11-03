extends SceneTree

## Five full games through the real scenes: New Game, then Restart from the
## end screen. Headless. Prints SOAK OK only after every game reaches Victory
## or Defeat and the last Restart is back on turn 1.


const LOG_DIR := "/tmp/bebop-soak-logs"
const CONFIG_PATH := "/tmp/bebop-soak-config.json"
const FRAME_BUDGET := 120
const GAMES: Array[Dictionary] = [
	{"seed": 12345, "mode": "score", "ending": "Turn 50 score"},
	{"seed": 12011, "mode": "score", "ending": "Turn 50 score"},
	{"seed": 12023, "mode": "score", "ending": "Turn 50 score"},
	{"seed": 12059, "mode": "conquest", "ending": "Conquest"},
	{"seed": 12073, "mode": "score", "ending": "Turn 50 score"},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var started := Time.get_ticks_msec()
	GameLog.directory_override = ""
	if not _write_config(int(GAMES[0]["seed"])):
		return
	GameConfig.path_override = CONFIG_PATH
	SceneDriver.remove_tree(LOG_DIR)
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	change_scene_to_file("res://scenes/main_menu.tscn")
	var menu := await SceneDriver.wait_for(self, "res://scripts/view/main_menu.gd", FRAME_BUDGET, "main menu")
	if menu == null:
		return
	(menu.get_node("%NewGameButton") as Button).pressed.emit()
	var game := await SceneDriver.wait_for(self, "res://scripts/view/game_view.gd", FRAME_BUDGET, "new game")
	if game == null:
		return
	var results: Array[String] = []
	for index in GAMES.size():
		var spec: Dictionary = GAMES[index]
		var policy := SoakPolicy.new()
		policy.mode = str(spec["mode"])
		var setup := game.get("setup") as GameSetup
		if setup == null or setup.seed_used != int(spec["seed"]):
			var used := -1 if setup == null else setup.seed_used
			print("FAIL seed %s built %s" % [str(spec["seed"]), used])
			quit(1)
			return
		print("GAME %d seed %d mode %s" % [index + 1, setup.seed_used, policy.mode])
		var prepared := policy.prepare(game)
		if prepared.begins_with("FAIL"):
			print(prepared)
			quit(1)
			return
		var played := await _play(game, policy)
		if not played:
			return
		var screen := await SceneDriver.wait_for(self, "res://scripts/view/end_screen.gd", FRAME_BUDGET, "end screen seed %d" % setup.seed_used)
		if screen == null:
			return
		var line := _check_end(screen, spec, policy)
		if line.is_empty():
			return
		results.append(line)
		print(line)
		print("  ", policy.summary())
		var next_seed := int(GAMES[0]["seed"]) if index + 1 == GAMES.size() else int(GAMES[index + 1]["seed"])
		if not _write_config(next_seed):
			return
		(screen.get_node("%RestartButton") as Button).pressed.emit()
		game = await SceneDriver.wait_for(self, "res://scripts/view/game_view.gd", FRAME_BUDGET, "restart after seed %d" % int(spec["seed"]))
		if game == null:
			return
		if not _fresh_turn(game, next_seed, "restart after seed %d" % int(spec["seed"])):
			return
	var score_games := 0
	var conquests := 0
	for line in results:
		if line.contains("ending=Turn 50 score"):
			score_games += 1
		if line.contains("ending=Conquest"):
			conquests += 1
	if score_games < 3 or conquests < 1:
		print("FAIL endings score=%d conquest=%d" % [score_games, conquests])
		quit(1)
		return
	var elapsed := Time.get_ticks_msec() - started
	print("SOAK OK %d games in %d ms" % [GAMES.size(), elapsed])
	quit(0)


func _play(game: Node, policy: SoakPolicy) -> bool:
	var guard := 0
	while guard < 80:
		guard += 1
		var setup := game.get("setup") as GameSetup
		if setup == null:
			print("FAIL the game scene lost its setup")
			quit(1)
			return false
		if setup.result != null:
			return true
		if setup.turn == 1 or setup.turn % 10 == 0:
			print("  play seed %d turn %d" % [setup.seed_used, setup.turn])
		var before := setup.turn
		var status := policy.play_turn(game)
		if status.begins_with("FAIL"):
			print(status)
			quit(1)
			return false
		setup = game.get("setup") as GameSetup
		if setup.result != null or status == SoakPolicy.ENDED:
			return true
		if setup.turn != before + 1:
			print("FAIL SOFT-LOCK confirmed End Turn did not advance or end the game | seed %d turn %d action %s" % [setup.seed_used, setup.turn, policy.last_action])
			quit(1)
			return false
		if policy.mode == SoakPolicy.MODE_CONQUEST and setup.turn > 12:
			print("FAIL conquest did not finish | seed %d turn %d action %s" % [setup.seed_used, setup.turn, policy.last_action])
			quit(1)
			return false
		await process_frame
	print("FAIL SOFT-LOCK the game did not end | action %s" % policy.last_action)
	quit(1)
	return false


func _check_end(screen: Node, spec: Dictionary, policy: SoakPolicy) -> String:
	var result := MatchResult.latest
	if result == null:
		print("FAIL no match result for seed %s" % str(spec["seed"]))
		quit(1)
		return ""
	if result.ending != str(spec["ending"]):
		print("FAIL ending %s expected %s | seed %s turn %d" % [result.ending, str(spec["ending"]), str(spec["seed"]), result.turn])
		quit(1)
		return ""
	if result.ending == MatchResult.REASON_SCORE and result.turn != 50:
		print("FAIL score ending on turn %d" % result.turn)
		quit(1)
		return ""
	if result.ending == MatchResult.REASON_CONQUEST and not result.human_won:
		print("FAIL conquest was not a human win")
		quit(1)
		return ""
	var title := (screen.get_node("%Title") as Label).text
	var expected_title := "Victory" if result.human_won else "Defeat"
	if title != expected_title:
		print("FAIL end title '%s' expected %s" % [title, expected_title])
		quit(1)
		return ""
	if result.log_path.is_empty() or not result.log_path.begins_with(LOG_DIR):
		print("FAIL log path ", result.log_path)
		quit(1)
		return ""
	if (screen.get_node("%LogPath") as Label).text != result.log_path:
		print("FAIL log label does not match the result")
		quit(1)
		return ""
	var events := SceneDriver.log_events(result.log_path)
	if SceneDriver.count_kind(events, "start") != 1 or SceneDriver.count_kind(events, "end") != 1:
		print("FAIL log events for ", result.log_path)
		quit(1)
		return ""
	if str((events[0] as Dictionary).get("event", "")) != "start" or str((events[events.size() - 1] as Dictionary).get("event", "")) != "end":
		print("FAIL log did not start and end once")
		quit(1)
		return ""
	var end_event: Dictionary = events[events.size() - 1]
	if str(end_event.get("ending", "")) != result.ending or bool(end_event.get("human_won", false)) != result.human_won:
		print("FAIL end row does not match the screen")
		quit(1)
		return ""
	var logged: Array = end_event["rows"]
	if logged.size() != result.rows.size():
		print("FAIL log row count")
		quit(1)
		return ""
	for i in result.rows.size():
		var row: Dictionary = logged[i]
		var want := result.rows[i]
		var line := screen.get_node("%ScoreTable").get_node("ScoreLine%d" % want.player) as HBoxContainer
		var text := "" if line == null else (line.get_node("Text") as Label).text
		if text != want.line() or int(row["score"]) != want.score or int(row["tiles"]) != want.tiles or int(row["cities"]) != want.cities or int(row["population"]) != want.population or bool(row["eliminated"]) != want.eliminated or str(row["reason"]) != want.reason:
			print("FAIL score row ", i, " '", text, "'")
			quit(1)
			return ""
	if str(spec["mode"]) == SoakPolicy.MODE_SCORE and (not policy.did_sink or not policy.did_rival_cast):
		print("FAIL score game did not sink a building and cast on rival land | ", policy.summary())
		quit(1)
		return ""
	var scores: PackedStringArray = []
	for row in result.rows:
		scores.append(str(row.score))
	return "RESULT seed=%s ending=%s turn=%d won=%s scores=%s" % [
		str(spec["seed"]), result.ending, result.turn, result.human_won, ",".join(scores),
	]


func _fresh_turn(game: Node, seed_value: int, source: String) -> bool:
	var setup := game.get("setup") as GameSetup
	var turn := (game.get_node("%TurnLabel") as Label).text
	if setup == null or turn != "1 / 50" or setup.turn != 1 or setup.result != null or MatchResult.latest != null:
		var core := -1 if setup == null else setup.turn
		print("FAIL SOFT-LOCK %s left turn '%s' core %s" % [source, turn, core])
		quit(1)
		return false
	if setup.seed_used != seed_value:
		print("FAIL %s used seed %d expected %d" % [source, setup.seed_used, seed_value])
		quit(1)
		return false
	var problem := SoakInvariants.check(setup)
	if not problem.is_empty():
		print("FAIL restart invariant: ", problem)
		quit(1)
		return false
	print("PASS ", source, " ", turn)
	return true


func _write_config(seed_value: int) -> bool:
	var data := GameConfig.read_json(GameConfig.PATH)
	if data.is_empty():
		print("FAIL could not read the base config")
		quit(1)
		return false
	var map: Dictionary = data["map"]
	map["seed"] = seed_value
	data["map"] = map
	var log: Dictionary = data["log"]
	log["enabled"] = true
	log["directory"] = LOG_DIR
	data["log"] = log
	var err := SceneDriver.write_json(CONFIG_PATH, data)
	if not err.is_empty():
		print("FAIL ", err)
		quit(1)
		return false
	return true
