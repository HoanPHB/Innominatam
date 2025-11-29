extends Control

func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://Scenes/playground.tscn")

func _on_load_button_pressed():
	if SaveManager.save_exists():
		SaveManager.load_game()
		get_tree().change_scene_to_file("res://Scenes/playground.tscn")
	else:
		print("No save game found!") # Replace with UI feedback later

func _on_settings_button_pressed():
	# Settings functionality to be implemented later
	pass

func _on_quit_button_pressed():
	get_tree().quit()
