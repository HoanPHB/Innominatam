extends Panel

signal character_selected(character)

@onready var character_list = $MarginContainer/VBoxContainer/CharacterList
var item_name: String

func _ready():
    populate_character_list()

func _input(event):
    if event.is_action_pressed("ui_cancel"):
        self.queue_free()

func populate_character_list():
    var party = PartyManager.get_party()
    for member in party:
        var btn = Button.new()
        btn.text = "%s (%d/%d)" % [member.name, member.hp, member.hp_max]
        btn.pressed.connect(_on_character_button_pressed.bind(member))
        character_list.add_child(btn)

func _on_character_button_pressed(character):
    emit_signal("character_selected", character)
    self.queue_free()
