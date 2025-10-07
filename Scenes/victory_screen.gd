extends Control

signal return_to_overworld

func _on_return_button_pressed():
	return_to_overworld.emit()
