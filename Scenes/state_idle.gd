class_name State_Idle extends State


@onready var walk: State = $"../Walk"

## Stores a reference to the player that this State belongs to

func Enter() -> void:
	player.UpdateAnimation("idle")
	pass
	
func Exit() -> void:
	pass
	
func Process (_delta : float) -> State:
	if player.direction != Vector2.ZERO:
		return walk
	player.velocity = Vector2.ZERO
	return null
	
func Physical (_delta : float) -> State:
	return null
	
func HandleInput(_event : InputEvent) -> State:
	return null
