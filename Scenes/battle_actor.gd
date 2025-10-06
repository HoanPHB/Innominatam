class_name BattleActor extends Resource

signal hp_changed(hp, change)

var name: String = "ORC"
var hp_max: int = 1
var hp: int = hp_max

# An array of strings that correspond to the keys in the Skills.gd database.
var known_skills: Array[String] = []
var is_defending: bool = false

func take_damage(damage: int) -> int:
	if is_defending:
		damage = damage / 2
	return healhurt(-damage)

func healhurt(value: int) -> int:
	var hp_start: int = hp
	var change: int = 0
	hp += value
	hp = clampi(hp, 0, hp_max)
	change = hp - hp_start
	emit_signal("hp_changed", hp, change)
	return change
