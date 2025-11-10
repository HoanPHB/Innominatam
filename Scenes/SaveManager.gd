extends Node

const SAVE_PATH = "user://savegame.json"

func save_game(extra_data: Dictionary = {}) -> Error:
	var save_data = {}

	# Save PartyManager data
	save_data["party_members"] = []
	for member in PartyManager.party_members:
		save_data["party_members"].append(_serialize_battle_actor(member))

	# Save InventoryManager data
	save_data["inventory"] = InventoryManager.inventory

	# Merge extra data
	for key in extra_data:
		save_data[key] = extra_data[key]

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open save file for writing: ", SAVE_PATH)
		return ERR_CANT_CREATE

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	print("Game saved successfully to ", SAVE_PATH)
	return OK

func load_game() -> Dictionary:
	if not save_exists():
		push_error("No save game found at ", SAVE_PATH)
		return {}

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Failed to open save file for reading: ", SAVE_PATH)
		return {}

	var content = file.get_as_text()
	file.close()

	var parse_result = JSON.parse_string(content)
	if parse_result == null:
		push_error("Failed to parse save file: ", SAVE_PATH)
		return {}

	var save_data: Dictionary = parse_result

	# Load PartyManager data
	PartyManager.party_members.clear()
	if save_data.has("party_members"):
		for member_data in save_data["party_members"]:
			var actor = _deserialize_battle_actor(member_data)
			PartyManager.party_members.append(actor)

	# Load InventoryManager data
	if save_data.has("inventory"):
		InventoryManager.inventory = save_data["inventory"]

	print("Game loaded successfully from ", SAVE_PATH)
	return save_data

func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func _serialize_battle_actor(actor: BattleActor) -> Dictionary:
	var serialized_actor = {
		"name": actor.name,
		"hp_max": actor.hp_max,
		"hp": actor.hp,
		"mp_max": actor.mp_max,
		"mp": actor.mp,
		"level": actor.level,
		"known_skills": actor.known_skills,
		"is_dead": actor.is_dead,
		"is_defending": actor.is_defending,
		"stats": _serialize_stats(actor.stats),
		"equipment": actor.equipment
	}
	return serialized_actor

func _deserialize_battle_actor(data: Dictionary) -> BattleActor:
	var actor = BattleActor.new()
	actor.name = data.get("name", "UNKNOWN")
	actor.hp_max = data.get("hp_max", 1)
	actor.hp = data.get("hp", 1)
	actor.mp_max = data.get("mp_max", 0)
	actor.mp = data.get("mp", 0)
	actor.level = data.get("level", 1)
	actor.known_skills = data.get("known_skills", [])
	actor.is_dead = data.get("is_dead", false)
	actor.is_defending = data.get("is_defending", false)
	actor.stats = _deserialize_stats(data.get("stats", {}))
	actor.equipment = data.get("equipment", {})
	return actor

func _serialize_stats(stats_res: Stats) -> Dictionary:
	var serialized_stats = {
		"strength": stats_res.strength,
		"defense": stats_res.defense,
		"dexterity": stats_res.dexterity,
		"faith": stats_res.faith,
		"intelligence": stats_res.intelligence,
		"speed": stats_res.speed
	}
	return serialized_stats

func _deserialize_stats(data: Dictionary) -> Stats:
	var stats_res = Stats.new()
	stats_res.strength = data.get("strength", 0)
	stats_res.defense = data.get("defense", 0)
	stats_res.dexterity = data.get("dexterity", 0)
	stats_res.faith = data.get("faith", 0)
	stats_res.intelligence = data.get("intelligence", 0)
	stats_res.speed = data.get("speed", 0)
	return stats_res
