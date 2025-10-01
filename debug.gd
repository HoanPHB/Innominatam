extends Node


const PRINT_CURRENT_FOCUS: bool = true

func _ready() ->void:
		get_viewport().gui_focus_changed.connect(_on_viewport_gui_focus_changed)
	


func _unhandled_key_input(event: InputEvent) -> void:
	var debug_input: InputEventKey = event
	if event.is_pressed():
		var key: int = debug_input.keycode
		match key:
			
			KEY_Q:
				get_tree().quit()
			KEY_R:
				get_tree().reload_current_scene()
			KEY_F11:
				# Check if the current window mode is fullscreen
				var is_fullscreen: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				# Determine the target mode: if currently fullscreen, switch to windowed; otherwise, switch to fullscreen
				var target_mode: int = DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN
				# Set the window mode to the determined target mode
				DisplayServer.window_set_mode(target_mode)


func _on_viewport_gui_focus_changed(node: Control) -> void:
	if PRINT_CURRENT_FOCUS:
		print(node)
