extends CanvasLayer

signal menu_closed

@onready var character_list = $"UIContainer/HBoxContainer/MarginContainer/CharacterList"
@onready var equipment_slots = $"UIContainer/EquipmentSlots"
@onready var inventory_item_list = $"UIContainer/InventoryItemList"
@onready var menu_cursor = $"UIContainer/MenuCursor"
@onready var ui_container = $"UIContainer"

var current_character = null
var button_theme = load("res://Theme/buttonfont.tres")
var menu_active: bool = false

func _ready():
	menu_cursor.set_active(true)
	inventory_item_list.item_selected.connect(_on_inventory_item_list_item_selected)
	populate_character_list()
	if character_list.get_child_count() > 0:
		character_list.get_child(0).grab_focus()
		current_character = PartyManager.get_party()[0]
		populate_equipment_slots()
	visible = false

func _input(event):
	if event.is_action_pressed("toggle_equipment"):
		_toggle_equipment()

func _toggle_equipment():
	visible = not visible
	menu_active = visible
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		player_node.state_machine.set_process(!visible)
	if visible:
		populate_character_list()
		if character_list.get_child_count() > 0:
			character_list.get_child(0).grab_focus()
			current_character = PartyManager.get_party()[0]
			populate_equipment_slots()
	else:
		menu_closed.emit()

func show_menu() -> void:
	visible = true
	menu_active = true
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		player_node.state_machine.set_process(false)
	populate_character_list()
	if character_list.get_child_count() > 0:
		character_list.get_child(0).grab_focus()
		current_character = PartyManager.get_party()[0]
		populate_equipment_slots()

func hide_menu() -> void:
	visible = false
	menu_active = false
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		player_node.state_machine.set_process(true)
	menu_closed.emit()

func populate_character_list():
	for child in character_list.get_children():
		child.queue_free()
	var party = PartyManager.get_party()
	for member in party:
		var button = Button.new()
		button.text = member.name
		button.theme = button_theme
		button.pressed.connect(func(): _on_character_selected(member))
		character_list.add_child(button)

func _on_character_selected(member):
	current_character = member
	populate_equipment_slots()

func populate_equipment_slots():
	for child in equipment_slots.get_children():
		child.queue_free()

	if not current_character:
		return

	var weapon_button = Button.new()
	weapon_button.text = "Weapon: %s" % current_character.equipment.weapon if current_character.equipment.weapon else "Weapon: None"
	weapon_button.theme = button_theme
	weapon_button.pressed.connect(func(): _on_equipment_slot_selected("weapon"))
	equipment_slots.add_child(weapon_button)

	var armor_button = Button.new()
	armor_button.text = "Armor: %s" % current_character.equipment.armor if current_character.equipment.armor else "Armor: None"
	armor_button.theme = button_theme
	armor_button.pressed.connect(func(): _on_equipment_slot_selected("armor"))
	equipment_slots.add_child(armor_button)

	var amulet_button = Button.new()
	amulet_button.text = "Amulet: %s" % current_character.equipment.amulet if current_character.equipment.amulet else "Amulet: None"
	amulet_button.theme = button_theme
	amulet_button.pressed.connect(func(): _on_equipment_slot_selected("amulet"))
	equipment_slots.add_child(amulet_button)

func _on_equipment_slot_selected(slot_type):
	populate_inventory(slot_type)
	inventory_item_list.visible = true
	inventory_item_list.grab_focus()

func populate_inventory(slot_type):
	inventory_item_list.clear()
	for item_name in InventoryManager.inventory:
		var item_data = Items.data.get(item_name)
		if item_data and item_data.has("type") and item_data.type == slot_type:
			inventory_item_list.add_item(item_name)

func _on_inventory_item_list_item_selected(index):
	var item_name = inventory_item_list.get_item_text(index)
	var slot_type = Items.data.get(item_name).type
	equip_item(current_character, slot_type, item_name)
	inventory_item_list.visible = false
	populate_equipment_slots()
	# Refocus on the equipment slot button
	for button in equipment_slots.get_children():
		if button.text.begins_with(slot_type.capitalize()):
			button.grab_focus()
			break

func equip_item(member, slot, item_name):
	# Unequip existing item
	if member.equipment[slot]:
		unequip_item(member, slot)

	# Equip new item
	member.equipment[slot] = item_name
	InventoryManager.remove_item(item_name)

	# Apply stats
	var item_data = Items.data.get(item_name)
	if item_data.has("attack"):
		member.stats.strength += item_data.attack
	if item_data.has("defense"):
		member.stats.defense += item_data.defense

func unequip_item(member, slot):
	var item_name = member.equipment[slot]
	if item_name:
		# Remove stats
		var item_data = Items.data.get(item_name)
		if item_data.has("attack"):
			member.stats.strength -= item_data.attack
		if item_data.has("defense"):
			member.stats.defense -= item_data.defense

		# Move item back to inventory
		member.equipment[slot] = null
		InventoryManager.add_item(item_name)
