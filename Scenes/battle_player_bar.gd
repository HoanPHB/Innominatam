class_name BattlePlayerbar extends HBoxContainer

signal atb_ready()

var actor: BattleActor

@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _atb: ATB = $ATB
@onready var _name_label: Label = $Name
@onready var _hp_label: Label = $Health

func _ready() -> void:
	_anim.play("RESET")
	# Ensure ATB signal is connected even if scene connection got overridden
	if _atb and not _atb.max_value_reached.is_connected(_on_atb_max_value_reached):
		_atb.max_value_reached.connect(_on_atb_max_value_reached)

func set_actor(a: BattleActor) -> void:
	actor = a
	if _name_label:
		_name_label.text = _shorten(actor.name, 6)
	if _hp_label:
		_hp_label.text = "%d/%d" % [actor.hp, actor.hp_max]
	if actor and not actor.hp_changed.is_connected(_on_actor_hp_changed):
		actor.hp_changed.connect(_on_actor_hp_changed)

func _shorten(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.substr(0, max_len)

func _on_actor_hp_changed(hp: int, change: int) -> void:
	if _hp_label:
		_hp_label.text = "%d/%d" % [hp, actor.hp_max]

func highlight(on: bool) -> void:
	var anim: String = "Highlight" if on else "RESET"
	_anim.play(anim)

func _on_atb_max_value_reached() -> void:
	atb_ready.emit()
	# Animation is controlled by the battle queue (only first ready animates)
	pass
