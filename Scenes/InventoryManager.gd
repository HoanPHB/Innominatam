extends Node

var inventory: Dictionary = {}

func add_item(item_name: String, amount: int = 1) -> void:
	if inventory.has(item_name):
		inventory[item_name] += amount
	else:
		inventory[item_name] = amount
	print("Inventory: ", inventory)
	self.emit_signal("inventory_changed")

func remove_item(item_name: String, amount: int = 1) -> bool:
	if inventory.has(item_name):
		inventory[item_name] -= amount
		if inventory[item_name] <= 0:
			inventory.erase(item_name)
		self.emit_signal("inventory_changed")
		return true
	return false

signal inventory_changed
