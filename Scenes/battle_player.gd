extends TextureButton

@onready var shield_icon = $ShieldIcon
@onready var shield_anim = $AnimationPlayer



func _ready() -> void:
	
	if shield_icon:
		shield_icon.visible = false
	# Make the material unique for this instance
	if material:
		material = material.duplicate()


func play_defend_anim():
	if shield_icon:
		shield_icon.visible = true
	if shield_anim:
		shield_anim.seek(0)
		shield_anim.play("defend_loop")
		
func stop_defend_anim():
	if shield_icon:
		shield_icon.visible = false
	if shield_anim:
		shield_anim.stop()
		
