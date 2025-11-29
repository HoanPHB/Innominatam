class_name Menu extends Container

signal button_focused(button: BaseButton)
signal button_pressed(button: BaseButton)

@export var auto_wrap: bool = true

var index: int = 0

# Whether this menu should react to input (arrow keys). Other systems can disable it
var enabled: bool = true


func _ready() -> void:
	#Connect to buttons
	for button in get_buttons():
		button.focus_exited.connect(_on_Button_focus_exited.bind(button))
		button.focus_entered.connect(_on_Button_focused.bind(button))
		button.pressed.connect(_on_Button_pressed.bind(button))

	# Ensure the first button is focused on start
	if get_buttons().size() > 0:
		button_focus(0)
	
	# Set focus neighbors
	# TODO Fix for grids (poss only issue with > 2 col grid)
	if !auto_wrap:
		return
	
	var _class: String = get_class()
	var buttons: Array = get_buttons()
	var use_this_on_grid_containers: bool = false
	
	if use_this_on_grid_containers and get("columns"):
		var top_row: Array = []
		var bottom_row: Array = []
		var cols: int = self.columns
		var rows: int = round(buttons.size() / cols)
		var btm_range: Array = [rows * cols - cols, rows * cols - 1]
		
		
		#if clear_first:
			#for button in buttons:
				#button.focus_neighbor_top = null
				#button.focus_neighbor_bottom = null
				
		#Get top and bottom rows or buttons.
		for x in cols:
			top_row.append(buttons[x])
		for x in range(btm_range[0], btm_range[1] + 1):
			if x > buttons.size():
				bottom_row.append(buttons[x - cols])
				continue
			bottom_row.append(buttons[x])
		# Change their focus neighbors accourdingly.
		for x in cols:
			var top_button: BaseButton = top_row[x]
			var bottom_button: BaseButton = bottom_row[x]
			
			
			if top_button == bottom_button:
				continue
			top_button.focus_neighbor_top = bottom_button.get_path()
			bottom_button.focus_neighbor_bottom = top_button.get_path()
			
		# Repeat for left and right columns.
		for i in range(0, buttons.size(), cols):
			var left_button: BaseButton = buttons[i]
			var right_button: BaseButton = buttons[i + cols - 1]
			
			left_button.focus_neighbor_left = right_button.get_path()
			right_button.focus_neighbor_right = left_button.get_path()
	elif _class.begins_with("VBox"):
		var top_button: BaseButton = buttons.front()
		var bottom_button: BaseButton = buttons.back()
		top_button.focus_neighbor_top = bottom_button.get_path()
		bottom_button.focus_neighbor_bottom = top_button.get_path()
	elif _class.begins_with("Hbox"):
		var first_button: BaseButton = buttons.front()
		var last_button: BaseButton = buttons.back()
		first_button.focus_neighbor_left = last_button.get_path()
		last_button.focus_neighbor_right = first_button.get_path()


func get_buttons() -> Array:
	return get_children()

func connect_to_buttons(target: Object, _name: String = name) -> void:
	var callable: Callable = Callable()
	callable = Callable(target, "_on_" + _name + "_focused")
	button_focused.connect(callable)
	callable = Callable(target, "_on_" + _name + "_pressed")
	button_pressed.connect(callable)

func button_focus(n: int = index) -> void:
	var button: BaseButton = get_buttons()[n]
	button.grab_focus()

func set_enabled(value: bool) -> void:
	enabled = value
	
func _on_Button_focused(button: BaseButton) -> void:
	# Sync index with the focused button to prevent desync
	var btn_index = get_buttons().find(button)
	if btn_index != -1:
		index = btn_index
	emit_signal("button_focused", button)
	
func _on_Button_focus_exited(button: BaseButton) -> void:
	# If menu input is disabled (e.g., selecting enemies), don't reclaim focus
	if not enabled:
		return
	await get_tree().process_frame
	if not is_inside_tree() or not get_viewport():
		return
	if not get_viewport().gui_get_focus_owner() in get_buttons():
		button.grab_focus()
		
func _on_Button_pressed(button: BaseButton) -> void:
	emit_signal("button_pressed", button)

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DOWN:
			index = (index + 1) % get_buttons().size()
			button_focus(index)
		elif event.keycode == KEY_UP:
			index = (index - 1 + get_buttons().size()) % get_buttons().size()
			button_focus(index)
