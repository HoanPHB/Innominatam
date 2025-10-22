extends Label

func show_value(value, travel, duration, spread, crit=false):
	text = str(value)

	var font = load("res://fonts/BoldPixels.ttf")
	add_theme_font_override("font", font)
	add_theme_font_size_override("font_size", 16)
	add_theme_color_override("font_outline_color", Color.GRAY)
	add_theme_constant_override("outline_size", 8)

	var movement = travel.rotated(randf_range(-spread/2, spread/2))
	
	# Wait a frame for the Label's size to be updated after changing the text
	await get_tree().process_frame
	pivot_offset = size / 2

	# Create a new Tween procedurally, as is required in Godot 4.
	var tween = create_tween()

	# Animate position and fade out simultaneously
	tween.set_parallel(true)
	tween.tween_property(self, "position", position + movement, duration)
	tween.tween_property(self, "modulate:a", 0.0, duration).from(1.0)

	# Handle crit display (simplified for Godot 4)
	if crit:
		modulate = Color.CRIMSON
		# You could add a scale animation here too if desired
	
	# Wait for the tween to finish, then free the node.
	# In Godot 4, the signal is "finished".
	await tween.finished
	queue_free()
