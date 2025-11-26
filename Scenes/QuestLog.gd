extends CanvasLayer

@onready var quest_container = $NinePatchRect/MarginContainer/ScrollContainer/VBoxContainer
@onready var scroll_container = $NinePatchRect/MarginContainer/ScrollContainer

func _ready():
	QuestManager.quest_started.connect(self._on_quest_updated)
	QuestManager.quest_updated.connect(self._on_quest_updated)
	QuestManager.quest_completed.connect(self._on_quest_updated)
	update_quest_log()

func update_quest_log():
	# Clear existing quests
	for child in quest_container.get_children():
		child.queue_free()

	var active_quests = QuestManager.get_active_quests()
	for quest in active_quests:
		var quest_label = Label.new()
		quest_label.text = "- " + quest.title + ": " + quest.description
		quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		var quest_label_settings = LabelSettings.new()
		quest_label_settings.font_size = 16
		quest_label.label_settings = quest_label_settings
		quest_container.add_child(quest_label)

		for objective in quest.objectives:
			var objective_label = Label.new()
			if objective.completed:
				objective_label.text = "  - " + objective.description + " (Completed)"
			else:
				objective_label.text = "  - " + objective.description + " (" + str(objective.current_count) + "/" + str(objective.target_count) + ")"
			objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			var objective_label_settings = LabelSettings.new()
			objective_label_settings.font_size = 16
			objective_label.label_settings = objective_label_settings
			quest_container.add_child(objective_label)

func _input(event):
	if Input.is_action_just_pressed("toggle_quest_log"):
		visible = not visible
		UIManager.quest_log_active = visible
		if visible:
			update_quest_log()

	if visible:
		if Input.is_action_pressed("up"):
			scroll_container.scroll_vertical -= 10
		if Input.is_action_pressed("down"):
			scroll_container.scroll_vertical += 10

func _on_quest_updated(quest_id):
	if visible:
		update_quest_log()
