class_name BattleActor extends Resource

signal hp_changed(hp, change)
signal mp_changed(mp, change)

var name: String = "ORC"
var hp_max: int = 20
var hp: int = hp_max
var mp_max: int = 10
var mp: int = mp_max
var level: int = 1

# An array of strings that correspond to the keys in the Skills.gd database.
var known_skills = []
var is_dead: bool = false
var is_defending: bool = false
var stats: Stats
var equipment: Dictionary = {
	"weapon": null,
	"armor": null,
	"amulet": null
}

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

func consume_mp(cost: int) -> bool:
	if mp >= cost:
		mp -= cost
		emit_signal("mp_changed", mp, -cost)
		return true
	return false

func manahurt(value: int) -> int:
	var mp_start: int = mp
	var change: int = 0
	mp += value
	mp = clampi(mp, 0, mp_max)
	change = mp - mp_start
	emit_signal("mp_changed", mp, change)
	return change

func get_effective_stat(stat_name: String) -> int:
	var base_value: int = 0
	match stat_name:
		"strength":
			base_value = stats.strength
		"defense":
			base_value = stats.defense
		"dexterity":
			base_value = stats.dexterity
		"faith":
			base_value = stats.faith
		"intelligence":
			base_value = stats.intelligence
		"speed":
			base_value = stats.speed
		"hp_max":
			base_value = hp_max
		"mp_max":
			base_value = mp_max
		_:
			push_warning("Attempted to get unknown stat: ", stat_name)
			return 0
	
	return base_value + _get_equipment_bonus(stat_name)

func _get_equipment_bonus(stat_name: String) -> int:
	var total_bonus: int = 0
	for slot in equipment:
		var item_id = equipment[slot]
		if item_id and Items.data.has(item_id):
			var item_data = Items.data[item_id]
			if item_data.has("bonuses") and item_data.bonuses.has(stat_name):
				total_bonus += item_data.bonuses[stat_name]
	return total_bonus
