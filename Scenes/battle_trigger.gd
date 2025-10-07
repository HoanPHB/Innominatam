extends Area2D

signal battle_started;
signal battle_ended;

@export var battle_scene: PackedScene;

var player: CharacterBody2D;
var player_position_before_battle: Vector2;

func _ready():
	body_entered.connect(_on_body_entered)
	battle_ended.connect(_on_battle_ended)

func _on_body_entered(body: Node):
	if body.is_in_group("player"):
		player = body
		player_position_before_battle = player.global_position
		start_battle()

func start_battle():
	if battle_scene:
		battle_started.emit()
		get_tree().change_scene_to_packed(battle_scene)

func _on_battle_ended():
	get_tree().change_scene_to_file("res://Tile Maps/Sprites/overworld.tscn")
	if player:
		player.global_position = player_position_before_battle
