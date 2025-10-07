extends Area2D

# Path to the battle scene
@export var battle_scene_path: String = "res://Scenes/battle.tscn"

func _ready() -> void:
	connect("body_entered", _on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):  # optional: check if it's the player
		print("Player touched the enemy! Starting battle...")
		get_tree().change_scene_to_file(battle_scene_path)
