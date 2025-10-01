extends Node

var player: Dictionary = {
	"Prysha": BattleActor.new(),
	"Ishamel": BattleActor.new(),
	"Felix": BattleActor.new(),
	"Casper": BattleActor.new()
}

var party: Array = players.values()

func _ready() -> void:
	Util.set_key_to_names(players)
	
