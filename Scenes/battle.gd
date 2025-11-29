extends Control

# Floating Combat Text Settings
var fct_scene = preload("res://Scenes/FCT.tscn")
var menu_cursor_scene = preload("res://Scenes/menu_cursor.tscn") # Preload the menu cursor scene
var fct_travel = Vector2(0, -40)
var fct_duration = 1.2
var fct_spread = 0

var victory_screen_scene = preload("res://Scenes/victory_screen.tscn")
var defeat_screen_scene = preload("res://Scenes/defeat_screen.tscn")

var event_queue: Array = []
var current_active_socket: TurnitySocket
var is_turn_active: bool = false
var atb_nodes: Array = []
var ready_sockets: Array[TurnitySocket] = [] # New: Managed by battle.gd
var _active_target_cursors: Array[Node] = [] # To hold multiple target cursors

@onready var _options: Char_Actions = $Options
@onready var _options_menu: Menu = $Options/Menu
@onready var _enemies_root: Control = $Options/Enemies
@onready var _menu_cursor: Node = $MenuCursor
@onready var _player_cursor: TextureRect = $PlayerCursor
@onready var _players_menu: Menu = $Players
@onready var _players_infos: Array = $Bottom/Players/MarginContainer/VBoxContainer.get_children()
@onready var _player_sprites: Array = $Options/Players.get_children()
@onready var _victory_screen: Control = $VictoryScreen
@onready var _defeat_screen: Control = $DefeatScreen
@onready var _actions_details: Control = $Options/Actions_Details
@onready var player_buttons: Array = $Options/Players.get_children()
@onready var enemy_buttons: Array = $Options/Enemies.get_children()
@onready var _battle_music_player: AudioStreamPlayer2D = find_child("BattleMusicPlayer", true, false)

var selecting_enemies: bool = false
var enemy_index: int = 0

var selecting_ally: bool = false
var player_index: int = 0
var selecting_all_enemies: bool = false
var selecting_all_allies: bool = false
var current_skill_id: String = ""
var current_item_id: String = ""

# Simple party setup for this scene
var party_members: Array = [] # Array[BattleActor]

func _highlight_targets(nodes: Array, on: bool):
	for node in nodes:
		if on:
			node.modulate = Color.BLUE
		else:
			node.modulate = Color.WHITE

func _ready() -> void:
	await BattleTransition.fade_out(1.0)
	# Disable menu and inputs until a player is ready
	_options_menu.set_enabled(false)
	for b in _options_menu.get_buttons():
		if b is BaseButton:
			b.disabled = true

	# Clear any initial focus and hide menu cursor
	if is_inside_tree() and get_viewport():
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

	# Explicitly connect menu signals
	if not _options_menu.button_pressed.is_connected(_on_menu_button_pressed):
		_options_menu.button_pressed.connect(_on_menu_button_pressed)
	if not _options_menu.button_focused.is_connected(_on_menu_button_focused):
		_options_menu.button_focused.connect(_on_menu_button_focused)

	for enemy in enemy_buttons:
		enemy.modulate.a = 0.0
		enemy.focus_mode = Control.FOCUS_NONE # Prevent accidental navigation
	for player in player_buttons:
		player.modulate.a = 0.0
		player.focus_mode = Control.FOCUS_NONE # Prevent accidental navigation
	
	_victory_screen = victory_screen_scene.instantiate()
	add_child(_victory_screen)
	_victory_screen.hide()

	_defeat_screen = defeat_screen_scene.instantiate()
	add_child(_defeat_screen)
	_defeat_screen.hide()

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

	_slide_in_battle_actors()

	if _battle_music_player:
		_battle_music_player.stream = load("res://sounds/BGM/Battle 1.wav")
		_battle_music_player.play()
	else:
		push_error("BattleMusicPlayer node not found in battle.tscn!")

func _exit_tree() -> void:
	if _battle_music_player:
		_battle_music_player.stop()

func _process(_delta: float) -> void:
	if is_turn_active:
		return

	_check_for_ready_actors()
	_start_next_turn()

func _check_for_ready_actors() -> void:
	var any_full = false
	for atb_bar in atb_nodes:
		if atb_bar.value >= atb_bar.max_value:
			atb_bar.value = atb_bar.max_value # Clamp
			atb_bar.set_process(false) # Stop processing this bar
			any_full = true

			if atb_bar.socket and atb_bar.socket.is_disabled(): # Only enable if not already enabled
				atb_bar.socket.enable()
				# Play the highlight animation from here
				if atb_bar._anim:
					atb_bar._anim.play("highlight")

				# Add to our custom ready queue
				if not ready_sockets.has(atb_bar.socket):
					ready_sockets.append(atb_bar.socket)

	if any_full:
		_pause_all_atb() # Pause all bars if any reached max

func _start_next_turn() -> void:
	if not is_turn_active and not ready_sockets.is_empty():
		# Sort by some criteria if needed (e.g., speed, or just take first)
		# For now, just take the first one that became ready
		var socket = ready_sockets.pop_front()
		socket.disable()
		# ULTIMATE FAILSAFE: Double-check the ATB bar's value one last time.
		var atb_bar = socket.actor.get_node_or_null("ATB")
		if atb_bar and atb_bar.value < atb_bar.max_value - 0.001:
			# This socket is enabled but its bar is NOT full. This is an invalid state.
			socket.enable() # Force it back to disabled
			if atb_bar._anim:
				atb_bar._anim.play("RESET") # Reset its highlight
			# Do NOT start turn, just return and wait for next _process
			return

		# If we get here, the character is *truly* ready.
		# Immediately disable them to prevent race conditions (already done by pop_front and disable above).

		is_turn_active = true
		_pause_all_atb()
		_on_turnity_activated_turn(socket)
		return
func _pause_all_atb() -> void:
	for atb in atb_nodes:
		atb.set_process(false)
		atb.value = min(atb.value, atb.max_value)

func _resume_all_atb() -> void:
	for atb in atb_nodes:
		if atb.value < atb.max_value:
			atb.set_process(true)
		else:
			# Already full, ensure it's in the ready queue
			if atb.socket and not atb.socket.is_disabled() and not ready_sockets.has(atb.socket):
				ready_sockets.append(atb.socket)

	_start_next_turn()

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

func _get_actor_from_socket(socket: TurnitySocket) -> BattleActor:
	if not socket or not socket.actor:
		return null
	
	return _get_actor_from_node(socket.actor)

func _get_actor_from_node(node: Node) -> BattleActor:
	if not node:
		return null
	
	if node is BattlePlayerbar:
		return node.actor
	elif "data" in node and node.data is BattleActor:
		return node.data
	elif node.has_method("get_actor"):
		return node.get_actor()

	return null

# Gets the correct node for visual feedback (the sprite on the battlefield)
func _get_feedback_node(target_info_node: Node) -> Node:
	if target_info_node is BattlePlayerbar:
		var player_index = _players_infos.find(target_info_node)
		if player_index != -1 and player_index < _player_sprites.size():
			return _player_sprites[player_index]
	# For enemies, the target node is already the correct sprite
	return target_info_node


func _slide_in_battle_actors() -> void:
	# Disable player input during intro
	_pause_all_atb()
	get_tree().paused = false

	var tween = create_tween()
	tween.set_parallel(true)

	# --- Slide Enemies In (from left off-screen) ---
	for enemy_btn in enemy_buttons:
		if not is_instance_valid(enemy_btn):
			continue

		var start_pos = enemy_btn.position
		enemy_btn.position.x = - enemy_btn.size.x
		enemy_btn.modulate.a = 1.0
		tween.tween_property(enemy_btn, "position", start_pos, 0.4) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(enemy_btn, "modulate:a", 1.0, 0.3)

	# --- Slide Players In (from right off-screen) ---
	for player_btn in player_buttons:
		if not is_instance_valid(player_btn):
			continue

		var start_pos = player_btn.position
		player_btn.position = start_pos + Vector2(get_viewport_rect().size.x, 0)
		player_btn.modulate.a = 1.0
		tween.tween_property(player_btn, "position", start_pos, 0.4) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(player_btn, "modulate:a", 1.0, 0.3)

	$Options.modulate.a = 0.0
	$Bottom.modulate.a = 0.0
	$Options.show()
	$Bottom.show()
	tween.tween_property($Options, "modulate:a", 1.0, 0.5).set_delay(0.2)
	tween.tween_property($Bottom, "modulate:a", 1.0, 0.5).set_delay(0.2)

	await tween.finished

	$Options.show()
	$Bottom.show()
	_resume_all_atb()
	_start_next_turn()

func _play_enemy_death_animation(enemy_btn: TextureButton) -> void:
	if not enemy_btn or not (enemy_btn.material is ShaderMaterial):
		return
	var mat := enemy_btn.material as ShaderMaterial
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# --- Step 1: Quick final red flash ---
	mat.set_shader_parameter("flash_color", Color(1, 0, 0)) # red
	tween.tween_property(mat, "shader_parameter/flash_modifier", 1.0, 0.15)
	tween.tween_property(mat, "shader_parameter/flash_modifier", 0.0, 0.15)
	
	# --- Step 2: Start dissolve after flash ---
	tween.tween_interval(0.2)
	tween.tween_property(mat, "shader_parameter/fade_amount", 1.0, 1.6)
	
	# --- Step 3: Fade out sprite alpha completely ---
	tween.tween_property(enemy_btn, "modulate:a", 0.0, 0.5)
	
	await tween.finished
	enemy_btn.hide()


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

func _animate_enemy_attack(enemy_node: Control) -> void:
	var tween = create_tween()
	var original_pos = enemy_node.position
	tween.tween_property(enemy_node, "position", original_pos + Vector2(20, 0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(enemy_node, "position", original_pos, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tween.finished


func _show_combat_text(target_node: Node, amount: int, is_healing: bool = false) -> void:
	if amount == 0:
		return

	var fct = fct_scene.instantiate()
	add_child(fct)
	
	# Calculate center position if possible
	var center_pos = target_node.global_position
	if target_node is Control:
		center_pos += target_node.size / 2.0
	elif target_node is Node2D and "texture" in target_node:
		var tex = target_node.texture
		if tex:
			center_pos += tex.get_size() / 2.0

	fct.global_position = center_pos + Vector2(randf_range(-8, 8), randf_range(-24, -8))

	var value_text = str(abs(amount))
	fct.show_value(value_text, fct_travel, fct_duration, fct_spread, false)
	fct.modulate = Color.PALE_GREEN if is_healing else Color.WHITE

func _on_turnity_activated_turn(socket: TurnitySocket) -> void:
	# Clear all previous highlights before starting the new turn
	_reset_all_highlights()

	current_active_socket = socket

	# Reset is_defending at the start of the turn
	var actor = _get_actor_from_socket(socket)
	if actor:
		actor.is_defending = false
		#Stop defend animation if any
		if socket.actor is BattlePlayerbar:
			var player_sprite = _get_feedback_node(socket.actor)
			if player_sprite and player_sprite.has_method("stop_defend_anim"):
				player_sprite.stop_defend_anim()

	if socket.actor is BattlePlayerbar:
		var player_bar: BattlePlayerbar = socket.actor
		player_bar.highlight(true)
		# Also ensure the ATB bar's own highlight is playing
		var atb_anim = player_bar.get_node("ATB").get_node("AnimationPlayer")
		atb_anim.play("highlight")

		# Set the player cursor to the active character
		var player_node = _get_feedback_node(player_bar)
		_player_cursor.set_character(player_node)

		# Enable player controls
		for b in _options_menu.get_children():
			if b is BaseButton:
				b.disabled = false
		if _menu_cursor:
			if _menu_cursor.has_method("set_active"):
				_menu_cursor.set_active(true)
			elif _menu_cursor.has_method("show"):
				_menu_cursor.show()
		_options.show()
		_options_menu.show() # Ensure the menu is visible
		_options_menu.set_enabled(true)

		# Disable Skills button if character has no skills
		var skills_button = null
		for b in _options_menu.get_children():
			if b is BaseButton and b.text == "Skills":
				skills_button = b
				break
		if skills_button:
			var skill_actor = _get_actor_from_socket(current_active_socket)
			if skill_actor and skill_actor.known_skills.is_empty():
				skills_button.disabled = true
		
		var items_button = null
		for b in _options_menu.get_children():
			if b is BaseButton and b.text == "Items":
				items_button = b
				break
		if items_button:
			if InventoryManager.inventory.is_empty():
				items_button.disabled = true

		# Grab focus on the first enabled button
		for b in _options_menu.get_children():
			if b is BaseButton and not b.disabled:
				b.grab_focus()
				break
	elif socket.actor is TextureButton: # Assuming enemies are TextureButtons
		# Basic Enemy AI: Attack a random player and end turn
		var enemy_button: TextureButton = socket.actor
		var random_player_bar: BattlePlayerbar = _players_infos.pick_random()

		# Animate the attack
		await _animate_enemy_attack(enemy_button)

		# Create and process an attack on the random player
		_create_attack_event(enemy_button, random_player_bar)
		_process_next_event()

		# End the enemy's turn
		var atb = enemy_button.get_node_or_null("ATB")
		if atb:
			atb.reset()
		socket.disable()

		is_turn_active = false
		_resume_all_atb()

func _on_menu_button_pressed(button: BaseButton) -> void:
	if button.text == "Attack":
		_begin_enemy_selection()
	elif button.text == "Skills":
		_show_skill_menu()
	elif button.text == "Items":
		_show_item_menu()
	elif button.text == "Defend":
		var defending_actor = _get_actor_from_socket(current_active_socket)
		if defending_actor:
			defending_actor.is_defending = true

		# Play the defend animation on the battlefield sprite
		var player_sprite = _get_feedback_node(current_active_socket.actor)
		if player_sprite and player_sprite.has_method("play_defend_anim"):
			player_sprite.play_defend_anim()

		_consume_player_turn(current_active_socket)
	else:
		pass

func _on_menu_button_focused(button):
	pass # Replace with function body.

func _begin_enemy_selection() -> void:
	# Prepare enemy selection, skipping dead/disabled enemies
	var enemies := _get_enemies()
	if enemies.size() == 0:
		return
	_options_menu.set_enabled(false)
	var start_index := _find_first_selectable_index(enemies)
	if start_index == -1:
		# No selectable enemies remain
		selecting_enemies = false
		_options_menu.set_enabled(true)
		return
	selecting_enemies = true
	for b in _options_menu.get_children():
		b.disabled = true
	# Enable focus for selectable enemies
	for enemy in enemies:
		if not enemy.disabled:
			enemy.focus_mode = Control.FOCUS_ALL
	enemy_index = start_index
	enemies[enemy_index].grab_focus()

func _end_enemy_selection(confirmed: bool) -> void:
	if not selecting_enemies:
		return
	selecting_enemies = false
	_options_menu.set_enabled(true)
	for b in _options_menu.get_children():
		if b is BaseButton:
			b.disabled = false

	# Restore focus to the first enabled menu button (safe and predictable).
	for b in _options_menu.get_children():
		if b is BaseButton and not b.disabled:
			b.grab_focus()
			break
	
	# Reset enemy focus modes
	for enemy in _get_enemies():
		enemy.focus_mode = Control.FOCUS_NONE


	if confirmed:
		var enemies := _get_enemies()
		if enemies.size() > 0 and current_active_socket:
			var target_btn: TextureButton = enemies[enemy_index] as TextureButton
			var attacker_bar: BattlePlayerbar = current_active_socket.actor

			_create_attack_event(attacker_bar, target_btn)
			_process_next_event()

			# Consume the current player's turn
			_consume_player_turn(current_active_socket)
			if _menu_cursor.has_method("set_active"):
				_menu_cursor.set_active(false)
	else:
		current_skill_id = ""
		current_item_id = ""

func _input(event: InputEvent) -> void:
	if selecting_ally:
		_handle_ally_selection_input(event)
	elif selecting_enemies:
		_handle_enemy_selection_input(event)
	elif selecting_all_enemies:
		if event.is_action_pressed("ui_accept"):
			_end_all_enemies_selection(true)
			accept_event()
		elif event.is_action_pressed("ui_cancel"):
			_end_all_enemies_selection(false)
			accept_event()
	elif selecting_all_allies:
		if event.is_action_pressed("ui_accept"):
			_end_all_allies_selection(true)
		elif event.is_action_pressed("ui_cancel"):
			_end_all_allies_selection(false)
	elif _actions_details.visible and event.is_action_pressed("ui_cancel"):
		_end_action_selection()

func _begin_all_enemies_selection():
	selecting_all_enemies = true
	var enemy_nodes = []
	for enemy_btn in _get_enemies():
		if not enemy_btn.disabled and not enemy_btn.data.is_dead:
			enemy_nodes.append(enemy_btn)
	_highlight_targets(enemy_nodes, true)
	
	# Instantiate and position a menu cursor for each enemy
	for enemy_node in enemy_nodes:
		var new_cursor = menu_cursor_scene.instantiate()
		add_child(new_cursor)
		new_cursor.target = enemy_node
		new_cursor.set_active(true)
		_active_target_cursors.append(new_cursor)

func _end_all_enemies_selection(confirmed: bool):
	selecting_all_enemies = false
	var enemy_nodes_to_highlight = []
	for enemy_btn in _get_enemies():
		enemy_nodes_to_highlight.append(enemy_btn)
	_highlight_targets(enemy_nodes_to_highlight, false)
	
	# Destroy all active target cursors
	for cursor in _active_target_cursors:
		cursor.queue_free()
	_active_target_cursors.clear()

	if confirmed:
		var attacker_actor = _get_actor_from_socket(current_active_socket)
		var skill_data = Skills.data.get(current_skill_id)
		if attacker_actor and skill_data:
			if not attacker_actor.consume_mp(skill_data.mana_cost):
				SoundManager.play_sfx("UI_ERROR")
				_end_action_selection()
				return
		for enemy_btn in _get_enemies(): # Iterate over all enemies again to re-check status
			if not enemy_btn.disabled and not enemy_btn.data.is_dead:
				var enemy_actor = enemy_btn.data as BattleActor
				_create_skill_event(current_skill_id, attacker_actor, enemy_actor, enemy_btn)
		_process_next_event()
		_consume_player_turn(current_active_socket)
		_end_action_selection()
		if _menu_cursor.has_method("set_active"):
			_menu_cursor.set_active(false)
	else:
		current_skill_id = ""
		current_item_id = ""
		_end_action_selection()

func _begin_all_allies_selection():
	selecting_all_allies = true
	var ally_nodes = []
	for i in range(party_members.size()):
		# Check if the actor has HP
		if party_members[i].hp > 0:
			ally_nodes.append(_player_sprites[i])
	_highlight_targets(ally_nodes, true)
	
	# Instantiate and position a menu cursor for each ally
	for ally_node in ally_nodes:
		var new_cursor = menu_cursor_scene.instantiate()
		add_child(new_cursor)
		new_cursor.target = ally_node
		new_cursor.set_active(true)
		_active_target_cursors.append(new_cursor)

func _end_all_allies_selection(confirmed: bool):
	selecting_all_allies = false
	var ally_nodes_to_highlight = []
	for i in range(party_members.size()):
		if party_members[i].hp > 0:
			ally_nodes_to_highlight.append(_player_sprites[i])
	_highlight_targets(ally_nodes_to_highlight, false)
	
	# Destroy all active target cursors
	for cursor in _active_target_cursors:
		cursor.queue_free()
	_active_target_cursors.clear()

	if confirmed:
		var attacker_actor = _get_actor_from_socket(current_active_socket)
		var skill_data = Skills.data.get(current_skill_id)
		if attacker_actor and skill_data:
			if not attacker_actor.consume_mp(skill_data.mana_cost):
				SoundManager.play_sfx("UI_ERROR")
				_end_action_selection()
				return
		for i in range(party_members.size()):
			# Check if the actor has HP
			if party_members[i].hp > 0:
				_create_skill_event(current_skill_id, attacker_actor, party_members[i], _players_infos[i])
		_process_next_event()
		_consume_player_turn(current_active_socket)
		_end_action_selection()
		if _menu_cursor.has_method("set_active"):
			_menu_cursor.set_active(false)
	else:
		current_skill_id = ""
		current_item_id = ""
		_end_action_selection()

func _unhandled_input(event: InputEvent) -> void:
	if selecting_enemies:
		_handle_enemy_selection_input(event)
	elif selecting_ally:
		_handle_ally_selection_input(event)
	elif _actions_details.visible:
		if event.is_action_pressed("ui_cancel"):
			_end_action_selection()
			accept_event()

func _handle_ally_selection_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_DOWN, KEY_RIGHT:
				player_index = (player_index + 1) % _player_sprites.size()
				_player_sprites[player_index].grab_focus()
				accept_event()
			KEY_UP, KEY_LEFT:
				player_index = (player_index - 1 + _player_sprites.size()) % _player_sprites.size()
				_player_sprites[player_index].grab_focus()
				accept_event()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_end_ally_selection(true)
				accept_event()
			KEY_ESCAPE, KEY_BACKSPACE:
				_end_ally_selection(false)
				accept_event()

func _handle_enemy_selection_input(event: InputEvent) -> void:
	# print("Enemy Selection Input: ", event)
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		var enemies := _get_enemies()
		if enemies.size() == 0:
			return
		var attempts := 0
		while attempts < enemies.size():
			enemy_index = (enemy_index + 1) % enemies.size()
			if _is_enemy_selectable(enemies[enemy_index]):
				enemies[enemy_index].grab_focus()
				accept_event()
				break
			attempts += 1
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		var enemies := _get_enemies()
		if enemies.size() == 0:
			return
		var attempts := 0
		while attempts < enemies.size():
			enemy_index = (enemy_index - 1 + enemies.size()) % enemies.size()
			if _is_enemy_selectable(enemies[enemy_index]):
				enemies[enemy_index].grab_focus()
				accept_event()
				break
			attempts += 1
	elif event.is_action_pressed("ui_accept"):
		_end_enemy_selection(true)
		accept_event()
	elif event.is_action_pressed("ui_cancel"):
		_end_enemy_selection(false)
		accept_event()


func _consume_player_turn(socket: TurnitySocket) -> void:
	if not is_inside_tree():
		return
		
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
	for b in _options_menu.get_children():
		if b is BaseButton:
			b.disabled = true
	if is_inside_tree() and get_viewport():
		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner:
			focus_owner.release_focus()
	if _menu_cursor:
		if _menu_cursor.has_method("set_active"):
			_menu_cursor.set_active(false)
		elif _menu_cursor.has_method("hide"):
			_menu_cursor.hide()

	# Hide the player cursor
	_player_cursor.set_character(null)

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

func _find_first_selectable_index(enemies: Array) -> int:
	for i in range(enemies.size()):
		var enemy = enemies[i]
		if not enemy.disabled and enemy.visible:
			return i
	return -1

func _on_enemies_button_pressed(button: BaseButton) -> void:
	if selecting_enemies:
		var enemies = _get_enemies()
		var idx = enemies.find(button)
		if idx != -1:
			enemy_index = idx
			_end_enemy_selection(true)

func _on_players_button_pressed(button: BaseButton) -> void:
	# Not used in current flow
	pass

# Initialize a simple set of party members for display/combat
func _init_party_members() -> void:
	party_members = PartyManager.get_party()
	for member in party_members:
		member.hp_max = member.get_effective_stat("hp_max")
		member.mp_max = member.get_effective_stat("mp_max")

# Assign created actors to UI bars
func _assign_party_to_bars() -> void:
	for i in range(min(party_members.size(), _players_infos.size())):
		var bar: BattlePlayerbar = _players_infos[i]
		bar.set_actor(party_members[i])
		# print("Assigned player actor to bar: ", bar.actor.name, " socket.actor: ", bar.socket.actor)

func _init_enemies() -> void:
	var enemy_nodes = _get_enemies()
	# Assign actors to enemies - alternating between Orc and Knight
	for i in range(enemy_nodes.size()):
		var enemy_btn = enemy_nodes[i]
		
		# Store original center to fix layout issues
		var original_center = enemy_btn.position + enemy_btn.size / 2.0
		
		# Randomly select enemy type
		var template_name = "Orc" if randf() > 0.5 else "Rat"
		var enemy_template = Enemies.data[template_name]
		var enemy_actor = enemy_template.duplicate() # Create a new instance
		
		enemy_actor.stats = Stats.new()
		enemy_actor.level = 1 # Default level for enemies for now
		enemy_actor.stats.level = enemy_actor.level
		
		var texture_path = ""
		if template_name == "Orc":
			texture_path = "res://assets/Orc1.png"
			enemy_btn.set_meta("cursor_offset", Vector2(20, 0)) # Custom cursor offset for Orc
			enemy_actor.stats.strength = enemy_actor.level * 4 + 6
			enemy_actor.stats.defense = enemy_actor.level * 2 + 8
			enemy_actor.stats.dexterity = enemy_actor.level * 3 + 4
			enemy_actor.stats.faith = enemy_actor.level * 1 + 1
			enemy_actor.stats.intelligence = enemy_actor.level * 1 + 1
			enemy_actor.stats.speed = enemy_actor.level * 3 + 5
		elif template_name == "Rat":
			texture_path = "res://assets/rat.png"
			enemy_actor.stats.strength = enemy_actor.level * 2 + 2 # Weaker
			enemy_actor.stats.defense = enemy_actor.level * 1 + 2 # Squishy
			enemy_actor.stats.dexterity = enemy_actor.level * 4 + 8 # Agile
			enemy_actor.stats.faith = 1
			enemy_actor.stats.intelligence = 1
			enemy_actor.stats.speed = enemy_actor.level * 5 + 10 # Very fast
		
		var tex = load(texture_path)
		if tex:
			enemy_btn.texture_normal = tex
			# Reset size to match new texture
			enemy_btn.size = tex.get_size()
			# Re-center based on original center
			enemy_btn.position = original_center - enemy_btn.size / 2.0
			# print("Initialized enemy %s (%s). Texture: %s. Size: %s. Pos: %s" % [i, template_name, texture_path, enemy_btn.size, enemy_btn.position])
		else:
			push_error("Failed to load texture for %s: %s" % [template_name, texture_path])

		enemy_actor.hp_max = enemy_actor.get_effective_stat("hp_max")
		enemy_actor.mp_max = enemy_actor.get_effective_stat("mp_max")
		enemy_actor.hp = enemy_actor.hp_max # Ensure full health
		enemy_actor.mp = enemy_actor.mp_max
		enemy_btn.data = enemy_actor
		# Update enemy label
		var name_label = enemy_btn.get_node_or_null("Name")
		if name_label:
			name_label.text = enemy_actor.name
		
		# Debug print for enemy socket actor
		var socket = enemy_btn.get_node_or_null("TurnitySocket")
		if socket:
			pass
			# print("Assigned enemy actor to button: ", enemy_actor.name, " socket.actor: ", socket.actor)
		
		# Connect pressed signal if not already connected
		if not enemy_btn.pressed.is_connected(_on_enemies_button_pressed):
			enemy_btn.pressed.connect(_on_enemies_button_pressed.bind(enemy_btn))

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
		var attacker_strength = attacker_actor.get_effective_stat("strength")
		var target_defense = target_actor.get_effective_stat("defense")
		var damage = (attacker_strength * attacker_strength) / (attacker_strength + target_defense)
		damage = max(1, int(damage * randf_range(0.9, 1.1)))
		
		var evt := {
			"type": "attack",
			"attacker": attacker_actor,
			"target": target_actor,
			"target_node": target_node, # Always store the target node
			"power": damage
		}
		event_queue.append(evt)

# Process next event in the queue
func _process_next_event() -> void:
	while not event_queue.is_empty():
		var evt = event_queue.pop_front()
		# print("Processing event: ", evt)
		if typeof(evt) != TYPE_DICTIONARY:
			continue
		match evt["type"]:
			"attack":
				var target_actor: BattleActor = evt.get("target", null)
				var target_info_node: Node = evt.get("target_node", null)
				if target_actor and target_info_node:
					var hp_change = target_actor.take_damage(int(evt.get("power")))

					# Get the node to apply feedback to (the sprite on the battlefield)
					var feedback_node = _get_feedback_node(target_info_node)

					# Show floating combat text
					_show_combat_text(feedback_node, hp_change, false)

					# Apply damage feedback if damage was taken
					if hp_change < 0:
						SoundManager.play_sfx("Melee_HIT")
						_apply_damage_feedback(feedback_node)

					# If target defeated, disable its button
					if target_actor.hp <= 0 and target_info_node is TextureButton:
						Enemies.on_enemy_defeated(target_actor.name)
						var btn: TextureButton = target_info_node
						btn.disabled = true
						#btn.modulate = Color(0.5, 0.5, 0.5)
						btn.tooltip_text = "%s (defeated)" % target_actor.name
						# Optional: hide or remove focusability
						btn.focus_mode = Control.FOCUS_NONE
						# Mark the data as dead so ATB filling logic can ignore it immediately
						if target_actor.has_meta("is_dead") == false: # not necessary if is_dead exists, safe-guard
						# no-op: metadata not required; we're using the typed BattleActor flag
							pass
						target_actor.is_dead = true

						# Stop and reset that enemy's ATB so it can't fill or re-enter ready queue
						var atb = btn.get_node_or_null("ATB")
						if atb:
							atb.set_process(false)
							if atb.has_method("reset"):
								atb.reset()
							# remove from our atb_nodes list so loops don't iterate it later (optional, but tidy)
							if atb_nodes.has(atb):
								atb_nodes.erase(atb)
						# Also disable its Turnity socket
						var socket: TurnitySocket = btn.get_node_or_null("TurnitySocket")
						if socket:
							socket.disable()
						_play_enemy_death_animation(btn) # Removed await
			"skill":
				var skill_data: Dictionary = evt.get("skill_data")
				var attacker_actor: BattleActor = evt.get("attacker", null)
				var target_actor: BattleActor = evt.get("target", null)
				var target_info_node: Node = evt.get("target_node", null)

				var scaling_stat_name = skill_data.get("scaling_stat", "strength")
				var attacker_scaling_stat = attacker_actor.get_effective_stat(scaling_stat_name)
				
				match skill_data.type:
					"healing":
						SoundManager.play_sfx("Simple_HEAL")
						var healing_amount = skill_data.power + attacker_scaling_stat
						var hp_change = target_actor.healhurt(healing_amount)
						var feedback_node = _get_feedback_node(target_info_node)
						_show_combat_text(feedback_node, healing_amount, true) # Pass calculated healing_amount and true for is_healing
					"damage":
						var target_defense = target_actor.get_effective_stat("defense")
						var damage = (skill_data.power + attacker_scaling_stat) - target_defense
						damage = max(1, int(damage * randf_range(0.9, 1.1)))
						# print("Enemy: ", target_actor.name, ", Calculated Damage: ", damage, ", Attacker Intelligence: ", attacker_scaling_stat, ", Target Defense: ", target_defense)
						var hp_change = target_actor.take_damage(damage)
						# print("Enemy: ", target_actor.name, ", HP Change: ", hp_change, ", Current HP: ", target_actor.hp)
						var feedback_node = _get_feedback_node(target_info_node)
						_show_combat_text(feedback_node, damage, false) # Pass calculated damage and false for is_healing
						if hp_change < 0:
							SoundManager.play_sfx("Melee_HIT")
							_apply_damage_feedback(feedback_node)
						if target_actor.hp <= 0 and target_info_node is TextureButton:
							Enemies.on_enemy_defeated(target_actor.name)
							var btn: TextureButton = target_info_node
							btn.disabled = true
							btn.focus_mode = Control.FOCUS_NONE
							target_actor.is_dead = true
							var atb = btn.get_node_or_null("ATB")
							if atb:
								atb.set_process(false)
								if atb_nodes.has(atb):
									atb_nodes.erase(atb)
							var socket: TurnitySocket = btn.get_node_or_null("TurnitySocket")
							if socket:
								socket.disable()
							_play_enemy_death_animation(btn) # Removed await
			"item":
				var item_data: Dictionary = evt.get("item_data")
				var target_actor: BattleActor = evt.get("target", null)
				var target_info_node: Node = evt.get("target_node", null)
				
				if item_data.get("type") == "consumable" and item_data.has("hp_recovery"):
					SoundManager.play_sfx("Simple_HEAL")
					var healing_amount = item_data.get("hp_recovery")
					var hp_change = target_actor.healhurt(healing_amount)
					var feedback_node = _get_feedback_node(target_info_node)
					_show_combat_text(feedback_node, healing_amount, true)

	await get_tree().create_timer(5).timeout # Add a short delay here
	_check_battle_over() # Moved outside the loop

func _check_battle_over() -> void:
	var all_enemies_defeated = true
	for enemy_btn in _get_enemies():
		var enemy_actor = enemy_btn.data as BattleActor
		if enemy_actor and enemy_actor.hp > 0:
			all_enemies_defeated = false
			break

	if all_enemies_defeated:
		PartyManager.add_experience(100)
		PartyManager.update_party_members(party_members)
		get_tree().paused = false
		_victory_screen.show()
		await get_tree().create_timer(2.0, true).timeout
		get_tree().paused = false
		TurnityManager.reset_active_sockets()
		await BattleTransition.fade_in(1.0) # Play fade-in to cover the screen
		get_tree().change_scene_to_file(WorldState.previous_scene_path)
		return

	var all_players_defeated = true
	for member in party_members:
		if member.hp > 0:
			all_players_defeated = false
			break

	if all_players_defeated:
		PartyManager.update_party_members(party_members)
		get_tree().paused = true
		_defeat_screen.show()
		await get_tree().create_timer(2.0, true).timeout
		get_tree().paused = false
		TurnityManager.reset_active_sockets()
		await BattleTransition.fade_in(1.0) # Play fade-in to cover the screen
		get_tree().change_scene_to_file(WorldState.previous_scene_path)

func _begin_ally_selection() -> void:
	selecting_ally = true
	player_index = 0
	# Make player sprites focusable
	for p in _player_sprites:
		p.focus_mode = Control.FOCUS_ALL
	_player_sprites[player_index].grab_focus()
	
	# Activate and position the menu cursor on the first selected ally
	if _menu_cursor:
		_menu_cursor.target = _player_sprites[player_index]
		_menu_cursor.set_active(true)


func _end_ally_selection(confirmed: bool) -> void:
	selecting_ally = false
	# Make player sprites non-focusable again
	for p in _player_sprites:
		p.focus_mode = Control.FOCUS_NONE

	if confirmed:
		var target_player_sprite = _player_sprites[player_index]
		# Find the corresponding BattlePlayerbar for the selected sprite
		var target_player_bar = _players_infos[player_index]

		var attacker_actor = _get_actor_from_socket(current_active_socket)
		var target_actor = target_player_bar.actor

		if not current_skill_id.is_empty():
			_create_skill_event(current_skill_id, attacker_actor, target_actor, target_player_bar)
			_process_next_event()
			_consume_player_turn(current_active_socket)
			_end_action_selection()
			if _menu_cursor.has_method("set_active"):
				_menu_cursor.set_active(false)
		elif not current_item_id.is_empty():
			var item_data = Items.data.get(current_item_id)
			if item_data:
				_create_item_event(current_item_id, target_actor, target_player_bar)
				InventoryManager.remove_item(current_item_id)
				_process_next_event()
				_consume_player_turn(current_active_socket)
				_end_action_selection()
	else:
		current_skill_id = ""
		current_item_id = ""
		_end_action_selection()

func _end_action_selection() -> void:
	_actions_details.hide()
	for child in _actions_details.get_node("SkillList").get_children():
		child.queue_free()

	# Re-enable menu button focus
	for btn in _options_menu.get_children():
		if btn is BaseButton:
			btn.focus_mode = Control.FOCUS_ALL

	_options_menu.show()
	_options_menu.set_enabled(true)
	if _menu_cursor.has_method("set_active"):
		_menu_cursor.set_active(true)

	if not current_item_id.is_empty():
		for btn in _options_menu.get_children():
			if btn is Button and btn.text == "Items":
				btn.grab_focus()
				break
	elif not current_skill_id.is_empty():
		for btn in _options_menu.get_children():
			if btn is Button and btn.text == "Skills":
				btn.grab_focus()
				break
	
	current_item_id = ""
	current_skill_id = ""

func _create_skill_event(skill_id: String, attacker: BattleActor, target: BattleActor, target_node: Node) -> void:
	var skill_data = Skills.data.get(skill_id)
	if not skill_data:
		return

	var evt = {
		"type": "skill",
		"skill_data": skill_data,
		"attacker": attacker,
		"target": target,
		"target_node": target_node
	}
	event_queue.append(evt)

func _create_item_event(item_id: String, target: BattleActor, target_node: Node) -> void:
	var item_data = Items.data.get(item_id)
	if not item_data:
		return

	var evt = {
		"type": "item",
		"item_data": item_data,
		"target": target,
		"target_node": target_node
	}
	event_queue.append(evt)

func _show_skill_menu() -> void:
	var current_actor: BattleActor = _get_actor_from_socket(current_active_socket)
	if not current_actor:
		return

	# Hide main menu, show details panel, and activate the cursor for the sub-menu
	_options_menu.set_enabled(false)
	_options_menu.hide()
	_actions_details.show()
	if _menu_cursor.has_method("set_active"):
		_menu_cursor.set_active(true)

	# Disable enemy focus to prevent leakage during skill selection
	for enemy in _get_enemies():
		enemy.focus_mode = Control.FOCUS_NONE

	# Disable menu button focus to prevent leakage
	for btn in _options_menu.get_children():
		if btn is BaseButton:
			btn.focus_mode = Control.FOCUS_NONE

	# Disable player sprite focus to prevent leakage
	for player_sprite in _player_sprites:
		player_sprite.focus_mode = Control.FOCUS_NONE

	# Clear any previous buttons from the details panel
	for child in _actions_details.get_node("SkillList").get_children():
		child.queue_free()

	if current_actor.known_skills.is_empty():
		var label = Label.new()
		label.text = "No skills"
		_actions_details.get_node("SkillList").add_child(label)
		return

	var skill_buttons: Array[Button] = []
	# Create and add a button for each known skill
	for skill_id in current_actor.known_skills:
		var skill_data = Skills.data.get(skill_id)
		if not skill_data:
			continue

		var skill_button = Button.new()
		skill_button.text = skill_data.name
		skill_button.pressed.connect(func(): _on_skill_selected(skill_id))
		skill_button.add_to_group("skill_buttons") # Add to group
		_actions_details.get_node("SkillList").add_child(skill_button)
		skill_buttons.append(skill_button)

	# Set up focus navigation for the new buttons
	if not skill_buttons.is_empty():
		if skill_buttons.size() > 1:
			for i in range(skill_buttons.size()):
				var current_button = skill_buttons[i]
				var prev_button = skill_buttons[i - 1] if i > 0 else skill_buttons.back()
				var next_button = skill_buttons[i + 1] if i < skill_buttons.size() - 1 else skill_buttons.front()

				current_button.focus_neighbor_top = prev_button.get_path()
				current_button.focus_neighbor_bottom = next_button.get_path()
				# Explicitly prevent horizontal focus escape
				current_button.focus_neighbor_left = NodePath()
				current_button.focus_neighbor_right = NodePath()

		# Grab focus for the first button in the list
		skill_buttons[0].grab_focus()

func _show_item_menu() -> void:
	# Hide main menu, show details panel, and activate the cursor for the sub-menu
	_options_menu.set_enabled(false)
	_options_menu.hide()
	_actions_details.show()
	if _menu_cursor.has_method("set_active"):
		_menu_cursor.set_active(true)

	# Disable focus for other UI elements
	for enemy in _get_enemies():
		enemy.focus_mode = Control.FOCUS_NONE
	for btn in _options_menu.get_children():
		if btn is BaseButton:
			btn.focus_mode = Control.FOCUS_NONE
	for player_sprite in _player_sprites:
		player_sprite.focus_mode = Control.FOCUS_NONE

	# Clear any previous buttons from the details panel
	for child in _actions_details.get_node("SkillList").get_children():
		child.queue_free()

	if InventoryManager.inventory.is_empty():
		var label = Label.new()
		label.text = "No items"
		_actions_details.get_node("SkillList").add_child(label)
		return

	var item_buttons: Array[Button] = []
	for item_name in InventoryManager.inventory:
		var item_data = Items.data.get(item_name)
		if not item_data:
			continue
		
		var item_button = Button.new()
		item_button.text = item_data.name
		item_button.pressed.connect(func(): _on_item_selected(item_name))
		_actions_details.get_node("SkillList").add_child(item_button)
		item_buttons.append(item_button)

	if not item_buttons.is_empty():
		if item_buttons.size() > 1:
			for i in range(item_buttons.size()):
				var current_button = item_buttons[i]
				var prev_button = item_buttons[i - 1] if i > 0 else item_buttons.back()
				var next_button = item_buttons[i + 1] if i < item_buttons.size() - 1 else item_buttons.front()
				current_button.focus_neighbor_top = prev_button.get_path()
				current_button.focus_neighbor_bottom = next_button.get_path()
				current_button.focus_neighbor_left = NodePath()
				current_button.focus_neighbor_right = NodePath()
		item_buttons[0].grab_focus()

func _on_skill_selected(skill_id: String):
	var skill_data = Skills.data.get(skill_id)
	if not skill_data:
		return

	var actor = _get_actor_from_socket(current_active_socket)
	if actor.mp < skill_data.mana_cost:
		SoundManager.play_sfx("UI_ERROR")
		return

	# Release focus from the skill menu
	if is_inside_tree() and get_viewport():
		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner and focus_owner.is_in_group("skill_buttons"): # Assuming skill buttons are in a group
			focus_owner.release_focus()
	
	# Deactivate the main menu cursor
	if _menu_cursor:
		if _menu_cursor.has_method("set_active"):
			_menu_cursor.set_active(false)
		elif _menu_cursor.has_method("hide"):
			_menu_cursor.hide()

	# Store the skill being used
	current_skill_id = skill_id
	current_item_id = ""

	# Begin target selection based on skill type
	match skill_data.target:
		"ally":
			_begin_ally_selection()
		"enemy":
			_begin_enemy_selection()
		"all_allies":
			_begin_all_allies_selection()
		"all_enemies":
			_begin_all_enemies_selection()
		"self":
			# TODO: Implement self-targeting skills
			pass

func _on_item_selected(item_id: String):
	var item_data = Items.data.get(item_id)
	if not item_data:
		return
	
	if _menu_cursor:
		if _menu_cursor.has_method("set_active"):
			_menu_cursor.set_active(false)
		elif _menu_cursor.has_method("hide"):
			_menu_cursor.hide()
			
	current_item_id = item_id
	current_skill_id = ""
	
	if item_data.get("type") == "consumable":
		_begin_ally_selection()
