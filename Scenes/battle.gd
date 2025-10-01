extends Control

var event_queue: Array = []
var current_active_socket: TurnitySocket
var is_turn_active: bool = false
var atb_nodes: Array = []

@onready var _options: Char_Actions = $Options
@onready var _options_menu: Menu = $Options/Menu
@onready var _enemies_root: Control = $Options/Enemies
@onready var _menu_cursor: Node = $MenuCursor

















@onready var _players_menu: Menu = $Players
@onready var _players_infos: Array = $Bottom/Players/MarginContainer/VBoxContainer.get_children()

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
	TurnityManager.activated_turn.connect(_on_turnity_activated_turn)
	TurnityManager.start(self) # Collect all sockets in the scene
	# Disable all sockets at the start of the battle
	for socket in TurnityManager.current_turnity_sockets:
		socket.disable()
	# --- End Turnity Setup ---

func _process(_delta: float) -> void:
	if is_turn_active:
		return

	for socket in TurnityManager.current_turnity_sockets:
		if not socket.is_disabled():
			# Found a ready character, start their turn.
			is_turn_active = true
			_pause_all_atb()
			# Manually trigger the turn instead of using next_turn()
			# This avoids the recursive skip chain.
			TurnityManager.on_socket_active_turn(socket)
			return

func _pause_all_atb() -> void:
	for atb in atb_nodes:
		atb.set_process(false)

func _resume_all_atb() -> void:
	for atb in atb_nodes:
		if atb.value < atb.max_value:
			atb.set_process(true)

func _on_turnity_activated_turn(socket: TurnitySocket) -> void:
	current_active_socket = socket
	
	if socket.actor is BattlePlayerbar:
		var player_bar: BattlePlayerbar = socket.actor
		player_bar.highlight(true)
		
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
		socket.disable()
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
	socket.disable()

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
			"target_btn": target_node if target_node is TextureButton else null,
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
			var target: BattleActor = evt.get("target", null)
			if target:
				target.healhurt(-int(evt.get("power", 10)))
				# If target defeated, disable its button
				var btn: TextureButton = evt.get("target_btn", null)
				if target.hp <= 0 and btn:
					btn.disabled = true
					btn.modulate = Color(0.5,0.5,0.5)
					btn.tooltip_text = "%s (defeated)" % target.name
					# Optional: hide or remove focusability
					btn.focus_mode = Control.FOCUS_NONE
					# Also disable its Turnity socket
					var socket: TurnitySocket = btn.get_node_or_null("TurnitySocket")
					if socket:
						socket.disable()
		_:
			pass
