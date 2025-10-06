extends Node

# A dictionary to hold all skill data.
# The key is the skill's unique ID, and the value is its data.
const data = {
	"heal": {
		"name": "Heal",
		"power": 25,
		"target": "ally", # Can be 'ally', 'self', 'enemy'
		"type": "healing",
		"description": "Restores a moderate amount of HP to one ally."
	}
}
