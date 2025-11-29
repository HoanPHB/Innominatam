extends TextureRect

# NOTE: The user is manually setting the offset. This is a placeholder.
const OFFSET: Vector2 = Vector2(0, -15)

# --- Bobbing Animation Parameters ---
var bob_height: float = 3.0 # How many pixels to bob up and down.
var bob_speed: float = 4.0  # How fast the bobbing animation plays.
# ----------------------------------

var target_character: CanvasItem = null

func _ready():
	set_process(false)
	hide()

func _process(delta: float):
	if is_instance_valid(target_character):
		# 1. Calculate the base position by following the target character.
		var base_position = target_character.global_position + OFFSET
		
		# 2. Calculate a smooth bobbing offset using a sine wave based on time.
		var time = Time.get_ticks_msec() / 1000.0 # Time in seconds
		var bob_offset = sin(time * bob_speed) * bob_height
		
		# 3. Apply the final position with the bobbing offset added.
		global_position = base_position + Vector2(0, bob_offset)
	else:
		# If the target is ever lost, hide and stop processing.
		target_character = null
		hide()
		set_process(false)

func set_character(character_node: CanvasItem):
	if character_node:
		target_character = character_node
		show()
		set_process(true)
		# Set the position once immediately to prevent a one-frame lag.
		global_position = target_character.global_position + OFFSET
	else:
		target_character = null
		hide()
		set_process(false)
