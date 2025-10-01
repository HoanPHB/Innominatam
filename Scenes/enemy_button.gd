extends TextureButton

@export var enemy_key: String = "Knight"
var data: BattleActor

@onready var _atb_bar: ATB = $ATB
@onready var _name_label: Label = $Name

func _ready() -> void:
	# Ensure each button uses its own BattleActor instance
	if data == null:
		if Enemies and Enemies.data.has(enemy_key):
			var tmpl: BattleActor = Enemies.data[enemy_key]
			data = BattleActor.new()
			data.name = tmpl.name
			data.hp_max = tmpl.hp_max
			data.hp = data.hp_max
		else:
			data = BattleActor.new()
			data.name = enemy_key
			data.hp_max = 30
			data.hp = data.hp_max
	# Surface the enemy name while focusing/selecting
	tooltip_text = data.name
	if _name_label:
		_name_label.text = data.name
	
