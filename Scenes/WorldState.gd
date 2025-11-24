extends Node

var player_position: Vector2 = Vector2.ZERO
var player_position_set: bool = false

var defeated_triggers: Array[String] = []
var picked_up_items: Array[String] = []

var previous_scene_path: String = ""
