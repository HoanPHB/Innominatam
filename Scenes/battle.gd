extends Control

# Floating Combat Text Settings
var fct_scene = preload("res://Scenes/FCT.tscn")
var fct_travel = Vector2(0, -40)
var fct_duration = 1.2
var fct_spread = 0

var event_queue: Array = []
var current_active_socket: TurnitySocket
var is_turn_active: bool = false
var atb_nodes: Array = []
var ready_sockets: Array[TurnitySocket] = [] # New: Managed by battle.gd

@onready var _options: Char_Actions = $Options
@onready var _options_menu: Menu = $Options/Menu
@onready var _enemies_root: Control = $Options/Enemies
@onready var _menu_cursor: Node = $MenuCursor
@onready var _players_menu: Menu = $Players
@onready var _players_infos: Array = $Bottom/Players/MarginContainer/VBoxContainer.get_children()
@onready var _player_sprites: Array = $Options/Players.get_children()

var selecting_enemies: bool = false
var enemy_index: int = 0

# Simple party setup for this scene
var party_members: Array = [] # Array[BattleActor]

func _ready() -> void:
	# Disable menu and inputs until a player is ready
	_options_menu.set_enabled(false)
	for b in _options_menu.get_buttons():
		if b is BaseButton:
			b.disabled = true
	
	# Clear any initial focus and hide menu cursor
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner:
		focus_owner.release_focus()
	if _menu_cursor:
		if _menu_cursor.has_method("set_active"):
			_menu_cursor.set_active(false)
		elif _menu_cursor.has_method("hide"):
			_menu_cursor.hide()

	_init_party_members()
	_assign_party_to_bars()
	_init_enemies()
	
	# Collect all ATB bars for pausing
	for p_bar in _players_infos:
		atb_nodes.append(p_bar.get_node("ATB"))
	for e_btn in _get_enemies():
		atb_nodes.append(e_btn.get_node("ATB"))
	
	# --- Turnity Setup ---
	# TurnityManager.activated_turn.connect(_on_turnity_activated_turn) # No longer needed
	TurnityManager.start(self) # Collect all sockets in the scene
	# Disable all sockets at the start of the battle
	for socket in TurnityManager.current_turnity_sockets:
		socket.disable()
	# --- End Turnity Setup ---

func _process(_delta: float) -> void:
	if is_turn_active:
		return

	# Step 1: Check all ATB bars and enable their sockets if they are truly full.
	for atb_bar in atb_nodes:
		if atb_bar.value >= atb_bar.max_value:
			atb_bar.value = atb_bar.max_value # Clamp
			atb_bar.set_process(false) # Stop processing this bar
			
			if atb_bar.socket and atb_bar.socket.is_disabled(): # Only enable if not already enabled
				atb_bar.socket.enable()
				# Play the highlight animation from here
				if atb_bar._anim:
					atb_bar._anim.play("highlight")
				
				# Add to our custom ready queue
				ready_sockets.append(atb_bar.socket)

	# Step 2: Find the first *truly* ready socket from our queue and start its turn.
	if not ready_sockets.is_empty():
		# Sort by some criteria if needed (e.g., speed, or just take first)
		# For now, just take the first one that became ready
		var socket = ready_sockets.pop_front()

		# ULTIMATE FAILSAFE: Double-check the ATB bar's value one last time.
		var atb_bar = socket.actor.get_node_or_null("ATB")
		if atb_bar and atb_bar.value < atb_bar.max_value - 0.001:
			# This socket is enabled but its bar is NOT full. This is an invalid state.
			socket.disable() # Force it back to disabled
			if atb_bar._anim:
				atb_bar._anim.play("RESET") # Reset its highlight
			# Do NOT start turn, just return and wait for next _process
			return

		# If we get here, the character is *truly* ready.
		# Immediately disable them to prevent race conditions (already done by pop_front and disable above).
		
		is_turn_active = true
		_pause_all_atb()
		_on_turnity_activated_turn(socket) # Call the turn activation logic directly
		return
func _pause_all_atb() -> void:
	for atb in atb_nodes:
		atb.set_process(false)

func _resume_all_atb() -> void:
	for atb in atb_nodes:
		if atb.value < atb.max_value:
			atb.set_process(true)

func _reset_all_highlights() -> void:
	for p_bar in _players_infos:
		p_bar.highlight(false)
		var atb_anim = p_bar.get_node("ATB").get_node("AnimationPlayer")
		if atb_anim.is_playing():
			atb_anim.play("RESET")
	for e_btn in _get_enemies():
		var atb_anim = e_btn.get_node("ATB").get_node("AnimationPlayer")
		if atb_anim.is_playing():
			atb_anim.play("RESET")

# Gets the correct node for visual feedback (the sprite on the battlefield)
func _get_feedback_node(target_info_node: Node) -> Node:
	if target_info_node is BattlePlayerbar:
		var player_index = _players_infos.find(target_info_node)
		if player_index != -1 and player_index < _player_sprites.size():
			return _player_sprites[player_index]
	# For enemies, the target node is already the correct sprite
	return target_info_node

func _apply_damage_feedback(node: Node) -> void:
	# Ensure the node has our custom material
	if not node.material is ShaderMaterial:
		return

	# Use a tween to animate the shader's flash modifier
	var tween = create_tween()
	tween.tween_property(node.material, "shader_parameter/flash_modifier", 0.0, 0.4).from(1.0)

	# Use another tween for the shake so it can run in parallel
	var shake_tween = create_tween()
	var original_x = node.position.x
	shake_tween.tween_property(node, "position:x", original_x + 4, 0.05).set_trans(Tween.TRANS_SINE)
	shake_tween.tween_property(node, "position:x", original_x - 4, 0.1).set_trans(Tween.TRANS_SINE)
	shake_tween.tween_property(node, "position:x", original_x, 0.05).set_trans(Tween.TRANS_SINE)

func _show_combat_text(target_node: Node, amount: int) -> void:
	if amount == 0:
		return

	var fct = fct_scene.instantiate()
	add_child(fct)
	fct.global_position = target_node.global_position - Vector2(0, 16)

	var value_text = "+%d" % amount if amount > 0 else str(amount)
	fct.show_value(value_text, fct_travel, fct_duration, fct_spread, false)
	fct.modulate = Color.RED if amount < 0 else Color.PALE_GREEN

func _on_turnity_activated_turn(socket: TurnitySocket) -> void:
	# Clear all previous highlights before starting the new turn
	_reset_all_highlights()

	current_active_socket = socket

	if socket.actor is BattlePlayerbar:
		var player_bar: BattlePlayerbar = socket.actor
		player_bar.highlight(true)
		# Also ensure the ATB bar's own highlight is playing
		var atb_anim = player_bar.get_node("ATB").get_node("AnimationPlayer")
		atb_anim.play("highlight")

		# Enable player controls
		_options_menu.set_enabled(true)
		for b in _options_menu.get_buttons():
			if b is BaseButton:
				b.disabled = false
		if _menu_cursor:
			if _menu_cursor.has_method("set_active"):
				_menu_cursor.set_active(true)
			elif _menu_cursor.has_method("show"):
				_menu_cursor.show()
		_options.show()
		_options_menu.button_focus(0)

	elif socket.actor is TextureButton: # Assuming enemies are TextureButtons
		# Basic Enemy AI: Attack a random player and end turn
		var enemy_button: TextureButton = socket.actor
		var random_player_bar: BattlePlayerbar = _players_infos.pick_random()

		# Create and process an attack on the random player
		_create_attack_event(enemy_button, random_player_bar)
		_process_next_event()

		# End the enemy's turn
		# socket is already disabled by the _process loop
		var atb = enemy_button.get_node_or_null("ATB")
		if atb:
			atb.reset()

		is_turn_active = false
		_resume_all_atb()

func _on_menu_button_pressed(button: BaseButton) -> void:
	if button.text == "Attack":
		_begin_enemy_selection()
	else:
		print(button.text)

func _on_menu_button_focused(button):
	pass # Replace with function body.

func _begin_enemy_selection() -> void:
	# Prepare enemy selection, skipping dead/disabled enemies
	var enemies := _get_enemies()
	if enemies.size() == 0:
		return
	var start_index := _find_first_selectable_index(enemies)
	if start_index == -1:
		# No selectable enemies remain
		selecting_enemies = false
		_options_menu.set_enabled(true)
		return
	selecting_enemies = true
	_options_menu.set_enabled(false)
	enemy_index = start_index
	enemies[enemy_index].grab_focus()

func _end_enemy_selection(confirmed: bool) -> void:
	selecting_enemies = false
	_options_menu.set_enabled(true)
	_options_menu.button_focus(_options_menu.index)

	if confirmed:
		var enemies := _get_enemies()
		if enemies.size() > 0 and current_active_socket:
			var target_btn: TextureButton = enemies[enemy_index] as TextureButton
			var attacker_bar: BattlePlayerbar = current_active_socket.actor

			_create_attack_event(attacker_bar, target_btn)
			_process_next_event()

			# Consume the current player's turn
			_consume_player_turn(current_active_socket)

func _input(event: InputEvent) -> void:
	# Intercept keys BEFORE GUI so TextureButtons/Menu don't also react
	if not selecting_enemies:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var enemies := _get_enemies()
		if enemies.size() == 0:
			return
		match event.keycode:
			KEY_RIGHT, KEY_DOWN:
				var attempts := 0
				while attempts < enemies.size():
					enemy_index = (enemy_index + 1) % enemies.size()
					if _is_enemy_selectable(enemies[enemy_index]):
						enemies[enemy_index].grab_focus()
						accept_event()
						break
					attempts += 1
			KEY_LEFT, KEY_UP:
				var attempts := 0
				while attempts < enemies.size():
					enemy_index = (enemy_index - 1 + enemies.size()) % enemies.size()
					if _is_enemy_selectable(enemies[enemy_index]):
						enemies[enemy_index].grab_focus()
						accept_event()
						break
					attempts += 1
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_end_enemy_selection(true)
				accept_event()
			KEY_ESCAPE, KEY_BACKSPACE:
				_end_enemy_selection(false)
				accept_event()

func _consume_player_turn(socket: TurnitySocket) -> void:
	if not socket:
		return

	var player_bar = socket.actor

	# Stop player highlight and disable socket
	player_bar.highlight(false)
	# socket is already disabled by the _process loop

	# Reset ATB bar for this player
	var atb = player_bar.get_node_or_null("ATB")
	if atb:
		atb.reset()

	# Disable menu input and hide the menu cursor
	_options_menu.set_enabled(false)
	for b in _options_menu.get_buttons():
		if b is BaseButton:
			b.disabled = true
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner:
		focus_owner.release_focus()
	if _menu_cursor:
		if _menu_cursor.has_method("set_active"):
			_menu_cursor.set_active(false)
		elif _menu_cursor.has_method("hide"):
			_menu_cursor.hide()

	is_turn_active = false
	_resume_all_atb()

func _get_enemies() -> Array[TextureButton]:
	var arr: Array[TextureButton] = []
	for child in _enemies_root.get_children():
		if child is TextureButton:
			arr.append(child)
	return arr

func _is_enemy_selectable(btn: TextureButton) -> bool:
	return btn and not btn.disabled and btn.focus_mode != Control.FOCUS_NONE

func _find_first_selectable_index(enemies: Array[TextureButton]) -> int:
	for i in range(enemies.size()):
		if _is_enemy_selectable(enemies[i]):
			return i
	return -1

func _on_enemies_button_pressed(button: BaseButton) -> void:
	# Not used in current flow; selection handled via keyboard
	pass

func _on_players_button_pressed(button: BaseButton) -> void:
	# Not used in current flow
	pass

# Initialize a simple set of party members for display/combat
func _init_party_members() -> void:
	var names := ["Prysha", "Ishamel", "Felix", "Casper"]
	party_members.clear()
	for n in names:
		var a := BattleActor.new()
		a.name = n
		a.hp_max = 100
		a.hp = a.hp_max
		party_members.append(a)

# Assign created actors to UI bars
func _assign_party_to_bars() -> void:
	for i in range(min(party_members.size(), _players_infos.size())):
		var bar: BattlePlayerbar = _players_infos[i]
		bar.set_actor(party_members[i])

func _init_enemies() -> void:
	var enemy_nodes = _get_enemies()
	# Assign actors to enemies - alternating between Orc and Knight
	for i in range(enemy_nodes.size()):
		var enemy_btn = enemy_nodes[i]
		var template_name = "Orc" # Always use Orc for now
		var enemy_template = Enemies.data[template_name]
		var enemy_actor = enemy_template.duplicate() # Create a new instance
		enemy_actor.hp = enemy_actor.hp_max # Ensure full health
		enemy_btn.data = enemy_actor
		# Update enemy label
		var name_label = enemy_btn.get_node_or_null("Name")
		if name_label:
			name_label.text = enemy_actor.name

# Build and queue an attack event
func _create_attack_event(attacker_node: Node, target_node: Node) -> void:
	var attacker_actor: BattleActor
	var target_actor: BattleActor

	if attacker_node is BattlePlayerbar:
		attacker_actor = attacker_node.actor
	elif attacker_node.data is BattleActor:
		attacker_actor = attacker_node.data

	if target_node is BattlePlayerbar:
		target_actor = target_node.actor
	elif target_node.data is BattleActor:
		target_actor = target_node.data

	if attacker_actor and target_actor:
		var evt := {
			"type": "attack",
			"attacker": attacker_actor,
			"target": target_actor,
			"target_node": target_node, # Always store the target node
			"power": 12
		}
		event_queue.append(evt)

# Process next event in the queue
func _process_next_event() -> void:
	if event_queue.is_empty():
		return
	var evt = event_queue.pop_front()
	if typeof(evt) != TYPE_DICTIONARY:
		return
	match evt["type"]:
		"attack":
			var target_actor: BattleActor = evt.get("target", null)
			var target_info_node: Node = evt.get("target_node", null)
			if target_actor and target_info_node:
				var hp_change = target_actor.healhurt(-int(evt.get("power", 10)))

				# Get the node to apply feedback to (the sprite on the battlefield)
				var feedback_node = _get_feedback_node(target_info_node)

				# Show floating combat text
				_show_combat_text(feedback_node, hp_change)

				# Apply damage feedback if damage was taken
				if hp_change < 0:
					_apply_damage_feedback(feedback_node)

				# If target defeated, disable its button
				if target_actor.hp <= 0 and target_info_node is TextureButton:
					var btn: TextureButton = target_info_node
					btn.disabled = true
					btn.modulate = Color(0.5, 0.5, 0.5)
					btn.tooltip_text = "%s (defeated)" % target_actor.name
					# Optional: hide or remove focusability
					btn.focus_mode = Control.FOCUS_NONE
					# Also disable its Turnity socket
					var socket: TurnitySocket = btn.get_node_or_null("TurnitySocket")
					if socket:
						socket.disable()
		_:
			pass
