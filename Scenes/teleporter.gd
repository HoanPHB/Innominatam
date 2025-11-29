extends Area2D

@export var destination: Node2D
@export var target_bounds: TileMapLayer

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	print("Teleporter: Body entered: %s" % body.name)
	if body.name == "Player":
		print("Teleporter: Teleporting player...")
		if destination:
			print("Teleporter: Destination found: %s" % destination.global_position)
			body.global_position = destination.global_position
		else:
			push_warning("Teleporter: No destination assigned!")
		
		var playground = get_parent()
		if playground.has_method("update_bounds") and target_bounds:
			print("Teleporter: Updating bounds...")
			playground.update_bounds(target_bounds)
			# Save the bounds path to WorldState
			WorldState.current_zone_bounds_path = playground.get_path_to(target_bounds)
			print("Teleporter: Saved bounds path: %s" % WorldState.current_zone_bounds_path)
		elif not target_bounds:
			push_warning("Teleporter: No target_bounds assigned!")
		else:
			push_warning("Teleporter: Parent does not have update_bounds method!")
