extends Node


func _ready():
	print("✅ InputManager ready")
	set_process_input(true)
	set_process_unhandled_input(true)
	
func _input(event):
	if event.is_action_pressed("toggle_inventory"):
		if InventoryUI:
			InventoryUI._toggle_inventory()
			print("🎮 Input detected in InputManager")

	if event.is_action_pressed("toggle_equipment"):
		if EquipmentMenu:
			EquipmentMenu._toggle_equipment()
			print("🎮 Input detected in InputManager")
