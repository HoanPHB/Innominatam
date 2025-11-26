extends Interactable

@onready var talk_bubble = $TalkBubble

@export var unique_id: String = ""

var dialog_tree = {}
var current_dialog_key = "start"

func _ready():
	var file = FileAccess.open("res://Scenes/npcs.json", FileAccess.READ)
	var content = file.get_as_text()
	file.close()
	var json = JSON.parse_string(content)
	dialog_tree = json[unique_id]["dialog_tree"]
	
	if DialogStates.dialog_states.has(unique_id):
		current_dialog_key = DialogStates.dialog_states[unique_id]
	
	DialogManager.dialog_finished.connect(_on_dialog_finished)

func on_area_enter(area):
	if area.is_in_group("player_interact_zone"):
		talk_bubble.show()

func on_area_exit(area):
	if area.is_in_group("player_interact_zone"):
		talk_bubble.hide()

func interact():
	if not DialogManager.dialog_active:
		talk_bubble.hide()
		var quest = QuestManager.get_quest("missing_sword")
		if quest and quest.is_completed():
			current_dialog_key = "end"
		elif quest and quest.started:
			if "DiamondSword1" in WorldState.picked_up_items:
				current_dialog_key = "has_sword"
				InventoryManager.remove_item("Diamond Sword")
				QuestManager.update_quest_progress("missing_sword", 0)
				QuestManager.update_quest_progress("missing_sword", 1)
				QuestManager.complete_quest("missing_sword")
			else:
				current_dialog_key = "quest_started"
		
		var dialog = dialog_tree[current_dialog_key]
		DialogManager.start_dialog(dialog)

func _on_dialog_finished(next_dialog_key):
	if next_dialog_key:
		current_dialog_key = next_dialog_key
		DialogStates.dialog_states[unique_id] = current_dialog_key
		var dialog = dialog_tree[current_dialog_key]
		if dialog.has("action"):
			if dialog["action"] == "start_quest":
				QuestManager.start_quest(dialog["quest_id"])
		
		DialogManager.start_dialog(dialog)
	else:
		talk_bubble.show()
