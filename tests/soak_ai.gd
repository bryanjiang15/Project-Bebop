extends SceneTree

## Both rivals and the human are driven by RivalAI on one fixed seed.
## Stops at 20 turns or at a match result. Prints AI SOAK OK.


const SEED := 16016
const TURNS := 20


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var cfg: GameConfig = GameConfig.load_file()
	cfg.log_enabled = false
	var game := GameSetup.start_with_seed(cfg, SEED)
	if game == null:
		print("FAIL ai soak could not build seed ", SEED)
		quit(1)
		return
	var played := 0
	while played < TURNS and game.result == null:
		var before := game.turn
		for player in game.players:
			if game.result != null:
				break
			if player.eliminated:
				continue
			RivalAI.play(game, player.index)
		if game.result == null:
			game.end_turn()
		var broken := SoakInvariants.check(game)
		if not broken.is_empty():
			print("FAIL ai soak turn ", game.turn, " ", broken)
			quit(1)
			return
		if game.result == null and game.turn == before:
			print("FAIL ai soak stalled on turn ", before)
			quit(1)
			return
		played += 1
	var ending := "none" if game.result == null else game.result.ending
	print("AI SOAK OK turns ", played, " result ", ending)
	quit(0)
