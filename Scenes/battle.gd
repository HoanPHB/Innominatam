extends Control

enum States {
	OPTIONS,
	TARGETS,
}

var state: States = States.OPTIONS
var atb_queue: Array = []
var event_queue: Array = []

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
	#_options_menu.connect_to_buttons(self)
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

	# Hook ATB ready for each player bar and initialize actors
	for player in _players_infos:
		player.atb_ready.connect(_on_player_atb_ready.bind(player))
	_init_party_members()
	_assign_party_to_bars()



func _on_menu_button_pressed(button: BaseButton) -> void:
	if button.text == "Attack":
		_begin_enemy_selection()
	else:
		print(button.text)


func _on_menu_button_focused(button):
	pass # Replace with function body.

func _on_player_atb_ready(player: BattlePlayerbar) -> void:
	# If this player is already queued, ignore duplicate signals
	if atb_queue.has(player):
		return
	atb_queue.append(player)
	# Only the first in queue gets control and highlight animation
	if atb_queue.size() == 1:
		player.highlight(true)
		# Re-enable inputs and show cursor when queue reappears, and focus Attack
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
		if enemies.size() > 0 and atb_queue.size() > 0:
			var target_btn: TextureButton = enemies[enemy_index] as TextureButton
			var attacker_bar: BattlePlayerbar = atb_queue[0]
			_create_attack_event(attacker_bar, target_btn)
		# Consume the current ready player after queuing the action
		_consume_current_ready()
		# Process the queued action immediately
		_process_next_event()

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

func _consume_current_ready() -> void:
	if atb_queue.size() == 0:
		return
	var player = atb_queue[0]
	atb_queue.remove_at(0)

	# Stop player highlight
	if player and player.has_method("highlight"):
		player.highlight(false)

	# Reset ATB bar for this player
	var atb = player.get_node_or_null("ATB")
	if atb:
		# Reset ATB's own animation and value
		var anim = atb.get_node_or_null(atb.anim_player_path)
		if anim and anim.has_method("play"):
			anim.play("RESET")
		atb.value = atb.min_value
		atb.set_process(true)

	# Promote next ready player
	if atb_queue.size() > 0:
		atb_queue[0].highlight(true)
		_options.show()
	else:
		# No ready players: disable menu input and hide the menu cursor
		_options_menu.set_enabled(false)
		for b in _options_menu.get_buttons():
			if b is BaseButton:
				b.disabled = true
		# Clear focus to avoid button activation via keyboard
		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner:
			focus_owner.release_focus()
		if _menu_cursor:
			if _menu_cursor.has_method("set_active"):
				_menu_cursor.set_active(false)
			elif _menu_cursor.has_method("hide"):
				_menu_cursor.hide()

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

# Build and queue an attack event
func _create_attack_event(attacker_bar: BattlePlayerbar, target_btn: TextureButton) -> void:
	var evt := {
		"type": "attack",
		"attacker_bar": attacker_bar,
		"attacker": attacker_bar.actor if attacker_bar and attacker_bar.actor else null,
		"target_btn": target_btn,
		"target": target_btn.data,
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
					
		_:
			pass
	
