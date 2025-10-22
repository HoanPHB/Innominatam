extends Area2D

func _on_body_entered(body):
	if body.is_in_group("player"):
		DialogManager.show_dialog(
			"Knight",
			"Be careful ahead! Monsters roam this area..."
		)

func _ready():
	connect("body_entered", _on_body_entered)
