extends Node

var inventory: Dictionary = {}

signal inventory_changed

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

func use_item(item_name: String, target_character: BattleActor) -> bool:
	if not inventory.has(item_name):
		return false

	var item_data = Items.data.get(item_name)
	if not item_data:
		return false

	if item_data.get("type") == "consumable":
		if item_data.has("hp_recovery"):
			target_character.hp = min(target_character.hp + item_data.get("hp_recovery"), target_character.hp_max)
			return remove_item(item_name)

	return false
