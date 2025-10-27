extends CanvasLayer

signal dialog_finished

@onready var dialog_box = $DialogBox
@onready var panel = $DialogBox/Panel
@onready var name_label = panel.get_node("Label") # or "NameLabel"
@onready var text_label = $DialogBox/RichTextLabel
@onready var portrait = $DialogBox/TextureRect

var dialog_active: bool = false
var is_showing := false

func _ready():
	dialog_box.visible = false

# Typewriter effect for each message line
func _type_text_into_label(message: String, speed: float = 0.03) -> void:
	text_label.text = ""
	for ch in message:
		text_label.text += ch
		await get_tree().process_frame
		await get_tree().create_timer(speed).timeout

# Now message_lines is an Array[String]
func show_dialog(speaker: String, message_lines: Array, portrait_texture: Texture2D = null) -> void:
	if is_showing:
		return
	
	is_showing = true
	dialog_active = true
	dialog_box.visible = true
	
	name_label.text = speaker
	portrait.texture = portrait_texture if portrait_texture else null
	
	# Loop through all dialog lines
	for message in message_lines:
		await _type_text_into_label(message)
		await wait_for_input() # Wait for player to continue
	
	# After all lines are done, hide the dialog box
	dialog_box.visible = false
	is_showing = false
	dialog_active = false
	dialog_finished.emit()

func wait_for_input():
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept"):
			break
