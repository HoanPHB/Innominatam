extends Node2D

@export var float_amplitude: float = 3.0
@export var float_speed: float = 2.0

var base_y: float

func _ready():
	base_y = position.y
	hide() # Start hidden

func _process(delta):
	if visible:
		position.y = base_y + sin(Time.get_ticks_msec() / 1000.0 * float_speed) * float_amplitude
