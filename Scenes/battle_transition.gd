extends CanvasLayer
# attach this script to the BattleTransition scene root and then autoload it
@onready var color_rect: ColorRect = $ColorRect

func _ready():
	# hide by default
	color_rect.visible = false
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

# Plays transition then changes scene. Safe to call from any scene.
func play_and_load(scene_path: String, duration := 1.2) -> void:
	# make sure visible and reset shader param if present
	color_rect.visible = true
	var mat := color_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("progress", 0.0)

	# create tween on the autoload node (so it runs outside other nodes)
	var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if mat:
		tw.tween_property(mat, "shader_parameter/progress", 1.0, duration)
	else:
		# fallback: fade the rect to white (or whatever color)
		color_rect.modulate.a = 0.0
		tw.tween_property(color_rect, "modulate:a", 1.0, duration)

	await tw.finished

	# change scene after transition completes
	get_tree().change_scene_to_file(scene_path)
	
func fade_out(duration := 1.2) -> void:
	print("FADE_OUT: Function called.")
	var scene = get_tree().current_scene
	var options_node = scene.find_child("Options")
	if options_node:
		options_node.hide()
	var bottom_node = scene.find_child("Bottom")
	if bottom_node:
		bottom_node.hide()
	# Makes the overlay fade back out to transparent after entering battle
	if not color_rect:
		push_error("BattleTransition: ColorRect missing")
		return

	print("FADE_OUT: color_rect.visible before setting to true:", color_rect.visible)
	color_rect.visible = true
	print("FADE_OUT: color_rect.visible after setting to true:", color_rect.visible)

	var mat := color_rect.material as ShaderMaterial
	var use_shader_progress := false
	
	if mat:
		print("FADE_OUT: Material is a ShaderMaterial.")
		# Safely detect if the shader source contains a "progress" parameter
		# Shader.code is the shader source string in Godot 4
		var shader_code := ""
		# Protect against unexpected nulls
		if mat.shader.has_method("get_code"):
			shader_code = str(mat.shader.get_code())
		elif "code" in mat.shader: # fallback / defensive
			shader_code = str(mat.shader.code)
		else:
			shader_code = ""

		if shader_code != "" and shader_code.find("progress") != -1:
			use_shader_progress = true
	else:
		print("FADE_OUT: Material is NOT a ShaderMaterial or is null.")

	print("FADE_OUT: use_shader_progress:", use_shader_progress)

	# Prepare tween
	var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if use_shader_progress:
		var current_progress = mat.get_shader_parameter("progress")
		print("FADE_OUT: Current shader progress before forcing to 1.0:", current_progress)
		# Ensure the shader starts from a fully covered state for the fade-out animation
		mat.set_shader_parameter("progress", 1.0)
		print("FADE_OUT: Shader progress forced to 1.0. Now tweening to 0.0")
		# animate shader parameter back to 0.0
		tw.tween_property(mat, "shader_parameter/progress", 0.0, duration)
	else:
		# fallback: fade the rect alpha to 0
		# ensure starting alpha is whatever it currently is (or 1.0)
		print("FADE_OUT: Using fallback alpha tween.")
		if color_rect.modulate.a == 0.0:
			color_rect.modulate.a = 1.0
		tw.tween_property(color_rect, "modulate:a", 0.0, duration)

	await tw.finished
	print("FADE_OUT: Tween finished. Setting color_rect.visible to false.")
	color_rect.visible = false
	print("FADE_OUT: Function finished.")


# Plays a fade-in transition (screen covers) without changing scene
func fade_in(duration := 1.2) -> void:
	color_rect.visible = true
	var mat := color_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("progress", 0.0)

	var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if mat:
		tw.tween_property(mat, "shader_parameter/progress", 1.0, duration)
	else:
		color_rect.modulate.a = 0.0
		tw.tween_property(color_rect, "modulate:a", 1.0, duration)
	await tw.finished

# Changes scene immediately and then fades out
func load_and_fade_out(scene_path: String, duration := 1.2) -> void:
	get_tree().change_scene_to_file(scene_path)
	# After scene is changed, the new scene will call fade_out in its _ready()
	# Or, if this autoload is persistent, we can trigger it here after a short delay
	# to allow the new scene's _ready to process
	await get_tree().create_timer(0.01).timeout # Small delay to ensure new scene's _ready runs
	fade_out(duration)
