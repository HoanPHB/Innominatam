extends CanvasLayer

signal menu_closed

@onready var item_list = $"Panel/MarginContainer/VBoxContainer/ItemList"

var menu_active: bool = false

func _ready() -> void:
	InventoryManager.inventory_changed.connect(update_inventory_display)
	visible = false

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
