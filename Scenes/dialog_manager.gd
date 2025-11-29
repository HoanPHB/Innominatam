extends CanvasLayer

signal dialog_finished(next_dialog)

@onready var dialog_box = $DialogBox
@onready var panel = $DialogBox/Panel
@onready var name_label = panel.get_node("Label") # or "NameLabel"
@onready var text_label = $DialogBox/RichTextLabel
@onready var portrait = $DialogBox/TextureRect
@onready var options_container = $DialogBox/Options

var dialog_active: bool = false
var is_showing := false

func _ready():
	dialog_box.visible = false

func start_dialog(dialog: Dictionary):
	if is_showing:
		return

	is_showing = true
	dialog_active = true
	dialog_box.visible = true
	name_label.text = "NPC" # Default speaker
	
	await _type_text_into_label(dialog["text"])

	for child in options_container.get_children():
		child.queue_free()

	if dialog.has("options"):
		for option in dialog["options"]:
			var button = Button.new()
			button.text = option["text"]
			button.pressed.connect(self._on_option_selected.bind(option["next"]))
			options_container.add_child(button)
	else:
		var button = Button.new()
		button.text = "Continue"
		button.pressed.connect(self._on_option_selected.bind(dialog.get("next", null)))
		options_container.add_child(button)


func _on_option_selected(next_dialog):
	for child in options_container.get_children():
		child.queue_free()
	dialog_box.visible = false
	is_showing = false
	dialog_active = false
	dialog_finished.emit(next_dialog)

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
	dialog_finished.emit(null)

func wait_for_input():
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("ui_accept"):
			break
