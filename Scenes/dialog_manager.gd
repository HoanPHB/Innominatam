extends CanvasLayer

@onready var dialog_box = $DialogBox
@onready var panel = $DialogBox/Panel
@onready var name_label = panel.get_node("Label") # or "NameLabel" if renamed
@onready var text_label = $DialogBox/RichTextLabel
@onready var portrait = $DialogBox/TextureRect

var is_showing := false

func _ready():
	dialog_box.visible = false

func show_dialog(speaker: String, message: String, portrait_texture: Texture2D = null) -> void:
	if is_showing:
		return
	
	is_showing = true
	dialog_box.visible = true
	
	# Update speaker name and portrait
	name_label.text = speaker
	if portrait_texture:
		portrait.texture = portrait_texture
	else:
		portrait.texture = null
	
	# Typewriter effect for text
	text_label.text = ""
	for i in message.length():
		text_label.text = message.substr(0, i + 1)
		await get_tree().create_timer(0.03).timeout
	
	await wait_for_input()
	dialog_box.visible = false
	is_showing = false

func wait_for_input():
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept"):
			break
