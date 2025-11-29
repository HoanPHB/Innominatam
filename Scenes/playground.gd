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

	# Camera Limits
	# Camera Limits
	var tilemap = $"Gentle Forest2"
	
	# Restore bounds from WorldState if available
	if not WorldState.current_zone_bounds_path.is_empty():
		var saved_node = get_node_or_null(WorldState.current_zone_bounds_path)
		if saved_node and saved_node is TileMapLayer:
			print("PLAYGROUND_READY: Restoring saved bounds: %s" % WorldState.current_zone_bounds_path)
			tilemap = saved_node
		else:
			push_warning("PLAYGROUND_READY: Saved bounds node not found or invalid: %s" % WorldState.current_zone_bounds_path)
	
	if tilemap:
		update_bounds(tilemap)

func update_bounds(tilemap: TileMapLayer) -> void:
	if _player.has_node("Camera2D"):
		var map_rect = tilemap.get_used_rect()
		var tile_size = tilemap.tile_set.tile_size
		var camera = _player.get_node("Camera2D")
		
		camera.limit_left = map_rect.position.x * tile_size.x
		camera.limit_top = map_rect.position.y * tile_size.y
		camera.limit_right = map_rect.end.x * tile_size.x
		camera.limit_bottom = map_rect.end.y * tile_size.y

		# Player Limits (Collision)
		var existing_boundaries = get_node_or_null("MapBoundaries")
		if existing_boundaries:
			existing_boundaries.queue_free()

		var static_body = StaticBody2D.new()
		static_body.name = "MapBoundaries"
		add_child(static_body)
		static_body.collision_layer = 16 # Layer 5 (bit 4) -> 16
		static_body.collision_mask = 0
		
		var limits = [
			[Vector2(map_rect.position.x * tile_size.x, map_rect.position.y * tile_size.y), Vector2(map_rect.end.x * tile_size.x, map_rect.position.y * tile_size.y)], # Top
			[Vector2(map_rect.end.x * tile_size.x, map_rect.position.y * tile_size.y), Vector2(map_rect.end.x * tile_size.x, map_rect.end.y * tile_size.y)], # Right
			[Vector2(map_rect.end.x * tile_size.x, map_rect.end.y * tile_size.y), Vector2(map_rect.position.x * tile_size.x, map_rect.end.y * tile_size.y)], # Bottom
			[Vector2(map_rect.position.x * tile_size.x, map_rect.end.y * tile_size.y), Vector2(map_rect.position.x * tile_size.x, map_rect.position.y * tile_size.y)] # Left
		]
		
		for points in limits:
			var collision_shape = CollisionShape2D.new()
			var segment = SegmentShape2D.new()
			segment.a = points[0]
			segment.b = points[1]
			collision_shape.shape = segment
			static_body.add_child(collision_shape)


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
