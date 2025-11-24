class_name BattleTrigger
extends Area2D

# Path to the battle scene
@export var battle_scene_path: String = "res://Scenes/battle.tscn"
@export var unique_id: String = "" # Unique identifier for this trigger instance

func _ready():
	connect("body_entered", _on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		# Save the current scene path to return later
		WorldState.previous_scene_path = get_tree().current_scene.scene_file_path
		
		# Save player's position
		WorldState.player_position = body.global_position
		WorldState.player_position_set = true
		
		# Add this trigger to the list of defeated triggers
		WorldState.defeated_triggers.append(unique_id)
		print("DEBUG: Added battle trigger '%s' to WorldState.defeated_triggers." % unique_id)
		
		# Transition to battle
		BattleTransition.play_and_load(battle_scene_path)
