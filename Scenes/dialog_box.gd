extends Control

@export var text_speed := 0.03    # seconds per letter
@export var auto_advance := false # if true, skip waiting for input

@onready var text_label: RichTextLabel = $RichTextLabel
@onready var name_label: Label = $Panel/Label
@onready var portrait: TextureRect = $TextureRect

var _is_typing := false
var _finished := false

func _ready():
	visible = false

# Call this to start dialogue
func show_dialog(speaker: String, message: String, portrait_tex: Texture2D = null):
	visible = true
	_finished = false
	name_label.text = speaker
	portrait.texture = portrait_tex
	text_label.text = ""
	await _type_text(message)

	if not auto_advance:
		await _wait_for_input()

	hide()

func _wait_for_input():
	while true:
		if Input.is_action_just_pressed("ui_accept"):
			break
		await get_tree().process_frame

func _type_text(message: String):
	_is_typing = true
	for i in message.length():
		text_label.text = message.substr(0, i + 1)
		await get_tree().create_timer(text_speed).timeout
	_is_typing = false
