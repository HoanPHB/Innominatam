extends Node2D

@onready var _ambient_music_player: AudioStreamPlayer2D = $AmbientMusic

func _ready() -> void:
	if _ambient_music_player:
		_ambient_music_player.play()
	else:
		push_error("AmbientMusic node not found in playground.tscn!")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		InventoryUI._toggle_inventory()

	if event.is_action_pressed("toggle_equipment"):
		EquipmentMenu._toggle_equipment()

func _exit_tree() -> void:
	if _ambient_music_player:
		_ambient_music_player.stop()
