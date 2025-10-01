extends Node

var data: Dictionary = {}

func _ready() -> void:
	# Define base templates for enemies
	var knight := BattleActor.new()
	knight.name = "Knight"
	knight.hp_max = 50
	knight.hp = knight.hp_max
	data[knight.name] = knight

	var orc := BattleActor.new()
	orc.name = "Orc"
	orc.hp_max = 40
	orc.hp = orc.hp_max
	data[orc.name] = orc
	
