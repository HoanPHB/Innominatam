class_name ATB extends ProgressBar

@export var anim_player_path: NodePath = NodePath("AnimationPlayer")
@onready var _anim: AnimationPlayer = get_node_or_null(anim_player_path)
@onready var socket: TurnitySocket = get_parent().get_node("TurnitySocket")

const SPEED_BASE: float = 0.075

func _ready() -> void:
	if _anim:
		_anim.play("RESET")
	value = randf_range(min_value, max_value * 0.75)

func _process(_delta: float) -> void:
	value += SPEED_BASE

	if value >= max_value:
		value = max_value # Clamp
		if _anim:
			_anim.play("highlight")
		set_process(false) # Stop processing this bar
		# socket.enable() is now handled by battle.gd

func reset() -> void:
	if _anim:
		_anim.play("RESET")
	value = min_value
