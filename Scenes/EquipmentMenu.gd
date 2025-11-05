extends CanvasLayer

signal menu_closed

@onready var character_list = $UIContainer/HBoxContainer/MarginContainer/CharacterList
@onready var equipment_and_inventory = $UIContainer/HBoxContainer/MarginContainer2/EquipmentAndInventory
@onready var inventory_item_list = $UIContainer/InventoryItemList
@onready var menu_cursor = $UIContainer/MenuCursor
@onready var ui_container = $UIContainer

var current_character = null
var button_theme = load("res://Theme/buttonfont.tres")
var menu_active: bool = false
var current_slot_type: String = ""

func _ready():
	menu_cursor.set_active(false)
	# Selection moves cursor only; activation equips
	inventory_item_list.item_selected.connect(_on_inventory_selection_changed)
	inventory_item_list.item_activated.connect(_on_inventory_item_activated)
	populate_character_list() # Populate character buttons initially
	visible = false # Keep menu hidden until activated

func _input(event):
	if event.is_action_pressed("toggle_equipment"):
		_toggle_equipment()
		return

	if not menu_active:
		return

	var focused_control = get_viewport().gui_get_focus_owner()
	
# --- Early: only handle Escape WHEN focus is in equipment column ---
	if menu_active and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			# If focus is in equipment list, move it back to the character list and consume event
			if is_in_equipment_list(focused_control):
				var char_buttons := character_list.get_children()
				# Try to re-focus the button for current_character if available
				if current_character:
					for btn in char_buttons:
						if btn is BaseButton and btn.text == current_character.name:
							btn.grab_focus()
							get_viewport().set_input_as_handled()
							return
				# Fallback to first visible character button
				for btn in char_buttons:
					if btn is BaseButton and btn.visible:
						btn.grab_focus()
						get_viewport().set_input_as_handled()
						return
			# otherwise do nothing here and let the normal cancel logic run later
	# Hard lock focus inside ItemList while it's visible to avoid spill/flicker
	if inventory_item_list.visible:
		if focused_control != inventory_item_list:
			inventory_item_list.grab_focus()
		if event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					var sel: Array = inventory_item_list.get_selected_items()
					if sel.is_empty() and inventory_item_list.item_count > 0:
						inventory_item_list.select(0)
						sel = inventory_item_list.get_selected_items()
					if not sel.is_empty():
						_on_inventory_item_activated(sel[0])
					get_viewport().set_input_as_handled()
					return
				KEY_ESCAPE, KEY_BACKSPACE:
					_handle_ui_cancel_logic()
					get_viewport().set_input_as_handled()
					return
		# Let ItemList handle Up/Down natively; do not synthesize or intercept
		return

	if event.is_action_pressed("ui_left"):
		if is_in_character_list(focused_control):
			# Simulate ui_up for vertical movement in character list
			var event_action = InputEventAction.new()
			event_action.action = "ui_up"
			event_action.pressed = true
			Input.parse_input_event(event_action)
		elif is_in_equipment_list(focused_control):
			# Simulate ui_up for vertical movement in equipment list
			var event_action = InputEventAction.new()
			event_action.action = "ui_up"
			event_action.pressed = true
			Input.parse_input_event(event_action)
		get_viewport().set_input_as_handled() # Consume the event

	elif event.is_action_pressed("ui_right"):
		if is_in_character_list(focused_control):
			# Simulate ui_down for vertical movement in character list
			var event_action = InputEventAction.new()
			event_action.action = "ui_down"
			event_action.pressed = true
			Input.parse_input_event(event_action)
		elif is_in_equipment_list(focused_control):
			# Simulate ui_down for vertical movement in equipment list
			var event_action = InputEventAction.new()
			event_action.action = "ui_down"
			event_action.pressed = true
			Input.parse_input_event(event_action)

		get_viewport().set_input_as_handled() # Consume the event

	elif event.is_action_pressed("ui_accept"):
		if is_in_character_list(focused_control):
			# Move focus from character list to equipment list
			var eq_buttons = equipment_and_inventory.get_children()
			if eq_buttons.size() > 0 and eq_buttons[0] is BaseButton:
			# Defer focus change to next frame so the current Enter press won't activate it.
				eq_buttons[0].call_deferred("grab_focus")
				get_viewport().set_input_as_handled()
	elif is_in_equipment_list(focused_control):
		# Activate equipment button
		if focused_control is BaseButton and event.is_action_pressed("ui_accept"):
			focused_control.emit_signal("pressed")
	elif focused_control == inventory_item_list:
		# Activate currently selected item in the list
		var sel: Array = inventory_item_list.get_selected_items()
		if sel.is_empty() and inventory_item_list.item_count > 0:
			inventory_item_list.select(0)
			sel = inventory_item_list.get_selected_items()
		if not sel.is_empty():
			_on_inventory_item_activated(sel[0])
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_handle_ui_cancel_logic()
		get_viewport().set_input_as_handled()
func _toggle_equipment():
	visible = not visible
	menu_active = visible
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		player_node.state_machine.set_process(!visible)
	if visible:
		_show_menu_internal()
	else:
		menu_closed.emit()

func show_menu() -> void:
	visible = true
	menu_active = true
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		player_node.state_machine.set_process(false)
	_show_menu_internal()

func hide_menu() -> void:
	visible = false
	menu_active = false
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node:
		player_node.state_machine.set_process(true)
	menu_closed.emit()
	menu_cursor.set_active(false)

func populate_character_list():
	var buttons: Array = character_list.get_children()
	var party = PartyManager.get_party()
	for i in range(buttons.size()):
		var btn = buttons[i]
		if i < party.size():
			var member = party[i]
			btn.visible = true
			btn.text = member.name
			if btn is BaseButton:
				for conn in btn.pressed.get_connections():
					btn.pressed.disconnect(conn.callable)
				for conn in btn.focus_entered.get_connections():
					btn.focus_entered.disconnect(conn.callable)
				
				btn.theme = button_theme
				btn.pressed.connect(func(): _on_character_activated(member))
				btn.focus_entered.connect(func(): _on_character_hovered(member))
		else:
			btn.visible = false

	var vis_buttons: Array = []
	for b in buttons:
		if b.visible and b is BaseButton:
			vis_buttons.append(b)


func _on_character_activated(member):
	current_character = member
	populate_equipment_slots()
	# Move focus to the first equipment button for quick selection
	var equipment_buttons = equipment_and_inventory.get_children()
	if equipment_buttons.size() > 0 and equipment_buttons[0] is BaseButton:
		equipment_buttons[0].grab_focus()

func _on_character_hovered(member):
	current_character = member
	populate_equipment_slots()

func populate_equipment_slots():
	if not current_character:
		return

	var eq_buttons: Array = equipment_and_inventory.get_children()
	var labels = ["Weapon", "Armor", "Amulet"]
	var slots = ["weapon", "armor", "amulet"]

	for i in range(min(3, eq_buttons.size())):
		var btn = eq_buttons[i]
		if not (btn is BaseButton):
			continue

		var slot_key = slots[i]
		var label = labels[i]
		var equipped = current_character.equipment.get(slot_key)

		# Use Godot 4 ternary syntax
		btn.text = "%s: %s" % [label, equipped] if equipped else "%s: Empty" % label
		btn.set_meta("slot_type", slot_key)
		btn.theme = button_theme

		# Disconnect old connections to prevent duplicates
		for conn in btn.pressed.get_connections():
			btn.pressed.disconnect(conn.callable)


		# Capture the slot key with an explicit type so the closure compiles
		var this_slot: String = slot_key
		btn.pressed.connect(func(): _on_equipment_slot_selected(this_slot))

	# Vertical focus wiring
	if eq_buttons.size() > 1:
		for i in range(eq_buttons.size()):
			var cur_btn: BaseButton = eq_buttons[i]
			var prev_btn: BaseButton = eq_buttons[i - 1] if i > 0 else eq_buttons.back()
			var next_btn: BaseButton = eq_buttons[i + 1] if i < eq_buttons.size() - 1 else eq_buttons.front()
			cur_btn.focus_neighbor_top = prev_btn.get_path()
			cur_btn.focus_neighbor_bottom = next_btn.get_path()




func _on_equipment_slot_selected(slot_type: String) -> void:
	# Prevent reopening the same slot if already visible
	if inventory_item_list.visible and current_slot_type == slot_type:
		return

	current_slot_type = slot_type
	populate_inventory(slot_type)
	inventory_item_list.visible = true
	inventory_item_list.grab_focus()

	if inventory_item_list.item_count > 0:
		inventory_item_list.select(0)
		_update_inventory_cursor_position()



func populate_inventory(slot_type):
	inventory_item_list.clear()

	var equipped_item_name = current_character.equipment.get(slot_type)
	var unequipped_items: Array = []
	var db := _get_items_db()

	if equipped_item_name:
		var equipped_item_data = db.get(equipped_item_name)
		var equipped_label: String
		if equipped_item_data:
			equipped_label = "%s (Equipped)" % equipped_item_data.name
		else:
			equipped_label = "%s (Equipped)" % equipped_item_name
		var idx = inventory_item_list.add_item(equipped_label)
		inventory_item_list.set_item_metadata(idx, {"name": equipped_item_name, "equipped": true, "slot_type": slot_type})
	else:
		var idx_empty = inventory_item_list.add_item("Empty (Equipped)")
		inventory_item_list.set_item_metadata(idx_empty, {"name": "", "equipped": true, "slot_type": slot_type})

	for item_name in InventoryManager.inventory:
		if item_name == equipped_item_name:
			continue

		var item_data = db.get(item_name)
		if item_data and item_data.has("type") and item_data.type == slot_type:
			unequipped_items.append(item_name)

	unequipped_items.sort()

	for item_name in unequipped_items:
		var amount = InventoryManager.inventory[item_name]
		var item_data = db.get(item_name)
		if item_data:
			var idx = inventory_item_list.add_item("%s x%d" % [item_data.name, amount])
			inventory_item_list.set_item_metadata(idx, {"name": item_name, "equipped": false, "slot_type": slot_type})
		else:
			var idx2 = inventory_item_list.add_item("%s x%d" % [str(item_name), int(amount)])
			inventory_item_list.set_item_metadata(idx2, {"name": str(item_name), "equipped": false, "slot_type": slot_type})

	if inventory_item_list.item_count == 0:
		inventory_item_list.add_item("Empty (None)")

	if inventory_item_list.item_count <= 1:
		var debug_names = []
		match slot_type:
			"weapon":
				debug_names = ["Debug Sword", "Rusty Dagger"]
			"armor":
				debug_names = ["Cloth Shirt", "Leather Vest"]
			"amulet":
				debug_names = ["Wood Charm", "Copper Amulet"]
		for dbg in debug_names:
			var idxd = inventory_item_list.add_item(dbg)
			inventory_item_list.set_item_metadata(idxd, {"name": dbg, "equipped": false, "slot_type": slot_type})

func _on_inventory_item_activated(index):
	var meta = inventory_item_list.get_item_metadata(index)
	if typeof(meta) != TYPE_DICTIONARY:
		return
	var item_name: String = meta.get("name", "")
	if item_name == "":
		return
	var slot_type = meta.get("slot_type", "")
	if slot_type == "":
		var db := _get_items_db()
		if db.has(item_name):
			slot_type = db.get(item_name).type

	equip_item(current_character, slot_type, item_name)
	inventory_item_list.visible = false

	menu_cursor.set_active(true)
	menu_cursor.scale = Vector2.ONE  # Reset the scale to normal size


	# Defer UI refresh by one frame to prevent flicker / smear
	call_deferred("_refresh_equipment_ui")

func _refresh_equipment_ui():
	populate_equipment_slots()
	var slots = equipment_and_inventory.get_children()
	for button in slots:
		var button_slot_type = button.get_meta("slot_type", "")
		if button_slot_type == current_slot_type:
			button.grab_focus()
			break


func _on_inventory_selection_changed(index):
	_update_inventory_cursor_position()

func equip_item(member, slot, item_name):
	if member.equipment[slot]:
		unequip_item(member, slot)

	member.equipment[slot] = item_name
	InventoryManager.remove_item(item_name)


func unequip_item(member, slot):
	var item_name = member.equipment[slot]
	if item_name:
		
		member.equipment[slot] = null
		InventoryManager.add_item(item_name)

func _show_menu_internal() -> void:
	populate_character_list()
	menu_cursor.set_active(true)
	if character_list.get_child_count() > 0:
		var first_btn = character_list.get_child(0)
		first_btn.grab_focus()
		var party = PartyManager.get_party()
		if party.size() > 0:
			current_character = party[0]
		populate_equipment_slots()

func _get_items_db() -> Dictionary:
	if typeof(Items) != TYPE_NIL and "data" in Items and typeof(Items.data) == TYPE_DICTIONARY:
		return Items.data
	return {}

func is_in_character_list(control: Control) -> bool:
	return control and character_list.is_ancestor_of(control)

func is_in_equipment_list(control: Control) -> bool:
	return control and equipment_and_inventory.is_ancestor_of(control)

func _handle_ui_cancel_logic():
	var focused = get_viewport().gui_get_focus_owner()

	# 1) If inventory list is open -> close it and return focus to equipment column (same slot if possible)
	if inventory_item_list.visible:
		inventory_item_list.visible = false
		menu_cursor.set_active(false)
		# try to return focus to the slot we came from
		var slots = equipment_and_inventory.get_children()
		if current_slot_type != "":
			for s in slots:
				if s.get_meta("slot_type", "") == current_slot_type and s is Control:
					s.grab_focus()
					get_viewport().set_input_as_handled()
					return
		# fallback: focus first equipment button
		if slots.size() > 0 and slots[0] is Control:
			slots[0].grab_focus()
		get_viewport().set_input_as_handled()
		return

	# 2) If focus is in equipment column -> move focus back to the character list
	if is_in_equipment_list(focused):
		_show_menu_internal()
		get_viewport().set_input_as_handled()
		return

	# 3) Otherwise close menu
	hide_menu()
	get_viewport().set_input_as_handled()


func _update_inventory_cursor_position():
	var selected_items = inventory_item_list.get_selected_items()
	if not selected_items.is_empty():
		var selected_index = selected_items[0]
		var item_rect = inventory_item_list.get_item_rect(selected_index)
		var item_global_pos = inventory_item_list.global_position + item_rect.position
		menu_cursor.global_position = item_global_pos
		if menu_cursor.texture:
			menu_cursor.scale = Vector2(
				item_rect.size.x / menu_cursor.texture.get_width(),
				item_rect.size.y / menu_cursor.texture.get_height()
			)
		menu_cursor.set_active(true)
	else:
		menu_cursor.set_active(false)
