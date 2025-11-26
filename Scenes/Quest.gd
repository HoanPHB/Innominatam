extends Node

class_name Quest

var id: String
var title: String
var description: String
var objectives: Array = []
var completed: bool = false
var started: bool = false

func _init(id: String, title: String, description: String):
	self.id = id
	self.title = title
	self.description = description

func add_objective(objective: QuestObjective):
	objectives.append(objective)

func is_completed() -> bool:
	for objective in objectives:
		if not objective.is_completed():
			return false
	completed = true
	return true
