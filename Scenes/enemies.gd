extends Node

var data: Dictionary = {}

func _ready() -> void:
	# Define base templates for enemies
	var knight := BattleActor.new()
	knight.name = "Knight"
	knight.hp_max = 50
	knight.hp = knight.hp_max
	data[knight.name] = knight

	var orc := BattleActor.new()
	orc.name = "Orc"
	orc.hp_max = 40
	orc.hp = orc.hp_max
	data[orc.name] = orc

	var rat := BattleActor.new()
	rat.name = "Rat"
	rat.hp_max = 20
	rat.hp = rat.hp_max
	data[rat.name] = rat
	
func on_enemy_defeated(enemy_name):
	var quest = QuestManager.get_quest("kill_orcs")
	if quest and quest.started and not quest.is_completed():
		if enemy_name == "Orc":
			QuestManager.update_quest_progress("kill_orcs", 0)
