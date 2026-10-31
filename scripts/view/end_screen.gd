extends Control

## Victory and Defeat. The score table is the hidden `%ScoreRow` template,
## duplicated once per player from `MatchResult.latest`.


func _ready() -> void:
	var result := MatchResult.latest
	var log_path := %LogPath as Label
	log_path.text = "" if result == null else result.log_path
	var template := %ScoreRow as HBoxContainer
	template.visible = false
	if result == null:
		return
	var table := %ScoreTable as VBoxContainer
	for row in result.rows:
		var line := template.duplicate() as HBoxContainer
		line.unique_name_in_owner = false
		line.visible = true
		line.name = "ScoreLine%d" % row.player
		(line.get_node("Swatch") as ColorRect).color = Color.html(row.color)
		(line.get_node("Text") as Label).text = row.line()
		table.add_child(line)


func _on_restart_pressed() -> void:
	if GameConfig.load_file() == null:
		return
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
