extends Area2D

class_name Interactable

# Optional – name or type to identify
@export var interaction_name: String = "Object"

func _ready():
	connect("area_entered", self.on_area_enter)
	connect("area_exited", self.on_area_exit)

func interact():
	print("Interacted with: ", interaction_name)

func on_area_enter(area):
	pass

func on_area_exit(area):
	pass
