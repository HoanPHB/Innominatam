extends Area2D

# Path to the battle scene
@export var battle_scene_path: String = "res://Scenes/battle.tscn"

func _ready():
	connect("body_entered", _on_body_entered)

func _on_body_entered(body: Node) -> void:
	print("body entered:", body)
	if body.is_in_group("player"):
		print("player entered, calling BattleTransition")
		BattleTransition.play_and_load(battle_scene_path)
