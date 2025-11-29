extends TextureButton

var data: BattleActor

func _ready() -> void:
	# Make the material unique for this instance
	if material:
		material = material.duplicate()
	
	# ... rest of _ready() if any
