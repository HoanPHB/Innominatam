extends Node2D

@onready var _ambient_music_player: AudioStreamPlayer2D = $AmbientMusic

func _ready() -> void:
	if _ambient_music_player:
		_ambient_music_player.play()
	else:
		push_error("AmbientMusic node not found in playground.tscn!")

@onready var _player: Node2D = $Player

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		InventoryUI._toggle_inventory()

	if event.is_action_pressed("toggle_equipment"):
		EquipmentMenu._toggle_equipment()
	
	if event.is_action_pressed("save_game"):
		var pos = _player.global_position
		SaveManager.save_game({"player_position": {"x": pos.x, "y": pos.y}})
	
	if event.is_action_pressed("load_game"):
		var loaded_data = SaveManager.load_game()
		if loaded_data.has("player_position"):
			var pos_data = loaded_data["player_position"]
			_player.global_position = Vector2(pos_data.x, pos_data.y)

func _exit_tree() -> void:
	if _ambient_music_player:
		_ambient_music_player.stop()
