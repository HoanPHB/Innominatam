class_name BattlePlayerbar extends HBoxContainer

var actor: BattleActor

@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _name_label: Label = $Name
@onready var _hp_label: Label = $Health
@onready var socket: TurnitySocket = $TurnitySocket

func _ready() -> void:
	_anim.play("RESET")

func set_actor(a: BattleActor) -> void:
	actor = a
	socket.actor = self # The socket actor is the bar itself
	if _name_label:
		_name_label.text = _shorten(actor.name, 6)
	if _hp_label:
		_hp_label.text = "%d" % actor.hp
	if actor and not actor.hp_changed.is_connected(_on_actor_hp_changed):
		actor.hp_changed.connect(_on_actor_hp_changed)

func _shorten(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.substr(0, max_len)

func _on_actor_hp_changed(hp: int, change: int) -> void:
	if _hp_label:
		_hp_label.text = "%d" % hp

func highlight(on: bool) -> void:
	var anim: String = "Highlight" if on else "RESET"
	_anim.play(anim)
