extends Node2D

@onready var _ambient_music_player: AudioStreamPlayer2D = $AmbientMusic

func _ready() -> void:
	BattleTransition.fade_out(1.0) # Fade out the transition overlay
	if _ambient_music_player:
		_ambient_music_player.play()
	else:
		push_error("AmbientMusic node not found in playground.tscn!")
	
	print("PLAYGROUND_READY: WorldState.player_position before set: %s" % WorldState.player_position)
	print("PLAYGROUND_READY: WorldState.player_position_set before set: %s" % WorldState.player_position_set)
	if WorldState.player_position_set:
		_player.global_position = WorldState.player_position
		WorldState.player_position_set = false # Reset after use

	print("PLAYGROUND_READY: WorldState.defeated_triggers: %s" % WorldState.defeated_triggers)
	print("PLAYGROUND_READY: WorldState.picked_up_items: %s" % WorldState.picked_up_items)

	var all_triggers_nodes: Array[Node] = _get_nodes_by_script(self, "res://Scenes/battle_trigger.gd")
	var all_triggers: Array[BattleTrigger] = []
	for node in all_triggers_nodes:
		all_triggers.append(node as BattleTrigger)
		
	for trigger_node in all_triggers:
		print("PLAYGROUND_READY: Found BattleTrigger: %s" % trigger_node.unique_id)
		if WorldState.defeated_triggers.has(trigger_node.unique_id):
			print("PLAYGROUND_READY: Removing defeated trigger: %s" % trigger_node.unique_id)
			var parent_node = trigger_node.get_parent()
			if parent_node and parent_node is CanvasItem: # Check if parent is a visual node
				print("PLAYGROUND_READY: Hiding parent of trigger: %s" % parent_node.name)
				parent_node.hide() # Hide the parent sprite
			trigger_node.set_deferred("monitoring", false) # Immediately disable collision
			trigger_node.queue_free()

	var all_items_nodes: Array[Node] = _get_nodes_by_script(self, "res://Scenes/item_pickup.gd")
	var all_items: Array[ItemPickup] = []
	for node in all_items_nodes:
		all_items.append(node as ItemPickup)
		
	for item_node in all_items:
		print("PLAYGROUND_READY: Found ItemPickup: %s" % item_node.unique_id)
		if WorldState.picked_up_items.has(item_node.unique_id):
			print("PLAYGROUND_READY: Removing picked up item: %s" % item_node.unique_id)
			item_node.queue_free()


@onready var _player: Node2D = $Player

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		InventoryUI._toggle_inventory()

	if event.is_action_pressed("toggle_equipment"):
		EquipmentMenu._toggle_equipment()
	
	if event.is_action_pressed("save_game"):
		print("PLAYGROUND_SAVE: _player.global_position before saving: %s" % _player.global_position)
		WorldState.player_position = _player.global_position
		WorldState.player_position_set = true
		SaveManager.save_game()
	
	if event.is_action_pressed("load_game"):
		SaveManager.load_game()
		
		# Reload the current scene to apply the loaded WorldState
		get_tree().change_scene_to_file(get_tree().current_scene.scene_file_path)

func _exit_tree() -> void:
	if _ambient_music_player:
		_ambient_music_player.stop()

# Recursive helper function to find nodes with a specific script
func _get_nodes_by_script(root: Node, script_path: String) -> Array[Node]:
	var found_nodes: Array[Node] = []
	for child in root.get_children():
		if child.has_method("get_script") and child.get_script() and child.get_script().resource_path == script_path:
			found_nodes.append(child)
		found_nodes.append_array(_get_nodes_by_script(child, script_path)) # Recurse
	return found_nodes
