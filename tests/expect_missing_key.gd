extends SceneTree

## Expect a non-zero exit. The loader must name the missing key and quit.


func _init() -> void:
	var data := GameConfig.read_json(GameConfig.PATH)
	var players: Dictionary = (data["players"] as Dictionary).duplicate()
	players.erase("count")
	data["players"] = players
	var cfg: GameConfig = GameConfig.from_dict(data)
	if cfg != null:
		printerr("FAIL: loader returned a config with a missing key")
		quit(2)
		return
	print("loader rejected the missing key")
	quit(1)
