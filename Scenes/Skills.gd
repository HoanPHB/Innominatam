extends Node

# A dictionary to hold all skill data.
# The key is the skill's unique ID, and the value is its data.
const data = {
	"heal": {
		"name": "Heal",
		"power": 25,
		"target": "ally", # Can be 'ally', 'self', 'enemy', 'all_allies', 'all_enemies'
		"type": "healing",
		"scaling_stat": "faith",
		"mana_cost": 10,
		"description": "Restores a moderate amount of HP to one ally."
	},
	"fireball": {
		"name": "Fireball",
		"power": 20,
		"target": "all_enemies",
		"type": "damage",
		"scaling_stat": "intelligence",
		"mana_cost": 15,
		"description": "Deals medium fire damage to all enemies."
	},
	"mass_restoration": {
		"name": "Mass Restoration",
		"power": 15,
		"target": "all_allies",
		"type": "healing",
		"scaling_stat": "faith",
		"mana_cost": 20,
		"description": "Restores a small amount of HP to all allies."
	}
}
