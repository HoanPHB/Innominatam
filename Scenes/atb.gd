class_name ATB extends ProgressBar

@export var anim_player_path: NodePath = NodePath("AnimationPlayer")
@onready var _anim: AnimationPlayer = get_node_or_null(anim_player_path)
@onready var socket: TurnitySocket = get_parent().get_node("TurnitySocket")

const SPEED_BASE: float = 10.0

var last_speed: float = -1.0

func _ready() -> void:
	if _anim:
		_anim.play("RESET")
	value = randf_range(min_value, max_value * 0.75)
	
	var node = socket.actor
	var actor: BattleActor
	if node is BattlePlayerbar:
		actor = node.actor
	elif "data" in node and node.data is BattleActor:
		actor = node.data
	
	if actor:
		last_speed = actor.get_effective_stat("speed")
		print("Initial ATB speed for ", actor.name, ": ", last_speed)


func _process(_delta: float) -> void:
	var node = socket.actor
	var actor: BattleActor
	if node is BattlePlayerbar:
		actor = node.actor
	elif "data" in node and node.data is BattleActor:
		actor = node.data

	if not actor:
		value += SPEED_BASE * _delta
	else:
		var speed = actor.get_effective_stat("speed")
		if speed != last_speed:
			print("ATB speed for ", actor.name, " changed to: ", speed)
			last_speed = speed
		value += SPEED_BASE * (speed / 10.0) * _delta

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
