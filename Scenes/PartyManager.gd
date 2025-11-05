extends Node

var party_members: Array = []

func _ready():
	# Initialize the party with some default members
	# In a real game, this would be loaded from a save file
	if party_members.is_empty():
		var prysha = create_character("Prysha", 1, 100, 50, ["heal"])
		prysha.equipment.weapon = "sword"
		prysha.equipment.armor = "leather_armor"
		var ishamel = create_character("Ishamel", 1, 120, 30, [])
		ishamel.equipment.amulet = "amulet"
		var felix = create_character("Felix", 1, 80, 70, [])
		var casper = create_character("Casper", 1, 90, 60, [])
		party_members = [prysha, ishamel, felix, casper]

func create_character(name: String, level: int, hp: int, mp: int, skills: Array) -> BattleActor:
	var character = BattleActor.new()
	character.name = name
	character.level = level
	character.hp_max = hp
	character.hp = hp
	character.mp_max = mp
	character.mp = mp
	character.known_skills = skills
	character.stats = Stats.new()
	character.stats.level = level
	return character

func get_party() -> Array:
	return party_members

func add_experience(amount: int):
	for member in party_members:
		member.stats.xp += amount
		if member.stats.xp >= member.stats.xp_to_next_level:
			level_up(member)

func level_up(member: BattleActor):
	member.level += 1
	member.stats.level = member.level
	member.stats.xp -= member.stats.xp_to_next_level
	member.stats.xp_to_next_level = int(member.stats.xp_to_next_level * 1.5)
	member.stats.strength += 2
	member.stats.defense += 1
	member.hp_max += 10
	member.hp = member.hp_max
	member.mp_max += 5
	member.mp = member.mp_max
