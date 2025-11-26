extends CanvasLayer

signal menu_closed

@onready var item_list = $"Panel/MarginContainer/VBoxContainer/ItemList"
@onready var use_button = $"Panel/MarginContainer/VBoxContainer/UseButton"

var menu_active: bool = false
const TargetSelectionMenu = preload("res://Scenes/target_selection_menu.tscn")

func _ready() -> void:
	InventoryManager.inventory_changed.connect(update_inventory_display)
	use_button.pressed.connect(_on_UseButton_pressed)
	visible = false
	if InventoryManager.inventory.is_empty():
		InventoryManager.add_item("health_potion", 3)

func update_inventory_display() -> void:
	item_list.clear()
	for item_name in InventoryManager.inventory:
		var amount = InventoryManager.inventory[item_name]
		item_list.add_item("%s x%d" % [item_name, amount])

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_toggle_inventory()

func _toggle_inventory() -> void:
	visible = not visible
	menu_active = visible
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		player_node.state_machine.set_process(!visible)
	if visible:
		update_inventory_display()
	else:
		menu_closed.emit()

func show_menu() -> void:
	visible = true
	menu_active = true
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		player_node.state_machine.set_process(false)
	update_inventory_display()

func hide_menu() -> void:
	visible = false
	menu_active = false
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		player_node.state_machine.set_process(true)
	menu_closed.emit()

func _on_UseButton_pressed() -> void:
	var selected_items = item_list.get_selected_items()
	if selected_items.size() > 0:
		var selected_index = selected_items[0]
		var item_text = item_list.get_item_text(selected_index)
		var item_name = item_text.split(" x")[0]
		
		var item_data = Items.data.get(item_name)
		if item_data and item_data.get("type") == "consumable":
			var menu = TargetSelectionMenu.instantiate()
			add_child(menu)
			menu.item_name = item_name
			menu.character_selected.connect(_on_character_selected_for_item)

func _on_character_selected_for_item(character):
	var selected_items = item_list.get_selected_items()
	if selected_items.size() > 0:
		var selected_index = selected_items[0]
		var item_text = item_list.get_item_text(selected_index)
		var item_name = item_text.split(" x")[0]
		InventoryManager.use_item(item_name, character)
