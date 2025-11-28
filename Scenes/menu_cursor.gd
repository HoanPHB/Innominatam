extends TextureRect

const OFFSET: Vector2 = Vector2(-16, 0)

var target: Node = null
var active: bool = false

func _ready() -> void:
	get_viewport().gui_focus_changed.connect(_on_viewport_gui_focus_changed)
	set_process(false)

func set_active(on: bool) -> void:
	active = on
	if active:
		show()
		set_process(true)
	else:
		hide()
		set_process(false)

func _process(delta: float) -> void:
	if target:
		# Center vertically relative to the target
		var y_offset = (target.size.y - size.y) / 2.0
		var current_offset = OFFSET
		if target.has_meta("cursor_offset"):
			current_offset = target.get_meta("cursor_offset")
		global_position = target.global_position + Vector2(0, y_offset) + current_offset

func _on_viewport_gui_focus_changed(node: Control) -> void:
	if not active:
		# Ignore focus changes when inactive
		hide()
		set_process(false)
		return
	if node is BaseButton:
		target = node
		show()
		set_process(true)
	else:
		hide()
		set_process(false)
