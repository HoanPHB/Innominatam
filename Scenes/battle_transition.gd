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
	var scene = get_tree().current_scene
	scene.find_child("Options").hide()
	scene.find_child("Bottom").hide()
	# Makes the overlay fade back out to transparent after entering battle
	if not color_rect:
		push_error("BattleTransition: ColorRect missing")
		return

	color_rect.visible = true

	var mat := color_rect.material as ShaderMaterial
	var use_shader_progress := false

	# Safely detect if the shader source contains a "progress" parameter
	if mat and mat.shader:
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

	# Prepare tween
	var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if use_shader_progress:
		# animate shader parameter back to 0.0
		tw.tween_property(mat, "shader_parameter/progress", 0.0, duration)
	else:
		# fallback: fade the rect alpha to 0
		# ensure starting alpha is whatever it currently is (or 1.0)
		if color_rect.modulate.a == 0.0:
			color_rect.modulate.a = 1.0
		tw.tween_property(color_rect, "modulate:a", 0.0, duration)

	await tw.finished
	color_rect.visible = false
