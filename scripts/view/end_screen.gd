extends Control


func _on_restart_pressed() -> void:
	if GameConfig.load_file() == null:
		return
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_main_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
