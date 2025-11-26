extends Node

signal quest_started(quest_id)
signal quest_updated(quest_id)
signal quest_completed(quest_id)

var quests: Dictionary = {}

func _ready():
	var sword_quest = Quest.new("missing_sword", "The Missing Sword", "Find the missing sword and return it to the NPC.")
	var find_objective = QuestObjective.new("Find the diamond sword")
	var return_objective = QuestObjective.new("Return the sword to the NPC")
	sword_quest.add_objective(find_objective)
	sword_quest.add_objective(return_objective)
	add_quest(sword_quest)

	var orc_quest = Quest.new("kill_orcs", "Orc Extermination", "Kill 5 orcs to protect the village.")
	var orc_objective = QuestObjective.new("Defeat the orc encounters", 5)
	orc_quest.add_objective(orc_objective)
	add_quest(orc_quest)
	start_quest("kill_orcs")

func add_quest(quest: Quest):
	quests[quest.id] = quest

func get_quest(id: String) -> Quest:
	return quests.get(id, null)

func start_quest(id: String):
	var quest = get_quest(id)
	if quest:
		quest.started = true
		print("Quest started: " + quest.title)
		quest_started.emit(id)

func update_quest_progress(quest_id: String, objective_index: int, amount: int = 1):
	var quest = get_quest(quest_id)
	if quest and quest.started and not quest.is_completed():
		var objective = quest.objectives[objective_index] as QuestObjective
		if objective and not objective.is_completed():
			objective.update_progress(amount)
			print("Quest progress updated: " + quest.title)
			quest_updated.emit(quest_id)
			if quest.is_completed():
				print("Quest completed: " + quest.title)
				quest_completed.emit(quest_id)

func update_kill_quest_progress(trigger_id: String):
	var quest = get_quest("kill_orcs")
	if quest and quest.started and not quest.is_completed():
		if "OrcEncounter" in trigger_id:
			var objective = quest.objectives[0] as QuestObjective
			if not objective.is_completed():
				objective.update_progress(1)
				print("Quest progress updated: " + quest.title)
				quest_updated.emit("kill_orcs")
				if quest.is_completed():
					print("Quest completed: " + quest.title)
					quest_completed.emit("kill_orcs")

func get_active_quests() -> Array:
	var active_quests = []
	for quest_id in quests:
		var quest = quests[quest_id]
		if quest.started and not quest.completed:
			active_quests.append(quest)
	return active_quests

func complete_quest(quest_id: String):
	var quest = get_quest(quest_id)
	if quest and quest.started and not quest.completed:
		quest.completed = true
		print("Quest completed: " + quest.title)
		quest_completed.emit(quest_id)
