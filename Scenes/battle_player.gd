extends TextureButton

func _ready() -> void:
	# Make the material unique for this instance
	if material:
		material = material.duplicate()
