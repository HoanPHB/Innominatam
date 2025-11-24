extends Node

var party_members: Array = []

func _ready():
	# Initialize the party with some default members
	# In a real game, this would be loaded from a save file
	if party_members.is_empty():
		var prysha = create_character("Prysha", 1, ["heal", "mass_restoration"])
		prysha.equipment.weapon = "sword"
		prysha.equipment.armor = "leather_armor"
		var ishamel = create_character("Ishamel", 1, [])
		ishamel.equipment.amulet = "amulet"
		var felix = create_character("Felix", 1, [])
		var casper = create_character("Casper", 1, ["fireball"])
		party_members = [prysha, ishamel, felix, casper]

func create_character(name: String, level: int, skills: Array) -> BattleActor:
	var character = BattleActor.new()
	character.name = name
	character.level = level
	character.stats = Stats.new()
	character.stats.level = level
	character.known_skills = skills
	character.stats.xp = 0
	character.stats.xp_to_next_level = level * 100

	match name:
		"Prysha": # Healer
			character.stats.strength = level * 2 + 5
			character.stats.defense = level * 3 + 8
			character.stats.dexterity = level * 3 + 5
			character.stats.faith = level * 7 + 10
			character.stats.intelligence = level * 5 + 8
			character.stats.speed = level * 4 + 6
			character.hp_max = level * 8 + 90
			character.mp_max = level * 7 + 30
		"Ishamel": # Knight
			character.stats.strength = level * 6 + 10
			character.stats.defense = level * 5 + 10
			character.stats.dexterity = level * 2 + 4
			character.stats.faith = level * 1 + 2
			character.stats.intelligence = level * 1 + 2
			character.stats.speed = level * 2 + 3
			character.hp_max = level * 12 + 100
			character.mp_max = level * 2 + 10
		"Felix": # Archer
			character.stats.strength = level * 4 + 7
			character.stats.defense = level * 3 + 6
			character.stats.dexterity = level * 7 + 10
			character.stats.faith = level * 2 + 3
			character.stats.intelligence = level * 3 + 4
			character.stats.speed = level * 6 + 8
			character.hp_max = level * 9 + 80
			character.mp_max = level * 4 + 20
		"Casper": # Mage
			character.stats.strength = level * 1 + 3
			character.stats.defense = level * 2 + 5
			character.stats.dexterity = level * 4 + 6
			character.stats.faith = level * 3 + 5
			character.stats.intelligence = level * 8 + 12
			character.stats.speed = level * 5 + 7
			character.hp_max = level * 7 + 70
			character.mp_max = level * 8 + 40
		_: # Default
			character.stats.strength = level * 4 + 5
			character.stats.defense = level * 4 + 5
			character.stats.dexterity = level * 4 + 5
			character.stats.faith = level * 4 + 5
			character.stats.intelligence = level * 4 + 5
			character.stats.speed = level * 4 + 5
			character.hp_max = level * 10 + 90
			character.mp_max = level * 5 + 25

	character.hp = character.hp_max
	character.mp = character.mp_max
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

	match member.name:
		"Prysha": # Healer
			member.stats.strength += 1
			member.stats.defense += 2
			member.stats.dexterity += 1
			member.stats.faith += 4
			member.stats.intelligence += 3
			member.stats.speed += 2
			member.hp_max += 8
			member.mp_max += 7
		"Ishamel": # Knight
			member.stats.strength += 3
			member.stats.defense += 3
			member.stats.dexterity += 1
			member.stats.faith += 1
			member.stats.intelligence += 1
			member.stats.speed += 1
			member.hp_max += 12
			member.mp_max += 2
		"Felix": # Archer
			member.stats.strength += 2
			member.stats.defense += 2
			member.stats.dexterity += 4
			member.stats.faith += 1
			member.stats.intelligence += 2
			member.stats.speed += 3
			member.hp_max += 9
			member.mp_max += 4
		"Casper": # Mage
			member.stats.strength += 1
			member.stats.defense += 1
			member.stats.dexterity += 2
			member.stats.faith += 2
			member.stats.intelligence += 4
			member.stats.speed += 3
			member.hp_max += 7
			member.mp_max += 8
		_: # Default
			member.stats.strength += 2
			member.stats.defense += 2
			member.stats.dexterity += 2
			member.stats.faith += 2
			member.stats.intelligence += 2
			member.stats.speed += 2
			member.hp_max += 10
			member.mp_max += 5

	member.hp = member.hp_max
	member.mp = member.mp_max
