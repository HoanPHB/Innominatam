extends Interactable

@onready var talk_bubble = $TalkBubble

@export var dialog_lines: Array[String] = [
	"Hello traveler!",
	"The weather is nice today, isn't it?"
]

func on_area_enter(area):
	if area.is_in_group("player_interact_zone"):
		talk_bubble.show()

func on_area_exit(area):
	if area.is_in_group("player_interact_zone"):
		talk_bubble.hide()

func interact():
	if not DialogManager.dialog_active:
		DialogManager.show_dialog("NPC", dialog_lines)
