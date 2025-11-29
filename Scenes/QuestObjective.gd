extends Node

class_name QuestObjective

var description: String
var completed: bool = false
var target_count: int
var current_count: int = 0

func _init(description: String, target_count: int = 1):
	self.description = description
	self.target_count = target_count

func update_progress(amount: int = 1):
	current_count += amount
	if current_count >= target_count:
		completed = true

func is_completed() -> bool:
	return completed
